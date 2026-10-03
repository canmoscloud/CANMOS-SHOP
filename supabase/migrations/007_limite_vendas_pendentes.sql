-- ============================================================================
-- 007 — Limite de vendas do plano conta as pendentes
-- ============================================================================
-- check_venda_limit é BEFORE INSERT em vendas e contava apenas vendas com
-- status 'confirmada' no mês. Como toda venda nasce 'pendente', o contador
-- ficava atrás da realidade: era possível criar 20 vendas pendentes (todas
-- passavam, porque o total de confirmadas seguia zero) e confirmar as 20
-- depois, estourando o limite do plano Free.
--
-- A correção vai na criação, não na confirmação. Checar no UPDATE para
-- 'confirmada' pareceria mais natural, mas quem confirma é o webhook do
-- provedor depois de o dinheiro entrar: um RAISE ali faria a venda paga
-- nunca fechar, e o cliente ficaria sem recibo por causa de um limite
-- comercial. Quota tem de barrar antes de cobrar, nunca depois.
--
-- Vendas canceladas não contam, então uma venda abandonada pode ser
-- cancelada para liberar a quota do mês.
-- ============================================================================

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

  -- limite_vendas = -1 significa ilimitado.
  IF v_plano_limite IS NOT NULL AND v_plano_limite >= 0 THEN
    SELECT COUNT(*) INTO v_total
    FROM vendas
    WHERE empresa_id = NEW.empresa_id
      AND status IN ('pendente', 'confirmada')
      AND created_at >= date_trunc('month', NOW());

    IF v_total >= v_plano_limite THEN
      RAISE EXCEPTION
        'Limite de % vendas do mês atingido no seu plano. '
        'Cancele vendas pendentes ou faça upgrade para o Premium.',
        v_plano_limite;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION check_venda_limit() FROM PUBLIC, anon, authenticated;
