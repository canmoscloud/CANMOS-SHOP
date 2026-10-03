-- ============================================================================
-- 006 — Pagamentos e conferência de caixa no servidor
-- ============================================================================
-- Problema que esta migration resolve:
--
-- Até a 005, o cliente Flutter gravava diretamente em `pagamentos` com
-- status 'aprovado' e marcava `vendas.status = 'confirmada'`. A policy
-- "pagamentos via venda" era FOR ALL, então qualquer usuário autenticado
-- podia marcar vendas como pagas direto no PostgREST, sem passar pelo
-- Stripe ou pela AbacatePay.
--
-- Efeito colateral: a guarda de idempotência do stripe-webhook
-- (`if status === 'aprovado' return`) sempre disparava, porque o cliente já
-- havia gravado 'aprovado' antes do webhook chegar. O webhook virou no-op.
--
-- Além disso, `fecharCaixa` calculava `saldo_esperado` e `diferenca` no
-- cliente — o operador controlava os dois lados da conferência e podia
-- esconder quebra de caixa.
--
-- Desenho novo: toda escrita em `pagamentos` passa a ser do servidor.
--   dinheiro  -> RPC registrar_pagamento_dinheiro (SECURITY DEFINER)
--   cartão    -> Edge Function stripe-payment grava 'pendente';
--                stripe-webhook promove para 'aprovado'
--   pix       -> Edge Function abacatepay-pix grava 'pendente';
--                abacatepay-webhook promove para 'aprovado'
-- O cliente só lê.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1. AJUSTE DE SCHEMA
-- ----------------------------------------------------------------------------
-- O copia-e-cola do PIX (EMV BR Code) passa de 255 caracteres quando o payload
-- é dinâmico e carrega URL. VARCHAR(255) faria o INSERT do pagamento falhar
-- justamente no fluxo de PIX.
ALTER TABLE pagamentos
  ALTER COLUMN pix_qr_code_texto TYPE TEXT;


-- ----------------------------------------------------------------------------
-- 2. HELPERS
-- ----------------------------------------------------------------------------

-- Soma dos pagamentos de uma venda. `p_incluir_pendentes` existe para
-- reservar o valor de um PIX/cartão em andamento e impedir que a soma dos
-- pagamentos ultrapasse o total da venda.
CREATE OR REPLACE FUNCTION venda_total_pago(
  p_venda_id UUID,
  p_incluir_pendentes BOOLEAN DEFAULT FALSE
)
RETURNS DECIMAL(10,2)
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT COALESCE(SUM(valor), 0)
  FROM pagamentos
  WHERE venda_id = p_venda_id
    AND (
      status = 'aprovado'
      OR (p_incluir_pendentes AND status = 'pendente')
    );
$$;


-- ----------------------------------------------------------------------------
-- 3. RPC: registrar pagamento em dinheiro
-- ----------------------------------------------------------------------------
-- Dinheiro é aprovado na hora: o operador recebe a cédula fisicamente, não
-- existe confirmação assíncrona. Mas o valor e o vínculo com a empresa são
-- validados no servidor.

