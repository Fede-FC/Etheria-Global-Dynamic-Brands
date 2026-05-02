-- =============================================================
--  ETHERIA GLOBAL — SPs + Datos v4 (Refactor UPSERT + INOUT)
--  Patrones avanzados: UPSERT granular, INOUT params,
--  transacciones explícitas, manejo de excepciones.
-- =============================================================
\c etheria_global_db;

-- =============================================================
-- SP DE LOG (llamado por todos los demás SPs)
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_log(
    p_sp        VARCHAR, p_desc TEXT, p_table VARCHAR DEFAULT NULL,
    p_id        BIGINT   DEFAULT NULL, p_status VARCHAR DEFAULT 'INFO',
    p_error     TEXT     DEFAULT NULL
) LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO process_log(sp_name,action_description,affected_table,
                             affected_record_id,status,error_detail)
    VALUES(p_sp,p_desc,p_table,p_id,p_status,p_error);
END;$$;

-- =============================================================
-- UPSERT: Currencies
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_upsert_currency(
    IN  p_code          CHAR(3),
    IN  p_name          VARCHAR(80),
    IN  p_symbol        VARCHAR(5),
    IN  p_is_base       BOOLEAN,
    INOUT p_currency_id INT
) LANGUAGE plpgsql AS $$
DECLARE v_existing INT;
BEGIN
    SELECT currency_id INTO v_existing FROM currencies WHERE currency_code = p_code;
    IF v_existing IS NULL THEN
        INSERT INTO currencies(currency_code,currency_name,currency_symbol,is_base)
        VALUES(p_code,p_name,p_symbol,p_is_base) RETURNING currency_id INTO p_currency_id;
        CALL sp_log('sp_upsert_currency','INSERT','currencies',p_currency_id,p_name,'SUCCESS',NULL);
    ELSE
        UPDATE currencies SET currency_name=p_name,currency_symbol=COALESCE(p_symbol,currency_symbol),is_base=p_is_base
        WHERE currency_id=v_existing;
        p_currency_id := v_existing;
        CALL sp_log('sp_upsert_currency','UPDATE','currencies',p_currency_id,p_name,'SUCCESS',NULL);
    END IF;
EXCEPTION WHEN OTHERS THEN
    CALL sp_log('sp_upsert_currency','ERROR','currencies',NULL,p_code||' '||SQLERRM,'ERROR',SQLERRM);
    RAISE;
END;$$;

-- =============================================================
-- UPSERT: Countries
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_upsert_country(
    IN  p_name          VARCHAR(100),
    IN  p_iso           CHAR(3),
    IN  p_region        VARCHAR(100),
    IN  p_cur_id        INT,
    INOUT p_country_id  INT
) LANGUAGE plpgsql AS $$
DECLARE v_existing INT;
BEGIN
    SELECT country_id INTO v_existing FROM countries WHERE iso_code = p_iso;
    IF v_existing IS NULL THEN
        INSERT INTO countries(country_name,iso_code,region,currency_id)
        VALUES(p_name,p_iso,p_region,p_cur_id) RETURNING country_id INTO p_country_id;
        CALL sp_log('sp_upsert_country','INSERT','countries',p_country_id,p_name,'SUCCESS',NULL);
    ELSE
        UPDATE countries SET country_name=p_name,region=p_region,currency_id=p_cur_id
        WHERE country_id=v_existing;
        p_country_id := v_existing;
        CALL sp_log('sp_upsert_country','UPDATE','countries',p_country_id,p_name,'SUCCESS',NULL);
    END IF;
EXCEPTION WHEN OTHERS THEN
    CALL sp_log('sp_upsert_country','ERROR','countries',NULL,p_iso||' '||SQLERRM,'ERROR',SQLERRM);
    RAISE;
END;$$;

-- =============================================================
-- UPSERT: States
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_upsert_state(
    IN  p_country_id    INT,
    IN  p_name          VARCHAR(100),
    IN  p_code          VARCHAR(10),
    INOUT p_state_id    INT
) LANGUAGE plpgsql AS $$
DECLARE v_existing INT;
BEGIN
    SELECT state_id INTO v_existing FROM states WHERE country_id=p_country_id AND state_code=p_code;
    IF v_existing IS NULL THEN
        INSERT INTO states(country_id,state_name,state_code)
        VALUES(p_country_id,p_name,p_code) RETURNING state_id INTO p_state_id;
    ELSE
        UPDATE states SET state_name=p_name WHERE state_id=v_existing;
        p_state_id := v_existing;
    END IF;
END;$$;

-- =============================================================
-- UPSERT: Cities
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_upsert_city(
    IN  p_state_id      INT,
    IN  p_name          VARCHAR(100),
    INOUT p_city_id     INT
) LANGUAGE plpgsql AS $$
DECLARE v_existing INT;
BEGIN
    SELECT city_id INTO v_existing FROM cities WHERE state_id=p_state_id AND city_name=p_name;
    IF v_existing IS NULL THEN
        INSERT INTO cities(state_id,city_name) VALUES(p_state_id,p_name) RETURNING city_id INTO p_city_id;
    ELSE
        p_city_id := v_existing;
    END IF;
END;$$;

-- =============================================================
-- INSERT: Addresses (no upsert — se versionan)
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_insert_address(
    IN  p_line1         VARCHAR(200),
    IN  p_city_id       INT,
    IN  p_postal        VARCHAR(20) DEFAULT NULL,
    INOUT p_address_id  INT
) LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO addresses(address_line1,city_id,postal_code)
    VALUES(p_line1,p_city_id,p_postal) RETURNING address_id INTO p_address_id;
END;$$;

-- =============================================================
-- UPSERT: Categories
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_upsert_category(
    IN  p_name          VARCHAR(100),
    IN  p_desc          VARCHAR(300),
    INOUT p_category_id INT
) LANGUAGE plpgsql AS $$
DECLARE v_existing INT;
BEGIN
    SELECT category_id INTO v_existing FROM categories WHERE category_name=p_name;
    IF v_existing IS NULL THEN
        INSERT INTO categories(category_name,description) VALUES(p_name,p_desc) RETURNING category_id INTO p_category_id;
    ELSE
        UPDATE categories SET description=COALESCE(p_desc,description) WHERE category_id=v_existing;
        p_category_id := v_existing;
    END IF;
END;$$;

-- =============================================================
-- UPSERT: MeasurementUnits
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_upsert_unit(
    IN  p_code          VARCHAR(10),
    IN  p_name          VARCHAR(40),
    IN  p_type          VARCHAR(20),
    INOUT p_unit_id     INT
) LANGUAGE plpgsql AS $$
DECLARE v_existing INT;
BEGIN
    SELECT unit_id INTO v_existing FROM measurement_units WHERE unit_code=p_code;
    IF v_existing IS NULL THEN
        INSERT INTO measurement_units(unit_code,unit_name,unit_type) VALUES(p_code,p_name,p_type) RETURNING unit_id INTO p_unit_id;
    ELSE
        p_unit_id := v_existing;
    END IF;
END;$$;

-- =============================================================
-- UPSERT: Products
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_upsert_product(
    IN  p_name          VARCHAR(150),
    IN  p_cat_id        INT,
    IN  p_unit_id       INT,
    IN  p_weight        DECIMAL(10,4),
    IN  p_origin_id     INT,
    INOUT p_product_id  INT
) LANGUAGE plpgsql AS $$
DECLARE v_existing INT;
BEGIN
    SELECT product_id INTO v_existing FROM products WHERE product_name=p_name;
    IF v_existing IS NULL THEN
        INSERT INTO products(product_name,category_id,unit_id,unit_weight_kg,origin_country_id)
        VALUES(p_name,p_cat_id,p_unit_id,p_weight,p_origin_id) RETURNING product_id INTO p_product_id;
    ELSE
        p_product_id := v_existing;
    END IF;
END;$$;

-- =============================================================
-- UPSERT: Suppliers
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_upsert_supplier(
    IN  p_name          VARCHAR(150),
    IN  p_country_id    INT,
    IN  p_email         VARCHAR(150),
    IN  p_phone         VARCHAR(30),
    INOUT p_supplier_id INT
) LANGUAGE plpgsql AS $$
DECLARE v_existing INT;
BEGIN
    SELECT supplier_id INTO v_existing FROM suppliers WHERE supplier_name=p_name;
    IF v_existing IS NULL THEN
        INSERT INTO suppliers(supplier_name,country_id,contact_email,contact_phone)
        VALUES(p_name,p_country_id,p_email,p_phone) RETURNING supplier_id INTO p_supplier_id;
    ELSE
        UPDATE suppliers SET country_id=p_country_id,contact_email=p_email,contact_phone=p_phone WHERE supplier_id=v_existing;
        p_supplier_id := v_existing;
    END IF;
