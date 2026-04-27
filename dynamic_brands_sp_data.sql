-- =============================================================
--  DYNAMIC BRANDS — Stored Procedures + Carga de Datos
--  Database: dynamic_brands_db (MySQL 8.4)
--  Incluye:
--    1. SP de logging independiente
--    2. SPs transaccionales de inserción con manejo de excepciones
--    3. Orquestación de llamadas para poblar la base de datos
-- =============================================================

USE dynamic_brands_db;

-- Configuración necesaria para MySQL
SET GLOBAL log_bin_trust_function_creators = 1;

-- =============================================================
-- SP 0: sp_log_process
-- SP de logging independiente llamado por todos los demás SPs.
-- Registra cada paso ejecutado en Process_log.
-- =============================================================
DROP PROCEDURE IF EXISTS sp_log_process;
DELIMITER $$
CREATE PROCEDURE sp_log_process(
    IN p_sp_name            VARCHAR(100),
    IN p_action_description TEXT,
    IN p_affected_table     VARCHAR(100),
    IN p_affected_record_id INT UNSIGNED,
    IN p_status             VARCHAR(20),
    IN p_error_detail       TEXT
)
BEGIN
    INSERT INTO Process_log (
        sp_name,
        action_description,
        affected_table,
        affected_record_id,
        status,
        error_detail
    ) VALUES (
        p_sp_name,
        p_action_description,
        p_affected_table,
        p_affected_record_id,
        p_status,
        p_error_detail
    );
END$$
DELIMITER ;

-- =============================================================
-- SP 1: sp_insert_country
-- Inserta un país de operación. Ignora duplicados.
-- =============================================================
DROP PROCEDURE IF EXISTS sp_insert_country;
DELIMITER $$
CREATE PROCEDURE sp_insert_country(
    IN p_country_name    VARCHAR(100),
    IN p_iso_code        CHAR(3),
    IN p_currency_code   CHAR(3),
    IN p_currency_symbol VARCHAR(5)
)
BEGIN
    DECLARE v_id         INT UNSIGNED DEFAULT NULL;
    DECLARE v_exists     INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @errmsg = MESSAGE_TEXT;
        CALL sp_log_process('sp_insert_country', CONCAT('Error al insertar país: ', p_country_name), 'Countries', NULL, 'ERROR', @errmsg);
        RESIGNAL;
    END;

    CALL sp_log_process('sp_insert_country', CONCAT('Iniciando inserción de país: ', p_country_name), 'Countries', NULL, 'INFO', NULL);

    SELECT COUNT(*) INTO v_exists FROM Countries WHERE iso_code = p_iso_code;

    IF v_exists = 0 THEN
        INSERT INTO Countries (country_name, iso_code, currency_code, currency_symbol)
        VALUES (p_country_name, p_iso_code, p_currency_code, p_currency_symbol);

        SET v_id = LAST_INSERT_ID();
        CALL sp_log_process('sp_insert_country', CONCAT('País insertado: ', p_country_name), 'Countries', v_id, 'SUCCESS', NULL);
    ELSE
        CALL sp_log_process('sp_insert_country', CONCAT('País ya existía (iso_code): ', p_iso_code), 'Countries', NULL, 'WARNING', NULL);
    END IF;
END$$
DELIMITER ;

-- =============================================================
-- SP 2: sp_insert_exchange_rate
-- Inserta tipo de cambio para un país. Ignora duplicados por país+fecha.
-- =============================================================
DROP PROCEDURE IF EXISTS sp_insert_exchange_rate;
DELIMITER $$
CREATE PROCEDURE sp_insert_exchange_rate(
    IN p_iso_code    CHAR(3),
    IN p_rate_to_usd DECIMAL(18,6),
    IN p_rate_date   DATE,
    IN p_source      VARCHAR(100)
)
BEGIN
    DECLARE v_country_id INT UNSIGNED DEFAULT NULL;
    DECLARE v_currency   CHAR(3);
    DECLARE v_id         INT UNSIGNED DEFAULT NULL;
    DECLARE v_exists     INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @errmsg = MESSAGE_TEXT;
        CALL sp_log_process('sp_insert_exchange_rate', CONCAT('Error tipo de cambio país: ', p_iso_code), 'Exchange_rates', NULL, 'ERROR', @errmsg);
        RESIGNAL;
    END;

    CALL sp_log_process('sp_insert_exchange_rate', CONCAT('Insertando tipo de cambio para: ', p_iso_code), 'Exchange_rates', NULL, 'INFO', NULL);

    SELECT country_id, currency_code INTO v_country_id, v_currency
    FROM Countries WHERE iso_code = p_iso_code LIMIT 1;

    IF v_country_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'País no encontrado para tipo de cambio';
    END IF;

    SELECT COUNT(*) INTO v_exists
    FROM Exchange_rates WHERE country_id = v_country_id AND rate_date = p_rate_date;

    IF v_exists = 0 THEN
        INSERT INTO Exchange_rates (country_id, currency_code, rate_to_usd, rate_date, source)
        VALUES (v_country_id, v_currency, p_rate_to_usd, p_rate_date, p_source);

        SET v_id = LAST_INSERT_ID();
        CALL sp_log_process('sp_insert_exchange_rate', CONCAT('Tipo de cambio insertado para ', p_iso_code), 'Exchange_rates', v_id, 'SUCCESS', NULL);
    ELSE
        CALL sp_log_process('sp_insert_exchange_rate', CONCAT('Tipo de cambio ya existe para ', p_iso_code, ' en ', p_rate_date), 'Exchange_rates', NULL, 'WARNING', NULL);
    END IF;
END$$
DELIMITER ;

-- =============================================================
-- SP 3: sp_insert_country_tax
-- Inserta la tasa de impuesto al consumidor de un país.
-- =============================================================
DROP PROCEDURE IF EXISTS sp_insert_country_tax;
DELIMITER $$
CREATE PROCEDURE sp_insert_country_tax(
    IN p_iso_code          CHAR(3),
    IN p_tax_rate_percent  DECIMAL(5,2),
    IN p_regulatory_notes  TEXT,
    IN p_valid_from        DATE
)
BEGIN
    DECLARE v_country_id INT UNSIGNED DEFAULT NULL;
    DECLARE v_id         INT UNSIGNED DEFAULT NULL;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @errmsg = MESSAGE_TEXT;
        CALL sp_log_process('sp_insert_country_tax', CONCAT('Error impuesto país: ', p_iso_code), 'Country_taxes', NULL, 'ERROR', @errmsg);
        RESIGNAL;
    END;

    CALL sp_log_process('sp_insert_country_tax', CONCAT('Insertando impuesto para: ', p_iso_code), 'Country_taxes', NULL, 'INFO', NULL);

    SELECT country_id INTO v_country_id FROM Countries WHERE iso_code = p_iso_code LIMIT 1;

    IF v_country_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'País no encontrado para impuesto';
    END IF;

    INSERT INTO Country_taxes (country_id, tax_rate_percent, regulatory_notes, valid_from)
    VALUES (v_country_id, p_tax_rate_percent, p_regulatory_notes, p_valid_from);

    SET v_id = LAST_INSERT_ID();
    CALL sp_log_process('sp_insert_country_tax', CONCAT('Impuesto insertado para ', p_iso_code, ': ', p_tax_rate_percent, '%'), 'Country_taxes', v_id, 'SUCCESS', NULL);
