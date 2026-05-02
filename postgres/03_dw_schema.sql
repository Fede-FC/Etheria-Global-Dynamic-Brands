-- =============================================================
--  DATA WAREHOUSE — Esquema Estrella v2
--  Base de datos: etheria_global_db
--  Descripción: Esquema para análisis integral con Metabase
-- =============================================================

\c etheria_global_db;

-- -------------------------------------------------------------
-- Crear schema analytics si no existe
-- -------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS analytics;

-- =============================================================
-- DIM: Tiempo (dim_fecha)
-- =============================================================
CREATE TABLE IF NOT EXISTS analytics.dim_fecha (
    date_key            INT PRIMARY KEY,  -- YYYYMMDD
    full_date           DATE NOT NULL UNIQUE,
    year                INT NOT NULL,
    quarter             INT NOT NULL,
    month               INT NOT NULL,
    month_name          VARCHAR(20),
    week                INT NOT NULL,
    day                 INT NOT NULL,
    day_of_week         VARCHAR(10),
    day_of_week_num     INT,
    is_weekend          BOOLEAN,
    is_month_end        BOOLEAN,
    semester            INT
);

-- =============================================================
-- DIM: Categoría
-- =============================================================
CREATE TABLE IF NOT EXISTS analytics.dim_category (
    category_key        SERIAL PRIMARY KEY,
    category_id         INT NOT NULL UNIQUE,
    category_name       VARCHAR(100),
    description         VARCHAR(300)
);

-- =============================================================
-- DIM: Producto
-- =============================================================
CREATE TABLE IF NOT EXISTS analytics.dim_product (
    product_key         SERIAL PRIMARY KEY,
    product_id          INT NOT NULL UNIQUE,
    product_name        VARCHAR(150),
    category_id         INT,
    category_name       VARCHAR(100),
    unit_code           VARCHAR(10),
    unit_weight_kg      DECIMAL(10,4),
    origin_country_id   INT,
    enabled             BOOLEAN
);

-- =============================================================
-- DIM: País
-- =============================================================
CREATE TABLE IF NOT EXISTS analytics.dim_country (
    country_key         SERIAL PRIMARY KEY,
    country_id          INT NOT NULL UNIQUE,
    country_name        VARCHAR(100),
    iso_code            CHAR(3),
    region              VARCHAR(100)
);

-- =============================================================
-- DIM: Marca (Dynamic Brands)
-- =============================================================
CREATE TABLE IF NOT EXISTS analytics.dim_brand (
    brand_key           SERIAL PRIMARY KEY,
    brand_id            INT NOT NULL UNIQUE,
    brand_name          VARCHAR(150),
    focus               VARCHAR(100),
    ai_model            VARCHAR(50),
    description         TEXT
);

-- =============================================================
-- DIM: Website (Dynamic Brands)
-- =============================================================
CREATE TABLE IF NOT EXISTS analytics.dim_website (
    website_key         SERIAL PRIMARY KEY,
    website_id          INT NOT NULL UNIQUE,
    website_url         VARCHAR(500),
    brand_id            INT,
    country_id          INT,
    marketing_focus     VARCHAR(200)
);

-- =============================================================
-- DIM: Moneda
-- =============================================================
CREATE TABLE IF NOT EXISTS analytics.dim_currency (
    currency_key        SERIAL PRIMARY KEY,
    currency_id         INT NOT NULL UNIQUE,
    currency_code       CHAR(3),
    currency_name       VARCHAR(80),
    currency_symbol     VARCHAR(5),
    is_base             BOOLEAN
);

-- =============================================================
-- DIM: Proveedor
-- =============================================================
CREATE TABLE IF NOT EXISTS analytics.dim_supplier (
    supplier_key        SERIAL PRIMARY KEY,
    supplier_id         INT NOT NULL UNIQUE,
    supplier_name       VARCHAR(150),
    country_id          INT,
    country_name        VARCHAR(100)
);

