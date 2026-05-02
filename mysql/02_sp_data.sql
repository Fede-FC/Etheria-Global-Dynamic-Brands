-- =============================================================
--  DYNAMIC BRANDS — MySQL 8.4 — Stored Procedures v4
--  Patrones: UPSERT granular, INOUT params, EXIT HANDLER,
--  transacciones explícitas, LAST_INSERT_ID para retorno.
-- =============================================================
USE dynamic_brands_db;

-- =============================================================
-- SP DE LOG
-- =============================================================
DROP PROCEDURE IF EXISTS sp_log;
DELIMITER //
CREATE PROCEDURE sp_log(
    IN p_sp VARCHAR(100), IN p_desc TEXT, IN p_table VARCHAR(100),
    IN p_id BIGINT UNSIGNED, IN p_status VARCHAR(20), IN p_error TEXT
)
BEGIN
    INSERT INTO Process_log(sp_name, action_description, affected_table,
                            affected_record_id, status, error_detail)
    VALUES (p_sp, p_desc, p_table, p_id, p_status, p_error);
END //
DELIMITER ;

-- =============================================================
-- UPSERT: Currencies
-- =============================================================
DROP PROCEDURE IF EXISTS sp_upsert_currency;
DELIMITER //
CREATE PROCEDURE sp_upsert_currency(
    IN  p_code          CHAR(3),
    IN  p_name          VARCHAR(80),
    IN  p_symbol        VARCHAR(5),
    IN  p_is_base       TINYINT(1),
    OUT p_currency_id   INT UNSIGNED
)
BEGIN
    DECLARE v_existing INT UNSIGNED;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @err = MESSAGE_TEXT;
        CALL sp_log('sp_upsert_currency','ERROR','Currencies',NULL,p_code||' '||@err,'ERROR',@err);
        RESIGNAL;
    END;

    SELECT currency_id INTO v_existing FROM Currencies WHERE currency_code = p_code;
    IF v_existing IS NULL THEN
        INSERT INTO Currencies(currency_code,currency_name,currency_symbol,is_base)
        VALUES(p_code,p_name,p_symbol,p_is_base);
        SET p_currency_id = LAST_INSERT_ID();
        CALL sp_log('sp_upsert_currency','INSERT','Currencies',p_currency_id,p_name,'SUCCESS',NULL);
    ELSE
        UPDATE Currencies SET currency_name=p_name,currency_symbol=COALESCE(p_symbol,currency_symbol),is_base=p_is_base
        WHERE currency_id=v_existing;
        SET p_currency_id = v_existing;
        CALL sp_log('sp_upsert_currency','UPDATE','Currencies',p_currency_id,p_name,'SUCCESS',NULL);
    END IF;
END //
DELIMITER ;

-- =============================================================
-- UPSERT: Countries
-- =============================================================
DROP PROCEDURE IF EXISTS sp_upsert_country;
DELIMITER //
CREATE PROCEDURE sp_upsert_country(
    IN  p_name          VARCHAR(100),
    IN  p_iso           CHAR(3),
    IN  p_cur_id        INT UNSIGNED,
    OUT p_country_id    INT UNSIGNED
)
BEGIN
    DECLARE v_existing INT UNSIGNED;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @err = MESSAGE_TEXT;
        CALL sp_log('sp_upsert_country','ERROR','Countries',NULL,p_iso||' '||@err,'ERROR',@err);
        RESIGNAL;
    END;

    SELECT country_id INTO v_existing FROM Countries WHERE iso_code = p_iso;
    IF v_existing IS NULL THEN
        INSERT INTO Countries(country_name,iso_code,currency_id) VALUES(p_name,p_iso,p_cur_id);
        SET p_country_id = LAST_INSERT_ID();
        CALL sp_log('sp_upsert_country','INSERT','Countries',p_country_id,p_name,'SUCCESS',NULL);
    ELSE
        UPDATE Countries SET country_name=p_name,currency_id=p_cur_id WHERE country_id=v_existing;
        SET p_country_id = v_existing;
        CALL sp_log('sp_upsert_country','UPDATE','Countries',p_country_id,p_name,'SUCCESS',NULL);
    END IF;
END //
DELIMITER ;

-- =============================================================
-- UPSERT: States
-- =============================================================
DROP PROCEDURE IF EXISTS sp_upsert_state;
DELIMITER //
CREATE PROCEDURE sp_upsert_state(
    IN  p_country_id    INT UNSIGNED,
    IN  p_name          VARCHAR(100),
    IN  p_code          VARCHAR(10),
    OUT p_state_id      INT UNSIGNED
)
BEGIN
    DECLARE v_existing INT UNSIGNED;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @err = MESSAGE_TEXT;
        RESIGNAL;
    END;

    SELECT state_id INTO v_existing FROM States WHERE country_id=p_country_id AND state_code=p_code;
    IF v_existing IS NULL THEN
        INSERT INTO States(country_id,state_name,state_code) VALUES(p_country_id,p_name,p_code);
        SET p_state_id = LAST_INSERT_ID();
    ELSE
        UPDATE States SET state_name=p_name WHERE state_id=v_existing;
        SET p_state_id = v_existing;
    END IF;
END //
DELIMITER ;

-- =============================================================
-- UPSERT: Cities
-- =============================================================
DROP PROCEDURE IF EXISTS sp_upsert_city;
DELIMITER //
CREATE PROCEDURE sp_upsert_city(
    IN  p_state_id      INT UNSIGNED,
    IN  p_name          VARCHAR(100),
    OUT p_city_id       INT UNSIGNED
)
BEGIN
    DECLARE v_existing INT UNSIGNED;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @err = MESSAGE_TEXT;
        RESIGNAL;
    END;

    SELECT city_id INTO v_existing FROM Cities WHERE state_id=p_state_id AND city_name=p_name;
    IF v_existing IS NULL THEN
        INSERT INTO Cities(state_id,city_name) VALUES(p_state_id,p_name);
        SET p_city_id = LAST_INSERT_ID();
    ELSE
        SET p_city_id = v_existing;
    END IF;
END //
DELIMITER ;

-- =============================================================
-- UPSERT: Order Statuses
-- =============================================================
DROP PROCEDURE IF EXISTS sp_upsert_order_status;
DELIMITER //
CREATE PROCEDURE sp_upsert_order_status(
    IN  p_code          VARCHAR(30),
    IN  p_desc          VARCHAR(150),
    OUT p_status_id     INT UNSIGNED
)
BEGIN
    DECLARE v_existing INT UNSIGNED;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN RESIGNAL; END;

    SELECT status_id INTO v_existing FROM Order_statuses WHERE status_code=p_code;
    IF v_existing IS NULL THEN
        INSERT INTO Order_statuses(status_code,description) VALUES(p_code,p_desc);
        SET p_status_id = LAST_INSERT_ID();
    ELSE
        SET p_status_id = v_existing;
    END IF;
END //
DELIMITER ;

-- =============================================================
-- UPSERT: Shipping Statuses
-- =============================================================
DROP PROCEDURE IF EXISTS sp_upsert_shipping_status;
DELIMITER //
CREATE PROCEDURE sp_upsert_shipping_status(
    IN  p_code          VARCHAR(30),
    IN  p_desc          VARCHAR(150),
    OUT p_status_id     INT UNSIGNED
)
BEGIN
    DECLARE v_existing INT UNSIGNED;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN RESIGNAL; END;

    SELECT status_id INTO v_existing FROM Shipping_statuses WHERE status_code=p_code;
    IF v_existing IS NULL THEN
        INSERT INTO Shipping_statuses(status_code,description) VALUES(p_code,p_desc);
        SET p_status_id = LAST_INSERT_ID();
    ELSE
        SET p_status_id = v_existing;
    END IF;
END //
DELIMITER ;

-- =============================================================
-- UPSERT: Brand Focuses
-- =============================================================
DROP PROCEDURE IF EXISTS sp_upsert_brand_focus;
DELIMITER //
CREATE PROCEDURE sp_upsert_brand_focus(
    IN  p_code          VARCHAR(30),
    IN  p_name          VARCHAR(100),
    OUT p_focus_id      INT UNSIGNED
)
BEGIN
    DECLARE v_existing INT UNSIGNED;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN RESIGNAL; END;

    SELECT focus_id INTO v_existing FROM Brand_focuses WHERE focus_code=p_code;
    IF v_existing IS NULL THEN
        INSERT INTO Brand_focuses(focus_code,focus_name) VALUES(p_code,p_name);
        SET p_focus_id = LAST_INSERT_ID();
    ELSE
        SET p_focus_id = v_existing;
    END IF;
END //
DELIMITER ;