END$$
DELIMITER ;

-- =============================================================
-- SP 4: sp_insert_brand
-- Inserta una marca blanca generada por la IA.
-- =============================================================
DROP PROCEDURE IF EXISTS sp_insert_brand;
DELIMITER $$
CREATE PROCEDURE sp_insert_brand(
    IN p_brand_name          VARCHAR(150),
    IN p_brand_logo_url      VARCHAR(500),
    IN p_brand_focus         VARCHAR(100),
    IN p_ai_model_version    VARCHAR(50)
)
BEGIN
    DECLARE v_id INT UNSIGNED DEFAULT NULL;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @errmsg = MESSAGE_TEXT;
        CALL sp_log_process('sp_insert_brand', CONCAT('Error al insertar marca: ', p_brand_name), 'Brands', NULL, 'ERROR', @errmsg);
        RESIGNAL;
    END;

    CALL sp_log_process('sp_insert_brand', CONCAT('Iniciando inserción de marca: ', p_brand_name), 'Brands', NULL, 'INFO', NULL);

    INSERT INTO Brands (brand_name, brand_logo_url, brand_focus, ai_model_version, generated_at)
    VALUES (p_brand_name, p_brand_logo_url, p_brand_focus, p_ai_model_version, NOW());

    SET v_id = LAST_INSERT_ID();
    CALL sp_log_process('sp_insert_brand', CONCAT('Marca insertada: ', p_brand_name), 'Brands', v_id, 'SUCCESS', NULL);
END$$
DELIMITER ;

-- =============================================================
-- SP 5: sp_insert_website
-- Inserta un sitio e-commerce dinámico vinculado a marca y país.
-- =============================================================
DROP PROCEDURE IF EXISTS sp_insert_website;
DELIMITER $$
CREATE PROCEDURE sp_insert_website(
    IN p_brand_name      VARCHAR(150),
    IN p_iso_code        CHAR(3),
    IN p_site_url        VARCHAR(500),
    IN p_marketing_focus VARCHAR(200),
    IN p_launch_date     DATE
)
BEGIN
    DECLARE v_brand_id   INT UNSIGNED DEFAULT NULL;
    DECLARE v_country_id INT UNSIGNED DEFAULT NULL;
    DECLARE v_id         INT UNSIGNED DEFAULT NULL;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @errmsg = MESSAGE_TEXT;
        CALL sp_log_process('sp_insert_website', CONCAT('Error al insertar sitio: ', p_site_url), 'Websites', NULL, 'ERROR', @errmsg);
        RESIGNAL;
    END;

    CALL sp_log_process('sp_insert_website', CONCAT('Iniciando inserción de sitio: ', p_site_url), 'Websites', NULL, 'INFO', NULL);

    SELECT brand_id INTO v_brand_id FROM Brands WHERE brand_name = p_brand_name AND is_deleted = 0 LIMIT 1;
    IF v_brand_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Marca no encontrada para el sitio web';
    END IF;

    SELECT country_id INTO v_country_id FROM Countries WHERE iso_code = p_iso_code LIMIT 1;
    IF v_country_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'País no encontrado para el sitio web';
    END IF;

    INSERT INTO Websites (brand_id, country_id, site_url, marketing_focus, status, launch_date)
    VALUES (v_brand_id, v_country_id, p_site_url, p_marketing_focus, 'ACTIVE', p_launch_date);

    SET v_id = LAST_INSERT_ID();
    CALL sp_log_process('sp_insert_website', CONCAT('Sitio insertado ID: ', v_id, ' URL: ', p_site_url), 'Websites', v_id, 'SUCCESS', NULL);
END$$
DELIMITER ;

-- =============================================================
-- SP 6: sp_insert_courier
-- Inserta un servicio de courier externo.
-- =============================================================
DROP PROCEDURE IF EXISTS sp_insert_courier;
DELIMITER $$
CREATE PROCEDURE sp_insert_courier(
    IN p_courier_name  VARCHAR(100),
    IN p_contact_info  VARCHAR(200)
)
BEGIN
    DECLARE v_id     INT UNSIGNED DEFAULT NULL;
    DECLARE v_exists INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @errmsg = MESSAGE_TEXT;
        CALL sp_log_process('sp_insert_courier', CONCAT('Error al insertar courier: ', p_courier_name), 'Couriers', NULL, 'ERROR', @errmsg);
        RESIGNAL;
    END;

    SELECT COUNT(*) INTO v_exists FROM Couriers WHERE courier_name = p_courier_name;

    IF v_exists = 0 THEN
        INSERT INTO Couriers (courier_name, contact_info) VALUES (p_courier_name, p_contact_info);
        SET v_id = LAST_INSERT_ID();
        CALL sp_log_process('sp_insert_courier', CONCAT('Courier insertado: ', p_courier_name), 'Couriers', v_id, 'SUCCESS', NULL);
    ELSE
        CALL sp_log_process('sp_insert_courier', CONCAT('Courier ya existía: ', p_courier_name), 'Couriers', NULL, 'WARNING', NULL);
    END IF;
END$$
DELIMITER ;

-- =============================================================
-- SP 7: sp_insert_customer
-- Inserta un cliente final con su dirección principal.
-- =============================================================
DROP PROCEDURE IF EXISTS sp_insert_customer;
DELIMITER $$
CREATE PROCEDURE sp_insert_customer(
    IN p_first_name   VARCHAR(80),
    IN p_last_name    VARCHAR(80),
    IN p_email        VARCHAR(150),
    IN p_phone        VARCHAR(30),
    IN p_iso_code     CHAR(3),
    IN p_address_line VARCHAR(300),
    IN p_city         VARCHAR(100)
)
BEGIN
    DECLARE v_country_id INT UNSIGNED DEFAULT NULL;
    DECLARE v_cust_id    INT UNSIGNED DEFAULT NULL;
    DECLARE v_addr_id    INT UNSIGNED DEFAULT NULL;
    DECLARE v_exists     INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @errmsg = MESSAGE_TEXT;
        CALL sp_log_process('sp_insert_customer', CONCAT('Error al insertar cliente: ', p_email), 'Customers', NULL, 'ERROR', @errmsg);
        RESIGNAL;
    END;

    CALL sp_log_process('sp_insert_customer', CONCAT('Iniciando inserción cliente: ', p_email), 'Customers', NULL, 'INFO', NULL);

    SELECT COUNT(*) INTO v_exists FROM Customers WHERE email = p_email;
    IF v_exists > 0 THEN
        CALL sp_log_process('sp_insert_customer', CONCAT('Cliente ya existe: ', p_email), 'Customers', NULL, 'WARNING', NULL);
        LEAVE sp_insert_customer;
    END IF;

    SELECT country_id INTO v_country_id FROM Countries WHERE iso_code = p_iso_code LIMIT 1;
    IF v_country_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'País no encontrado para el cliente';
    END IF;

    START TRANSACTION;

    INSERT INTO Customers (first_name, last_name, email, phone, country_id)
    VALUES (p_first_name, p_last_name, p_email, p_phone, v_country_id);
    SET v_cust_id = LAST_INSERT_ID();

    INSERT INTO Customer_addresses (customer_id, address_line, city, country_id, is_default)
    VALUES (v_cust_id, p_address_line, p_city, v_country_id, 1);
    SET v_addr_id = LAST_INSERT_ID();

    COMMIT;

    CALL sp_log_process('sp_insert_customer', CONCAT('Cliente insertado ID: ', v_cust_id, ' dirección ID: ', v_addr_id), 'Customers', v_cust_id, 'SUCCESS', NULL);
