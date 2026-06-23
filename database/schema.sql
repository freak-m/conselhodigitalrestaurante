-- =============================================================
-- SISTEMA DE GESTÃO PARA RESTAURANTES
-- Script SQL para Supabase (PostgreSQL)
-- FASE 1: Esquema completo + Políticas de Segurança (RLS)
-- =============================================================

-- Habilita a extensão UUID para geração de IDs
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =============================================================
-- TABELA: categorias
-- Agrupa os produtos do cardápio (ex: Entradas, Bebidas)
-- =============================================================
CREATE TABLE IF NOT EXISTS public.categorias (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nome        TEXT NOT NULL,
    descricao   TEXT,
    ordem       INTEGER NOT NULL DEFAULT 0,  -- controla a ordem de exibição no cardápio
    ativo       BOOLEAN NOT NULL DEFAULT TRUE,
    criado_em   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.categorias IS 'Categorias do cardápio (Entradas, Pratos Principais, Bebidas, etc.)';

-- =============================================================
-- TABELA: produtos
-- Itens do cardápio pertencentes a uma categoria
-- =============================================================
CREATE TABLE IF NOT EXISTS public.produtos (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    categoria_id    UUID NOT NULL REFERENCES public.categorias(id) ON DELETE RESTRICT,
    nome            TEXT NOT NULL,
    descricao       TEXT,
    preco           NUMERIC(10, 2) NOT NULL CHECK (preco >= 0),
    foto_url        TEXT,            -- URL do Supabase Storage
    ativo           BOOLEAN NOT NULL DEFAULT TRUE,
    destaque        BOOLEAN NOT NULL DEFAULT FALSE,  -- marca como prato em destaque na landing page
    criado_em       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    atualizado_em   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.produtos IS 'Pratos e bebidas do cardápio com preço e foto.';

CREATE INDEX IF NOT EXISTS idx_produtos_categoria ON public.produtos(categoria_id);
CREATE INDEX IF NOT EXISTS idx_produtos_ativo ON public.produtos(ativo);

-- Trigger para manter atualizado_em sempre sincronizado
CREATE OR REPLACE FUNCTION public.set_atualizado_em()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.atualizado_em = NOW();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_produtos_atualizado_em
    BEFORE UPDATE ON public.produtos
    FOR EACH ROW EXECUTE FUNCTION public.set_atualizado_em();

-- =============================================================
-- TABELA: mesas
-- Representa cada mesa física do salão
-- =============================================================
CREATE TABLE IF NOT EXISTS public.mesas (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    numero      INTEGER NOT NULL UNIQUE,       -- número visível ao cliente (Mesa 1, Mesa 2...)
    capacidade  INTEGER NOT NULL DEFAULT 4,
    pos_x       NUMERIC(5,2) NOT NULL DEFAULT 0,  -- posição X no mapa visual (percentual)
    pos_y       NUMERIC(5,2) NOT NULL DEFAULT 0,  -- posição Y no mapa visual (percentual)
    status      TEXT NOT NULL DEFAULT 'livre'
                    CHECK (status IN ('livre', 'reservada', 'ocupada')),
    ativo       BOOLEAN NOT NULL DEFAULT TRUE,
    criado_em   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.mesas IS 'Mesas do salão com posição no mapa e status em tempo real.';

-- =============================================================
-- TABELA: pedidos
-- Pedidos de delivery feitos pelo cliente no front-end público
-- =============================================================
CREATE TABLE IF NOT EXISTS public.pedidos (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    numero_pedido       SERIAL,              -- número legível exibido ao cliente (ex: #0042)
    nome_cliente        TEXT NOT NULL,
    telefone            TEXT NOT NULL,
    endereco_entrega    TEXT NOT NULL,
    observacoes         TEXT,
    forma_pagamento     TEXT NOT NULL
                            CHECK (forma_pagamento IN ('mbway', 'dinheiro', 'tpa')),
    subtotal            NUMERIC(10, 2) NOT NULL CHECK (subtotal >= 0),
    taxa_entrega        NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (taxa_entrega >= 0),
    total               NUMERIC(10, 2) NOT NULL CHECK (total >= 0),
    status              TEXT NOT NULL DEFAULT 'pendente'
                            CHECK (status IN ('pendente', 'aceite', 'em_preparo', 'saiu_entrega', 'entregue', 'cancelado')),
    criado_em           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    atualizado_em       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.pedidos IS 'Pedidos de delivery com status rastreável em tempo real pelo cliente.';

CREATE INDEX IF NOT EXISTS idx_pedidos_status ON public.pedidos(status);
CREATE INDEX IF NOT EXISTS idx_pedidos_criado_em ON public.pedidos(criado_em DESC);

CREATE TRIGGER trg_pedidos_atualizado_em
    BEFORE UPDATE ON public.pedidos
    FOR EACH ROW EXECUTE FUNCTION public.set_atualizado_em();

-- =============================================================
-- TABELA: itens_pedido
-- Produtos associados a um pedido de delivery
-- =============================================================
CREATE TABLE IF NOT EXISTS public.itens_pedido (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pedido_id   UUID NOT NULL REFERENCES public.pedidos(id) ON DELETE CASCADE,
    produto_id  UUID NOT NULL REFERENCES public.produtos(id) ON DELETE RESTRICT,
    quantidade  INTEGER NOT NULL CHECK (quantidade > 0),
    preco_unit  NUMERIC(10, 2) NOT NULL CHECK (preco_unit >= 0),  -- preço travado no momento do pedido
    subtotal    NUMERIC(10, 2) GENERATED ALWAYS AS (quantidade * preco_unit) STORED,
    observacao  TEXT          -- pedido especial do cliente para aquele item
);

COMMENT ON TABLE public.itens_pedido IS 'Itens individuais de cada pedido de delivery.';

CREATE INDEX IF NOT EXISTS idx_itens_pedido_pedido ON public.itens_pedido(pedido_id);

-- =============================================================
-- TABELA: reservas
-- Reservas de mesa solicitadas pelo cliente
-- =============================================================
CREATE TABLE IF NOT EXISTS public.reservas (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    mesa_id         UUID NOT NULL REFERENCES public.mesas(id) ON DELETE RESTRICT,
    nome_cliente    TEXT NOT NULL,
    telefone        TEXT NOT NULL,
    data_reserva    DATE NOT NULL,
    hora_reserva    TIME NOT NULL,
    num_pessoas     INTEGER NOT NULL CHECK (num_pessoas > 0),
    observacoes     TEXT,
    status          TEXT NOT NULL DEFAULT 'pendente'
                        CHECK (status IN ('pendente', 'confirmada', 'cancelada', 'concluida')),
    criado_em       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.reservas IS 'Reservas de mesa com data, horário e status de confirmação pelo restaurante.';

CREATE INDEX IF NOT EXISTS idx_reservas_mesa ON public.reservas(mesa_id);
CREATE INDEX IF NOT EXISTS idx_reservas_data ON public.reservas(data_reserva);
CREATE INDEX IF NOT EXISTS idx_reservas_status ON public.reservas(status);

-- =============================================================
-- TABELA: comandas
-- Conta/tab aberta de uma mesa no salão (consumo presencial)
-- =============================================================
CREATE TABLE IF NOT EXISTS public.comandas (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    mesa_id     UUID NOT NULL REFERENCES public.mesas(id) ON DELETE RESTRICT,
    aberta_em   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    fechada_em  TIMESTAMPTZ,                  -- NULL enquanto a conta está em aberto
    total       NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (total >= 0),
    status      TEXT NOT NULL DEFAULT 'aberta'
                    CHECK (status IN ('aberta', 'fechada', 'cancelada')),
    observacoes TEXT
);

COMMENT ON TABLE public.comandas IS 'Conta corrente de uma mesa ocupada; acumula os itens_comanda lançados pelos garçons.';

CREATE INDEX IF NOT EXISTS idx_comandas_mesa ON public.comandas(mesa_id);
CREATE INDEX IF NOT EXISTS idx_comandas_status ON public.comandas(status);

-- =============================================================
-- TABELA: itens_comanda
-- Produtos lançados na comanda de uma mesa pelo garçom
-- =============================================================
CREATE TABLE IF NOT EXISTS public.itens_comanda (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    comanda_id  UUID NOT NULL REFERENCES public.comandas(id) ON DELETE CASCADE,
    produto_id  UUID NOT NULL REFERENCES public.produtos(id) ON DELETE RESTRICT,
    quantidade  INTEGER NOT NULL CHECK (quantidade > 0),
    preco_unit  NUMERIC(10, 2) NOT NULL CHECK (preco_unit >= 0),  -- preço travado no momento do lançamento
    subtotal    NUMERIC(10, 2) GENERATED ALWAYS AS (quantidade * preco_unit) STORED,
    observacao  TEXT,
    lancado_em  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.itens_comanda IS 'Itens individuais lançados numa comanda de mesa pelo garçom.';

CREATE INDEX IF NOT EXISTS idx_itens_comanda_comanda ON public.itens_comanda(comanda_id);

-- =============================================================
-- TRIGGER: atualiza total da comanda automaticamente
-- Mantém comandas.total sincronizado sempre que um item é
-- inserido, atualizado ou removido
-- =============================================================
CREATE OR REPLACE FUNCTION public.recalcular_total_comanda()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_comanda_id UUID;
BEGIN
    v_comanda_id := COALESCE(NEW.comanda_id, OLD.comanda_id);
    UPDATE public.comandas
       SET total = (
               SELECT COALESCE(SUM(subtotal), 0)
                 FROM public.itens_comanda
                WHERE comanda_id = v_comanda_id
           )
     WHERE id = v_comanda_id;
    RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE TRIGGER trg_itens_comanda_total
    AFTER INSERT OR UPDATE OR DELETE ON public.itens_comanda
    FOR EACH ROW EXECUTE FUNCTION public.recalcular_total_comanda();

-- =============================================================
-- TRIGGER: atualiza status da mesa quando comanda é aberta/fechada
-- =============================================================
CREATE OR REPLACE FUNCTION public.sincronizar_status_mesa()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF (TG_OP = 'INSERT' AND NEW.status = 'aberta') THEN
        UPDATE public.mesas SET status = 'ocupada' WHERE id = NEW.mesa_id;
    ELSIF (NEW.status IN ('fechada', 'cancelada')) THEN
        -- só libera se não houver outra comanda aberta para a mesma mesa
        IF NOT EXISTS (
            SELECT 1 FROM public.comandas
             WHERE mesa_id = NEW.mesa_id AND status = 'aberta' AND id <> NEW.id
        ) THEN
            UPDATE public.mesas SET status = 'livre' WHERE id = NEW.mesa_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_comanda_status_mesa
    AFTER INSERT OR UPDATE OF status ON public.comandas
    FOR EACH ROW EXECUTE FUNCTION public.sincronizar_status_mesa();

-- =============================================================
-- ROW LEVEL SECURITY (RLS)
-- =============================================================

-- Habilita RLS em todas as tabelas
ALTER TABLE public.categorias    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.produtos       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mesas          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pedidos        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.itens_pedido   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reservas       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comandas       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.itens_comanda  ENABLE ROW LEVEL SECURITY;

-- -------------------------------------------------------------
-- CATEGORIAS: leitura pública; escrita apenas para autenticados (admin)
-- -------------------------------------------------------------
CREATE POLICY "categorias_leitura_publica"
    ON public.categorias FOR SELECT
    USING (ativo = TRUE);

CREATE POLICY "categorias_admin_total"
    ON public.categorias FOR ALL
    TO authenticated
    USING (TRUE)
    WITH CHECK (TRUE);

-- -------------------------------------------------------------
-- PRODUTOS: leitura pública dos ativos; escrita apenas admin
-- -------------------------------------------------------------
CREATE POLICY "produtos_leitura_publica"
    ON public.produtos FOR SELECT
    USING (ativo = TRUE);

CREATE POLICY "produtos_admin_total"
    ON public.produtos FOR ALL
    TO authenticated
    USING (TRUE)
    WITH CHECK (TRUE);

-- -------------------------------------------------------------
-- MESAS: leitura pública (mapa de mesas visível ao cliente);
--        escrita apenas para autenticados (admin/garçom)
-- -------------------------------------------------------------
CREATE POLICY "mesas_leitura_publica"
    ON public.mesas FOR SELECT
    USING (ativo = TRUE);

CREATE POLICY "mesas_staff_escrita"
    ON public.mesas FOR ALL
    TO authenticated
    USING (TRUE)
    WITH CHECK (TRUE);

-- -------------------------------------------------------------
-- PEDIDOS: o cliente pode inserir e consultar o próprio pedido
--          (identificado pelo ID na URL); admin vê tudo
-- -------------------------------------------------------------
CREATE POLICY "pedidos_insercao_publica"
    ON public.pedidos FOR INSERT
    WITH CHECK (TRUE);

CREATE POLICY "pedidos_leitura_proprio"
    ON public.pedidos FOR SELECT
    USING (TRUE);  -- filtro por ID feito na query do cliente; ajuste com auth.uid() se adicionar login do cliente

CREATE POLICY "pedidos_admin_total"
    ON public.pedidos FOR ALL
    TO authenticated
    USING (TRUE)
    WITH CHECK (TRUE);

-- -------------------------------------------------------------
-- ITENS_PEDIDO: acompanha as permissões de pedidos
-- -------------------------------------------------------------
CREATE POLICY "itens_pedido_insercao_publica"
    ON public.itens_pedido FOR INSERT
    WITH CHECK (TRUE);

CREATE POLICY "itens_pedido_leitura_publica"
    ON public.itens_pedido FOR SELECT
    USING (TRUE);

CREATE POLICY "itens_pedido_admin_total"
    ON public.itens_pedido FOR ALL
    TO authenticated
    USING (TRUE)
    WITH CHECK (TRUE);

-- -------------------------------------------------------------
-- RESERVAS: cliente pode inserir e consultar a própria reserva;
--           admin/staff gerencia tudo
-- -------------------------------------------------------------
CREATE POLICY "reservas_insercao_publica"
    ON public.reservas FOR INSERT
    WITH CHECK (TRUE);

CREATE POLICY "reservas_leitura_publica"
    ON public.reservas FOR SELECT
    USING (TRUE);

CREATE POLICY "reservas_admin_total"
    ON public.reservas FOR ALL
    TO authenticated
    USING (TRUE)
    WITH CHECK (TRUE);

-- -------------------------------------------------------------
-- COMANDAS e ITENS_COMANDA: apenas staff autenticado
-- -------------------------------------------------------------
CREATE POLICY "comandas_staff_total"
    ON public.comandas FOR ALL
    TO authenticated
    USING (TRUE)
    WITH CHECK (TRUE);

CREATE POLICY "itens_comanda_staff_total"
    ON public.itens_comanda FOR ALL
    TO authenticated
    USING (TRUE)
    WITH CHECK (TRUE);

-- =============================================================
-- REALTIME
-- Habilita publicação em tempo real para as tabelas que
-- o cliente e o staff precisam monitorar ao vivo
-- =============================================================
ALTER PUBLICATION supabase_realtime ADD TABLE public.pedidos;
ALTER PUBLICATION supabase_realtime ADD TABLE public.mesas;
ALTER PUBLICATION supabase_realtime ADD TABLE public.reservas;
ALTER PUBLICATION supabase_realtime ADD TABLE public.comandas;

-- =============================================================
-- DADOS INICIAIS DE EXEMPLO (seed)
-- Execute apenas em ambiente de desenvolvimento/teste
-- =============================================================

-- Categorias de exemplo
INSERT INTO public.categorias (nome, descricao, ordem) VALUES
    ('Entradas',         'Petiscos e aperitivos para começar bem',  1),
    ('Pratos Principais','O melhor da nossa cozinha',               2),
    ('Sobremesas',       'Para adoçar o fim da refeição',           3),
    ('Bebidas',          'Sumos, refrigerantes e cervejas',         4)
ON CONFLICT DO NOTHING;

-- Mesas de exemplo (layout 4x3 no mapa, posições em %)
INSERT INTO public.mesas (numero, capacidade, pos_x, pos_y) VALUES
    (1,  4, 10, 15),
    (2,  4, 30, 15),
    (3,  4, 50, 15),
    (4,  4, 70, 15),
    (5,  2, 10, 45),
    (6,  2, 30, 45),
    (7,  6, 55, 45),
    (8,  4, 10, 75),
    (9,  4, 30, 75),
    (10, 8, 60, 75)
ON CONFLICT (numero) DO NOTHING;
