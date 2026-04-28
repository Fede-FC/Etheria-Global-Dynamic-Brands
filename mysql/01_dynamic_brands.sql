-- =============================================================
--  DYNAMIC BRANDS — Base de Datos MySQL 8.4
--  Database: dynamic_brands_db
--  Descripción: Retail digital impulsado por IA. Gestiona sitios
--               e-commerce con marca blanca en Latam.
-- =============================================================

CREATE DATABASE IF NOT EXISTS dynamic_brands_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE dynamic_brands_db;

-- =============================================================
-- TABLA: Countries
-- Países donde Dynamic Brands opera o puede operar tiendas
-- =============================================================
CREATE TABLE Countries (
    country_id      INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    country_name    VARCHAR(100)    NOT NULL,
    iso_code        CHAR(3)         NOT NULL,
    currency_code   CHAR(3)         NOT NULL,
    currency_symbol VARCHAR(5),
    is_active       TINYINT(1)      NOT NULL DEFAULT 1,
    is_deleted      TINYINT(1)      NOT NULL DEFAULT 0,
    created_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (country_id),
    UNIQUE KEY uq_countries_name     (country_name),
    UNIQUE KEY uq_countries_iso      (iso_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
-- TABLA: Country_taxes
-- Impuestos al consumidor final por país (IVA, IGV, etc.)
-- =============================================================
CREATE TABLE Country_taxes (
    tax_id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    country_id         INT UNSIGNED    NOT NULL,
    tax_rate_percent   DECIMAL(5,2)    NOT NULL DEFAULT 0.00,
    regulatory_notes   TEXT,
    valid_from         DATE            NOT NULL,
    valid_until        DATE,
    created_at         TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (tax_id),

    CONSTRAINT chk_tax_rate
        CHECK (tax_rate_percent >= 0),

    CONSTRAINT fk_country_taxes_country
        FOREIGN KEY (country_id) REFERENCES Countries(country_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
-- TABLA: Exchange_rates
-- Tipos de cambio de moneda local a USD por país y fecha
-- =============================================================
CREATE TABLE Exchange_rates (
    exchange_rate_id INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    country_id       INT UNSIGNED    NOT NULL,
    currency_code    CHAR(3)         NOT NULL,
    rate_to_usd      DECIMAL(18,6)   NOT NULL,
    rate_date        DATE            NOT NULL,
    source           VARCHAR(100),
    created_at       TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (exchange_rate_id),
    UNIQUE KEY uq_exchange_country_date (country_id, rate_date),

    CONSTRAINT chk_exchange_rate
        CHECK (rate_to_usd > 0),

    CONSTRAINT fk_exchange_rates_country
        FOREIGN KEY (country_id) REFERENCES Countries(country_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
-- TABLA: Brands
-- Marcas blancas generadas por la IA de Dynamic Brands
-- =============================================================
CREATE TABLE Brands (
    brand_id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    brand_name           VARCHAR(150)    NOT NULL,
    brand_logo_url       VARCHAR(500),
    brand_focus          VARCHAR(100)    NOT NULL,
    ai_generation_params JSON,
    ai_model_version     VARCHAR(50),
    generated_at         TIMESTAMP,
    is_active            TINYINT(1)      NOT NULL DEFAULT 1,
    is_deleted           TINYINT(1)      NOT NULL DEFAULT 0,
    created_at           TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at           TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (brand_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
-- TABLA: Websites
-- Sitios de e-commerce dinámicos generados por la IA
-- =============================================================
CREATE TABLE Websites (
    website_id       INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    brand_id         INT UNSIGNED    NOT NULL,
    country_id       INT UNSIGNED    NOT NULL,
    site_url         VARCHAR(500)    NOT NULL,
    marketing_focus  VARCHAR(200),
    site_config      JSON,
    status           VARCHAR(20)     NOT NULL DEFAULT 'ACTIVE',
    launch_date      DATE,
    close_date       DATE,
    is_deleted       TINYINT(1)      NOT NULL DEFAULT 0,
    created_at       TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (website_id),
    UNIQUE KEY uq_websites_url (site_url),

    CONSTRAINT chk_websites_status
        CHECK (status IN ('ACTIVE','PAUSED','CLOSED')),

    CONSTRAINT fk_websites_brand
        FOREIGN KEY (brand_id) REFERENCES Brands(brand_id),
    CONSTRAINT fk_websites_country
        FOREIGN KEY (country_id) REFERENCES Countries(country_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
-- TABLA: Customers
-- Clientes finales registrados en la plataforma
-- =============================================================
CREATE TABLE Customers (
    customer_id INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    first_name  VARCHAR(80)     NOT NULL,
    last_name   VARCHAR(80)     NOT NULL,
    email       VARCHAR(150)    NOT NULL,
    phone       VARCHAR(30)     NOT NULL,
    country_id  INT UNSIGNED    NOT NULL,
    is_active   TINYINT(1)      NOT NULL DEFAULT 1,
    is_deleted  TINYINT(1)      NOT NULL DEFAULT 0,
    created_at  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (customer_id),
    UNIQUE KEY uq_customers_email (email),

    CONSTRAINT fk_customers_country
        FOREIGN KEY (country_id) REFERENCES Countries(country_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
-- TABLA: Customer_addresses
-- Direcciones de envío registradas por los clientes
-- =============================================================
CREATE TABLE Customer_addresses (
    address_id   INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    customer_id  INT UNSIGNED    NOT NULL,
    address_line VARCHAR(300)    NOT NULL,
    city         VARCHAR(100)    NOT NULL,
    country_id   INT UNSIGNED    NOT NULL,
    is_default   TINYINT(1)      NOT NULL DEFAULT 0,
    is_deleted   TINYINT(1)      NOT NULL DEFAULT 0,
    created_at   TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (address_id),

    CONSTRAINT fk_addresses_customer
        FOREIGN KEY (customer_id) REFERENCES Customers(customer_id),
    CONSTRAINT fk_addresses_country
        FOREIGN KEY (country_id) REFERENCES Countries(country_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
-- TABLA: Product_catalog
-- Catálogo central de productos con identidad de marca blanca
-- =============================================================
CREATE TABLE Product_catalog (
    catalog_product_id  INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    etheria_product_id  INT UNSIGNED    NOT NULL,   -- Referencia ETL a Products.product_id de Etheria Global
    brand_id            INT UNSIGNED    NOT NULL,
    branded_name        VARCHAR(150)    NOT NULL,
    branded_description TEXT,
    branded_image_url   VARCHAR(500),
    health_claims       TEXT,
    is_active           TINYINT(1)      NOT NULL DEFAULT 1,
    is_deleted          TINYINT(1)      NOT NULL DEFAULT 0,
    created_at          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (catalog_product_id),
    UNIQUE KEY uq_catalog_product_brand (etheria_product_id, brand_id),

    CONSTRAINT fk_catalog_brand
        FOREIGN KEY (brand_id) REFERENCES Brands(brand_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
-- TABLA: Website_products
-- Publicación de productos del catálogo en sitios específicos
-- =============================================================
CREATE TABLE Website_products (
    website_product_id  INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    website_id          INT UNSIGNED    NOT NULL,
    catalog_product_id  INT UNSIGNED    NOT NULL,
    is_featured         TINYINT(1)      NOT NULL DEFAULT 0,
    stock_display       INT UNSIGNED    NOT NULL DEFAULT 0,
    is_active           TINYINT(1)      NOT NULL DEFAULT 1,
    is_deleted          TINYINT(1)      NOT NULL DEFAULT 0,
    created_at          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (website_product_id),
    UNIQUE KEY uq_website_product (website_id, catalog_product_id),

    CONSTRAINT fk_website_products_website
        FOREIGN KEY (website_id) REFERENCES Websites(website_id),
    CONSTRAINT fk_website_products_catalog
        FOREIGN KEY (catalog_product_id) REFERENCES Product_catalog(catalog_product_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
-- TABLA: Website_product_prices
-- Historial de precios de venta en moneda local por producto y sitio
-- =============================================================
CREATE TABLE Website_product_prices (
    price_id            INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    website_product_id  INT UNSIGNED    NOT NULL,
    sale_price_local    DECIMAL(14,2)   NOT NULL,
    valid_from          DATE            NOT NULL,
    valid_until         DATE,
    created_at          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (price_id),

    CONSTRAINT chk_price_local
        CHECK (sale_price_local > 0),

    CONSTRAINT fk_prices_website_product
        FOREIGN KEY (website_product_id) REFERENCES Website_products(website_product_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
-- TABLA: Orders
-- Órdenes de compra del cliente final en los sitios web
-- =============================================================
CREATE TABLE Orders (
    order_id                INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    customer_id             INT UNSIGNED    NOT NULL,
    website_id              INT UNSIGNED    NOT NULL,
    address_id              INT UNSIGNED    NOT NULL,
    order_date              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    total_amount_local      DECIMAL(14,2)   NOT NULL,
    exchange_rate_id        INT UNSIGNED    NOT NULL,
    exchange_rate_snapshot  DECIMAL(18,6)   NOT NULL,
    total_amount_usd        DECIMAL(14,4)   NOT NULL,
    etheria_dispatch_id     INT UNSIGNED,              -- Referencia ETL a Dispatch_orders.dispatch_order_id de Etheria
    status                  VARCHAR(30)     NOT NULL DEFAULT 'PENDIENTE',
    notes                   TEXT,
    is_deleted              TINYINT(1)      NOT NULL DEFAULT 0,
    created_at              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (order_id),

    CONSTRAINT chk_orders_total_local
        CHECK (total_amount_local >= 0),
    CONSTRAINT chk_orders_total_usd
        CHECK (total_amount_usd >= 0),
    CONSTRAINT chk_orders_exchange_snapshot
        CHECK (exchange_rate_snapshot > 0),
    CONSTRAINT chk_orders_status
        CHECK (status IN ('PENDIENTE','CONFIRMADA','EN_PREPARACION','ENVIADA','ENTREGADA','CANCELADA','REEMBOLSADA')),

    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id) REFERENCES Customers(customer_id),
    CONSTRAINT fk_orders_website
        FOREIGN KEY (website_id) REFERENCES Websites(website_id),
    CONSTRAINT fk_orders_address
        FOREIGN KEY (address_id) REFERENCES Customer_addresses(address_id),
    CONSTRAINT fk_orders_exchange_rate
        FOREIGN KEY (exchange_rate_id) REFERENCES Exchange_rates(exchange_rate_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
-- TABLA: Order_items
-- Líneas de detalle de cada orden de compra
-- =============================================================
CREATE TABLE Order_items (
    order_item_id      INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    order_id           INT UNSIGNED    NOT NULL,
    website_product_id INT UNSIGNED    NOT NULL,
    quantity           INT UNSIGNED    NOT NULL,
    unit_price_local   DECIMAL(14,2)   NOT NULL,
    subtotal_local     DECIMAL(14,2)   NOT NULL,
    is_deleted         TINYINT(1)      NOT NULL DEFAULT 0,
    created_at         TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (order_item_id),

    CONSTRAINT chk_order_items_quantity      CHECK (quantity > 0),
    CONSTRAINT chk_order_items_unit_price    CHECK (unit_price_local > 0),
    CONSTRAINT chk_order_items_subtotal      CHECK (subtotal_local >= 0),

    CONSTRAINT fk_order_items_order
        FOREIGN KEY (order_id) REFERENCES Orders(order_id),
    CONSTRAINT fk_order_items_website_product
        FOREIGN KEY (website_product_id) REFERENCES Website_products(website_product_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
-- TABLA: Couriers
-- Servicios de courier externos para la entrega al cliente final
-- =============================================================
CREATE TABLE Couriers (
    courier_id   INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    courier_name VARCHAR(100)    NOT NULL,
    contact_info VARCHAR(200),
    is_active    TINYINT(1)      NOT NULL DEFAULT 1,
    created_at   TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (courier_id),
    UNIQUE KEY uq_couriers_name (courier_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
-- TABLA: Shipping_records
-- Registros de envío del courier: una orden = un envío
-- =============================================================
CREATE TABLE Shipping_records (
    shipping_id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    order_id                INT UNSIGNED    NOT NULL,
    courier_id              INT UNSIGNED    NOT NULL,
    tracking_code           VARCHAR(100),
    shipping_cost_local     DECIMAL(12,2)   NOT NULL DEFAULT 0.00,
    shipping_cost_usd       DECIMAL(12,2)   NOT NULL DEFAULT 0.00,
    estimated_delivery_date DATE,
    actual_delivery_date    DATE,
    status                  VARCHAR(30)     NOT NULL DEFAULT 'PENDIENTE',
    health_permit_number    VARCHAR(100),
    is_deleted              TINYINT(1)      NOT NULL DEFAULT 0,
    created_at              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (shipping_id),
    UNIQUE KEY uq_shipping_order   (order_id),
    UNIQUE KEY uq_shipping_tracking (tracking_code),

    CONSTRAINT chk_shipping_cost_local
        CHECK (shipping_cost_local >= 0),
    CONSTRAINT chk_shipping_cost_usd
        CHECK (shipping_cost_usd >= 0),
    CONSTRAINT chk_shipping_status
        CHECK (status IN ('PENDIENTE','RETIRADO_HUB','EN_TRANSITO','EN_ADUANA','ENTREGADO','FALLIDO','RETORNADO')),

    CONSTRAINT fk_shipping_order
        FOREIGN KEY (order_id) REFERENCES Orders(order_id),
    CONSTRAINT fk_shipping_courier
        FOREIGN KEY (courier_id) REFERENCES Couriers(courier_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
-- TABLA: Process_log
-- Log de auditoría de todos los Stored Procedures
-- =============================================================
CREATE TABLE Process_log (
    log_id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    sp_name            VARCHAR(100)    NOT NULL,
    action_description TEXT            NOT NULL,
    affected_table     VARCHAR(100),
    affected_record_id INT UNSIGNED,
    status             VARCHAR(20)     NOT NULL,
    error_detail       TEXT,
    executed_at        TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    db_user            VARCHAR(100)    NOT NULL DEFAULT (CURRENT_USER()),

    PRIMARY KEY (log_id),

    CONSTRAINT chk_process_log_status
        CHECK (status IN ('INFO','SUCCESS','WARNING','ERROR'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
-- ÍNDICES para optimizar consultas frecuentes
-- =============================================================
CREATE INDEX idx_websites_brand      ON Websites(brand_id);
CREATE INDEX idx_websites_country    ON Websites(country_id);
CREATE INDEX idx_websites_status     ON Websites(status);
CREATE INDEX idx_customers_country   ON Customers(country_id);
CREATE INDEX idx_catalog_brand       ON Product_catalog(brand_id);
CREATE INDEX idx_catalog_etheria     ON Product_catalog(etheria_product_id);
CREATE INDEX idx_wp_website          ON Website_products(website_id);
CREATE INDEX idx_wp_catalog          ON Website_products(catalog_product_id);
CREATE INDEX idx_orders_customer     ON Orders(customer_id);
CREATE INDEX idx_orders_website      ON Orders(website_id);
CREATE INDEX idx_orders_status       ON Orders(status);
CREATE INDEX idx_orders_dispatch     ON Orders(etheria_dispatch_id);
CREATE INDEX idx_order_items_order   ON Order_items(order_id);
CREATE INDEX idx_shipping_courier    ON Shipping_records(courier_id);
CREATE INDEX idx_shipping_status     ON Shipping_records(status);
CREATE INDEX idx_exchange_date       ON Exchange_rates(rate_date);
CREATE INDEX idx_process_log_sp      ON Process_log(sp_name);
CREATE INDEX idx_process_log_status  ON Process_log(status);
CREATE INDEX idx_process_log_time    ON Process_log(executed_at);