END$$
DELIMITER ;

-- =============================================================
-- SP 8: sp_insert_catalog_product
-- Inserta un producto con identidad de marca blanca en el catálogo.
-- =============================================================
DROP PROCEDURE IF EXISTS sp_insert_catalog_product;
DELIMITER $$
CREATE PROCEDURE sp_insert_catalog_product(
    IN p_etheria_product_id  INT UNSIGNED,
    IN p_brand_name          VARCHAR(150),
    IN p_branded_name        VARCHAR(150),
    IN p_branded_description TEXT,
    IN p_health_claims       TEXT
)
BEGIN
    DECLARE v_brand_id INT UNSIGNED DEFAULT NULL;
    DECLARE v_id       INT UNSIGNED DEFAULT NULL;
    DECLARE v_exists   INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @errmsg = MESSAGE_TEXT;
        CALL sp_log_process('sp_insert_catalog_product', CONCAT('Error al insertar producto catálogo: ', p_branded_name), 'Product_catalog', NULL, 'ERROR', @errmsg);
        RESIGNAL;
    END;

    CALL sp_log_process('sp_insert_catalog_product', CONCAT('Insertando producto catálogo: ', p_branded_name, ' marca: ', p_brand_name), 'Product_catalog', NULL, 'INFO', NULL);

    SELECT brand_id INTO v_brand_id FROM Brands WHERE brand_name = p_brand_name AND is_deleted = 0 LIMIT 1;
    IF v_brand_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Marca no encontrada para producto catálogo';
    END IF;

    SELECT COUNT(*) INTO v_exists FROM Product_catalog WHERE etheria_product_id = p_etheria_product_id AND brand_id = v_brand_id;
    IF v_exists > 0 THEN
        CALL sp_log_process('sp_insert_catalog_product', CONCAT('Producto catálogo ya existe: ', p_branded_name), 'Product_catalog', NULL, 'WARNING', NULL);
        LEAVE sp_insert_catalog_product;
    END IF;

    INSERT INTO Product_catalog (etheria_product_id, brand_id, branded_name, branded_description, health_claims)
    VALUES (p_etheria_product_id, v_brand_id, p_branded_name, p_branded_description, p_health_claims);

    SET v_id = LAST_INSERT_ID();
    CALL sp_log_process('sp_insert_catalog_product', CONCAT('Producto catálogo insertado ID: ', v_id), 'Product_catalog', v_id, 'SUCCESS', NULL);
END$$
DELIMITER ;

-- =============================================================
-- SP 9: sp_publish_product_on_website
-- Publica un producto del catálogo en un sitio web con precio.
-- =============================================================
DROP PROCEDURE IF EXISTS sp_publish_product_on_website;
DELIMITER $$
CREATE PROCEDURE sp_publish_product_on_website(
    IN p_site_url          VARCHAR(500),
    IN p_branded_name      VARCHAR(150),
    IN p_brand_name        VARCHAR(150),
    IN p_sale_price_local  DECIMAL(14,2),
    IN p_valid_from        DATE,
    IN p_stock_display     INT UNSIGNED
)
BEGIN
    DECLARE v_website_id      INT UNSIGNED DEFAULT NULL;
    DECLARE v_catalog_id      INT UNSIGNED DEFAULT NULL;
    DECLARE v_brand_id        INT UNSIGNED DEFAULT NULL;
    DECLARE v_wp_id           INT UNSIGNED DEFAULT NULL;
    DECLARE v_price_id        INT UNSIGNED DEFAULT NULL;
    DECLARE v_exists          INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @errmsg = MESSAGE_TEXT;
        CALL sp_log_process('sp_publish_product_on_website', CONCAT('Error al publicar producto: ', p_branded_name, ' en sitio: ', p_site_url), 'Website_products', NULL, 'ERROR', @errmsg);
        RESIGNAL;
    END;

    CALL sp_log_process('sp_publish_product_on_website', CONCAT('Publicando: ', p_branded_name, ' en ', p_site_url), 'Website_products', NULL, 'INFO', NULL);

    SELECT website_id INTO v_website_id FROM Websites WHERE site_url = p_site_url AND is_deleted = 0 LIMIT 1;
    IF v_website_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Sitio web no encontrado';
    END IF;

    SELECT brand_id INTO v_brand_id FROM Brands WHERE brand_name = p_brand_name AND is_deleted = 0 LIMIT 1;
    IF v_brand_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Marca no encontrada al publicar producto';
    END IF;

    SELECT catalog_product_id INTO v_catalog_id FROM Product_catalog
    WHERE branded_name = p_branded_name AND brand_id = v_brand_id AND is_deleted = 0 LIMIT 1;
    IF v_catalog_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Producto catálogo no encontrado para publicación';
    END IF;

    SELECT COUNT(*) INTO v_exists FROM Website_products WHERE website_id = v_website_id AND catalog_product_id = v_catalog_id;

    IF v_exists = 0 THEN
        START TRANSACTION;

        INSERT INTO Website_products (website_id, catalog_product_id, stock_display, is_featured)
        VALUES (v_website_id, v_catalog_id, p_stock_display, 0);
        SET v_wp_id = LAST_INSERT_ID();

        INSERT INTO Website_product_prices (website_product_id, sale_price_local, valid_from)
        VALUES (v_wp_id, p_sale_price_local, p_valid_from);
        SET v_price_id = LAST_INSERT_ID();

        COMMIT;

        CALL sp_log_process('sp_publish_product_on_website', CONCAT('Producto publicado wp_id: ', v_wp_id, ' precio_id: ', v_price_id), 'Website_products', v_wp_id, 'SUCCESS', NULL);
    ELSE
        CALL sp_log_process('sp_publish_product_on_website', CONCAT('Producto ya publicado en este sitio: ', p_branded_name), 'Website_products', NULL, 'WARNING', NULL);
    END IF;
END$$
DELIMITER ;

