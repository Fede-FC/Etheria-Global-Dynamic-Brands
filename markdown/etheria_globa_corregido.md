# 🟣 Etheria Global — Esquema de Base de Datos (PostgreSQL)

- Database engine: PostgreSQL 16
- Database name: etheria_global_db
- Context: Sistema de gestión de importaciones, inventario y despacho del HUB en Nicaragua. Normalización completa con catálogos independientes, moneda base configurable, inventario histórico por doble entrada, auditoría checksum y tabla ETL de rentabilidad para responder preguntas gerenciales.

---

## Currencies

- currency_id
  - tipo: SERIAL
  - pk: si
  - descripcion: identificador único de la moneda

- currency_code
  - tipo: CHAR(3)
  - pk: no
  - restriccion: NOT NULL, UNIQUE
  - descripcion: código ISO 4217 de la moneda (ej: USD, COP, NIO)

- currency_name
  - tipo: VARCHAR(80)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: nombre completo de la moneda (ej: US Dollar, Peso Colombiano)

- currency_symbol
  - tipo: VARCHAR(5)
  - pk: no
  - descripcion: símbolo de la moneda (ej: $, C$, S/)

- is_base
  - tipo: BOOLEAN
  - pk: no
  - restriccion: NOT NULL, DEFAULT FALSE
  - descripcion: indica si esta es la moneda base del sistema; solo una moneda puede tener este valor en TRUE

- enabled
  - tipo: BOOLEAN
  - pk: no
  - restriccion: NOT NULL, DEFAULT TRUE
  - descripcion: indica si la moneda está activa en el sistema

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updated_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

- updated_by
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_USER
  - descripcion: usuario de base de datos que realizó la última modificación

- checksum
  - tipo: VARCHAR(64)
  - pk: no
  - descripcion: hash de auditoría para verificar integridad del registro

---

## Countries

- country_id
  - tipo: SERIAL
  - pk: si
  - descripcion: identificador único del país

- country_name
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL, UNIQUE
  - descripcion: nombre del país (ej: Nicaragua, Colombia, México)

- iso_code
  - tipo: CHAR(3)
  - pk: no
  - restriccion: NOT NULL, UNIQUE
  - descripcion: código ISO 3166-1 alpha-3 del país (ej: NIC, COL, MEX)

- region
  - tipo: VARCHAR(100)
  - pk: no
  - descripcion: región geográfica del país (ej: Centroamérica, Sudamérica)

- currency_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Currencies.currency_id
  - descripcion: moneda oficial del país

- enabled
  - tipo: BOOLEAN
  - pk: no
  - restriccion: NOT NULL, DEFAULT TRUE
  - descripcion: indica si el país está activo en el sistema

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updated_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

- updated_by
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_USER
  - descripcion: usuario de base de datos que realizó la última modificación

- checksum
  - tipo: VARCHAR(64)
  - pk: no
  - descripcion: hash de auditoría para verificar integridad del registro

---

## States

- state_id
  - tipo: SERIAL
  - pk: si
  - descripcion: identificador único del estado o provincia

- country_id
  - tipo: INT
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
  - tipo: BOOLEAN
  - pk: no
  - restriccion: NOT NULL, DEFAULT TRUE
  - descripcion: indica si el estado está activo en el sistema

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

---

## Cities

- city_id
  - tipo: SERIAL
  - pk: si
  - descripcion: identificador único de la ciudad

- state_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → States.state_id
  - descripcion: estado o provincia al que pertenece la ciudad

- city_name
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: nombre de la ciudad

- enabled
  - tipo: BOOLEAN
  - pk: no
  - restriccion: NOT NULL, DEFAULT TRUE
  - descripcion: indica si la ciudad está activa en el sistema

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

---

## Addresses

- address_id
  - tipo: SERIAL
  - pk: si
  - descripcion: identificador único de la dirección; reutilizable por Suppliers, Warehouses y otras entidades

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
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Cities.city_id
  - descripcion: ciudad a la que pertenece esta dirección

- postal_code
  - tipo: VARCHAR(20)
  - pk: no
  - descripcion: código postal de la dirección

