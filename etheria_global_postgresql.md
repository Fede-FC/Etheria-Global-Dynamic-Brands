# 🟣 Etheria Global — Esquema de Base de Datos (PostgreSQL)

- Database engine: PostgreSQL 16
- Database name: etheria_global_db
- Context: Sistema de gestión de cadena de suministro e importaciones. Maneja proveedores internacionales, importaciones en bulk, inventario en el HUB logístico de la costa Caribe de Nicaragua, permisos sanitarios por país y despachos hacia Dynamic Brands para su etiquetado con marca blanca y entrega al cliente final.

---

## Countries

- country_id
  - tipo: SERIAL
  - pk: si
  - descripcion: identificador único del país de origen de proveedores o destino de exportación

- country_name
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL, UNIQUE
  - descripcion: nombre completo del país (ej: India, Marruecos, Brasil)

- iso_code
  - tipo: CHAR(3)
  - pk: no
  - restriccion: NOT NULL, UNIQUE
  - descripcion: código ISO 3166-1 alpha-3 del país (ej: IND, MAR, BRA)

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updated_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

---

## Categories

- category_id
  - tipo: SERIAL
  - pk: si
  - descripcion: identificador único de la categoría de producto

- name
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL, UNIQUE
  - descripcion: nombre de la categoría de producto (ej: Aceites Esenciales, Cosmética Capilar, Bebidas Funcionales, Aromaterapia, Jabones)

- description
  - tipo: TEXT
  - pk: no
  - descripcion: descripción general de los tipos de productos que agrupa esta categoría

- is_active
  - tipo: BOOLEAN
  - pk: no
  - restriccion: DEFAULT TRUE
  - descripcion: indica si la categoría está activa para la importación de nuevos productos

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

---

## Suppliers

- supplier_id
  - tipo: SERIAL
  - pk: si
  - descripcion: identificador único del proveedor internacional

- supplier_name
  - tipo: VARCHAR(150)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: nombre legal o comercial del proveedor

- country_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Countries.country_id
  - descripcion: país de origen del proveedor; desde donde exporta los productos a Nicaragua

- contact_email
  - tipo: VARCHAR(150)
  - pk: no
  - descripcion: correo electrónico del contacto comercial del proveedor

- contact_phone
  - tipo: VARCHAR(30)
  - pk: no
  - descripcion: teléfono del contacto comercial del proveedor

- is_active
  - tipo: BOOLEAN
  - pk: no
  - restriccion: DEFAULT TRUE
  - descripcion: indica si el proveedor está activo y disponible para nuevas órdenes de importación

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updated_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

---

## Products

- product_id
  - tipo: SERIAL
  - pk: si
  - descripcion: identificador único del producto base importado en bulk

- product_name
  - tipo: VARCHAR(150)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: nombre genérico del producto sin marca (ej: 'Aceite de Argán', 'Agua de Rosas', 'Jabón de Azufre')

- category_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Categories.category_id
  - descripcion: categoría a la que pertenece el producto

- base_description
  - tipo: TEXT
  - pk: no
  - descripcion: descripción técnica base del producto (ingredientes, propiedades, composición); independiente de cualquier marca

- unit_measure
  - tipo: VARCHAR(50)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: unidad de medida del producto (ej: ml, g, litro, unidad, kg)

- base_cost_usd
  - tipo: DECIMAL(12,2)
  - pk: no
  - restriccion: NOT NULL, CHECK > 0
  - descripcion: costo base referencial del producto en USD; sirve como punto de partida para calcular el costo real de importación

- origin_country_id
  - tipo: INT
  - pk: no
  - restriccion: FK → Countries.country_id
  - descripcion: país de origen típico del producto; puede diferir del proveedor en casos de reexportación

- is_active
  - tipo: BOOLEAN
  - pk: no
  - restriccion: DEFAULT TRUE
  - descripcion: indica si el producto está disponible para ser importado y despachado

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

- updated_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última modificación

---

## Warehouses

- warehouse_id
  - tipo: SERIAL
  - pk: si
  - descripcion: identificador único del almacén logístico

- name
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: nombre del almacén (ej: 'HUB Principal Caribe', 'Área de Etiquetado')

