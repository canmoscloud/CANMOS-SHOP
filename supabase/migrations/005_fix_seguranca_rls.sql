-- CANMOS-SHOP: Correções de segurança
-- Migration 005:
--   1. Funções auxiliares para RLS (elimina recursão infinita na policy de usuarios)
--   2. Policies reescritas (operadores podem ler a própria empresa; escrita restrita a admin)
--   3. RLS em assinaturas e planos (antes ficavam totalmente expostas ao client)
--   4. criar_venda segura: deriva usuário/empresa de auth.uid(), recalcula preços no servidor
--      e vincula automaticamente ao caixa aberto
--   5. Limites de plano: -1 = ilimitado (Premium estava bloqueado) e limite de vendas por mês

-- ============================================
-- 1. FUNÇÕES AUXILIARES (SECURITY DEFINER ignora RLS, evitando recursão)
-- ============================================

CREATE OR REPLACE FUNCTION get_my_empresa_id()
RETURNS UUID
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT empresa_id FROM usuarios WHERE id = auth.uid() AND ativo = TRUE;
$$;

CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM usuarios WHERE id = auth.uid() AND role = 'admin' AND ativo = TRUE
  );
$$;

REVOKE ALL ON FUNCTION get_my_empresa_id() FROM PUBLIC;
REVOKE ALL ON FUNCTION is_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_my_empresa_id() TO authenticated;
GRANT EXECUTE ON FUNCTION is_admin() TO authenticated;

-- ============================================
-- 2. POLICIES REESCRITAS
-- ============================================

-- Remove as policies existentes das tabelas afetadas: torna a migration
-- reexecutável e elimina resquícios do schema original
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT policyname, tablename
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN ('empresas','usuarios','produtos','categorias','vendas',
                        'itens_venda','pagamentos','caixa','logs','assinaturas','planos')
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', r.policyname, r.tablename);
  END LOOP;
END;
$$;

-- EMPRESAS: qualquer membro lê; apenas admin altera
CREATE POLICY "empresas: membros leem" ON empresas
  FOR SELECT USING (id = get_my_empresa_id());
CREATE POLICY "empresas: admin atualiza" ON empresas
  FOR UPDATE USING (id = get_my_empresa_id() AND is_admin());

-- USUARIOS: sem subquery recursiva
CREATE POLICY "usuarios: membros leem" ON usuarios
  FOR SELECT USING (empresa_id = get_my_empresa_id());
CREATE POLICY "usuarios: admin gerencia" ON usuarios
  FOR ALL USING (empresa_id = get_my_empresa_id() AND is_admin());

-- PRODUTOS
CREATE POLICY "produtos por empresa" ON produtos
  FOR ALL USING (empresa_id = get_my_empresa_id())
  WITH CHECK (empresa_id = get_my_empresa_id());

-- CATEGORIAS
CREATE POLICY "categorias por empresa" ON categorias
  FOR ALL USING (empresa_id = get_my_empresa_id())
  WITH CHECK (empresa_id = get_my_empresa_id());

-- VENDAS
CREATE POLICY "vendas por empresa" ON vendas
  FOR ALL USING (empresa_id = get_my_empresa_id())
  WITH CHECK (empresa_id = get_my_empresa_id());

-- ITENS_VENDA
CREATE POLICY "itens_venda via venda" ON itens_venda
  FOR ALL USING (
    venda_id IN (SELECT id FROM vendas WHERE empresa_id = get_my_empresa_id())
  );

-- PAGAMENTOS
CREATE POLICY "pagamentos via venda" ON pagamentos
  FOR ALL USING (
    venda_id IN (SELECT id FROM vendas WHERE empresa_id = get_my_empresa_id())
  );

-- CAIXA
CREATE POLICY "caixa por empresa" ON caixa
  FOR ALL USING (empresa_id = get_my_empresa_id())
  WITH CHECK (empresa_id = get_my_empresa_id());