- enabled
  - tipo: BOOLEAN
  - pk: no
  - restriccion: NOT NULL, DEFAULT TRUE
  - descripcion: indica si la dirección está activa en el sistema

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updated_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

- updated_by
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_USER
  - descripcion: usuario de base de datos que realizó la última modificación

---

## Exchange_rates

- exchange_rate_id
  - tipo: SERIAL
  - pk: si
  - descripcion: identificador único del registro de tipo de cambio

- currency_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Currencies.currency_id
  - descripcion: moneda que se está convirtiendo

- base_currency_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Currencies.currency_id
  - descripcion: moneda base del sistema (la marcada con is_base = TRUE)

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
  - tipo: BOOLEAN
  - pk: no
  - restriccion: NOT NULL, DEFAULT TRUE
  - descripcion: indica si el registro está activo

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updated_by
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_USER
  - descripcion: usuario de base de datos que creó el registro

- checksum
  - tipo: VARCHAR(64)
  - pk: no
  - descripcion: hash de auditoría para verificar integridad del registro

> **Restricción única:** UNIQUE(currency_id, base_currency_id, rate_date)

---

## Categories

- category_id
  - tipo: SERIAL
  - pk: si
  - descripcion: identificador único de la categoría de producto

- category_name
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL, UNIQUE
  - descripcion: nombre de la categoría (ej: Cosméticos, Suplementos, Cuidado Personal)

- description
  - tipo: VARCHAR(300)
  - pk: no
  - descripcion: descripción general de la categoría

- enabled
  - tipo: BOOLEAN
  - pk: no
  - restriccion: NOT NULL, DEFAULT TRUE
  - descripcion: indica si la categoría está activa en el sistema

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updated_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

- updated_by
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_USER
  - descripcion: usuario de base de datos que realizó la última modificación

---

## Measurement_units

- unit_id
  - tipo: SERIAL
  - pk: si
  - descripcion: identificador único de la unidad de medida

- unit_code
  - tipo: VARCHAR(10)
  - pk: no
  - restriccion: NOT NULL, UNIQUE
  - descripcion: código abreviado de la unidad (ej: kg, ml, UN)

- unit_name
  - tipo: VARCHAR(40)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: nombre completo de la unidad de medida (ej: Kilogramo, Mililitro, Unidad)

- unit_type
  - tipo: VARCHAR(20)
  - pk: no
  - restriccion: NOT NULL, CHECK IN ('WEIGHT', 'VOLUME', 'UNIT')
  - descripcion: tipo de magnitud que representa la unidad

- enabled
  - tipo: BOOLEAN
  - pk: no
  - restriccion: NOT NULL, DEFAULT TRUE
  - descripcion: indica si la unidad está activa en el sistema

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

---

## Cost_types

- cost_type_id
  - tipo: SERIAL
  - pk: si
  - descripcion: identificador único del tipo de costo

- cost_type_code
  - tipo: VARCHAR(30)
  - pk: no
  - restriccion: NOT NULL, UNIQUE
  - descripcion: código abreviado del tipo de costo (ej: FLETE_MARITIMO, ARANCEL_IMPORT)

- cost_type_name
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: nombre descriptivo del tipo de costo

- description
  - tipo: VARCHAR(300)
  - pk: no
  - descripcion: descripción detallada de qué incluye este tipo de costo

- applies_to
  - tipo: VARCHAR(30)
  - pk: no
  - restriccion: NOT NULL, CHECK IN ('IMPORT', 'LOGISTIC', 'TARIFF', 'PERMIT', 'SHIPPING', 'OTHER')
  - descripcion: proceso al que aplica este tipo de costo

- enabled
  - tipo: BOOLEAN
  - pk: no
  - restriccion: NOT NULL, DEFAULT TRUE
  - descripcion: indica si el tipo de costo está activo

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

---

## Permit_types

- permit_type_id
  - tipo: SERIAL
  - pk: si
  - descripcion: identificador único del tipo de permiso sanitario

- permit_type_code
  - tipo: VARCHAR(30)
  - pk: no
  - restriccion: NOT NULL, UNIQUE
  - descripcion: código del tipo de permiso (ej: INVIMA_COL, COFEPRIS_MEX)

