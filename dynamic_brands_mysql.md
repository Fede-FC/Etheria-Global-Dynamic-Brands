# 🔵 Dynamic Brands — Esquema de Base de Datos (MySQL)

- Database engine: MySQL 8.4
- Database name: dynamic_brands_db
- Context: Sistema de retail digital impulsado por IA. Gestiona sitios de e-commerce con marca blanca (white label) en distintos países de Latam, recibiendo demanda del consumidor final y coordinando las órdenes de productos hacia Etheria Global para su despacho desde el HUB en Nicaragua.

---

## Countries

- country_id
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único del país donde Dynamic Brands opera o puede operar tiendas

- country_name
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL, UNIQUE
  - descripcion: nombre completo del país (ej: Colombia, Perú, México)

- iso_code
  - tipo: CHAR(3)
  - pk: no
  - restriccion: NOT NULL, UNIQUE
  - descripcion: código ISO 3166-1 alpha-3 del país (ej: COL, PER, MEX)

- currency_code
  - tipo: CHAR(3)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: código ISO 4217 de la moneda local (ej: COP, PEN, MXN)

- currency_symbol
  - tipo: VARCHAR(5)
  - pk: no
  - descripcion: símbolo de la moneda local (ej: $, S/, Q)

- tax_rate_percent
  - tipo: DECIMAL(5,2)
  - pk: no
  - restriccion: DEFAULT 0.00, CHECK >= 0
  - descripcion: porcentaje de impuesto al consumidor final aplicable en el país (IVA, IGV, etc.)

- regulatory_notes
  - tipo: TEXT
  - pk: no
  - descripcion: notas sobre requisitos legales o sanitarios para la venta de productos de salud y belleza en el país

- is_active
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 1
  - descripcion: indica si el país está activo para la apertura de nuevas tiendas

- is_deleted
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 0
  - descripcion: borrado lógico del registro

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updated_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

---

## Exchange_rates

- rate_id
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único del registro de tipo de cambio

- currency_code
  - tipo: CHAR(3)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: código ISO 4217 de la moneda (ej: COP, MXN, PEN); referencia lógica a Countries.currency_code

- rate_to_usd
  - tipo: DECIMAL(18,6)
  - pk: no
  - restriccion: NOT NULL, CHECK > 0
  - descripcion: cantidad de unidades de moneda local equivalentes a 1 USD (ej: 4000.00 para COP)

- rate_date
  - tipo: DATE
  - pk: no
  - restriccion: NOT NULL
  - descripcion: fecha a la que corresponde la tasa de cambio registrada

- source
  - tipo: VARCHAR(50)
  - pk: no
  - descripcion: fuente de la tasa de cambio (ej: 'Banco Central', 'Open Exchange Rates API')

- is_deleted
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 0
  - descripcion: borrado lógico del registro

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

> **Restricción única:** UNIQUE(currency_code, rate_date)

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

- brand_focus
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: enfoque o nicho de mercado de la marca (ej: bienestar holístico, cosmética natural, nutrición deportiva)

- ai_generation_params
  - tipo: JSON
  - pk: no
  - descripcion: parámetros JSON usados por la IA para generar la identidad de la marca (paleta de colores, tono, palabras clave)

- ai_model_version
  - tipo: VARCHAR(50)
  - pk: no
  - descripcion: versión del modelo de IA que generó la marca (ej: 'v2.3-latam'); permite auditar qué versión produce mejores resultados comerciales

- generated_at
  - tipo: TIMESTAMP
  - pk: no
  - descripcion: fecha y hora en que la IA generó la identidad de la marca

- is_active
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 1
  - descripcion: indica si la marca está activa y en uso

- is_deleted
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 0
  - descripcion: borrado lógico del registro

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updated_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

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
  - tipo: VARCHAR(255)
  - pk: no
  - restriccion: NOT NULL, UNIQUE
  - descripcion: URL del sitio de e-commerce (ej: naturapura.com.co, aromatica.mx)

- marketing_focus
  - tipo: VARCHAR(150)
  - pk: no
  - descripcion: mensaje o propuesta de valor central para ese mercado específico (ej: 'Cuida tu piel con lo mejor de la naturaleza')

