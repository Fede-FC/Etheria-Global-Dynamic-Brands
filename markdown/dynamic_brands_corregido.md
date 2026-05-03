# 🔵 Dynamic Brands — Esquema de Base de Datos v2 (MySQL)

- Database engine: MySQL 8.4
- Database name: dynamic_brands_db
- Context: Rediseño v2 del sistema de retail digital impulsado por IA. Catálogos normalizados, moneda base configurable sin campos USD alambrados, inventario histórico, addresses y auditoría checksum. Gestiona sitios de e-commerce con marca blanca (white label) en distintos países de Latam, coordinando las órdenes hacia Etheria Global para su despacho desde el HUB en Nicaragua.

---

## Currencies

- currency_id
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único de la moneda

- currency_code
  - tipo: CHAR(3)
  - pk: no
  - restriccion: NOT NULL, UNIQUE
  - descripcion: código ISO 4217 de la moneda (ej: USD, COP, MXN)

- currency_name
  - tipo: VARCHAR(80)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: nombre completo de la moneda (ej: US Dollar, Peso Colombiano)

- currency_symbol
  - tipo: VARCHAR(5)
  - pk: no
  - descripcion: símbolo de la moneda (ej: $, S/, Q)

- is_base
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 0
  - descripcion: indica si esta es la moneda base del sistema; solo una moneda puede tener este valor en 1

- enabled
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 1
  - descripcion: indica si la moneda está activa en el sistema

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updated_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

- updated_by
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 'system'
  - descripcion: usuario o proceso que realizó la última modificación

- checksum
  - tipo: VARCHAR(64)
  - pk: no
  - descripcion: hash de auditoría para verificar integridad del registro

---

## Countries

- country_id
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único del país donde Dynamic Brands opera o puede operar tiendas

- country_name
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: nombre del país donde opera o puede operar una tienda (ej: Colombia, Perú, México)

- iso_code
  - tipo: CHAR(3)
  - pk: no
  - restriccion: NOT NULL, UNIQUE
  - descripcion: código ISO 3166-1 alpha-3 del país (ej: COL, PER, MEX)

- currency_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, FK → Currencies.currency_id
  - descripcion: moneda oficial del país

- enabled
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 1
  - descripcion: indica si el país está activo para la apertura de nuevas tiendas

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updated_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

- updated_by
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 'system'
  - descripcion: usuario o proceso que realizó la última modificación

- checksum
  - tipo: VARCHAR(64)
  - pk: no
  - descripcion: hash de auditoría para verificar integridad del registro

---

## States

- state_id
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único del estado o provincia

- country_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, FK → Countries.country_id
  - descripcion: país al que pertenece el estado o provincia

- state_name
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: nombre del estado o provincia

- state_code
  - tipo: VARCHAR(10)
  - pk: no
  - descripcion: código abreviado del estado o provincia

- enabled
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 1
  - descripcion: indica si el estado está activo en el sistema

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

---

## Cities

- city_id
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único de la ciudad

- state_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, FK → States.state_id
  - descripcion: estado o provincia al que pertenece la ciudad

- city_name
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: nombre de la ciudad

- enabled
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 1
  - descripcion: indica si la ciudad está activa en el sistema

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

---

## Addresses

- address_id
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único de la dirección; reutilizable por distintas entidades del sistema

- address_line1
  - tipo: VARCHAR(200)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: primera línea de la dirección (calle, número, edificio)

- address_line2
  - tipo: VARCHAR(200)
  - pk: no
  - descripcion: segunda línea de la dirección (apartamento, piso, referencia adicional)

- city_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, FK → Cities.city_id
  - descripcion: ciudad a la que pertenece esta dirección

- postal_code
  - tipo: VARCHAR(20)
  - pk: no
  - descripcion: código postal de la dirección

- enabled
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 1
  - descripcion: indica si la dirección está activa en el sistema

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updated_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

- updated_by
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 'system'
  - descripcion: usuario o proceso que realizó la última modificación

---

## Exchange_rates

- exchange_rate_id
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único del registro de tipo de cambio

- currency_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, FK → Currencies.currency_id
  - descripcion: moneda que se está convirtiendo

- base_currency_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, FK → Currencies.currency_id
  - descripcion: moneda base del sistema (la marcada con is_base = 1)