-- =============================================================
-- SP 10: sp_register_order
-- Registra una orden de compra completa con sus ítems y envío.
-- Es la transacción principal de Dynamic Brands.
-- =============================================================
DROP PROCEDURE IF EXISTS sp_register_order;
DELIMITER $$
CREATE PROCEDURE sp_register_order(
    IN p_customer_email       VARCHAR(150),
    IN p_site_url             VARCHAR(500),
    IN p_branded_name         VARCHAR(150),
    IN p_brand_name           VARCHAR(150),
    IN p_quantity             INT UNSIGNED,
    IN p_courier_name         VARCHAR(100),
    IN p_tracking_code        VARCHAR(100),
    IN p_shipping_cost_local  DECIMAL(12,2),
    IN p_etheria_dispatch_id  INT UNSIGNED
)
BEGIN
    DECLARE v_customer_id    INT UNSIGNED DEFAULT NULL;
    DECLARE v_address_id     INT UNSIGNED DEFAULT NULL;
    DECLARE v_website_id     INT UNSIGNED DEFAULT NULL;
    DECLARE v_country_id     INT UNSIGNED DEFAULT NULL;
    DECLARE v_wp_id          INT UNSIGNED DEFAULT NULL;
    DECLARE v_catalog_id     INT UNSIGNED DEFAULT NULL;
    DECLARE v_brand_id       INT UNSIGNED DEFAULT NULL;
    DECLARE v_price_local    DECIMAL(14,2);
    DECLARE v_rate_id        INT UNSIGNED DEFAULT NULL;
    DECLARE v_rate           DECIMAL(18,6);
    DECLARE v_subtotal       DECIMAL(14,2);
    DECLARE v_shipping_usd   DECIMAL(12,2);
    DECLARE v_total_local    DECIMAL(14,2);
    DECLARE v_total_usd      DECIMAL(14,4);
    DECLARE v_order_id       INT UNSIGNED DEFAULT NULL;
    DECLARE v_courier_id     INT UNSIGNED DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        GET DIAGNOSTICS CONDITION 1 @errmsg = MESSAGE_TEXT;
        CALL sp_log_process('sp_register_order', CONCAT('Error en orden cliente: ', p_customer_email, ' sitio: ', p_site_url), 'Orders', NULL, 'ERROR', @errmsg);
        RESIGNAL;
    END;

    CALL sp_log_process('sp_register_order', CONCAT('Iniciando orden: cliente=', p_customer_email, ' sitio=', p_site_url), 'Orders', NULL, 'INFO', NULL);

    -- Resolver cliente y dirección
    SELECT customer_id INTO v_customer_id FROM Customers WHERE email = p_customer_email AND is_deleted = 0 LIMIT 1;
    IF v_customer_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cliente no encontrado';
    END IF;

    SELECT address_id INTO v_address_id FROM Customer_addresses
    WHERE customer_id = v_customer_id AND is_default = 1 AND is_deleted = 0 LIMIT 1;
    IF v_address_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Dirección por defecto del cliente no encontrada';
    END IF;

    -- Resolver sitio y país
    SELECT website_id, country_id INTO v_website_id, v_country_id
    FROM Websites WHERE site_url = p_site_url AND is_deleted = 0 LIMIT 1;
    IF v_website_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Sitio web no encontrado';
    END IF;

    -- Resolver tipo de cambio más reciente para ese país
    SELECT exchange_rate_id, rate_to_usd INTO v_rate_id, v_rate
    FROM Exchange_rates WHERE country_id = v_country_id
    ORDER BY rate_date DESC LIMIT 1;
    IF v_rate_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Tipo de cambio no encontrado para el país del sitio';
    END IF;

    -- Resolver producto publicado y precio
    SELECT brand_id INTO v_brand_id FROM Brands WHERE brand_name = p_brand_name AND is_deleted = 0 LIMIT 1;

    SELECT pc.catalog_product_id INTO v_catalog_id
    FROM Product_catalog pc
    WHERE pc.branded_name = p_branded_name AND pc.brand_id = v_brand_id AND pc.is_deleted = 0 LIMIT 1;

    SELECT wp.website_product_id INTO v_wp_id
    FROM Website_products wp
    WHERE wp.website_id = v_website_id AND wp.catalog_product_id = v_catalog_id AND wp.is_deleted = 0 LIMIT 1;
    IF v_wp_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Producto no publicado en este sitio';
    END IF;

    SELECT sale_price_local INTO v_price_local
    FROM Website_product_prices WHERE website_product_id = v_wp_id
    ORDER BY valid_from DESC LIMIT 1;
    IF v_price_local IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Precio del producto no encontrado';
    END IF;

    -- Calcular totales
    SET v_subtotal     = v_price_local * p_quantity;
    SET v_total_local  = v_subtotal + p_shipping_cost_local;
    SET v_shipping_usd = p_shipping_cost_local / v_rate;
    SET v_total_usd    = v_total_local / v_rate;

    -- Resolver courier
    SELECT courier_id INTO v_courier_id FROM Couriers WHERE courier_name = p_courier_name AND is_active = 1 LIMIT 1;
    IF v_courier_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Courier no encontrado';
    END IF;

    START TRANSACTION;

    -- Insertar orden
    INSERT INTO Orders (
        customer_id, website_id, address_id,
        total_amount_local, exchange_rate_id, exchange_rate_snapshot,
        total_amount_usd, etheria_dispatch_id, status
    ) VALUES (
        v_customer_id, v_website_id, v_address_id,
        v_total_local, v_rate_id, v_rate,
        v_total_usd, p_etheria_dispatch_id, 'CONFIRMADA'
    );
    SET v_order_id = LAST_INSERT_ID();

    CALL sp_log_process('sp_register_order', CONCAT('Orden creada ID: ', v_order_id), 'Orders', v_order_id, 'INFO', NULL);

    -- Insertar ítem de la orden
    INSERT INTO Order_items (order_id, website_product_id, quantity, unit_price_local, subtotal_local)
    VALUES (v_order_id, v_wp_id, p_quantity, v_price_local, v_subtotal);

    CALL sp_log_process('sp_register_order', CONCAT('Order_item insertado para orden: ', v_order_id), 'Order_items', v_order_id, 'INFO', NULL);

    -- Registrar envío
    INSERT INTO Shipping_records (
        order_id, courier_id, tracking_code,
        shipping_cost_local, shipping_cost_usd,
        estimated_delivery_date, status
    ) VALUES (
        v_order_id, v_courier_id, p_tracking_code,
        p_shipping_cost_local, v_shipping_usd,
        DATE_ADD(CURDATE(), INTERVAL 10 DAY), 'EN_TRANSITO'
    );

    COMMIT;

    CALL sp_log_process('sp_register_order', CONCAT('Orden completa registrada ID: ', v_order_id, ' total USD: ', ROUND(v_total_usd,2)), 'Orders', v_order_id, 'SUCCESS', NULL);
END$$
DELIMITER ;

-- =============================================================
-- =============================================================
--  ORQUESTACIÓN — Carga de Datos
-- =============================================================
-- =============================================================

-- ─────────────────────────────────────────────────────────────
-- BLOQUE 1: Países donde opera Dynamic Brands (5 países Latam)
-- ─────────────────────────────────────────────────────────────
CALL sp_insert_country('Colombia',   'COL', 'COP', '$');
CALL sp_insert_country('México',     'MEX', 'MXN', '$');
CALL sp_insert_country('Perú',       'PER', 'PEN', 'S/');
CALL sp_insert_country('Chile',      'CHL', 'CLP', '$');
CALL sp_insert_country('Costa Rica', 'CRI', 'CRC', '₡');

-- ─────────────────────────────────────────────────────────────
-- BLOQUE 2: Tipos de cambio (1 USD = X moneda local)
-- ─────────────────────────────────────────────────────────────
CALL sp_insert_exchange_rate('COL', 4150.000000, '2025-01-01', 'Banco de la República Colombia');
CALL sp_insert_exchange_rate('MEX',   17.250000, '2025-01-01', 'Banco de México');
CALL sp_insert_exchange_rate('PER',    3.820000, '2025-01-01', 'BCRP Perú');
CALL sp_insert_exchange_rate('CHL',  930.000000, '2025-01-01', 'Banco Central de Chile');
CALL sp_insert_exchange_rate('CRI',  520.000000, '2025-01-01', 'BCCR Costa Rica');