CREATE OR REPLACE FUNCTION registrar_pagamento_dinheiro(
  p_venda_id UUID,
  p_valor DECIMAL(10,2)
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_empresa_id   UUID;
  v_venda        RECORD;
  v_liquido      DECIMAL(10,2);
  v_reservado    DECIMAL(10,2);
  v_restante     DECIMAL(10,2);
  v_pagamento_id UUID;
  v_aprovado     DECIMAL(10,2);
  v_status_venda TEXT;
BEGIN
  v_empresa_id := get_my_empresa_id();
  IF v_empresa_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  IF p_valor IS NULL OR p_valor <= 0 THEN
    RAISE EXCEPTION 'Valor do pagamento deve ser maior que zero';
  END IF;

  SELECT * INTO v_venda
  FROM vendas
  WHERE id = p_venda_id AND empresa_id = v_empresa_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Venda não encontrada';
  END IF;

  IF v_venda.status <> 'pendente' THEN
    RAISE EXCEPTION 'Venda já está % e não aceita novo pagamento', v_venda.status;
  END IF;

  v_liquido   := v_venda.valor_total - v_venda.desconto;
  v_reservado := venda_total_pago(p_venda_id, TRUE);
  v_restante  := v_liquido - v_reservado;

  IF p_valor > v_restante THEN
    RAISE EXCEPTION 'Valor % excede o restante da venda (%)', p_valor, v_restante;
  END IF;

  INSERT INTO pagamentos (venda_id, forma_pagamento, valor, status, processado_em)
  VALUES (p_venda_id, 'dinheiro', p_valor, 'aprovado', NOW())
  RETURNING id INTO v_pagamento_id;

  -- Confirma a venda somente quando o total aprovado cobre o líquido.
  v_aprovado := venda_total_pago(p_venda_id, FALSE);

  IF v_aprovado >= v_liquido THEN
    UPDATE vendas SET status = 'confirmada' WHERE id = p_venda_id;
    v_status_venda := 'confirmada';
  ELSE
    v_status_venda := 'pendente';
  END IF;

  RETURN jsonb_build_object(
    'pagamento_id', v_pagamento_id,
    'venda_status', v_status_venda,
    'total_aprovado', v_aprovado,
    'restante', GREATEST(v_liquido - v_aprovado, 0)
  );
END;
$$;


-- ----------------------------------------------------------------------------
-- 4. RPC: cancelar venda
-- ----------------------------------------------------------------------------
-- Substitui o UPDATE direto que o cliente fazia. Recusa cancelar venda que
-- já tenha pagamento aprovado: isso exige estorno, que não está implementado,
-- e cancelar sem estornar deixaria dinheiro recebido sem venda associada.

CREATE OR REPLACE FUNCTION cancelar_venda(p_venda_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_empresa_id UUID;
  v_venda      RECORD;
  v_aprovado   DECIMAL(10,2);
BEGIN
  v_empresa_id := get_my_empresa_id();
  IF v_empresa_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  SELECT * INTO v_venda
  FROM vendas
  WHERE id = p_venda_id AND empresa_id = v_empresa_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Venda não encontrada';
  END IF;

  IF v_venda.status = 'cancelada' THEN
    RETURN jsonb_build_object('venda_status', 'cancelada', 'ja_cancelada', TRUE);
  END IF;

  v_aprovado := venda_total_pago(p_venda_id, FALSE);

  IF v_aprovado > 0 THEN
    RAISE EXCEPTION
      'Venda possui % já aprovado em pagamentos. Estorne antes de cancelar.',
      v_aprovado;
  END IF;

  -- Pagamentos pendentes (PIX não pago, cartão não confirmado) são cancelados
  -- junto, senão um webhook atrasado reativaria o pagamento de uma venda morta.
  UPDATE pagamentos
  SET status = 'cancelado'
  WHERE venda_id = p_venda_id AND status = 'pendente';

  UPDATE vendas SET status = 'cancelada' WHERE id = p_venda_id;

  RETURN jsonb_build_object('venda_status', 'cancelada', 'ja_cancelada', FALSE);
END;
$$;


-- ----------------------------------------------------------------------------
-- 5. RPC: fechar caixa
-- ----------------------------------------------------------------------------
-- O operador informa apenas o que contou na gaveta (p_saldo_real). O esperado
-- é somado no servidor a partir dos pagamentos em dinheiro aprovados das
-- vendas vinculadas a este caixa. Só dinheiro entra na gaveta — cartão e PIX
-- não afetam a conferência física.

CREATE OR REPLACE FUNCTION fechar_caixa(
  p_caixa_id    UUID,
  p_saldo_real  DECIMAL(10,2),
  p_observacao  TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_empresa_id UUID;
  v_caixa      RECORD;
  v_dinheiro   DECIMAL(10,2);
  v_esperado   DECIMAL(10,2);
  v_diferenca  DECIMAL(10,2);
BEGIN
  v_empresa_id := get_my_empresa_id();
  IF v_empresa_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  IF p_saldo_real IS NULL OR p_saldo_real < 0 THEN
    RAISE EXCEPTION 'Saldo real informado é inválido';
  END IF;

  SELECT * INTO v_caixa
  FROM caixa
  WHERE id = p_caixa_id AND empresa_id = v_empresa_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Caixa não encontrado';
  END IF;

  IF v_caixa.status <> 'aberto' THEN
    RAISE EXCEPTION 'Caixa já está fechado';
  END IF;

  SELECT COALESCE(SUM(pg.valor), 0) INTO v_dinheiro
  FROM pagamentos pg
  JOIN vendas v ON v.id = pg.venda_id
  WHERE v.caixa_id = p_caixa_id
    AND v.status = 'confirmada'
    AND pg.forma_pagamento = 'dinheiro'
    AND pg.status = 'aprovado';

  v_esperado  := v_caixa.valor_abertura + v_dinheiro;
  v_diferenca := p_saldo_real - v_esperado;

  UPDATE caixa SET
    valor_fechamento = p_saldo_real,
    saldo_esperado   = v_esperado,
    saldo_real       = p_saldo_real,
    diferenca        = v_diferenca,
    observacao       = p_observacao,
    status           = 'fechado',
    data_fechamento  = NOW()
  WHERE id = p_caixa_id;

  RETURN jsonb_build_object(
    'valor_abertura',  v_caixa.valor_abertura,
    'total_dinheiro',  v_dinheiro,
    'saldo_esperado',  v_esperado,
    'saldo_real',      p_saldo_real,
    'diferenca',       v_diferenca
  );
END;
$$;


-- ----------------------------------------------------------------------------
-- 6. RLS — o cliente passa a só ler pagamentos, vendas e itens
-- ----------------------------------------------------------------------------
-- Remove as policies FOR ALL das tabelas financeiras. Escrita agora é
-- exclusividade do service_role (Edge Functions) e das funções
-- SECURITY DEFINER acima, que validam empresa e valor.
--
-- Drop dinâmico: os nomes das policies vieram da 005 e a migration precisa
-- ser re-executável.

DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT policyname, tablename
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN ('vendas', 'itens_venda', 'pagamentos', 'caixa')
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', r.policyname, r.tablename);
  END LOOP;
END;
$$;

-- VENDAS: leitura da própria empresa. Criação via criar_venda(),
-- cancelamento via cancelar_venda(), confirmação só pelo servidor.
CREATE POLICY "vendas leitura" ON vendas
  FOR SELECT USING (empresa_id = get_my_empresa_id());

-- ITENS_VENDA: leitura. Inserção acontece dentro de criar_venda().
CREATE POLICY "itens_venda leitura" ON itens_venda
  FOR SELECT USING (
    venda_id IN (SELECT id FROM vendas WHERE empresa_id = get_my_empresa_id())
  );

-- PAGAMENTOS: somente leitura. Nenhuma escrita pelo cliente.
CREATE POLICY "pagamentos leitura" ON pagamentos
  FOR SELECT USING (
    venda_id IN (SELECT id FROM vendas WHERE empresa_id = get_my_empresa_id())
  );

-- CAIXA: abrir é legítimo pelo cliente (o valor de abertura é declarado pelo
-- operador, não há como derivá-lo). Fechar vai por fechar_caixa(), porque é
-- lá que a conferência é calculada.
CREATE POLICY "caixa leitura" ON caixa
  FOR SELECT USING (empresa_id = get_my_empresa_id());

-- O caixa nasce aberto, sem conferência preenchida, e no nome de quem abriu:
-- `usuario_id = auth.uid()` evita abrir caixa atribuído a um colega.
CREATE POLICY "caixa abertura" ON caixa
  FOR INSERT WITH CHECK (
    empresa_id = get_my_empresa_id()
    AND usuario_id = auth.uid()
    AND status = 'aberto'
    AND valor_fechamento IS NULL
    AND saldo_esperado IS NULL
    AND diferenca IS NULL
  );


-- ----------------------------------------------------------------------------
-- 7. PRIVILÉGIOS
-- ----------------------------------------------------------------------------
-- O Supabase concede EXECUTE a anon/authenticated por padrão, o que expõe
-- toda função como endpoint REST. Revoga de anon e dos helpers internos.

-- venda_total_pago é chamada de dentro das funções SECURITY DEFINER acima,
-- onde o EXECUTE é verificado contra o owner e não contra o chamador — logo
-- revogar de authenticated não quebra nada e fecha o endpoint REST.
REVOKE ALL ON FUNCTION venda_total_pago(UUID, BOOLEAN) FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION registrar_pagamento_dinheiro(UUID, DECIMAL) FROM anon;
REVOKE ALL ON FUNCTION cancelar_venda(UUID) FROM anon;
REVOKE ALL ON FUNCTION fechar_caixa(UUID, DECIMAL, TEXT) FROM anon;

GRANT EXECUTE ON FUNCTION registrar_pagamento_dinheiro(UUID, DECIMAL) TO authenticated;
GRANT EXECUTE ON FUNCTION cancelar_venda(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION fechar_caixa(UUID, DECIMAL, TEXT) TO authenticated;