- location
  - tipo: VARCHAR(150)
  - pk: no
  - restriccion: DEFAULT 'Nicaragua - Costa Caribe'
  - descripcion: ubicación geográfica del almacén; el HUB principal está en la costa Caribe de Nicaragua

- warehouse_type
  - tipo: VARCHAR(30)
  - pk: no
  - restriccion: CHECK IN ('RECEIVING','LABELING','DISPATCH','MIXED')
  - descripcion: tipo funcional del almacén; RECEIVING recibe el bulk importado, LABELING aplica marca blanca, DISPATCH prepara los paquetes para el courier

- capacity_units
  - tipo: INT
  - pk: no
  - restriccion: CHECK > 0
  - descripcion: capacidad máxima del almacén expresada en unidades de producto

- is_active
  - tipo: BOOLEAN
  - pk: no
  - restriccion: DEFAULT TRUE
  - descripcion: indica si el almacén está operativo

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

---

## Imports

- import_id
  - tipo: SERIAL
  - pk: si
  - descripcion: identificador único de la orden de importación

- supplier_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Suppliers.supplier_id
  - descripcion: proveedor al que se le realizó la orden de importación

- import_date
  - tipo: DATE
  - pk: no
  - restriccion: NOT NULL
  - descripcion: fecha en que se emitió la orden de importación al proveedor

- expected_arrival
  - tipo: DATE
  - pk: no
  - descripcion: fecha estimada de llegada del bulk al HUB logístico en Nicaragua

- actual_arrival
  - tipo: DATE
  - pk: no
  - descripcion: fecha real en que el bulk llegó y fue recibido en el HUB

- status
  - tipo: VARCHAR(30)
  - pk: no
  - restriccion: CHECK IN ('PENDING','SHIPPED','RECEIVED','CANCELLED')
  - descripcion: estado actual de la importación en su ciclo de vida logístico

- total_cost_usd
  - tipo: DECIMAL(14,2)
  - pk: no
  - restriccion: CHECK >= 0
  - descripcion: costo total de la importación en USD; se calcula sumando todos los Import_details

- notes
  - tipo: TEXT
  - pk: no
  - descripcion: observaciones adicionales sobre la importación (retrasos, incidentes, condiciones de la carga)

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

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
  - descripcion: producto importado en esta línea

- quantity
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, CHECK > 0
  - descripcion: cantidad de unidades importadas de este producto en bulk

- unit_cost_usd
  - tipo: DECIMAL(12,2)
  - pk: no
  - restriccion: NOT NULL, CHECK > 0
  - descripcion: costo unitario pactado con el proveedor en USD para esta importación específica

- subtotal_usd
  - tipo: DECIMAL(14,2)
  - pk: no
  - restriccion: NOT NULL, CHECK >= 0
  - descripcion: subtotal de la línea en USD (quantity × unit_cost_usd)

---

## Logistic_costs

- logistic_cost_id
  - tipo: SERIAL
  - pk: si
  - descripcion: identificador único del registro de costos logísticos

- import_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, UNIQUE, FK → Imports.import_id
  - descripcion: importación a la que corresponden estos costos logísticos (un registro por importación)

- shipping_cost_usd
  - tipo: DECIMAL(12,2)
  - pk: no
  - restriccion: DEFAULT 0.00, CHECK >= 0
  - descripcion: costo del flete marítimo o aéreo desde el país de origen hasta el HUB en Nicaragua

- insurance_cost_usd
  - tipo: DECIMAL(12,2)
  - pk: no
  - restriccion: DEFAULT 0.00, CHECK >= 0
  - descripcion: costo del seguro de la carga durante el transporte

- port_handling_usd
  - tipo: DECIMAL(12,2)
  - pk: no
  - restriccion: DEFAULT 0.00, CHECK >= 0
  - descripcion: costos de manejo portuario, descarga y almacenaje temporal en el puerto de llegada

- other_costs_usd
  - tipo: DECIMAL(12,2)
  - pk: no
  - restriccion: DEFAULT 0.00, CHECK >= 0
  - descripcion: otros costos logísticos no clasificados (inspecciones, certificados de origen, fumigaciones)

