-- =============================================================
--  METABASE DASHBOARD QUERIES — Etheria Global + Dynamic Brands
--  Base de datos: etheria_global_db (schema: analytics)
--  Preguntas gerenciales que responde:
--    1. Rentabilidad por marca y país
--    2. Margen por categoría
--    3. ROI de marcas
--    4. Costos de importación vs ventas
--    5. Inventario actual
--    6. Tendencia de ventas mensual
-- =============================================================

-- =============================================================
-- 1. RENTABILIDAD POR MARCA Y PAÍS
--    "¿Qué marca es más rentable en cada país?"
-- =============================================================
SELECT
    s.brand_name,
    s.sale_country,
    s.sale_currency_code,
    s.total_orders,
    s.total_units_sold,
    s.revenue_base,
    s.cost_total,
    s.gross_margin,
    ROUND(s.gross_margin_pct, 2) AS margin_pct,
    ROUND(s.roi_pct, 2) AS roi_pct
FROM analytics.etl_profitability_summary s
ORDER BY s.gross_margin DESC;

-- =============================================================
-- 2. MARGEN POR CATEGORÍA
--    "¿Cuál categoría tiene mayor margen de ganancia?"
-- =============================================================
SELECT
    category_name,
    COUNT(DISTINCT brand_name) AS marcas,
    SUM(total_orders) AS ordenes,
    SUM(total_units_sold) AS unidades,
    ROUND(SUM(revenue_base), 2) AS ingresos_base,
    ROUND(SUM(cost_total), 2) AS costos,
    ROUND(SUM(gross_margin), 2) AS margen,
    ROUND(AVG(gross_margin_pct), 2) AS margen_promedio_pct
FROM analytics.etl_profitability_summary
GROUP BY category_name
ORDER BY margen DESC;

-- =============================================================
-- 3. ROI DE MARCAS
--    "¿Cuál marca tiene mejor retorno sobre inversión?"
-- =============================================================
SELECT
    brand_name,
    SUM(total_orders) AS total_ordenes,
    ROUND(SUM(revenue_base), 2) AS total_ingresos,
    ROUND(SUM(cost_total), 2) AS total_costos,
    ROUND(SUM(gross_margin), 2) AS ganancia_neta,
    ROUND(AVG(roi_pct), 2) AS roi_promedio,
    ROUND(AVG(gross_margin_pct), 2) AS margen_promedio
FROM analytics.etl_profitability_summary
GROUP BY brand_name
ORDER BY roi_promedio DESC;

-- =============================================================
-- 4. COSTOS DE IMPORTACIÓN VS VENTAS
--    "¿Cuánto cuesta importar vs cuánto se vende?"
-- =============================================================
SELECT
    p.category_name,
    ROUND(SUM(pu.subtotal), 2) AS total_compras,
    ROUND(SUM(pu.freight_cost + pu.insurance_cost + pu.port_cost), 2) AS costos_logisticos,
    ROUND(SUM(fs.revenue), 2) AS total_ventas,
    ROUND(SUM(fs.profit), 2) AS ganancia,
    CASE
        WHEN SUM(fs.revenue) > 0
        THEN ROUND(SUM(fs.profit) / SUM(fs.revenue) * 100, 2)
        ELSE 0
    END AS margen_venta_pct
FROM analytics.dw_fact_purchases pu
JOIN analytics.dim_product p ON pu.product_id = p.product_id
LEFT JOIN analytics.dw_fact_sales fs ON pu.product_id = fs.product_id
GROUP BY p.category_name
ORDER BY total_compras DESC;

-- =============================================================
-- 5. INVENTARIO ACTUAL POR PRODUCTO
--    "¿Qué productos tienen stock y cuánto vale?"
-- =============================================================
SELECT
    product_name,
    category_name,
    stock_available,
    ROUND(avg_unit_cost, 2) AS costo_unitario_promedio,
    ROUND(stock_available * avg_unit_cost, 2) AS valor_inventario
FROM analytics.vw_current_inventory
WHERE stock_available > 0
ORDER BY valor_inventario DESC;