-- ─────────────────────────────────────────────────────────────
-- BLOQUE 3: Impuestos al consumidor final por país
-- ─────────────────────────────────────────────────────────────
CALL sp_insert_country_tax('COL', 19.00, 'IVA estándar Colombia — Ley 2010 de 2019',    '2025-01-01');
CALL sp_insert_country_tax('MEX', 16.00, 'IVA estándar México — LIVA Art. 1',           '2025-01-01');
CALL sp_insert_country_tax('PER', 18.00, 'IGV Perú — TUO Ley IGV D.S. 055-99-EF',      '2025-01-01');
CALL sp_insert_country_tax('CHL', 19.00, 'IVA Chile — DL 825 Art. 14',                  '2025-01-01');
CALL sp_insert_country_tax('CRI', 13.00, 'IVA Costa Rica — Ley 9635 ITBIS',             '2025-01-01');

-- ─────────────────────────────────────────────────────────────
-- BLOQUE 4: Marcas blancas generadas por la IA (5 marcas, 9 sitios)
-- ─────────────────────────────────────────────────────────────
CALL sp_insert_brand('VerdeLux',  'https://cdn.dynamicbrands.io/logos/verdelux.svg',  'Lujo natural y bienestar premium',      'DynAI-v3.2');
CALL sp_insert_brand('NaturPura', 'https://cdn.dynamicbrands.io/logos/naturpura.svg', 'Pureza amazónica y medicina ancestral', 'DynAI-v3.2');
CALL sp_insert_brand('AromaPura', 'https://cdn.dynamicbrands.io/logos/aromapura.svg', 'Aromaterapia y bienestar sensorial',    'DynAI-v3.1');
CALL sp_insert_brand('BioVita',   'https://cdn.dynamicbrands.io/logos/biovita.svg',   'Suplementos y nutrición funcional',     'DynAI-v3.2');
CALL sp_insert_brand('ZenBody',   'https://cdn.dynamicbrands.io/logos/zenbody.svg',   'Cosmética holística y cuidado corporal','DynAI-v3.3');

-- ─────────────────────────────────────────────────────────────
-- BLOQUE 5: Sitios web dinámicos (9 sitios — al menos 1 por país)
-- ─────────────────────────────────────────────────────────────
-- Colombia (COL) — 2 sitios
CALL sp_insert_website('VerdeLux',  'COL', 'https://verdelux.co',    'Lujo botánico para Colombia — enfoque en piel y cabello', '2024-11-01');
CALL sp_insert_website('NaturPura', 'COL', 'https://naturpura.co',   'Remedios amazónicos para el mercado colombiano',          '2024-11-15');
-- México (MEX) — 2 sitios
CALL sp_insert_website('AromaPura', 'MEX', 'https://aromapura.mx',   'Aromaterapia y cosmética francesa para México',           '2024-10-01');
CALL sp_insert_website('ZenBody',   'MEX', 'https://zenbody.mx',     'Cuidado corporal holístico — mercado mexicano',           '2024-10-20');
-- Perú (PER) — 2 sitios
CALL sp_insert_website('BioVita',   'PER', 'https://biovita.pe',     'Suplementos amazónicos y adaptógenos para Perú',         '2024-11-01');
CALL sp_insert_website('NaturPura', 'PER', 'https://naturpura.pe',   'Cosmética natural certificada — mercado peruano',        '2024-11-20');
-- Chile (CHL) — 2 sitios
CALL sp_insert_website('ZenBody',   'CHL', 'https://zenbody.cl',     'Cosmética premium importada para el mercado chileno',    '2024-09-15');
CALL sp_insert_website('VerdeLux',  'CHL', 'https://verdelux.cl',    'Lujo vegano y orgánico — enfoque en bienestar chileno',  '2024-09-30');
-- Costa Rica (CRI) — 1 sitio
CALL sp_insert_website('AromaPura', 'CRI', 'https://aromapura.cr',   'Aromaterapia y aceites esenciales para Costa Rica',     '2024-12-01');

-- ─────────────────────────────────────────────────────────────
-- BLOQUE 6: Couriers externos
-- ─────────────────────────────────────────────────────────────
CALL sp_insert_courier('DHL Express Latam',    'customerservice@dhl.com — Tel: +1-800-225-5345');
CALL sp_insert_courier('FedEx International',  'fedexlatam@fedex.com — Tel: +1-800-463-3339');
CALL sp_insert_courier('Servientrega',         'servicioalcliente@servientrega.com.co — Tel: +57-1-3078888');
CALL sp_insert_courier('Estafeta México',      'clientes@estafeta.com — Tel: +52-55-30037300');
CALL sp_insert_courier('Correos de Costa Rica','call.center@correos.go.cr — Tel: +506-2202-8000');

