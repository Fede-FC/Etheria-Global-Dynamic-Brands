-- =============================================================
--  ETHERIA GLOBAL — PostgreSQL 16
--  Rediseño v2: normalización completa, sin campos *_usd alambrados,
--  catálogos normalizados, inventario histórico, addresses, currencies,
--  auditoría checksum, campos enabled/is_deleted.
-- =============================================================

-- =============================================================
-- CATÁLOGO: Currencies  (moneda base configurable, no alambrada)
-- =============================================================
CREATE TABLE currencies (
    currency_id     SERIAL          PRIMARY KEY,
    currency_code   CHAR(3)         NOT NULL UNIQUE,
    currency_name   VARCHAR(80)     NOT NULL,
    currency_symbol VARCHAR(5),
    is_base         BOOLEAN         NOT NULL DEFAULT FALSE,  -- solo 1 puede ser TRUE
    enabled         BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by      VARCHAR(100)    NOT NULL DEFAULT CURRENT_USER,
    checksum        VARCHAR(64)
);

-- =============================================================
-- CATÁLOGO: Countries
-- =============================================================
CREATE TABLE countries (
    country_id      SERIAL          PRIMARY KEY,
    country_name    VARCHAR(100)    NOT NULL UNIQUE,
    iso_code        CHAR(3)         NOT NULL UNIQUE,
    region          VARCHAR(100),
    currency_id     INT             NOT NULL,
    enabled         BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by      VARCHAR(100)    NOT NULL DEFAULT CURRENT_USER,
    checksum        VARCHAR(64),

    CONSTRAINT fk_countries_currency
        FOREIGN KEY (currency_id) REFERENCES currencies(currency_id)
);

-- =============================================================
-- CATÁLOGO: States / Provinces
-- =============================================================
CREATE TABLE states (
    state_id    SERIAL          PRIMARY KEY,
    country_id  INT             NOT NULL,
    state_name  VARCHAR(100)    NOT NULL,
    state_code  VARCHAR(10),
    enabled     BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_states_country
        FOREIGN KEY (country_id) REFERENCES countries(country_id)
);

-- =============================================================
-- CATÁLOGO: Cities
-- =============================================================
CREATE TABLE cities (
    city_id     SERIAL          PRIMARY KEY,
    state_id    INT             NOT NULL,
    city_name   VARCHAR(100)    NOT NULL,
    enabled     BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_cities_state
        FOREIGN KEY (state_id) REFERENCES states(state_id)
);

-- =============================================================
-- PATRÓN: Addresses  (reutilizable por Suppliers, Warehouses, etc.)
-- =============================================================
CREATE TABLE addresses (
    address_id      SERIAL          PRIMARY KEY,
    address_line1   VARCHAR(200)    NOT NULL,
    address_line2   VARCHAR(200),
    city_id         INT             NOT NULL,
    postal_code     VARCHAR(20),
    enabled         BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by      VARCHAR(100)    NOT NULL DEFAULT CURRENT_USER,

    CONSTRAINT fk_addresses_city
        FOREIGN KEY (city_id) REFERENCES cities(city_id)
);

-- =============================================================
-- CATÁLOGO: Exchange_rates  (histórico, moneda base configurable)
-- =============================================================
CREATE TABLE exchange_rates (
    exchange_rate_id    SERIAL          PRIMARY KEY,
    currency_id         INT             NOT NULL,
    base_currency_id    INT             NOT NULL,  -- moneda base (la marcada is_base=TRUE)
    rate                DECIMAL(18,6)   NOT NULL,  -- cuántas unidades de base compra 1 unidad de currency
    rate_date           DATE            NOT NULL,
    source              VARCHAR(100),
    enabled             BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by          VARCHAR(100)    NOT NULL DEFAULT CURRENT_USER,
    checksum            VARCHAR(64),

    CONSTRAINT chk_exchange_rate_positive   CHECK (rate > 0),
    CONSTRAINT uq_exchange_rate_day         UNIQUE (currency_id, base_currency_id, rate_date),

    CONSTRAINT fk_exchange_rates_currency
        FOREIGN KEY (currency_id) REFERENCES currencies(currency_id),
    CONSTRAINT fk_exchange_rates_base
        FOREIGN KEY (base_currency_id) REFERENCES currencies(currency_id)
);

