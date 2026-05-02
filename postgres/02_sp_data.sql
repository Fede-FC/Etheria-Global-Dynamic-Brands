-- =============================================================
--  ETHERIA GLOBAL — SPs + Datos v2
-- =============================================================
-- \c etheria_global_db;

-- =============================================================
-- SP DE LOG (llamado por todos los demás SPs)
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_log(
    p_sp        VARCHAR, p_desc TEXT, p_table VARCHAR DEFAULT NULL,
    p_id        BIGINT   DEFAULT NULL, p_status VARCHAR DEFAULT 'INFO',
    p_error     TEXT     DEFAULT NULL
) LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO process_log(sp_name,action_description,affected_table,
                            affected_record_id,status,error_detail)
    VALUES(p_sp,p_desc,p_table,p_id,p_status,p_error);
END;$$;

-- =============================================================
-- SP 1 — Catálogos base
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_insert_catalogs()
LANGUAGE plpgsql AS $$
DECLARE v_err TEXT;
BEGIN
    -- Currencies
    INSERT INTO currencies(currency_code,currency_name,currency_symbol,is_base)
    VALUES
        ('USD','US Dollar','$',TRUE),
        ('COP','Peso Colombiano','$',FALSE),
        ('PEN','Sol Peruano','S/',FALSE),
        ('MXN','Peso Mexicano','$',FALSE),
        ('CLP','Peso Chileno','$',FALSE),
        ('CRC','Colón Costarricense','₡',FALSE)
    ON CONFLICT(currency_code) DO NOTHING;

    -- Categories
    INSERT INTO categories(category_name,description)
    VALUES
        ('Aceites Esenciales','Aceites naturales para aromaterapia y uso tópico'),
        ('Cosmética Dermatológica','Productos para el cuidado de la piel'),
        ('Capilar','Productos para el cuidado del cabello'),
        ('Bebidas Naturales','Bebidas funcionales y saludables'),
        ('Alimentos Funcionales','Alimentos con propiedades medicinales'),
        ('Jabones Artesanales','Jabones naturales y orgánicos'),
        ('Aromaterapia','Difusores y mezclas aromáticas')
    ON CONFLICT(category_name) DO NOTHING;

    -- MeasurementUnits
    INSERT INTO measurement_units(unit_code,unit_name,unit_type)
    VALUES
        ('KG','Kilogramo','WEIGHT'),
        ('G','Gramo','WEIGHT'),
        ('L','Litro','VOLUME'),
        ('ML','Mililitro','VOLUME'),
        ('UN','Unidad','UNIT')
    ON CONFLICT(unit_code) DO NOTHING;

    -- CostTypes
    INSERT INTO cost_types(cost_type_code,cost_type_name,applies_to)
    VALUES
        ('FLETE','Flete Marítimo','LOGISTIC'),
        ('SEGURO','Seguro de Carga','LOGISTIC'),
        ('PUERTO','Manejo Portuario','LOGISTIC'),
        ('ARANCEL_GEN','Arancel General de Importación','TARIFF'),
        ('IVA_IMPORT','IVA en Importación','TARIFF'),
        ('PERMISO_SAN','Permiso Sanitario','PERMIT'),
        ('PERMISO_COSM','Registro Cosmético','PERMIT'),
        ('COURIER','Envío Courier al Cliente','SHIPPING'),
        ('ALMACEN','Almacenamiento HUB','OTHER')
    ON CONFLICT(cost_type_code) DO NOTHING;

    -- PermitTypes
    INSERT INTO permit_types(permit_type_code,permit_type_name,issuing_authority)
    VALUES
        ('INVIMA','Registro INVIMA Colombia','INVIMA Colombia'),
        ('DIGEMID','Registro DIGEMID Perú','DIGEMID Perú'),
        ('COFEPRIS','Registro COFEPRIS México','COFEPRIS México'),
        ('ISP','Registro ISP Chile','ISP Chile'),
        ('MINSA_CRI','Registro MINSA Costa Rica','MINSA Costa Rica')
    ON CONFLICT(permit_type_code) DO NOTHING;

    -- ImportStatuses
    INSERT INTO import_statuses(status_code,description)
    VALUES
        ('PENDING','Pendiente de envío'),
        ('SHIPPED','En tránsito'),
        ('RECEIVED','Recibido en HUB'),
        ('DISPATCHED','Despachado al país destino'),
        ('CANCELLED','Cancelado'),
        ('ACTIVE','Activo'),
        ('EXPIRED','Expirado'),
        ('REJECTED','Rechazado')
    ON CONFLICT(status_code) DO NOTHING;

    -- WarehouseTypes
    INSERT INTO warehouse_types(type_code,type_name)
    VALUES
        ('RECEIVING','Recepción de Mercancía'),
        ('LABELING','Etiquetado y Marcas'),
        ('DISPATCH','Despacho'),
        ('MIXED','Uso Mixto')
    ON CONFLICT(type_code) DO NOTHING;

    -- MovementTypes
    INSERT INTO movement_types(type_code,type_name,direction)
    VALUES
        ('ENTRY','Entrada por Importación',1),
        ('DISPATCH','Salida por Despacho',-1),
        ('ADJUSTMENT','Ajuste de Inventario',1),
        ('RETURN','Devolución',1),
        ('LOSS','Pérdida/Merma',-1)
    ON CONFLICT(type_code) DO NOTHING;

    CALL sp_log('sp_insert_catalogs','Catálogos insertados','currencies',NULL,'SUCCESS');
EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    CALL sp_log('sp_insert_catalogs','Error en catálogos',NULL,NULL,'ERROR',v_err);
    RAISE;
END;$$;

-- =============================================================
-- SP 2 — Países, estados, ciudades, direcciones
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_insert_geography()
LANGUAGE plpgsql AS $$
DECLARE
    v_cid_col INT; v_cid_per INT; v_cid_mex INT;
    v_cid_chl INT; v_cid_cri INT; v_cid_nic INT;
    v_cur_usd INT; v_cur_cop INT; v_cur_pen INT;
    v_cur_mxn INT; v_cur_clp INT; v_cur_crc INT;
    v_st INT; v_city INT; v_addr INT;
    v_err TEXT;
BEGIN
    SELECT currency_id INTO v_cur_usd FROM currencies WHERE currency_code='USD';
    SELECT currency_id INTO v_cur_cop FROM currencies WHERE currency_code='COP';
    SELECT currency_id INTO v_cur_pen FROM currencies WHERE currency_code='PEN';
    SELECT currency_id INTO v_cur_mxn FROM currencies WHERE currency_code='MXN';
    SELECT currency_id INTO v_cur_clp FROM currencies WHERE currency_code='CLP';
    SELECT currency_id INTO v_cur_crc FROM currencies WHERE currency_code='CRC';

    -- Países
    INSERT INTO countries(country_name,iso_code,region,currency_id)
    VALUES
        ('Colombia','COL','Latinoamérica',v_cur_cop),
        ('Perú','PER','Latinoamérica',v_cur_pen),
        ('México','MEX','Latinoamérica',v_cur_mxn),
        ('Chile','CHL','Latinoamérica',v_cur_clp),
        ('Costa Rica','CRI','Centroamérica',v_cur_crc),
        ('Nicaragua','NIC','Centroamérica',v_cur_usd)   -- HUB logístico
    ON CONFLICT(iso_code) DO NOTHING;

    SELECT country_id INTO v_cid_col FROM countries WHERE iso_code='COL';
    SELECT country_id INTO v_cid_per FROM countries WHERE iso_code='PER';
    SELECT country_id INTO v_cid_mex FROM countries WHERE iso_code='MEX';
    SELECT country_id INTO v_cid_chl FROM countries WHERE iso_code='CHL';
    SELECT country_id INTO v_cid_cri FROM countries WHERE iso_code='CRI';
    SELECT country_id INTO v_cid_nic FROM countries WHERE iso_code='NIC';

    -- Estados/Provincias principales
    INSERT INTO states(country_id,state_name,state_code) VALUES
        (v_cid_col,'Cundinamarca','CUN'),(v_cid_col,'Antioquia','ANT'),
        (v_cid_per,'Lima','LIM'),(v_cid_per,'Arequipa','AQP'),
        (v_cid_mex,'Ciudad de México','CDMX'),(v_cid_mex,'Jalisco','JAL'),
        (v_cid_chl,'Región Metropolitana','RM'),(v_cid_chl,'Valparaíso','VAL'),
        (v_cid_cri,'San José','SJ'),(v_cid_cri,'Alajuela','AL'),
        (v_cid_nic,'Managua','MAN'),(v_cid_nic,'Región Autónoma Caribe Sur','RACS');

    -- Ciudades
    SELECT state_id INTO v_st FROM states WHERE state_code='CUN';
    INSERT INTO cities(state_id,city_name) VALUES(v_st,'Bogotá');
    SELECT state_id INTO v_st FROM states WHERE state_code='LIM';
    INSERT INTO cities(state_id,city_name) VALUES(v_st,'Lima');
    SELECT state_id INTO v_st FROM states WHERE state_code='CDMX';
    INSERT INTO cities(state_id,city_name) VALUES(v_st,'Ciudad de México');
    SELECT state_id INTO v_st FROM states WHERE state_code='RM';
    INSERT INTO cities(state_id,city_name) VALUES(v_st,'Santiago');
    SELECT state_id INTO v_st FROM states WHERE state_code='SJ';
    INSERT INTO cities(state_id,city_name) VALUES(v_st,'San José');
    SELECT state_id INTO v_st FROM states WHERE state_code='RACS';
    INSERT INTO cities(state_id,city_name) VALUES(v_st,'Bluefields');  -- HUB

    -- Dirección del HUB Nicaragua
    SELECT city_id INTO v_city FROM cities WHERE city_name='Bluefields';
    INSERT INTO addresses(address_line1,city_id)
    VALUES('Puerto de Bluefields, Zona Franca Caribe Sur',v_city)
    RETURNING address_id INTO v_addr;

    CALL sp_log('sp_insert_geography','Geografía insertada: 6 países','countries',NULL,'SUCCESS');
EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    CALL sp_log('sp_insert_geography','Error geografía',NULL,NULL,'ERROR',v_err);
    RAISE;
END;$$;

-- =============================================================
-- SP 3 — Tipos de cambio históricos
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_insert_exchange_rates()
LANGUAGE plpgsql AS $$
DECLARE
    v_usd INT; v_cop INT; v_pen INT; v_mxn INT; v_clp INT; v_crc INT;
    v_err TEXT;
BEGIN
    SELECT currency_id INTO v_usd FROM currencies WHERE currency_code='USD';
    SELECT currency_id INTO v_cop FROM currencies WHERE currency_code='COP';
    SELECT currency_id INTO v_pen FROM currencies WHERE currency_code='PEN';
    SELECT currency_id INTO v_mxn FROM currencies WHERE currency_code='MXN';
    SELECT currency_id INTO v_clp FROM currencies WHERE currency_code='CLP';
    SELECT currency_id INTO v_crc FROM currencies WHERE currency_code='CRC';

    -- rate = cuántas unidades de moneda local compra 1 USD
    INSERT INTO exchange_rates(currency_id,base_currency_id,rate,rate_date,source) VALUES
        (v_cop,v_usd,4150.00,'2025-01-01','Banco de la República'),
        (v_pen,v_usd,3.72,  '2025-01-01','BCRP'),
        (v_mxn,v_usd,17.15, '2025-01-01','Banxico'),
        (v_clp,v_usd,920.00,'2025-01-01','Banco Central de Chile'),
        (v_crc,v_usd,515.00,'2025-01-01','BCCR'),
        (v_cop,v_usd,4200.00,'2025-06-01','Banco de la República'),
        (v_pen,v_usd,3.75,  '2025-06-01','BCRP'),
        (v_mxn,v_usd,17.50, '2025-06-01','Banxico'),
        (v_clp,v_usd,940.00,'2025-06-01','Banco Central de Chile'),
        (v_crc,v_usd,520.00,'2025-06-01','BCCR')
    ON CONFLICT(currency_id,base_currency_id,rate_date) DO NOTHING;

    CALL sp_log('sp_insert_exchange_rates','Tipos de cambio insertados','exchange_rates',NULL,'SUCCESS');
EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    CALL sp_log('sp_insert_exchange_rates','Error tipos de cambio',NULL,NULL,'ERROR',v_err);
    RAISE;
END;$$;

-- =============================================================
-- SP 4 — Proveedores y almacenes
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_insert_suppliers_warehouses()
LANGUAGE plpgsql AS $$
DECLARE
    v_cid_ind INT; v_cid_fra INT; v_cid_bra INT; v_cid_nic INT;
    v_cur_usd INT; v_wt INT; v_addr INT; v_city INT; v_st INT;
    v_err TEXT;
BEGIN
    SELECT currency_id INTO v_cur_usd FROM currencies WHERE currency_code='USD';

    -- Países de origen de proveedores
    INSERT INTO countries(country_name,iso_code,region,currency_id)
    VALUES
        ('India','IND','Asia',v_cur_usd),
        ('Francia','FRA','Europa',v_cur_usd),
        ('Brasil','BRA','Latinoamérica',v_cur_usd)
    ON CONFLICT(iso_code) DO NOTHING;

    SELECT country_id INTO v_cid_ind FROM countries WHERE iso_code='IND';
    SELECT country_id INTO v_cid_fra FROM countries WHERE iso_code='FRA';
    SELECT country_id INTO v_cid_bra FROM countries WHERE iso_code='BRA';
    SELECT country_id INTO v_cid_nic FROM countries WHERE iso_code='NIC';

    -- Proveedores
    INSERT INTO suppliers(supplier_name,country_id,contact_email,contact_phone) VALUES
        ('Himalaya Naturals Ltd',     v_cid_ind,'procurement@himalaya-naturals.com','+91-22-12345678'),
        ('Provence Arômes SARL',      v_cid_fra,'contact@provence-aromes.fr','+33-4-90123456'),
        ('AmazonBio Exportações Ltda',v_cid_bra,'export@amazonbio.com.br','+55-92-98765432'),
        ('Pacific Wellness Co.',      v_cid_ind,'sales@pacificwellness.in','+91-80-87654321'),
        ('Andean Roots S.A.',         v_cid_bra,'info@andeanroots.com','+55-11-11223344');

    -- Almacenes HUB Nicaragua
    SELECT warehouse_type_id INTO v_wt FROM warehouse_types WHERE type_code='RECEIVING';
    SELECT city_id INTO v_city FROM cities WHERE city_name='Bluefields';
    SELECT address_id INTO v_addr FROM addresses WHERE city_id=v_city LIMIT 1;

    INSERT INTO warehouses(warehouse_name,address_id,warehouse_type_id,capacity_units) VALUES
        ('HUB-A Recepción Caribe',v_addr,v_wt,5000);
    SELECT warehouse_type_id INTO v_wt FROM warehouse_types WHERE type_code='LABELING';
    INSERT INTO warehouses(warehouse_name,address_id,warehouse_type_id,capacity_units) VALUES
        ('HUB-B Etiquetado y Marcas',v_addr,v_wt,3000);
    SELECT warehouse_type_id INTO v_wt FROM warehouse_types WHERE type_code='DISPATCH';
    INSERT INTO warehouses(warehouse_name,address_id,warehouse_type_id,capacity_units) VALUES
        ('HUB-C Despacho Internacional',v_addr,v_wt,4000);

    CALL sp_log('sp_insert_suppliers_warehouses','5 proveedores y 3 almacenes insertados',NULL,NULL,'SUCCESS');
EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    CALL sp_log('sp_insert_suppliers_warehouses','Error proveedores/almacenes',NULL,NULL,'ERROR',v_err);
    RAISE;
END;$$;

-- =============================================================
-- SP 5 — Productos (100 distribuidos en 7 categorías)
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_insert_products()
LANGUAGE plpgsql AS $$
DECLARE
    v_cat_ace INT; v_cat_cos INT; v_cat_cap INT; v_cat_beb INT;
    v_cat_ali INT; v_cat_jab INT; v_cat_aro INT;
    v_unit_l INT; v_unit_ml INT; v_unit_kg INT; v_unit_g INT; v_unit_un INT;
    v_cid_ind INT; v_cid_bra INT; v_cid_fra INT;
    v_err TEXT;
