-- CANMOS-SHOP: RPC function to create a sale atomically
-- Migration 002: criar_venda function

-- NOTA: parâmetros com DEFAULT precisam vir por último (a versão original
-- tinha p_caixa_id DEFAULT NULL antes de parâmetros obrigatórios e falhava).
-- Esta função é substituída pela versão segura na migration 005.
CREATE OR REPLACE FUNCTION criar_venda(
  p_empresa_id UUID,
  p_usuario_id UUID,
  p_valor_total DECIMAL(10,2),
  p_itens JSONB,
  p_caixa_id UUID DEFAULT NULL,
  p_desconto DECIMAL(10,2) DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_venda_id UUID;
  v_item JSONB;
BEGIN
  INSERT INTO vendas (empresa_id, usuario_id, caixa_id, valor_total, desconto, status)
  VALUES (p_empresa_id, p_usuario_id, p_caixa_id, p_valor_total, p_desconto, 'pendente')
  RETURNING id INTO v_venda_id;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_itens)
  LOOP
    INSERT INTO itens_venda (venda_id, produto_id, quantidade, preco_unitario, subtotal)
    VALUES (
      v_venda_id,
      (v_item->>'produto_id')::UUID,
      (v_item->>'quantidade')::INTEGER,
      (v_item->>'preco_unitario')::DECIMAL,
      (v_item->>'subtotal')::DECIMAL
    );
  END LOOP;

  PERFORM pg_notify('venda_criada', jsonb_build_object('id', v_venda_id)::text);

  RETURN jsonb_build_object('id', v_venda_id);
END;
$$;