END;$$;

-- =============================================================
-- UPSERT: Exchange Rates
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_upsert_exchange_rate(
    IN  p_cur_id            INT,
    IN  p_base_cur_id       INT,
    IN  p_rate              DECIMAL(18,6),
    IN  p_date              DATE,
    IN  p_source            VARCHAR(100),
    INOUT p_exchange_rate_id INT
) LANGUAGE plpgsql AS $$
DECLARE v_existing INT;
BEGIN
    SELECT exchange_rate_id INTO v_existing FROM exchange_rates WHERE currency_id=p_cur_id AND base_currency_id=p_base_cur_id AND rate_date=p_date;
    IF v_existing IS NULL THEN
        INSERT INTO exchange_rates(currency_id,base_currency_id,rate,rate_date,source)
        VALUES(p_cur_id,p_base_cur_id,p_rate,p_date,p_source) RETURNING exchange_rate_id INTO p_exchange_rate_id;
    ELSE
        UPDATE exchange_rates SET rate=p_rate,source=p_source WHERE exchange_rate_id=v_existing;
        p_exchange_rate_id := v_existing;
    END IF;
END;$$;

-- =============================================================
-- UPSERT: Import Statuses
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_upsert_import_status(
    IN  p_code          VARCHAR(30),
    IN  p_desc          VARCHAR(150),
    INOUT p_status_id   INT
) LANGUAGE plpgsql AS $$
DECLARE v_existing INT;
BEGIN
    SELECT status_id INTO v_existing FROM import_statuses WHERE status_code=p_code;
    IF v_existing IS NULL THEN
        INSERT INTO import_statuses(status_code,description) VALUES(p_code,p_desc) RETURNING status_id INTO p_status_id;
    ELSE
        p_status_id := v_existing;
    END IF;
END;$$;

-- =============================================================
-- UPSERT: Cost Types
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_upsert_cost_type(
    IN  p_code          VARCHAR(30),
    IN  p_name          VARCHAR(100),
    IN  p_applies       VARCHAR(30),
    INOUT p_cost_type_id INT
) LANGUAGE plpgsql AS $$
DECLARE v_existing INT;
BEGIN
    SELECT cost_type_id INTO v_existing FROM cost_types WHERE cost_type_code=p_code;
    IF v_existing IS NULL THEN
        INSERT INTO cost_types(cost_type_code,cost_type_name,applies_to) VALUES(p_code,p_name,p_applies) RETURNING cost_type_id INTO p_cost_type_id;
    ELSE
        p_cost_type_id := v_existing;
    END IF;
END;$$;

-- =============================================================
-- UPSERT: Permit Types
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_upsert_permit_type(
    IN  p_code          VARCHAR(30),
    IN  p_name          VARCHAR(100),
    IN  p_authority     VARCHAR(150),
    INOUT p_permit_type_id INT
) LANGUAGE plpgsql AS $$
DECLARE v_existing INT;
BEGIN
    SELECT permit_type_id INTO v_existing FROM permit_types WHERE permit_type_code=p_code;
    IF v_existing IS NULL THEN
        INSERT INTO permit_types(permit_type_code,permit_type_name,issuing_authority) VALUES(p_code,p_name,p_authority) RETURNING permit_type_id INTO p_permit_type_id;
    ELSE
        p_permit_type_id := v_existing;
    END IF;
END;$$;

-- =============================================================
-- UPSERT: Warehouse Types
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_upsert_warehouse_type(
    IN  p_code          VARCHAR(20),
    IN  p_name          VARCHAR(60),
    INOUT p_warehouse_type_id INT
) LANGUAGE plpgsql AS $$
DECLARE v_existing INT;
BEGIN
    SELECT warehouse_type_id INTO v_existing FROM warehouse_types WHERE type_code=p_code;
    IF v_existing IS NULL THEN
        INSERT INTO warehouse_types(type_code,type_name) VALUES(p_code,p_name) RETURNING warehouse_type_id INTO p_warehouse_type_id;
    ELSE
        p_warehouse_type_id := v_existing;
    END IF;
END;$$;

-- =============================================================
-- UPSERT: Warehouses
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_upsert_warehouse(
    IN  p_name          VARCHAR(100),
    IN  p_addr_id       INT,
    IN  p_type_id       INT,
    IN  p_capacity      INT,
    INOUT p_warehouse_id INT
) LANGUAGE plpgsql AS $$
DECLARE v_existing INT;
BEGIN
    SELECT warehouse_id INTO v_existing FROM warehouses WHERE warehouse_name=p_name;
    IF v_existing IS NULL THEN
        INSERT INTO warehouses(warehouse_name,address_id,warehouse_type_id,capacity_units)
        VALUES(p_name,p_addr_id,p_type_id,p_capacity) RETURNING warehouse_id INTO p_warehouse_id;
    ELSE
        UPDATE warehouses SET address_id=p_addr_id,warehouse_type_id=p_type_id,capacity_units=p_capacity WHERE warehouse_id=v_existing;
        p_warehouse_id := v_existing;
    END IF;
END;$$;

-- =============================================================
-- SP 1 — Catálogos base (orquestador de UPSERTs)
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_insert_catalogs()
LANGUAGE plpgsql AS $$
DECLARE
    v_err TEXT;
    v_dummy INT;
BEGIN
    -- Currencies
    CALL sp_upsert_currency('USD','US Dollar','$',TRUE,v_dummy);
    CALL sp_upsert_currency('COP','Peso Colombiano','$',FALSE,v_dummy);
    CALL sp_upsert_currency('PEN','Sol Peruano','S/',FALSE,v_dummy);
    CALL sp_upsert_currency('MXN','Peso Mexicano','$',FALSE,v_dummy);
    CALL sp_upsert_currency('CLP','Peso Chileno','$',FALSE,v_dummy);
    CALL sp_upsert_currency('CRC','Colón Costarricense','₡',FALSE,v_dummy);

    -- Categories
    CALL sp_upsert_category('Aceites Esenciales','Aceites naturales para aromaterapia y uso tópico',v_dummy);
    CALL sp_upsert_category('Cosmética Dermatológica','Productos para el cuidado de la piel',v_dummy);
    CALL sp_upsert_category('Capilar','Productos para el cuidado del cabello',v_dummy);
    CALL sp_upsert_category('Bebidas Naturales','Bebidas funcionales y saludables',v_dummy);
    CALL sp_upsert_category('Alimentos Funcionales','Alimentos con propiedades medicinales',v_dummy);
    CALL sp_upsert_category('Jabones Artesanales','Jabones naturales y orgánicos',v_dummy);
    CALL sp_upsert_category('Aromaterapia','Difusores y mezclas aromáticas',v_dummy);

    -- MeasurementUnits
    CALL sp_upsert_unit('KG','Kilogramo','WEIGHT',v_dummy);
    CALL sp_upsert_unit('G','Gramo','WEIGHT',v_dummy);
    CALL sp_upsert_unit('L','Litro','VOLUME',v_dummy);
    CALL sp_upsert_unit('ML','Mililitro','VOLUME',v_dummy);
    CALL sp_upsert_unit('UN','Unidad','UNIT',v_dummy);

    -- CostTypes
    CALL sp_upsert_cost_type('FLETE','Flete Marítimo','LOGISTIC',v_dummy);
    CALL sp_upsert_cost_type('SEGURO','Seguro de Carga','LOGISTIC',v_dummy);
    CALL sp_upsert_cost_type('PUERTO','Manejo Portuario','LOGISTIC',v_dummy);
    CALL sp_upsert_cost_type('ARANCEL_GEN','Arancel General de Importación','TARIFF',v_dummy);
    CALL sp_upsert_cost_type('IVA_IMPORT','IVA en Importación','TARIFF',v_dummy);
    CALL sp_upsert_cost_type('PERMISO_SAN','Permiso Sanitario','PERMIT',v_dummy);
    CALL sp_upsert_cost_type('PERMISO_COSM','Registro Cosmético','PERMIT',v_dummy);
    CALL sp_upsert_cost_type('COURIER','Envío Courier al Cliente','SHIPPING',v_dummy);
    CALL sp_upsert_cost_type('ALMACEN','Almacenamiento HUB','OTHER',v_dummy);

    -- PermitTypes
    CALL sp_upsert_permit_type('INVIMA','Registro INVIMA Colombia','INVIMA Colombia',v_dummy);
    CALL sp_upsert_permit_type('DIGEMID','Registro DIGEMID Perú','DIGEMID Perú',v_dummy);
    CALL sp_upsert_permit_type('COFEPRIS','Registro COFEPRIS México','COFEPRIS México',v_dummy);
    CALL sp_upsert_permit_type('ISP','Registro ISP Chile','ISP Chile',v_dummy);
    CALL sp_upsert_permit_type('MINSA_CRI','Registro MINSA Costa Rica','MINSA Costa Rica',v_dummy);

    -- ImportStatuses
    CALL sp_upsert_import_status('PENDING','Pendiente de envío',v_dummy);
    CALL sp_upsert_import_status('SHIPPED','En tránsito',v_dummy);
    CALL sp_upsert_import_status('RECEIVED','Recibido en HUB',v_dummy);
    CALL sp_upsert_import_status('DISPATCHED','Despachado al país destino',v_dummy);
    CALL sp_upsert_import_status('CANCELLED','Cancelado',v_dummy);
    CALL sp_upsert_import_status('ACTIVE','Activo',v_dummy);
    CALL sp_upsert_import_status('EXPIRED','Expirado',v_dummy);
    CALL sp_upsert_import_status('REJECTED','Rechazado',v_dummy);

    -- WarehouseTypes
    CALL sp_upsert_warehouse_type('RECEIVING','Recepción de Mercancía',v_dummy);
    CALL sp_upsert_warehouse_type('LABELING','Etiquetado de Marca',v_dummy);
    CALL sp_upsert_warehouse_type('DISPATCH','Despacho a País Destino',v_dummy);
    CALL sp_upsert_warehouse_type('MIXED','Multipropósito',v_dummy);

    CALL sp_log('sp_insert_catalogs','Catálogos base insertados exitosamente','categories',NULL,'SUCCESS',NULL);

EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    CALL sp_log('sp_insert_catalogs','Error en inserción de catálogos',NULL,NULL,'ERROR',v_err);
    RAISE;
END;$$;

-- =============================================================
-- SP 2 — Geografía (con UPSERT chaining)
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_insert_geography()
LANGUAGE plpgsql AS $$
DECLARE
    v_cur_usd INT; v_cur_cop INT; v_cur_pen INT;
    v_cur_mxn INT; v_cur_clp INT; v_cur_crc INT;
    v_cid_col INT; v_cid_per INT; v_cid_mex INT;
    v_cid_chl INT; v_cid_cri INT; v_cid_nic INT;
    v_st INT; v_city INT; v_addr INT;
    v_err TEXT;
BEGIN
    -- Get currency IDs
    SELECT currency_id INTO v_cur_usd FROM currencies WHERE currency_code='USD';
    SELECT currency_id INTO v_cur_cop FROM currencies WHERE currency_code='COP';
    SELECT currency_id INTO v_cur_pen FROM currencies WHERE currency_code='PEN';
    SELECT currency_id INTO v_cur_mxn FROM currencies WHERE currency_code='MXN';
    SELECT currency_id INTO v_cur_clp FROM currencies WHERE currency_code='CLP';
    SELECT currency_id INTO v_cur_crc FROM currencies WHERE currency_code='CRC';

    -- Countries via UPSERT
    CALL sp_upsert_country('Colombia','COL','Latinoamérica',v_cur_cop,v_cid_col);
    CALL sp_upsert_country('Perú','PER','Latinoamérica',v_cur_pen,v_cid_per);
    CALL sp_upsert_country('México','MEX','Latinoamérica',v_cur_mxn,v_cid_mex);
    CALL sp_upsert_country('Chile','CHL','Latinoamérica',v_cur_clp,v_cid_chl);
    CALL sp_upsert_country('Costa Rica','CRI','Centroamérica',v_cur_crc,v_cid_cri);
    CALL sp_upsert_country('Nicaragua','NIC','Centroamérica',v_cur_usd,v_cid_nic);

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
    CALL sp_upsert_state(v_cid_nic,'Managua','MAN',v_st);
    CALL sp_upsert_state(v_cid_nic,'Región Autónoma Caribe Sur','RACS',v_st);

    -- Cities
    SELECT state_id INTO v_st FROM states WHERE state_code='CUN';
    CALL sp_upsert_city(v_st,'Bogotá',v_city);
    SELECT state_id INTO v_st FROM states WHERE state_code='LIM';
    CALL sp_upsert_city(v_st,'Lima',v_city);
    SELECT state_id INTO v_st FROM states WHERE state_code='CDMX';
    CALL sp_upsert_city(v_st,'Ciudad de México',v_city);
    SELECT state_id INTO v_st FROM states WHERE state_code='RM';
    CALL sp_upsert_city(v_st,'Santiago',v_city);
    SELECT state_id INTO v_st FROM states WHERE state_code='SJ';
    CALL sp_upsert_city(v_st,'San José',v_city);
    SELECT state_id INTO v_st FROM states WHERE state_code='RACS';
    CALL sp_upsert_city(v_st,'Bluefields',v_city);

    -- Dirección del HUB Nicaragua
    CALL sp_insert_address('Puerto de Bluefields, Zona Franca Caribe Sur',v_city,NULL,v_addr);

    CALL sp_log('sp_insert_geography','Geografía insertada: 6 países','countries',NULL,'SUCCESS',NULL);
EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    CALL sp_log('sp_insert_geography','Error geografía',NULL,NULL,'ERROR',v_err);
    RAISE;
END;$$;

-- =============================================================
-- SP 3 — Tipos de cambio históricos
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_insert_exchange_rates()
LANGUAGE plpgsql AS $$
DECLARE
    v_usd INT; v_cop INT; v_pen INT; v_mxn INT; v_clp INT; v_crc INT;
    v_dummy INT;
    v_err TEXT;
BEGIN
    SELECT currency_id INTO v_usd FROM currencies WHERE currency_code='USD';
    SELECT currency_id INTO v_cop FROM currencies WHERE currency_code='COP';
    SELECT currency_id INTO v_pen FROM currencies WHERE currency_code='PEN';
    SELECT currency_id INTO v_mxn FROM currencies WHERE currency_code='MXN';
    SELECT currency_id INTO v_clp FROM currencies WHERE currency_code='CLP';
    SELECT currency_id INTO v_crc FROM currencies WHERE currency_code='CRC';

    -- USD→USD self-reference (needed for imports priced in base currency)
    CALL sp_upsert_exchange_rate(v_usd,v_usd,1.000000,'2025-01-01','Sistema',v_dummy);
    CALL sp_upsert_exchange_rate(v_usd,v_usd,1.000000,'2025-06-01','Sistema',v_dummy);

    CALL sp_upsert_exchange_rate(v_cop,v_usd,4150.000000,'2025-01-01','Banco de la República',v_dummy);
    CALL sp_upsert_exchange_rate(v_pen,v_usd,3.720000,'2025-01-01','BCRP',v_dummy);
    CALL sp_upsert_exchange_rate(v_mxn,v_usd,17.150000,'2025-01-01','Banxico',v_dummy);
    CALL sp_upsert_exchange_rate(v_clp,v_usd,920.000000,'2025-01-01','Banco Central de Chile',v_dummy);
    CALL sp_upsert_exchange_rate(v_crc,v_usd,515.000000,'2025-01-01','BCCR',v_dummy);
    CALL sp_upsert_exchange_rate(v_cop,v_usd,4200.000000,'2025-06-01','Banco de la República',v_dummy);
    CALL sp_upsert_exchange_rate(v_pen,v_usd,3.750000,'2025-06-01','BCRP',v_dummy);
    CALL sp_upsert_exchange_rate(v_mxn,v_usd,17.500000,'2025-06-01','Banxico',v_dummy);
    CALL sp_upsert_exchange_rate(v_clp,v_usd,940.000000,'2025-06-01','Banco Central de Chile',v_dummy);
    CALL sp_upsert_exchange_rate(v_crc,v_usd,520.000000,'2025-06-01','BCCR',v_dummy);

    CALL sp_log('sp_insert_exchange_rates','Tipos de cambio insertados','exchange_rates',NULL,'SUCCESS',NULL);
EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    CALL sp_log('sp_insert_exchange_rates','Error tipos de cambio',NULL,NULL,'ERROR',v_err);
    RAISE;
END;$$;

-- =============================================================
-- SP 4 — Proveedores y almacenes
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_insert_suppliers_warehouses()
LANGUAGE plpgsql AS $$
DECLARE
    v_cid_ind INT; v_cid_fra INT; v_cid_bra INT; v_cid_nic INT;
    v_cur_usd INT; v_wt INT; v_addr INT; v_city INT; v_wh INT;
    v_sup INT;
    v_err TEXT;
