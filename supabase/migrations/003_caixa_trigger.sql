-- CANMOS-SHOP: Add missing updated_at trigger on caixa table
-- Migration 003: caixa trigger

-- A tabela caixa foi criada sem updated_at (001), então o trigger abaixo
-- falharia em runtime ("record new has no field updated_at") em todo
-- fechamento de caixa. A coluna precisa existir antes do trigger.
ALTER TABLE caixa ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

CREATE TRIGGER update_caixa_updated_at
  BEFORE UPDATE ON caixa FOR EACH ROW EXECUTE FUNCTION update_updated_at();
