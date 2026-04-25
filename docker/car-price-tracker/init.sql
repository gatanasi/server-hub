-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- Filters: user-defined search criteria
-- ============================================================
CREATE TABLE IF NOT EXISTS filters (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    search_url  TEXT,
    brand       VARCHAR(100),
    model       VARCHAR(100),
    max_price   INTEGER,
    min_year    INTEGER,
    max_mileage INTEGER,
    sort_by     VARCHAR(50) NOT NULL DEFAULT 'price_asc',
    is_active   BOOLEAN NOT NULL DEFAULT true,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- Listings: scraped car listings
-- ============================================================
CREATE TABLE IF NOT EXISTS listings (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    external_id    VARCHAR(100) NOT NULL UNIQUE,
    filter_id      UUID REFERENCES filters(id) ON DELETE SET NULL,
    brand          VARCHAR(100),
    model          VARCHAR(200),
    title          VARCHAR(500),
    version        VARCHAR(200),
    price          INTEGER,
    original_price INTEGER,
    currency       VARCHAR(8),
    mileage        INTEGER,
    range_km       INTEGER,
    year           INTEGER,
    registration_month INTEGER,
    power_ps       INTEGER,
    power_kw       INTEGER,
    fuel_type      VARCHAR(50),
    transmission   VARCHAR(50),
    seller_name    VARCHAR(255),
    seller_location VARCHAR(255),
    seller_type    VARCHAR(50),
    description    TEXT,
    is_inspected   BOOLEAN NOT NULL DEFAULT false,
    has_warranty   BOOLEAN NOT NULL DEFAULT false,
    is_accident_free BOOLEAN NOT NULL DEFAULT false,
    url            TEXT,
    image_url      TEXT,
    first_seen_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_seen_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_listings_filter_id ON listings(filter_id);
CREATE INDEX IF NOT EXISTS idx_listings_brand ON listings(brand);
CREATE INDEX IF NOT EXISTS idx_listings_price ON listings(price);
CREATE INDEX IF NOT EXISTS idx_listings_last_seen ON listings(last_seen_at);
CREATE INDEX IF NOT EXISTS idx_listings_filter_last_seen ON listings(filter_id, last_seen_at);

-- ============================================================
-- Price History: track price changes over time
-- ============================================================
CREATE TABLE IF NOT EXISTS price_history (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    listing_id  UUID NOT NULL REFERENCES listings(id) ON DELETE CASCADE,
    price       INTEGER NOT NULL,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_price_history_listing_id ON price_history(listing_id);
CREATE INDEX IF NOT EXISTS idx_price_history_recorded_at ON price_history(recorded_at);

-- ============================================================
-- Price Snapshots: aggregate price stats per filter per scrape
-- ============================================================
CREATE TABLE IF NOT EXISTS price_snapshots (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    filter_id     UUID NOT NULL REFERENCES filters(id) ON DELETE CASCADE,
    avg_price     INTEGER NOT NULL,
    median_price  INTEGER NOT NULL,
    min_price     INTEGER NOT NULL,
    max_price     INTEGER NOT NULL,
    listing_count INTEGER NOT NULL,
    recorded_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_price_snapshots_recorded_at ON price_snapshots(recorded_at);
CREATE INDEX IF NOT EXISTS idx_price_snapshots_filter_recorded ON price_snapshots(filter_id, recorded_at);

-- ============================================================
-- Auto-update updated_at trigger
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_filters_updated_at
    BEFORE UPDATE ON filters
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_listings_updated_at
    BEFORE UPDATE ON listings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