-- =============================================================
-- CATÁLOGO: Categories
-- =============================================================
CREATE TABLE categories (
    category_id     SERIAL          PRIMARY KEY,
    category_name   VARCHAR(100)    NOT NULL UNIQUE,
    description     VARCHAR(300),
    enabled         BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by      VARCHAR(100)    NOT NULL DEFAULT CURRENT_USER
);

-- =============================================================
-- CATÁLOGO: MeasurementUnits
-- =============================================================
CREATE TABLE measurement_units (
    unit_id     SERIAL          PRIMARY KEY,
    unit_code   VARCHAR(10)     NOT NULL UNIQUE,
    unit_name   VARCHAR(40)     NOT NULL,
    unit_type   VARCHAR(20)     NOT NULL,   -- WEIGHT | VOLUME | UNIT
    enabled     BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_unit_type CHECK (unit_type IN ('WEIGHT','VOLUME','UNIT'))
);

-- =============================================================
-- CATÁLOGO: CostTypes  (tipos de costo normalizados)
-- Responde: "Tipos de Costo" requerido por el profesor
-- =============================================================
CREATE TABLE cost_types (
    cost_type_id    SERIAL          PRIMARY KEY,
    cost_type_code  VARCHAR(30)     NOT NULL UNIQUE,
    cost_type_name  VARCHAR(100)    NOT NULL,
    description     VARCHAR(300),
    applies_to      VARCHAR(30)     NOT NULL,   -- IMPORT | LOGISTIC | TARIFF | PERMIT | SHIPPING
    enabled         BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_cost_type_applies CHECK (applies_to IN ('IMPORT','LOGISTIC','TARIFF','PERMIT','SHIPPING','OTHER'))
);

-- =============================================================
-- CATÁLOGO: PermitTypes  (tipos de permiso sanitario)
-- =============================================================
CREATE TABLE permit_types (
    permit_type_id      SERIAL          PRIMARY KEY,
    permit_type_code    VARCHAR(30)     NOT NULL UNIQUE,
    permit_type_name    VARCHAR(100)    NOT NULL,
    issuing_authority   VARCHAR(150),
    enabled             BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================
-- CATÁLOGO: ImportStatuses  (estados normalizados)
-- =============================================================
CREATE TABLE import_statuses (
    status_id   SERIAL          PRIMARY KEY,
    status_code VARCHAR(30)     NOT NULL UNIQUE,
    description VARCHAR(150),
    enabled     BOOLEAN         NOT NULL DEFAULT TRUE
);

-- =============================================================
-- MAESTRO: Suppliers
-- =============================================================
CREATE TABLE suppliers (
    supplier_id     SERIAL          PRIMARY KEY,
    supplier_name   VARCHAR(150)    NOT NULL,
    country_id      INT             NOT NULL,
    address_id      INT,
    contact_email   VARCHAR(150)    UNIQUE,
    contact_phone   VARCHAR(30),
    tax_id          VARCHAR(50),
    enabled         BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by      VARCHAR(100)    NOT NULL DEFAULT CURRENT_USER,
    checksum        VARCHAR(64),

    CONSTRAINT fk_suppliers_country
        FOREIGN KEY (country_id) REFERENCES countries(country_id),
    CONSTRAINT fk_suppliers_address
        FOREIGN KEY (address_id) REFERENCES addresses(address_id)
);

-- =============================================================
-- MAESTRO: Products  (base, sin marca — bulk)
-- =============================================================
CREATE TABLE products (
    product_id          SERIAL          PRIMARY KEY,
    product_name        VARCHAR(150)    NOT NULL,
    category_id         INT             NOT NULL,
    unit_id             INT             NOT NULL,
    unit_volume_m3      DECIMAL(10,6),
    unit_weight_kg      DECIMAL(10,4),
    origin_country_id   INT,
    enabled             BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by          VARCHAR(100)    NOT NULL DEFAULT CURRENT_USER,
    checksum            VARCHAR(64),

    CONSTRAINT fk_products_category
        FOREIGN KEY (category_id) REFERENCES categories(category_id),
    CONSTRAINT fk_products_unit
        FOREIGN KEY (unit_id) REFERENCES measurement_units(unit_id),
    CONSTRAINT fk_products_origin
        FOREIGN KEY (origin_country_id) REFERENCES countries(country_id)
);

-- =============================================================
-- MAESTRO: Warehouses  (HUB Nicaragua)
-- =============================================================
CREATE TABLE warehouses (
    warehouse_id        SERIAL          PRIMARY KEY,
    warehouse_name      VARCHAR(100)    NOT NULL,
    address_id          INT,
    warehouse_type_id   INT             NOT NULL,   -- FK a catálogo
    capacity_units      INT,
    enabled             BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by          VARCHAR(100)    NOT NULL DEFAULT CURRENT_USER,

    CONSTRAINT chk_warehouses_capacity CHECK (capacity_units IS NULL OR capacity_units > 0),
    CONSTRAINT fk_warehouses_address
        FOREIGN KEY (address_id) REFERENCES addresses(address_id)
);

-- CATÁLOGO: WarehouseTypes
CREATE TABLE warehouse_types (
    warehouse_type_id   SERIAL          PRIMARY KEY,
    type_code           VARCHAR(20)     NOT NULL UNIQUE,
    type_name           VARCHAR(60)     NOT NULL,
    enabled             BOOLEAN         NOT NULL DEFAULT TRUE,

    CONSTRAINT chk_wh_type CHECK (type_code IN ('RECEIVING','LABELING','DISPATCH','MIXED'))
);

ALTER TABLE warehouses ADD CONSTRAINT fk_warehouses_type
    FOREIGN KEY (warehouse_type_id) REFERENCES warehouse_types(warehouse_type_id);

-- =============================================================
-- TRANSACCIONAL: Imports  (órdenes de compra a proveedores)
-- =============================================================
CREATE TABLE imports (
    import_id       SERIAL          PRIMARY KEY,
    supplier_id     INT             NOT NULL,
    status_id       INT             NOT NULL,
    import_date     DATE            NOT NULL,
    expected_arrival DATE,
    actual_arrival  DATE,
    notes           TEXT,
    enabled         BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by      VARCHAR(100)    NOT NULL DEFAULT CURRENT_USER,
    checksum        VARCHAR(64),

    CONSTRAINT fk_imports_supplier
        FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id),
    CONSTRAINT fk_imports_status
        FOREIGN KEY (status_id) REFERENCES import_statuses(status_id)
);