BEGIN
    SELECT currency_id INTO v_cur_usd FROM currencies WHERE currency_code='USD';

    -- Países de origen (pueden no existir en geography SP)
    CALL sp_upsert_country('India','IND','Asia',v_cur_usd,v_cid_ind);
    CALL sp_upsert_country('Francia','FRA','Europa',v_cur_usd,v_cid_fra);
    CALL sp_upsert_country('Brasil','BRA','Latinoamérica',v_cur_usd,v_cid_bra);
    SELECT country_id INTO v_cid_nic FROM countries WHERE iso_code='NIC';

    -- Proveedores via UPSERT
    CALL sp_upsert_supplier('Himalaya Naturals Ltd',v_cid_ind,'procurement@himalaya-naturals.com','+91-22-12345678',v_sup);
    CALL sp_upsert_supplier('Provence Arômes SARL',v_cid_fra,'contact@provence-aromes.fr','+33-4-90123456',v_sup);
    CALL sp_upsert_supplier('AmazonBio Exportações Ltda',v_cid_bra,'export@amazonbio.com.br','+55-92-98765432',v_sup);
    CALL sp_upsert_supplier('Pacific Wellness Co.',v_cid_ind,'sales@pacificwellness.in','+91-80-87654321',v_sup);
    CALL sp_upsert_supplier('Andean Roots S.A.',v_cid_bra,'info@andeanroots.com','+55-11-11223344',v_sup);

    -- Almacenes HUB Nicaragua
    SELECT city_id INTO v_city FROM cities WHERE city_name='Bluefields';
    SELECT address_id INTO v_addr FROM addresses WHERE city_id=v_city LIMIT 1;

    SELECT warehouse_type_id INTO v_wt FROM warehouse_types WHERE type_code='RECEIVING';
    CALL sp_upsert_warehouse('HUB-A Recepción Caribe',v_addr,v_wt,5000,v_wh);
    SELECT warehouse_type_id INTO v_wt FROM warehouse_types WHERE type_code='LABELING';
    CALL sp_upsert_warehouse('HUB-B Etiquetado y Marcas',v_addr,v_wt,3000,v_wh);
    SELECT warehouse_type_id INTO v_wt FROM warehouse_types WHERE type_code='DISPATCH';
    CALL sp_upsert_warehouse('HUB-C Despacho Internacional',v_addr,v_wt,4000,v_wh);

    CALL sp_log('sp_insert_suppliers_warehouses','5 proveedores y 3 almacenes insertados',NULL,NULL,'SUCCESS',NULL);
EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    CALL sp_log('sp_insert_suppliers_warehouses','Error proveedores/almacenes',NULL,NULL,'ERROR',v_err);
    RAISE;
END;$$;

-- =============================================================
-- SP 5 — Productos (100 distribuidos en 7 categorías)
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_insert_products()
LANGUAGE plpgsql AS $$
DECLARE
    v_cat_ace INT; v_cat_cos INT; v_cat_cap INT; v_cat_beb INT;
    v_cat_ali INT; v_cat_jab INT; v_cat_aro INT;
    v_unit_l INT; v_unit_ml INT; v_unit_kg INT; v_unit_g INT; v_unit_un INT;
    v_cid_ind INT; v_cid_bra INT; v_cid_fra INT;
    v_prod INT; v_err TEXT;