-- ─────────────────────────────────────────────────────────────
-- BLOQUE 7: Clientes finales (5 por país = 25 clientes)
-- ─────────────────────────────────────────────────────────────
-- Colombia
CALL sp_insert_customer('Valentina', 'Ríos',       'v.rios@email.co',       '+57-310-1234567', 'COL', 'Calle 72 #10-45 Apto 301',       'Bogotá');
CALL sp_insert_customer('Sebastián', 'Mora',       's.mora@gmail.com',      '+57-311-2345678', 'COL', 'Carrera 43A #18-25',             'Medellín');
CALL sp_insert_customer('Camila',    'Herrera',    'camila.h@outlook.com',  '+57-312-3456789', 'COL', 'Av. El Dorado #68D-35',         'Bogotá');
CALL sp_insert_customer('Andrés',    'Ospina',     'andres.o@email.co',     '+57-313-4567890', 'COL', 'Calle 5 Norte #28-42',          'Cali');
CALL sp_insert_customer('Lucía',     'Vargas',     'lucia.v@gmail.com',     '+57-314-5678901', 'COL', 'Cra 51B #80-58 Of. 412',        'Barranquilla');
-- México
CALL sp_insert_customer('Fernanda',  'Gutiérrez',  'f.gutierrez@email.mx',  '+52-55-91234567', 'MEX', 'Av. Insurgentes Sur 1602',      'Ciudad de México');
CALL sp_insert_customer('Miguel',    'Ramírez',    'm.ramirez@hotmail.com', '+52-33-82345678', 'MEX', 'Calzada Independencia Norte 622','Guadalajara');
CALL sp_insert_customer('Sofía',     'López',      'sofia.l@gmail.com',     '+52-81-73456789', 'MEX', 'Av. Constitución 4500',         'Monterrey');
CALL sp_insert_customer('Diego',     'Hernández',  'd.hernandez@email.mx',  '+52-55-64567890', 'MEX', 'Calle Amsterdam 85',            'Ciudad de México');
CALL sp_insert_customer('Isabella',  'Torres',     'isabella.t@gmail.com',  '+52-442-5678901', 'MEX', 'Blvd. Bernardo Quintana 7001',  'Querétaro');
-- Perú
CALL sp_insert_customer('Ximena',    'Castro',     'x.castro@email.pe',     '+51-1-91234567',  'PER', 'Av. Javier Prado Este 4200',    'Lima');
CALL sp_insert_customer('Rodrigo',   'Silva',      'r.silva@gmail.com',     '+51-54-82345678', 'PER', 'Calle San Agustín 312',         'Arequipa');
CALL sp_insert_customer('Daniela',   'Flores',     'daniela.f@outlook.com', '+51-74-73456789', 'PER', 'Jr. Lima 431',                  'Trujillo');
CALL sp_insert_customer('Mateo',     'García',     'm.garcia@email.pe',     '+51-1-64567890',  'PER', 'Av. Benavides 1515',            'Lima');
CALL sp_insert_customer('Renata',    'Mendoza',    'renata.m@gmail.com',    '+51-64-5678901',  'PER', 'Calle Piura 124',               'Huancayo');
-- Chile
CALL sp_insert_customer('Catalina',  'Muñoz',      'c.munoz@email.cl',      '+56-9-91234567',  'CHL', 'Av. Providencia 2244',          'Santiago');
CALL sp_insert_customer('Nicolás',   'Pérez',      'n.perez@gmail.com',     '+56-9-82345678',  'CHL', 'Av. España 1680',               'Valparaíso');
CALL sp_insert_customer('Javiera',   'Rojas',      'javiera.r@hotmail.com', '+56-9-73456789',  'CHL', 'Av. Alemania 0850',             'Temuco');
CALL sp_insert_customer('Tomás',     'Soto',       't.soto@email.cl',       '+56-9-64567890',  'CHL', 'Av. O\'Higgins 420',            'Concepción');
CALL sp_insert_customer('Martina',   'Fuentes',    'martina.f@gmail.com',   '+56-9-55678901',  'CHL', 'Calle Las Condes 11287',        'Santiago');
-- Costa Rica
CALL sp_insert_customer('Pablo',     'Jiménez',    'p.jimenez@email.cr',    '+506-8812-3456',  'CRI', 'Condominio Los Laureles C-8',   'San José');
CALL sp_insert_customer('Natalia',   'Solís',      'n.solis@gmail.com',     '+506-8823-4567',  'CRI', 'Av. Central Calle 1 Edif. Bco.','San José');
CALL sp_insert_customer('Gabriel',   'Chaves',     'g.chaves@email.cr',     '+506-8834-5678',  'CRI', 'Urbanización Los Cipreses 45',  'Heredia');
CALL sp_insert_customer('Valeria',   'Mora',       'valeria.m@gmail.com',   '+506-8845-6789',  'CRI', 'Residencial La Colina Casa 12', 'Alajuela');
CALL sp_insert_customer('Esteban',   'Ulate',      'e.ulate@email.cr',      '+506-8856-7890',  'CRI', 'Calle 15 Av. 8 Casa 22',        'Cartago');

-- ─────────────────────────────────────────────────────────────
-- BLOQUE 8: Productos en catálogo con identidad de marca blanca
-- etheria_product_id referencia Products.product_id de Etheria Global
-- ─────────────────────────────────────────────────────────────
-- VerdeLux (lujo natural)
CALL sp_insert_catalog_product(1,  'VerdeLux', 'VerdeLux Oro de Argán',         'Aceite de argán puro de primera prensada en frío — tratamiento capilar y facial de lujo',        'Regenera y nutre el cabello dañado. Hidrata profundamente la piel seca.');
CALL sp_insert_catalog_product(3,  'VerdeLux', 'VerdeLux Esencia de Rosas',     'Destilado puro de pétalos de Rosa de Damasco — el máximo en aromaterapia premium',              'Antioxidante natural. Equilibra el estado de ánimo. Hidratación celular profunda.');
CALL sp_insert_catalog_product(85, 'VerdeLux', 'VerdeLux Lavanda Provenzal',    'Aceite esencial de lavanda de alta montaña — cosecha artesanal de Provence',                   'Reduce el estrés y la ansiedad. Favorece el sueño reparador. Antiinflamatorio natural.');
CALL sp_insert_catalog_product(83, 'VerdeLux', 'VerdeLux Rosa de Francia',      'Aceite esencial de Rosa Centifolia — el ingrediente más exclusivo de la perfumería francesa',   'Antienvejecimiento celular. Equilibra el pH de la piel sensible. Armonizante emocional.');
CALL sp_insert_catalog_product(86, 'VerdeLux', 'VerdeLux Jazmín Absoluto',      'Absoluto de Jazmín Grasse — flor recolectada al amanecer por maestros perfumadores',           'Afrodisíaco natural. Tonifica la piel madura. Reduce la ansiedad y el insomnio.');

-- NaturPura (amazónica y ancestral)
CALL sp_insert_catalog_product(41, 'NaturPura', 'NaturPura Copaiba Virgen',      'Aceite de resina de copaiba 100% amazónico — extraído de forma sostenible por comunidades nativas', 'Potente antiinflamatorio natural. Cicatrizante. Antibacteriano de amplio espectro.');
CALL sp_insert_catalog_product(45, 'NaturPura', 'NaturPura Açaí Vitalizante',    'Pulpa de açaí liofilizada con 100% de concentración — el superalimento del Amazonas',         'Antioxidante ORAC superior. Energizante natural. Favorece la salud cardiovascular.');
CALL sp_insert_catalog_product(46, 'NaturPura', 'NaturPura Guaraná Puro',        'Polvo de guaraná orgánico sin aditivos — energía sostenida durante 6-8 horas',                 'Estimulante cognitivo natural. Mejora la concentración. Quemador de grasa suave.');
CALL sp_insert_catalog_product(47, 'NaturPura', 'NaturPura Cupuaçu Nutritivo',   'Manteca bruta de cupuaçu prensada en frío — hidratante corporal amazónica de profundidad',     'Hidratación 24 horas. Regenera la barrera cutánea. Rico en ácidos grasos esenciales.');
CALL sp_insert_catalog_product(59, 'NaturPura', 'NaturPura Camu Camu',           'Polvo de camu camu liofilizado — la fuente más concentrada de vitamina C natural del planeta', 'Inmuno-estimulante potente. Colágeno natural. Antioxidante celular de alta potencia.');

-- AromaPura (aromaterapia)
CALL sp_insert_catalog_product(61, 'AromaPura', 'AromaPura Ylang Sensorial',     'Aceite esencial de ylang-ylang indonesio de grado superior — fijador de aromas',              'Equilibra el sistema nervioso. Aphrodisiaco. Regula la producción de sebo capilar.');
CALL sp_insert_catalog_product(63, 'AromaPura', 'AromaPura Vetiver Tierra',      'Aceite esencial de vetiver de Java — raíces cosechadas a mano con 5 años de madurez',         'Grounding emocional profundo. Antiestrés. Favorece la concentración y meditación.');
CALL sp_insert_catalog_product(76, 'AromaPura', 'AromaPura Patchouli Místico',   'Aceite esencial de patchouli indonesio añejado — profundidad amaderada y terrosa',            'Afrodisíaco y calmante. Antiséptico natural. Fijador de fragancias artesanales.');
CALL sp_insert_catalog_product(85, 'AromaPura', 'AromaPura Lavanda Serena',      'Aceite esencial de lavanda provenzal en presentación aromaterapia — difusión y masajes',      'Reduce el cortisol. Favorece el sueño. Analgésico suave para tensión muscular.');
CALL sp_insert_catalog_product(88, 'AromaPura', 'AromaPura Eucalipto Vital',     'Aceite esencial de eucalipto de Provenza — grado terapéutico para respiración y ambientes',  'Expectorante natural. Descongestiona vías respiratorias. Desinfectante de ambientes.');