-- =============================================================
-- UPSERT: Couriers
-- =============================================================
DROP PROCEDURE IF EXISTS sp_upsert_courier;
DELIMITER //
CREATE PROCEDURE sp_upsert_courier(
    IN  p_name          VARCHAR(100),
    IN  p_contact       VARCHAR(200),
    OUT p_courier_id    INT UNSIGNED
)
BEGIN
    DECLARE v_existing INT UNSIGNED;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN RESIGNAL; END;

    SELECT courier_id INTO v_existing FROM Couriers WHERE courier_name=p_name;
    IF v_existing IS NULL THEN
        INSERT INTO Couriers(courier_name,contact_info) VALUES(p_name,p_contact);
        SET p_courier_id = LAST_INSERT_ID();
    ELSE
        SET p_courier_id = v_existing;
    END IF;
END //
DELIMITER ;

-- =============================================================
-- UPSERT: Exchange Rates
-- =============================================================
DROP PROCEDURE IF EXISTS sp_upsert_exchange_rate;
DELIMITER //
CREATE PROCEDURE sp_upsert_exchange_rate(
    IN  p_cur_id            INT UNSIGNED,
    IN  p_base_cur_id       INT UNSIGNED,
    IN  p_rate              DECIMAL(18,6),
    IN  p_date              DATE,
    IN  p_source            VARCHAR(100),
    OUT p_exchange_rate_id  INT UNSIGNED
)
BEGIN
    DECLARE v_existing INT UNSIGNED;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN RESIGNAL; END;

    SELECT exchange_rate_id INTO v_existing FROM Exchange_rates
    WHERE currency_id=p_cur_id AND base_currency_id=p_base_cur_id AND rate_date=p_date;
    IF v_existing IS NULL THEN
        INSERT INTO Exchange_rates(currency_id,base_currency_id,rate,rate_date,source)
        VALUES(p_cur_id,p_base_cur_id,p_rate,p_date,p_source);
        SET p_exchange_rate_id = LAST_INSERT_ID();
    ELSE
        UPDATE Exchange_rates SET rate=p_rate,source=p_source WHERE exchange_rate_id=v_existing;
        SET p_exchange_rate_id = v_existing;
    END IF;
END //
DELIMITER ;

-- =============================================================
-- UPSERT: Brands
-- =============================================================
DROP PROCEDURE IF EXISTS sp_upsert_brand;
DELIMITER //
CREATE PROCEDURE sp_upsert_brand(
    IN  p_name          VARCHAR(150),
    IN  p_focus_id      INT UNSIGNED,
    IN  p_ai_model      VARCHAR(50),
    IN  p_ai_params     JSON,
    IN  p_generated     TIMESTAMP,
    OUT p_brand_id      INT UNSIGNED
)
BEGIN
    DECLARE v_existing INT UNSIGNED;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN RESIGNAL; END;

    SELECT brand_id INTO v_existing FROM Brands WHERE brand_name=p_name;
    IF v_existing IS NULL THEN
        INSERT INTO Brands(brand_name,focus_id,ai_model_version,ai_generation_params,generated_at)
        VALUES(p_name,p_focus_id,p_ai_model,p_ai_params,p_generated);
        SET p_brand_id = LAST_INSERT_ID();
        CALL sp_log('sp_upsert_brand','INSERT','Brands',p_brand_id,p_name,'SUCCESS',NULL);
    ELSE
        UPDATE Brands SET focus_id=p_focus_id,ai_model_version=p_ai_model WHERE brand_id=v_existing;
        SET p_brand_id = v_existing;
        CALL sp_log('sp_upsert_brand','UPDATE','Brands',p_brand_id,p_name,'SUCCESS',NULL);
    END IF;
END //
DELIMITER ;

-- =============================================================
-- UPSERT: Customers
-- =============================================================
DROP PROCEDURE IF EXISTS sp_upsert_customer;
DELIMITER //
CREATE PROCEDURE sp_upsert_customer(
    IN  p_first         VARCHAR(80),
    IN  p_last          VARCHAR(80),
    IN  p_email         VARCHAR(150),
    IN  p_phone         VARCHAR(30),
    IN  p_country_id    INT UNSIGNED,
    OUT p_customer_id   INT UNSIGNED
)
BEGIN
    DECLARE v_existing INT UNSIGNED;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN RESIGNAL; END;

    SELECT customer_id INTO v_existing FROM Customers WHERE email=p_email;
    IF v_existing IS NULL THEN
        INSERT INTO Customers(first_name,last_name,email,phone,country_id)
        VALUES(p_first,p_last,p_email,p_phone,p_country_id);
        SET p_customer_id = LAST_INSERT_ID();
    ELSE
        UPDATE Customers SET first_name=p_first,last_name=p_last,phone=p_phone,country_id=p_country_id
        WHERE customer_id=v_existing;
        SET p_customer_id = v_existing;
    END IF;
END //
DELIMITER ;

-- =============================================================
-- SP 1 — Catálogos (orquestador de UPSERTs)
-- =============================================================
DROP PROCEDURE IF EXISTS sp_insert_catalogs;
DELIMITER //
CREATE PROCEDURE sp_insert_catalogs()
BEGIN
    DECLARE v_dummy INT UNSIGNED;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @err = MESSAGE_TEXT;
        CALL sp_log('sp_insert_catalogs','Error en catálogos',NULL,NULL,'ERROR',@err);
        RESIGNAL;
    END;

    -- Currencies
    CALL sp_upsert_currency('USD','US Dollar','$',1,v_dummy);
    CALL sp_upsert_currency('COP','Peso Colombiano','$',0,v_dummy);
    CALL sp_upsert_currency('PEN','Sol Peruano','S/',0,v_dummy);
    CALL sp_upsert_currency('MXN','Peso Mexicano','$',0,v_dummy);
    CALL sp_upsert_currency('CLP','Peso Chileno','$',0,v_dummy);
    CALL sp_upsert_currency('CRC','Colón Costarricense','₡',0,v_dummy);

    -- Order Statuses
    CALL sp_upsert_order_status('PENDING','Orden recibida',v_dummy);
    CALL sp_upsert_order_status('CONFIRMED','Pago confirmado',v_dummy);
    CALL sp_upsert_order_status('PROCESSING','En preparación',v_dummy);
    CALL sp_upsert_order_status('SHIPPED','Enviado',v_dummy);
    CALL sp_upsert_order_status('DELIVERED','Entregado',v_dummy);
    CALL sp_upsert_order_status('CANCELLED','Cancelada',v_dummy);
    CALL sp_upsert_order_status('REFUNDED','Reembolsada',v_dummy);

    -- Shipping Statuses
    CALL sp_upsert_shipping_status('PENDING','Pendiente',v_dummy);
    CALL sp_upsert_shipping_status('PICKED_UP','Recojo HUB',v_dummy);
    CALL sp_upsert_shipping_status('IN_TRANSIT','En tránsito',v_dummy);
    CALL sp_upsert_shipping_status('DELIVERED','Entregado',v_dummy);
    CALL sp_upsert_shipping_status('RETURNED','Devuelto',v_dummy);

    -- Brand Focuses
    CALL sp_upsert_brand_focus('WELLNESS','Bienestar integral',v_dummy);
    CALL sp_upsert_brand_focus('AROMATHERAPY','Aromaterapia',v_dummy);
    CALL sp_upsert_brand_focus('ECO_GREEN','Ecológico',v_dummy);
    CALL sp_upsert_brand_focus('DERMA_CARE','Dermatológico premium',v_dummy);
    CALL sp_upsert_brand_focus('HAIR_LUXURY','Lujo capilar',v_dummy);
    CALL sp_upsert_brand_focus('NATURAL_FOOD','Alimentación natural',v_dummy);

    -- Couriers
    CALL sp_upsert_courier('DHL Express','logistics@dhl.com',v_dummy);
    CALL sp_upsert_courier('FedEx International','shipping@fedex.com',v_dummy);
    CALL sp_upsert_courier('UPS Worldwide','pickup@ups.com',v_dummy);
    CALL sp_upsert_courier('Servientrega Latam','contacto@servientrega.com',v_dummy);
    CALL sp_upsert_courier('99Minutos','envios@99minutos.com',v_dummy);

    CALL sp_log('sp_insert_catalogs','Catálogos insertados','Currencies',NULL,'SUCCESS',NULL);
END //
DELIMITER ;