- status
  - tipo: VARCHAR(20)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 'ACTIVE', CHECK IN ('ACTIVE','PAUSED','CLOSED')
  - descripcion: estado operativo del sitio; permite abrir y cerrar tiendas por temporada o país con un solo clic

- launch_date
  - tipo: DATE
  - pk: no
  - descripcion: fecha de lanzamiento del sitio al público

- close_date
  - tipo: DATE
  - pk: no
  - descripcion: fecha de cierre del sitio (NULL si sigue activo)

- is_deleted
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 0
  - descripcion: borrado lógico del registro

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updated_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

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
  - descripcion: nombre(s) del cliente

- last_name
  - tipo: VARCHAR(80)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: apellido(s) del cliente

- email
  - tipo: VARCHAR(150)
  - pk: no
  - restriccion: NOT NULL, UNIQUE
  - descripcion: correo electrónico del cliente, usado como identificador único en la plataforma

- phone
  - tipo: VARCHAR(30)
  - pk: no
  - descripcion: teléfono de contacto del cliente, necesario para coordinación de entrega con el courier

- country_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, FK → Countries.country_id
  - descripcion: país de residencia del cliente

- delivery_address
  - tipo: TEXT
  - pk: no
  - descripcion: dirección completa de entrega principal del cliente

- city
  - tipo: VARCHAR(100)
  - pk: no
  - descripcion: ciudad de residencia del cliente

- is_active
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 1
  - descripcion: indica si el cliente está activo en la plataforma

- is_deleted
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 0
  - descripcion: borrado lógico del registro

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updated_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

---

## Product_catalog

- catalog_product_id
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único del producto en el catálogo de Dynamic Brands

- etheria_product_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL
  - descripcion: ID del producto base en Etheria Global (referencia de integración ETL a etheria_global.products.product_id)

- brand_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, FK → Brands.brand_id
  - descripcion: marca blanca bajo la cual se comercializa este producto

- branded_name
  - tipo: VARCHAR(150)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: nombre comercial del producto bajo la marca blanca (ej: 'Aceite de Argán AromaPura', 'Sérum Rejuvenecedor VerdeLux')

- branded_description
  - tipo: TEXT
  - pk: no
  - descripcion: descripción de marketing adaptada al enfoque y tono de la marca blanca

- marketing_claims
  - tipo: TEXT
  - pk: no
  - descripcion: beneficios y claims publicitarios del producto (ej: '100% orgánico', 'dermatológicamente probado', 'sin parabenos')

- is_active
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 1
  - descripcion: indica si el producto está disponible en el catálogo

- is_deleted
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 0
  - descripcion: borrado lógico del registro

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updated_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

> **Restricción única:** UNIQUE(etheria_product_id, brand_id) — un producto base solo puede tener una versión por marca

---

## Website_products

- website_product_id
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único del producto publicado en un sitio web específico

- website_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, FK → Websites.website_id
  - descripcion: sitio web donde se publica y vende el producto

- catalog_product_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, FK → Product_catalog.catalog_product_id
  - descripcion: producto del catálogo que se publica en el sitio

- sale_price_local
  - tipo: DECIMAL(14,2)
  - pk: no
  - restriccion: NOT NULL, CHECK > 0
  - descripcion: precio de venta al público en la moneda local del país del sitio

- stock_display
  - tipo: INT
  - pk: no
  - restriccion: DEFAULT 0, CHECK >= 0
  - descripcion: unidades de stock visible en el sitio web (puede diferir del inventario real en Etheria)

- is_featured
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 0
  - descripcion: indica si el producto está destacado en la página principal del sitio

- is_active
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 1
  - descripcion: indica si el producto está publicado y disponible para compra

- is_deleted
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 0
  - descripcion: borrado lógico del registro

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de publicación del producto en el sitio

- updated_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

> **Restricción única:** UNIQUE(website_id, catalog_product_id) — un producto no puede aparecer duplicado en el mismo sitio

---

## Orders

- order_id
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único de la orden de compra

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

- order_date
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora exacta en que se realizó la orden

- total_amount_local
  - tipo: DECIMAL(14,2)
  - pk: no
  - restriccion: NOT NULL, CHECK >= 0
  - descripcion: monto total de la venta en la moneda local del país del sitio