-- =============================================================
-- TRANSACCIONAL: Import_details  (líneas por producto)
-- Montos en moneda del sistema (sin alambrar USD)
-- =============================================================
CREATE TABLE import_details (
    import_detail_id    SERIAL          PRIMARY KEY,
    import_id           INT             NOT NULL,
    product_id          INT             NOT NULL,
    quantity            DECIMAL(12,3)   NOT NULL,
    unit_cost           DECIMAL(14,4)   NOT NULL,   -- en moneda base del sistema
    currency_id         INT             NOT NULL,   -- moneda en que se pactó
    exchange_rate_id    INT             NOT NULL,   -- tipo de cambio aplicado
    subtotal            DECIMAL(16,4)   NOT NULL,
    created_at          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by          VARCHAR(100)    NOT NULL DEFAULT CURRENT_USER,
    checksum            VARCHAR(64),

    CONSTRAINT chk_import_details_qty      CHECK (quantity > 0),
    CONSTRAINT chk_import_details_cost     CHECK (unit_cost > 0),
    CONSTRAINT chk_import_details_subtotal CHECK (subtotal >= 0),

    CONSTRAINT fk_import_details_import
        FOREIGN KEY (import_id) REFERENCES imports(import_id),
    CONSTRAINT fk_import_details_product
        FOREIGN KEY (product_id) REFERENCES products(product_id),
    CONSTRAINT fk_import_details_currency
        FOREIGN KEY (currency_id) REFERENCES currencies(currency_id),
    CONSTRAINT fk_import_details_rate
        FOREIGN KEY (exchange_rate_id) REFERENCES exchange_rates(exchange_rate_id)
);

-- =============================================================
-- TRANSACCIONAL: Import_costs  (costos logísticos detallados por tipo)
-- Reemplaza la tabla logistic_costs monolítica
-- =============================================================
CREATE TABLE import_costs (
    import_cost_id      SERIAL          PRIMARY KEY,
    import_id           INT             NOT NULL,
    cost_type_id        INT             NOT NULL,
    amount              DECIMAL(14,4)   NOT NULL DEFAULT 0,
    currency_id         INT             NOT NULL,
    exchange_rate_id    INT             NOT NULL,
    notes               TEXT,
    created_at          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by          VARCHAR(100)    NOT NULL DEFAULT CURRENT_USER,

    CONSTRAINT chk_import_costs_amount CHECK (amount >= 0),

    CONSTRAINT fk_import_costs_import
        FOREIGN KEY (import_id) REFERENCES imports(import_id),
    CONSTRAINT fk_import_costs_type
        FOREIGN KEY (cost_type_id) REFERENCES cost_types(cost_type_id),
    CONSTRAINT fk_import_costs_currency
        FOREIGN KEY (currency_id) REFERENCES currencies(currency_id),
    CONSTRAINT fk_import_costs_rate
        FOREIGN KEY (exchange_rate_id) REFERENCES exchange_rates(exchange_rate_id)
);