- permit_type_name
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: nombre descriptivo del tipo de permiso sanitario

- issuing_authority
  - tipo: VARCHAR(150)
  - pk: no
  - descripcion: nombre de la autoridad regulatoria que emite el permiso

- enabled
  - tipo: BOOLEAN
  - pk: no
  - restriccion: NOT NULL, DEFAULT TRUE
  - descripcion: indica si el tipo de permiso está activo

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

---

## Import_statuses

- status_id
  - tipo: SERIAL
  - pk: si
  - descripcion: identificador único del estado

- status_code
  - tipo: VARCHAR(30)
  - pk: no
  - restriccion: NOT NULL, UNIQUE
  - descripcion: código del estado (ej: PENDIENTE, EN_TRANSITO, RECIBIDO, CANCELADO)

- description
  - tipo: VARCHAR(150)
  - pk: no
  - descripcion: descripción del estado y su significado en el proceso

- enabled
  - tipo: BOOLEAN
  - pk: no
  - restriccion: NOT NULL, DEFAULT TRUE
  - descripcion: indica si el estado está activo en el sistema

---

## Suppliers

- supplier_id
  - tipo: SERIAL
  - pk: si
  - descripcion: identificador único del proveedor

- supplier_name
  - tipo: VARCHAR(150)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: nombre o razón social del proveedor

- country_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Countries.country_id
  - descripcion: país de origen del proveedor

- address_id
  - tipo: INT
  - pk: no
  - restriccion: FK → Addresses.address_id
  - descripcion: dirección física del proveedor

- contact_email
  - tipo: VARCHAR(150)
  - pk: no
  - restriccion: UNIQUE
  - descripcion: correo electrónico de contacto del proveedor

- contact_phone
  - tipo: VARCHAR(30)
  - pk: no
  - descripcion: teléfono de contacto del proveedor

- tax_id
  - tipo: VARCHAR(50)
  - pk: no
  - descripcion: número de identificación fiscal del proveedor en su país de origen

- enabled
  - tipo: BOOLEAN
  - pk: no
  - restriccion: NOT NULL, DEFAULT TRUE
  - descripcion: indica si el proveedor está activo para realizar compras

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updated_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

- updated_by
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_USER
  - descripcion: usuario de base de datos que realizó la última modificación

- checksum
  - tipo: VARCHAR(64)
  - pk: no
  - descripcion: hash de auditoría para verificar integridad del registro

---

## Products

- product_id
  - tipo: SERIAL
  - pk: si
  - descripcion: identificador único del producto base (sin marca, a granel)

- product_name
  - tipo: VARCHAR(150)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: nombre genérico del producto tal como se importa al HUB

- category_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Categories.category_id
  - descripcion: categoría a la que pertenece el producto

- unit_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Measurement_units.unit_id
  - descripcion: unidad de medida en que se gestiona el inventario de este producto

- unit_volume_m3
  - tipo: DECIMAL(10,6)
  - pk: no
  - descripcion: volumen unitario del producto en metros cúbicos; usado para cálculos logísticos

- unit_weight_kg
  - tipo: DECIMAL(10,4)
  - pk: no
  - descripcion: peso unitario del producto en kilogramos; usado para costos de flete

- origin_country_id
  - tipo: INT
  - pk: no
  - restriccion: FK → Countries.country_id
  - descripcion: país de fabricación u origen del producto

- enabled
  - tipo: BOOLEAN
  - pk: no
  - restriccion: NOT NULL, DEFAULT TRUE
  - descripcion: indica si el producto está activo en el catálogo

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updated_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

- updated_by
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_USER
  - descripcion: usuario de base de datos que realizó la última modificación

- checksum
  - tipo: VARCHAR(64)
  - pk: no
  - descripcion: hash de auditoría para verificar integridad del registro

---

## Warehouse_types

- warehouse_type_id
  - tipo: SERIAL
  - pk: si
  - descripcion: identificador único del tipo de bodega

- type_code
  - tipo: VARCHAR(20)
  - pk: no
  - restriccion: NOT NULL, UNIQUE, CHECK IN ('RECEIVING', 'LABELING', 'DISPATCH', 'MIXED')
  - descripcion: código del tipo de bodega según su función en el HUB

