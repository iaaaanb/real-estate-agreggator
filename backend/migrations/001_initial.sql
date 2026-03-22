CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ============================================================
-- Propiedades
-- ============================================================
CREATE TABLE properties (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    canonical_id    UUID,

    -- Origen
    source          VARCHAR(20) NOT NULL,
    source_id       VARCHAR(100) NOT NULL,
    source_url      TEXT NOT NULL,

    -- Datos principales
    title           TEXT NOT NULL,
    description     TEXT,
    property_type   VARCHAR(20) NOT NULL,
    operation       VARCHAR(10) NOT NULL,
    price_uf        DECIMAL(12,2),
    price_clp       BIGINT,
    currency        VARCHAR(3) DEFAULT 'UF',

    -- Dimensiones
    area_built      DECIMAL(8,2),
    area_total      DECIMAL(8,2),
    bedrooms        SMALLINT,
    bathrooms       SMALLINT,
    parking         SMALLINT,

    -- Ubicación
    comuna          VARCHAR(60),
    address         TEXT,
    neighborhood    VARCHAR(100),
    location        GEOMETRY(Point, 4326),

    -- Imágenes
    thumbnail_url   TEXT,
    image_urls      TEXT[],

    -- Métricas calculadas
    price_per_m2    DECIMAL(10,2),
    days_on_market  INTEGER GENERATED ALWAYS AS (
        EXTRACT(DAY FROM (NOW() - first_seen))::INTEGER
    ) STORED,

    -- Timestamps y estado
    first_seen      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_seen       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_changed    TIMESTAMPTZ,
    content_hash    VARCHAR(64),
    status          VARCHAR(10) NOT NULL DEFAULT 'active',

    CONSTRAINT uq_source_item UNIQUE (source, source_id),
    CONSTRAINT chk_status CHECK (status IN ('active', 'paused', 'removed')),
    CONSTRAINT chk_operation CHECK (operation IN ('sale', 'rent')),
    CONSTRAINT chk_property_type CHECK (property_type IN (
        'apartment', 'house', 'land', 'office', 'commercial', 'parking', 'other'
    ))
);

-- Índices de búsqueda
CREATE INDEX idx_prop_location     ON properties USING GIST (location);
CREATE INDEX idx_prop_search       ON properties (status, operation, property_type, comuna);
CREATE INDEX idx_prop_price        ON properties (price_uf) WHERE status = 'active';
CREATE INDEX idx_prop_canonical    ON properties (canonical_id) WHERE canonical_id IS NOT NULL;
CREATE INDEX idx_prop_source       ON properties (source, source_id);
CREATE INDEX idx_prop_first_seen   ON properties (first_seen DESC);
CREATE INDEX idx_prop_address_trgm ON properties USING GIN (address gin_trgm_ops);

-- ============================================================
-- Historial de precios
-- ============================================================
CREATE TABLE price_history (
    id          BIGSERIAL PRIMARY KEY,
    property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    price_uf    DECIMAL(12,2),
    price_clp   BIGINT,
    detected_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ph_property ON price_history (property_id, detected_at DESC);

-- ============================================================
-- Alertas
-- ============================================================
CREATE TABLE alerts (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email       VARCHAR(255) NOT NULL,
    alert_type  VARCHAR(20) NOT NULL,
    filters     JSONB NOT NULL DEFAULT '{}',
    geometry    GEOMETRY(Polygon, 4326),
    property_id UUID REFERENCES properties(id) ON DELETE CASCADE,
    active      BOOLEAN NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_alert_type CHECK (alert_type IN ('price_drop', 'new_listing'))
);

CREATE INDEX idx_alerts_active ON alerts (active, alert_type);

-- ============================================================
-- Vista materializada: stats por zona
-- ============================================================
CREATE MATERIALIZED VIEW zone_stats AS
SELECT
    comuna,
    property_type,
    operation,
    COUNT(*)                                                    AS total_listings,
    ROUND(AVG(price_per_m2)::NUMERIC, 1)                       AS avg_price_m2,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price_per_m2)::NUMERIC, 1) AS median_price_m2,
    ROUND(AVG(EXTRACT(DAY FROM (NOW() - first_seen)))::NUMERIC, 0)  AS avg_days_on_market
FROM properties
WHERE status = 'active'
  AND price_per_m2 IS NOT NULL
  AND price_per_m2 > 0
GROUP BY comuna, property_type, operation;

CREATE UNIQUE INDEX idx_zs_key ON zone_stats (comuna, property_type, operation);