- rate
  - tipo: DECIMAL(18,6)
  - pk: no
  - restriccion: NOT NULL, CHECK > 0
  - descripcion: cantidad de unidades de la moneda base que equivalen a 1 unidad de la moneda de origen

- rate_date
  - tipo: DATE
  - pk: no
  - restriccion: NOT NULL
  - descripcion: fecha a la que corresponde la tasa de cambio registrada

- source
  - tipo: VARCHAR(100)
  - pk: no
  - descripcion: fuente de la tasa de cambio (ej: Banco Central, Open Exchange Rates API)

- enabled
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 1
  - descripcion: indica si el registro está activo

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updated_by
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 'system'
  - descripcion: usuario o proceso que creó el registro

- checksum
  - tipo: VARCHAR(64)
  - pk: no
  - descripcion: hash de auditoría para verificar integridad del registro

> **Restricción única:** UNIQUE(currency_id, base_currency_id, rate_date)

---

## Order_statuses

- status_id
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único del estado de orden

- status_code
  - tipo: VARCHAR(30)
  - pk: no
  - restriccion: NOT NULL, UNIQUE
  - descripcion: código del estado (ej: PENDIENTE, CONFIRMADA, EN_PREPARACION, ENVIADA, ENTREGADA, CANCELADA)

- description
  - tipo: VARCHAR(150)
  - pk: no
  - descripcion: descripción del estado y su significado en el ciclo de vida de la orden

- enabled
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 1
  - descripcion: indica si el estado está activo en el sistema

---

## Shipping_statuses

- status_id
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único del estado de envío

- status_code
  - tipo: VARCHAR(30)
  - pk: no
  - restriccion: NOT NULL, UNIQUE
  - descripcion: código del estado (ej: PENDIENTE, RETIRADO_HUB, EN_TRANSITO, EN_ADUANA, ENTREGADO, FALLIDO, RETORNADO)

- description
  - tipo: VARCHAR(150)
  - pk: no
  - descripcion: descripción del estado y su significado en el ciclo de vida del envío

- enabled
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 1
  - descripcion: indica si el estado está activo en el sistema

---

## Brand_focuses

- focus_id
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único del enfoque de marca

- focus_code
  - tipo: VARCHAR(30)
  - pk: no
  - restriccion: NOT NULL, UNIQUE
  - descripcion: código del enfoque de marca (ej: BIENESTAR, COSMETICA_NATURAL, NUTRICION_DEPORTIVA)

- focus_name
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: nombre descriptivo del enfoque o nicho de mercado de la marca

- enabled
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 1
  - descripcion: indica si el enfoque está activo en el sistema

---

## Brands

- brand_id
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único de la marca blanca generada por la IA

- brand_name
  - tipo: VARCHAR(150)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: nombre comercial de la marca blanca (ej: VerdeLux, AromaPura, BioVita)

- brand_logo_url
  - tipo: VARCHAR(500)
  - pk: no
  - descripcion: URL del logotipo generado por la IA para la marca

- focus_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, FK → Brand_focuses.focus_id
  - descripcion: enfoque o nicho de mercado de la marca según el catálogo normalizado

- ai_model_version
  - tipo: VARCHAR(50)
  - pk: no
  - descripcion: versión del modelo de IA que generó la marca (ej: v2.3-latam)

- ai_generation_params
  - tipo: JSON
  - pk: no
  - descripcion: parámetros JSON usados por la IA para generar la identidad de la marca (paleta de colores, tono, palabras clave)

- generated_at
  - tipo: TIMESTAMP
  - pk: no
  - descripcion: fecha y hora en que la IA generó la identidad de la marca

- enabled
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 1
  - descripcion: indica si la marca está activa y en uso

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updated_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

- updated_by
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 'system'
  - descripcion: usuario o proceso que realizó la última modificación

- checksum
  - tipo: VARCHAR(64)
  - pk: no
  - descripcion: hash de auditoría para verificar integridad del registro

---

## Websites

- website_id
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único del sitio de e-commerce dinámico

- brand_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, FK → Brands.brand_id
  - descripcion: marca blanca que representa y opera este sitio web

- country_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, FK → Countries.country_id
  - descripcion: país donde opera el sitio y al que está dirigido su marketing

- site_url
  - tipo: VARCHAR(500)
  - pk: no
  - restriccion: NOT NULL, UNIQUE
  - descripcion: URL del sitio de e-commerce (ej: naturapura.com.co, aromatica.mx)