- type_name
  - tipo: VARCHAR(60)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: nombre descriptivo del tipo de bodega

- enabled
  - tipo: BOOLEAN
  - pk: no
  - restriccion: NOT NULL, DEFAULT TRUE
  - descripcion: indica si el tipo de bodega está activo

---

## Warehouses

- warehouse_id
  - tipo: SERIAL
  - pk: si
  - descripcion: identificador único de la bodega del HUB en Nicaragua

- warehouse_name
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: nombre de la bodega (ej: Bodega Recepción Norte, Bodega Despacho Sur)

- address_id
  - tipo: INT
  - pk: no
  - restriccion: FK → Addresses.address_id
  - descripcion: dirección física de la bodega

- warehouse_type_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Warehouse_types.warehouse_type_id
  - descripcion: tipo de bodega según su función en el flujo del HUB

- capacity_units
  - tipo: INT
  - pk: no
  - restriccion: CHECK > 0
  - descripcion: capacidad máxima de almacenamiento de la bodega expresada en unidades

- enabled
  - tipo: BOOLEAN
  - pk: no
  - restriccion: NOT NULL, DEFAULT TRUE
  - descripcion: indica si la bodega está operativa

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updated_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

- updated_by
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_USER
  - descripcion: usuario de base de datos que realizó la última modificación

---

## Imports

- import_id
  - tipo: SERIAL
  - pk: si
  - descripcion: identificador único de la orden de compra al proveedor

- supplier_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Suppliers.supplier_id
  - descripcion: proveedor al que se realizó la orden de importación

- status_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Import_statuses.status_id
  - descripcion: estado actual de la importación en su ciclo de vida

- import_date
  - tipo: DATE
  - pk: no
  - restriccion: NOT NULL
  - descripcion: fecha en que se realizó la orden de compra al proveedor

- expected_arrival
  - tipo: DATE
  - pk: no
  - descripcion: fecha estimada de llegada de la importación al HUB

- actual_arrival
  - tipo: DATE
  - pk: no
  - descripcion: fecha real en que la importación llegó al HUB

- notes
  - tipo: TEXT
  - pk: no
  - descripcion: observaciones o instrucciones especiales para esta importación

- enabled
  - tipo: BOOLEAN
  - pk: no
  - restriccion: NOT NULL, DEFAULT TRUE
  - descripcion: indica si el registro está activo

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updated_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

- updated_by
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_USER
  - descripcion: usuario de base de datos que realizó la última modificación

- checksum
  - tipo: VARCHAR(64)
  - pk: no
  - descripcion: hash de auditoría para verificar integridad del registro

---

## Import_details

- import_detail_id
  - tipo: SERIAL
  - pk: si
  - descripcion: identificador único de la línea de detalle de la importación

- import_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Imports.import_id
  - descripcion: importación a la que pertenece esta línea de detalle

- product_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Products.product_id
  - descripcion: producto comprado en esta línea

- quantity
  - tipo: DECIMAL(12,3)
  - pk: no
  - restriccion: NOT NULL, CHECK > 0
  - descripcion: cantidad de unidades del producto comprado

- unit_cost
  - tipo: DECIMAL(14,4)
  - pk: no
  - restriccion: NOT NULL, CHECK > 0
  - descripcion: costo unitario del producto en la moneda pactada con el proveedor

- currency_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Currencies.currency_id
  - descripcion: moneda en que se pactó el precio con el proveedor

- exchange_rate_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Exchange_rates.exchange_rate_id
  - descripcion: tipo de cambio aplicado al momento de registrar la línea

- subtotal
  - tipo: DECIMAL(16,4)
  - pk: no
  - restriccion: NOT NULL, CHECK >= 0
  - descripcion: subtotal de la línea (quantity × unit_cost en la moneda pactada)

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updated_by
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_USER
  - descripcion: usuario de base de datos que creó el registro

- checksum
  - tipo: VARCHAR(64)
  - pk: no
  - descripcion: hash de auditoría para verificar integridad del registro

---

## Import_costs

