-- =============================================================
--  ETHERIA GLOBAL — Base de Datos PostgreSQL 16
--  Database: etheria_global_db
--  Descripción: Cadena de suministro e importaciones de productos
--               naturales y curativos. HUB logístico en Nicaragua.
-- =============================================================

-- -------------------------------------------------------------
-- Crear y conectar a la base de datos
-- -------------------------------------------------------------
-- CREATE DATABASE etheria_global_db
--     ENCODING = 'UTF8'
--     LC_COLLATE = 'en_US.UTF-8'
--     LC_CTYPE = 'en_US.UTF-8'
--     TEMPLATE = template0;
-- 
-- \c etheria_global_db;

-- =============================================================
-- TABLA: Countries
-- Países de origen de proveedores y destinos de exportación
-- =============================================================
CREATE TABLE countries (
    country_id   SERIAL          PRIMARY KEY,
    country_name VARCHAR(100)    NOT NULL UNIQUE,
    iso_code     CHAR(3)         NOT NULL UNIQUE,
    region       VARCHAR(100),
    is_deleted   BOOLEAN         NOT NULL DEFAULT FALSE,
    created_at   TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================
-- TABLA: Categories
-- Categorías de productos (Aceites Esenciales, Cosmética, etc.)
-- =============================================================
CREATE TABLE categories (
    category_id          SERIAL          PRIMARY KEY,
    category_name        VARCHAR(100)    NOT NULL UNIQUE,
    category_description VARCHAR(200),
    is_deleted           BOOLEAN         NOT NULL DEFAULT FALSE,
    created_at           TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================
-- TABLA: MeasurementUnits
-- Unidades de medida para productos (kg, L, ml, unidades)
-- =============================================================
CREATE TABLE measurementUnits (
    measurementUnitId SERIAL       PRIMARY KEY,
    unitName          VARCHAR(20)  NOT NULL UNIQUE,
    is_deleted        BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at        TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================
-- TABLA: Suppliers
-- Proveedores internacionales que exportan a Nicaragua
-- =============================================================
CREATE TABLE suppliers (
    supplier_id    SERIAL          PRIMARY KEY,
    supplier_name  VARCHAR(150)    NOT NULL,
    country_id     INT             NOT NULL,
    contact_email  VARCHAR(150)    UNIQUE,
    contact_phone  VARCHAR(30),
    is_active      BOOLEAN         NOT NULL DEFAULT TRUE,
    is_deleted     BOOLEAN         NOT NULL DEFAULT FALSE,
    created_at     TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_suppliers_country
        FOREIGN KEY (country_id) REFERENCES Countries(country_id)
);

-- =============================================================
-- TABLA: Products
-- Productos base importados en bulk, sin marca ni etiquetado
-- =============================================================
CREATE TABLE products (
    product_id                 SERIAL           PRIMARY KEY,
    product_name               VARCHAR(150)     NOT NULL,
    category_id                INT              NOT NULL,
    base_unit_measurementUnitId INT             NOT NULL,
    unit_volume_m3             DECIMAL(10,6),
    unit_weight_kg             DECIMAL(10,4),
    base_cost_usd              DECIMAL(12,2)    NOT NULL,
    origin_country_id          INT,
    is_active                  BOOLEAN          NOT NULL DEFAULT TRUE,
    is_deleted                 BOOLEAN          NOT NULL DEFAULT FALSE,
    created_at                 TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at                 TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_products_base_cost     CHECK (base_cost_usd > 0),

    CONSTRAINT fk_products_category
        FOREIGN KEY (category_id) REFERENCES Categories(category_id),
    CONSTRAINT fk_products_unit
        FOREIGN KEY (base_unit_measurementUnitId) REFERENCES MeasurementUnits(measurementUnitId),
    CONSTRAINT fk_products_origin_country
        FOREIGN KEY (origin_country_id) REFERENCES Countries(country_id)
);

-- =============================================================
-- TABLA: Warehouses
-- Almacenes logísticos en el HUB de la costa Caribe de Nicaragua
-- =============================================================
CREATE TABLE warehouses (
    warehouse_id   SERIAL          PRIMARY KEY,
    name           VARCHAR(100)    NOT NULL,
    location       VARCHAR(150)    NOT NULL DEFAULT 'Nicaragua - Costa Caribe',
    warehouse_type VARCHAR(30),
    capacity_units INT,
    is_active      BOOLEAN         NOT NULL DEFAULT TRUE,
    is_deleted     BOOLEAN         NOT NULL DEFAULT FALSE,
    created_at     TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_warehouses_type
        CHECK (warehouse_type IN ('RECEIVING','LABELING','DISPATCH','MIXED')),
    CONSTRAINT chk_warehouses_capacity
        CHECK (capacity_units IS NULL OR capacity_units > 0)
);

-- =============================================================
-- TABLA: Imports
-- Órdenes de importación emitidas a proveedores
-- =============================================================
CREATE TABLE imports (
    import_id        SERIAL          PRIMARY KEY,
    supplier_id      INT             NOT NULL,
    import_date      DATE            NOT NULL,
    expected_arrival DATE,
    actual_arrival   DATE,
    status           VARCHAR(30)     NOT NULL DEFAULT 'PENDING',
    total_cost_usd   DECIMAL(14,2),
    notes            TEXT,
    created_at       TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_imports_status
        CHECK (status IN ('PENDING','SHIPPED','RECEIVED','CANCELLED')),
    CONSTRAINT chk_imports_total_cost
        CHECK (total_cost_usd IS NULL OR total_cost_usd >= 0),

    CONSTRAINT fk_imports_supplier
        FOREIGN KEY (supplier_id) REFERENCES Suppliers(supplier_id)
);

-- =============================================================
-- TABLA: Import_details
-- Líneas de detalle por producto dentro de cada importación
-- =============================================================
CREATE TABLE import_details (
    import_detail_id SERIAL           PRIMARY KEY,
    import_id        INT              NOT NULL,
    product_id       INT              NOT NULL,
    quantity         DECIMAL(12,3)    NOT NULL,
    unit_cost_usd    DECIMAL(12,2)    NOT NULL,
    subtotal_usd     DECIMAL(14,2)    NOT NULL,

    CONSTRAINT chk_import_details_quantity     CHECK (quantity > 0),
    CONSTRAINT chk_import_details_unit_cost    CHECK (unit_cost_usd > 0),
    CONSTRAINT chk_import_details_subtotal     CHECK (subtotal_usd >= 0),

    CONSTRAINT fk_import_details_import
        FOREIGN KEY (import_id) REFERENCES Imports(import_id),
    CONSTRAINT fk_import_details_product
        FOREIGN KEY (product_id) REFERENCES Products(product_id)
);

-- =============================================================
-- TABLA: Logistic_costs
-- Costos logísticos asociados a una importación (flete, seguro, puerto)
-- =============================================================
CREATE TABLE logistic_costs (
    logistic_cost_id   SERIAL          PRIMARY KEY,
    import_id          INT             NOT NULL UNIQUE,
    shipping_cost_usd  DECIMAL(12,2)   NOT NULL DEFAULT 0.00,
    insurance_cost_usd DECIMAL(12,2)   NOT NULL DEFAULT 0.00,
    port_handling_usd  DECIMAL(12,2)   NOT NULL DEFAULT 0.00,
    other_costs_usd    DECIMAL(12,2)   NOT NULL DEFAULT 0.00,
    notes              TEXT,

    CONSTRAINT chk_logistic_shipping   CHECK (shipping_cost_usd >= 0),
    CONSTRAINT chk_logistic_insurance  CHECK (insurance_cost_usd >= 0),
    CONSTRAINT chk_logistic_port       CHECK (port_handling_usd >= 0),
    CONSTRAINT chk_logistic_other      CHECK (other_costs_usd >= 0),

    CONSTRAINT fk_logistic_costs_import
        FOREIGN KEY (import_id) REFERENCES Imports(import_id)
);

-- =============================================================
-- TABLA: Import_tariffs
-- Aranceles e impuestos de importación por línea de detalle y país destino
-- =============================================================
CREATE TABLE import_tariffs (
    tariff_id              SERIAL           PRIMARY KEY,
    import_detail_id       INT              NOT NULL,
    destination_country_iso CHAR(3)         NOT NULL,
    tariff_type            VARCHAR(80)      NOT NULL,
    tariff_rate_percent    DECIMAL(5,2)     NOT NULL DEFAULT 0.00,
    tariff_amount_usd      DECIMAL(12,2)    NOT NULL,
    created_at             TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_tariff_rate    CHECK (tariff_rate_percent >= 0),
    CONSTRAINT chk_tariff_amount  CHECK (tariff_amount_usd >= 0),

    CONSTRAINT fk_import_tariffs_detail
        FOREIGN KEY (import_detail_id) REFERENCES Import_details(import_detail_id)
);

-- =============================================================
-- TABLA: Country_product_permits
-- Permisos sanitarios por producto y país de destino
-- =============================================================
CREATE TABLE country_product_permits (
    permit_id               SERIAL          PRIMARY KEY,
    product_id              INT             NOT NULL,
    destination_country_iso CHAR(3)         NOT NULL,
    permit_type             VARCHAR(100)    NOT NULL,
    permit_number           VARCHAR(100),
    issuing_authority       VARCHAR(150),
    valid_from              DATE            NOT NULL,
    valid_until             DATE,
    permit_cost_usd         DECIMAL(10,2)   NOT NULL DEFAULT 0.00,
    status                  VARCHAR(20)     NOT NULL DEFAULT 'PENDING',
    is_deleted              BOOLEAN         NOT NULL DEFAULT FALSE,
    created_at              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_permits_status
        CHECK (status IN ('ACTIVE','EXPIRED','PENDING','REJECTED')),
    CONSTRAINT chk_permits_cost
        CHECK (permit_cost_usd >= 0),
    CONSTRAINT uq_permits_product_country_type
        UNIQUE (product_id, destination_country_iso, permit_type),

    CONSTRAINT fk_permits_product
        FOREIGN KEY (product_id) REFERENCES Products(product_id)
);

-- =============================================================
-- TABLA: Inventory
-- Movimientos de inventario en el HUB (entradas, salidas, ajustes)
-- El stock disponible se obtiene con SUM(quantity) por producto
-- =============================================================
CREATE TABLE inventory (
    inventory_id      SERIAL           PRIMARY KEY,
    warehouse_id      INT              NOT NULL,
    product_id        INT              NOT NULL,
    quantity          DECIMAL(12,3)    NOT NULL,
    cost_per_unit_usd DECIMAL(12,4)    NOT NULL,
    movement_type     VARCHAR(30)      NOT NULL,
    reference_type    VARCHAR(30),
    reference_id      INT,
    moved_by          VARCHAR(100),
    notes             TEXT,
    moved_at          TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_inventory_movement_type
        CHECK (movement_type IN ('ENTRY','DISPATCH','ADJUSTMENT','RETURN','LOSS')),
    CONSTRAINT chk_inventory_reference_type
        CHECK (reference_type IS NULL OR reference_type IN ('IMPORT','DISPATCH','MANUAL','RETURN')),

    CONSTRAINT fk_inventory_warehouse
        FOREIGN KEY (warehouse_id) REFERENCES Warehouses(warehouse_id),
    CONSTRAINT fk_inventory_product
        FOREIGN KEY (product_id) REFERENCES Products(product_id)
);

-- =============================================================
-- TABLA: Exchange_rates
-- Tipos de cambio históricos de monedas locales a USD
-- =============================================================
CREATE TABLE exchange_rates (
    exchange_rate_id SERIAL           PRIMARY KEY,
    country_id       INT              NOT NULL,
    currency_code    CHAR(3)          NOT NULL,
    rate_to_usd      DECIMAL(18,6)    NOT NULL,
    rate_date        DATE             NOT NULL,
    source           VARCHAR(100),
    created_at       TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_exchange_rate_value
        CHECK (rate_to_usd > 0),

    CONSTRAINT fk_exchange_rates_country
        FOREIGN KEY (country_id) REFERENCES Countries(country_id)
);

-- =============================================================
-- TABLA: Dispatch_orders
-- Órdenes de despacho desde el HUB hacia el país destino
-- Tabla clave de integración ETL con Dynamic Brands
-- =============================================================
CREATE TABLE dispatch_orders (
    dispatch_order_id     SERIAL           PRIMARY KEY,
    reference_order_id    INT              NOT NULL,   -- FK lógica a Dynamic Brands Orders.order_id (integración ETL)
    product_id            INT              NOT NULL,
    quantity              DECIMAL(12,3)    NOT NULL,
    warehouse_id          INT              NOT NULL,
    destination_country_iso CHAR(3)        NOT NULL,
    brand_label           VARCHAR(150),
    packaging_permit_ok   BOOLEAN          NOT NULL DEFAULT FALSE,
    unit_cost_usd         DECIMAL(12,4)    NOT NULL,
    dispatch_date         TIMESTAMP,
    courier_handoff_date  TIMESTAMP,
    status                VARCHAR(30)      NOT NULL DEFAULT 'PENDING',
    is_deleted            BOOLEAN          NOT NULL DEFAULT FALSE,
    created_at            TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_dispatch_quantity
        CHECK (quantity > 0),
    CONSTRAINT chk_dispatch_status
        CHECK (status IN ('PENDING','PREPARING','LABELED','SHIPPED','DELIVERED','CANCELLED')),

    CONSTRAINT fk_dispatch_product
        FOREIGN KEY (product_id) REFERENCES Products(product_id),
    CONSTRAINT fk_dispatch_warehouse
        FOREIGN KEY (warehouse_id) REFERENCES Warehouses(warehouse_id)
);

-- =============================================================
-- TABLA: Process_log
-- Log de auditoría de todos los Stored Procedures
-- =============================================================
CREATE TABLE process_log (
    log_id             BIGSERIAL        PRIMARY KEY,
    sp_name            VARCHAR(100)     NOT NULL,
    action_description TEXT             NOT NULL,
    affected_table     VARCHAR(100),
    affected_record_id INT,
    status             VARCHAR(20)      NOT NULL,
    error_detail       TEXT,
    executed_at        TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    session_user_pg    VARCHAR(100)     NOT NULL DEFAULT current_user,

    CONSTRAINT chk_process_log_status
        CHECK (status IN ('INFO','SUCCESS','WARNING','ERROR'))
);

-- =============================================================
-- ÍNDICES para optimizar consultas frecuentes
-- =============================================================
CREATE INDEX idx_products_category      ON Products(category_id);
CREATE INDEX idx_products_origin        ON Products(origin_country_id);
CREATE INDEX idx_suppliers_country      ON Suppliers(country_id);
CREATE INDEX idx_imports_supplier       ON Imports(supplier_id);
CREATE INDEX idx_imports_status         ON Imports(status);
CREATE INDEX idx_import_details_import  ON Import_details(import_id);
CREATE INDEX idx_import_details_product ON Import_details(product_id);
CREATE INDEX idx_inventory_product      ON Inventory(product_id);
CREATE INDEX idx_inventory_warehouse    ON Inventory(warehouse_id);
CREATE INDEX idx_inventory_movement     ON Inventory(movement_type);
CREATE INDEX idx_dispatch_reference     ON Dispatch_orders(reference_order_id);
CREATE INDEX idx_dispatch_status        ON Dispatch_orders(status);
CREATE INDEX idx_dispatch_country       ON Dispatch_orders(destination_country_iso);
CREATE INDEX idx_permits_product        ON Country_product_permits(product_id);
CREATE INDEX idx_permits_country        ON Country_product_permits(destination_country_iso);
CREATE INDEX idx_exchange_country_date  ON Exchange_rates(country_id, rate_date);
CREATE INDEX idx_process_log_sp         ON Process_log(sp_name);
CREATE INDEX idx_process_log_status     ON Process_log(status);
CREATE INDEX idx_process_log_executed   ON Process_log(executed_at);