- marketing_focus
  - tipo: VARCHAR(200)
  - pk: no
  - descripcion: mensaje o propuesta de valor central para ese mercado específico

- site_config
  - tipo: JSON
  - pk: no
  - descripcion: configuración visual del sitio generada por la IA (estilos, colores, fuentes, componentes activos)

- status_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, FK → Order_statuses.status_id
  - descripcion: estado operativo del sitio según el catálogo normalizado

- launch_date
  - tipo: DATE
  - pk: no
  - descripcion: fecha de lanzamiento del sitio al público

- close_date
  - tipo: DATE
  - pk: no
  - descripcion: fecha de cierre del sitio (NULL si sigue activo)

- enabled
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 1
  - descripcion: indica si el sitio está activo en el sistema

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updated_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

- updated_by
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 'system'
  - descripcion: usuario o proceso que realizó la última modificación

- checksum
  - tipo: VARCHAR(64)
  - pk: no
  - descripcion: hash de auditoría para verificar integridad del registro

---

## Customers

- customer_id
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único del cliente final

- first_name
  - tipo: VARCHAR(80)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: nombre del cliente

- last_name
  - tipo: VARCHAR(80)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: apellido del cliente

- email
  - tipo: VARCHAR(150)
  - pk: no
  - restriccion: NOT NULL, UNIQUE
  - descripcion: correo electrónico del cliente; usado como identificador único de cuenta

- phone
  - tipo: VARCHAR(30)
  - pk: no
  - descripcion: número de teléfono de contacto del cliente

- country_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, FK → Countries.country_id
  - descripcion: país de residencia del cliente

- enabled
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 1
  - descripcion: indica si la cuenta del cliente está activa

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updated_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

- updated_by
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 'system'
  - descripcion: usuario o proceso que realizó la última modificación

- checksum
  - tipo: VARCHAR(64)
  - pk: no
  - descripcion: hash de auditoría para verificar integridad del registro

---

## Customer_addresses

- customer_address_id
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único de la relación entre cliente y dirección de entrega

- customer_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, FK → Customers.customer_id
  - descripcion: cliente al que pertenece esta dirección

- address_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, FK → Addresses.address_id
  - descripcion: dirección asociada al cliente

- is_default
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 0
  - descripcion: indica si esta es la dirección de entrega predeterminada del cliente

- enabled
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 1
  - descripcion: indica si la dirección del cliente está activa

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

---

## Product_catalog

- catalog_product_id
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único del producto en el catálogo con identidad de marca

- etheria_product_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL
  - descripcion: referencia lógica al Products.product_id de la base PostgreSQL de Etheria Global

- brand_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, FK → Brands.brand_id
  - descripcion: marca blanca bajo la que se comercializa el producto

- branded_name
  - tipo: VARCHAR(150)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: nombre comercial del producto bajo la identidad de la marca blanca

- branded_description
  - tipo: TEXT
  - pk: no
  - descripcion: descripción del producto generada con la voz y tono de la marca blanca

- branded_image_url
  - tipo: VARCHAR(500)
  - pk: no
  - descripcion: URL de la imagen del producto con la identidad visual de la marca

- health_claims
  - tipo: TEXT
  - pk: no
  - descripcion: declaraciones de propiedades saludables del producto para uso en marketing digital

- enabled
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 1
  - descripcion: indica si el producto está activo en el catálogo

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updated_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

- updated_by
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 'system'
  - descripcion: usuario o proceso que realizó la última modificación

- checksum
  - tipo: VARCHAR(64)
  - pk: no
  - descripcion: hash de auditoría para verificar integridad del registro

> **Restricción única:** UNIQUE(etheria_product_id, brand_id)

---

## Website_products

- website_product_id
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único de la publicación de un producto en un sitio específico

- website_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, FK → Websites.website_id
  - descripcion: sitio e-commerce donde se publica el producto

- catalog_product_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, FK → Product_catalog.catalog_product_id
  - descripcion: producto del catálogo de marca que se publica en el sitio

- is_featured
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 0
  - descripcion: indica si el producto aparece como destacado en el sitio

- enabled
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 1
  - descripcion: indica si la publicación del producto está activa en el sitio

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updated_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

- updated_by
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 'system'
  - descripcion: usuario o proceso que realizó la última modificación

> **Restricción única:** UNIQUE(website_id, catalog_product_id)

---

## Website_product_prices

- price_id
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único del registro de precio de un producto en un sitio