- import_cost_id
  - tipo: SERIAL
  - pk: si
  - descripcion: identificador único del registro de costo logístico

- import_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Imports.import_id
  - descripcion: importación a la que se asocia este costo

- cost_type_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Cost_types.cost_type_id
  - descripcion: tipo de costo según el catálogo normalizado

- amount
  - tipo: DECIMAL(14,4)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 0, CHECK >= 0
  - descripcion: monto del costo en la moneda indicada

- currency_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Currencies.currency_id
  - descripcion: moneda en que se registra el costo

- exchange_rate_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Exchange_rates.exchange_rate_id
  - descripcion: tipo de cambio aplicado al momento de registrar el costo

- notes
  - tipo: TEXT
  - pk: no
  - descripcion: observaciones adicionales sobre el costo registrado

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updated_by
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_USER
  - descripcion: usuario de base de datos que creó el registro

---

## Import_tariffs

- tariff_id
  - tipo: SERIAL
  - pk: si
  - descripcion: identificador único del registro de arancel por línea de detalle y país destino

- import_detail_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Import_details.import_detail_id
  - descripcion: línea de detalle de importación a la que aplica el arancel

- destination_country_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Countries.country_id
  - descripcion: país de destino al que aplica este arancel

- cost_type_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Cost_types.cost_type_id
  - descripcion: tipo de costo arancelario según el catálogo

- tariff_rate_percent
  - tipo: DECIMAL(5,2)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 0, CHECK >= 0
  - descripcion: porcentaje del arancel aplicado sobre el valor de la línea

- amount
  - tipo: DECIMAL(14,4)
  - pk: no
  - restriccion: NOT NULL, CHECK >= 0
  - descripcion: monto total del arancel en la moneda indicada

- currency_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Currencies.currency_id
  - descripcion: moneda en que se registra el arancel

- exchange_rate_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Exchange_rates.exchange_rate_id
  - descripcion: tipo de cambio aplicado al momento de registrar el arancel

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updated_by
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_USER
  - descripcion: usuario de base de datos que creó el registro

---

## Product_permits

- permit_id
  - tipo: SERIAL
  - pk: si
  - descripcion: identificador único del permiso sanitario de un producto para un país destino

- product_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Products.product_id
  - descripcion: producto al que aplica el permiso sanitario

- destination_country_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Countries.country_id
  - descripcion: país destino para el que se obtuvo el permiso

- permit_type_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Permit_types.permit_type_id
  - descripcion: tipo de permiso sanitario según el catálogo

- permit_number
  - tipo: VARCHAR(100)
  - pk: no
  - descripcion: número oficial del permiso emitido por la autoridad regulatoria

- valid_from
  - tipo: DATE
  - pk: no
  - restriccion: NOT NULL
  - descripcion: fecha de inicio de vigencia del permiso

- valid_until
  - tipo: DATE
  - pk: no
  - descripcion: fecha de vencimiento del permiso (NULL si no tiene fecha de expiración)

- cost_amount
  - tipo: DECIMAL(12,4)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 0
  - descripcion: costo incurrido para obtener el permiso sanitario

- currency_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Currencies.currency_id
  - descripcion: moneda en que se registra el costo del permiso

- exchange_rate_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Exchange_rates.exchange_rate_id
  - descripcion: tipo de cambio aplicado al momento de registrar el costo

- status_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Import_statuses.status_id
  - descripcion: estado actual del permiso (ej: VIGENTE, VENCIDO, EN_TRAMITE)

- enabled
  - tipo: BOOLEAN
  - pk: no
  - restriccion: NOT NULL, DEFAULT TRUE
  - descripcion: indica si el permiso está activo en el sistema

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updated_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

- updated_by
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_USER
  - descripcion: usuario de base de datos que realizó la última modificación

> **Restricción única:** UNIQUE(product_id, destination_country_id, permit_type_id)

---

## Movement_types

- movement_type_id
  - tipo: SERIAL
  - pk: si
  - descripcion: identificador único del tipo de movimiento de inventario

- type_code
  - tipo: VARCHAR(20)
  - pk: no
  - restriccion: NOT NULL, UNIQUE
  - descripcion: código del tipo de movimiento (ej: RECEPCION, DESPACHO, AJUSTE, DEVOLUCION)