-- =============================================================
-- TRANSACCIONAL: Import_tariffs  (aranceles por línea y país destino)
-- =============================================================
CREATE TABLE import_tariffs (
    tariff_id               SERIAL          PRIMARY KEY,
    import_detail_id        INT             NOT NULL,
    destination_country_id  INT             NOT NULL,
    cost_type_id            INT             NOT NULL,
    tariff_rate_percent     DECIMAL(5,2)    NOT NULL DEFAULT 0,
    amount                  DECIMAL(14,4)   NOT NULL,
    currency_id             INT             NOT NULL,
    exchange_rate_id        INT             NOT NULL,
    created_at              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by              VARCHAR(100)    NOT NULL DEFAULT CURRENT_USER,

    CONSTRAINT chk_tariff_rate   CHECK (tariff_rate_percent >= 0),
    CONSTRAINT chk_tariff_amount CHECK (amount >= 0),

    CONSTRAINT fk_import_tariffs_detail
        FOREIGN KEY (import_detail_id) REFERENCES import_details(import_detail_id),
    CONSTRAINT fk_import_tariffs_country
        FOREIGN KEY (destination_country_id) REFERENCES countries(country_id),
    CONSTRAINT fk_import_tariffs_type
        FOREIGN KEY (cost_type_id) REFERENCES cost_types(cost_type_id),
    CONSTRAINT fk_import_tariffs_currency
        FOREIGN KEY (currency_id) REFERENCES currencies(currency_id),
    CONSTRAINT fk_import_tariffs_rate
        FOREIGN KEY (exchange_rate_id) REFERENCES exchange_rates(exchange_rate_id)
);

-- =============================================================
-- TRANSACCIONAL: Product_permits  (permisos sanitarios)
-- =============================================================
CREATE TABLE product_permits (
    permit_id               SERIAL          PRIMARY KEY,
    product_id              INT             NOT NULL,
    destination_country_id  INT             NOT NULL,
    permit_type_id          INT             NOT NULL,
    permit_number           VARCHAR(100),
    valid_from              DATE            NOT NULL,
    valid_until             DATE,
    cost_amount             DECIMAL(12,4)   NOT NULL DEFAULT 0,
    currency_id             INT             NOT NULL,
    exchange_rate_id        INT             NOT NULL,
    status_id               INT             NOT NULL,
    enabled                 BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by              VARCHAR(100)    NOT NULL DEFAULT CURRENT_USER,

    CONSTRAINT uq_permit_product_country_type
        UNIQUE (product_id, destination_country_id, permit_type_id),

    CONSTRAINT fk_permits_product
        FOREIGN KEY (product_id) REFERENCES products(product_id),
    CONSTRAINT fk_permits_country
        FOREIGN KEY (destination_country_id) REFERENCES countries(country_id),
    CONSTRAINT fk_permits_type
        FOREIGN KEY (permit_type_id) REFERENCES permit_types(permit_type_id),
    CONSTRAINT fk_permits_currency
        FOREIGN KEY (currency_id) REFERENCES currencies(currency_id),
    CONSTRAINT fk_permits_rate
        FOREIGN KEY (exchange_rate_id) REFERENCES exchange_rates(exchange_rate_id),
    CONSTRAINT fk_permits_status
        FOREIGN KEY (status_id) REFERENCES import_statuses(status_id)
);