-- =============================================================
-- 6. TENDENCIA DE VENTAS MENSUAL
--    "¿Cómo evolucionan las ventas mes a mes?"
-- =============================================================
SELECT
    d.year,
    d.month,
    d.month_name,
    COUNT(DISTINCT s.order_id) AS ordenes,
    SUM(s.quantity) AS unidades,
    ROUND(SUM(s.revenue), 2) AS ingresos,
    ROUND(SUM(s.profit), 2) AS ganancia,
    ROUND(AVG(s.margin_percent), 2) AS margen_promedio
FROM analytics.dw_fact_sales s
JOIN analytics.dim_fecha d ON s.date_key = d.date_key
GROUP BY d.year, d.month, d.month_name
ORDER BY d.year, d.month;

-- =============================================================
-- 7. VENTAS POR SITIO WEB
--    "¿Qué sitio web genera más ingresos?"
-- =============================================================
SELECT
    w.website_url,
    b.brand_name,
    c.country_name AS pais_sitio,
    COUNT(DISTINCT s.order_id) AS ordenes,
    SUM(s.quantity) AS unidades,
    ROUND(SUM(s.revenue), 2) AS ingresos,
    ROUND(SUM(s.profit), 2) AS ganancia
FROM analytics.dw_fact_sales s
JOIN analytics.dim_website w ON s.website_id = w.website_id
JOIN analytics.dim_brand b ON s.brand_id = b.brand_id
JOIN analytics.dim_country c ON s.country_id = c.country_id
GROUP BY w.website_url, b.brand_name, c.country_name
ORDER BY ingresos DESC;

-- =============================================================
-- 8. TOP 10 PRODUCTOS MÁS VENDIDOS
-- =============================================================
SELECT
    p.product_name,
    c.category_name,
    SUM(s.quantity) AS total_unidades,
    COUNT(DISTINCT s.order_id) AS ordenes,
    ROUND(SUM(s.revenue), 2) AS ingresos,
    ROUND(SUM(s.profit), 2) AS ganancia,
    ROUND(AVG(s.margin_percent), 2) AS margen_promedio
FROM analytics.dw_fact_sales s
JOIN analytics.dim_product p ON s.product_id = p.product_id
JOIN analytics.dim_category c ON s.category_id = c.category_id
GROUP BY p.product_name, c.category_name
ORDER BY total_unidades DESC
LIMIT 10;

-- =============================================================
-- 9. COMPARATIVA DE MARGEN POR PAÍS DE VENTA
-- =============================================================
SELECT
    country_name,
    iso_code,
    COUNT(DISTINCT order_id) AS ordenes,
    ROUND(SUM(revenue), 2) AS ingresos,
    ROUND(SUM(profit), 2) AS ganancia,
    ROUND(AVG(margin_percent), 2) AS margen_promedio,
    currency_code
FROM analytics.vw_sales_full
GROUP BY country_name, iso_code, currency_code
ORDER BY ganancia DESC;

-- =============================================================
-- 10. RESUMEN EJECUTIVO
-- =============================================================
SELECT
    (SELECT COUNT(DISTINCT order_id) FROM analytics.dw_fact_sales) AS total_ordenes,
    (SELECT ROUND(SUM(revenue), 2) FROM analytics.dw_fact_sales) AS total_ingresos,
    (SELECT ROUND(SUM(profit), 2) FROM analytics.dw_fact_sales) AS total_ganancia,
    (SELECT ROUND(AVG(margin_percent), 2) FROM analytics.dw_fact_sales) AS margen_promedio,
    (SELECT COUNT(DISTINCT brand_name) FROM analytics.etl_profitability_summary) AS marcas_activas,
    (SELECT COUNT(DISTINCT product_id) FROM analytics.dim_product WHERE enabled = TRUE) AS productos_activos,
    (SELECT ROUND(SUM(revenue_base), 2) FROM analytics.etl_profitability_summary) AS revenue_base_total,
    (SELECT ROUND(SUM(cost_total), 2) FROM analytics.etl_profitability_summary) AS costos_totales;
