-- CANMOS-SHOP: Database Schema
-- Migration 001: Initial schema

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- TABLES
-- ============================================

-- EMPRESAS (companies/multi-tenant)
CREATE TABLE empresas (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nome VARCHAR(255) NOT NULL,
  cnpj VARCHAR(18) UNIQUE,
  telefone VARCHAR(20),
  email VARCHAR(255),
  endereco TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- USUARIOS (profiles linked to auth.users)
CREATE TABLE usuarios (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  nome VARCHAR(255) NOT NULL,
  email VARCHAR(255) NOT NULL UNIQUE,
  role VARCHAR(20) NOT NULL DEFAULT 'operador' CHECK (role IN ('admin', 'operador', 'gerente')),
  ativo BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- PLANOS (free/premium)
CREATE TABLE planos (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nome VARCHAR(50) NOT NULL UNIQUE,
  limite_produtos INTEGER NOT NULL,
  limite_vendas INTEGER NOT NULL,
  permite_relatorios BOOLEAN NOT NULL DEFAULT FALSE,
  permite_multi_usuario BOOLEAN NOT NULL DEFAULT FALSE,
  preco_mensal DECIMAL(10,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ASSINATURAS (empresa <> plano)
CREATE TABLE assinaturas (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  plano_id UUID NOT NULL REFERENCES planos(id) ON DELETE CASCADE,
  stripe_subscription_id VARCHAR(255),
  status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'canceled', 'past_due', 'trialing')),
  inicio_periodo TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  fim_periodo TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- CATEGORIAS
CREATE TABLE categorias (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  nome VARCHAR(100) NOT NULL,
  cor VARCHAR(7) DEFAULT '#6B7280',
  ordem INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(empresa_id, nome)
);

-- PRODUTOS
CREATE TABLE produtos (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  categoria_id UUID REFERENCES categorias(id) ON DELETE SET NULL,
  nome VARCHAR(255) NOT NULL,
  descricao TEXT,
  preco DECIMAL(10,2) NOT NULL CHECK (preco >= 0),
  codigo_barras VARCHAR(50),
  imagem_url TEXT,
  ativo BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_produtos_empresa ON produtos(empresa_id);
CREATE INDEX idx_produtos_categoria ON produtos(categoria_id);
CREATE INDEX idx_produtos_ativo ON produtos(ativo);

-- VENDAS
CREATE TABLE vendas (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  caixa_id UUID REFERENCES caixa(id),
  valor_total DECIMAL(10,2) NOT NULL CHECK (valor_total >= 0),
  desconto DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK (desconto >= 0),
  status VARCHAR(20) NOT NULL DEFAULT 'pendente' CHECK (status IN ('pendente', 'confirmada', 'cancelada')),
  observacao TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_vendas_empresa ON vendas(empresa_id);
CREATE INDEX idx_vendas_usuario ON vendas(usuario_id);
CREATE INDEX idx_vendas_data ON vendas(created_at DESC);
CREATE INDEX idx_vendas_caixa ON vendas(caixa_id);

-- ITENS_VENDA
CREATE TABLE itens_venda (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  venda_id UUID NOT NULL REFERENCES vendas(id) ON DELETE CASCADE,
  produto_id UUID NOT NULL REFERENCES produtos(id) ON DELETE CASCADE,
  quantidade INTEGER NOT NULL CHECK (quantidade > 0),
  preco_unitario DECIMAL(10,2) NOT NULL CHECK (preco_unitario >= 0),
  subtotal DECIMAL(10,2) NOT NULL CHECK (subtotal >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_itens_venda ON itens_venda(venda_id);
CREATE INDEX idx_itens_produto ON itens_venda(produto_id);

-- PAGAMENTOS
CREATE TABLE pagamentos (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  venda_id UUID NOT NULL REFERENCES vendas(id) ON DELETE CASCADE,
  forma_pagamento VARCHAR(20) NOT NULL CHECK (forma_pagamento IN ('cartao_credito', 'cartao_debito', 'pix', 'dinheiro')),
  valor DECIMAL(10,2) NOT NULL CHECK (valor > 0),
  status VARCHAR(20) NOT NULL DEFAULT 'pendente' CHECK (status IN ('pendente', 'aprovado', 'recusado', 'cancelado', 'estornado')),
  stripe_payment_intent_id VARCHAR(255),
  abacatepay_cobranca_id VARCHAR(255),
  pix_qr_code TEXT,
  pix_qr_code_texto VARCHAR(255),
  comprovante_url TEXT,
  processado_em TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_pagamentos_venda ON pagamentos(venda_id);

-- CAIXA (abertura/fechamento)
CREATE TABLE caixa (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  valor_abertura DECIMAL(10,2) NOT NULL DEFAULT 0,
  valor_fechamento DECIMAL(10,2),
  saldo_esperado DECIMAL(10,2),
  saldo_real DECIMAL(10,2),
  diferenca DECIMAL(10,2),
  observacao TEXT,
  data_abertura TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  data_fechamento TIMESTAMPTZ,
  status VARCHAR(20) NOT NULL DEFAULT 'aberto' CHECK (status IN ('aberto', 'fechado'))
);

CREATE INDEX idx_caixa_empresa ON caixa(empresa_id);
CREATE INDEX idx_caixa_usuario ON caixa(usuario_id);

-- LOGS (segurança e transações)
CREATE TABLE logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  empresa_id UUID REFERENCES empresas(id) ON DELETE CASCADE,
  usuario_id UUID REFERENCES usuarios(id) ON DELETE CASCADE,
  acao VARCHAR(50) NOT NULL,
  entidade VARCHAR(50),
  entidade_id UUID,
  detalhes JSONB,
  ip_address VARCHAR(45),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_logs_empresa ON logs(empresa_id);
CREATE INDEX idx_logs_data ON logs(created_at DESC);
CREATE INDEX idx_logs_acao ON logs(acao);

-- ============================================
-- ROW LEVEL SECURITY
-- ============================================

-- Empresas: apenas admin da empresa
ALTER TABLE empresas ENABLE ROW LEVEL SECURITY;
CREATE POLICY "usuarios veem propria empresa" ON empresas
  FOR ALL USING (id IN (
    SELECT empresa_id FROM usuarios WHERE id = auth.uid() AND role = 'admin'
  ));

-- Usuarios: veem apenas da propria empresa
ALTER TABLE usuarios ENABLE ROW LEVEL SECURITY;
CREATE POLICY "usuarios veem da propria empresa" ON usuarios
  FOR ALL USING (empresa_id IN (
    SELECT empresa_id FROM usuarios WHERE id = auth.uid()
  ));

-- Produtos: veem apenas da propria empresa
ALTER TABLE produtos ENABLE ROW LEVEL SECURITY;
CREATE POLICY "produtos por empresa" ON produtos
  FOR ALL USING (empresa_id IN (
    SELECT empresa_id FROM usuarios WHERE id = auth.uid()
  ));

-- Categorias: veem apenas da propria empresa
ALTER TABLE categorias ENABLE ROW LEVEL SECURITY;
CREATE POLICY "categorias por empresa" ON categorias
  FOR ALL USING (empresa_id IN (
    SELECT empresa_id FROM usuarios WHERE id = auth.uid()
  ));

-- Vendas: veem apenas da propria empresa
ALTER TABLE vendas ENABLE ROW LEVEL SECURITY;
CREATE POLICY "vendas por empresa" ON vendas
  FOR ALL USING (empresa_id IN (
    SELECT empresa_id FROM usuarios WHERE id = auth.uid()
  ));

-- Itens venda: via venda
ALTER TABLE itens_venda ENABLE ROW LEVEL SECURITY;
CREATE POLICY "itens_venda via venda" ON itens_venda
  FOR ALL USING (venda_id IN (
    SELECT v.id FROM vendas v
    JOIN usuarios u ON u.id = auth.uid() AND u.empresa_id = v.empresa_id
  ));

-- Pagamentos: via venda
ALTER TABLE pagamentos ENABLE ROW LEVEL SECURITY;
CREATE POLICY "pagamentos via venda" ON pagamentos
  FOR ALL USING (venda_id IN (
    SELECT v.id FROM vendas v
    JOIN usuarios u ON u.id = auth.uid() AND u.empresa_id = v.empresa_id
  ));

-- Caixa: por empresa
ALTER TABLE caixa ENABLE ROW LEVEL SECURITY;
CREATE POLICY "caixa por empresa" ON caixa
  FOR ALL USING (empresa_id IN (
    SELECT empresa_id FROM usuarios WHERE id = auth.uid()
  ));

-- Logs: apenas admin
ALTER TABLE logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "logs apenas admin" ON logs
  FOR ALL USING (empresa_id IN (
    SELECT empresa_id FROM usuarios WHERE id = auth.uid() AND role = 'admin'
  ));

-- ============================================
-- TRIGGER: AUTO-CREATE PROFILE ON SIGNUP
-- ============================================

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_empresa_id UUID;
  v_plano_free UUID;
BEGIN
  -- Create empresa
  INSERT INTO empresas (nome, email)
  VALUES (
    COALESCE(NEW.raw_user_meta_data ->> 'empresa_nome', 'Minha Empresa'),
    NEW.email
  )
  RETURNING id INTO v_empresa_id;

  -- Get free plan
  SELECT id INTO v_plano_free FROM planos WHERE nome = 'Free';
  IF NOT FOUND THEN
    INSERT INTO planos (nome, limite_produtos, limite_vendas) VALUES ('Free', 3, 5)
    RETURNING id INTO v_plano_free;
  END IF;

  -- Assign free plan
  INSERT INTO assinaturas (empresa_id, plano_id) VALUES (v_empresa_id, v_plano_free);

  -- Create user profile
  INSERT INTO usuarios (id, empresa_id, nome, email, role)
  VALUES (
    NEW.id,
    v_empresa_id,
    COALESCE(NEW.raw_user_meta_data ->> 'nome', 'Usuario'),
    NEW.email,
    'admin'
  );

  -- Log
  INSERT INTO logs (empresa_id, usuario_id, acao, entidade, detalhes)
  VALUES (v_empresa_id, NEW.id, 'usuario_criado', 'auth.users', jsonb_build_object('email', NEW.email));

  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();

-- ============================================
-- FUNCTIONS
-- ============================================

-- Check if company can create more products
CREATE OR REPLACE FUNCTION check_produto_limit()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_plano_limite INTEGER;
  v_total INTEGER;
BEGIN
  SELECT p.limite_produtos INTO v_plano_limite
  FROM assinaturas a
  JOIN planos p ON p.id = a.plano_id
  WHERE a.empresa_id = NEW.empresa_id AND a.status = 'active';

  IF v_plano_limite IS NOT NULL THEN
    SELECT COUNT(*) INTO v_total FROM produtos
    WHERE empresa_id = NEW.empresa_id AND ativo = TRUE;

    IF v_total >= v_plano_limite THEN
      RAISE EXCEPTION 'Limite de produtos atingido: %', v_plano_limite;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER check_produto_limit_trigger
  BEFORE INSERT ON produtos
  FOR EACH ROW
  EXECUTE FUNCTION check_produto_limit();

-- Check if company can create more sales
CREATE OR REPLACE FUNCTION check_venda_limit()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_plano_limite INTEGER;
  v_total INTEGER;
BEGIN
  SELECT p.limite_vendas INTO v_plano_limite
  FROM assinaturas a
  JOIN planos p ON p.id = a.plano_id
  WHERE a.empresa_id = NEW.empresa_id AND a.status = 'active';

  IF v_plano_limite IS NOT NULL THEN
    SELECT COUNT(*) INTO v_total FROM vendas
    WHERE empresa_id = NEW.empresa_id AND status = 'confirmada';

    IF v_total >= v_plano_limite THEN
      RAISE EXCEPTION 'Limite de vendas atingido: %', v_plano_limite;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER check_venda_limit_trigger
  BEFORE INSERT ON vendas
  FOR EACH ROW
  EXECUTE FUNCTION check_venda_limit();

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER update_empresas_updated_at
  BEFORE UPDATE ON empresas FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_usuarios_updated_at
  BEFORE UPDATE ON usuarios FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_produtos_updated_at
  BEFORE UPDATE ON produtos FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_vendas_updated_at
  BEFORE UPDATE ON vendas FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_assinaturas_updated_at
  BEFORE UPDATE ON assinaturas FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_pagamentos_updated_at
  BEFORE UPDATE ON pagamentos FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================
-- SEED: Default plans
-- ============================================

INSERT INTO planos (nome, limite_produtos, limite_vendas, permite_relatorios, permite_multi_usuario, preco_mensal)
VALUES
  ('Free', 3, 5, FALSE, FALSE, 0),
  ('Premium', -1, -1, TRUE, TRUE, 49.90)
ON CONFLICT (nome) DO NOTHING;