BEGIN
    SELECT category_id INTO v_cat_ace FROM categories WHERE category_name='Aceites Esenciales';
    SELECT category_id INTO v_cat_cos FROM categories WHERE category_name='Cosmética Dermatológica';
    SELECT category_id INTO v_cat_cap FROM categories WHERE category_name='Capilar';
    SELECT category_id INTO v_cat_beb FROM categories WHERE category_name='Bebidas Naturales';
    SELECT category_id INTO v_cat_ali FROM categories WHERE category_name='Alimentos Funcionales';
    SELECT category_id INTO v_cat_jab FROM categories WHERE category_name='Jabones Artesanales';
    SELECT category_id INTO v_cat_aro FROM categories WHERE category_name='Aromaterapia';
    SELECT unit_id INTO v_unit_l   FROM measurement_units WHERE unit_code='L';
    SELECT unit_id INTO v_unit_ml  FROM measurement_units WHERE unit_code='ML';
    SELECT unit_id INTO v_unit_kg  FROM measurement_units WHERE unit_code='KG';
    SELECT unit_id INTO v_unit_g   FROM measurement_units WHERE unit_code='G';
    SELECT unit_id INTO v_unit_un  FROM measurement_units WHERE unit_code='UN';
    SELECT country_id INTO v_cid_ind FROM countries WHERE iso_code='IND';
    SELECT country_id INTO v_cid_bra FROM countries WHERE iso_code='BRA';
    SELECT country_id INTO v_cid_fra FROM countries WHERE iso_code='FRA';

    -- Aceites Esenciales (20 productos)
    INSERT INTO products(product_name,category_id,unit_id,unit_weight_kg,origin_country_id) VALUES
        ('Aceite Esencial de Lavanda 30ml',v_cat_ace,v_unit_ml,0.05,v_cid_fra),
        ('Aceite Esencial de Árbol de Té 30ml',v_cat_ace,v_unit_ml,0.05,v_cid_ind),
        ('Aceite Esencial de Eucalipto 50ml',v_cat_ace,v_unit_ml,0.08,v_cid_ind),
        ('Aceite Esencial de Rosa Mosqueta 30ml',v_cat_ace,v_unit_ml,0.05,v_cid_bra),
        ('Aceite Esencial de Menta 30ml',v_cat_ace,v_unit_ml,0.05,v_cid_ind),
        ('Aceite de Coco Virgen 500ml',v_cat_ace,v_unit_ml,0.55,v_cid_ind),
        ('Aceite de Argán Puro 100ml',v_cat_ace,v_unit_ml,0.12,v_cid_ind),
        ('Aceite de Jojoba 100ml',v_cat_ace,v_unit_ml,0.12,v_cid_ind),
        ('Aceite de Almendras Dulces 250ml',v_cat_ace,v_unit_ml,0.27,v_cid_ind),
        ('Aceite de Ricino Premium 200ml',v_cat_ace,v_unit_ml,0.22,v_cid_ind),
        ('Aceite Esencial de Bergamota 15ml',v_cat_ace,v_unit_ml,0.03,v_cid_fra),
        ('Aceite Esencial de Ylang Ylang 15ml',v_cat_ace,v_unit_ml,0.03,v_cid_ind),
        ('Aceite Esencial de Limón 30ml',v_cat_ace,v_unit_ml,0.05,v_cid_bra),
        ('Aceite Esencial de Naranja Dulce 30ml',v_cat_ace,v_unit_ml,0.05,v_cid_bra),
        ('Aceite de Hemp Cáñamo 100ml',v_cat_ace,v_unit_ml,0.12,v_cid_ind),
        ('Aceite Esencial de Incienso 15ml',v_cat_ace,v_unit_ml,0.03,v_cid_ind),
        ('Aceite Esencial de Romero 30ml',v_cat_ace,v_unit_ml,0.05,v_cid_fra),
        ('Aceite Esencial de Geranio 30ml',v_cat_ace,v_unit_ml,0.05,v_cid_fra),
        ('Aceite de Macadamia 200ml',v_cat_ace,v_unit_ml,0.22,v_cid_bra),
        ('Aceite de Semilla de Uva 250ml',v_cat_ace,v_unit_ml,0.27,v_cid_fra);

    -- Cosmética Dermatológica (15 productos)
    INSERT INTO products(product_name,category_id,unit_id,unit_weight_kg,origin_country_id) VALUES
        ('Sérum Vitamina C 30ml',v_cat_cos,v_unit_ml,0.08,v_cid_ind),
        ('Crema Hidratante Aloe Vera 150ml',v_cat_cos,v_unit_ml,0.18,v_cid_ind),
        ('Mascarilla de Arcilla Verde 200g',v_cat_cos,v_unit_g,0.22,v_cid_fra),
        ('Contorno de Ojos Retinol 20ml',v_cat_cos,v_unit_ml,0.05,v_cid_fra),
        ('Exfoliante de Café 300g',v_cat_cos,v_unit_g,0.33,v_cid_bra),
        ('Tónico Facial de Agua de Rosas 200ml',v_cat_cos,v_unit_ml,0.22,v_cid_fra),
        ('Crema Antienvejecimiento Q10 50ml',v_cat_cos,v_unit_ml,0.08,v_cid_ind),
        ('Protector Solar Natural SPF50 100ml',v_cat_cos,v_unit_ml,0.12,v_cid_ind),
        ('Mascarilla de Carbón Activado 150ml',v_cat_cos,v_unit_ml,0.17,v_cid_ind),
        ('Sérum Hialurónico 30ml',v_cat_cos,v_unit_ml,0.05,v_cid_fra),
        ('Bálsamo de Cúrcuma 80g',v_cat_cos,v_unit_g,0.10,v_cid_ind),
        ('Crema de Caléndula Orgánica 100ml',v_cat_cos,v_unit_ml,0.12,v_cid_ind),
        ('Aceite Facial de Noche Bakuchiol 30ml',v_cat_cos,v_unit_ml,0.05,v_cid_ind),
        ('Gel de Aloe Vera Puro 500ml',v_cat_cos,v_unit_ml,0.55,v_cid_ind),
        ('Crema Corporal de Manteca de Karité 250ml',v_cat_cos,v_unit_ml,0.27,v_cid_ind);

    -- Capilar (15 productos)
    INSERT INTO products(product_name,category_id,unit_id,unit_weight_kg,origin_country_id) VALUES
        ('Shampoo de Keratina Natural 400ml',v_cat_cap,v_unit_ml,0.44,v_cid_ind),
        ('Acondicionador Proteínas de Seda 400ml',v_cat_cap,v_unit_ml,0.44,v_cid_ind),
        ('Mascarilla Capilar Aguacate 300g',v_cat_cap,v_unit_g,0.33,v_cid_bra),
        ('Sérum Anticaída con Biotina 100ml',v_cat_cap,v_unit_ml,0.12,v_cid_ind),
        ('Aceite Capilar de Argán Marroquí 100ml',v_cat_cap,v_unit_ml,0.12,v_cid_ind),
        ('Shampoo en Barra sin Sulfatos 80g',v_cat_cap,v_unit_g,0.10,v_cid_fra),
        ('Tratamiento Capilar de Ricino 150ml',v_cat_cap,v_unit_ml,0.17,v_cid_ind),
        ('Ampolletas de Colágeno Capilar 12un',v_cat_cap,v_unit_un,0.15,v_cid_ind),
        ('Crema para Peinar sin Enjuague 200ml',v_cat_cap,v_unit_ml,0.22,v_cid_ind),
        ('Spray Protector Térmico Natural 200ml',v_cat_cap,v_unit_ml,0.22,v_cid_fra),
        ('Champú de Romero y Menta 300ml',v_cat_cap,v_unit_ml,0.33,v_cid_fra),
        ('Bálsamo Labial Natural Cacao 10g',v_cat_cap,v_unit_g,0.01,v_cid_bra),
        ('Tónico Capilar Jengibre 100ml',v_cat_cap,v_unit_ml,0.12,v_cid_ind),
        ('Mascarilla Proteínas Quinoa 250g',v_cat_cap,v_unit_g,0.27,v_cid_bra),
        ('Aceite de Cacay para Cabello 50ml',v_cat_cap,v_unit_ml,0.06,v_cid_bra);

    -- Bebidas Naturales (12 productos)
    INSERT INTO products(product_name,category_id,unit_id,unit_weight_kg,origin_country_id) VALUES
        ('Té Verde Matcha Ceremonial 100g',v_cat_beb,v_unit_g,0.12,v_cid_ind),
        ('Moringa en Polvo Orgánica 200g',v_cat_beb,v_unit_g,0.22,v_cid_ind),
        ('Cúrcuma Golden Milk 300g',v_cat_beb,v_unit_g,0.33,v_cid_ind),
        ('Kombucha Base Concentrada 500ml',v_cat_beb,v_unit_ml,0.55,v_cid_ind),
        ('Ashwagandha en Polvo 150g',v_cat_beb,v_unit_g,0.17,v_cid_ind),
        ('Maca Negra Andina en Polvo 200g',v_cat_beb,v_unit_g,0.22,v_cid_bra),
        ('Spirulina Premium en Polvo 250g',v_cat_beb,v_unit_g,0.27,v_cid_ind),
        ('Agua de Coco Liofilizada 150g',v_cat_beb,v_unit_g,0.17,v_cid_bra),
        ('Té de Hibisco Jamaicano 100g',v_cat_beb,v_unit_g,0.12,v_cid_bra),
        ('Guaraná Natural en Polvo 100g',v_cat_beb,v_unit_g,0.12,v_cid_bra),
        ('Jengibre Liofilizado 80g',v_cat_beb,v_unit_g,0.10,v_cid_ind),
        ('Chaga Mushroom en Polvo 100g',v_cat_beb,v_unit_g,0.12,v_cid_ind);

    -- Alimentos Funcionales (12 productos)
    INSERT INTO products(product_name,category_id,unit_id,unit_weight_kg,origin_country_id) VALUES
        ('Aceite MCT de Coco Puro 500ml',v_cat_ali,v_unit_ml,0.55,v_cid_ind),
        ('Colágeno Marino Hidrolizado 300g',v_cat_ali,v_unit_g,0.33,v_cid_ind),
        ('Proteína de Cáñamo Orgánica 500g',v_cat_ali,v_unit_g,0.55,v_cid_ind),
        ('Cacao Crudo en Polvo 250g',v_cat_ali,v_unit_g,0.27,v_cid_bra),
        ('Levadura Nutricional 200g',v_cat_ali,v_unit_g,0.22,v_cid_ind),
        ('Polen de Abeja Orgánico 250g',v_cat_ali,v_unit_g,0.27,v_cid_bra),
        ('Semillas de Chía Orgánica 500g',v_cat_ali,v_unit_g,0.55,v_cid_bra),
        ('Aceite de Hígado de Bacalao 250ml',v_cat_ali,v_unit_ml,0.27,v_cid_ind),
        ('Inulina de Achicoria 300g',v_cat_ali,v_unit_g,0.33,v_cid_bra),
        ('Clorela en Tabletas 250un',v_cat_ali,v_unit_un,0.28,v_cid_ind),
        ('Quercetina con Bromelina 90caps',v_cat_ali,v_unit_un,0.10,v_cid_ind),
        ('Probiótico Multicepa 60caps',v_cat_ali,v_unit_un,0.07,v_cid_ind);

    -- Jabones Artesanales (14 productos)
    INSERT INTO products(product_name,category_id,unit_id,unit_weight_kg,origin_country_id) VALUES
        ('Jabón de Lavanda y Avena 100g',v_cat_jab,v_unit_g,0.11,v_cid_fra),
        ('Jabón de Carbón Activado 100g',v_cat_jab,v_unit_g,0.11,v_cid_ind),
        ('Jabón de Arcilla Kaolin 100g',v_cat_jab,v_unit_g,0.11,v_cid_fra),
        ('Jabón de Leche de Cabra 100g',v_cat_jab,v_unit_g,0.11,v_cid_fra),
        ('Jabón de Azufre Natural 100g',v_cat_jab,v_unit_g,0.11,v_cid_ind),
        ('Jabón de Café Exfoliante 120g',v_cat_jab,v_unit_g,0.13,v_cid_bra),
        ('Jabón de Manteca de Cacao 100g',v_cat_jab,v_unit_g,0.11,v_cid_bra),
        ('Jabón de Rosa Mosqueta 100g',v_cat_jab,v_unit_g,0.11,v_cid_bra),
        ('Jabón de Aloe Vera 100g',v_cat_jab,v_unit_g,0.11,v_cid_ind),
        ('Jabón de Miel y Avena 100g',v_cat_jab,v_unit_g,0.11,v_cid_ind),
        ('Jabón de Árbol de Té Antibacterial 100g',v_cat_jab,v_unit_g,0.11,v_cid_ind),
        ('Jabón de Oliva Extra Virgen 100g',v_cat_jab,v_unit_g,0.11,v_cid_fra),
        ('Jabón de Cúrcuma Antiinflamatorio 100g',v_cat_jab,v_unit_g,0.11,v_cid_ind),
        ('Jabón de Chocolate y Café 120g',v_cat_jab,v_unit_g,0.13,v_cid_bra);

    -- Aromaterapia (12 productos)
    INSERT INTO products(product_name,category_id,unit_id,unit_weight_kg,origin_country_id) VALUES
        ('Difusor Ultrasónico de Bambú 200ml',v_cat_aro,v_unit_un,0.35,v_cid_ind),
        ('Mezcla Relax Lavanda-Bergamota 30ml',v_cat_aro,v_unit_ml,0.05,v_cid_fra),
        ('Mezcla Energía Menta-Romero 30ml',v_cat_aro,v_unit_ml,0.05,v_cid_fra),
        ('Mezcla Immunity Eucalipto-Árbol Té 30ml',v_cat_aro,v_unit_ml,0.05,v_cid_ind),
        ('Velas de Cera de Abeja Lavanda 200g',v_cat_aro,v_unit_g,0.22,v_cid_fra),
        ('Velas de Soya y Vainilla 200g',v_cat_aro,v_unit_g,0.22,v_cid_bra),
        ('Incienso Natural de Palo Santo 20un',v_cat_aro,v_unit_un,0.04,v_cid_bra),
        ('Incienso de Sándalo Premium 20un',v_cat_aro,v_unit_un,0.04,v_cid_ind),
        ('Spray Ambiental Relajante 150ml',v_cat_aro,v_unit_ml,0.17,v_cid_fra),
        ('Piedras de Lava para Difusor 50un',v_cat_aro,v_unit_un,0.15,v_cid_ind),
        ('Kit Aromaterapia Básico 5 aceites',v_cat_aro,v_unit_un,0.25,v_cid_fra),
        ('Collar Difusor Aromaterapia',v_cat_aro,v_unit_un,0.05,v_cid_ind);

    CALL sp_log('sp_insert_products','100 productos insertados en 7 categorías','products',NULL,'SUCCESS');
EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    CALL sp_log('sp_insert_products','Error productos',NULL,NULL,'ERROR',v_err);
    RAISE;
END;$$;

-- =============================================================
-- SP 6 — Importaciones con costos detallados
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_insert_imports()
LANGUAGE plpgsql AS $$
DECLARE
    v_sup1 INT; v_sup2 INT; v_sup3 INT; v_sup4 INT; v_sup5 INT;
    v_st_rcv INT; v_st_shp INT; v_st_pnd INT;
    v_cur_usd INT; v_er_usd INT;
    v_ct_flete INT; v_ct_seg INT; v_ct_pto INT; v_ct_aran INT;
    v_imp INT; v_det INT;
    v_prod INT; v_i INT;
    v_err TEXT;
BEGIN
    SELECT supplier_id INTO v_sup1 FROM suppliers WHERE supplier_name LIKE 'Himalaya%';
    SELECT supplier_id INTO v_sup2 FROM suppliers WHERE supplier_name LIKE 'Provence%';
    SELECT supplier_id INTO v_sup3 FROM suppliers WHERE supplier_name LIKE 'AmazonBio%';
    SELECT supplier_id INTO v_sup4 FROM suppliers WHERE supplier_name LIKE 'Pacific%';
    SELECT supplier_id INTO v_sup5 FROM suppliers WHERE supplier_name LIKE 'Andean%';
    SELECT status_id INTO v_st_rcv FROM import_statuses WHERE status_code='RECEIVED';
    SELECT status_id INTO v_st_shp FROM import_statuses WHERE status_code='SHIPPED';
    SELECT status_id INTO v_st_pnd FROM import_statuses WHERE status_code='PENDING';
    SELECT currency_id INTO v_cur_usd FROM currencies WHERE currency_code='USD';
    SELECT exchange_rate_id INTO v_er_usd FROM exchange_rates
        WHERE currency_id=v_cur_usd AND base_currency_id=v_cur_usd LIMIT 1;
    -- Insertar un rate self-referencial USD→USD si no existe
    IF v_er_usd IS NULL THEN
        INSERT INTO exchange_rates(currency_id,base_currency_id,rate,rate_date,source)
        VALUES(v_cur_usd,v_cur_usd,1.0,'2025-01-01','Sistema')
        ON CONFLICT DO NOTHING
        RETURNING exchange_rate_id INTO v_er_usd;
        IF v_er_usd IS NULL THEN
            SELECT exchange_rate_id INTO v_er_usd FROM exchange_rates
            WHERE currency_id=v_cur_usd AND base_currency_id=v_cur_usd LIMIT 1;
        END IF;
    END IF;

    SELECT cost_type_id INTO v_ct_flete FROM cost_types WHERE cost_type_code='FLETE';
    SELECT cost_type_id INTO v_ct_seg   FROM cost_types WHERE cost_type_code='SEGURO';
    SELECT cost_type_id INTO v_ct_pto   FROM cost_types WHERE cost_type_code='PUERTO';
    SELECT cost_type_id INTO v_ct_aran  FROM cost_types WHERE cost_type_code='ARANCEL_GEN';

    -- IMPORTACIÓN 1: Himalaya — Aceites y Cosmética
    INSERT INTO imports(supplier_id,status_id,import_date,actual_arrival,notes)
    VALUES(v_sup1,v_st_rcv,'2025-01-15','2025-02-10','Lote Q1 aceites esenciales India')
    RETURNING import_id INTO v_imp;

    FOR v_i IN 1..8 LOOP
        SELECT product_id INTO v_prod FROM products
        WHERE category_id=(SELECT category_id FROM categories WHERE category_name='Aceites Esenciales')
        ORDER BY product_id OFFSET v_i-1 LIMIT 1;
        INSERT INTO import_details(import_id,product_id,quantity,unit_cost,currency_id,exchange_rate_id,subtotal)
        VALUES(v_imp,v_prod,500,8.50+v_i*0.5,v_cur_usd,v_er_usd,(500*(8.50+v_i*0.5)))
        RETURNING import_detail_id INTO v_det;
    END LOOP;
    INSERT INTO import_costs(import_id,cost_type_id,amount,currency_id,exchange_rate_id)
    VALUES(v_imp,v_ct_flete,1200,v_cur_usd,v_er_usd),
          (v_imp,v_ct_seg,240,v_cur_usd,v_er_usd),
          (v_imp,v_ct_pto,180,v_cur_usd,v_er_usd);

    -- IMPORTACIÓN 2: Provence — Cosméticos Francia
    INSERT INTO imports(supplier_id,status_id,import_date,actual_arrival,notes)
    VALUES(v_sup2,v_st_rcv,'2025-02-01','2025-03-01','Cosméticos premium Francia Q1')
    RETURNING import_id INTO v_imp;

    FOR v_i IN 1..6 LOOP
        SELECT product_id INTO v_prod FROM products
        WHERE category_id=(SELECT category_id FROM categories WHERE category_name='Cosmética Dermatológica')
        ORDER BY product_id OFFSET v_i-1 LIMIT 1;
        INSERT INTO import_details(import_id,product_id,quantity,unit_cost,currency_id,exchange_rate_id,subtotal)
        VALUES(v_imp,v_prod,300,12.00+v_i*1.0,v_cur_usd,v_er_usd,(300*(12.00+v_i*1.0)))
        RETURNING import_detail_id INTO v_det;
    END LOOP;
    INSERT INTO import_costs(import_id,cost_type_id,amount,currency_id,exchange_rate_id)
    VALUES(v_imp,v_ct_flete,900,v_cur_usd,v_er_usd),
          (v_imp,v_ct_seg,180,v_cur_usd,v_er_usd),
          (v_imp,v_ct_pto,120,v_cur_usd,v_er_usd);

    -- IMPORTACIÓN 3: AmazonBio — Bebidas y Alimentos Brasil
    INSERT INTO imports(supplier_id,status_id,import_date,actual_arrival,notes)
    VALUES(v_sup3,v_st_rcv,'2025-02-15','2025-03-20','Bebidas y superfoods Brasil')
    RETURNING import_id INTO v_imp;

    FOR v_i IN 1..8 LOOP
        SELECT product_id INTO v_prod FROM products
        WHERE category_id IN (
            SELECT category_id FROM categories
            WHERE category_name IN ('Bebidas Naturales','Alimentos Funcionales')
        )
        ORDER BY product_id OFFSET v_i-1 LIMIT 1;
        INSERT INTO import_details(import_id,product_id,quantity,unit_cost,currency_id,exchange_rate_id,subtotal)
        VALUES(v_imp,v_prod,400,6.50+v_i*0.3,v_cur_usd,v_er_usd,(400*(6.50+v_i*0.3)))
        RETURNING import_detail_id INTO v_det;
    END LOOP;
    INSERT INTO import_costs(import_id,cost_type_id,amount,currency_id,exchange_rate_id)
    VALUES(v_imp,v_ct_flete,800,v_cur_usd,v_er_usd),
          (v_imp,v_ct_seg,160,v_cur_usd,v_er_usd),
          (v_imp,v_ct_pto,100,v_cur_usd,v_er_usd);

    -- IMPORTACIÓN 4: Pacific Wellness — Capilar
    INSERT INTO imports(supplier_id,status_id,import_date,actual_arrival,notes)
    VALUES(v_sup4,v_st_rcv,'2025-03-01','2025-04-05','Línea capilar premium India')
    RETURNING import_id INTO v_imp;

    FOR v_i IN 1..8 LOOP
        SELECT product_id INTO v_prod FROM products
        WHERE category_id=(SELECT category_id FROM categories WHERE category_name='Capilar')
        ORDER BY product_id OFFSET v_i-1 LIMIT 1;
        INSERT INTO import_details(import_id,product_id,quantity,unit_cost,currency_id,exchange_rate_id,subtotal)
        VALUES(v_imp,v_prod,350,9.00+v_i*0.4,v_cur_usd,v_er_usd,(350*(9.00+v_i*0.4)))
        RETURNING import_detail_id INTO v_det;
    END LOOP;
    INSERT INTO import_costs(import_id,cost_type_id,amount,currency_id,exchange_rate_id)
    VALUES(v_imp,v_ct_flete,700,v_cur_usd,v_er_usd),
          (v_imp,v_ct_seg,140,v_cur_usd,v_er_usd),
          (v_imp,v_ct_pto,90,v_cur_usd,v_er_usd);

    -- IMPORTACIÓN 5: Andean — Jabones y Aromaterapia
    INSERT INTO imports(supplier_id,status_id,import_date,actual_arrival,notes)
    VALUES(v_sup5,v_st_rcv,'2025-03-15','2025-04-20','Jabones artesanales y aromaterapia')
    RETURNING import_id INTO v_imp;

    FOR v_i IN 1..8 LOOP
        SELECT product_id INTO v_prod FROM products
        WHERE category_id IN (
            SELECT category_id FROM categories
            WHERE category_name IN ('Jabones Artesanales','Aromaterapia')
        )
        ORDER BY product_id OFFSET v_i-1 LIMIT 1;
        INSERT INTO import_details(import_id,product_id,quantity,unit_cost,currency_id,exchange_rate_id,subtotal)
        VALUES(v_imp,v_prod,600,4.50+v_i*0.2,v_cur_usd,v_er_usd,(600*(4.50+v_i*0.2)))
        RETURNING import_detail_id INTO v_det;
    END LOOP;
    INSERT INTO import_costs(import_id,cost_type_id,amount,currency_id,exchange_rate_id)
    VALUES(v_imp,v_ct_flete,600,v_cur_usd,v_er_usd),
          (v_imp,v_ct_seg,120,v_cur_usd,v_er_usd),
          (v_imp,v_ct_pto,80,v_cur_usd,v_er_usd);

    CALL sp_log('sp_insert_imports','5 importaciones con costos detallados','imports',NULL,'SUCCESS');
EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    CALL sp_log('sp_insert_imports','Error importaciones',NULL,NULL,'ERROR',v_err);
    RAISE;
END;$$;

-- =============================================================
-- SP 7 — Movimientos de inventario
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_insert_inventory()
LANGUAGE plpgsql AS $$
DECLARE
    v_wh INT; v_mt_entry INT;
    v_cur_usd INT; v_er_usd INT;
    v_prod INT;
    v_err TEXT;
BEGIN
    SELECT warehouse_id INTO v_wh FROM warehouses WHERE warehouse_name LIKE 'HUB-A%';
    SELECT movement_type_id INTO v_mt_entry FROM movement_types WHERE type_code='ENTRY';
    SELECT currency_id INTO v_cur_usd FROM currencies WHERE currency_code='USD';
    SELECT exchange_rate_id INTO v_er_usd FROM exchange_rates
        WHERE currency_id=v_cur_usd AND base_currency_id=v_cur_usd LIMIT 1;

    -- Registrar entrada de inventario para TODOS los productos
    FOR v_prod IN (
        SELECT product_id FROM products ORDER BY product_id
    ) LOOP
        INSERT INTO inventory_movements(
            warehouse_id, product_id, movement_type_id,
            quantity, unit_cost, currency_id, exchange_rate_id,
            reference_type, notes
        ) VALUES (
            v_wh, v_prod, v_mt_entry,
            500, 10.00, v_cur_usd, v_er_usd,
            'IMPORT', 'Entrada inicial importación Q1'
        );
    END LOOP;

    CALL sp_log('sp_insert_inventory','Movimientos de inventario registrados','inventory_movements',NULL,'SUCCESS');
EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    CALL sp_log('sp_insert_inventory','Error inventario',NULL,NULL,'ERROR',v_err);
    RAISE;
END;$$;

-- =============================================================
-- SP 8 — Permisos sanitarios por producto y país
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_insert_permits()
LANGUAGE plpgsql AS $$
DECLARE
    v_cur_usd INT; v_er_usd INT; v_st_active INT;
    v_pt_inv INT; v_pt_dig INT; v_pt_cof INT; v_pt_isp INT; v_pt_min INT;
    v_cid_col INT; v_cid_per INT; v_cid_mex INT; v_cid_chl INT; v_cid_cri INT;
    v_prod INT; v_counter INT := 0; v_err TEXT;
BEGIN
    SELECT currency_id INTO v_cur_usd FROM currencies WHERE currency_code='USD';
    SELECT exchange_rate_id INTO v_er_usd FROM exchange_rates WHERE currency_id=v_cur_usd AND base_currency_id=v_cur_usd ORDER BY rate_date DESC LIMIT 1;
    SELECT status_id INTO v_st_active FROM import_statuses WHERE status_code='ACTIVE';
    SELECT permit_type_id INTO v_pt_inv FROM permit_types WHERE permit_type_code='INVIMA';
    SELECT permit_type_id INTO v_pt_dig FROM permit_types WHERE permit_type_code='DIGEMID';
    SELECT permit_type_id INTO v_pt_cof FROM permit_types WHERE permit_type_code='COFEPRIS';
    SELECT permit_type_id INTO v_pt_isp FROM permit_types WHERE permit_type_code='ISP';
    SELECT permit_type_id INTO v_pt_min FROM permit_types WHERE permit_type_code='MINSA_CRI';
    SELECT country_id INTO v_cid_col FROM countries WHERE iso_code='COL';
    SELECT country_id INTO v_cid_per FROM countries WHERE iso_code='PER';
    SELECT country_id INTO v_cid_mex FROM countries WHERE iso_code='MEX';
    SELECT country_id INTO v_cid_chl FROM countries WHERE iso_code='CHL';
    SELECT country_id INTO v_cid_cri FROM countries WHERE iso_code='CRI';

    FOR v_prod IN (SELECT product_id FROM products ORDER BY product_id) LOOP
        INSERT INTO product_permits(product_id,destination_country_id,permit_type_id,permit_number,valid_from,valid_until,cost_amount,currency_id,exchange_rate_id,status_id)
        VALUES(v_prod,v_cid_col,v_pt_inv,CONCAT('INV-2025-',LPAD(v_prod::TEXT,4,'0')),'2025-01-01','2027-12-31',150+(v_prod%5)*20,v_cur_usd,v_er_usd,v_st_active) ON CONFLICT(product_id,destination_country_id,permit_type_id) DO NOTHING;
        INSERT INTO product_permits(product_id,destination_country_id,permit_type_id,permit_number,valid_from,valid_until,cost_amount,currency_id,exchange_rate_id,status_id)
        VALUES(v_prod,v_cid_per,v_pt_dig,CONCAT('DIG-2025-',LPAD(v_prod::TEXT,4,'0')),'2025-01-01','2027-12-31',120+(v_prod%4)*15,v_cur_usd,v_er_usd,v_st_active) ON CONFLICT(product_id,destination_country_id,permit_type_id) DO NOTHING;
        INSERT INTO product_permits(product_id,destination_country_id,permit_type_id,permit_number,valid_from,valid_until,cost_amount,currency_id,exchange_rate_id,status_id)
        VALUES(v_prod,v_cid_mex,v_pt_cof,CONCAT('COF-2025-',LPAD(v_prod::TEXT,4,'0')),'2025-01-01','2027-12-31',180+(v_prod%6)*25,v_cur_usd,v_er_usd,v_st_active) ON CONFLICT(product_id,destination_country_id,permit_type_id) DO NOTHING;
        INSERT INTO product_permits(product_id,destination_country_id,permit_type_id,permit_number,valid_from,valid_until,cost_amount,currency_id,exchange_rate_id,status_id)
        VALUES(v_prod,v_cid_chl,v_pt_isp,CONCAT('ISP-2025-',LPAD(v_prod::TEXT,4,'0')),'2025-01-01','2027-12-31',130+(v_prod%5)*18,v_cur_usd,v_er_usd,v_st_active) ON CONFLICT(product_id,destination_country_id,permit_type_id) DO NOTHING;
        INSERT INTO product_permits(product_id,destination_country_id,permit_type_id,permit_number,valid_from,valid_until,cost_amount,currency_id,exchange_rate_id,status_id)
        VALUES(v_prod,v_cid_cri,v_pt_min,CONCAT('MIN-2025-',LPAD(v_prod::TEXT,4,'0')),'2025-01-01','2027-12-31',100+(v_prod%4)*12,v_cur_usd,v_er_usd,v_st_active) ON CONFLICT(product_id,destination_country_id,permit_type_id) DO NOTHING;
        v_counter := v_counter + 1;
    END LOOP;
    CALL sp_log('sp_insert_permits',CONCAT(v_counter*5,' permisos en 5 países'),'product_permits',NULL,'SUCCESS');
EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    CALL sp_log('sp_insert_permits','Error permisos',NULL,NULL,'ERROR',v_err);
    RAISE;
END;$$;

-- =============================================================
-- SP 9 — Dispatch orders
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_insert_dispatch_orders()
LANGUAGE plpgsql AS $$
DECLARE
    v_cur_usd INT; v_er_usd INT; v_wh_disp INT; v_st_disp INT;
    v_cid_col INT; v_cid_per INT; v_cid_mex INT; v_cid_chl INT; v_cid_cri INT;
    v_prod INT; v_err TEXT;