-- =============================================================
-- SP 2 — Geografía (con UPSERT chaining)
-- =============================================================
DROP PROCEDURE IF EXISTS sp_insert_geography;
DELIMITER //
CREATE PROCEDURE sp_insert_geography()
BEGIN
    DECLARE v_cur_usd INT UNSIGNED; DECLARE v_cur_cop INT UNSIGNED;
    DECLARE v_cur_pen INT UNSIGNED; DECLARE v_cur_mxn INT UNSIGNED;
    DECLARE v_cur_clp INT UNSIGNED; DECLARE v_cur_crc INT UNSIGNED;
    DECLARE v_cid_col INT UNSIGNED; DECLARE v_cid_per INT UNSIGNED; DECLARE v_cid_mex INT UNSIGNED;
    DECLARE v_cid_chl INT UNSIGNED; DECLARE v_cid_cri INT UNSIGNED;
    DECLARE v_st INT UNSIGNED; DECLARE v_city INT UNSIGNED;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @err = MESSAGE_TEXT;
        CALL sp_log('sp_insert_geography','Error geografía',NULL,NULL,'ERROR',@err);
        RESIGNAL;
    END;

    SELECT currency_id INTO v_cur_usd FROM Currencies WHERE currency_code='USD';
    SELECT currency_id INTO v_cur_cop FROM Currencies WHERE currency_code='COP';
    SELECT currency_id INTO v_cur_pen FROM Currencies WHERE currency_code='PEN';
    SELECT currency_id INTO v_cur_mxn FROM Currencies WHERE currency_code='MXN';
    SELECT currency_id INTO v_cur_clp FROM Currencies WHERE currency_code='CLP';
    SELECT currency_id INTO v_cur_crc FROM Currencies WHERE currency_code='CRC';

    -- Countries via UPSERT
    CALL sp_upsert_country('Colombia','COL',v_cur_cop,v_cid_col);
    CALL sp_upsert_country('Perú','PER',v_cur_pen,v_cid_per);
    CALL sp_upsert_country('México','MEX',v_cur_mxn,v_cid_mex);
    CALL sp_upsert_country('Chile','CHL',v_cur_clp,v_cid_chl);
    CALL sp_upsert_country('Costa Rica','CRI',v_cur_crc,v_cid_cri);

    -- States
    CALL sp_upsert_state(v_cid_col,'Cundinamarca','CUN',v_st);
    CALL sp_upsert_state(v_cid_col,'Antioquia','ANT',v_st);
    CALL sp_upsert_state(v_cid_per,'Lima','LIM',v_st);
    CALL sp_upsert_state(v_cid_per,'Arequipa','AQP',v_st);
    CALL sp_upsert_state(v_cid_mex,'Ciudad de México','CDMX',v_st);
    CALL sp_upsert_state(v_cid_mex,'Jalisco','JAL',v_st);
    CALL sp_upsert_state(v_cid_chl,'Región Metropolitana','RM',v_st);
    CALL sp_upsert_state(v_cid_chl,'Valparaíso','VAL',v_st);
    CALL sp_upsert_state(v_cid_cri,'San José','SJ',v_st);
    CALL sp_upsert_state(v_cid_cri,'Alajuela','AL',v_st);

    -- Cities
    SELECT state_id INTO v_st FROM States WHERE state_code='CUN';
    CALL sp_upsert_city(v_st,'Bogotá',v_city);
    SELECT state_id INTO v_st FROM States WHERE state_code='LIM';
    CALL sp_upsert_city(v_st,'Lima',v_city);
    SELECT state_id INTO v_st FROM States WHERE state_code='CDMX';
    CALL sp_upsert_city(v_st,'Ciudad de México',v_city);
    SELECT state_id INTO v_st FROM States WHERE state_code='RM';
    CALL sp_upsert_city(v_st,'Santiago',v_city);
    SELECT state_id INTO v_st FROM States WHERE state_code='SJ';
    CALL sp_upsert_city(v_st,'San José',v_city);

    CALL sp_log('sp_insert_geography','5 países insertados','Countries',NULL,'SUCCESS',NULL);
END //
DELIMITER ;

-- =============================================================
-- SP 3 — Tipos de cambio
-- =============================================================
DROP PROCEDURE IF EXISTS sp_insert_exchange_rates;
DELIMITER //
CREATE PROCEDURE sp_insert_exchange_rates()
BEGIN
    DECLARE v_usd INT UNSIGNED; DECLARE v_cop INT UNSIGNED;
    DECLARE v_pen INT UNSIGNED; DECLARE v_mxn INT UNSIGNED;
    DECLARE v_clp INT UNSIGNED; DECLARE v_crc INT UNSIGNED;
    DECLARE v_dummy INT UNSIGNED;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @err = MESSAGE_TEXT;
        CALL sp_log('sp_insert_exchange_rates','Error tipos de cambio',NULL,NULL,'ERROR',@err);
        RESIGNAL;
    END;

    SELECT currency_id INTO v_usd FROM Currencies WHERE currency_code='USD';
    SELECT currency_id INTO v_cop FROM Currencies WHERE currency_code='COP';
    SELECT currency_id INTO v_pen FROM Currencies WHERE currency_code='PEN';
    SELECT currency_id INTO v_mxn FROM Currencies WHERE currency_code='MXN';
    SELECT currency_id INTO v_clp FROM Currencies WHERE currency_code='CLP';
    SELECT currency_id INTO v_crc FROM Currencies WHERE currency_code='CRC';

    CALL sp_upsert_exchange_rate(v_usd,v_usd,1.000000,'2025-01-01','Sistema',v_dummy);
    CALL sp_upsert_exchange_rate(v_cop,v_usd,4150.000000,'2025-01-01','Banco Rep',v_dummy);
    CALL sp_upsert_exchange_rate(v_pen,v_usd,3.720000,'2025-01-01','BCRP',v_dummy);
    CALL sp_upsert_exchange_rate(v_mxn,v_usd,17.150000,'2025-01-01','Banxico',v_dummy);
    CALL sp_upsert_exchange_rate(v_clp,v_usd,920.000000,'2025-01-01','BCChile',v_dummy);
    CALL sp_upsert_exchange_rate(v_crc,v_usd,515.000000,'2025-01-01','BCCR',v_dummy);
    CALL sp_upsert_exchange_rate(v_usd,v_usd,1.000000,'2025-06-01','Sistema',v_dummy);
    CALL sp_upsert_exchange_rate(v_cop,v_usd,4200.000000,'2025-06-01','Banco Rep',v_dummy);
    CALL sp_upsert_exchange_rate(v_pen,v_usd,3.750000,'2025-06-01','BCRP',v_dummy);
    CALL sp_upsert_exchange_rate(v_mxn,v_usd,17.500000,'2025-06-01','Banxico',v_dummy);
    CALL sp_upsert_exchange_rate(v_clp,v_usd,940.000000,'2025-06-01','BCChile',v_dummy);
    CALL sp_upsert_exchange_rate(v_crc,v_usd,520.000000,'2025-06-01','BCCR',v_dummy);

    CALL sp_log('sp_insert_exchange_rates','Tipos de cambio insertados','Exchange_rates',NULL,'SUCCESS',NULL);
END //
DELIMITER ;

-- =============================================================
-- SP 4 — Marcas y Sitios Web
-- =============================================================
DROP PROCEDURE IF EXISTS sp_insert_brands_websites;
DELIMITER //
CREATE PROCEDURE sp_insert_brands_websites()
BEGIN
    DECLARE v_fw INT UNSIGNED; DECLARE v_fa INT UNSIGNED; DECLARE v_fe INT UNSIGNED;
    DECLARE v_fd INT UNSIGNED; DECLARE v_fh INT UNSIGNED;
    DECLARE v_col INT UNSIGNED; DECLARE v_per INT UNSIGNED; DECLARE v_mex INT UNSIGNED;
    DECLARE v_chl INT UNSIGNED; DECLARE v_cri INT UNSIGNED;
    DECLARE v_st_a INT UNSIGNED; DECLARE v_st_p INT UNSIGNED;
    DECLARE v_bv INT UNSIGNED; DECLARE v_bz INT UNSIGNED; DECLARE v_be INT UNSIGNED;
    DECLARE v_bp INT UNSIGNED; DECLARE v_bh INT UNSIGNED;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @err = MESSAGE_TEXT;
        CALL sp_log('sp_insert_brands_websites','Error marcas/sitios',NULL,NULL,'ERROR',@err);
        RESIGNAL;
    END;

    SELECT focus_id INTO v_fw FROM Brand_focuses WHERE focus_code='WELLNESS';
    SELECT focus_id INTO v_fa FROM Brand_focuses WHERE focus_code='AROMATHERAPY';
    SELECT focus_id INTO v_fe FROM Brand_focuses WHERE focus_code='ECO_GREEN';
    SELECT focus_id INTO v_fd FROM Brand_focuses WHERE focus_code='DERMA_CARE';
    SELECT focus_id INTO v_fh FROM Brand_focuses WHERE focus_code='HAIR_LUXURY';

    SELECT country_id INTO v_col FROM Countries WHERE iso_code='COL';
    SELECT country_id INTO v_per FROM Countries WHERE iso_code='PER';
    SELECT country_id INTO v_mex FROM Countries WHERE iso_code='MEX';
    SELECT country_id INTO v_chl FROM Countries WHERE iso_code='CHL';
    SELECT country_id INTO v_cri FROM Countries WHERE iso_code='CRI';

    SELECT status_id INTO v_st_a FROM Order_statuses WHERE status_code='CONFIRMED';
    SELECT status_id INTO v_st_p FROM Order_statuses WHERE status_code='PENDING';

    -- Brands via UPSERT
    CALL sp_upsert_brand('Vivanatura',v_fw,'AI-Gen-3.2','{"style":"organic"}','2025-01-01 10:00:00',v_bv);
    CALL sp_upsert_brand('ZenAromatics',v_fa,'AI-Gen-3.2','{"style":"zen"}','2025-01-01 10:05:00',v_bz);
    CALL sp_upsert_brand('EcoVital',v_fe,'AI-Gen-3.2','{"style":"eco"}','2025-01-01 10:10:00',v_be);
    CALL sp_upsert_brand('PuraDerma',v_fd,'AI-Gen-3.5','{"style":"clinical"}','2025-02-01 09:00:00',v_bp);
    CALL sp_upsert_brand('HairElixir',v_fh,'AI-Gen-3.5','{"style":"luxury"}','2025-02-01 09:30:00',v_bh);

    -- 9 sitios
    INSERT IGNORE INTO Websites(brand_id,country_id,site_url,marketing_focus,status_id,launch_date) VALUES
        (v_bv,v_col,'https://vivanatura.co','Bienestar integral',v_st_a,'2025-01-15'),
        (v_bz,v_col,'https://zenaromatics.co','Aromaterapia holística',v_st_a,'2025-01-20'),
        (v_bv,v_per,'https://vivanatura.pe','Vida natural',v_st_a,'2025-02-01'),
        (v_be,v_per,'https://ecovital.pe','Ecología sostenible',v_st_a,'2025-02-10'),
        (v_bp,v_mex,'https://puraderma.mx','Dermatología premium',v_st_a,'2025-03-01'),
        (v_bh,v_mex,'https://hairelixir.mx','Tratamientos capilares lujo',v_st_a,'2025-03-05'),
        (v_bp,v_chl,'https://puraderma.cl','Cuidado dermatológico',v_st_a,'2025-03-15'),
        (v_be,v_chl,'https://ecovital.cl','Productos ecológicos',v_st_p,'2025-04-01'),
        (v_bz,v_cri,'https://zenaromatics.cr','Aromaterapia pura',v_st_a,'2025-04-10');

    CALL sp_log('sp_insert_brands_websites','5 marcas y 9 sitios','Websites',NULL,'SUCCESS',NULL);
