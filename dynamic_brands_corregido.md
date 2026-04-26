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
  - descripcion: nombre del país donde opera o puede operar una tienda (ej: Colombia, Perú, México)

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

## Country_taxes

- tax_id
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único del registro de impuesto por país

- country_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, FK → Countries.country_id
  - descripcion: país al que aplica este registro de impuesto

- tax_rate_percent
  - tipo: DECIMAL(5,2)
  - pk: no
  - restriccion: DEFAULT 0.00, CHECK >= 0
  - descripcion: porcentaje de impuesto al consumidor final aplicable en el país (IVA, IGV, etc.)

- regulatory_notes
  - tipo: TEXT
  - pk: no
  - descripcion: notas sobre requisitos legales o sanitarios para la venta de productos de salud y belleza en el país

- valid_from
  - tipo: DATE
  - pk: no
  - restriccion: NOT NULL
  - descripcion: fecha de inicio de vigencia de este registro de impuesto

- valid_until
  - tipo: DATE
  - pk: no
  - descripcion: fecha de fin de vigencia (NULL si está vigente)

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

---

## Exchange_rates

- exchange_rate_id
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador del registro de tipo de cambio

- country_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, FK → Countries.country_id
  - descripcion: país cuya moneda local se está registrando

- currency_code
  - tipo: CHAR(3)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: código ISO 4217 de la moneda (ej: COP, MXN, PEN)

- rate_to_usd
  - tipo: DECIMAL(18,6)
  - pk: no
  - restriccion: NOT NULL, CHECK > 0
  - descripcion: cantidad de unidades de moneda local equivalentes a 1 USD

- rate_date
  - tipo: DATE
  - pk: no
  - restriccion: NOT NULL
  - descripcion: fecha a la que corresponde la tasa de cambio registrada

- source
  - tipo: VARCHAR(100)
  - pk: no
  - descripcion: fuente de la tasa de cambio (ej: 'Banco Central', 'Open Exchange Rates API')

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

> **Restricción única:** UNIQUE(country_id, rate_date)

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
  - descripcion: versión del modelo de IA que generó la marca (ej: 'v2.3-latam')

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
  - descripcion: configuración visual del sitio generada por la IA (estilos, colores, fuentes, punteros a imágenes, componentes activos)

- status
  - tipo: VARCHAR(20)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 'ACTIVE', CHECK IN ('ACTIVE','PAUSED','CLOSED')
  - descripcion: estado operativo del sitio

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
  - restriccion: NOT NULL
  - descripcion: teléfono de contacto del cliente

- country_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, FK → Countries.country_id
  - descripcion: país de residencia del cliente

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

## Customer_addresses

- address_id
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único de la dirección de envío del cliente

- customer_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, FK → Customers.customer_id
  - descripcion: cliente al que pertenece esta dirección

- address_line
  - tipo: VARCHAR(300)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: dirección completa de entrega

- city
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: ciudad de entrega

- country_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, FK → Countries.country_id
  - descripcion: país de la dirección de entrega

- is_default
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 0
  - descripcion: indica si es la dirección de envío principal del cliente

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

## Product_catalog

- catalog_product_id
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único del producto en el catálogo de Dynamic Brands

- etheria_product_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL
  - descripcion: ID del producto individual en Etheria Global (referencia de integración ETL)

- brand_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, FK → Brands.brand_id
  - descripcion: marca blanca bajo la cual se comercializa este producto

- branded_name
  - tipo: VARCHAR(150)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: nombre comercial del producto bajo la marca blanca (ej: 'Aceite de Argán AromaPura')

- branded_description
  - tipo: TEXT
  - pk: no
  - descripcion: descripción de marketing adaptada al enfoque y tono de la marca blanca

- branded_image_url
  - tipo: VARCHAR(500)
  - pk: no
  - descripcion: URL de la imagen del producto con el etiquetado de la marca blanca

- health_claims
  - tipo: TEXT
  - pk: no
  - descripcion: beneficios y claims publicitarios del producto adaptados por país y marca (ej: '100% orgánico', 'sin parabenos')

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