- currency_code
  - tipo: CHAR(3)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: código ISO 4217 de la moneda en que se realizó la venta (ej: COP, MXN, PEN)

- exchange_rate_to_usd
  - tipo: DECIMAL(18,6)
  - pk: no
  - restriccion: NOT NULL, CHECK > 0
  - descripcion: tasa de cambio vigente al momento de la venta (unidades de moneda local por 1 USD); se congela para preservar el valor histórico

- total_amount_usd
  - tipo: DECIMAL(14,4)
  - pk: no
  - restriccion: NOT NULL, CHECK >= 0
  - descripcion: monto total convertido a USD al momento de la venta (total_amount_local / exchange_rate_to_usd); base para análisis de rentabilidad

- etheria_dispatch_id
  - tipo: INT UNSIGNED
  - pk: no
  - descripcion: ID del despacho en Etheria Global (referencia de integración ETL a etheria_global.dispatch_orders.dispatch_order_id)

- status
  - tipo: VARCHAR(30)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 'PENDING', CHECK IN ('PENDING','CONFIRMED','PROCESSING','SHIPPED','DELIVERED','CANCELLED','REFUNDED')
  - descripcion: estado actual de la orden en su ciclo de vida

- notes
  - tipo: TEXT
  - pk: no
  - descripcion: observaciones o instrucciones especiales del cliente para la orden

- is_deleted
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 0
  - descripcion: borrado lógico del registro

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updated_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

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
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, CHECK > 0
  - descripcion: cantidad de unidades compradas de este producto

- unit_price_local
  - tipo: DECIMAL(14,2)
  - pk: no
  - restriccion: NOT NULL, CHECK > 0
  - descripcion: precio unitario en moneda local al momento de la compra (se congela para preservar el valor histórico)

- subtotal_local
  - tipo: DECIMAL(14,2)
  - pk: no
  - restriccion: NOT NULL, CHECK >= 0
  - descripcion: subtotal de la línea en moneda local (quantity × unit_price_local)

- is_deleted
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 0
  - descripcion: borrado lógico del registro

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
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

- courier_name
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: nombre del courier externo encargado del envío (ej: DHL, FedEx, Correos de Costa Rica)

- tracking_code
  - tipo: VARCHAR(100)
  - pk: no
  - descripcion: código de rastreo proporcionado por el courier para seguimiento del paquete

- shipping_cost_local
  - tipo: DECIMAL(12,2)
  - pk: no
  - restriccion: DEFAULT 0.00, CHECK >= 0
  - descripcion: costo del envío en la moneda local del país de destino

- shipping_cost_usd
  - tipo: DECIMAL(12,2)
  - pk: no
  - restriccion: DEFAULT 0.00, CHECK >= 0
  - descripcion: costo del envío convertido a USD; necesario para el cálculo de margen real por país

- estimated_delivery
  - tipo: DATE
  - pk: no
  - descripcion: fecha estimada de entrega al cliente final

- actual_delivery
  - tipo: DATE
  - pk: no
  - descripcion: fecha real en que el courier entregó el paquete al cliente

- status
  - tipo: VARCHAR(30)
  - pk: no
  - restriccion: DEFAULT 'PENDING', CHECK IN ('PENDING','IN_TRANSIT','CUSTOMS','DELIVERED','FAILED','RETURNED')
  - descripcion: estado actual del envío según el courier

- is_deleted
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 0
  - descripcion: borrado lógico del registro

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updated_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

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

- affected_id
  - tipo: INT UNSIGNED
  - pk: no
  - descripcion: ID del registro afectado por la operación

- status
  - tipo: VARCHAR(20)
  - pk: no
  - restriccion: NOT NULL, CHECK IN ('INFO','SUCCESS','WARNING','ERROR')
  - descripcion: resultado de la acción ejecutada; ERROR activa revisión manual del proceso

- error_message
  - tipo: TEXT
  - pk: no
  - descripcion: mensaje de error detallado capturado en el bloque DECLARE HANDLER; solo se llena cuando status = 'ERROR'

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora exacta en que se generó el registro de log