END //
DELIMITER ;

-- =============================================================
-- SP 5 — Clientes (30 en 5 países)
-- =============================================================
DROP PROCEDURE IF EXISTS sp_insert_customers;
DELIMITER //
CREATE PROCEDURE sp_insert_customers()
BEGIN
    DECLARE v_col INT UNSIGNED; DECLARE v_per INT UNSIGNED; DECLARE v_mex INT UNSIGNED;
    DECLARE v_chl INT UNSIGNED; DECLARE v_cri INT UNSIGNED;
    DECLARE v_city_bog INT UNSIGNED; DECLARE v_city_lim INT UNSIGNED;
    DECLARE v_city_cdmx INT UNSIGNED; DECLARE v_city_scl INT UNSIGNED;
    DECLARE v_city_sj INT UNSIGNED;
    DECLARE v_dummy INT UNSIGNED;
    DECLARE i INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @err = MESSAGE_TEXT;
        CALL sp_log('sp_insert_customers','Error clientes',NULL,NULL,'ERROR',@err);
        RESIGNAL;
    END;

    SELECT country_id INTO v_col FROM Countries WHERE iso_code='COL';
    SELECT country_id INTO v_per FROM Countries WHERE iso_code='PER';
    SELECT country_id INTO v_mex FROM Countries WHERE iso_code='MEX';
    SELECT country_id INTO v_chl FROM Countries WHERE iso_code='CHL';
    SELECT country_id INTO v_cri FROM Countries WHERE iso_code='CRI';

    SELECT city_id INTO v_city_bog FROM Cities WHERE city_name='Bogotá';
    SELECT city_id INTO v_city_lim FROM Cities WHERE city_name='Lima';
    SELECT city_id INTO v_city_cdmx FROM Cities WHERE city_name='Ciudad de México';
    SELECT city_id INTO v_city_scl FROM Cities WHERE city_name='Santiago';
    SELECT city_id INTO v_city_sj FROM Cities WHERE city_name='San José';

    -- Insertar direcciones (30)
    WHILE i < 6 DO
        INSERT INTO Addresses(address_line1,city_id) VALUES(CONCAT('Calle ',10+i,' #20-',30+i),v_city_bog);
        INSERT INTO Addresses(address_line1,city_id) VALUES(CONCAT('Av. Arequipa ',500+i*100),v_city_lim);
        INSERT INTO Addresses(address_line1,city_id) VALUES(CONCAT('Roma Norte, Calle ',1+i,' #100'),v_city_cdmx);
        INSERT INTO Addresses(address_line1,city_id) VALUES(CONCAT('Providencia ',1000+i*50),v_city_scl);
        INSERT INTO Addresses(address_line1,city_id) VALUES(CONCAT('Escalante, Calle ',1+i),v_city_sj);
        SET i=i+1;
    END WHILE;

    -- Insertar clientes (30) via UPSERT
    SET i=0;
    WHILE i < 6 DO
        CALL sp_upsert_customer(CONCAT('Carlos',i),'Ramirez',CONCAT('carlos',i,'@mail.com'),CONCAT('+57 300',i*1000+1234),v_col,v_dummy);
        CALL sp_upsert_customer(CONCAT('Ana',i),'Flores',CONCAT('ana',i,'@mail.com'),CONCAT('+51 987',i*1000+6543),v_per,v_dummy);
        CALL sp_upsert_customer(CONCAT('Diego',i),'Hernandez',CONCAT('diego',i,'@mail.com'),CONCAT('+52 55',i*1000+7890),v_mex,v_dummy);
        CALL sp_upsert_customer(CONCAT('Valentina',i),'Silva',CONCAT('val',i,'@mail.com'),CONCAT('+56 9',i*1000+3456),v_chl,v_dummy);
        CALL sp_upsert_customer(CONCAT('Jose',i),'Castro',CONCAT('jose',i,'@mail.com'),CONCAT('+506 ',i*1000+8901),v_cri,v_dummy);
        SET i=i+1;
    END WHILE;

    -- Vincular direcciones
    SET i=0;
    WHILE i < 30 DO
        INSERT IGNORE INTO Customer_addresses(customer_id,address_id,is_default) VALUES(i+1, i+1, 1);
        SET i=i+1;
    END WHILE;

    CALL sp_log('sp_insert_customers','30 clientes en 5 países','Customers',NULL,'SUCCESS',NULL);
END //
DELIMITER ;

