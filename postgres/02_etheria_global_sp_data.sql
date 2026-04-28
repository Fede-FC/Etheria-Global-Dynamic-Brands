-- =============================================================
--  ETHERIA GLOBAL — Stored Procedures + Carga de Datos
--  Database: etheria_global_db (PostgreSQL 16)
--  Incluye:
--    1. SP de logging independiente
--    2. SPs transaccionales de inserción con manejo de excepciones
--    3. Orquestación de llamadas para poblar la base de datos
-- =============================================================

\c etheria_global_db;

-- =============================================================
-- SP 0: sp_log_process
-- SP de logging independiente llamado por todos los demás SPs.
-- Registra cada paso ejecutado en Process_log.
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_log_process(
    p_sp_name            VARCHAR,
    p_action_description TEXT,
    p_affected_table     VARCHAR,
    p_affected_record_id INT,
    p_status             VARCHAR,
    p_error_detail       TEXT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
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
END;
$$;

-- =============================================================
-- SP 1: sp_insert_country
-- Inserta un país. Ignora duplicados por iso_code.
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_insert_country(
    p_country_name VARCHAR,
    p_iso_code     CHAR,
    p_region       VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id INT;
BEGIN
    CALL sp_log_process('sp_insert_country', 'Iniciando inserción de país: ' || p_country_name, 'Countries', NULL, 'INFO');

    INSERT INTO Countries (country_name, iso_code, region)
    VALUES (p_country_name, p_iso_code, p_region)
    ON CONFLICT (iso_code) DO NOTHING
    RETURNING country_id INTO v_id;

    IF v_id IS NOT NULL THEN
        CALL sp_log_process('sp_insert_country', 'País insertado exitosamente: ' || p_country_name, 'Countries', v_id, 'SUCCESS');
    ELSE
        CALL sp_log_process('sp_insert_country', 'País ya existía (iso_code duplicado): ' || p_iso_code, 'Countries', NULL, 'WARNING');
    END IF;

EXCEPTION WHEN OTHERS THEN
    CALL sp_log_process('sp_insert_country', 'Error al insertar país: ' || p_country_name, 'Countries', NULL, 'ERROR', SQLERRM);
    RAISE;
END;
$$;

-- =============================================================
-- SP 2: sp_insert_category
-- Inserta una categoría de producto.
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_insert_category(
    p_category_name        VARCHAR,
    p_category_description VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id INT;
BEGIN
    CALL sp_log_process('sp_insert_category', 'Iniciando inserción de categoría: ' || p_category_name, 'Categories', NULL, 'INFO');

    INSERT INTO Categories (category_name, category_description)
    VALUES (p_category_name, p_category_description)
    ON CONFLICT (category_name) DO NOTHING
    RETURNING category_id INTO v_id;

    IF v_id IS NOT NULL THEN
        CALL sp_log_process('sp_insert_category', 'Categoría insertada: ' || p_category_name, 'Categories', v_id, 'SUCCESS');
    ELSE
        CALL sp_log_process('sp_insert_category', 'Categoría ya existía: ' || p_category_name, 'Categories', NULL, 'WARNING');
    END IF;

EXCEPTION WHEN OTHERS THEN
    CALL sp_log_process('sp_insert_category', 'Error al insertar categoría: ' || p_category_name, 'Categories', NULL, 'ERROR', SQLERRM);
    RAISE;
END;
$$;

-- =============================================================
-- SP 3: sp_insert_measurement_unit
-- Inserta una unidad de medida.
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_insert_measurement_unit(
    p_unit_name VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id INT;
BEGIN
    CALL sp_log_process('sp_insert_measurement_unit', 'Iniciando inserción de unidad: ' || p_unit_name, 'MeasurementUnits', NULL, 'INFO');

    INSERT INTO MeasurementUnits (unitName)
    VALUES (p_unit_name)
    ON CONFLICT (unitName) DO NOTHING
    RETURNING measurementUnitId INTO v_id;

    IF v_id IS NOT NULL THEN
        CALL sp_log_process('sp_insert_measurement_unit', 'Unidad insertada: ' || p_unit_name, 'MeasurementUnits', v_id, 'SUCCESS');
    ELSE
        CALL sp_log_process('sp_insert_measurement_unit', 'Unidad ya existía: ' || p_unit_name, 'MeasurementUnits', NULL, 'WARNING');
    END IF;

EXCEPTION WHEN OTHERS THEN
    CALL sp_log_process('sp_insert_measurement_unit', 'Error al insertar unidad: ' || p_unit_name, 'MeasurementUnits', NULL, 'ERROR', SQLERRM);
    RAISE;
END;
$$;

-- =============================================================
-- SP 4: sp_insert_supplier
-- Inserta un proveedor internacional.
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_insert_supplier(
    p_supplier_name  VARCHAR,
    p_iso_code       CHAR,
    p_contact_email  VARCHAR,
    p_contact_phone  VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_country_id INT;
    v_id         INT;
BEGIN
    CALL sp_log_process('sp_insert_supplier', 'Iniciando inserción de proveedor: ' || p_supplier_name, 'Suppliers', NULL, 'INFO');

    SELECT country_id INTO v_country_id FROM Countries WHERE iso_code = p_iso_code;

    IF v_country_id IS NULL THEN
        CALL sp_log_process('sp_insert_supplier', 'País no encontrado con iso_code: ' || p_iso_code, 'Suppliers', NULL, 'ERROR', 'País referenciado no existe');
        RAISE EXCEPTION 'País con iso_code % no existe', p_iso_code;
    END IF;

    INSERT INTO Suppliers (supplier_name, country_id, contact_email, contact_phone)
    VALUES (p_supplier_name, v_country_id, p_contact_email, p_contact_phone)
    RETURNING supplier_id INTO v_id;

    CALL sp_log_process('sp_insert_supplier', 'Proveedor insertado: ' || p_supplier_name, 'Suppliers', v_id, 'SUCCESS');

EXCEPTION WHEN OTHERS THEN
    CALL sp_log_process('sp_insert_supplier', 'Error al insertar proveedor: ' || p_supplier_name, 'Suppliers', NULL, 'ERROR', SQLERRM);
    RAISE;
END;
$$;

-- =============================================================
-- SP 5: sp_insert_warehouse
-- Inserta un almacén logístico en el HUB.
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_insert_warehouse(
    p_name           VARCHAR,
    p_location       VARCHAR,
    p_warehouse_type VARCHAR,
    p_capacity_units INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id INT;
BEGIN
    CALL sp_log_process('sp_insert_warehouse', 'Iniciando inserción de almacén: ' || p_name, 'Warehouses', NULL, 'INFO');

    INSERT INTO Warehouses (name, location, warehouse_type, capacity_units)
    VALUES (p_name, p_location, p_warehouse_type, p_capacity_units)
    RETURNING warehouse_id INTO v_id;

    CALL sp_log_process('sp_insert_warehouse', 'Almacén insertado: ' || p_name, 'Warehouses', v_id, 'SUCCESS');

EXCEPTION WHEN OTHERS THEN
    CALL sp_log_process('sp_insert_warehouse', 'Error al insertar almacén: ' || p_name, 'Warehouses', NULL, 'ERROR', SQLERRM);
    RAISE;
END;
$$;

-- =============================================================
-- SP 6: sp_insert_product
-- Inserta un producto base importado en bulk.
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_insert_product(
    p_product_name  VARCHAR,
    p_category_name VARCHAR,
    p_unit_name     VARCHAR,
    p_unit_volume   DECIMAL,
    p_unit_weight   DECIMAL,
    p_base_cost_usd DECIMAL,
    p_origin_iso    CHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_category_id  INT;
    v_unit_id      INT;
    v_origin_id    INT;
    v_id           INT;
BEGIN
    CALL sp_log_process('sp_insert_product', 'Iniciando inserción de producto: ' || p_product_name, 'Products', NULL, 'INFO');

    SELECT category_id INTO v_category_id FROM Categories WHERE category_name = p_category_name;
    IF v_category_id IS NULL THEN
        RAISE EXCEPTION 'Categoría % no existe', p_category_name;
    END IF;

    SELECT measurementUnitId INTO v_unit_id FROM MeasurementUnits WHERE unitName = p_unit_name;
    IF v_unit_id IS NULL THEN
        RAISE EXCEPTION 'Unidad de medida % no existe', p_unit_name;
    END IF;

    SELECT country_id INTO v_origin_id FROM Countries WHERE iso_code = p_origin_iso;
    IF v_origin_id IS NULL THEN
        RAISE EXCEPTION 'País de origen % no existe', p_origin_iso;
    END IF;

    INSERT INTO Products (
        product_name, category_id, base_unit_measurementUnitId,
        unit_volume_m3, unit_weight_kg, base_cost_usd, origin_country_id
    ) VALUES (
        p_product_name, v_category_id, v_unit_id,
        p_unit_volume, p_unit_weight, p_base_cost_usd, v_origin_id
    )
    RETURNING product_id INTO v_id;

    CALL sp_log_process('sp_insert_product', 'Producto insertado: ' || p_product_name, 'Products', v_id, 'SUCCESS');

EXCEPTION WHEN OTHERS THEN
    CALL sp_log_process('sp_insert_product', 'Error al insertar producto: ' || p_product_name, 'Products', NULL, 'ERROR', SQLERRM);
    RAISE;
END;
$$;

-- =============================================================
-- SP 7: sp_insert_exchange_rate
-- Inserta un tipo de cambio histórico.
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_insert_exchange_rate(
    p_iso_code     CHAR,
    p_currency     CHAR,
    p_rate_to_usd  DECIMAL,
    p_rate_date    DATE,
    p_source       VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_country_id INT;
    v_id         INT;
BEGIN
    CALL sp_log_process('sp_insert_exchange_rate', 'Insertando tipo de cambio para: ' || p_iso_code || ' fecha: ' || p_rate_date::TEXT, 'Exchange_rates', NULL, 'INFO');

    SELECT country_id INTO v_country_id FROM Countries WHERE iso_code = p_iso_code;
    IF v_country_id IS NULL THEN
        RAISE EXCEPTION 'País % no existe', p_iso_code;
    END IF;

    INSERT INTO Exchange_rates (country_id, currency_code, rate_to_usd, rate_date, source)
    VALUES (v_country_id, p_currency, p_rate_to_usd, p_rate_date, p_source)
    ON CONFLICT DO NOTHING
    RETURNING exchange_rate_id INTO v_id;

    IF v_id IS NOT NULL THEN
        CALL sp_log_process('sp_insert_exchange_rate', 'Tipo de cambio insertado para ' || p_iso_code, 'Exchange_rates', v_id, 'SUCCESS');
    ELSE
        CALL sp_log_process('sp_insert_exchange_rate', 'Tipo de cambio ya existía para ' || p_iso_code || ' en ' || p_rate_date::TEXT, 'Exchange_rates', NULL, 'WARNING');
    END IF;

EXCEPTION WHEN OTHERS THEN
    CALL sp_log_process('sp_insert_exchange_rate', 'Error al insertar tipo de cambio para: ' || p_iso_code, 'Exchange_rates', NULL, 'ERROR', SQLERRM);
    RAISE;
END;
$$;

-- =============================================================
-- SP 8: sp_insert_permit
-- Inserta un permiso sanitario para un producto en un país destino.
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_insert_permit(
    p_product_name           VARCHAR,
    p_destination_country_iso CHAR,
    p_permit_type            VARCHAR,
    p_permit_number          VARCHAR,
    p_issuing_authority      VARCHAR,
    p_valid_from             DATE,
    p_valid_until            DATE,
    p_permit_cost_usd        DECIMAL,
    p_status                 VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_product_id INT;
    v_id         INT;
BEGIN
    CALL sp_log_process('sp_insert_permit', 'Insertando permiso para producto: ' || p_product_name || ' destino: ' || p_destination_country_iso, 'Country_product_permits', NULL, 'INFO');

    SELECT product_id INTO v_product_id FROM Products WHERE product_name = p_product_name AND is_deleted = FALSE LIMIT 1;
    IF v_product_id IS NULL THEN
        RAISE EXCEPTION 'Producto % no existe', p_product_name;
    END IF;

    INSERT INTO Country_product_permits (
        product_id, destination_country_iso, permit_type,
        permit_number, issuing_authority, valid_from, valid_until,
        permit_cost_usd, status
    ) VALUES (
        v_product_id, p_destination_country_iso, p_permit_type,
        p_permit_number, p_issuing_authority, p_valid_from, p_valid_until,
        p_permit_cost_usd, p_status
    )
    ON CONFLICT (product_id, destination_country_iso, permit_type) DO NOTHING
    RETURNING permit_id INTO v_id;

    IF v_id IS NOT NULL THEN
        CALL sp_log_process('sp_insert_permit', 'Permiso insertado ID: ' || v_id::TEXT, 'Country_product_permits', v_id, 'SUCCESS');
    ELSE
        CALL sp_log_process('sp_insert_permit', 'Permiso ya existía para combinación producto/país/tipo', 'Country_product_permits', NULL, 'WARNING');
    END IF;

EXCEPTION WHEN OTHERS THEN
    CALL sp_log_process('sp_insert_permit', 'Error al insertar permiso para: ' || p_product_name, 'Country_product_permits', NULL, 'ERROR', SQLERRM);
    RAISE;
END;
$$;

-- =============================================================
-- SP 9: sp_register_import
-- Registra una importación completa (cabecera + detalle + costos
-- logísticos + movimiento de inventario). Es la transacción más
-- importante de Etheria Global.
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_register_import(
    p_supplier_name     VARCHAR,
    p_import_date       DATE,
    p_expected_arrival  DATE,
    p_product_name      VARCHAR,
    p_quantity          DECIMAL,
    p_unit_cost_usd     DECIMAL,
    p_warehouse_name    VARCHAR,
    p_shipping_cost_usd DECIMAL,
    p_insurance_usd     DECIMAL,
    p_port_handling_usd DECIMAL,
    p_other_costs_usd   DECIMAL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_supplier_id      INT;
    v_product_id       INT;
    v_warehouse_id     INT;
    v_import_id        INT;
    v_detail_id        INT;
    v_subtotal         DECIMAL(14,2);
    v_total_logistic   DECIMAL(14,2);
    v_landed_cost_unit DECIMAL(12,4);
BEGIN
    CALL sp_log_process('sp_register_import', 'Iniciando importación de: ' || p_product_name || ' desde proveedor: ' || p_supplier_name, 'Imports', NULL, 'INFO');

    -- Resolver IDs
    SELECT supplier_id INTO v_supplier_id FROM Suppliers WHERE supplier_name = p_supplier_name AND is_deleted = FALSE LIMIT 1;
    IF v_supplier_id IS NULL THEN
        RAISE EXCEPTION 'Proveedor % no encontrado', p_supplier_name;
    END IF;

    SELECT product_id INTO v_product_id FROM Products WHERE product_name = p_product_name AND is_deleted = FALSE LIMIT 1;
    IF v_product_id IS NULL THEN
        RAISE EXCEPTION 'Producto % no encontrado', p_product_name;
    END IF;

    SELECT warehouse_id INTO v_warehouse_id FROM Warehouses WHERE name = p_warehouse_name AND is_deleted = FALSE LIMIT 1;
    IF v_warehouse_id IS NULL THEN
        RAISE EXCEPTION 'Almacén % no encontrado', p_warehouse_name;
    END IF;

    -- Calcular subtotales
    v_subtotal       := p_quantity * p_unit_cost_usd;
    v_total_logistic := COALESCE(p_shipping_cost_usd,0) + COALESCE(p_insurance_usd,0) + COALESCE(p_port_handling_usd,0) + COALESCE(p_other_costs_usd,0);
    v_landed_cost_unit := (v_subtotal + v_total_logistic) / p_quantity;

    -- 1. Cabecera de importación
    INSERT INTO Imports (supplier_id, import_date, expected_arrival, status, total_cost_usd)
    VALUES (v_supplier_id, p_import_date, p_expected_arrival, 'RECEIVED', v_subtotal + v_total_logistic)
    RETURNING import_id INTO v_import_id;

    CALL sp_log_process('sp_register_import', 'Cabecera Imports creada ID: ' || v_import_id::TEXT, 'Imports', v_import_id, 'INFO');

    -- 2. Detalle de la importación
    INSERT INTO Import_details (import_id, product_id, quantity, unit_cost_usd, subtotal_usd)
    VALUES (v_import_id, v_product_id, p_quantity, p_unit_cost_usd, v_subtotal)
    RETURNING import_detail_id INTO v_detail_id;

    CALL sp_log_process('sp_register_import', 'Import_detail creado ID: ' || v_detail_id::TEXT, 'Import_details', v_detail_id, 'INFO');

    -- 3. Costos logísticos
    INSERT INTO Logistic_costs (import_id, shipping_cost_usd, insurance_cost_usd, port_handling_usd, other_costs_usd)
    VALUES (v_import_id, COALESCE(p_shipping_cost_usd,0), COALESCE(p_insurance_usd,0), COALESCE(p_port_handling_usd,0), COALESCE(p_other_costs_usd,0));

    CALL sp_log_process('sp_register_import', 'Costos logísticos registrados para import_id: ' || v_import_id::TEXT, 'Logistic_costs', v_import_id, 'INFO');

    -- 4. Movimiento de inventario (ENTRY)
    INSERT INTO Inventory (warehouse_id, product_id, quantity, cost_per_unit_usd, movement_type, reference_type, reference_id, moved_by)
    VALUES (v_warehouse_id, v_product_id, p_quantity, v_landed_cost_unit, 'ENTRY', 'IMPORT', v_import_id, current_user);

    CALL sp_log_process('sp_register_import', 'Inventario actualizado: +' || p_quantity::TEXT || ' unidades de producto_id ' || v_product_id::TEXT, 'Inventory', v_import_id, 'SUCCESS');

EXCEPTION WHEN OTHERS THEN
    CALL sp_log_process('sp_register_import', 'Error en importación de: ' || p_product_name, 'Imports', NULL, 'ERROR', SQLERRM);
    RAISE;
END;
$$;

-- =============================================================
-- SP 10: sp_register_dispatch
-- Registra una orden de despacho desde el HUB y descuenta
-- el inventario correspondiente.
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_register_dispatch(
    p_reference_order_id    INT,
    p_product_name          VARCHAR,
    p_quantity              DECIMAL,
    p_warehouse_name        VARCHAR,
    p_destination_iso       CHAR,
    p_brand_label           VARCHAR,
    p_packaging_permit_ok   BOOLEAN
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_product_id    INT;
    v_warehouse_id  INT;
    v_unit_cost     DECIMAL(12,4);
    v_stock         DECIMAL(12,3);
    v_dispatch_id   INT;
BEGIN
    CALL sp_log_process('sp_register_dispatch', 'Iniciando despacho para orden DB ref: ' || p_reference_order_id::TEXT || ' producto: ' || p_product_name, 'dispatch_orders', NULL, 'INFO');

    SELECT product_id INTO v_product_id FROM Products WHERE product_name = p_product_name AND is_deleted = FALSE LIMIT 1;
    IF v_product_id IS NULL THEN
        RAISE EXCEPTION 'Producto % no encontrado', p_product_name;
    END IF;

    SELECT warehouse_id INTO v_warehouse_id FROM Warehouses WHERE name = p_warehouse_name AND is_deleted = FALSE LIMIT 1;
    IF v_warehouse_id IS NULL THEN
        RAISE EXCEPTION 'Almacén % no encontrado', p_warehouse_name;
    END IF;

    -- Verificar stock disponible
    SELECT COALESCE(SUM(quantity), 0) INTO v_stock
    FROM Inventory
    WHERE product_id = v_product_id AND warehouse_id = v_warehouse_id;

    IF v_stock < p_quantity THEN
        CALL sp_log_process('sp_register_dispatch', 'Stock insuficiente. Disponible: ' || v_stock::TEXT || ' Solicitado: ' || p_quantity::TEXT, 'Inventory', NULL, 'ERROR', 'Stock insuficiente');
        RAISE EXCEPTION 'Stock insuficiente para producto %. Disponible: %, Solicitado: %', p_product_name, v_stock, p_quantity;
    END IF;

    -- Obtener costo unitario promedio del inventario
    SELECT COALESCE(AVG(cost_per_unit_usd), 0) INTO v_unit_cost
    FROM Inventory
    WHERE product_id = v_product_id AND warehouse_id = v_warehouse_id AND movement_type = 'ENTRY';

    -- Crear orden de despacho
    INSERT INTO dispatch_orders (
        reference_order_id, product_id, quantity, warehouse_id,
        destination_country_iso, brand_label, packaging_permit_ok,
        unit_cost_usd, dispatch_date, courier_handoff_date, status
    ) VALUES (
        p_reference_order_id, v_product_id, p_quantity, v_warehouse_id,
        p_destination_iso, p_brand_label, p_packaging_permit_ok,
        v_unit_cost, NOW(), NOW(), 'SHIPPED'
    )
    RETURNING dispatch_order_id INTO v_dispatch_id;

    CALL sp_log_process('sp_register_dispatch', 'Dispatch_order creada ID: ' || v_dispatch_id::TEXT, 'dispatch_orders', v_dispatch_id, 'INFO');

    -- Descontar inventario (salida negativa)
    INSERT INTO Inventory (warehouse_id, product_id, quantity, cost_per_unit_usd, movement_type, reference_type, reference_id, moved_by)
    VALUES (v_warehouse_id, v_product_id, -p_quantity, v_unit_cost, 'DISPATCH', 'DISPATCH', v_dispatch_id, current_user);

    CALL sp_log_process('sp_register_dispatch', 'Inventario descontado: -' || p_quantity::TEXT || ' unidades producto_id ' || v_product_id::TEXT, 'Inventory', v_dispatch_id, 'SUCCESS');

EXCEPTION WHEN OTHERS THEN
    CALL sp_log_process('sp_register_dispatch', 'Error en despacho para orden ref: ' || p_reference_order_id::TEXT, 'dispatch_orders', NULL, 'ERROR', SQLERRM);
    RAISE;
END;
$$;

-- =============================================================
-- =============================================================
--  ORQUESTACIÓN — Carga de Datos
--  Llama a los SPs para poblar la base de datos con:
--  - 5 países destino (Latam) + países de origen de productos
--  - 5 categorías de productos
--  - 100 productos distribuidos entre 5 países de origen
--  - 3 almacenes en el HUB
--  - Importaciones con detalle, costos y movimientos de inventario
--  - Permisos sanitarios por producto y país
-- =============================================================
-- =============================================================

-- ─────────────────────────────────────────────────────────────
-- BLOQUE 1: Países de origen de proveedores
-- ─────────────────────────────────────────────────────────────
CALL sp_insert_country('Marruecos',        'MAR', 'África del Norte');
CALL sp_insert_country('India',            'IND', 'Asia del Sur');
CALL sp_insert_country('Brasil',           'BRA', 'Sudamérica');
CALL sp_insert_country('Francia',          'FRA', 'Europa Occidental');
CALL sp_insert_country('Indonesia',        'IDN', 'Asia del Sudeste');
CALL sp_insert_country('Kenya',            'KEN', 'África Oriental');
CALL sp_insert_country('Tailandia',        'THA', 'Asia del Sudeste');
CALL sp_insert_country('Australia',        'AUS', 'Oceanía');

-- ─────────────────────────────────────────────────────────────
-- BLOQUE 2: Países de destino (Latam — donde opera Dynamic Brands)
-- ─────────────────────────────────────────────────────────────
CALL sp_insert_country('Colombia',         'COL', 'Sudamérica');
CALL sp_insert_country('México',           'MEX', 'América del Norte');
CALL sp_insert_country('Perú',             'PER', 'Sudamérica');
CALL sp_insert_country('Chile',            'CHL', 'Sudamérica');
CALL sp_insert_country('Costa Rica',       'CRI', 'América Central');

-- ─────────────────────────────────────────────────────────────
-- BLOQUE 3: Categorías de productos
-- ─────────────────────────────────────────────────────────────
CALL sp_insert_category('Aceites Esenciales',    'Aceites puros extraídos de plantas con propiedades terapéuticas y aromáticas');
CALL sp_insert_category('Cosmética Capilar',     'Productos para el cuidado y tratamiento del cabello de origen natural');
CALL sp_insert_category('Cosmética Dermatológica','Cremas, sueros y tratamientos para la piel con activos naturales');
CALL sp_insert_category('Bebidas Funcionales',   'Bebidas con propiedades medicinales o nutricionales de origen exótico');
CALL sp_insert_category('Jabones y Aromaterapia','Jabones artesanales, sahumerios e insumos para aromaterapia');

-- ─────────────────────────────────────────────────────────────
-- BLOQUE 4: Unidades de medida
-- ─────────────────────────────────────────────────────────────
CALL sp_insert_measurement_unit('ml');
CALL sp_insert_measurement_unit('L');
CALL sp_insert_measurement_unit('g');
CALL sp_insert_measurement_unit('kg');
CALL sp_insert_measurement_unit('unidades');

-- ─────────────────────────────────────────────────────────────
-- BLOQUE 5: Proveedores internacionales
-- ─────────────────────────────────────────────────────────────
CALL sp_insert_supplier('Argan Premium SARL',        'MAR', 'contacto@arganpremium.ma',    '+212-522-334455');
CALL sp_insert_supplier('Spice Route Exports Ltd',   'IND', 'sales@spiceroute.in',          '+91-22-61234567');
CALL sp_insert_supplier('AmazonNatural Ltda',         'BRA', 'exporta@amaznatural.com.br',  '+55-11-93456789');
CALL sp_insert_supplier('Provence Essences SAS',     'FRA', 'export@provenceessences.fr',  '+33-4-90123456');
CALL sp_insert_supplier('Nusantara Botanicals PT',   'IDN', 'info@nusantarabot.id',         '+62-21-8765432');
CALL sp_insert_supplier('Savanna Herbs Kenya Ltd',   'KEN', 'orders@savannaherbs.co.ke',   '+254-20-4567890');
CALL sp_insert_supplier('Thai Wellness Exports Co.', 'THA', 'export@thaiwellness.th',       '+66-2-9876543');
CALL sp_insert_supplier('AusNaturals Pty Ltd',       'AUS', 'trade@ausnaturals.com.au',    '+61-2-93456789');

-- ─────────────────────────────────────────────────────────────
-- BLOQUE 6: Almacenes en el HUB de Nicaragua
-- ─────────────────────────────────────────────────────────────
CALL sp_insert_warehouse('HUB Principal Caribe',      'Nicaragua - Costa Caribe - Puerto Bluefields', 'RECEIVING', 500000);
CALL sp_insert_warehouse('Área de Etiquetado y Marca','Nicaragua - Costa Caribe - Puerto Bluefields', 'LABELING',  200000);
CALL sp_insert_warehouse('Centro de Despacho Courier','Nicaragua - Costa Caribe - Puerto Bluefields', 'DISPATCH',  150000);

-- ─────────────────────────────────────────────────────────────
-- BLOQUE 7: Tipos de cambio (USD base — monedas Latam)
-- ─────────────────────────────────────────────────────────────
CALL sp_insert_exchange_rate('COL', 'COP', 4150.000000, '2025-01-01', 'Banco de la República Colombia');
CALL sp_insert_exchange_rate('MEX', 'MXN',   17.250000, '2025-01-01', 'Banco de México');
CALL sp_insert_exchange_rate('PER', 'PEN',    3.820000, '2025-01-01', 'BCRP Perú');
CALL sp_insert_exchange_rate('CHL', 'CLP',  930.000000, '2025-01-01', 'Banco Central de Chile');
CALL sp_insert_exchange_rate('CRI', 'CRC',  520.000000, '2025-01-01', 'BCCR Costa Rica');

-- ─────────────────────────────────────────────────────────────
-- BLOQUE 8: Productos (100 productos entre 5 países de origen)
-- Distribuidos: ~20 por país de origen
-- ─────────────────────────────────────────────────────────────

-- === Marruecos (MAR) — Aceites y Cosmética ===
CALL sp_insert_product('Aceite de Argán Puro',              'Aceites Esenciales',      'ml',      0.000030, 0.0300, 28.50, 'MAR');
CALL sp_insert_product('Aceite de Comino Negro MAR',        'Aceites Esenciales',      'ml',      0.000030, 0.0300, 22.00, 'MAR');
CALL sp_insert_product('Aceite de Rosa de Damasco',         'Aceites Esenciales',      'ml',      0.000050, 0.0500, 85.00, 'MAR');
CALL sp_insert_product('Ghassoul Arcilla Mineral',          'Cosmética Dermatológica', 'g',       0.000001, 0.0010,  4.50, 'MAR');
CALL sp_insert_product('Manteca de Karité Bruta MAR',       'Cosmética Capilar',       'g',       0.000001, 0.0010,  6.80, 'MAR');
CALL sp_insert_product('Jabón Negro Beldi Hammam',          'Jabones y Aromaterapia',  'g',       0.000001, 0.0010,  3.20, 'MAR');
CALL sp_insert_product('Agua de Rosas Marroquí',            'Cosmética Dermatológica', 'ml',      0.000030, 0.0310,  9.50, 'MAR');
CALL sp_insert_product('Aceite de Semilla de Higo Chumbo',  'Aceites Esenciales',      'ml',      0.000030, 0.0300,120.00, 'MAR');
CALL sp_insert_product('Ámbar Gris Extracto Marroquí',      'Jabones y Aromaterapia',  'g',       0.000001, 0.0020, 95.00, 'MAR');
CALL sp_insert_product('Crema de Argán y Aloe Vera',        'Cosmética Dermatológica', 'ml',      0.000050, 0.0500, 15.00, 'MAR');
CALL sp_insert_product('Sérum de Aceite de Argán',          'Cosmética Capilar',       'ml',      0.000030, 0.0300, 18.00, 'MAR');
CALL sp_insert_product('Mascarilla Capilar de Karité',      'Cosmética Capilar',       'g',       0.000001, 0.0010,  7.50, 'MAR');
CALL sp_insert_product('Exfoliante de Azúcar y Argán',      'Cosmética Dermatológica', 'g',       0.000001, 0.0010,  8.00, 'MAR');
CALL sp_insert_product('Aceite de Nigella Sativa',          'Aceites Esenciales',      'ml',      0.000030, 0.0300, 24.00, 'MAR');
CALL sp_insert_product('Polvo de Rassoul Amarillo',         'Cosmética Dermatológica', 'g',       0.000001, 0.0010,  5.20, 'MAR');
CALL sp_insert_product('Jabón de Argán y Menta',            'Jabones y Aromaterapia',  'g',       0.000001, 0.0010,  4.80, 'MAR');
CALL sp_insert_product('Aceite de Almendra Dulce MAR',      'Aceites Esenciales',      'ml',      0.000030, 0.0300, 11.00, 'MAR');
CALL sp_insert_product('Tónico Floral de Azahar',           'Cosmética Dermatológica', 'ml',      0.000030, 0.0310, 12.50, 'MAR');
CALL sp_insert_product('Bálsamo de Miel y Argán',           'Cosmética Dermatológica', 'g',       0.000001, 0.0015, 14.00, 'MAR');
CALL sp_insert_product('Aceite Esencial de Cedro Atlas',    'Jabones y Aromaterapia',  'ml',      0.000010, 0.0100, 32.00, 'MAR');

-- === India (IND) — Aceites y Bebidas ===
CALL sp_insert_product('Aceite de Coco Virgen IND',         'Aceites Esenciales',      'ml',      0.000030, 0.0280, 12.00, 'IND');
CALL sp_insert_product('Aceite de Sésamo Ayurvédico',       'Aceites Esenciales',      'ml',      0.000030, 0.0290,  9.50, 'IND');
CALL sp_insert_product('Aceite de Neem Puro',               'Aceites Esenciales',      'ml',      0.000030, 0.0300,  8.00, 'IND');
CALL sp_insert_product('Polvo de Cúrcuma Orgánica',         'Bebidas Funcionales',     'g',       0.000001, 0.0010,  3.80, 'IND');
CALL sp_insert_product('Ashwagandha en Polvo',              'Bebidas Funcionales',     'g',       0.000001, 0.0010,  7.20, 'IND');
CALL sp_insert_product('Aceite de Ricino Castor IND',       'Cosmética Capilar',       'ml',      0.000030, 0.0320,  6.50, 'IND');
CALL sp_insert_product('Ghee Clarificado Orgánico',         'Bebidas Funcionales',     'g',       0.000001, 0.0010, 18.00, 'IND');
CALL sp_insert_product('Masala de Especias Chai',           'Bebidas Funcionales',     'g',       0.000001, 0.0010,  5.50, 'IND');
CALL sp_insert_product('Aceite de Mostaza Puro',            'Aceites Esenciales',      'ml',      0.000030, 0.0300,  7.00, 'IND');
CALL sp_insert_product('Polvo de Amla Grosella India',      'Cosmética Capilar',       'g',       0.000001, 0.0010,  6.00, 'IND');
CALL sp_insert_product('Aceite de Brahmi Ayurveda',         'Cosmética Capilar',       'ml',      0.000030, 0.0300, 10.50, 'IND');
CALL sp_insert_product('Té de Tulsi Holy Basil',            'Bebidas Funcionales',     'g',       0.000001, 0.0010,  4.20, 'IND');
CALL sp_insert_product('Jabón de Nim y Cúrcuma',            'Jabones y Aromaterapia',  'g',       0.000001, 0.0010,  3.50, 'IND');
CALL sp_insert_product('Aceite de Semilla de Uva IND',      'Cosmética Dermatológica', 'ml',      0.000030, 0.0300, 13.00, 'IND');
CALL sp_insert_product('Pasta de Sándalo Kerala',           'Cosmética Dermatológica', 'g',       0.000001, 0.0010, 22.00, 'IND');
CALL sp_insert_product('Polvo de Moringa Orgánica IND',     'Bebidas Funcionales',     'g',       0.000001, 0.0010,  5.80, 'IND');
CALL sp_insert_product('Aceite de Jojoba IND',              'Aceites Esenciales',      'ml',      0.000030, 0.0290, 16.00, 'IND');
CALL sp_insert_product('Aceite de Semilla de Comino IND',   'Aceites Esenciales',      'ml',      0.000030, 0.0300, 11.50, 'IND');
CALL sp_insert_product('Manteca de Mango Bruta',            'Cosmética Dermatológica', 'g',       0.000001, 0.0010,  8.50, 'IND');
CALL sp_insert_product('Suplemento de Triphala en Polvo',   'Bebidas Funcionales',     'g',       0.000001, 0.0010,  9.00, 'IND');

-- === Brasil (BRA) — Amazonia Natural ===
CALL sp_insert_product('Aceite de Copaiba Amazónico',       'Aceites Esenciales',      'ml',      0.000030, 0.0300, 35.00, 'BRA');
CALL sp_insert_product('Aceite de Andiroba Puro',           'Aceites Esenciales',      'ml',      0.000030, 0.0300, 28.00, 'BRA');
CALL sp_insert_product('Manteca de Murumuru',               'Cosmética Capilar',       'g',       0.000001, 0.0010,  9.50, 'BRA');
CALL sp_insert_product('Aceite de Pracaxi',                 'Cosmética Capilar',       'ml',      0.000030, 0.0300, 32.00, 'BRA');
CALL sp_insert_product('Açaí en Polvo Liofilizado',         'Bebidas Funcionales',     'g',       0.000001, 0.0010, 14.00, 'BRA');
CALL sp_insert_product('Guaraná en Polvo Orgánico',         'Bebidas Funcionales',     'g',       0.000001, 0.0010, 11.00, 'BRA');
CALL sp_insert_product('Manteca de Cupuaçu Bruta',          'Cosmética Dermatológica', 'g',       0.000001, 0.0010, 12.50, 'BRA');
CALL sp_insert_product('Aceite de Buriti Amazónico',        'Cosmética Dermatológica', 'ml',      0.000030, 0.0300, 26.00, 'BRA');
CALL sp_insert_product('Jabón de Babaçu Natural',           'Jabones y Aromaterapia',  'g',       0.000001, 0.0010,  4.50, 'BRA');
CALL sp_insert_product('Extracto de Sangre de Drago',       'Cosmética Dermatológica', 'ml',      0.000010, 0.0100, 42.00, 'BRA');
CALL sp_insert_product('Aceite de Brasil Nut',              'Aceites Esenciales',      'ml',      0.000030, 0.0310, 19.00, 'BRA');
CALL sp_insert_product('Polvo de Maca Amazónica',           'Bebidas Funcionales',     'g',       0.000001, 0.0010,  8.00, 'BRA');
CALL sp_insert_product('Cera de Carnaúba Natural',          'Cosmética Dermatológica', 'g',       0.000001, 0.0010,  7.50, 'BRA');
CALL sp_insert_product('Extracto de Castaña de Cajú',       'Bebidas Funcionales',     'g',       0.000001, 0.0010,  6.50, 'BRA');
CALL sp_insert_product('Aceite de Ucuuba Amazónico',        'Aceites Esenciales',      'ml',      0.000030, 0.0300, 38.00, 'BRA');
CALL sp_insert_product('Jabón de Karité y Cupuaçu',         'Jabones y Aromaterapia',  'g',       0.000001, 0.0010,  5.20, 'BRA');
CALL sp_insert_product('Argila Verde Amazónica',            'Cosmética Dermatológica', 'g',       0.000001, 0.0010,  3.80, 'BRA');
CALL sp_insert_product('Aceite de Pitanga Cherry',          'Aceites Esenciales',      'ml',      0.000010, 0.0100, 48.00, 'BRA');
CALL sp_insert_product('Polvo de Camu Camu',                'Bebidas Funcionales',     'g',       0.000001, 0.0010, 22.00, 'BRA');
CALL sp_insert_product('Manteca de Tucumã Bruta',           'Cosmética Capilar',       'g',       0.000001, 0.0010, 11.00, 'BRA');

-- === Indonesia (IDN) — Especias y Tropicales ===
CALL sp_insert_product('Aceite de Ylang-Ylang IDN',         'Jabones y Aromaterapia',  'ml',      0.000010, 0.0100, 45.00, 'IDN');
CALL sp_insert_product('Aceite de Clavo de Olor IDN',       'Aceites Esenciales',      'ml',      0.000010, 0.0100, 18.00, 'IDN');
CALL sp_insert_product('Aceite de Vetiver IDN',             'Jabones y Aromaterapia',  'ml',      0.000010, 0.0100, 52.00, 'IDN');
CALL sp_insert_product('Aceite de Cananga Odorata',         'Aceites Esenciales',      'ml',      0.000010, 0.0100, 38.00, 'IDN');
CALL sp_insert_product('Manteca de Cacao Virgen IDN',       'Cosmética Dermatológica', 'g',       0.000001, 0.0010,  8.00, 'IDN');
CALL sp_insert_product('Aceite de Palma Roja IDN',          'Aceites Esenciales',      'ml',      0.000030, 0.0300, 10.00, 'IDN');
CALL sp_insert_product('Polvo de Jengibre Silvestre IDN',   'Bebidas Funcionales',     'g',       0.000001, 0.0010,  4.80, 'IDN');
CALL sp_insert_product('Aceite de Kayu Putih',              'Aceites Esenciales',      'ml',      0.000010, 0.0100, 22.00, 'IDN');
CALL sp_insert_product('Jabón de Carbón Activado IDN',      'Jabones y Aromaterapia',  'g',       0.000001, 0.0010,  5.50, 'IDN');
CALL sp_insert_product('Aceite de Jarak Castor IDN',        'Cosmética Capilar',       'ml',      0.000030, 0.0320,  7.20, 'IDN');
CALL sp_insert_product('Polvo de Kunyit Cúrcuma IDN',       'Bebidas Funcionales',     'g',       0.000001, 0.0010,  3.50, 'IDN');
CALL sp_insert_product('Aceite de Kelapa Coco IDN',         'Aceites Esenciales',      'ml',      0.000030, 0.0280,  9.00, 'IDN');
CALL sp_insert_product('Lulur Boreh Scrub Tradicional',     'Cosmética Dermatológica', 'g',       0.000001, 0.0010,  6.80, 'IDN');
CALL sp_insert_product('Aceite de Candlenut Kemiri',        'Cosmética Capilar',       'ml',      0.000030, 0.0300, 24.00, 'IDN');
CALL sp_insert_product('Extracto de Mangostán IDN',         'Bebidas Funcionales',     'ml',      0.000030, 0.0300, 15.00, 'IDN');
CALL sp_insert_product('Aceite Esencial de Patchouli IDN',  'Jabones y Aromaterapia',  'ml',      0.000010, 0.0100, 35.00, 'IDN');
CALL sp_insert_product('Mascarilla de Arcilla Volcánica IDN','Cosmética Dermatológica','g',       0.000001, 0.0010,  7.00, 'IDN');
CALL sp_insert_product('Jabón de Ylang y Coco',             'Jabones y Aromaterapia',  'g',       0.000001, 0.0010,  4.20, 'IDN');
CALL sp_insert_product('Aceite de Semilla de Kapok IDN',    'Aceites Esenciales',      'ml',      0.000030, 0.0300, 19.00, 'IDN');
CALL sp_insert_product('Polvo de Moringa IDN',              'Bebidas Funcionales',     'g',       0.000001, 0.0010,  5.00, 'IDN');

-- === Francia (FRA) — Alta Cosmética ===
CALL sp_insert_product('Aceite Esencial de Lavanda Provenzal','Jabones y Aromaterapia','ml',      0.000010, 0.0100, 38.00, 'FRA');
CALL sp_insert_product('Agua Floral de Lavanda FRA',        'Cosmética Dermatológica', 'ml',      0.000030, 0.0310,  9.00, 'FRA');
CALL sp_insert_product('Aceite Esencial de Rosa Centifolia','Aceites Esenciales',      'ml',      0.000010, 0.0100,220.00, 'FRA');
CALL sp_insert_product('Absoluto de Jazmín Grasse',         'Jabones y Aromaterapia',  'ml',      0.000010, 0.0100,185.00, 'FRA');
CALL sp_insert_product('Aceite Esencial de Neroli FRA',     'Aceites Esenciales',      'ml',      0.000010, 0.0100,145.00, 'FRA');
CALL sp_insert_product('Sérum de Péptidos Anti-edad FRA',   'Cosmética Dermatológica', 'ml',      0.000030, 0.0300, 55.00, 'FRA');
CALL sp_insert_product('Crema de Día SPF30 Provence',       'Cosmética Dermatológica', 'ml',      0.000050, 0.0500, 42.00, 'FRA');
CALL sp_insert_product('Aceite Seco Rosehip FRA',           'Cosmética Dermatológica', 'ml',      0.000030, 0.0300, 28.00, 'FRA');
CALL sp_insert_product('Mascarilla de Arcilla Caolín FRA',  'Cosmética Dermatológica', 'g',       0.000001, 0.0010, 18.00, 'FRA');
CALL sp_insert_product('Aceite Esencial de Petit Grain',    'Jabones y Aromaterapia',  'ml',      0.000010, 0.0100, 32.00, 'FRA');
CALL sp_insert_product('Agua Micelar de Rosa FRA',          'Cosmética Dermatológica', 'ml',      0.000050, 0.0510, 16.00, 'FRA');
CALL sp_insert_product('Aceite Esencial de Ylang FRA',      'Jabones y Aromaterapia',  'ml',      0.000010, 0.0100, 48.00, 'FRA');
CALL sp_insert_product('Cera de Abeja Orgánica FRA',        'Cosmética Dermatológica', 'g',       0.000001, 0.0010,  9.50, 'FRA');
CALL sp_insert_product('Jabón de Marsella Original 72%',    'Jabones y Aromaterapia',  'g',       0.000001, 0.0010,  5.80, 'FRA');
CALL sp_insert_product('Aceite Esencial de Romero FRA',     'Aceites Esenciales',      'ml',      0.000010, 0.0100, 22.00, 'FRA');
CALL sp_insert_product('Absoluto de Mimosa Grasse',         'Jabones y Aromaterapia',  'ml',      0.000010, 0.0100,160.00, 'FRA');
CALL sp_insert_product('Sérum Vitamina C Estabilizado',     'Cosmética Dermatológica', 'ml',      0.000030, 0.0300, 48.00, 'FRA');
CALL sp_insert_product('Aceite Esencial de Eucalipto FRA',  'Jabones y Aromaterapia',  'ml',      0.000010, 0.0100, 18.00, 'FRA');
CALL sp_insert_product('Bálsamo Labial de Miel y Cera FRA', 'Cosmética Dermatológica', 'g',       0.000001, 0.0010, 12.00, 'FRA');
CALL sp_insert_product('Aceite Esencial de Bergamota FRA',  'Jabones y Aromaterapia',  'ml',      0.000010, 0.0100, 28.00, 'FRA');

-- ─────────────────────────────────────────────────────────────
-- BLOQUE 9: Importaciones (cabecera + detalle + costos + inventario)
-- ─────────────────────────────────────────────────────────────

-- Importación Marruecos
CALL sp_register_import('Argan Premium SARL',      '2024-09-10', '2024-10-05', 'Aceite de Argán Puro',           5000.000, 28.50, 'HUB Principal Caribe', 2200.00, 450.00, 380.00, 120.00);
CALL sp_register_import('Argan Premium SARL',      '2024-09-10', '2024-10-05', 'Aceite de Rosa de Damasco',       800.000, 85.00, 'HUB Principal Caribe',  800.00, 200.00, 150.00,  80.00);
CALL sp_register_import('Argan Premium SARL',      '2024-09-10', '2024-10-05', 'Ghassoul Arcilla Mineral',      10000.000,  4.50, 'HUB Principal Caribe',  900.00, 180.00, 120.00,  50.00);
CALL sp_register_import('Argan Premium SARL',      '2024-09-10', '2024-10-05', 'Jabón Negro Beldi Hammam',       8000.000,  3.20, 'HUB Principal Caribe',  750.00, 150.00, 100.00,  40.00);

-- Importación India
CALL sp_register_import('Spice Route Exports Ltd', '2024-09-15', '2024-10-12', 'Polvo de Cúrcuma Orgánica',     12000.000,  3.80, 'HUB Principal Caribe', 1800.00, 300.00, 220.00,  90.00);
CALL sp_register_import('Spice Route Exports Ltd', '2024-09-15', '2024-10-12', 'Ashwagandha en Polvo',          6000.000,   7.20, 'HUB Principal Caribe', 1200.00, 240.00, 180.00,  70.00);
CALL sp_register_import('Spice Route Exports Ltd', '2024-09-15', '2024-10-12', 'Aceite de Ricino Castor IND',   4000.000,   6.50, 'HUB Principal Caribe',  950.00, 190.00, 140.00,  55.00);
CALL sp_register_import('Spice Route Exports Ltd', '2024-09-15', '2024-10-12', 'Aceite de Neem Puro',           5000.000,   8.00, 'HUB Principal Caribe', 1100.00, 220.00, 165.00,  60.00);

-- Importación Brasil
CALL sp_register_import('AmazonNatural Ltda',       '2024-09-20', '2024-10-18', 'Aceite de Copaiba Amazónico',  3000.000, 35.00, 'HUB Principal Caribe', 2800.00, 560.00, 420.00, 140.00);
CALL sp_register_import('AmazonNatural Ltda',       '2024-09-20', '2024-10-18', 'Açaí en Polvo Liofilizado',    5000.000, 14.00, 'HUB Principal Caribe', 1500.00, 300.00, 225.00,  80.00);
CALL sp_register_import('AmazonNatural Ltda',       '2024-09-20', '2024-10-18', 'Guaraná en Polvo Orgánico',    4000.000, 11.00, 'HUB Principal Caribe', 1200.00, 240.00, 180.00,  65.00);
CALL sp_register_import('AmazonNatural Ltda',       '2024-09-20', '2024-10-18', 'Manteca de Cupuaçu Bruta',     6000.000, 12.50, 'HUB Principal Caribe', 1400.00, 280.00, 210.00,  75.00);

-- Importación Indonesia
CALL sp_register_import('Nusantara Botanicals PT',  '2024-09-25', '2024-10-22', 'Aceite de Ylang-Ylang IDN',    1500.000, 45.00, 'HUB Principal Caribe', 1600.00, 320.00, 240.00,  90.00);
CALL sp_register_import('Nusantara Botanicals PT',  '2024-09-25', '2024-10-22', 'Aceite de Vetiver IDN',        1000.000, 52.00, 'HUB Principal Caribe', 1400.00, 280.00, 210.00,  80.00);
CALL sp_register_import('Nusantara Botanicals PT',  '2024-09-25', '2024-10-22', 'Manteca de Cacao Virgen IDN',  8000.000,  8.00, 'HUB Principal Caribe', 1100.00, 220.00, 165.00,  55.00);
CALL sp_register_import('Nusantara Botanicals PT',  '2024-09-25', '2024-10-22', 'Aceite Esencial de Patchouli IDN', 1200.000, 35.00, 'HUB Principal Caribe', 1500.00, 300.00, 225.00, 85.00);

-- Importación Francia
CALL sp_register_import('Provence Essences SAS',   '2024-10-01', '2024-10-28', 'Aceite Esencial de Lavanda Provenzal', 2000.000, 38.00, 'HUB Principal Caribe', 2500.00, 500.00, 375.00, 125.00);
CALL sp_register_import('Provence Essences SAS',   '2024-10-01', '2024-10-28', 'Aceite Esencial de Rosa Centifolia',  500.000, 220.00, 'HUB Principal Caribe', 1800.00, 360.00, 270.00, 100.00);
CALL sp_register_import('Provence Essences SAS',   '2024-10-01', '2024-10-28', 'Jabón de Marsella Original 72%',     10000.000, 5.80, 'HUB Principal Caribe', 1200.00, 240.00, 180.00,  65.00);
CALL sp_register_import('Provence Essences SAS',   '2024-10-01', '2024-10-28', 'Absoluto de Jazmín Grasse',           300.000, 185.00,'HUB Principal Caribe', 1600.00, 320.00, 240.00,  90.00);

-- ─────────────────────────────────────────────────────────────
-- BLOQUE 10: Permisos sanitarios (productos → países destino)
-- ─────────────────────────────────────────────────────────────

-- Colombia (COL) — INVIMA
CALL sp_insert_permit('Aceite de Argán Puro',           'COL', 'Registro INVIMA Cosméticos', 'INVIMA-COS-2024-001', 'INVIMA Colombia',         '2024-01-15', '2027-01-14', 850.00,  'ACTIVE');
CALL sp_insert_permit('Aceite de Rosa de Damasco',      'COL', 'Registro INVIMA Cosméticos', 'INVIMA-COS-2024-002', 'INVIMA Colombia',         '2024-02-10', '2027-02-09', 850.00,  'ACTIVE');
CALL sp_insert_permit('Polvo de Cúrcuma Orgánica',      'COL', 'Registro INVIMA Alimentos',  'INVIMA-ALI-2024-003', 'INVIMA Colombia',         '2024-03-01', '2027-02-28', 1200.00, 'ACTIVE');
CALL sp_insert_permit('Aceite de Ylang-Ylang IDN',      'COL', 'Registro INVIMA Cosméticos', 'INVIMA-COS-2024-004', 'INVIMA Colombia',         '2024-03-15', '2027-03-14', 850.00,  'ACTIVE');
CALL sp_insert_permit('Jabón de Marsella Original 72%', 'COL', 'Registro INVIMA Cosméticos', 'INVIMA-COS-2024-005', 'INVIMA Colombia',         '2024-04-01', '2027-03-31', 850.00,  'ACTIVE');

-- México (MEX) — COFEPRIS
CALL sp_insert_permit('Aceite de Argán Puro',           'MEX', 'Registro COFEPRIS Cosméticos','COFEPRIS-2024-1001', 'COFEPRIS México',         '2024-02-01', '2026-01-31', 1100.00, 'ACTIVE');
CALL sp_insert_permit('Aceite de Copaiba Amazónico',    'MEX', 'Registro COFEPRIS Cosméticos','COFEPRIS-2024-1002', 'COFEPRIS México',         '2024-02-15', '2026-02-14', 1100.00, 'ACTIVE');
CALL sp_insert_permit('Ashwagandha en Polvo',           'MEX', 'Registro COFEPRIS Suplementos','COFEPRIS-2024-1003','COFEPRIS México',         '2024-03-10', '2026-03-09', 1500.00, 'ACTIVE');
CALL sp_insert_permit('Aceite Esencial de Lavanda Provenzal','MEX','Registro COFEPRIS Cosméticos','COFEPRIS-2024-1004','COFEPRIS México',      '2024-04-01', '2026-03-31', 1100.00, 'ACTIVE');
CALL sp_insert_permit('Jabón Negro Beldi Hammam',       'MEX', 'Registro COFEPRIS Cosméticos','COFEPRIS-2024-1005', 'COFEPRIS México',         '2024-04-20', '2026-04-19', 1100.00, 'ACTIVE');

-- Perú (PER) — DIGEMID
CALL sp_insert_permit('Aceite de Argán Puro',           'PER', 'Registro DIGEMID Cosméticos', 'DIGEMID-2024-501', 'DIGEMID Perú',            '2024-01-20', '2026-01-19', 780.00,  'ACTIVE');
CALL sp_insert_permit('Guaraná en Polvo Orgánico',      'PER', 'Registro DIGEMID Alimentos',  'DIGEMID-2024-502', 'MINSA Perú',              '2024-02-05', '2026-02-04', 950.00,  'ACTIVE');
CALL sp_insert_permit('Aceite de Vetiver IDN',          'PER', 'Registro DIGEMID Cosméticos', 'DIGEMID-2024-503', 'DIGEMID Perú',            '2024-03-01', '2026-02-28', 780.00,  'ACTIVE');
CALL sp_insert_permit('Manteca de Cacao Virgen IDN',    'PER', 'Registro DIGEMID Cosméticos', 'DIGEMID-2024-504', 'DIGEMID Perú',            '2024-03-20', '2026-03-19', 780.00,  'ACTIVE');
CALL sp_insert_permit('Absoluto de Jazmín Grasse',      'PER', 'Registro DIGEMID Cosméticos', 'DIGEMID-2024-505', 'DIGEMID Perú',            '2024-04-10', '2026-04-09', 780.00,  'ACTIVE');

-- Chile (CHL) — ISP
CALL sp_insert_permit('Aceite de Argán Puro',           'CHL', 'Registro ISP Cosméticos',     'ISP-2024-2001', 'ISP Chile',                 '2024-01-25', '2027-01-24', 920.00,  'ACTIVE');
CALL sp_insert_permit('Açaí en Polvo Liofilizado',      'CHL', 'Registro ISP Alimentos',      'ISP-2024-2002', 'SEREMI Salud Chile',        '2024-02-20', '2027-02-19', 1050.00, 'ACTIVE');
CALL sp_insert_permit('Aceite Esencial de Lavanda Provenzal','CHL','Registro ISP Cosméticos',  'ISP-2024-2003', 'ISP Chile',                 '2024-03-15', '2027-03-14', 920.00,  'ACTIVE');
CALL sp_insert_permit('Jabón de Marsella Original 72%', 'CHL', 'Registro ISP Cosméticos',     'ISP-2024-2004', 'ISP Chile',                 '2024-04-05', '2027-04-04', 920.00,  'ACTIVE');
CALL sp_insert_permit('Aceite de Copaiba Amazónico',    'CHL', 'Registro ISP Cosméticos',     'ISP-2024-2005', 'ISP Chile',                 '2024-04-25', '2027-04-24', 920.00,  'ACTIVE');

-- Costa Rica (CRI) — MINSA
CALL sp_insert_permit('Aceite de Argán Puro',           'CRI', 'Registro MINSA Cosméticos',   'MINSA-CR-2024-101', 'MINSA Costa Rica',       '2024-02-01', '2026-01-31', 680.00,  'ACTIVE');
CALL sp_insert_permit('Polvo de Cúrcuma Orgánica',      'CRI', 'Registro MINSA Alimentos',    'MINSA-CR-2024-102', 'MINSA Costa Rica',       '2024-02-20', '2026-02-19', 820.00,  'ACTIVE');
CALL sp_insert_permit('Aceite de Ylang-Ylang IDN',      'CRI', 'Registro MINSA Cosméticos',   'MINSA-CR-2024-103', 'MINSA Costa Rica',       '2024-03-10', '2026-03-09', 680.00,  'ACTIVE');
CALL sp_insert_permit('Aceite de Neem Puro',            'CRI', 'Registro MINSA Cosméticos',   'MINSA-CR-2024-104', 'MINSA Costa Rica',       '2024-03-25', '2026-03-24', 680.00,  'ACTIVE');
CALL sp_insert_permit('Manteca de Cupuaçu Bruta',       'CRI', 'Registro MINSA Cosméticos',   'MINSA-CR-2024-105', 'MINSA Costa Rica',       '2024-04-15', '2026-04-14', 680.00,  'ACTIVE');

-- ─────────────────────────────────────────────────────────────
-- BLOQUE 11: Despachos hacia Dynamic Brands (ya con inventario disponible)
-- ─────────────────────────────────────────────────────────────
CALL sp_register_dispatch(1001, 'Aceite de Argán Puro',             500.000, 'HUB Principal Caribe', 'COL', 'VerdeLux',    TRUE);
CALL sp_register_dispatch(1002, 'Polvo de Cúrcuma Orgánica',        800.000, 'HUB Principal Caribe', 'COL', 'NaturPura',   TRUE);
CALL sp_register_dispatch(1003, 'Aceite de Ylang-Ylang IDN',        200.000, 'HUB Principal Caribe', 'MEX', 'AromaPura',   TRUE);
CALL sp_register_dispatch(1004, 'Aceite Esencial de Lavanda Provenzal', 300.000, 'HUB Principal Caribe', 'MEX', 'AromaPura', TRUE);
CALL sp_register_dispatch(1005, 'Aceite de Copaiba Amazónico',      400.000, 'HUB Principal Caribe', 'PER', 'BioVita',     TRUE);
CALL sp_register_dispatch(1006, 'Guaraná en Polvo Orgánico',        500.000, 'HUB Principal Caribe', 'PER', 'BioVita',     TRUE);
CALL sp_register_dispatch(1007, 'Jabón de Marsella Original 72%',  1000.000, 'HUB Principal Caribe', 'CHL', 'ZenBody',     TRUE);
CALL sp_register_dispatch(1008, 'Açaí en Polvo Liofilizado',        600.000, 'HUB Principal Caribe', 'CHL', 'ZenBody',     TRUE);
CALL sp_register_dispatch(1009, 'Aceite de Argán Puro',             350.000, 'HUB Principal Caribe', 'CRI', 'VerdeLux',    TRUE);
CALL sp_register_dispatch(1010, 'Manteca de Cupuaçu Bruta',         700.000, 'HUB Principal Caribe', 'CRI', 'NaturPura',   TRUE);