-- =============================================================
-- INVENTARIO HISTÓRICO: Inventory_movements  (doble entrada)
-- Control histórico completo — el stock se obtiene con SUM(quantity)
-- =============================================================
CREATE TABLE inventory_movements (
    movement_id     BIGSERIAL       PRIMARY KEY,
    warehouse_id    INT             NOT NULL,
    product_id      INT             NOT NULL,
    movement_type_id INT            NOT NULL,   -- FK a catálogo
    quantity        DECIMAL(12,3)   NOT NULL,   -- positivo=entrada, negativo=salida
    unit_cost       DECIMAL(14,4)   NOT NULL,
    currency_id     INT             NOT NULL,
    exchange_rate_id INT            NOT NULL,
    reference_type  VARCHAR(30),               -- IMPORT | DISPATCH | ADJUSTMENT | RETURN
    reference_id    INT,
    notes           TEXT,
    moved_at        TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    moved_by        VARCHAR(100)    NOT NULL DEFAULT CURRENT_USER,
    checksum        VARCHAR(64),

    CONSTRAINT fk_inv_warehouse
        FOREIGN KEY (warehouse_id) REFERENCES warehouses(warehouse_id),
    CONSTRAINT fk_inv_product
        FOREIGN KEY (product_id) REFERENCES products(product_id),
    CONSTRAINT fk_inv_currency
        FOREIGN KEY (currency_id) REFERENCES currencies(currency_id),
    CONSTRAINT fk_inv_rate
        FOREIGN KEY (exchange_rate_id) REFERENCES exchange_rates(exchange_rate_id)
);

-- CATÁLOGO: MovementTypes
CREATE TABLE movement_types (
    movement_type_id    SERIAL          PRIMARY KEY,
    type_code           VARCHAR(20)     NOT NULL UNIQUE,
    type_name           VARCHAR(60)     NOT NULL,
    direction           SMALLINT        NOT NULL,   -- +1 entrada, -1 salida
    enabled             BOOLEAN         NOT NULL DEFAULT TRUE,

    CONSTRAINT chk_mv_direction CHECK (direction IN (1,-1))
);

ALTER TABLE inventory_movements ADD CONSTRAINT fk_inv_movement_type
    FOREIGN KEY (movement_type_id) REFERENCES movement_types(movement_type_id);

-- =============================================================
-- TRANSACCIONAL: Dispatch_orders  (despacho HUB → país destino)
-- Tabla de integración ETL con Dynamic Brands
-- =============================================================
CREATE TABLE dispatch_orders (
    dispatch_order_id       BIGSERIAL       PRIMARY KEY,
    reference_order_id      INT             NOT NULL,   -- lógico: Orders.order_id de MySQL
    product_id              INT             NOT NULL,
    quantity                DECIMAL(12,3)   NOT NULL,
    warehouse_id            INT             NOT NULL,
    destination_country_id  INT             NOT NULL,
    brand_label             VARCHAR(150),
    packaging_permit_ok     BOOLEAN         NOT NULL DEFAULT FALSE,
    unit_cost               DECIMAL(14,4)   NOT NULL,
    currency_id             INT             NOT NULL,
    exchange_rate_id        INT             NOT NULL,
    dispatch_date           TIMESTAMP,
    courier_handoff_date    TIMESTAMP,
    status_id               INT             NOT NULL,
    enabled                 BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by              VARCHAR(100)    NOT NULL DEFAULT CURRENT_USER,
    checksum                VARCHAR(64),

    CONSTRAINT chk_dispatch_qty CHECK (quantity > 0),

    CONSTRAINT fk_dispatch_product
        FOREIGN KEY (product_id) REFERENCES products(product_id),
    CONSTRAINT fk_dispatch_warehouse
        FOREIGN KEY (warehouse_id) REFERENCES warehouses(warehouse_id),
    CONSTRAINT fk_dispatch_country
        FOREIGN KEY (destination_country_id) REFERENCES countries(country_id),
    CONSTRAINT fk_dispatch_currency
        FOREIGN KEY (currency_id) REFERENCES currencies(currency_id),
    CONSTRAINT fk_dispatch_rate
        FOREIGN KEY (exchange_rate_id) REFERENCES exchange_rates(exchange_rate_id),
    CONSTRAINT fk_dispatch_status
        FOREIGN KEY (status_id) REFERENCES import_statuses(status_id)
);

-- =============================================================
-- AUDITORÍA: Process_log
-- =============================================================
CREATE TABLE process_log (
    log_id              BIGSERIAL       PRIMARY KEY,
    sp_name             VARCHAR(100)    NOT NULL,
    action_description  TEXT            NOT NULL,
    affected_table      VARCHAR(100),
    affected_record_id  BIGINT,
    status              VARCHAR(20)     NOT NULL,
    error_detail        TEXT,
    executed_at         TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    executed_by         VARCHAR(100)    NOT NULL DEFAULT CURRENT_USER,

    CONSTRAINT chk_log_status CHECK (status IN ('INFO','SUCCESS','WARNING','ERROR'))
);