-- BioVita (suplementos y funcional)
CALL sp_insert_catalog_product(24, 'BioVita', 'BioVita Cúrcuma Dorada',          'Cúrcuma orgánica con pimienta negra incorporada — biodisponibilidad 20x superior',           'Antiinflamatorio sistémico. Protector hepático. Antioxidante curcuminoide de alta pureza.');
CALL sp_insert_catalog_product(25, 'BioVita', 'BioVita Ashwagandha Forte',       'Extracto estandarizado de ashwagandha con 5% withanólidos — adaptógeno supremo',             'Reduce el cortisol en un 27%. Mejora la resistencia física. Equilibrio hormonal natural.');
CALL sp_insert_catalog_product(32, 'BioVita', 'BioVita Té de Tulsi Sagrado',     'Hojas secas de Holy Basil (Tulsi) de cultivo orgánico certificado — infusión premium',       'Adaptógeno. Reduce el azúcar en sangre. Antiestrés y antimicrobiano natural.');
CALL sp_insert_catalog_product(36, 'BioVita', 'BioVita Moringa Energía',         'Polvo de moringa orgánica — 90+ nutrientes en un solo suplemento natural',                   'Energía sostenida sin estimulantes. Reduce inflamación. Rica en hierro y calcio vegetal.');
CALL sp_insert_catalog_product(40, 'BioVita', 'BioVita Triphala Detox',          'Polvo de triphala ayurvédico — fórmula ancestral de 3 frutas medicinales',                   'Depurador intestinal natural. Antioxidante. Mejora la digestión y la absorción de nutrientes.');

-- ZenBody (cosmética holística)
CALL sp_insert_catalog_product(4,  'ZenBody', 'ZenBody Arcilla Rhassoul',        'Arcilla mineral marroquí 100% natural — limpieza profunda sin irritación',                   'Regula el sebo. Purifica los poros. Apta para pieles sensibles y reactivas.');
CALL sp_insert_catalog_product(67, 'ZenBody', 'ZenBody Cacao Puro',              'Manteca de cacao virgen de prensado en frío Indonesia — hidratación corporal intensiva',      'Hidrata profundamente. Mejora la elasticidad. Antioxidante natural de la piel.');
CALL sp_insert_catalog_product(94, 'ZenBody', 'ZenBody Jabón Marsella Clásico',  'Jabón de Marsella original 72% aceite de oliva — fórmula centenaria artesanal',              'Hipoalergénico. Biodegradable. Limpieza suave apta para toda la familia.');
CALL sp_insert_catalog_product(71, 'ZenBody', 'ZenBody Lulur Ritual',            'Scrub corporal tradicional balinés con especias — exfoliación y renovación profunda',         'Elimina células muertas. Suaviza y uniformiza el tono de piel. Aromaterapia incluida.');
CALL sp_insert_catalog_product(6,  'ZenBody', 'ZenBody Jabón Beldi Hammam',      'Jabón negro marroquí de aceite de oliva y eucalipto — ritual de hammam auténtico',           'Purificante intensivo. Prepara la piel para el exfoliante. Antibacteriano natural.');

-- ─────────────────────────────────────────────────────────────
-- BLOQUE 9: Publicación de productos en sitios con precios locales
-- ─────────────────────────────────────────────────────────────

-- verdelux.co (COL — COP)
CALL sp_publish_product_on_website('https://verdelux.co',   'VerdeLux Oro de Argán',      'VerdeLux', 185000.00, '2024-11-01', 120);
CALL sp_publish_product_on_website('https://verdelux.co',   'VerdeLux Esencia de Rosas',  'VerdeLux', 350000.00, '2024-11-01',  40);
CALL sp_publish_product_on_website('https://verdelux.co',   'VerdeLux Lavanda Provenzal', 'VerdeLux', 160000.00, '2024-11-01',  80);

-- naturpura.co (COL — COP)
CALL sp_publish_product_on_website('https://naturpura.co',  'NaturPura Copaiba Virgen',   'NaturPura', 145000.00, '2024-11-15',  90);
CALL sp_publish_product_on_website('https://naturpura.co',  'NaturPura Açaí Vitalizante', 'NaturPura',  58000.00, '2024-11-15', 200);
CALL sp_publish_product_on_website('https://naturpura.co',  'NaturPura Guaraná Puro',     'NaturPura',  46000.00, '2024-11-15', 180);

-- aromapura.mx (MEX — MXN)
CALL sp_publish_product_on_website('https://aromapura.mx',  'AromaPura Ylang Sensorial',  'AromaPura',  890.00, '2024-10-01', 100);
CALL sp_publish_product_on_website('https://aromapura.mx',  'AromaPura Vetiver Tierra',   'AromaPura',  970.00, '2024-10-01',  70);
CALL sp_publish_product_on_website('https://aromapura.mx',  'AromaPura Lavanda Serena',   'AromaPura',  760.00, '2024-10-01', 130);

-- zenbody.mx (MEX — MXN)
CALL sp_publish_product_on_website('https://zenbody.mx',    'ZenBody Arcilla Rhassoul',   'ZenBody',    420.00, '2024-10-20', 150);
CALL sp_publish_product_on_website('https://zenbody.mx',    'ZenBody Jabón Marsella Clásico','ZenBody', 290.00, '2024-10-20', 250);
CALL sp_publish_product_on_website('https://zenbody.mx',    'ZenBody Cacao Puro',         'ZenBody',    550.00, '2024-10-20', 110);

-- biovita.pe (PER — PEN)
CALL sp_publish_product_on_website('https://biovita.pe',    'BioVita Cúrcuma Dorada',     'BioVita',    48.00, '2024-11-01', 200);
CALL sp_publish_product_on_website('https://biovita.pe',    'BioVita Ashwagandha Forte',  'BioVita',    89.00, '2024-11-01', 160);
CALL sp_publish_product_on_website('https://biovita.pe',    'BioVita Moringa Energía',    'BioVita',    55.00, '2024-11-01', 190);

-- naturpura.pe (PER — PEN)
CALL sp_publish_product_on_website('https://naturpura.pe',  'NaturPura Copaiba Virgen',   'NaturPura', 138.00, '2024-11-20',  80);
CALL sp_publish_product_on_website('https://naturpura.pe',  'NaturPura Cupuaçu Nutritivo','NaturPura',  72.00, '2024-11-20', 120);
CALL sp_publish_product_on_website('https://naturpura.pe',  'NaturPura Camu Camu',        'NaturPura',  95.00, '2024-11-20', 140);

-- zenbody.cl (CHL — CLP)
CALL sp_publish_product_on_website('https://zenbody.cl',    'ZenBody Arcilla Rhassoul',   'ZenBody',   14900.00, '2024-09-15', 130);
CALL sp_publish_product_on_website('https://zenbody.cl',    'ZenBody Lulur Ritual',       'ZenBody',   22900.00, '2024-09-15',  90);
CALL sp_publish_product_on_website('https://zenbody.cl',    'ZenBody Jabón Beldi Hammam', 'ZenBody',   11900.00, '2024-09-15', 170);