-- =============================================================
-- SP 6 — Catálogo de productos por marca
-- =============================================================
DROP PROCEDURE IF EXISTS sp_insert_product_catalog;
DELIMITER //
CREATE PROCEDURE sp_insert_product_catalog()
BEGIN
    DECLARE v_bv INT UNSIGNED; DECLARE v_bz INT UNSIGNED;
    DECLARE v_be INT UNSIGNED; DECLARE v_bp INT UNSIGNED; DECLARE v_bh INT UNSIGNED;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @err = MESSAGE_TEXT;
        CALL sp_log('sp_insert_product_catalog','Error catálogo',NULL,NULL,'ERROR',@err);
        RESIGNAL;
    END;

    SELECT brand_id INTO v_bv FROM Brands WHERE brand_name='Vivanatura';
    SELECT brand_id INTO v_bz FROM Brands WHERE brand_name='ZenAromatics';
    SELECT brand_id INTO v_be FROM Brands WHERE brand_name='EcoVital';
    SELECT brand_id INTO v_bp FROM Brands WHERE brand_name='PuraDerma';
    SELECT brand_id INTO v_bh FROM Brands WHERE brand_name='HairElixir';

    -- Vivanatura: Aceites (1-20) + Bebidas (51-62) + Alimentos (63-74)
    INSERT IGNORE INTO Product_catalog(etheria_product_id,brand_id,branded_name) VALUES
        (1,v_bv,'Vivanatura Prod #1'),(2,v_bv,'Vivanatura Prod #2'),(3,v_bv,'Vivanatura Prod #3'),
        (4,v_bv,'Vivanatura Prod #4'),(5,v_bv,'Vivanatura Prod #5'),(6,v_bv,'Vivanatura Prod #6'),
        (7,v_bv,'Vivanatura Prod #7'),(8,v_bv,'Vivanatura Prod #8'),(9,v_bv,'Vivanatura Prod #9'),
        (10,v_bv,'Vivanatura Prod #10'),(11,v_bv,'Vivanatura Prod #11'),(12,v_bv,'Vivanatura Prod #12'),
        (13,v_bv,'Vivanatura Prod #13'),(14,v_bv,'Vivanatura Prod #14'),(15,v_bv,'Vivanatura Prod #15'),
        (16,v_bv,'Vivanatura Prod #16'),(17,v_bv,'Vivanatura Prod #17'),(18,v_bv,'Vivanatura Prod #18'),
        (19,v_bv,'Vivanatura Prod #19'),(20,v_bv,'Vivanatura Prod #20'),
        (51,v_bv,'Vivanatura Prod #51'),(52,v_bv,'Vivanatura Prod #52'),(53,v_bv,'Vivanatura Prod #53'),
        (54,v_bv,'Vivanatura Prod #54'),(55,v_bv,'Vivanatura Prod #55'),(56,v_bv,'Vivanatura Prod #56'),
        (57,v_bv,'Vivanatura Prod #57'),(58,v_bv,'Vivanatura Prod #58'),(59,v_bv,'Vivanatura Prod #59'),
        (60,v_bv,'Vivanatura Prod #60'),(61,v_bv,'Vivanatura Prod #61'),(62,v_bv,'Vivanatura Prod #62'),
        (63,v_bv,'Vivanatura Prod #63'),(64,v_bv,'Vivanatura Prod #64'),(65,v_bv,'Vivanatura Prod #65'),
        (66,v_bv,'Vivanatura Prod #66'),(67,v_bv,'Vivanatura Prod #67'),(68,v_bv,'Vivanatura Prod #68'),
        (69,v_bv,'Vivanatura Prod #69'),(70,v_bv,'Vivanatura Prod #70'),(71,v_bv,'Vivanatura Prod #71'),
        (72,v_bv,'Vivanatura Prod #72'),(73,v_bv,'Vivanatura Prod #73'),(74,v_bv,'Vivanatura Prod #74');

    -- ZenAromatics: Aceites (1-20) + Aromaterapia (89-100)
    INSERT IGNORE INTO Product_catalog(etheria_product_id,brand_id,branded_name) VALUES
        (1,v_bz,'ZenAromatics Prod #1'),(2,v_bz,'ZenAromatics Prod #2'),(3,v_bz,'ZenAromatics Prod #3'),
        (4,v_bz,'ZenAromatics Prod #4'),(5,v_bz,'ZenAromatics Prod #5'),(6,v_bz,'ZenAromatics Prod #6'),
        (7,v_bz,'ZenAromatics Prod #7'),(8,v_bz,'ZenAromatics Prod #8'),(9,v_bz,'ZenAromatics Prod #9'),
        (10,v_bz,'ZenAromatics Prod #10'),(11,v_bz,'ZenAromatics Prod #11'),(12,v_bz,'ZenAromatics Prod #12'),
        (13,v_bz,'ZenAromatics Prod #13'),(14,v_bz,'ZenAromatics Prod #14'),(15,v_bz,'ZenAromatics Prod #15'),
        (16,v_bz,'ZenAromatics Prod #16'),(17,v_bz,'ZenAromatics Prod #17'),(18,v_bz,'ZenAromatics Prod #18'),
        (19,v_bz,'ZenAromatics Prod #19'),(20,v_bz,'ZenAromatics Prod #20'),
        (89,v_bz,'ZenAromatics Prod #89'),(90,v_bz,'ZenAromatics Prod #90'),(91,v_bz,'ZenAromatics Prod #91'),
        (92,v_bz,'ZenAromatics Prod #92'),(93,v_bz,'ZenAromatics Prod #93'),(94,v_bz,'ZenAromatics Prod #94'),
        (95,v_bz,'ZenAromatics Prod #95'),(96,v_bz,'ZenAromatics Prod #96'),(97,v_bz,'ZenAromatics Prod #97'),
        (98,v_bz,'ZenAromatics Prod #98'),(99,v_bz,'ZenAromatics Prod #99'),(100,v_bz,'ZenAromatics Prod #100');

    -- EcoVital: Jabones (75-88) + Alimentos (63-74)
    INSERT IGNORE INTO Product_catalog(etheria_product_id,brand_id,branded_name) VALUES
        (75,v_be,'EcoVital Prod #75'),(76,v_be,'EcoVital Prod #76'),(77,v_be,'EcoVital Prod #77'),
        (78,v_be,'EcoVital Prod #78'),(79,v_be,'EcoVital Prod #79'),(80,v_be,'EcoVital Prod #80'),
        (81,v_be,'EcoVital Prod #81'),(82,v_be,'EcoVital Prod #82'),(83,v_be,'EcoVital Prod #83'),
        (84,v_be,'EcoVital Prod #84'),(85,v_be,'EcoVital Prod #85'),(86,v_be,'EcoVital Prod #86'),
        (87,v_be,'EcoVital Prod #87'),(88,v_be,'EcoVital Prod #88'),
        (63,v_be,'EcoVital Prod #63'),(64,v_be,'EcoVital Prod #64'),(65,v_be,'EcoVital Prod #65'),
        (66,v_be,'EcoVital Prod #66'),(67,v_be,'EcoVital Prod #67'),(68,v_be,'EcoVital Prod #68'),
        (69,v_be,'EcoVital Prod #69'),(70,v_be,'EcoVital Prod #70'),(71,v_be,'EcoVital Prod #71'),
        (72,v_be,'EcoVital Prod #72'),(73,v_be,'EcoVital Prod #73'),(74,v_be,'EcoVital Prod #74');

    -- PuraDerma: Cosmética (21-35)
    INSERT IGNORE INTO Product_catalog(etheria_product_id,brand_id,branded_name) VALUES
        (21,v_bp,'PuraDerma Prod #21'),(22,v_bp,'PuraDerma Prod #22'),(23,v_bp,'PuraDerma Prod #23'),
        (24,v_bp,'PuraDerma Prod #24'),(25,v_bp,'PuraDerma Prod #25'),(26,v_bp,'PuraDerma Prod #26'),
        (27,v_bp,'PuraDerma Prod #27'),(28,v_bp,'PuraDerma Prod #28'),(29,v_bp,'PuraDerma Prod #29'),
        (30,v_bp,'PuraDerma Prod #30'),(31,v_bp,'PuraDerma Prod #31'),(32,v_bp,'PuraDerma Prod #32'),
        (33,v_bp,'PuraDerma Prod #33'),(34,v_bp,'PuraDerma Prod #34'),(35,v_bp,'PuraDerma Prod #35');

    -- HairElixir: Capilar (36-50)
    INSERT IGNORE INTO Product_catalog(etheria_product_id,brand_id,branded_name) VALUES
        (36,v_bh,'HairElixir Prod #36'),(37,v_bh,'HairElixir Prod #37'),(38,v_bh,'HairElixir Prod #38'),
        (39,v_bh,'HairElixir Prod #39'),(40,v_bh,'HairElixir Prod #40'),(41,v_bh,'HairElixir Prod #41'),
        (42,v_bh,'HairElixir Prod #42'),(43,v_bh,'HairElixir Prod #43'),(44,v_bh,'HairElixir Prod #44'),
        (45,v_bh,'HairElixir Prod #45'),(46,v_bh,'HairElixir Prod #46'),(47,v_bh,'HairElixir Prod #47'),
        (48,v_bh,'HairElixir Prod #48'),(49,v_bh,'HairElixir Prod #49'),(50,v_bh,'HairElixir Prod #50');

    CALL sp_log('sp_insert_product_catalog','Catálogo por marca creado','Product_catalog',NULL,'SUCCESS',NULL);
END //
DELIMITER ;

-- =============================================================
-- SP 7 — Website_products + Precios
-- =============================================================
DROP PROCEDURE IF EXISTS sp_insert_website_products;
DELIMITER //
CREATE PROCEDURE sp_insert_website_products()
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @err = MESSAGE_TEXT;
        CALL sp_log('sp_insert_website_products','Error website products',NULL,NULL,'ERROR',@err);
        RESIGNAL;
    END;

    INSERT IGNORE INTO Website_products(website_id,catalog_product_id,is_featured)
    SELECT w.website_id, pc.catalog_product_id, (pc.catalog_product_id % 3 = 0)
    FROM Websites w
    JOIN Product_catalog pc ON w.brand_id = pc.brand_id
    WHERE w.status_id IN (SELECT status_id FROM Order_statuses WHERE status_code IN ('CONFIRMED','PENDING'))
    GROUP BY w.website_id, pc.catalog_product_id
    HAVING COUNT(*) <= 8 OR pc.catalog_product_id <= (
        SELECT MIN(c2.catalog_product_id) + 5 FROM Product_catalog c2
        JOIN Brands b2 ON c2.brand_id=b2.brand_id JOIN Websites w2 ON b2.brand_id=w2.brand_id
        WHERE w2.website_id=w.website_id
    );

    INSERT IGNORE INTO Website_product_prices(website_product_id,sale_price,currency_id,valid_from)
    SELECT wp.website_product_id,
           ROUND((12 + (wp.catalog_product_id * 2.3)) * er.rate, 2),
           c.currency_id, '2025-01-01'
    FROM Website_products wp
    JOIN Websites w ON wp.website_id=w.website_id
    JOIN Countries c ON w.country_id=c.country_id
    JOIN Exchange_rates er ON er.currency_id=c.currency_id
    AND er.rate_date = (SELECT MAX(er2.rate_date) FROM Exchange_rates er2 WHERE er2.currency_id=c.currency_id);

    CALL sp_log('sp_insert_website_products','Productos y precios publicados','Website_products',NULL,'SUCCESS',NULL);