- is_featured
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 0
  - descripcion: indica si el producto está destacado en la página principal del sitio

- stock_display
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: DEFAULT 0
  - descripcion: unidades de stock visible en el sitio web (depende del inventario real en Etheria)

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

## Website_product_prices

- price_id
  - tipo: INT UNSIGNED AUTO_INCREMENT
  - pk: si
  - descripcion: identificador único del registro de precio

- website_product_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, FK → Website_products.website_product_id
  - descripcion: producto del sitio al que aplica este precio

- sale_price_local
  - tipo: DECIMAL(14,2)
  - pk: no
  - restriccion: NOT NULL, CHECK > 0
  - descripcion: precio de venta al público en la moneda local del país del sitio

- valid_from
  - tipo: DATE
  - pk: no
  - restriccion: NOT NULL
  - descripcion: fecha de inicio de vigencia de este precio

- valid_until
  - tipo: DATE
  - pk: no
  - descripcion: fecha de fin de vigencia (NULL si es el precio actual)

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

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

- address_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, FK → Customer_addresses.address_id
  - descripcion: dirección de entrega seleccionada para esta orden

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

- exchange_rate_id
  - tipo: INT UNSIGNED
  - pk: no
  - restriccion: NOT NULL, FK → Exchange_rates.exchange_rate_id
  - descripcion: tasa de cambio vigente al momento de la venta; se congela para preservar el valor histórico

- exchange_rate_snapshot
  - tipo: DECIMAL(18,6)
  - pk: no
  - restriccion: NOT NULL, CHECK > 0
  - descripcion: valor de la tasa de cambio al momento exacto de la venta (snapshot para trazabilidad histórica)

- total_amount_usd
  - tipo: DECIMAL(14,4)
  - pk: no
  - restriccion: NOT NULL, CHECK >= 0
  - descripcion: monto total convertido a USD al momento de la venta; base para análisis de rentabilidad

- etheria_dispatch_id
  - tipo: INT UNSIGNED
  - pk: no
  - descripcion: ID del despacho en Etheria Global (referencia de integración ETL)

- status
  - tipo: VARCHAR(30)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 'PENDIENTE', CHECK IN ('PENDIENTE','CONFIRMADA','EN_PREPARACION','ENVIADA','ENTREGADA','CANCELADA','REEMBOLSADA')
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
  - tipo: INT UNSIGNED
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

- is_active
  - tipo: TINYINT(1)
  - pk: no
  - restriccion: DEFAULT 1
  - descripcion: indica si el courier está activo y disponible para asignar envíos

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

- estimated_delivery_date
  - tipo: DATE
  - pk: no
  - descripcion: fecha estimada de entrega al cliente final

- actual_delivery_date
  - tipo: DATE
  - pk: no
  - descripcion: fecha real en que el courier entregó el paquete al cliente

- status
  - tipo: VARCHAR(30)
  - pk: no
  - restriccion: DEFAULT 'PENDIENTE', CHECK IN ('PENDIENTE','RETIRADO_HUB','EN_TRANSITO','EN_ADUANA','ENTREGADO','FALLIDO','RETORNADO')
  - descripcion: estado actual del envío según el courier

- health_permit_number
  - tipo: VARCHAR(100)
  - pk: no
  - descripcion: número del permiso sanitario requerido para la importación en el país destino

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

- affected_record_id
  - tipo: INT UNSIGNED
  - pk: no
  - descripcion: ID del registro afectado por la operación

- status
  - tipo: VARCHAR(20)
  - pk: no
  - restriccion: NOT NULL, CHECK IN ('INFO','SUCCESS','WARNING','ERROR')
  - descripcion: resultado de la acción ejecutada; ERROR activa revisión manual del proceso

- error_detail
  - tipo: TEXT
  - pk: no
  - descripcion: detalle técnico del error capturado en el bloque DECLARE HANDLER; solo se llena cuando status = 'ERROR'

- executed_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora exacta en que se generó el registro de log

- db_user
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: DEFAULT (CURRENT_USER())
  - descripcion: usuario de base de datos que ejecutó el SP
EOF