-- =============================================================
-- TABLA ETL: etl_profitability_summary
-- Destino del ETL — responde las 3 preguntas gerenciales
-- Vista sumarizada, alto nivel, sin detalle de órdenes
-- =============================================================
CREATE TABLE etl_profitability_summary (
    summary_id          BIGSERIAL       PRIMARY KEY,
    -- Dimensiones de análisis
    category_name       VARCHAR(100)    NOT NULL,
    brand_name          VARCHAR(150)    NOT NULL,
    site_url            VARCHAR(500),
    sale_country        VARCHAR(100)    NOT NULL,
    sale_currency_code  CHAR(3)         NOT NULL,
    base_currency_code  CHAR(3)         NOT NULL,
    -- Métricas de volumen
    total_orders        INT             NOT NULL DEFAULT 0,
    total_units_sold    DECIMAL(14,3)   NOT NULL DEFAULT 0,
    -- Ventas (en moneda local del país y en moneda base)
    revenue_local       DECIMAL(18,4)   NOT NULL DEFAULT 0,
    revenue_base        DECIMAL(18,4)   NOT NULL DEFAULT 0,
    -- Costos desglosados (en moneda base)
    cost_product        DECIMAL(18,4)   NOT NULL DEFAULT 0,
    cost_logistics      DECIMAL(18,4)   NOT NULL DEFAULT 0,
    cost_tariffs        DECIMAL(18,4)   NOT NULL DEFAULT 0,
    cost_permits        DECIMAL(18,4)   NOT NULL DEFAULT 0,
    cost_shipping       DECIMAL(18,4)   NOT NULL DEFAULT 0,
    cost_total          DECIMAL(18,4)   NOT NULL DEFAULT 0,
    -- Rentabilidad
    gross_margin        DECIMAL(18,4)   NOT NULL DEFAULT 0,
    gross_margin_pct    DECIMAL(8,4),
    roi_pct             DECIMAL(8,4),
    -- Control ETL
    etl_run_at          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    etl_period_from     DATE,
    etl_period_to       DATE
);

-- =============================================================
-- ÍNDICES
-- =============================================================
CREATE INDEX idx_countries_currency      ON countries(currency_id);
CREATE INDEX idx_states_country          ON states(country_id);
CREATE INDEX idx_cities_state            ON cities(state_id);
CREATE INDEX idx_addresses_city          ON addresses(city_id);
CREATE INDEX idx_exchange_currency_date  ON exchange_rates(currency_id, rate_date);
CREATE INDEX idx_suppliers_country       ON suppliers(country_id);
CREATE INDEX idx_products_category       ON products(category_id);
CREATE INDEX idx_products_origin         ON products(origin_country_id);
CREATE INDEX idx_imports_supplier        ON imports(supplier_id);
CREATE INDEX idx_imports_status          ON imports(status_id);
CREATE INDEX idx_import_details_import   ON import_details(import_id);
CREATE INDEX idx_import_details_product  ON import_details(product_id);
CREATE INDEX idx_import_costs_import     ON import_costs(import_id);
CREATE INDEX idx_import_costs_type       ON import_costs(cost_type_id);
CREATE INDEX idx_inv_product_warehouse   ON inventory_movements(product_id, warehouse_id);
CREATE INDEX idx_inv_reference           ON inventory_movements(reference_type, reference_id);
CREATE INDEX idx_inv_moved_at            ON inventory_movements(moved_at);
CREATE INDEX idx_dispatch_reference      ON dispatch_orders(reference_order_id);
CREATE INDEX idx_dispatch_status         ON dispatch_orders(status_id);
CREATE INDEX idx_dispatch_country        ON dispatch_orders(destination_country_id);
CREATE INDEX idx_etl_summary_category    ON etl_profitability_summary(category_name);
CREATE INDEX idx_etl_summary_brand       ON etl_profitability_summary(brand_name);
CREATE INDEX idx_etl_summary_country     ON etl_profitability_summary(sale_country);
CREATE INDEX idx_process_log_sp          ON process_log(sp_name);
CREATE INDEX idx_process_log_status      ON process_log(status);
CREATE INDEX idx_process_log_time        ON process_log(executed_at);