END //
DELIMITER ;

-- =============================================================
-- SP 8 — Órdenes (27+ en 5 países)
-- =============================================================
DROP PROCEDURE IF EXISTS sp_insert_orders;
DELIMITER //
CREATE PROCEDURE sp_insert_orders()
BEGIN
    DECLARE v_col INT UNSIGNED; DECLARE v_per INT UNSIGNED; DECLARE v_mex INT UNSIGNED;
    DECLARE v_chl INT UNSIGNED; DECLARE v_cri INT UNSIGNED;
    DECLARE v_cop INT UNSIGNED; DECLARE v_pen INT UNSIGNED; DECLARE v_mxn INT UNSIGNED;
    DECLARE v_clp INT UNSIGNED; DECLARE v_crc INT UNSIGNED;
    DECLARE v_ercop INT UNSIGNED; DECLARE v_erpen INT UNSIGNED; DECLARE v_ermxn INT UNSIGNED;
    DECLARE v_erchl INT UNSIGNED; DECLARE v_ercrc INT UNSIGNED;
    DECLARE v_st_conf INT UNSIGNED; DECLARE v_st_ship INT UNSIGNED; DECLARE v_st_del INT UNSIGNED;
    DECLARE v_w1 INT UNSIGNED; DECLARE v_w2 INT UNSIGNED; DECLARE v_w3 INT UNSIGNED;
    DECLARE v_w4 INT UNSIGNED; DECLARE v_w5 INT UNSIGNED; DECLARE v_w6 INT UNSIGNED;
    DECLARE v_w7 INT UNSIGNED; DECLARE v_w8 INT UNSIGNED; DECLARE v_w9 INT UNSIGNED;
    DECLARE v_c1 INT UNSIGNED; DECLARE v_c2 INT UNSIGNED; DECLARE v_c3 INT UNSIGNED;
    DECLARE v_c4 INT UNSIGNED; DECLARE v_c5 INT UNSIGNED;
    DECLARE v_a1 INT UNSIGNED; DECLARE v_a2 INT UNSIGNED; DECLARE v_a3 INT UNSIGNED;
    DECLARE v_a4 INT UNSIGNED; DECLARE v_a5 INT UNSIGNED;
    DECLARE v_wp INT UNSIGNED;
    DECLARE v_price DECIMAL(14,4);
    DECLARE v_rate DECIMAL(18,6);
    DECLARE v_total DECIMAL(16,4);
    DECLARE v_total_base DECIMAL(16,4);
    DECLARE v_oid INT UNSIGNED;
    DECLARE v_qty INT;
    DECLARE v_i INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @err = MESSAGE_TEXT;
        CALL sp_log('sp_insert_orders','Error órdenes',NULL,NULL,'ERROR',@err);
        RESIGNAL;
    END;

    SELECT country_id INTO v_col FROM Countries WHERE iso_code='COL';
    SELECT country_id INTO v_per FROM Countries WHERE iso_code='PER';
    SELECT country_id INTO v_mex FROM Countries WHERE iso_code='MEX';
    SELECT country_id INTO v_chl FROM Countries WHERE iso_code='CHL';
    SELECT country_id INTO v_cri FROM Countries WHERE iso_code='CRI';

    SELECT currency_id INTO v_cop FROM Currencies WHERE currency_code='COP';
    SELECT currency_id INTO v_pen FROM Currencies WHERE currency_code='PEN';
    SELECT currency_id INTO v_mxn FROM Currencies WHERE currency_code='MXN';
    SELECT currency_id INTO v_clp FROM Currencies WHERE currency_code='CLP';
    SELECT currency_id INTO v_crc FROM Currencies WHERE currency_code='CRC';

    SELECT exchange_rate_id INTO v_ercop FROM Exchange_rates WHERE currency_id=v_cop ORDER BY rate_date DESC LIMIT 1;
    SELECT exchange_rate_id INTO v_erpen FROM Exchange_rates WHERE currency_id=v_pen ORDER BY rate_date DESC LIMIT 1;
    SELECT exchange_rate_id INTO v_ermxn FROM Exchange_rates WHERE currency_id=v_mxn ORDER BY rate_date DESC LIMIT 1;
    SELECT exchange_rate_id INTO v_erchl FROM Exchange_rates WHERE currency_id=v_clp ORDER BY rate_date DESC LIMIT 1;
    SELECT exchange_rate_id INTO v_ercrc FROM Exchange_rates WHERE currency_id=v_crc ORDER BY rate_date DESC LIMIT 1;

    SELECT rate INTO v_rate FROM Exchange_rates WHERE currency_id=v_cop ORDER BY rate_date DESC LIMIT 1;

    SELECT status_id INTO v_st_conf FROM Order_statuses WHERE status_code='CONFIRMED';
    SELECT status_id INTO v_st_ship FROM Order_statuses WHERE status_code='SHIPPED';
    SELECT status_id INTO v_st_del FROM Order_statuses WHERE status_code='DELIVERED';

    SELECT website_id INTO v_w1 FROM Websites WHERE site_url='https://vivanatura.co';
    SELECT website_id INTO v_w2 FROM Websites WHERE site_url='https://zenaromatics.co';
    SELECT website_id INTO v_w3 FROM Websites WHERE site_url='https://vivanatura.pe';
    SELECT website_id INTO v_w4 FROM Websites WHERE site_url='https://ecovital.pe';
    SELECT website_id INTO v_w5 FROM Websites WHERE site_url='https://puraderma.mx';
    SELECT website_id INTO v_w6 FROM Websites WHERE site_url='https://hairelixir.mx';
    SELECT website_id INTO v_w7 FROM Websites WHERE site_url='https://puraderma.cl';
    SELECT website_id INTO v_w8 FROM Websites WHERE site_url='https://ecovital.cl';
    SELECT website_id INTO v_w9 FROM Websites WHERE site_url='https://zenaromatics.cr';

    SELECT customer_id INTO v_c1 FROM Customers WHERE country_id=v_col LIMIT 1;
    SELECT customer_id INTO v_c2 FROM Customers WHERE country_id=v_per LIMIT 1;
    SELECT customer_id INTO v_c3 FROM Customers WHERE country_id=v_mex LIMIT 1;
    SELECT customer_id INTO v_c4 FROM Customers WHERE country_id=v_chl LIMIT 1;
    SELECT customer_id INTO v_c5 FROM Customers WHERE country_id=v_cri LIMIT 1;
    SELECT customer_address_id INTO v_a1 FROM Customer_addresses WHERE customer_id=v_c1 LIMIT 1;
    SELECT customer_address_id INTO v_a2 FROM Customer_addresses WHERE customer_id=v_c2 LIMIT 1;
    SELECT customer_address_id INTO v_a3 FROM Customer_addresses WHERE customer_id=v_c3 LIMIT 1;
    SELECT customer_address_id INTO v_a4 FROM Customer_addresses WHERE customer_id=v_c4 LIMIT 1;
    SELECT customer_address_id INTO v_a5 FROM Customer_addresses WHERE customer_id=v_c5 LIMIT 1;

    -- COLOMBIA: 8 órdenes
    SET v_i=0;
    WHILE v_i < 5 DO
        SELECT wp.website_product_id, wpp.sale_price INTO v_wp, v_price
        FROM Website_products wp JOIN Website_product_prices wpp ON wp.website_product_id=wpp.website_product_id
        WHERE wp.website_id=v_w1 LIMIT 1 OFFSET v_i;
        SET v_qty = 2 + (v_i % 3);
        SET v_total = v_price * v_qty;
        SET v_total_base = ROUND(v_total / v_rate, 4);
        INSERT INTO Orders(customer_id,website_id,customer_address_id,total_amount_local,currency_id,exchange_rate_id,exchange_rate_snapshot,total_amount_base,status_id,order_date)
        VALUES(v_c1,v_w1,v_a1,v_total,v_cop,v_ercop,v_rate,v_total_base,IF(v_i<3,v_st_del,v_st_ship),DATE_ADD('2025-02-01',INTERVAL v_i DAY));
        SET v_oid=LAST_INSERT_ID();
        INSERT INTO Order_items(order_id,website_product_id,quantity,unit_price,currency_id,subtotal)
        VALUES(v_oid,v_wp,v_qty,v_price,v_cop,v_total);
        SET v_i=v_i+1;
    END WHILE;

    SET v_i=0;
    WHILE v_i < 3 DO
        SELECT wp.website_product_id, wpp.sale_price INTO v_wp, v_price
        FROM Website_products wp JOIN Website_product_prices wpp ON wp.website_product_id=wpp.website_product_id
        WHERE wp.website_id=v_w2 LIMIT 1 OFFSET v_i;
        SET v_qty = 1 + (v_i % 4);
        SET v_total = v_price * v_qty;
        SET v_total_base = ROUND(v_total / v_rate, 4);
        INSERT INTO Orders(customer_id,website_id,customer_address_id,total_amount_local,currency_id,exchange_rate_id,exchange_rate_snapshot,total_amount_base,status_id,order_date)
        VALUES(v_c1,v_w2,v_a1,v_total,v_cop,v_ercop,v_rate,v_total_base,v_st_del,DATE_ADD('2025-02-10',INTERVAL v_i DAY));
        SET v_oid=LAST_INSERT_ID();
        INSERT INTO Order_items(order_id,website_product_id,quantity,unit_price,currency_id,subtotal)
        VALUES(v_oid,v_wp,v_qty,v_price,v_cop,v_total);
        SET v_i=v_i+1;
    END WHILE;

    -- PERÚ: 6 órdenes
    SELECT rate INTO v_rate FROM Exchange_rates WHERE currency_id=v_pen ORDER BY rate_date DESC LIMIT 1;
    SET v_i=0;
    WHILE v_i < 3 DO
        SELECT wp.website_product_id, wpp.sale_price INTO v_wp, v_price
        FROM Website_products wp JOIN Website_product_prices wpp ON wp.website_product_id=wpp.website_product_id
        WHERE wp.website_id=v_w3 LIMIT 1 OFFSET v_i;
        SET v_qty = 2 + (v_i % 3);
        SET v_total = v_price * v_qty;
        SET v_total_base = ROUND(v_total / v_rate, 4);
        INSERT INTO Orders(customer_id,website_id,customer_address_id,total_amount_local,currency_id,exchange_rate_id,exchange_rate_snapshot,total_amount_base,status_id,order_date)
        VALUES(v_c2,v_w3,v_a2,v_total,v_pen,v_erpen,v_rate,v_total_base,IF(v_i<2,v_st_del,v_st_conf),DATE_ADD('2025-03-01',INTERVAL v_i DAY));
        SET v_oid=LAST_INSERT_ID();
        INSERT INTO Order_items(order_id,website_product_id,quantity,unit_price,currency_id,subtotal)
        VALUES(v_oid,v_wp,v_qty,v_price,v_pen,v_total);
        SET v_i=v_i+1;
    END WHILE;

    SET v_i=0;
    WHILE v_i < 3 DO
        SELECT wp.website_product_id, wpp.sale_price INTO v_wp, v_price
        FROM Website_products wp JOIN Website_product_prices wpp ON wp.website_product_id=wpp.website_product_id
        WHERE wp.website_id=v_w4 LIMIT 1 OFFSET v_i;
        SET v_qty = 1 + (v_i % 3);
        SET v_total = v_price * v_qty;
        SET v_total_base = ROUND(v_total / v_rate, 4);
        INSERT INTO Orders(customer_id,website_id,customer_address_id,total_amount_local,currency_id,exchange_rate_id,exchange_rate_snapshot,total_amount_base,status_id,order_date)
        VALUES(v_c2,v_w4,v_a2,v_total,v_pen,v_erpen,v_rate,v_total_base,v_st_conf,DATE_ADD('2025-03-10',INTERVAL v_i DAY));
        SET v_oid=LAST_INSERT_ID();
        INSERT INTO Order_items(order_id,website_product_id,quantity,unit_price,currency_id,subtotal)
        VALUES(v_oid,v_wp,v_qty,v_price,v_pen,v_total);
        SET v_i=v_i+1;
    END WHILE;

    -- MÉXICO: 5 órdenes
    SELECT rate INTO v_rate FROM Exchange_rates WHERE currency_id=v_mxn ORDER BY rate_date DESC LIMIT 1;
    SET v_i=0;
    WHILE v_i < 3 DO
        SELECT wp.website_product_id, wpp.sale_price INTO v_wp, v_price
        FROM Website_products wp JOIN Website_product_prices wpp ON wp.website_product_id=wpp.website_product_id
        WHERE wp.website_id=v_w5 LIMIT 1 OFFSET v_i;
        SET v_qty = 1 + (v_i % 4);
        SET v_total = v_price * v_qty;
        SET v_total_base = ROUND(v_total / v_rate, 4);
        INSERT INTO Orders(customer_id,website_id,customer_address_id,total_amount_local,currency_id,exchange_rate_id,exchange_rate_snapshot,total_amount_base,status_id,order_date)
        VALUES(v_c3,v_w5,v_a3,v_total,v_mxn,v_ermxn,v_rate,v_total_base,v_st_del,DATE_ADD('2025-03-15',INTERVAL v_i DAY));
        SET v_oid=LAST_INSERT_ID();
        INSERT INTO Order_items(order_id,website_product_id,quantity,unit_price,currency_id,subtotal)
        VALUES(v_oid,v_wp,v_qty,v_price,v_mxn,v_total);
        SET v_i=v_i+1;
    END WHILE;

    SET v_i=0;
    WHILE v_i < 2 DO
        SELECT wp.website_product_id, wpp.sale_price INTO v_wp, v_price
        FROM Website_products wp JOIN Website_product_prices wpp ON wp.website_product_id=wpp.website_product_id
        WHERE wp.website_id=v_w6 LIMIT 1 OFFSET v_i;
        SET v_qty = 2 + (v_i % 3);
        SET v_total = v_price * v_qty;
        SET v_total_base = ROUND(v_total / v_rate, 4);
        INSERT INTO Orders(customer_id,website_id,customer_address_id,total_amount_local,currency_id,exchange_rate_id,exchange_rate_snapshot,total_amount_base,status_id,order_date)
        VALUES(v_c3,v_w6,v_a3,v_total,v_mxn,v_ermxn,v_rate,v_total_base,v_st_ship,DATE_ADD('2025-03-20',INTERVAL v_i DAY));
        SET v_oid=LAST_INSERT_ID();
        INSERT INTO Order_items(order_id,website_product_id,quantity,unit_price,currency_id,subtotal)
        VALUES(v_oid,v_wp,v_qty,v_price,v_mxn,v_total);
        SET v_i=v_i+1;
    END WHILE;

    -- CHILE: 4 órdenes
    SELECT rate INTO v_rate FROM Exchange_rates WHERE currency_id=v_clp ORDER BY rate_date DESC LIMIT 1;
    SET v_i=0;
    WHILE v_i < 2 DO
        SELECT wp.website_product_id, wpp.sale_price INTO v_wp, v_price
        FROM Website_products wp JOIN Website_product_prices wpp ON wp.website_product_id=wpp.website_product_id
        WHERE wp.website_id=v_w7 LIMIT 1 OFFSET v_i;
        SET v_qty = 1 + (v_i % 3);
        SET v_total = v_price * v_qty;
        SET v_total_base = ROUND(v_total / v_rate, 4);
        INSERT INTO Orders(customer_id,website_id,customer_address_id,total_amount_local,currency_id,exchange_rate_id,exchange_rate_snapshot,total_amount_base,status_id,order_date)
        VALUES(v_c4,v_w7,v_a4,v_total,v_clp,v_erchl,v_rate,v_total_base,v_st_del,DATE_ADD('2025-04-01',INTERVAL v_i DAY));
        SET v_oid=LAST_INSERT_ID();
        INSERT INTO Order_items(order_id,website_product_id,quantity,unit_price,currency_id,subtotal)
        VALUES(v_oid,v_wp,v_qty,v_price,v_clp,v_total);
        SET v_i=v_i+1;
    END WHILE;

    SET v_i=0;
    WHILE v_i < 2 DO
        SELECT wp.website_product_id, wpp.sale_price INTO v_wp, v_price
        FROM Website_products wp JOIN Website_product_prices wpp ON wp.website_product_id=wpp.website_product_id
        WHERE wp.website_id=v_w8 LIMIT 1 OFFSET v_i;
        SET v_qty = 2;
        SET v_total = v_price * v_qty;
        SET v_total_base = ROUND(v_total / v_rate, 4);
        INSERT INTO Orders(customer_id,website_id,customer_address_id,total_amount_local,currency_id,exchange_rate_id,exchange_rate_snapshot,total_amount_base,status_id,order_date)
        VALUES(v_c4,v_w8,v_a4,v_total,v_clp,v_erchl,v_rate,v_total_base,v_st_conf,DATE_ADD('2025-04-05',INTERVAL v_i DAY));
        SET v_oid=LAST_INSERT_ID();
        INSERT INTO Order_items(order_id,website_product_id,quantity,unit_price,currency_id,subtotal)
        VALUES(v_oid,v_wp,v_qty,v_price,v_clp,v_total);
        SET v_i=v_i+1;
    END WHILE;

    -- COSTA RICA: 4 órdenes
    SELECT rate INTO v_rate FROM Exchange_rates WHERE currency_id=v_crc ORDER BY rate_date DESC LIMIT 1;
    SET v_i=0;
    WHILE v_i < 4 DO
        SELECT wp.website_product_id, wpp.sale_price INTO v_wp, v_price
        FROM Website_products wp JOIN Website_product_prices wpp ON wp.website_product_id=wpp.website_product_id
        WHERE wp.website_id=v_w9 LIMIT 1 OFFSET v_i;
        SET v_qty = 1 + (v_i % 3);
        SET v_total = v_price * v_qty;
        SET v_total_base = ROUND(v_total / v_rate, 4);
        INSERT INTO Orders(customer_id,website_id,customer_address_id,total_amount_local,currency_id,exchange_rate_id,exchange_rate_snapshot,total_amount_base,status_id,order_date)
        VALUES(v_c5,v_w9,v_a5,v_total,v_crc,v_ercrc,v_rate,v_total_base,IF(v_i<2,v_st_del,v_st_ship),DATE_ADD('2025-04-10',INTERVAL v_i DAY));
        SET v_oid=LAST_INSERT_ID();
        INSERT INTO Order_items(order_id,website_product_id,quantity,unit_price,currency_id,subtotal)
        VALUES(v_oid,v_wp,v_qty,v_price,v_crc,v_total);
        SET v_i=v_i+1;
    END WHILE;

    CALL sp_log('sp_insert_orders','27 órdenes en 5 países','Orders',NULL,'SUCCESS',NULL);
