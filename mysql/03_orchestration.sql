-- =============================================================
-- SCRIPT DE ORQUESTACIÓN - DYNAMIC BRANDS v4 (MySQL 8.4)
-- Patrón UPSERT + INOUT, EXIT HANDLER, logging
-- =============================================================
USE dynamic_brands_db;

-- 1. Catálogos base (currencies, statuses, focuses, couriers)
CALL sp_log('main','Iniciando carga Dynamic Brands v4...',NULL,NULL,'INFO',NULL);
CALL sp_insert_catalogs();

-- 2. Geografía (5 países, estados, ciudades)
CALL sp_insert_geography();

-- 3. Tipos de cambio históricos
CALL sp_insert_exchange_rates();

-- 4. Marcas (5) y 9 sitios web
CALL sp_insert_brands_websites();

-- 5. Clientes (30 en 5 países) + direcciones
CALL sp_insert_customers();

-- 6. Catálogo de productos por marca
CALL sp_insert_product_catalog();

-- 7. Website products + precios en moneda local
CALL sp_insert_website_products();

-- 8. Órdenes (27+ órdenes en 5 países)
CALL sp_insert_orders();

-- 9. Envíos (shipping records)
CALL sp_insert_shipping();

-- 10. Movimientos de inventario (IN por restock, OUT por órdenes)
CALL sp_insert_inventory_movements();

CALL sp_log('main','Carga Dynamic Brands v4 completada.',NULL,NULL,'SUCCESS',NULL);