-- LOGS
CREATE POLICY "logs apenas admin" ON logs
  FOR SELECT USING (empresa_id = get_my_empresa_id() AND is_admin());

-- ============================================
-- 3. RLS EM ASSINATURAS E PLANOS
--    (sem RLS, qualquer usuário autenticado podia ler/alterar assinaturas de
--     qualquer empresa e se promover a Premium)
-- ============================================

ALTER TABLE assinaturas ENABLE ROW LEVEL SECURITY;
CREATE POLICY "assinaturas: membros leem" ON assinaturas
  FOR SELECT USING (empresa_id = get_my_empresa_id());
-- Escrita apenas via service_role (webhooks) — nenhuma policy de INSERT/UPDATE/DELETE

ALTER TABLE planos ENABLE ROW LEVEL SECURITY;
CREATE POLICY "planos: leitura para autenticados" ON planos
  FOR SELECT TO authenticated USING (TRUE);

-- ============================================
-- 4. CRIAR_VENDA SEGURA
--    A versão anterior aceitava empresa_id/usuario_id/preços do cliente
--    (SECURITY DEFINER sem validação = qualquer usuário criava vendas em
--     qualquer empresa com valores arbitrários)
-- ============================================

-- Remove qualquer overload anterior: se sobrar mais de uma versão, o PostgREST
-- não consegue resolver a chamada RPC pelos nomes dos parâmetros.
DO $$
DECLARE
  v_sig TEXT;
BEGIN
  FOR v_sig IN
    SELECT format('%I(%s)', p.proname, pg_get_function_identity_arguments(p.oid))
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'criar_venda'
  LOOP
    EXECUTE 'DROP FUNCTION IF EXISTS public.' || v_sig;
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION criar_venda(
  p_itens JSONB,
  p_desconto DECIMAL(10,2) DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_usuario_id UUID := auth.uid();
  v_empresa_id UUID;
  v_caixa_id UUID;
  v_venda_id UUID;
  v_item JSONB;
  v_produto RECORD;
  v_quantidade INTEGER;
  v_subtotal DECIMAL(10,2);
  v_valor_total DECIMAL(10,2) := 0;
BEGIN
  IF v_usuario_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  SELECT empresa_id INTO v_empresa_id
  FROM usuarios WHERE id = v_usuario_id AND ativo = TRUE;

  IF v_empresa_id IS NULL THEN
    RAISE EXCEPTION 'Usuário inválido ou inativo';
  END IF;

  IF p_itens IS NULL OR jsonb_typeof(p_itens) <> 'array' OR jsonb_array_length(p_itens) = 0 THEN
    RAISE EXCEPTION 'Venda sem itens';
  END IF;

  IF p_desconto IS NULL OR p_desconto < 0 THEN
    RAISE EXCEPTION 'Desconto inválido';
  END IF;

  -- Vincula ao caixa aberto da empresa, se houver
  SELECT id INTO v_caixa_id
  FROM caixa
  WHERE empresa_id = v_empresa_id AND status = 'aberto'
  ORDER BY data_abertura DESC
  LIMIT 1;

  INSERT INTO vendas (empresa_id, usuario_id, caixa_id, valor_total, desconto, status)
  VALUES (v_empresa_id, v_usuario_id, v_caixa_id, 0, p_desconto, 'pendente')
  RETURNING id INTO v_venda_id;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_itens)
  LOOP
    v_quantidade := (v_item->>'quantidade')::INTEGER;
    IF v_quantidade IS NULL OR v_quantidade <= 0 THEN
      RAISE EXCEPTION 'Quantidade inválida';
    END IF;

    -- Preço vem do banco, nunca do cliente
    SELECT id, preco INTO v_produto
    FROM produtos
    WHERE id = (v_item->>'produto_id')::UUID
      AND empresa_id = v_empresa_id
      AND ativo = TRUE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Produto não encontrado ou inativo: %', v_item->>'produto_id';
    END IF;

    v_subtotal := ROUND(v_produto.preco * v_quantidade, 2);
    v_valor_total := v_valor_total + v_subtotal;

    INSERT INTO itens_venda (venda_id, produto_id, quantidade, preco_unitario, subtotal)
    VALUES (v_venda_id, v_produto.id, v_quantidade, v_produto.preco, v_subtotal);
  END LOOP;

  IF p_desconto > v_valor_total THEN
    RAISE EXCEPTION 'Desconto (%) maior que o total da venda (%)', p_desconto, v_valor_total;
  END IF;

  -- valor_total é o bruto; o líquido é valor_total - desconto (semântica do app)
  UPDATE vendas SET valor_total = v_valor_total WHERE id = v_venda_id;

  PERFORM pg_notify('venda_criada', jsonb_build_object('id', v_venda_id)::text);

  RETURN jsonb_build_object(
    'id', v_venda_id,
    'valor_total', v_valor_total,
    'desconto', p_desconto,
    'valor_liquido', v_valor_total - p_desconto,
    'caixa_id', v_caixa_id
  );