- type_name
  - tipo: VARCHAR(60)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: nombre descriptivo del tipo de movimiento

- direction
  - tipo: SMALLINT
  - pk: no
  - restriccion: NOT NULL, CHECK IN (1, -1)
  - descripcion: dirección del movimiento: +1 para entradas al inventario, -1 para salidas

- enabled
  - tipo: BOOLEAN
  - pk: no
  - restriccion: NOT NULL, DEFAULT TRUE
  - descripcion: indica si el tipo de movimiento está activo

---

## Inventory_movements

- movement_id
  - tipo: BIGSERIAL
  - pk: si
  - descripcion: identificador único del movimiento de inventario; el stock actual se obtiene con SUM(quantity) por producto y bodega

- warehouse_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Warehouses.warehouse_id
  - descripcion: bodega donde se registra el movimiento

- product_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Products.product_id
  - descripcion: producto afectado por el movimiento

- movement_type_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Movement_types.movement_type_id
  - descripcion: tipo de movimiento según el catálogo normalizado

- quantity
  - tipo: DECIMAL(12,3)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: cantidad afectada; positiva para entradas, negativa para salidas

- unit_cost
  - tipo: DECIMAL(14,4)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: costo unitario del producto en la moneda indicada al momento del movimiento

- currency_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Currencies.currency_id
  - descripcion: moneda en que se registra el costo unitario

- exchange_rate_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Exchange_rates.exchange_rate_id
  - descripcion: tipo de cambio aplicado al momento del movimiento

- reference_type
  - tipo: VARCHAR(30)
  - pk: no
  - descripcion: tipo de documento que originó el movimiento (IMPORT, DISPATCH, ADJUSTMENT, RETURN)

- reference_id
  - tipo: INT
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
  - restriccion: NOT NULL, DEFAULT CURRENT_USER
  - descripcion: usuario de base de datos que registró el movimiento

- checksum
  - tipo: VARCHAR(64)
  - pk: no
  - descripcion: hash de auditoría para verificar integridad del registro

---

## Dispatch_orders

- dispatch_order_id
  - tipo: BIGSERIAL
  - pk: si
  - descripcion: identificador único de la orden de despacho desde el HUB hacia el país destino; tabla de integración ETL con Dynamic Brands

- reference_order_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL
  - descripcion: referencia lógica al Orders.order_id de la base MySQL de Dynamic Brands

- product_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Products.product_id
  - descripcion: producto despachado desde el HUB

- quantity
  - tipo: DECIMAL(12,3)
  - pk: no
  - restriccion: NOT NULL, CHECK > 0
  - descripcion: cantidad de unidades del producto a despachar

- warehouse_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Warehouses.warehouse_id
  - descripcion: bodega del HUB desde la que se despacha el producto

- destination_country_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Countries.country_id
  - descripcion: país de destino al que se envía el despacho

- brand_label
  - tipo: VARCHAR(150)
  - pk: no
  - descripcion: nombre de la marca blanca con que se etiqueta el producto para este despacho

- packaging_permit_ok
  - tipo: BOOLEAN
  - pk: no
  - restriccion: NOT NULL, DEFAULT FALSE
  - descripcion: indica si se verificó que el empaque cumple los requisitos del permiso sanitario del país destino

- unit_cost
  - tipo: DECIMAL(14,4)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: costo unitario del producto al momento del despacho en la moneda indicada

- currency_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Currencies.currency_id
  - descripcion: moneda en que se registra el costo unitario del despacho

- exchange_rate_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Exchange_rates.exchange_rate_id
  - descripcion: tipo de cambio aplicado al momento del despacho

- dispatch_date
  - tipo: TIMESTAMP
  - pk: no
  - descripcion: fecha y hora en que se procesó el despacho desde el HUB

- courier_handoff_date
  - tipo: TIMESTAMP
  - pk: no
  - descripcion: fecha y hora en que el courier retiró el paquete del HUB

- status_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Import_statuses.status_id
  - descripcion: estado actual del despacho en su ciclo de vida

