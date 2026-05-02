-- =============================================================
-- SCRIPT DE ORQUESTACIÓN - DYNAMIC BRANDS (MySQL 8.4)
-- =============================================================
USE dynamic_brands_db;

-- 1. Catálogos base
CALL sp_log('main','Iniciando carga Dynamic Brands...',NULL,NULL,'INFO',NULL);
CALL sp_insert_catalogs();

-- 2. Geografía (5 países)
CALL sp_insert_geography();

-- 3. Tipos de cambio
CALL sp_insert_exchange_rates();

-- 4. Marcas y 9 sitios web
CALL sp_insert_brands_websites();

-- 5. Clientes (30 en 5 países)
CALL sp_insert_customers();

-- 6. Catálogo de productos por marca
CALL sp_insert_product_catalog();

-- 7. Website products + precios
CALL sp_insert_website_products();

-- 8. Órdenes (27 órdenes en 5 países)
CALL sp_insert_orders();

-- 9. Envíos (shipping records)
CALL sp_insert_shipping();

CALL sp_log('main','Carga Dynamic Brands completada.',NULL,NULL,'SUCCESS',NULL);