END;
$$;

REVOKE ALL ON FUNCTION criar_venda(JSONB, DECIMAL) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION criar_venda(JSONB, DECIMAL) TO authenticated;

-- ============================================
-- 5. LIMITES DE PLANO
--    -1 = ilimitado (antes o Premium era bloqueado: COUNT >= -1 é sempre TRUE)
--    Limite de vendas do Free passa a ser mensal, não vitalício
-- ============================================

CREATE OR REPLACE FUNCTION check_produto_limit()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_plano_limite INTEGER;
  v_total INTEGER;
BEGIN
  SELECT p.limite_produtos INTO v_plano_limite
  FROM assinaturas a
  JOIN planos p ON p.id = a.plano_id
  WHERE a.empresa_id = NEW.empresa_id AND a.status = 'active'
  ORDER BY a.created_at DESC
  LIMIT 1;

  IF v_plano_limite IS NOT NULL AND v_plano_limite >= 0 THEN
    SELECT COUNT(*) INTO v_total FROM produtos
    WHERE empresa_id = NEW.empresa_id AND ativo = TRUE;

    IF v_total >= v_plano_limite THEN
      RAISE EXCEPTION 'Limite de produtos atingido: %', v_plano_limite;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION check_venda_limit()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_plano_limite INTEGER;
  v_total INTEGER;
BEGIN
  SELECT p.limite_vendas INTO v_plano_limite
  FROM assinaturas a
  JOIN planos p ON p.id = a.plano_id
  WHERE a.empresa_id = NEW.empresa_id AND a.status = 'active'
  ORDER BY a.created_at DESC
  LIMIT 1;

  IF v_plano_limite IS NOT NULL AND v_plano_limite >= 0 THEN
    SELECT COUNT(*) INTO v_total FROM vendas
    WHERE empresa_id = NEW.empresa_id
      AND status = 'confirmada'
      AND created_at >= date_trunc('month', NOW());

    IF v_total >= v_plano_limite THEN
      RAISE EXCEPTION 'Limite de vendas do mês atingido: %', v_plano_limite;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- ============================================
-- 6. ENDURECIMENTO DE PRIVILÉGIOS
--    O Supabase concede EXECUTE a anon/authenticated por padrão, então
--    REVOKE ... FROM PUBLIC não basta: é preciso revogar dos roles nominalmente.
--    Sem isso, toda função fica exposta como endpoint em /rest/v1/rpc/.
--    Funções de trigger não precisam de EXECUTE para disparar — o privilégio
--    só é verificado no CREATE TRIGGER.
-- ============================================

ALTER FUNCTION update_updated_at() SET search_path = public;

REVOKE ALL ON FUNCTION handle_new_user() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION check_produto_limit() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION check_venda_limit() FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION get_my_empresa_id() FROM anon;
REVOKE ALL ON FUNCTION is_admin() FROM anon;
REVOKE ALL ON FUNCTION criar_venda(JSONB, DECIMAL) FROM anon;
