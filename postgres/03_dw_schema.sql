-- =============================================================
--  DATA WAREHOUSE — Esquema Estrella
--  Base de datos: etheria_global_db
--  Descripción: Esquema para análisis integral con Metabase
-- =============================================================

\c etheria_global_db;

-- -------------------------------------------------------------
-- Crear schema analytics si no existe
-- -------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS analytics;

-- =============================================================
-- TABLA DE HECHOS: dw_fact_sales
-- =============================================================
CREATE TABLE IF NOT EXISTS analytics.dw_fact_sales (
    sale_id              SERIAL PRIMARY KEY,
    order_id             INT NOT NULL,
    product_id           INT NOT NULL,
    brand_id             INT,
    website_id           INT,
    country_id           INT,
    category_id          INT,
    date_key             INT,
    quantity             INT,
    unit_price           NUMERIC(10,2),
    total_amount         NUMERIC(12,2),
    shipping_cost        NUMERIC(10,2),
    import_cost          NUMERIC(10,2),
    total_cost           NUMERIC(12,2),
    revenue              NUMERIC(12,2),
    profit               NUMERIC(12,2),
    margin_percent       NUMERIC(10,2),
    currency_code        VARCHAR(3),
    created_at           TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================
-- DIMENSIONES
-- =============================================================

-- Dim Producto
CREATE TABLE IF NOT EXISTS analytics.dw_dim_product (
    product_key         SERIAL PRIMARY KEY,
    product_id          INT NOT NULL UNIQUE,
    product_name        VARCHAR(255),
    category_name       VARCHAR(100),
    unit_code           VARCHAR(10),
    enabled             BOOLEAN
);

-- Dim Marca
CREATE TABLE IF NOT EXISTS analytics.dw_dim_brand (
    brand_key           SERIAL PRIMARY KEY,
    brand_id            INT NOT NULL UNIQUE,
    brand_name          VARCHAR(255),
    description         TEXT,
    focus               VARCHAR(100),
    ai_model            VARCHAR(100),
    website_url         VARCHAR(255)
);

-- Dim País
CREATE TABLE IF NOT EXISTS analytics.dw_dim_country (
    country_key         SERIAL PRIMARY KEY,
    country_id          INT NOT NULL UNIQUE,
    country_name        VARCHAR(100),
    iso_code            CHAR(3),
    region              VARCHAR(100)
);

-- Dim Categoría
CREATE TABLE IF NOT EXISTS analytics.dw_dim_category (
    category_key        SERIAL PRIMARY KEY,
    category_id         INT NOT NULL UNIQUE,
    category_name       VARCHAR(100)
);

-- Dim Tiempo
CREATE TABLE IF NOT EXISTS analytics.dw_dim_time (
    date_key            INT PRIMARY KEY,  -- Formato YYYYMMDD
    full_date           DATE,
    year                INT,
    quarter             INT,
    month               INT,
    week                INT,
    day                 INT,
    day_of_week         VARCHAR(10),
    is_weekend          BOOLEAN
);

-- =============================================================
-- TABLAS ANALÍTICAS (vistas materializadas o agregaciones)
-- =============================================================

-- Resumen de rentabilidad (ya existente, mantener)
CREATE TABLE IF NOT EXISTS analytics.etl_profitability_summary (
    summary_id          SERIAL PRIMARY KEY,
    brand_name          VARCHAR(255),
    website_name        VARCHAR(255),
    country_name        VARCHAR(100),
    total_orders        INT,
    total_revenue       NUMERIC(12,2),
    total_cost          NUMERIC(12,2),
    total_profit        NUMERIC(12,2),
    avg_margin          NUMERIC(5,2),
    avg_delivery_days   NUMERIC(5,1),
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Crear tabla de dimensiones de website
CREATE TABLE IF NOT EXISTS analytics.dw_dim_website (
    website_key     SERIAL PRIMARY KEY,
    website_id      INT NOT NULL UNIQUE,
    website_name    VARCHAR(255),
    brand_id        INT,
    country_id      INT
);

-- Vista unificada para Metabase
CREATE OR REPLACE VIEW analytics.vw_sales_full AS
SELECT
    f.sale_id,
    f.order_id,
    p.product_name,
    c.category_name,
    b.brand_name,
    w.website_name,
    co.country_name,
    co.iso_code,
    t.year,
    t.month,
    t.quarter,
    f.quantity,
    f.unit_price,
    f.total_amount,
    f.shipping_cost,
    f.import_cost,
    f.profit,
    f.margin_percent,
    f.currency_code
FROM analytics.dw_fact_sales f
LEFT JOIN analytics.dw_dim_product p ON f.product_id = p.product_id
LEFT JOIN analytics.dw_dim_brand b ON f.brand_id = b.brand_id
LEFT JOIN analytics.dw_dim_country co ON f.country_id = co.country_id
LEFT JOIN analytics.dw_dim_category c ON f.category_id = c.category_id
LEFT JOIN analytics.dw_dim_time t ON f.date_key = t.date_key
LEFT JOIN analytics.dw_dim_website w ON f.website_id = w.website_id;

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_fact_sales_date ON analytics.dw_fact_sales(date_key);
CREATE INDEX IF NOT EXISTS idx_fact_sales_product ON analytics.dw_fact_sales(product_id);
CREATE INDEX IF NOT EXISTS idx_fact_sales_brand ON analytics.dw_fact_sales(brand_id);
CREATE INDEX IF NOT EXISTS idx_fact_sales_country ON analytics.dw_fact_sales(country_id);
