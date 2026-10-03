-- ============================================================================
-- 008 — Revoga EXECUTE de PUBLIC nas RPCs da 006
-- ============================================================================
-- A 006 fez `REVOKE ALL ... FROM anon` nas três RPCs novas, o que não teve
-- efeito: no Postgres, um GRANT a PUBLIC vale para todos os papéis, e um
-- REVOKE de um papel específico não anula o grant de PUBLIC. O privilégio
-- efetivo é a união dos grants do papel, dos papéis que ele herda e de
-- PUBLIC. Como o Supabase concede EXECUTE a PUBLIC por padrão, `anon`
-- continuava alcançando as funções.
--
-- Confirmado pelo advisor: 3 findings de
-- `anon_security_definer_function_executable`.
--
-- Não era exploração — as três começam checando get_my_empresa_id(), que é
-- NULL sem sessão e dispara 'Não autenticado'. Mas deixava três endpoints
-- REST expostos sem motivo, e defesa em profundidade aqui custa uma linha.
--
-- Os avisos de `authenticated_security_definer_function_executable` que
-- sobram são intencionais: criar_venda, cancelar_venda, fechar_caixa e
-- registrar_pagamento_dinheiro existem para serem chamadas pelo app, e
-- get_my_empresa_id/is_admin precisam de EXECUTE para `authenticated`
-- porque são referenciadas dentro das expressões das policies de RLS —
-- revogá-las quebraria o acesso a todas as tabelas.
-- ============================================================================

REVOKE ALL ON FUNCTION registrar_pagamento_dinheiro(UUID, DECIMAL) FROM PUBLIC;
REVOKE ALL ON FUNCTION cancelar_venda(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION fechar_caixa(UUID, DECIMAL, TEXT) FROM PUBLIC;

-- O REVOKE de PUBLIC remove o privilégio de todos, inclusive de
-- authenticated: reconcede explicitamente a quem deve ter.
GRANT EXECUTE ON FUNCTION registrar_pagamento_dinheiro(UUID, DECIMAL) TO authenticated;
GRANT EXECUTE ON FUNCTION cancelar_venda(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION fechar_caixa(UUID, DECIMAL, TEXT) TO authenticated;