- enabled
  - tipo: BOOLEAN
  - pk: no
  - restriccion: NOT NULL, DEFAULT TRUE
  - descripcion: indica si el registro de despacho está activo

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updated_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

- updated_by
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_USER
  - descripcion: usuario de base de datos que realizó la última modificación

- checksum
  - tipo: VARCHAR(64)
  - pk: no
  - descripcion: hash de auditoría para verificar integridad del registro

---

## Process_log

- log_id
  - tipo: BIGSERIAL
  - pk: si
  - descripcion: identificador único del registro de log

- sp_name
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: nombre del Stored Procedure o proceso que generó este registro de log

- action_description
  - tipo: TEXT
  - pk: no
  - restriccion: NOT NULL
  - descripcion: descripción detallada del paso o acción ejecutada

- affected_table
  - tipo: VARCHAR(100)
  - pk: no
  - descripcion: nombre de la tabla sobre la que se realizó la operación

- affected_record_id
  - tipo: BIGINT
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
  - descripcion: detalle técnico del error capturado; solo se llena cuando status = 'ERROR'

- executed_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora exacta en que se generó el registro de log

- executed_by
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_USER
  - descripcion: usuario de base de datos que ejecutó el proceso

---

## Etl_profitability_summary

- summary_id
  - tipo: BIGSERIAL
  - pk: si
  - descripcion: identificador único del resumen ETL de rentabilidad

- category_name
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: nombre de la categoría de producto analizada (dimensión de análisis)

- brand_name
  - tipo: VARCHAR(150)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: nombre de la marca blanca analizada (dimensión de análisis)

- site_url
  - tipo: VARCHAR(500)
  - pk: no
  - descripcion: URL del sitio e-commerce de Dynamic Brands analizado

- sale_country
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: país donde se realizaron las ventas analizadas

- sale_currency_code
  - tipo: CHAR(3)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: código de la moneda local del país de venta

- base_currency_code
  - tipo: CHAR(3)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: código de la moneda base del sistema usada para la conversión

- total_orders
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, DEFAULT 0
  - descripcion: total de órdenes incluidas en el resumen

- total_units_sold
  - tipo: DECIMAL(14,3)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 0
  - descripcion: total de unidades vendidas en el período analizado

- revenue_local
  - tipo: DECIMAL(18,4)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 0
  - descripcion: ingresos totales expresados en moneda local del país de venta

- revenue_base
  - tipo: DECIMAL(18,4)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 0
  - descripcion: ingresos totales convertidos a moneda base para comparación entre países

- cost_product
  - tipo: DECIMAL(18,4)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 0
  - descripcion: costo total del producto en moneda base

- cost_logistics
  - tipo: DECIMAL(18,4)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 0
  - descripcion: costos logísticos totales en moneda base (flete, manejo, almacenaje)

- cost_tariffs
  - tipo: DECIMAL(18,4)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 0
  - descripcion: costos arancelarios totales en moneda base

- cost_permits
  - tipo: DECIMAL(18,4)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 0
  - descripcion: costos de permisos sanitarios en moneda base

- cost_shipping
  - tipo: DECIMAL(18,4)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 0
  - descripcion: costos de envío al cliente final en moneda base

- cost_total
  - tipo: DECIMAL(18,4)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 0
  - descripcion: suma de todos los costos en moneda base

- gross_margin
  - tipo: DECIMAL(18,4)
  - pk: no
  - restriccion: NOT NULL, DEFAULT 0
  - descripcion: margen bruto en moneda base (revenue_base − cost_total)

- gross_margin_pct
  - tipo: DECIMAL(8,4)
  - pk: no
  - descripcion: porcentaje de margen bruto sobre los ingresos totales

- roi_pct
  - tipo: DECIMAL(8,4)
  - pk: no
  - descripcion: retorno sobre la inversión expresado como porcentaje (gross_margin / cost_total × 100)

- etl_run_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: NOT NULL, DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora en que se ejecutó el proceso ETL que generó este resumen

- etl_period_from
  - tipo: DATE
  - pk: no
  - descripcion: fecha de inicio del período analizado en este resumen

- etl_period_to
  - tipo: DATE
  - pk: no
  - descripcion: fecha de fin del período analizado en este resumen