-- =============================================================
-- FACT: Ventas (dw_fact_sales)
-- =============================================================
CREATE TABLE IF NOT EXISTS analytics.dw_fact_sales (
    sale_id             SERIAL PRIMARY KEY,
    order_id            INT NOT NULL,
    product_id          INT NOT NULL,
    brand_id            INT,
    website_id          INT,
    country_id          INT,
    category_id         INT,
    date_key            INT,
    quantity            INT,
    unit_price          NUMERIC(14,4),
    total_amount        NUMERIC(16,4),
    shipping_cost       NUMERIC(12,4),
    import_cost         NUMERIC(12,4),
    logistics_cost      NUMERIC(12,4),
    tariff_cost         NUMERIC(12,4),
    permit_cost         NUMERIC(12,4),
    total_cost          NUMERIC(16,4),
    revenue             NUMERIC(16,4),
    profit              NUMERIC(16,4),
    margin_percent      NUMERIC(10,4),
    currency_code       VARCHAR(3),
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================
-- FACT: Inventario (dw_fact_inventory)
-- =============================================================
CREATE TABLE IF NOT EXISTS analytics.dw_fact_inventory (
    inventory_id        SERIAL PRIMARY KEY,
    product_id          INT NOT NULL,
    warehouse_id        INT,
    category_id         INT,
    date_key            INT,
    movement_type       VARCHAR(20),
    quantity            DECIMAL(12,3),
    unit_cost           NUMERIC(14,4),
    total_cost          NUMERIC(16,4),
    currency_code       VARCHAR(3),
    reference_type      VARCHAR(30),
    reference_id        INT,
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================
-- FACT: Compras/Importaciones (dw_fact_purchases)
-- =============================================================
CREATE TABLE IF NOT EXISTS analytics.dw_fact_purchases (
    purchase_id         SERIAL PRIMARY KEY,
    import_id           INT,
    supplier_id         INT,
    product_id          INT,
    category_id         INT,
    date_key            INT,
    quantity            DECIMAL(12,3),
    unit_cost           NUMERIC(14,4),
    subtotal            NUMERIC(16,4),
    freight_cost        NUMERIC(12,4),
    insurance_cost      NUMERIC(12,4),
    port_cost           NUMERIC(12,4),
    currency_code       VARCHAR(3),
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================
-- RESUMEN: Rentabilidad (etl_profitability_summary)
-- =============================================================
CREATE TABLE IF NOT EXISTS analytics.etl_profitability_summary (
    summary_id          BIGSERIAL PRIMARY KEY,
    category_name       VARCHAR(100),
    brand_name          VARCHAR(150),
    site_url            VARCHAR(500),
    sale_country        VARCHAR(100),
    sale_currency_code  CHAR(3),
    base_currency_code  CHAR(3),
    total_orders        INT NOT NULL DEFAULT 0,
    total_units_sold    DECIMAL(14,3) NOT NULL DEFAULT 0,
    revenue_local       DECIMAL(18,4) NOT NULL DEFAULT 0,
    revenue_base        DECIMAL(18,4) NOT NULL DEFAULT 0,
    cost_product        DECIMAL(18,4) NOT NULL DEFAULT 0,
    cost_logistics      DECIMAL(18,4) NOT NULL DEFAULT 0,
    cost_tariffs        DECIMAL(18,4) NOT NULL DEFAULT 0,
    cost_permits        DECIMAL(18,4) NOT NULL DEFAULT 0,
    cost_shipping       DECIMAL(18,4) NOT NULL DEFAULT 0,
    cost_total          DECIMAL(18,4) NOT NULL DEFAULT 0,
    gross_margin        DECIMAL(18,4) NOT NULL DEFAULT 0,
    gross_margin_pct    DECIMAL(8,4),
    roi_pct             DECIMAL(8,4),
    etl_run_at          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    etl_period_from     DATE,
    etl_period_to       DATE
);

-- =============================================================
-- VISTA UNIFICADA: Ventas completas para Metabase
-- =============================================================
CREATE OR REPLACE VIEW analytics.vw_sales_full AS
SELECT
    f.sale_id,
    f.order_id,
    p.product_name,
    c.category_name,
    b.brand_name,
    w.website_url,
    co.country_name,
    co.iso_code,
    d.year,
    d.month,
    d.month_name,
    d.quarter,
    f.quantity,
    f.unit_price,
    f.total_amount,
    f.shipping_cost,
    f.import_cost,
    f.logistics_cost,
    f.tariff_cost,
    f.permit_cost,
    f.total_cost,
    f.revenue,
    f.profit,
    f.margin_percent,
    f.currency_code
FROM analytics.dw_fact_sales f
LEFT JOIN analytics.dim_product p ON f.product_id = p.product_id
LEFT JOIN analytics.dim_brand b ON f.brand_id = b.brand_id
LEFT JOIN analytics.dim_country co ON f.country_id = co.country_id
LEFT JOIN analytics.dim_category c ON f.category_id = c.category_id
LEFT JOIN analytics.dim_fecha d ON f.date_key = d.date_key
LEFT JOIN analytics.dim_website w ON f.website_id = w.website_id;

-- =============================================================
-- VISTA: Rentabilidad por marca y país
-- =============================================================
CREATE OR REPLACE VIEW analytics.vw_profitability_by_brand AS
SELECT
    brand_name,
    sale_country,
    sale_currency_code,
    SUM(total_orders) AS total_orders,
    SUM(total_units_sold) AS total_units_sold,
    SUM(revenue_base) AS total_revenue_base,
    SUM(cost_total) AS total_cost,
    SUM(gross_margin) AS total_margin,
    ROUND(AVG(gross_margin_pct), 2) AS avg_margin_pct,
    ROUND(AVG(roi_pct), 2) AS avg_roi_pct
FROM analytics.etl_profitability_summary
GROUP BY brand_name, sale_country, sale_currency_code;

-- =============================================================
-- VISTA: Rentabilidad por categoría
-- =============================================================
CREATE OR REPLACE VIEW analytics.vw_profitability_by_category AS
SELECT
    category_name,
    COUNT(DISTINCT brand_name) AS brands_count,
    SUM(total_orders) AS total_orders,
    SUM(revenue_base) AS total_revenue,
    SUM(cost_total) AS total_cost,
    SUM(gross_margin) AS total_margin,
    ROUND(AVG(gross_margin_pct), 2) AS avg_margin_pct
FROM analytics.etl_profitability_summary
GROUP BY category_name;

-- =============================================================
-- VISTA: Inventario actual por producto
-- =============================================================
CREATE OR REPLACE VIEW analytics.vw_current_inventory AS
SELECT
    p.product_name,
    c.category_name,
    COALESCE(SUM(CASE WHEN f.movement_type IN ('ENTRY','IN') THEN f.quantity ELSE 0 END), 0) -
    COALESCE(SUM(CASE WHEN f.movement_type IN ('DISPATCH','OUT') THEN ABS(f.quantity) ELSE 0 END), 0) AS stock_available,
    AVG(f.unit_cost) AS avg_unit_cost
FROM analytics.dw_fact_inventory f
JOIN analytics.dim_product p ON f.product_id = p.product_id
LEFT JOIN analytics.dim_category c ON f.category_id = c.category_id
GROUP BY p.product_name, c.category_name;

-- =============================================================
-- Índices para performance
-- =============================================================
CREATE INDEX IF NOT EXISTS idx_fact_sales_date ON analytics.dw_fact_sales(date_key);
CREATE INDEX IF NOT EXISTS idx_fact_sales_product ON analytics.dw_fact_sales(product_id);
CREATE INDEX IF NOT EXISTS idx_fact_sales_brand ON analytics.dw_fact_sales(brand_id);
CREATE INDEX IF NOT EXISTS idx_fact_sales_country ON analytics.dw_fact_sales(country_id);
CREATE INDEX IF NOT EXISTS idx_fact_sales_category ON analytics.dw_fact_sales(category_id);
CREATE INDEX IF NOT EXISTS idx_fact_inventory_date ON analytics.dw_fact_inventory(date_key);
CREATE INDEX IF NOT EXISTS idx_fact_inventory_product ON analytics.dw_fact_inventory(product_id);
CREATE INDEX IF NOT EXISTS idx_fact_purchases_date ON analytics.dw_fact_purchases(date_key);
CREATE INDEX IF NOT EXISTS idx_fact_purchases_supplier ON analytics.dw_fact_purchases(supplier_id);
CREATE INDEX IF NOT EXISTS idx_fecha_full_date ON analytics.dim_fecha(full_date);
CREATE INDEX IF NOT EXISTS idx_profit_category ON analytics.etl_profitability_summary(category_name);
CREATE INDEX IF NOT EXISTS idx_profit_brand ON analytics.etl_profitability_summary(brand_name);
CREATE INDEX IF NOT EXISTS idx_profit_country ON analytics.etl_profitability_summary(sale_country);