END //
DELIMITER ;

-- =============================================================
-- SP 9 — Shipping records
-- =============================================================
DROP PROCEDURE IF EXISTS sp_insert_shipping;
DELIMITER //
CREATE PROCEDURE sp_insert_shipping()
BEGIN
    DECLARE v_oid INT UNSIGNED;
    DECLARE v_cur INT UNSIGNED; DECLARE v_er INT UNSIGNED;
    DECLARE v_cop INT UNSIGNED; DECLARE v_pen INT UNSIGNED;
    DECLARE v_mxn INT UNSIGNED; DECLARE v_clp INT UNSIGNED; DECLARE v_crc INT UNSIGNED;
    DECLARE v_rate_cop DECIMAL(18,6); DECLARE v_rate_pen DECIMAL(18,6);
    DECLARE v_rate_mxn DECIMAL(18,6); DECLARE v_rate_clp DECIMAL(18,6); DECLARE v_rate_crc DECIMAL(18,6);
    DECLARE v_st_del INT UNSIGNED; DECLARE v_st_tr INT UNSIGNED;
    DECLARE v_cdhl INT UNSIGNED; DECLARE v_cfed INT UNSIGNED; DECLARE v_c99 INT UNSIGNED;
    DECLARE v_sc DECIMAL(12,4); DECLARE v_scb DECIMAL(12,4); DECLARE v_rate DECIMAL(18,6);
    DECLARE done INT DEFAULT 0;
    DECLARE cur_o CURSOR FOR SELECT order_id,currency_id,exchange_rate_id,status_id FROM Orders;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done=1;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @err = MESSAGE_TEXT;
        CALL sp_log('sp_insert_shipping','Error shipping',NULL,NULL,'ERROR',@err);
        RESIGNAL;
    END;

    SELECT currency_id INTO v_cop FROM Currencies WHERE currency_code='COP';
    SELECT currency_id INTO v_pen FROM Currencies WHERE currency_code='PEN';
    SELECT currency_id INTO v_mxn FROM Currencies WHERE currency_code='MXN';
    SELECT currency_id INTO v_clp FROM Currencies WHERE currency_code='CLP';
    SELECT currency_id INTO v_crc FROM Currencies WHERE currency_code='CRC';

    SELECT rate INTO v_rate_cop FROM Exchange_rates WHERE currency_id=v_cop ORDER BY rate_date DESC LIMIT 1;
    SELECT rate INTO v_rate_pen FROM Exchange_rates WHERE currency_id=v_pen ORDER BY rate_date DESC LIMIT 1;
    SELECT rate INTO v_rate_mxn FROM Exchange_rates WHERE currency_id=v_mxn ORDER BY rate_date DESC LIMIT 1;
    SELECT rate INTO v_rate_clp FROM Exchange_rates WHERE currency_id=v_clp ORDER BY rate_date DESC LIMIT 1;
    SELECT rate INTO v_rate_crc FROM Exchange_rates WHERE currency_id=v_crc ORDER BY rate_date DESC LIMIT 1;

    SELECT status_id INTO v_st_del FROM Shipping_statuses WHERE status_code='DELIVERED';
    SELECT status_id INTO v_st_tr FROM Shipping_statuses WHERE status_code='IN_TRANSIT';
    SELECT courier_id INTO v_cdhl FROM Couriers WHERE courier_name='DHL Express';
    SELECT courier_id INTO v_cfed FROM Couriers WHERE courier_name='FedEx International';
    SELECT courier_id INTO v_c99 FROM Couriers WHERE courier_name='99Minutos';

    OPEN cur_o;
    ship_loop: LOOP
        FETCH cur_o INTO v_oid,v_cur,v_er,v_st_del;
        IF done THEN LEAVE ship_loop; END IF;

        SET v_sc = 15000 + (v_oid * 2500);

        IF v_cur = v_cop THEN SET v_rate=v_rate_cop;
        ELSEIF v_cur = v_pen THEN SET v_rate=v_rate_pen;
        ELSEIF v_cur = v_mxn THEN SET v_rate=v_rate_mxn;
        ELSEIF v_cur = v_clp THEN SET v_rate=v_rate_clp;
        ELSE SET v_rate=v_rate_crc;
        END IF;
        SET v_scb = ROUND(v_sc / v_rate, 4);

        INSERT IGNORE INTO Shipping_records(order_id,courier_id,tracking_code,shipping_cost,currency_id,
            exchange_rate_id,shipping_cost_base,estimated_delivery_date,actual_delivery_date,status_id,health_permit_number)
        VALUES(v_oid,
            CASE v_oid % 3 WHEN 0 THEN v_cdhl WHEN 1 THEN v_cfed ELSE v_c99 END,
            CONCAT('TRK-',LPAD(v_oid,6,'0')),v_sc,v_cur,v_er,v_scb,
            DATE_ADD('2025-01-01',INTERVAL (v_oid+5) DAY),
            DATE_ADD('2025-01-01',INTERVAL (v_oid+3) DAY),
            v_st_del,
            CONCAT('HP-2025-',LPAD(v_oid,4,'0')));
    END LOOP;
    CLOSE cur_o;

    CALL sp_log('sp_insert_shipping','Shipping records creados','Shipping_records',NULL,'SUCCESS',NULL);