-- verdelux.cl (CHL — CLP)
CALL sp_publish_product_on_website('https://verdelux.cl',   'VerdeLux Oro de Argán',      'VerdeLux',  64900.00, '2024-09-30', 100);
CALL sp_publish_product_on_website('https://verdelux.cl',   'VerdeLux Rosa de Francia',   'VerdeLux', 149900.00, '2024-09-30',  30);
CALL sp_publish_product_on_website('https://verdelux.cl',   'VerdeLux Jazmín Absoluto',   'VerdeLux', 129900.00, '2024-09-30',  35);

-- aromapura.cr (CRI — CRC)
CALL sp_publish_product_on_website('https://aromapura.cr',  'AromaPura Ylang Sensorial',  'AromaPura', 28500.00, '2024-12-01',  80);
CALL sp_publish_product_on_website('https://aromapura.cr',  'AromaPura Patchouli Místico','AromaPura', 31500.00, '2024-12-01',  65);
CALL sp_publish_product_on_website('https://aromapura.cr',  'AromaPura Eucalipto Vital',  'AromaPura', 19500.00, '2024-12-01', 100);

-- ─────────────────────────────────────────────────────────────
-- BLOQUE 10: Órdenes de compra con envío
-- ─────────────────────────────────────────────────────────────

-- Colombia
CALL sp_register_order('v.rios@email.co',       'https://verdelux.co',  'VerdeLux Oro de Argán',      'VerdeLux',  2, 'DHL Express Latam',    'DHL-COL-001',  18000.00, 1001);
CALL sp_register_order('s.mora@gmail.com',      'https://verdelux.co',  'VerdeLux Lavanda Provenzal', 'VerdeLux',  1, 'Servientrega',         'SER-COL-002',  12000.00, 1004);
CALL sp_register_order('camila.h@outlook.com',  'https://naturpura.co', 'NaturPura Açaí Vitalizante', 'NaturPura', 3, 'Servientrega',         'SER-COL-003',  10000.00, 1002);
CALL sp_register_order('andres.o@email.co',     'https://naturpura.co', 'NaturPura Guaraná Puro',     'NaturPura', 2, 'DHL Express Latam',    'DHL-COL-004',  12000.00, 1002);
CALL sp_register_order('lucia.v@gmail.com',     'https://naturpura.co', 'NaturPura Copaiba Virgen',   'NaturPura', 1, 'Servientrega',         'SER-COL-005',  15000.00, 1001);

-- México
CALL sp_register_order('f.gutierrez@email.mx',  'https://aromapura.mx', 'AromaPura Ylang Sensorial',  'AromaPura', 2, 'Estafeta México',      'EST-MEX-001',  185.00, 1003);
CALL sp_register_order('m.ramirez@hotmail.com', 'https://aromapura.mx', 'AromaPura Lavanda Serena',   'AromaPura', 1, 'FedEx International',  'FDX-MEX-002',  220.00, 1004);
CALL sp_register_order('sofia.l@gmail.com',     'https://zenbody.mx',   'ZenBody Arcilla Rhassoul',   'ZenBody',   2, 'Estafeta México',      'EST-MEX-003',  150.00, 1002);
CALL sp_register_order('d.hernandez@email.mx',  'https://zenbody.mx',   'ZenBody Cacao Puro',         'ZenBody',   1, 'FedEx International',  'FDX-MEX-004',  190.00, 1003);
CALL sp_register_order('isabella.t@gmail.com',  'https://aromapura.mx', 'AromaPura Vetiver Tierra',   'AromaPura', 1, 'Estafeta México',      'EST-MEX-005',  200.00, 1003);

-- Perú
CALL sp_register_order('x.castro@email.pe',     'https://biovita.pe',   'BioVita Cúrcuma Dorada',     'BioVita',   3, 'DHL Express Latam',    'DHL-PER-001',  18.50,  1002);
CALL sp_register_order('r.silva@gmail.com',     'https://biovita.pe',   'BioVita Ashwagandha Forte',  'BioVita',   2, 'FedEx International',  'FDX-PER-002',  22.00,  1005);
CALL sp_register_order('daniela.f@outlook.com', 'https://naturpura.pe', 'NaturPura Copaiba Virgen',   'NaturPura', 1, 'DHL Express Latam',    'DHL-PER-003',  25.00,  1005);
CALL sp_register_order('m.garcia@email.pe',     'https://biovita.pe',   'BioVita Moringa Energía',    'BioVita',   2, 'FedEx International',  'FDX-PER-004',  19.00,  1006);
CALL sp_register_order('renata.m@gmail.com',    'https://naturpura.pe', 'NaturPura Camu Camu',        'NaturPura', 1, 'DHL Express Latam',    'DHL-PER-005',  22.00,  1006);

-- Chile
CALL sp_register_order('c.munoz@email.cl',      'https://zenbody.cl',   'ZenBody Arcilla Rhassoul',   'ZenBody',   2, 'DHL Express Latam',    'DHL-CHL-001',  4900.00, 1007);
CALL sp_register_order('n.perez@gmail.com',     'https://verdelux.cl',  'VerdeLux Oro de Argán',      'VerdeLux',  1, 'FedEx International',  'FDX-CHL-002',  5900.00, 1009);
CALL sp_register_order('javiera.r@hotmail.com', 'https://zenbody.cl',   'ZenBody Jabón Beldi Hammam', 'ZenBody',   3, 'DHL Express Latam',    'DHL-CHL-003',  3900.00, 1007);
CALL sp_register_order('t.soto@email.cl',       'https://verdelux.cl',  'VerdeLux Rosa de Francia',   'VerdeLux',  1, 'FedEx International',  'FDX-CHL-004',  6900.00, 1008);
CALL sp_register_order('martina.f@gmail.com',   'https://zenbody.cl',   'ZenBody Lulur Ritual',       'ZenBody',   1, 'DHL Express Latam',    'DHL-CHL-005',  4500.00, 1008);

-- Costa Rica
CALL sp_register_order('p.jimenez@email.cr',    'https://aromapura.cr', 'AromaPura Ylang Sensorial',  'AromaPura', 1, 'Correos de Costa Rica','CCR-CRI-001', 2500.00, 1009);
CALL sp_register_order('n.solis@gmail.com',     'https://aromapura.cr', 'AromaPura Patchouli Místico','AromaPura', 1, 'DHL Express Latam',    'DHL-CRI-002', 3200.00, 1010);
CALL sp_register_order('g.chaves@email.cr',     'https://aromapura.cr', 'AromaPura Eucalipto Vital',  'AromaPura', 2, 'Correos de Costa Rica','CCR-CRI-003', 2200.00, 1010);
CALL sp_register_order('valeria.m@gmail.com',   'https://aromapura.cr', 'AromaPura Ylang Sensorial',  'AromaPura', 1, 'DHL Express Latam',    'DHL-CRI-004', 2800.00, 1009);
CALL sp_register_order('e.ulate@email.cr',      'https://aromapura.cr', 'AromaPura Patchouli Místico','AromaPura', 2, 'Correos de Costa Rica','CCR-CRI-005', 2500.00, 1010);
