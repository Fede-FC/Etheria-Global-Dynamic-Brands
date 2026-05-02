-- =============================================================
--  DYNAMIC BRANDS — MySQL 8.4
--  Rediseño v2: catálogos normalizados, sin campos *_usd alambrados,
--  inventario histórico, addresses, currencies, auditoría checksum.
-- =============================================================
SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;

-- =============================================================
-- IDEMPOTENTE: DROP de tablas en orden inverso de FKs
-- =============================================================
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS Shipping_records, Order_items, Orders, Inventory_movements,
    Website_product_prices, Website_products, Product_catalog,
    Customer_addresses, Customers, Websites, Brands, Brand_focuses,
    Shipping_statuses, Order_statuses, Exchange_rates,
    Cities, States, Addresses, Couriers, Process_log, Countries, Currencies;
SET FOREIGN_KEY_CHECKS = 1;

CREATE DATABASE IF NOT EXISTS dynamic_brands_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;
USE dynamic_brands_db;

-- =============================================================
-- CATÁLOGO: Currencies
-- =============================================================
CREATE TABLE Currencies (
    currency_id     INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    currency_code   CHAR(3)         NOT NULL,
    currency_name   VARCHAR(80)     NOT NULL,
    currency_symbol VARCHAR(5),
    is_base         TINYINT(1)      NOT NULL DEFAULT 0,
    enabled         TINYINT(1)      NOT NULL DEFAULT 1,
    created_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    updated_by      VARCHAR(100)    NOT NULL DEFAULT 'system',
    checksum        VARCHAR(64),

    PRIMARY KEY (currency_id),
    UNIQUE KEY uq_currency_code (currency_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
-- CATÁLOGO: Countries
-- =============================================================
CREATE TABLE Countries (
    country_id      INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    country_name    VARCHAR(100)    NOT NULL,
    iso_code        CHAR(3)         NOT NULL,
    currency_id     INT UNSIGNED    NOT NULL,
    enabled         TINYINT(1)      NOT NULL DEFAULT 1,
    created_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    updated_by      VARCHAR(100)    NOT NULL DEFAULT 'system',
    checksum        VARCHAR(64),

    PRIMARY KEY (country_id),
    UNIQUE KEY uq_countries_iso (iso_code),

    CONSTRAINT fk_countries_currency
        FOREIGN KEY (currency_id) REFERENCES Currencies(currency_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
-- CATÁLOGO: States
-- =============================================================
CREATE TABLE States (
    state_id    INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    country_id  INT UNSIGNED    NOT NULL,
    state_name  VARCHAR(100)    NOT NULL,
    state_code  VARCHAR(10),
    enabled     TINYINT(1)      NOT NULL DEFAULT 1,
    created_at  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (state_id),
    CONSTRAINT fk_states_country FOREIGN KEY (country_id) REFERENCES Countries(country_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
-- CATÁLOGO: Cities
-- =============================================================
CREATE TABLE Cities (
    city_id     INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    state_id    INT UNSIGNED    NOT NULL,
    city_name   VARCHAR(100)    NOT NULL,
    enabled     TINYINT(1)      NOT NULL DEFAULT 1,
    created_at  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (city_id),
    CONSTRAINT fk_cities_state FOREIGN KEY (state_id) REFERENCES States(state_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
-- PATRÓN: Addresses
-- =============================================================
CREATE TABLE Addresses (
    address_id      INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    address_line1   VARCHAR(200)    NOT NULL,
    address_line2   VARCHAR(200),
    city_id         INT UNSIGNED    NOT NULL,
    postal_code     VARCHAR(20),
    enabled         TINYINT(1)      NOT NULL DEFAULT 1,
    created_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    updated_by      VARCHAR(100)    NOT NULL DEFAULT 'system',

    PRIMARY KEY (address_id),
    CONSTRAINT fk_addresses_city FOREIGN KEY (city_id) REFERENCES Cities(city_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
-- CATÁLOGO: Exchange_rates  (histórico, moneda base configurable)
-- =============================================================
CREATE TABLE Exchange_rates (
    exchange_rate_id    INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    currency_id         INT UNSIGNED    NOT NULL,
    base_currency_id    INT UNSIGNED    NOT NULL,
    rate                DECIMAL(18,6)   NOT NULL,
    rate_date           DATE            NOT NULL,
    source              VARCHAR(100),
    enabled             TINYINT(1)      NOT NULL DEFAULT 1,
    created_at          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by          VARCHAR(100)    NOT NULL DEFAULT 'system',
    checksum            VARCHAR(64),

    PRIMARY KEY (exchange_rate_id),
    UNIQUE KEY uq_exchange_rate_day (currency_id, base_currency_id, rate_date),

    CONSTRAINT chk_exchange_rate_positive CHECK (rate > 0),

    CONSTRAINT fk_exchange_currency
        FOREIGN KEY (currency_id) REFERENCES Currencies(currency_id),
    CONSTRAINT fk_exchange_base
        FOREIGN KEY (base_currency_id) REFERENCES Currencies(currency_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
-- CATÁLOGO: Order_statuses  (estados normalizados)
-- =============================================================
CREATE TABLE Order_statuses (
    status_id   INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    status_code VARCHAR(30)     NOT NULL,
    description VARCHAR(150),
    enabled     TINYINT(1)      NOT NULL DEFAULT 1,

    PRIMARY KEY (status_id),
    UNIQUE KEY uq_order_status_code (status_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
-- CATÁLOGO: Shipping_statuses
-- =============================================================
CREATE TABLE Shipping_statuses (
    status_id   INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    status_code VARCHAR(30)     NOT NULL,
    description VARCHAR(150),
    enabled     TINYINT(1)      NOT NULL DEFAULT 1,

    PRIMARY KEY (status_id),
    UNIQUE KEY uq_shipping_status_code (status_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
-- CATÁLOGO: Brand_focuses  (enfoques de marca normalizados)
-- =============================================================
CREATE TABLE Brand_focuses (
    focus_id    INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    focus_code  VARCHAR(30)     NOT NULL,
    focus_name  VARCHAR(100)    NOT NULL,
    enabled     TINYINT(1)      NOT NULL DEFAULT 1,

    PRIMARY KEY (focus_id),
    UNIQUE KEY uq_focus_code (focus_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
-- MAESTRO: Brands  (marcas blancas generadas por IA)
-- =============================================================
CREATE TABLE Brands (
    brand_id            INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    brand_name          VARCHAR(150)    NOT NULL,
    brand_logo_url      VARCHAR(500),
    focus_id            INT UNSIGNED    NOT NULL,
    ai_model_version    VARCHAR(50),
    ai_generation_params JSON,
    generated_at        TIMESTAMP,
    enabled             TINYINT(1)      NOT NULL DEFAULT 1,
    created_at          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    updated_by          VARCHAR(100)    NOT NULL DEFAULT 'system',
    checksum            VARCHAR(64),

    PRIMARY KEY (brand_id),

    CONSTRAINT fk_brands_focus
        FOREIGN KEY (focus_id) REFERENCES Brand_focuses(focus_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
-- MAESTRO: Websites  (sitios e-commerce dinámicos por IA)
-- =============================================================
CREATE TABLE Websites (
    website_id      INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    brand_id        INT UNSIGNED    NOT NULL,
    country_id      INT UNSIGNED    NOT NULL,
    site_url        VARCHAR(500)    NOT NULL,
    marketing_focus VARCHAR(200),
    site_config     JSON,
    status_id       INT UNSIGNED    NOT NULL,
    launch_date     DATE,
    close_date      DATE,
    enabled         TINYINT(1)      NOT NULL DEFAULT 1,
    created_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    updated_by      VARCHAR(100)    NOT NULL DEFAULT 'system',
    checksum        VARCHAR(64),

    PRIMARY KEY (website_id),
    UNIQUE KEY uq_websites_url (site_url),

    CONSTRAINT fk_websites_brand
        FOREIGN KEY (brand_id) REFERENCES Brands(brand_id),
    CONSTRAINT fk_websites_country
        FOREIGN KEY (country_id) REFERENCES Countries(country_id),
    CONSTRAINT fk_websites_status
        FOREIGN KEY (status_id) REFERENCES Order_statuses(status_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
-- MAESTRO: Customers
-- =============================================================
CREATE TABLE Customers (
    customer_id INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    first_name  VARCHAR(80)     NOT NULL,
    last_name   VARCHAR(80)     NOT NULL,
    email       VARCHAR(150)    NOT NULL,
    phone       VARCHAR(30),
    country_id  INT UNSIGNED    NOT NULL,
    enabled     TINYINT(1)      NOT NULL DEFAULT 1,
    created_at  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    updated_by  VARCHAR(100)    NOT NULL DEFAULT 'system',
    checksum    VARCHAR(64),

    PRIMARY KEY (customer_id),
    UNIQUE KEY uq_customers_email (email),

    CONSTRAINT fk_customers_country
        FOREIGN KEY (country_id) REFERENCES Countries(country_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
-- PATRÓN: Customer_addresses  (direcciones del cliente)
-- =============================================================
CREATE TABLE Customer_addresses (
    customer_address_id INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    customer_id         INT UNSIGNED    NOT NULL,
    address_id          INT UNSIGNED    NOT NULL,
    is_default          TINYINT(1)      NOT NULL DEFAULT 0,
    enabled             TINYINT(1)      NOT NULL DEFAULT 1,
    created_at          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (customer_address_id),

    CONSTRAINT fk_caddr_customer FOREIGN KEY (customer_id) REFERENCES Customers(customer_id),
    CONSTRAINT fk_caddr_address  FOREIGN KEY (address_id)  REFERENCES Addresses(address_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
-- MAESTRO: Product_catalog  (catálogo con identidad de marca)
-- =============================================================
CREATE TABLE Product_catalog (
    catalog_product_id  INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    etheria_product_id  INT UNSIGNED    NOT NULL,
    brand_id            INT UNSIGNED    NOT NULL,
    branded_name        VARCHAR(150)    NOT NULL,
    branded_description TEXT,
    branded_image_url   VARCHAR(500),
    health_claims       TEXT,
    enabled             TINYINT(1)      NOT NULL DEFAULT 1,
    created_at          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    updated_by          VARCHAR(100)    NOT NULL DEFAULT 'system',
    checksum            VARCHAR(64),

    PRIMARY KEY (catalog_product_id),
    UNIQUE KEY uq_catalog_product_brand (etheria_product_id, brand_id),

    CONSTRAINT fk_catalog_brand
        FOREIGN KEY (brand_id) REFERENCES Brands(brand_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
-- MAESTRO: Website_products  (publicación por sitio)
-- =============================================================
CREATE TABLE Website_products (
    website_product_id  INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    website_id          INT UNSIGNED    NOT NULL,
    catalog_product_id  INT UNSIGNED    NOT NULL,
    is_featured         TINYINT(1)      NOT NULL DEFAULT 0,
    enabled             TINYINT(1)      NOT NULL DEFAULT 1,
    created_at          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    updated_by          VARCHAR(100)    NOT NULL DEFAULT 'system',

    PRIMARY KEY (website_product_id),
    UNIQUE KEY uq_website_product (website_id, catalog_product_id),

    CONSTRAINT fk_wp_website  FOREIGN KEY (website_id)         REFERENCES Websites(website_id),
    CONSTRAINT fk_wp_catalog  FOREIGN KEY (catalog_product_id) REFERENCES Product_catalog(catalog_product_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
-- HISTORIAL: Website_product_prices  (precios en moneda local)
-- =============================================================
CREATE TABLE Website_product_prices (
    price_id            INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    website_product_id  INT UNSIGNED    NOT NULL,
    sale_price          DECIMAL(14,4)   NOT NULL,
    currency_id         INT UNSIGNED    NOT NULL,
    valid_from          DATE            NOT NULL,
    valid_until         DATE,
    created_at          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by          VARCHAR(100)    NOT NULL DEFAULT 'system',

    PRIMARY KEY (price_id),
    CONSTRAINT chk_price_positive CHECK (sale_price > 0),

    CONSTRAINT fk_prices_wp       FOREIGN KEY (website_product_id) REFERENCES Website_products(website_product_id),
    CONSTRAINT fk_prices_currency FOREIGN KEY (currency_id)        REFERENCES Currencies(currency_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
-- INVENTARIO HISTÓRICO: Inventory_movements
-- =============================================================
CREATE TABLE Inventory_movements (
    movement_id     BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    website_product_id INT UNSIGNED NOT NULL,
    movement_type   VARCHAR(20)     NOT NULL,   -- IN | OUT | ADJUSTMENT | RETURN
    quantity        INT             NOT NULL,   -- positivo=entrada, negativo=salida
    reference_type  VARCHAR(30),               -- ORDER | RESTOCK | MANUAL
    reference_id    INT UNSIGNED,
    notes           TEXT,
    moved_at        TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    moved_by        VARCHAR(100)    NOT NULL DEFAULT 'system',
    checksum        VARCHAR(64),

    PRIMARY KEY (movement_id),
    CONSTRAINT chk_inv_mv_type CHECK (movement_type IN ('IN','OUT','ADJUSTMENT','RETURN')),

    CONSTRAINT fk_inv_mv_wp FOREIGN KEY (website_product_id) REFERENCES Website_products(website_product_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
-- TRANSACCIONAL: Orders
-- =============================================================
CREATE TABLE Orders (
    order_id                INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    customer_id             INT UNSIGNED    NOT NULL,
    website_id              INT UNSIGNED    NOT NULL,
    customer_address_id     INT UNSIGNED    NOT NULL,
    order_date              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    total_amount_local      DECIMAL(16,4)   NOT NULL,
    currency_id             INT UNSIGNED    NOT NULL,
    exchange_rate_id        INT UNSIGNED    NOT NULL,
    exchange_rate_snapshot  DECIMAL(18,6)   NOT NULL,
    total_amount_base       DECIMAL(16,4)   NOT NULL,   -- en moneda base, no alambrado a USD
    status_id               INT UNSIGNED    NOT NULL,
    etheria_dispatch_id     INT UNSIGNED,
    notes                   TEXT,
    enabled                 TINYINT(1)      NOT NULL DEFAULT 1,
    created_at              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    updated_by              VARCHAR(100)    NOT NULL DEFAULT 'system',
    checksum                VARCHAR(64),

    PRIMARY KEY (order_id),

    CONSTRAINT chk_orders_total_local   CHECK (total_amount_local >= 0),
    CONSTRAINT chk_orders_total_base    CHECK (total_amount_base >= 0),
    CONSTRAINT chk_orders_rate_snapshot CHECK (exchange_rate_snapshot > 0),

    CONSTRAINT fk_orders_customer  FOREIGN KEY (customer_id)         REFERENCES Customers(customer_id),
    CONSTRAINT fk_orders_website   FOREIGN KEY (website_id)          REFERENCES Websites(website_id),
    CONSTRAINT fk_orders_address   FOREIGN KEY (customer_address_id) REFERENCES Customer_addresses(customer_address_id),
    CONSTRAINT fk_orders_currency  FOREIGN KEY (currency_id)         REFERENCES Currencies(currency_id),
    CONSTRAINT fk_orders_rate      FOREIGN KEY (exchange_rate_id)    REFERENCES Exchange_rates(exchange_rate_id),
    CONSTRAINT fk_orders_status    FOREIGN KEY (status_id)           REFERENCES Order_statuses(status_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
-- TRANSACCIONAL: Order_items
-- =============================================================
CREATE TABLE Order_items (
    order_item_id       INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    order_id            INT UNSIGNED    NOT NULL,
    website_product_id  INT UNSIGNED    NOT NULL,
    quantity            INT UNSIGNED    NOT NULL,
    unit_price          DECIMAL(14,4)   NOT NULL,
    currency_id         INT UNSIGNED    NOT NULL,
    subtotal            DECIMAL(16,4)   NOT NULL,
    enabled             TINYINT(1)      NOT NULL DEFAULT 1,
    created_at          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by          VARCHAR(100)    NOT NULL DEFAULT 'system',

    PRIMARY KEY (order_item_id),
    CONSTRAINT chk_oi_qty      CHECK (quantity > 0),
    CONSTRAINT chk_oi_price    CHECK (unit_price > 0),
    CONSTRAINT chk_oi_subtotal CHECK (subtotal >= 0),

    CONSTRAINT fk_oi_order    FOREIGN KEY (order_id)           REFERENCES Orders(order_id),
    CONSTRAINT fk_oi_wp       FOREIGN KEY (website_product_id) REFERENCES Website_products(website_product_id),
    CONSTRAINT fk_oi_currency FOREIGN KEY (currency_id)        REFERENCES Currencies(currency_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
-- MAESTRO: Couriers
-- =============================================================
CREATE TABLE Couriers (
    courier_id      INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    courier_name    VARCHAR(100)    NOT NULL,
    contact_info    VARCHAR(200),
    enabled         TINYINT(1)      NOT NULL DEFAULT 1,
    created_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (courier_id),
    UNIQUE KEY uq_courier_name (courier_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
-- TRANSACCIONAL: Shipping_records
-- =============================================================
CREATE TABLE Shipping_records (
    shipping_id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    order_id                INT UNSIGNED    NOT NULL,
    courier_id              INT UNSIGNED    NOT NULL,
    tracking_code           VARCHAR(100),
    shipping_cost           DECIMAL(12,4)   NOT NULL DEFAULT 0,
    currency_id             INT UNSIGNED    NOT NULL,
    exchange_rate_id        INT UNSIGNED    NOT NULL,
    shipping_cost_base      DECIMAL(12,4)   NOT NULL DEFAULT 0,
    estimated_delivery_date DATE,
    actual_delivery_date    DATE,
    status_id               INT UNSIGNED    NOT NULL,
    health_permit_number    VARCHAR(100),
    enabled                 TINYINT(1)      NOT NULL DEFAULT 1,
    created_at              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    updated_by              VARCHAR(100)    NOT NULL DEFAULT 'system',

    PRIMARY KEY (shipping_id),
    UNIQUE KEY uq_shipping_order    (order_id),
    UNIQUE KEY uq_shipping_tracking (tracking_code),

    CONSTRAINT chk_shipping_cost_pos CHECK (shipping_cost >= 0),

    CONSTRAINT fk_shipping_order    FOREIGN KEY (order_id)          REFERENCES Orders(order_id),
    CONSTRAINT fk_shipping_courier  FOREIGN KEY (courier_id)        REFERENCES Couriers(courier_id),
    CONSTRAINT fk_shipping_currency FOREIGN KEY (currency_id)       REFERENCES Currencies(currency_id),
    CONSTRAINT fk_shipping_rate     FOREIGN KEY (exchange_rate_id)  REFERENCES Exchange_rates(exchange_rate_id),
    CONSTRAINT fk_shipping_status   FOREIGN KEY (status_id)         REFERENCES Shipping_statuses(status_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
-- AUDITORÍA: Process_log
-- =============================================================
CREATE TABLE Process_log (
    log_id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    sp_name             VARCHAR(100)    NOT NULL,
    action_description  TEXT            NOT NULL,
    affected_table      VARCHAR(100),
    affected_record_id  BIGINT UNSIGNED,
    status              VARCHAR(20)     NOT NULL,
    error_detail        TEXT,
    executed_at         TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    executed_by         VARCHAR(100)    NOT NULL DEFAULT (CURRENT_USER()),

    PRIMARY KEY (log_id),
    CONSTRAINT chk_log_status CHECK (status IN ('INFO','SUCCESS','WARNING','ERROR'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
-- ÍNDICES
-- =============================================================
CREATE INDEX idx_countries_currency     ON Countries(currency_id);
CREATE INDEX idx_states_country         ON States(country_id);
CREATE INDEX idx_cities_state           ON Cities(state_id);
CREATE INDEX idx_addresses_city         ON Addresses(city_id);
CREATE INDEX idx_exchange_currency_date ON Exchange_rates(currency_id, rate_date);
CREATE INDEX idx_brands_focus           ON Brands(focus_id);
CREATE INDEX idx_websites_brand         ON Websites(brand_id);
CREATE INDEX idx_websites_country       ON Websites(country_id);
CREATE INDEX idx_websites_status        ON Websites(status_id);
CREATE INDEX idx_customers_country      ON Customers(country_id);
CREATE INDEX idx_catalog_brand          ON Product_catalog(brand_id);
CREATE INDEX idx_catalog_etheria        ON Product_catalog(etheria_product_id);
CREATE INDEX idx_wp_website             ON Website_products(website_id);
CREATE INDEX idx_wp_catalog             ON Website_products(catalog_product_id);
CREATE INDEX idx_inv_mv_wp              ON Inventory_movements(website_product_id);
CREATE INDEX idx_orders_customer        ON Orders(customer_id);
CREATE INDEX idx_orders_website         ON Orders(website_id);
CREATE INDEX idx_orders_status          ON Orders(status_id);
CREATE INDEX idx_orders_dispatch        ON Orders(etheria_dispatch_id);
CREATE INDEX idx_oi_order               ON Order_items(order_id);
CREATE INDEX idx_oi_wp                  ON Order_items(website_product_id);
CREATE INDEX idx_shipping_courier       ON Shipping_records(courier_id);
CREATE INDEX idx_shipping_status        ON Shipping_records(status_id);
CREATE INDEX idx_process_log_sp         ON Process_log(sp_name);
CREATE INDEX idx_process_log_status     ON Process_log(status);
CREATE INDEX idx_process_log_time       ON Process_log(executed_at);