BEGIN
    SELECT currency_id INTO v_cur_usd FROM currencies WHERE currency_code='USD';
    SELECT exchange_rate_id INTO v_er_usd FROM exchange_rates WHERE currency_id=v_cur_usd AND base_currency_id=v_cur_usd ORDER BY rate_date DESC LIMIT 1;
    SELECT warehouse_id INTO v_wh_disp FROM warehouses WHERE warehouse_name LIKE 'HUB-C%';
    SELECT status_id INTO v_st_disp FROM import_statuses WHERE status_code='RECEIVED';
    SELECT country_id INTO v_cid_col FROM countries WHERE iso_code='COL';
    SELECT country_id INTO v_cid_per FROM countries WHERE iso_code='PER';
    SELECT country_id INTO v_cid_mex FROM countries WHERE iso_code='MEX';
    SELECT country_id INTO v_cid_chl FROM countries WHERE iso_code='CHL';
    SELECT country_id INTO v_cid_cri FROM countries WHERE iso_code='CRI';

    -- Colombia (ref order_id 1-8 de MySQL)
    FOR v_prod IN (SELECT p.product_id FROM products p JOIN categories c ON p.category_id=c.category_id WHERE c.category_name='Aceites Esenciales' ORDER BY p.product_id LIMIT 5) LOOP
        INSERT INTO dispatch_orders(reference_order_id,product_id,quantity,warehouse_id,destination_country_id,brand_label,packaging_permit_ok,unit_cost,currency_id,exchange_rate_id,dispatch_date,status_id)
        VALUES(1,v_prod,50,v_wh_disp,v_cid_col,'Vivanatura/ZenAromatics',TRUE,12.50,v_cur_usd,v_er_usd,'2025-02-12 08:00:00',v_st_disp);
    END LOOP;
    -- Perú (ref order_id 9-14)
    FOR v_prod IN (SELECT p.product_id FROM products p JOIN categories c ON p.category_id=c.category_id WHERE c.category_name IN ('Aceites Esenciales','Alimentos Funcionales') ORDER BY p.product_id LIMIT 5) LOOP
        INSERT INTO dispatch_orders(reference_order_id,product_id,quantity,warehouse_id,destination_country_id,brand_label,packaging_permit_ok,unit_cost,currency_id,exchange_rate_id,dispatch_date,status_id)
        VALUES(9,v_prod,40,v_wh_disp,v_cid_per,'Vivanatura/EcoVital',TRUE,11.00,v_cur_usd,v_er_usd,'2025-03-07 08:00:00',v_st_disp);
    END LOOP;
    -- México (ref order_id 15-19)
    FOR v_prod IN (SELECT p.product_id FROM products p JOIN categories c ON p.category_id=c.category_id WHERE c.category_name IN ('Cosmética Dermatológica','Capilar') ORDER BY p.product_id LIMIT 5) LOOP
        INSERT INTO dispatch_orders(reference_order_id,product_id,quantity,warehouse_id,destination_country_id,brand_label,packaging_permit_ok,unit_cost,currency_id,exchange_rate_id,dispatch_date,status_id)
        VALUES(15,v_prod,60,v_wh_disp,v_cid_mex,'PuraDerma/HairElixir',TRUE,14.00,v_cur_usd,v_er_usd,'2025-03-17 08:00:00',v_st_disp);
    END LOOP;
    -- Chile (ref order_id 20-23)
    FOR v_prod IN (SELECT p.product_id FROM products p JOIN categories c ON p.category_id=c.category_id WHERE c.category_name IN ('Cosmética Dermatológica','Jabones Artesanales') ORDER BY p.product_id LIMIT 5) LOOP
        INSERT INTO dispatch_orders(reference_order_id,product_id,quantity,warehouse_id,destination_country_id,brand_label,packaging_permit_ok,unit_cost,currency_id,exchange_rate_id,dispatch_date,status_id)
        VALUES(20,v_prod,35,v_wh_disp,v_cid_chl,'PuraDerma/EcoVital',TRUE,10.50,v_cur_usd,v_er_usd,'2025-04-03 08:00:00',v_st_disp);
    END LOOP;
    -- Costa Rica (ref order_id 24-27)
    FOR v_prod IN (SELECT p.product_id FROM products p JOIN categories c ON p.category_id=c.category_id WHERE c.category_name IN ('Aromaterapia','Bebidas Naturales') ORDER BY p.product_id LIMIT 5) LOOP
        INSERT INTO dispatch_orders(reference_order_id,product_id,quantity,warehouse_id,destination_country_id,brand_label,packaging_permit_ok,unit_cost,currency_id,exchange_rate_id,dispatch_date,status_id)
        VALUES(24,v_prod,30,v_wh_disp,v_cid_cri,'ZenAromatics',TRUE,9.00,v_cur_usd,v_er_usd,'2025-04-12 08:00:00',v_st_disp);
    END LOOP;
    CALL sp_log('sp_insert_dispatch_orders','Despachos a 5 países','dispatch_orders',NULL,'SUCCESS');
EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    CALL sp_log('sp_insert_dispatch_orders','Error despachos',NULL,NULL,'ERROR',v_err);
    RAISE;
END;$$;

-- =============================================================
-- SP 8 — Permisos sanitarios por producto y país destino
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_insert_permits()
LANGUAGE plpgsql AS $$
DECLARE
    v_cur_usd INT; v_er_usd INT; v_st_active INT;
    v_pt_inv INT; v_pt_dig INT; v_pt_cof INT; v_pt_isp INT; v_pt_min INT;
    v_cid_col INT; v_cid_per INT; v_cid_mex INT; v_cid_chl INT; v_cid_cri INT;
    v_prod INT; v_counter INT := 0; v_err TEXT;
BEGIN
    SELECT currency_id INTO v_cur_usd FROM currencies WHERE currency_code='USD';
    SELECT exchange_rate_id INTO v_er_usd FROM exchange_rates WHERE currency_id=v_cur_usd AND base_currency_id=v_cur_usd ORDER BY rate_date DESC LIMIT 1;
    SELECT status_id INTO v_st_active FROM import_statuses WHERE status_code='ACTIVE';
    SELECT permit_type_id INTO v_pt_inv FROM permit_types WHERE permit_type_code='INVIMA';
    SELECT permit_type_id INTO v_pt_dig FROM permit_types WHERE permit_type_code='DIGEMID';
    SELECT permit_type_id INTO v_pt_cof FROM permit_types WHERE permit_type_code='COFEPRIS';
    SELECT permit_type_id INTO v_pt_isp FROM permit_types WHERE permit_type_code='ISP';
    SELECT permit_type_id INTO v_pt_min FROM permit_types WHERE permit_type_code='MINSA_CRI';
    SELECT country_id INTO v_cid_col FROM countries WHERE iso_code='COL';
    SELECT country_id INTO v_cid_per FROM countries WHERE iso_code='PER';
    SELECT country_id INTO v_cid_mex FROM countries WHERE iso_code='MEX';
    SELECT country_id INTO v_cid_chl FROM countries WHERE iso_code='CHL';
    SELECT country_id INTO v_cid_cri FROM countries WHERE iso_code='CRI';

    FOR v_prod IN (SELECT product_id FROM products ORDER BY product_id) LOOP
        INSERT INTO product_permits(product_id,destination_country_id,permit_type_id,permit_number,valid_from,valid_until,cost_amount,currency_id,exchange_rate_id,status_id)
        VALUES(v_prod,v_cid_col,v_pt_inv,CONCAT('INV-2025-',LPAD(v_prod::TEXT,4,'0')),'2025-01-01','2027-12-31',150+(v_prod%5)*20,v_cur_usd,v_er_usd,v_st_active) ON CONFLICT(product_id,destination_country_id,permit_type_id) DO NOTHING;
        INSERT INTO product_permits(product_id,destination_country_id,permit_type_id,permit_number,valid_from,valid_until,cost_amount,currency_id,exchange_rate_id,status_id)
        VALUES(v_prod,v_cid_per,v_pt_dig,CONCAT('DIG-2025-',LPAD(v_prod::TEXT,4,'0')),'2025-01-01','2027-12-31',120+(v_prod%4)*15,v_cur_usd,v_er_usd,v_st_active) ON CONFLICT(product_id,destination_country_id,permit_type_id) DO NOTHING;
        INSERT INTO product_permits(product_id,destination_country_id,permit_type_id,permit_number,valid_from,valid_until,cost_amount,currency_id,exchange_rate_id,status_id)
        VALUES(v_prod,v_cid_mex,v_pt_cof,CONCAT('COF-2025-',LPAD(v_prod::TEXT,4,'0')),'2025-01-01','2027-12-31',180+(v_prod%6)*25,v_cur_usd,v_er_usd,v_st_active) ON CONFLICT(product_id,destination_country_id,permit_type_id) DO NOTHING;
        INSERT INTO product_permits(product_id,destination_country_id,permit_type_id,permit_number,valid_from,valid_until,cost_amount,currency_id,exchange_rate_id,status_id)
        VALUES(v_prod,v_cid_chl,v_pt_isp,CONCAT('ISP-2025-',LPAD(v_prod::TEXT,4,'0')),'2025-01-01','2027-12-31',130+(v_prod%5)*18,v_cur_usd,v_er_usd,v_st_active) ON CONFLICT(product_id,destination_country_id,permit_type_id) DO NOTHING;
        INSERT INTO product_permits(product_id,destination_country_id,permit_type_id,permit_number,valid_from,valid_until,cost_amount,currency_id,exchange_rate_id,status_id)
        VALUES(v_prod,v_cid_cri,v_pt_min,CONCAT('MIN-2025-',LPAD(v_prod::TEXT,4,'0')),'2025-01-01','2027-12-31',100+(v_prod%4)*12,v_cur_usd,v_er_usd,v_st_active) ON CONFLICT(product_id,destination_country_id,permit_type_id) DO NOTHING;
        v_counter := v_counter + 1;
    END LOOP;
    CALL sp_log('sp_insert_permits',CONCAT(v_counter*5,' permisos en 5 países'),'product_permits',NULL,'SUCCESS');
EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    CALL sp_log('sp_insert_permits','Error permisos',NULL,NULL,'ERROR',v_err);
    RAISE;
END;$$;

-- =============================================================
-- SP 9 — Dispatch orders (HUB -> países destino)
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_insert_dispatch_orders()
LANGUAGE plpgsql AS $$
DECLARE
    v_cur_usd INT; v_er_usd INT; v_wh_disp INT; v_st_disp INT;
    v_cid_col INT; v_cid_per INT; v_cid_mex INT; v_cid_chl INT; v_cid_cri INT;
    v_prod INT; v_err TEXT;
BEGIN
    SELECT currency_id INTO v_cur_usd FROM currencies WHERE currency_code='USD';
    SELECT exchange_rate_id INTO v_er_usd FROM exchange_rates WHERE currency_id=v_cur_usd AND base_currency_id=v_cur_usd ORDER BY rate_date DESC LIMIT 1;
    SELECT warehouse_id INTO v_wh_disp FROM warehouses WHERE warehouse_name LIKE 'HUB-C%';
    SELECT status_id INTO v_st_disp FROM import_statuses WHERE status_code='DISPATCHED';
    SELECT country_id INTO v_cid_col FROM countries WHERE iso_code='COL';
    SELECT country_id INTO v_cid_per FROM countries WHERE iso_code='PER';
    SELECT country_id INTO v_cid_mex FROM countries WHERE iso_code='MEX';
    SELECT country_id INTO v_cid_chl FROM countries WHERE iso_code='CHL';
    SELECT country_id INTO v_cid_cri FROM countries WHERE iso_code='CRI';

    -- Colombia (ref order_id 1-8)
    FOR v_prod IN (SELECT p.product_id FROM products p JOIN categories c ON p.category_id=c.category_id WHERE c.category_name='Aceites Esenciales' ORDER BY p.product_id LIMIT 5) LOOP
        INSERT INTO dispatch_orders(reference_order_id,product_id,quantity,warehouse_id,destination_country_id,brand_label,packaging_permit_ok,unit_cost,currency_id,exchange_rate_id,dispatch_date,status_id)
        VALUES(1,v_prod,50,v_wh_disp,v_cid_col,'Vivanatura/ZenAromatics',TRUE,12.50,v_cur_usd,v_er_usd,'2025-02-12 08:00:00',v_st_disp);
    END LOOP;
    -- Perú (ref order_id 9-14)
    FOR v_prod IN (SELECT p.product_id FROM products p JOIN categories c ON p.category_id=c.category_id WHERE c.category_name IN ('Aceites Esenciales','Alimentos Funcionales') ORDER BY p.product_id LIMIT 5) LOOP
        INSERT INTO dispatch_orders(reference_order_id,product_id,quantity,warehouse_id,destination_country_id,brand_label,packaging_permit_ok,unit_cost,currency_id,exchange_rate_id,dispatch_date,status_id)
        VALUES(9,v_prod,40,v_wh_disp,v_cid_per,'Vivanatura/EcoVital',TRUE,11.00,v_cur_usd,v_er_usd,'2025-03-07 08:00:00',v_st_disp);
    END LOOP;
    -- México (ref order_id 15-19)
    FOR v_prod IN (SELECT p.product_id FROM products p JOIN categories c ON p.category_id=c.category_id WHERE c.category_name IN ('Cosmética Dermatológica','Capilar') ORDER BY p.product_id LIMIT 5) LOOP
        INSERT INTO dispatch_orders(reference_order_id,product_id,quantity,warehouse_id,destination_country_id,brand_label,packaging_permit_ok,unit_cost,currency_id,exchange_rate_id,dispatch_date,status_id)
        VALUES(15,v_prod,60,v_wh_disp,v_cid_mex,'PuraDerma/HairElixir',TRUE,14.00,v_cur_usd,v_er_usd,'2025-03-17 08:00:00',v_st_disp);
    END LOOP;
    -- Chile (ref order_id 20-23)
    FOR v_prod IN (SELECT p.product_id FROM products p JOIN categories c ON p.category_id=c.category_id WHERE c.category_name IN ('Cosmética Dermatológica','Jabones Artesanales') ORDER BY p.product_id LIMIT 5) LOOP
        INSERT INTO dispatch_orders(reference_order_id,product_id,quantity,warehouse_id,destination_country_id,brand_label,packaging_permit_ok,unit_cost,currency_id,exchange_rate_id,dispatch_date,status_id)
        VALUES(20,v_prod,35,v_wh_disp,v_cid_chl,'PuraDerma/EcoVital',TRUE,10.50,v_cur_usd,v_er_usd,'2025-04-03 08:00:00',v_st_disp);
    END LOOP;
    -- Costa Rica (ref order_id 24-27)
    FOR v_prod IN (SELECT p.product_id FROM products p JOIN categories c ON p.category_id=c.category_id WHERE c.category_name IN ('Aromaterapia','Bebidas Naturales') ORDER BY p.product_id LIMIT 5) LOOP
        INSERT INTO dispatch_orders(reference_order_id,product_id,quantity,warehouse_id,destination_country_id,brand_label,packaging_permit_ok,unit_cost,currency_id,exchange_rate_id,dispatch_date,status_id)
        VALUES(24,v_prod,30,v_wh_disp,v_cid_cri,'ZenAromatics',TRUE,9.00,v_cur_usd,v_er_usd,'2025-04-12 08:00:00',v_st_disp);
    END LOOP;
    CALL sp_log('sp_insert_dispatch_orders','Despachos a 5 países','dispatch_orders',NULL,'SUCCESS');
EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    CALL sp_log('sp_insert_dispatch_orders','Error despachos',NULL,NULL,'ERROR',v_err);
    RAISE;
END;$$;

-- =============================================================
-- ORQUESTADOR v3
-- =============================================================
CREATE OR REPLACE PROCEDURE sp_load_all_data()
LANGUAGE plpgsql AS $$
DECLARE v_err TEXT;
BEGIN
    RAISE NOTICE 'Iniciando carga Etheria Global v3...';
    CALL sp_insert_catalogs();
    CALL sp_insert_geography();
    CALL sp_insert_exchange_rates();
    CALL sp_insert_suppliers_warehouses();
    CALL sp_insert_products();
    CALL sp_insert_imports();
    CALL sp_insert_inventory();
    CALL sp_insert_permits();
    CALL sp_insert_dispatch_orders();
    CALL sp_log('sp_load_all_data','Carga completa Etheria Global v3',NULL,NULL,'SUCCESS');
    RAISE NOTICE 'Carga Etheria Global v3 completada.';
EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    CALL sp_log('sp_load_all_data','Error en carga',NULL,NULL,'ERROR',v_err);
    RAISE;
END;$$;

CALL sp_load_all_data();