- website_product_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, FK → Website_products.website_product_id
  - descripcion: publicación del producto a la que aplica este precio

- sale_price
  - tipo: DECIMAL(14,4)
  - pk: no
  - restriccion: NOT NULL, CHECK > 0
  - descripcion: precio de venta al público en la moneda local del sitio

- currency_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, FK → Currencies.currency_id
  - descripcion: moneda en que se expresa el precio de venta

- valid_from
  - tipo: DATE
  - pk: no
  - restriccion: NOT NULL
  - descripcion: fecha de inicio de vigencia de este precio

- valid_until
  - tipo: DATE
  - pk: no
  - descripcion: fecha de fin de vigencia del precio (NULL si está vigente)

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updated_by
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 'system'
  - descripcion: usuario o proceso que creó el registro

---

## Inventory_movements

- movement_id
  - tipo: BIGINT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único del movimiento de inventario; el stock actual se obtiene con SUM(quantity) por producto

- website_product_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, FK → Website_products.website_product_id
  - descripcion: publicación del producto afectada por el movimiento

- movement_type
  - tipo: VARCHAR(20)
  - pk: no
  - restriccion: NOT NULL, CHECK IN ('IN', 'OUT', 'ADJUSTMENT', 'RETURN')
  - descripcion: tipo de movimiento de inventario

- quantity
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL
  - descripcion: cantidad afectada; positiva para entradas, negativa para salidas

- reference_type
  - tipo: VARCHAR(30)
  - pk: no
  - descripcion: tipo de documento que originó el movimiento (ORDER, RESTOCK, MANUAL)

- reference_id
  - tipo: INT UNSIGNED
  - pk: no
  - descripcion: ID del documento origen del movimiento según su tipo de referencia

- notes
  - tipo: TEXT
  - pk: no
  - descripcion: observaciones adicionales sobre el movimiento de inventario

- moved_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora exacta en que se registró el movimiento

- moved_by
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 'system'
  - descripcion: usuario o proceso que registró el movimiento

- checksum
  - tipo: VARCHAR(64)
  - pk: no
  - descripcion: hash de auditoría para verificar integridad del registro

---

## Orders

- order_id
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único de la orden de compra del cliente final

- customer_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, FK → Customers.customer_id
  - descripcion: cliente que realizó la compra

- website_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, FK → Websites.website_id
  - descripcion: sitio web donde se originó la compra

- customer_address_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, FK → Customer_addresses.customer_address_id
  - descripcion: dirección de entrega seleccionada para esta orden

- order_date
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora exacta en que se realizó la orden

- total_amount_local
  - tipo: DECIMAL(16,4)
  - pk: no
  - restriccion: NOT NULL, CHECK >= 0
  - descripcion: monto total de la venta en la moneda local del país del sitio

- currency_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, FK → Currencies.currency_id
  - descripcion: moneda local del país en que se realizó la venta

- exchange_rate_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, FK → Exchange_rates.exchange_rate_id
  - descripcion: tasa de cambio vigente al momento de la venta; se referencia para preservar el valor histórico

- exchange_rate_snapshot
  - tipo: DECIMAL(18,6)
  - pk: no
  - restriccion: NOT NULL, CHECK > 0
  - descripcion: valor de la tasa de cambio al momento exacto de la venta (snapshot para trazabilidad histórica)

- total_amount_base
  - tipo: DECIMAL(16,4)
  - pk: no
  - restriccion: NOT NULL, CHECK >= 0
  - descripcion: monto total convertido a moneda base al momento de la venta; base para análisis de rentabilidad entre países

- status_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, FK → Order_statuses.status_id
  - descripcion: estado actual de la orden en su ciclo de vida según el catálogo normalizado

- etheria_dispatch_id
  - tipo: INT UNSIGNED
  - pk: no
  - descripcion: ID del despacho en Etheria Global (referencia de integración ETL)

- notes
  - tipo: TEXT
  - pk: no
  - descripcion: observaciones o instrucciones especiales del cliente para la orden

- enabled
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 1
  - descripcion: indica si el registro de la orden está activo

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updated_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

- updated_by
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 'system'
  - descripcion: usuario o proceso que realizó la última modificación

- checksum
  - tipo: VARCHAR(64)
  - pk: no
  - descripcion: hash de auditoría para verificar integridad del registro

---

## Order_items

- order_item_id
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único de la línea de detalle de la orden