- notes
  - tipo: TEXT
  - pk: no
  - descripcion: detalle de los costos adicionales incluidos en other_costs_usd

---

## Import_tariffs

- tariff_id
  - tipo: SERIAL
  - pk: si
  - descripcion: identificador único del registro de arancel o impuesto de importación

- import_detail_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Import_details.import_detail_id
  - descripcion: línea de detalle de importación sobre la que aplica este arancel

- destination_country_iso
  - tipo: CHAR(3)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: código ISO del país de destino final; determina el arancel aplicable según la legislación de ese país

- tariff_type
  - tipo: VARCHAR(80)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: tipo de gravamen aplicado (ej: 'Arancel General', 'IVA Importación', 'Tasa Portuaria', 'Impuesto Específico')

- tariff_rate_percent
  - tipo: DECIMAL(5,2)
  - pk: no
  - restriccion: DEFAULT 0.00, CHECK >= 0
  - descripcion: porcentaje del arancel aplicado sobre el valor de la mercancía

- tariff_amount_usd
  - tipo: DECIMAL(12,2)
  - pk: no
  - restriccion: NOT NULL, CHECK >= 0
  - descripcion: monto calculado del arancel en USD; se suma al costo del producto para obtener el costo landed real

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

---

## Country_product_permits

- permit_id
  - tipo: SERIAL
  - pk: si
  - descripcion: identificador único del permiso sanitario o regulatorio

- product_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Products.product_id
  - descripcion: producto al que aplica el permiso

- destination_country_iso
  - tipo: CHAR(3)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: código ISO del país donde se requiere el permiso para comercializar el producto

- permit_type
  - tipo: VARCHAR(100)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: tipo de permiso o registro requerido por el país (ej: 'INVIMA' Colombia, 'COFEPRIS' México, 'DIGEMID' Perú, 'ANMAT' Argentina)

- permit_number
  - tipo: VARCHAR(100)
  - pk: no
  - descripcion: número oficial del registro o permiso otorgado por la autoridad sanitaria

- issuing_authority
  - tipo: VARCHAR(150)
  - pk: no
  - descripcion: entidad gubernamental que emite el permiso (ej: 'Ministerio de Salud de Colombia')

- valid_from
  - tipo: DATE
  - pk: no
  - restriccion: NOT NULL
  - descripcion: fecha de inicio de vigencia del permiso

- valid_until
  - tipo: DATE
  - pk: no
  - descripcion: fecha de expiración del permiso (NULL si el permiso es indefinido)

- permit_cost_usd
  - tipo: DECIMAL(10,2)
  - pk: no
  - restriccion: DEFAULT 0.00, CHECK >= 0
  - descripcion: costo incurrido para obtener el permiso en USD; se considera parte del costo operativo por país

- status
  - tipo: VARCHAR(20)
  - pk: no
  - restriccion: CHECK IN ('ACTIVE','EXPIRED','PENDING','REJECTED')
  - descripcion: estado actual del permiso; solo se puede despachar un producto a un país si el permiso está ACTIVE

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación del registro

> **Restricción única:** UNIQUE(product_id, destination_country_iso, permit_type)

---

## Inventory

- inventory_id
  - tipo: SERIAL
  - pk: si
  - descripcion: identificador único del registro de inventario

- warehouse_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Warehouses.warehouse_id
  - descripcion: almacén donde se encuentra físicamente el stock

- product_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Products.product_id
  - descripcion: producto cuyo stock se registra

- quantity_available
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, DEFAULT 0, CHECK >= 0
  - descripcion: unidades disponibles actualmente para despacho (no incluye las reservadas)

- quantity_reserved
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, DEFAULT 0, CHECK >= 0
  - descripcion: unidades reservadas para despachos pendientes pero aún no enviadas físicamente

- last_updated
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de la última actualización del registro de inventario

> **Restricción única:** UNIQUE(warehouse_id, product_id)

---

## Inventory_movements

- movement_id
  - tipo: SERIAL
  - pk: si
  - descripcion: identificador único del movimiento de inventario