BEGIN
    SELECT category_id INTO v_cat_ace FROM categories WHERE category_name='Aceites Esenciales';
    SELECT category_id INTO v_cat_cos FROM categories WHERE category_name='Cosmética Dermatológica';
    SELECT category_id INTO v_cat_cap FROM categories WHERE category_name='Capilar';
    SELECT category_id INTO v_cat_beb FROM categories WHERE category_name='Bebidas Naturales';
    SELECT category_id INTO v_cat_ali FROM categories WHERE category_name='Alimentos Funcionales';
    SELECT category_id INTO v_cat_jab FROM categories WHERE category_name='Jabones Artesanales';
    SELECT category_id INTO v_cat_aro FROM categories WHERE category_name='Aromaterapia';
    SELECT unit_id INTO v_unit_l   FROM measurement_units WHERE unit_code='L';
    SELECT unit_id INTO v_unit_ml  FROM measurement_units WHERE unit_code='ML';
    SELECT unit_id INTO v_unit_kg  FROM measurement_units WHERE unit_code='KG';
    SELECT unit_id INTO v_unit_g   FROM measurement_units WHERE unit_code='G';
    SELECT unit_id INTO v_unit_un  FROM measurement_units WHERE unit_code='UN';
    SELECT country_id INTO v_cid_ind FROM countries WHERE iso_code='IND';
    SELECT country_id INTO v_cid_bra FROM countries WHERE iso_code='BRA';
    SELECT country_id INTO v_cid_fra FROM countries WHERE iso_code='FRA';

    -- Aceites Esenciales (19 productos)
    CALL sp_upsert_product('Aceite Esencial de Lavanda 30ml',v_cat_ace,v_unit_ml,0.05,v_cid_fra,v_prod);
    CALL sp_upsert_product('Aceite Esencial de Árbol de Té 30ml',v_cat_ace,v_unit_ml,0.05,v_cid_ind,v_prod);
    CALL sp_upsert_product('Aceite Esencial de Eucalipto 50ml',v_cat_ace,v_unit_ml,0.08,v_cid_ind,v_prod);
    CALL sp_upsert_product('Aceite Esencial de Rosa Mosqueta 30ml',v_cat_ace,v_unit_ml,0.05,v_cid_bra,v_prod);
    CALL sp_upsert_product('Aceite Esencial de Menta 30ml',v_cat_ace,v_unit_ml,0.05,v_cid_ind,v_prod);
    CALL sp_upsert_product('Aceite de Coco Virgen 500ml',v_cat_ace,v_unit_ml,0.55,v_cid_ind,v_prod);
    CALL sp_upsert_product('Aceite de Argán Puro 100ml',v_cat_ace,v_unit_ml,0.12,v_cid_ind,v_prod);
    CALL sp_upsert_product('Aceite de Jojoba 100ml',v_cat_ace,v_unit_ml,0.12,v_cid_ind,v_prod);
    CALL sp_upsert_product('Aceite de Almendras Dulces 250ml',v_cat_ace,v_unit_ml,0.27,v_cid_ind,v_prod);
    CALL sp_upsert_product('Aceite Esencial de Bergamota 15ml',v_cat_ace,v_unit_ml,0.03,v_cid_fra,v_prod);
    CALL sp_upsert_product('Aceite Esencial de Ylang Ylang 15ml',v_cat_ace,v_unit_ml,0.03,v_cid_ind,v_prod);
    CALL sp_upsert_product('Aceite Esencial de Limón 30ml',v_cat_ace,v_unit_ml,0.05,v_cid_bra,v_prod);
    CALL sp_upsert_product('Aceite Esencial de Naranja Dulce 30ml',v_cat_ace,v_unit_ml,0.05,v_cid_bra,v_prod);
    CALL sp_upsert_product('Aceite de Hemp Cáñamo 100ml',v_cat_ace,v_unit_ml,0.12,v_cid_ind,v_prod);
    CALL sp_upsert_product('Aceite Esencial de Incienso 15ml',v_cat_ace,v_unit_ml,0.03,v_cid_ind,v_prod);
    CALL sp_upsert_product('Aceite Esencial de Romero 30ml',v_cat_ace,v_unit_ml,0.05,v_cid_fra,v_prod);
    CALL sp_upsert_product('Aceite Esencial de Geranio 30ml',v_cat_ace,v_unit_ml,0.05,v_cid_fra,v_prod);
    CALL sp_upsert_product('Aceite de Macadamia 200ml',v_cat_ace,v_unit_ml,0.22,v_cid_bra,v_prod);
    CALL sp_upsert_product('Aceite de Semilla de Uva 250ml',v_cat_ace,v_unit_ml,0.27,v_cid_fra,v_prod);

    -- Cosmética Dermatológica (15 productos)
    CALL sp_upsert_product('Sérum Vitamina C 30ml',v_cat_cos,v_unit_ml,0.08,v_cid_ind,v_prod);
    CALL sp_upsert_product('Crema Hidratante Aloe Vera 150ml',v_cat_cos,v_unit_ml,0.18,v_cid_ind,v_prod);
    CALL sp_upsert_product('Mascarilla de Arcilla Verde 200g',v_cat_cos,v_unit_g,0.22,v_cid_fra,v_prod);
    CALL sp_upsert_product('Contorno de Ojos Retinol 20ml',v_cat_cos,v_unit_ml,0.05,v_cid_fra,v_prod);
    CALL sp_upsert_product('Exfoliante de Café 300g',v_cat_cos,v_unit_g,0.33,v_cid_bra,v_prod);
    CALL sp_upsert_product('Tónico Facial de Agua de Rosas 200ml',v_cat_cos,v_unit_ml,0.22,v_cid_fra,v_prod);
    CALL sp_upsert_product('Crema Antienvejecimiento Q10 50ml',v_cat_cos,v_unit_ml,0.08,v_cid_ind,v_prod);
    CALL sp_upsert_product('Protector Solar Natural SPF50 100ml',v_cat_cos,v_unit_ml,0.12,v_cid_ind,v_prod);
    CALL sp_upsert_product('Mascarilla de Carbón Activado 150ml',v_cat_cos,v_unit_ml,0.17,v_cid_ind,v_prod);
    CALL sp_upsert_product('Sérum Hialurónico 30ml',v_cat_cos,v_unit_ml,0.05,v_cid_fra,v_prod);
    CALL sp_upsert_product('Bálsamo de Cúrcuma 80g',v_cat_cos,v_unit_g,0.10,v_cid_ind,v_prod);
    CALL sp_upsert_product('Crema de Caléndula Orgánica 100ml',v_cat_cos,v_unit_ml,0.12,v_cid_ind,v_prod);
    CALL sp_upsert_product('Aceite Facial de Noche Bakuchiol 30ml',v_cat_cos,v_unit_ml,0.05,v_cid_ind,v_prod);
    CALL sp_upsert_product('Gel de Aloe Vera Puro 500ml',v_cat_cos,v_unit_ml,0.55,v_cid_ind,v_prod);
    CALL sp_upsert_product('Crema Corporal de Manteca de Karité 250ml',v_cat_cos,v_unit_ml,0.27,v_cid_ind,v_prod);

    -- Capilar (15 productos)
    CALL sp_upsert_product('Shampoo de Keratina Natural 400ml',v_cat_cap,v_unit_ml,0.44,v_cid_ind,v_prod);
    CALL sp_upsert_product('Acondicionador Proteínas de Seda 400ml',v_cat_cap,v_unit_ml,0.44,v_cid_ind,v_prod);
    CALL sp_upsert_product('Mascarilla Capilar Aguacate 300g',v_cat_cap,v_unit_g,0.33,v_cid_bra,v_prod);
    CALL sp_upsert_product('Sérum Anticaída con Biotina 100ml',v_cat_cap,v_unit_ml,0.12,v_cid_ind,v_prod);
    CALL sp_upsert_product('Aceite Capilar de Argán Marroquí 100ml',v_cat_cap,v_unit_ml,0.12,v_cid_ind,v_prod);
    CALL sp_upsert_product('Shampoo en Barra sin Sulfatos 80g',v_cat_cap,v_unit_g,0.10,v_cid_fra,v_prod);
    CALL sp_upsert_product('Tratamiento Capilar de Ricino 150ml',v_cat_cap,v_unit_ml,0.17,v_cid_ind,v_prod);
    CALL sp_upsert_product('Ampolletas de Colágeno Capilar 12un',v_cat_cap,v_unit_un,0.15,v_cid_ind,v_prod);
    CALL sp_upsert_product('Crema para Peinar sin Enjuague 200ml',v_cat_cap,v_unit_ml,0.22,v_cid_ind,v_prod);
    CALL sp_upsert_product('Spray Protector Térmico Natural 200ml',v_cat_cap,v_unit_ml,0.22,v_cid_fra,v_prod);
    CALL sp_upsert_product('Champú de Romero y Menta 300ml',v_cat_cap,v_unit_ml,0.33,v_cid_fra,v_prod);
    CALL sp_upsert_product('Bálsamo Labial Natural Cacao 10g',v_cat_cap,v_unit_g,0.01,v_cid_bra,v_prod);
    CALL sp_upsert_product('Tónico Capilar Jengibre 100ml',v_cat_cap,v_unit_ml,0.12,v_cid_ind,v_prod);
    CALL sp_upsert_product('Mascarilla Proteínas Quinoa 250g',v_cat_cap,v_unit_g,0.27,v_cid_bra,v_prod);
    CALL sp_upsert_product('Aceite de Cacay para Cabello 50ml',v_cat_cap,v_unit_ml,0.06,v_cid_bra,v_prod);

    -- Bebidas Naturales (12 productos)
    CALL sp_upsert_product('Té Verde Matcha Ceremonial 100g',v_cat_beb,v_unit_g,0.12,v_cid_ind,v_prod);
    CALL sp_upsert_product('Moringa en Polvo Orgánica 200g',v_cat_beb,v_unit_g,0.22,v_cid_ind,v_prod);
    CALL sp_upsert_product('Cúrcuma Golden Milk 300g',v_cat_beb,v_unit_g,0.33,v_cid_ind,v_prod);
    CALL sp_upsert_product('Kombucha Base Concentrada 500ml',v_cat_beb,v_unit_ml,0.55,v_cid_ind,v_prod);
    CALL sp_upsert_product('Ashwagandha en Polvo 150g',v_cat_beb,v_unit_g,0.17,v_cid_ind,v_prod);
    CALL sp_upsert_product('Maca Negra Andina en Polvo 200g',v_cat_beb,v_unit_g,0.22,v_cid_bra,v_prod);
    CALL sp_upsert_product('Spirulina Premium en Polvo 250g',v_cat_beb,v_unit_g,0.27,v_cid_ind,v_prod);
    CALL sp_upsert_product('Agua de Coco Liofilizada 150g',v_cat_beb,v_unit_g,0.17,v_cid_bra,v_prod);
    CALL sp_upsert_product('Té de Hibisco Jamaicano 100g',v_cat_beb,v_unit_g,0.12,v_cid_bra,v_prod);
    CALL sp_upsert_product('Guaraná Natural en Polvo 100g',v_cat_beb,v_unit_g,0.12,v_cid_bra,v_prod);
    CALL sp_upsert_product('Jengibre Liofilizado 80g',v_cat_beb,v_unit_g,0.10,v_cid_ind,v_prod);
    CALL sp_upsert_product('Chaga Mushroom en Polvo 100g',v_cat_beb,v_unit_g,0.12,v_cid_ind,v_prod);

    -- Alimentos Funcionales (12 productos)
    CALL sp_upsert_product('Aceite MCT de Coco Puro 500ml',v_cat_ali,v_unit_ml,0.55,v_cid_ind,v_prod);
    CALL sp_upsert_product('Colágeno Marino Hidrolizado 300g',v_cat_ali,v_unit_g,0.33,v_cid_ind,v_prod);
    CALL sp_upsert_product('Proteína de Cáñamo Orgánica 500g',v_cat_ali,v_unit_g,0.55,v_cid_ind,v_prod);
    CALL sp_upsert_product('Cacao Crudo en Polvo 250g',v_cat_ali,v_unit_g,0.27,v_cid_bra,v_prod);
    CALL sp_upsert_product('Levadura Nutricional 200g',v_cat_ali,v_unit_g,0.22,v_cid_ind,v_prod);
    CALL sp_upsert_product('Polen de Abeja Orgánico 250g',v_cat_ali,v_unit_g,0.27,v_cid_bra,v_prod);
    CALL sp_upsert_product('Semillas de Chía Orgánica 500g',v_cat_ali,v_unit_g,0.55,v_cid_bra,v_prod);
    CALL sp_upsert_product('Aceite de Hígado de Bacalao 250ml',v_cat_ali,v_unit_ml,0.27,v_cid_ind,v_prod);
    CALL sp_upsert_product('Inulina de Achicoria 300g',v_cat_ali,v_unit_g,0.33,v_cid_bra,v_prod);
    CALL sp_upsert_product('Clorela en Tabletas 250un',v_cat_ali,v_unit_un,0.28,v_cid_ind,v_prod);
    CALL sp_upsert_product('Quercetina con Bromelina 90caps',v_cat_ali,v_unit_un,0.10,v_cid_ind,v_prod);
    CALL sp_upsert_product('Probiótico Multicepa 60caps',v_cat_ali,v_unit_un,0.07,v_cid_ind,v_prod);

    -- Jabones Artesanales (14 productos)
    CALL sp_upsert_product('Jabón de Lavanda y Avena 100g',v_cat_jab,v_unit_g,0.11,v_cid_fra,v_prod);
    CALL sp_upsert_product('Jabón de Carbón Activado 100g',v_cat_jab,v_unit_g,0.11,v_cid_ind,v_prod);
    CALL sp_upsert_product('Jabón de Arcilla Kaolin 100g',v_cat_jab,v_unit_g,0.11,v_cid_fra,v_prod);
    CALL sp_upsert_product('Jabón de Leche de Cabra 100g',v_cat_jab,v_unit_g,0.11,v_cid_fra,v_prod);
    CALL sp_upsert_product('Jabón de Azufre Natural 100g',v_cat_jab,v_unit_g,0.11,v_cid_ind,v_prod);
    CALL sp_upsert_product('Jabón de Café Exfoliante 120g',v_cat_jab,v_unit_g,0.13,v_cid_bra,v_prod);
    CALL sp_upsert_product('Jabón de Manteca de Cacao 100g',v_cat_jab,v_unit_g,0.11,v_cid_bra,v_prod);
    CALL sp_upsert_product('Jabón de Rosa Mosqueta 100g',v_cat_jab,v_unit_g,0.11,v_cid_bra,v_prod);
    CALL sp_upsert_product('Jabón de Aloe Vera 100g',v_cat_jab,v_unit_g,0.11,v_cid_ind,v_prod);
    CALL sp_upsert_product('Jabón de Miel y Avena 100g',v_cat_jab,v_unit_g,0.11,v_cid_ind,v_prod);
    CALL sp_upsert_product('Jabón de Árbol de Té Antibacterial 100g',v_cat_jab,v_unit_g,0.11,v_cid_ind,v_prod);
    CALL sp_upsert_product('Jabón de Oliva Extra Virgen 100g',v_cat_jab,v_unit_g,0.11,v_cid_fra,v_prod);
    CALL sp_upsert_product('Jabón de Cúrcuma Antiinflamatorio 100g',v_cat_jab,v_unit_g,0.11,v_cid_ind,v_prod);
    CALL sp_upsert_product('Jabón de Chocolate y Café 120g',v_cat_jab,v_unit_g,0.13,v_cid_bra,v_prod);

    -- Aromaterapia (12 productos)
    CALL sp_upsert_product('Difusor Ultrasónico de Bambú 200ml',v_cat_aro,v_unit_un,0.35,v_cid_ind,v_prod);
    CALL sp_upsert_product('Mezcla Relax Lavanda-Bergamota 30ml',v_cat_aro,v_unit_ml,0.05,v_cid_fra,v_prod);
    CALL sp_upsert_product('Mezcla Energía Menta-Romero 30ml',v_cat_aro,v_unit_ml,0.05,v_cid_fra,v_prod);
    CALL sp_upsert_product('Mezcla Immunity Eucalipto-Árbol Té 30ml',v_cat_aro,v_unit_ml,0.05,v_cid_ind,v_prod);
    CALL sp_upsert_product('Velas de Cera de Abeja Lavanda 200g',v_cat_aro,v_unit_g,0.22,v_cid_fra,v_prod);
    CALL sp_upsert_product('Velas de Soya y Vainilla 200g',v_cat_aro,v_unit_g,0.22,v_cid_bra,v_prod);
    CALL sp_upsert_product('Incienso Natural de Palo Santo 20un',v_cat_aro,v_unit_un,0.04,v_cid_bra,v_prod);
    CALL sp_upsert_product('Incienso de Sándalo Premium 20un',v_cat_aro,v_unit_un,0.04,v_cid_ind,v_prod);
    CALL sp_upsert_product('Spray Ambiental Relajante 150ml',v_cat_aro,v_unit_ml,0.17,v_cid_fra,v_prod);
    CALL sp_upsert_product('Piedras de Lava para Difusor 50un',v_cat_aro,v_unit_un,0.15,v_cid_ind,v_prod);
    CALL sp_upsert_product('Kit Aromaterapia Básico 5 aceites',v_cat_aro,v_unit_un,0.25,v_cid_fra,v_prod);
    CALL sp_upsert_product('Collar Difusor Aromaterapia',v_cat_aro,v_unit_un,0.05,v_cid_ind,v_prod);

    CALL sp_log('sp_insert_products','100 productos insertados en 7 categorías','products',NULL,'SUCCESS',NULL);
EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    CALL sp_log('sp_insert_products','Error productos',NULL,NULL,'ERROR',v_err);
    RAISE;
END;$$;

-- =============================================================
-- SP 6 — Importaciones con costos detallados
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_insert_imports()
LANGUAGE plpgsql AS $$
DECLARE
    v_sup1 INT; v_sup2 INT; v_sup3 INT; v_sup4 INT; v_sup5 INT;
    v_st_rcv INT; v_st_shp INT;
    v_cur_usd INT; v_er_usd INT;
    v_ct_flete INT; v_ct_seg INT; v_ct_pto INT; v_ct_aran INT;
    v_imp INT; v_det INT;
    v_prod INT; v_i INT;
    v_err TEXT;
BEGIN
    SELECT supplier_id INTO v_sup1 FROM suppliers WHERE supplier_name LIKE 'Himalaya%';
    SELECT supplier_id INTO v_sup2 FROM suppliers WHERE supplier_name LIKE 'Provence%';
    SELECT supplier_id INTO v_sup3 FROM suppliers WHERE supplier_name LIKE 'AmazonBio%';
    SELECT supplier_id INTO v_sup4 FROM suppliers WHERE supplier_name LIKE 'Pacific%';
    SELECT supplier_id INTO v_sup5 FROM suppliers WHERE supplier_name LIKE 'Andean%';
    SELECT status_id INTO v_st_rcv FROM import_statuses WHERE status_code='RECEIVED';
    SELECT status_id INTO v_st_shp FROM import_statuses WHERE status_code='SHIPPED';
    SELECT currency_id INTO v_cur_usd FROM currencies WHERE currency_code='USD';
    SELECT exchange_rate_id INTO v_er_usd FROM exchange_rates
        WHERE currency_id=v_cur_usd AND base_currency_id=v_cur_usd AND rate_date='2025-01-01' LIMIT 1;

    SELECT cost_type_id INTO v_ct_flete FROM cost_types WHERE cost_type_code='FLETE';
    SELECT cost_type_id INTO v_ct_seg   FROM cost_types WHERE cost_type_code='SEGURO';
    SELECT cost_type_id INTO v_ct_pto   FROM cost_types WHERE cost_type_code='PUERTO';
    SELECT cost_type_id INTO v_ct_aran  FROM cost_types WHERE cost_type_code='ARANCEL_GEN';

    -- IMPORTACIÓN 1: Himalaya — Aceites y Cosmética
    INSERT INTO imports(supplier_id,status_id,import_date,actual_arrival,notes)
    VALUES(v_sup1,v_st_rcv,'2025-01-15','2025-02-10','Lote Q1 aceites esenciales India')
    RETURNING import_id INTO v_imp;

    FOR v_i IN 1..8 LOOP
        SELECT product_id INTO v_prod FROM products
        WHERE category_id=(SELECT category_id FROM categories WHERE category_name='Aceites Esenciales')
        ORDER BY product_id OFFSET v_i-1 LIMIT 1;
        INSERT INTO import_details(import_id,product_id,quantity,unit_cost,currency_id,exchange_rate_id,subtotal)
        VALUES(v_imp,v_prod,500,8.50+v_i*0.5,v_cur_usd,v_er_usd,(500*(8.50+v_i*0.5)))
        RETURNING import_detail_id INTO v_det;
    END LOOP;
    INSERT INTO import_costs(import_id,cost_type_id,amount,currency_id,exchange_rate_id)
    VALUES(v_imp,v_ct_flete,1200,v_cur_usd,v_er_usd),
          (v_imp,v_ct_seg,240,v_cur_usd,v_er_usd),
          (v_imp,v_ct_pto,180,v_cur_usd,v_er_usd);

    -- IMPORTACIÓN 2: Provence — Cosméticos Francia
    INSERT INTO imports(supplier_id,status_id,import_date,actual_arrival,notes)
    VALUES(v_sup2,v_st_rcv,'2025-02-01','2025-03-01','Cosméticos premium Francia Q1')
    RETURNING import_id INTO v_imp;

    FOR v_i IN 1..6 LOOP
        SELECT product_id INTO v_prod FROM products
        WHERE category_id=(SELECT category_id FROM categories WHERE category_name='Cosmética Dermatológica')
        ORDER BY product_id OFFSET v_i-1 LIMIT 1;
        INSERT INTO import_details(import_id,product_id,quantity,unit_cost,currency_id,exchange_rate_id,subtotal)
        VALUES(v_imp,v_prod,300,12.00+v_i*1.0,v_cur_usd,v_er_usd,(300*(12.00+v_i*1.0)))
        RETURNING import_detail_id INTO v_det;
    END LOOP;
    INSERT INTO import_costs(import_id,cost_type_id,amount,currency_id,exchange_rate_id)
    VALUES(v_imp,v_ct_flete,900,v_cur_usd,v_er_usd),
          (v_imp,v_ct_seg,180,v_cur_usd,v_er_usd),
          (v_imp,v_ct_pto,120,v_cur_usd,v_er_usd);

    -- IMPORTACIÓN 3: AmazonBio — Bebidas y Alimentos Brasil
    INSERT INTO imports(supplier_id,status_id,import_date,actual_arrival,notes)
    VALUES(v_sup3,v_st_rcv,'2025-02-15','2025-03-20','Bebidas y superfoods Brasil')
    RETURNING import_id INTO v_imp;

    FOR v_i IN 1..8 LOOP
        SELECT product_id INTO v_prod FROM products
        WHERE category_id IN (
            SELECT category_id FROM categories
            WHERE category_name IN ('Bebidas Naturales','Alimentos Funcionales')
        )
        ORDER BY product_id OFFSET v_i-1 LIMIT 1;
        INSERT INTO import_details(import_id,product_id,quantity,unit_cost,currency_id,exchange_rate_id,subtotal)
        VALUES(v_imp,v_prod,400,6.50+v_i*0.3,v_cur_usd,v_er_usd,(400*(6.50+v_i*0.3)))
        RETURNING import_detail_id INTO v_det;
    END LOOP;
    INSERT INTO import_costs(import_id,cost_type_id,amount,currency_id,exchange_rate_id)
    VALUES(v_imp,v_ct_flete,800,v_cur_usd,v_er_usd),
          (v_imp,v_ct_seg,160,v_cur_usd,v_er_usd),
          (v_imp,v_ct_pto,100,v_cur_usd,v_er_usd);

    -- IMPORTACIÓN 4: Pacific Wellness — Capilar
    INSERT INTO imports(supplier_id,status_id,import_date,actual_arrival,notes)
    VALUES(v_sup4,v_st_rcv,'2025-03-01','2025-04-05','Línea capilar premium India')
    RETURNING import_id INTO v_imp;

    FOR v_i IN 1..8 LOOP
        SELECT product_id INTO v_prod FROM products
        WHERE category_id=(SELECT category_id FROM categories WHERE category_name='Capilar')
        ORDER BY product_id OFFSET v_i-1 LIMIT 1;
        INSERT INTO import_details(import_id,product_id,quantity,unit_cost,currency_id,exchange_rate_id,subtotal)
        VALUES(v_imp,v_prod,350,9.00+v_i*0.4,v_cur_usd,v_er_usd,(350*(9.00+v_i*0.4)))
        RETURNING import_detail_id INTO v_det;
    END LOOP;
    INSERT INTO import_costs(import_id,cost_type_id,amount,currency_id,exchange_rate_id)
    VALUES(v_imp,v_ct_flete,700,v_cur_usd,v_er_usd),
          (v_imp,v_ct_seg,140,v_cur_usd,v_er_usd),
          (v_imp,v_ct_pto,90,v_cur_usd,v_er_usd);

    -- IMPORTACIÓN 5: Andean — Jabones y Aromaterapia
    INSERT INTO imports(supplier_id,status_id,import_date,actual_arrival,notes)
    VALUES(v_sup5,v_st_rcv,'2025-03-15','2025-04-20','Jabones artesanales y aromaterapia')
    RETURNING import_id INTO v_imp;

    FOR v_i IN 1..8 LOOP
        SELECT product_id INTO v_prod FROM products
        WHERE category_id IN (
            SELECT category_id FROM categories
            WHERE category_name IN ('Jabones Artesanales','Aromaterapia')
        )
        ORDER BY product_id OFFSET v_i-1 LIMIT 1;
        INSERT INTO import_details(import_id,product_id,quantity,unit_cost,currency_id,exchange_rate_id,subtotal)
        VALUES(v_imp,v_prod,600,4.50+v_i*0.2,v_cur_usd,v_er_usd,(600*(4.50+v_i*0.2)))
        RETURNING import_detail_id INTO v_det;
    END LOOP;
    INSERT INTO import_costs(import_id,cost_type_id,amount,currency_id,exchange_rate_id)
    VALUES(v_imp,v_ct_flete,600,v_cur_usd,v_er_usd),
          (v_imp,v_ct_seg,120,v_cur_usd,v_er_usd),
          (v_imp,v_ct_pto,80,v_cur_usd,v_er_usd);

    CALL sp_log('sp_insert_imports','5 importaciones con costos detallados','imports',NULL,'SUCCESS',NULL);
EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    CALL sp_log('sp_insert_imports','Error importaciones',NULL,NULL,'ERROR',v_err);
    RAISE;
END;$$;

-- =============================================================
-- SP 7 — Movimientos de inventario
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_insert_inventory()
LANGUAGE plpgsql AS $$
DECLARE
    v_wh INT; v_mt_entry INT;
    v_cur_usd INT; v_er_usd INT;
    v_prod RECORD;
    v_err TEXT;
BEGIN
    SELECT warehouse_id INTO v_wh FROM warehouses WHERE warehouse_name LIKE 'HUB-A%';
    SELECT movement_type_id INTO v_mt_entry FROM movement_types WHERE type_code='ENTRY';
    SELECT currency_id INTO v_cur_usd FROM currencies WHERE currency_code='USD';
    SELECT exchange_rate_id INTO v_er_usd FROM exchange_rates
        WHERE currency_id=v_cur_usd AND base_currency_id=v_cur_usd AND rate_date='2025-01-01' LIMIT 1;

    -- Registrar entrada de inventario para TODOS los productos
    FOR v_prod IN (SELECT product_id FROM products ORDER BY product_id) LOOP
        INSERT INTO inventory_movements(
            warehouse_id, product_id, movement_type_id,
            quantity, unit_cost, currency_id, exchange_rate_id,
            reference_type, notes
        ) VALUES (
            v_wh, v_prod.product_id, v_mt_entry,
            500, 10.00, v_cur_usd, v_er_usd,
            'IMPORT', 'Entrada inicial importación Q1'
        );
    END LOOP;

    CALL sp_log('sp_insert_inventory','Movimientos de inventario registrados','inventory_movements',NULL,'SUCCESS',NULL);
EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    CALL sp_log('sp_insert_inventory','Error inventario',NULL,NULL,'ERROR',v_err);
    RAISE;
END;$$;

-- =============================================================
-- SP 8 — Permisos sanitarios por producto y país
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_insert_permits()
LANGUAGE plpgsql AS $$
DECLARE
    v_cur_usd INT; v_er_usd INT; v_st_active INT;
    v_pt_inv INT; v_pt_dig INT; v_pt_cof INT; v_pt_isp INT; v_pt_min INT;
    v_cid_col INT; v_cid_per INT; v_cid_mex INT; v_cid_chl INT; v_cid_cri INT;
    v_prod INT; v_counter INT := 0; v_err TEXT;
BEGIN
    SELECT currency_id INTO v_cur_usd FROM currencies WHERE currency_code='USD';
    SELECT exchange_rate_id INTO v_er_usd FROM exchange_rates WHERE currency_id=v_cur_usd AND base_currency_id=v_cur_usd ORDER BY rate_date DESC LIMIT 1;
    SELECT status_id INTO v_st_active FROM import_statuses WHERE status_code='ACTIVE';
    SELECT permit_type_id INTO v_pt_inv FROM permit_types WHERE permit_type_code='INVIMA';
    SELECT permit_type_id INTO v_pt_dig FROM permit_types WHERE permit_type_code='DIGEMID';
    SELECT permit_type_id INTO v_pt_cof FROM permit_types WHERE permit_type_code='COFEPRIS';
    SELECT permit_type_id INTO v_pt_isp FROM permit_types WHERE permit_type_code='ISP';
    SELECT permit_type_id INTO v_pt_min FROM permit_types WHERE permit_type_code='MINSA_CRI';
    SELECT country_id INTO v_cid_col FROM countries WHERE iso_code='COL';
    SELECT country_id INTO v_cid_per FROM countries WHERE iso_code='PER';
    SELECT country_id INTO v_cid_mex FROM countries WHERE iso_code='MEX';
    SELECT country_id INTO v_cid_chl FROM countries WHERE iso_code='CHL';
    SELECT country_id INTO v_cid_cri FROM countries WHERE iso_code='CRI';

    FOR v_prod IN (SELECT product_id FROM products ORDER BY product_id) LOOP
        INSERT INTO product_permits(product_id,destination_country_id,permit_type_id,permit_number,valid_from,valid_until,cost_amount,currency_id,exchange_rate_id,status_id)
        VALUES(v_prod,v_cid_col,v_pt_inv,CONCAT('INV-2025-',LPAD(v_prod::TEXT,4,'0')),'2025-01-01','2027-12-31',150+(v_prod%5)*20,v_cur_usd,v_er_usd,v_st_active) ON CONFLICT(product_id,destination_country_id,permit_type_id) DO NOTHING;
        INSERT INTO product_permits(product_id,destination_country_id,permit_type_id,permit_number,valid_from,valid_until,cost_amount,currency_id,exchange_rate_id,status_id)
        VALUES(v_prod,v_cid_per,v_pt_dig,CONCAT('DIG-2025-',LPAD(v_prod::TEXT,4,'0')),'2025-01-01','2027-12-31',120+(v_prod%4)*15,v_cur_usd,v_er_usd,v_st_active) ON CONFLICT(product_id,destination_country_id,permit_type_id) DO NOTHING;
        INSERT INTO product_permits(product_id,destination_country_id,permit_type_id,permit_number,valid_from,valid_until,cost_amount,currency_id,exchange_rate_id,status_id)
        VALUES(v_prod,v_cid_mex,v_pt_cof,CONCAT('COF-2025-',LPAD(v_prod::TEXT,4,'0')),'2025-01-01','2027-12-31',180+(v_prod%6)*25,v_cur_usd,v_er_usd,v_st_active) ON CONFLICT(product_id,destination_country_id,permit_type_id) DO NOTHING;
        INSERT INTO product_permits(product_id,destination_country_id,permit_type_id,permit_number,valid_from,valid_until,cost_amount,currency_id,exchange_rate_id,status_id)
        VALUES(v_prod,v_cid_chl,v_pt_isp,CONCAT('ISP-2025-',LPAD(v_prod::TEXT,4,'0')),'2025-01-01','2027-12-31',130+(v_prod%5)*18,v_cur_usd,v_er_usd,v_st_active) ON CONFLICT(product_id,destination_country_id,permit_type_id) DO NOTHING;
        INSERT INTO product_permits(product_id,destination_country_id,permit_type_id,permit_number,valid_from,valid_until,cost_amount,currency_id,exchange_rate_id,status_id)
        VALUES(v_prod,v_cid_cri,v_pt_min,CONCAT('MIN-2025-',LPAD(v_prod::TEXT,4,'0')),'2025-01-01','2027-12-31',100+(v_prod%4)*12,v_cur_usd,v_er_usd,v_st_active) ON CONFLICT(product_id,destination_country_id,permit_type_id) DO NOTHING;
        v_counter := v_counter + 1;
    END LOOP;

    CALL sp_log('sp_insert_permits',CONCAT(v_counter*5,' permisos en 5 países'),'product_permits',NULL,'SUCCESS',NULL);
EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    CALL sp_log('sp_insert_permits','Error permisos',NULL,NULL,'ERROR',v_err);
    RAISE;
END;$$;

-- =============================================================
-- SP 9 — Dispatch orders (HUB -> países destino)
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_insert_dispatch_orders()
LANGUAGE plpgsql AS $$
DECLARE
    v_cur_usd INT; v_er_usd INT; v_wh_disp INT; v_st_disp INT;
    v_cid_col INT; v_cid_per INT; v_cid_mex INT; v_cid_chl INT; v_cid_cri INT;
    v_prod INT; v_err TEXT;
BEGIN
    SELECT currency_id INTO v_cur_usd FROM currencies WHERE currency_code='USD';
    SELECT exchange_rate_id INTO v_er_usd FROM exchange_rates WHERE currency_id=v_cur_usd AND base_currency_id=v_cur_usd ORDER BY rate_date DESC LIMIT 1;
    SELECT warehouse_id INTO v_wh_disp FROM warehouses WHERE warehouse_name LIKE 'HUB-C%';
    SELECT status_id INTO v_st_disp FROM import_statuses WHERE status_code='DISPATCHED';
    SELECT country_id INTO v_cid_col FROM countries WHERE iso_code='COL';
    SELECT country_id INTO v_cid_per FROM countries WHERE iso_code='PER';
    SELECT country_id INTO v_cid_mex FROM countries WHERE iso_code='MEX';
    SELECT country_id INTO v_cid_chl FROM countries WHERE iso_code='CHL';
    SELECT country_id INTO v_cid_cri FROM countries WHERE iso_code='CRI';

    -- Colombia (ref order_id 1-8)
    FOR v_prod IN (SELECT p.product_id FROM products p JOIN categories c ON p.category_id=c.category_id WHERE c.category_name='Aceites Esenciales' ORDER BY p.product_id LIMIT 5) LOOP
        INSERT INTO dispatch_orders(reference_order_id,product_id,quantity,warehouse_id,destination_country_id,brand_label,packaging_permit_ok,unit_cost,currency_id,exchange_rate_id,dispatch_date,status_id)
        VALUES(1,v_prod,50,v_wh_disp,v_cid_col,'Vivanatura/ZenAromatics',TRUE,12.50,v_cur_usd,v_er_usd,'2025-02-12 08:00:00',v_st_disp);
    END LOOP;
    -- Perú (ref order_id 9-14)
    FOR v_prod IN (SELECT p.product_id FROM products p JOIN categories c ON p.category_id=c.category_id WHERE c.category_name IN ('Aceites Esenciales','Alimentos Funcionales') ORDER BY p.product_id LIMIT 5) LOOP
        INSERT INTO dispatch_orders(reference_order_id,product_id,quantity,warehouse_id,destination_country_id,brand_label,packaging_permit_ok,unit_cost,currency_id,exchange_rate_id,dispatch_date,status_id)
        VALUES(9,v_prod,40,v_wh_disp,v_cid_per,'Vivanatura/EcoVital',TRUE,11.00,v_cur_usd,v_er_usd,'2025-03-07 08:00:00',v_st_disp);
    END LOOP;
    -- México (ref order_id 15-19)
    FOR v_prod IN (SELECT p.product_id FROM products p JOIN categories c ON p.category_id=c.category_id WHERE c.category_name IN ('Cosmética Dermatológica','Capilar') ORDER BY p.product_id LIMIT 5) LOOP
        INSERT INTO dispatch_orders(reference_order_id,product_id,quantity,warehouse_id,destination_country_id,brand_label,packaging_permit_ok,unit_cost,currency_id,exchange_rate_id,dispatch_date,status_id)
        VALUES(15,v_prod,60,v_wh_disp,v_cid_mex,'PuraDerma/HairElixir',TRUE,14.00,v_cur_usd,v_er_usd,'2025-03-17 08:00:00',v_st_disp);
    END LOOP;
    -- Chile (ref order_id 20-23)
    FOR v_prod IN (SELECT p.product_id FROM products p JOIN categories c ON p.category_id=c.category_id WHERE c.category_name IN ('Cosmética Dermatológica','Jabones Artesanales') ORDER BY p.product_id LIMIT 5) LOOP
        INSERT INTO dispatch_orders(reference_order_id,product_id,quantity,warehouse_id,destination_country_id,brand_label,packaging_permit_ok,unit_cost,currency_id,exchange_rate_id,dispatch_date,status_id)
        VALUES(20,v_prod,35,v_wh_disp,v_cid_chl,'PuraDerma/EcoVital',TRUE,10.50,v_cur_usd,v_er_usd,'2025-04-03 08:00:00',v_st_disp);
    END LOOP;
    -- Costa Rica (ref order_id 24-27)
    FOR v_prod IN (SELECT p.product_id FROM products p JOIN categories c ON p.category_id=c.category_id WHERE c.category_name IN ('Aromaterapia','Bebidas Naturales') ORDER BY p.product_id LIMIT 5) LOOP
        INSERT INTO dispatch_orders(reference_order_id,product_id,quantity,warehouse_id,destination_country_id,brand_label,packaging_permit_ok,unit_cost,currency_id,exchange_rate_id,dispatch_date,status_id)
        VALUES(24,v_prod,30,v_wh_disp,v_cid_cri,'ZenAromatics',TRUE,9.00,v_cur_usd,v_er_usd,'2025-04-12 08:00:00',v_st_disp);
    END LOOP;

    CALL sp_log('sp_insert_dispatch_orders','Despachos a 5 países','dispatch_orders',NULL,'SUCCESS',NULL);
EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    CALL sp_log('sp_insert_dispatch_orders','Error despachos',NULL,NULL,'ERROR',v_err);
    RAISE;
END;$$;

-- =============================================================
-- ORQUESTADOR v4 — Con transacción explícita
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_load_all_data()
LANGUAGE plpgsql AS $$
DECLARE v_err TEXT;
BEGIN
    RAISE NOTICE 'Iniciando carga Etheria Global v4 (UPSERT + INOUT)...';
    BEGIN
        CALL sp_insert_catalogs();
        CALL sp_insert_geography();
        CALL sp_insert_exchange_rates();
        CALL sp_insert_suppliers_warehouses();
        CALL sp_insert_products();
        CALL sp_insert_imports();
        CALL sp_insert_inventory();
        CALL sp_insert_permits();
        CALL sp_insert_dispatch_orders();
        CALL sp_log('sp_load_all_data','Carga completa Etheria Global v4',NULL,NULL,'SUCCESS',NULL);
        RAISE NOTICE 'Carga Etheria Global v4 completada.';
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
        CALL sp_log('sp_load_all_data','Error en carga: '||v_err,NULL,NULL,'ERROR',v_err);
        RAISE;
    END;
END;$$;

-- Ejecutar carga completa
CALL sp_load_all_data();