- order_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, FK → Orders.order_id
  - descripcion: orden a la que pertenece esta línea de detalle

- website_product_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, FK → Website_products.website_product_id
  - descripcion: producto del sitio que fue comprado en esta línea

- quantity
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, CHECK > 0
  - descripcion: cantidad de unidades compradas de este producto

- unit_price
  - tipo: DECIMAL(14,4)
  - pk: no
  - restriccion: NOT NULL, CHECK > 0
  - descripcion: precio unitario en moneda local al momento de la compra (se congela para preservar el valor histórico)

- currency_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, FK → Currencies.currency_id
  - descripcion: moneda local en que se expresa el precio unitario

- subtotal
  - tipo: DECIMAL(16,4)
  - pk: no
  - restriccion: NOT NULL, CHECK >= 0
  - descripcion: subtotal de la línea en moneda local (quantity × unit_price)

- enabled
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 1
  - descripcion: indica si el registro está activo

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updated_by
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 'system'
  - descripcion: usuario o proceso que creó el registro

---

## Couriers

- courier_id
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único del courier registrado en el sistema

- courier_name
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL, UNIQUE
  - descripcion: nombre del courier externo (ej: DHL, FedEx, Correos de Costa Rica)

- contact_info
  - tipo: VARCHAR(200)
  - pk: no
  - descripcion: información de contacto del courier

- enabled
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 1
  - descripcion: indica si el courier está activo y disponible para asignar envíos

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

---

## Shipping_records

- shipping_id
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único del registro de envío

- order_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, UNIQUE, FK → Orders.order_id
  - descripcion: orden a la que corresponde este envío (una orden tiene un solo envío)

- courier_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, FK → Couriers.courier_id
  - descripcion: courier externo encargado del envío

- tracking_code
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: UNIQUE
  - descripcion: código de rastreo proporcionado por el courier

- shipping_cost
  - tipo: DECIMAL(12,4)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 0, CHECK >= 0
  - descripcion: costo del envío en la moneda local indicada

- currency_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, FK → Currencies.currency_id
  - descripcion: moneda en que se registra el costo del envío

- exchange_rate_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, FK → Exchange_rates.exchange_rate_id
  - descripcion: tipo de cambio aplicado al momento de registrar el costo de envío

- shipping_cost_base
  - tipo: DECIMAL(12,4)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 0
  - descripcion: costo del envío convertido a moneda base; necesario para el cálculo de margen real por país

- estimated_delivery_date
  - tipo: DATE
  - pk: no
  - descripcion: fecha estimada de entrega al cliente final

- actual_delivery_date
  - tipo: DATE
  - pk: no
  - descripcion: fecha real en que el courier entregó el paquete al cliente

- status_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, FK → Shipping_statuses.status_id
  - descripcion: estado actual del envío según el courier y el catálogo normalizado

- health_permit_number
  - tipo: VARCHAR(100)
  - pk: no
  - descripcion: número del permiso sanitario requerido para la importación en el país destino

- enabled
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 1
  - descripcion: indica si el registro de envío está activo

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updated_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

- updated_by
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 'system'
  - descripcion: usuario o proceso que realizó la última modificación

---

## Process_log

- log_id
  - tipo: BIGINT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único del registro de log

- sp_name
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: nombre del Stored Procedure que generó este registro de log

- action_description
  - tipo: TEXT
  - pk: no
  - restriccion: NOT NULL
  - descripcion: descripción detallada del paso o acción ejecutada dentro del SP

- affected_table
  - tipo: VARCHAR(100)
  - pk: no
  - descripcion: nombre de la tabla sobre la que se realizó la operación

- affected_record_id
  - tipo: BIGINT UNSIGNED
  - pk: no
  - descripcion: ID del registro afectado por la operación

- status
  - tipo: VARCHAR(20)
  - pk: no
  - restriccion: NOT NULL, CHECK IN ('INFO', 'SUCCESS', 'WARNING', 'ERROR')
  - descripcion: resultado de la acción ejecutada; ERROR activa revisión manual del proceso

- error_detail
  - tipo: TEXT
  - pk: no
  - descripcion: detalle técnico del error capturado en el bloque DECLARE HANDLER; solo se llena cuando status = 'ERROR'

- executed_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora exacta en que se generó el registro de log

- executed_by
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL, DEFAULT (CURRENT_USER())
  - descripcion: usuario de base de datos que ejecutó el SP