- inventory_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Inventory.inventory_id
  - descripcion: registro de inventario afectado por el movimiento

- movement_type
  - tipo: VARCHAR(30)
  - pk: no
  - restriccion: NOT NULL, CHECK IN ('ENTRY','DISPATCH','ADJUSTMENT','RETURN','LOSS')
  - descripcion: tipo de movimiento; ENTRY es entrada por importación, DISPATCH es salida por despacho a Dynamic Brands, ADJUSTMENT es corrección manual, RETURN es devolución, LOSS es pérdida o merma

- quantity
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL
  - descripcion: cantidad movida; positivo para entradas, negativo para salidas

- reference_type
  - tipo: VARCHAR(30)
  - pk: no
  - restriccion: CHECK IN ('IMPORT','DISPATCH','MANUAL','RETURN')
  - descripcion: tipo del registro que originó el movimiento; permite rastrear la causa

- reference_id
  - tipo: INT
  - pk: no
  - descripcion: ID del import_id o dispatch_order_id que causó el movimiento; junto con reference_type permite trazabilidad completa del producto desde el proveedor al cliente

- moved_by
  - tipo: VARCHAR(100)
  - pk: no
  - descripcion: usuario, sistema o proceso que ejecutó el movimiento (ej: 'SP_InsertDispatch', 'admin@etheria.com')

- notes
  - tipo: TEXT
  - pk: no
  - descripcion: observaciones del movimiento (ej: motivo del ajuste, descripción de la pérdida)

- moved_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora exacta en que se realizó el movimiento

---

## Dispatch_orders

- dispatch_order_id
  - tipo: SERIAL
  - pk: si
  - descripcion: identificador único de la orden de despacho; es la clave primaria de integración con Dynamic Brands

- reference_order_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL
  - descripcion: ID de la orden en Dynamic Brands (Orders.order_id) que originó este despacho; clave de integración ETL entre ambas bases de datos

- product_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Products.product_id
  - descripcion: producto base en bulk que se despacha desde el HUB; antes de salir se etiqueta con la marca blanca solicitada

- quantity
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, CHECK > 0
  - descripcion: cantidad de unidades a despachar

- warehouse_id
  - tipo: INT
  - pk: no
  - restriccion: NOT NULL, FK → Warehouses.warehouse_id
  - descripcion: almacén desde el que se retira el producto para su preparación y despacho

- destination_country_iso
  - tipo: CHAR(3)
  - pk: no
  - restriccion: NOT NULL
  - descripcion: código ISO del país de destino final del paquete; determina los requisitos legales y de empaque aplicables

- brand_label
  - tipo: VARCHAR(150)
  - pk: no
  - descripcion: nombre de la marca blanca con la que se etiquetará el producto bulk antes del despacho (ej: 'AromaPura', 'VerdeLux')

- packaging_permit_ok
  - tipo: BOOLEAN
  - pk: no
  - restriccion: DEFAULT FALSE
  - descripcion: indica si los permisos sanitarios y de empaque requeridos por el país destino han sido verificados y están vigentes antes de proceder al despacho

- dispatch_date
  - tipo: TIMESTAMP
  - pk: no
  - descripcion: fecha y hora real en que el producto salió del almacén ya empacado y etiquetado

- courier_handoff_date
  - tipo: TIMESTAMP
  - pk: no
  - descripcion: fecha y hora en que el courier externo recogió el paquete del HUB; a partir de aquí la responsabilidad pasa al courier

- status
  - tipo: VARCHAR(30)
  - pk: no
  - restriccion: CHECK IN ('PENDING','PREPARING','LABELED','SHIPPED','DELIVERED','CANCELLED')
  - descripcion: estado actual del despacho; LABELED indica que el bulk ya tiene la marca blanca aplicada y está listo para el courier

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora de creación de la orden de despacho

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
  - tipo: INT
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
  - descripcion: mensaje de error detallado capturado en el bloque EXCEPTION; solo se llena cuando status = 'ERROR'

- created_at
  - tipo: TIMESTAMP
  - pk: no
  - restriccion: DEFAULT CURRENT_TIMESTAMP
  - descripcion: fecha y hora exacta en que se generó el registro de log