END //
DELIMITER ;

-- =============================================================
-- SP 10 — Inventory movements
-- =============================================================
DROP PROCEDURE IF EXISTS sp_insert_inventory_movements;
DELIMITER //
CREATE PROCEDURE sp_insert_inventory_movements()
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @err = MESSAGE_TEXT;
        CALL sp_log('sp_insert_inventory_movements','Error inv movements',NULL,NULL,'ERROR',@err);
        RESIGNAL;
    END;

    INSERT INTO Inventory_movements(website_product_id,movement_type,quantity,reference_type,notes)
    SELECT website_product_id, 'IN', 500+(website_product_id*10), 'RESTOCK', 'Stock inicial'
    FROM Website_products;

    INSERT INTO Inventory_movements(website_product_id,movement_type,quantity,reference_type,notes)
    SELECT oi.website_product_id, 'OUT', 0 - CAST(oi.quantity AS SIGNED), 'ORDER', CONCAT('Orden #',oi.order_id)
    FROM Order_items oi;

    CALL sp_log('sp_insert_inventory_movements','Movimientos de inventario','Inventory_movements',NULL,'SUCCESS',NULL);
END //
DELIMITER ;

-- =============================================================
-- ORQUESTADOR v4
-- =============================================================
DROP PROCEDURE IF EXISTS sp_load_all_data;
DELIMITER //
CREATE PROCEDURE sp_load_all_data()
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @err = MESSAGE_TEXT;
        CALL sp_log('sp_load_all_data','Error carga Dynamic Brands',NULL,NULL,'ERROR',@err);
        RESIGNAL;
    END;

    SELECT '=== Dynamic Brands v4: Iniciando carga (UPSERT + INOUT) ===' AS status;

    CALL sp_insert_catalogs();
    CALL sp_insert_geography();
    CALL sp_insert_exchange_rates();
    CALL sp_insert_brands_websites();
    CALL sp_insert_customers();
    CALL sp_insert_product_catalog();
    CALL sp_insert_website_products();
    CALL sp_insert_orders();
    CALL sp_insert_shipping();
    CALL sp_insert_inventory_movements();

    CALL sp_log('sp_load_all_data','Carga completa Dynamic Brands v4',NULL,NULL,'SUCCESS',NULL);
    SELECT '=== Dynamic Brands v4: Carga completada ===' AS status;
END //
DELIMITER ;

CALL sp_load_all_data();
