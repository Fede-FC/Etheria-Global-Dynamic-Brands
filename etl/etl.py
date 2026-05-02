import sys
import time
import pandas as pd
from sqlalchemy import create_engine, text
from sqlalchemy.exc import OperationalError
from datetime import datetime

PG_URL = "postgresql+psycopg2://etheria_user:etheria_password@etheria_global_db:5432/etheria_global_db"
MY_URL = "mysql+pymysql://dynamic_user:dynamic_password@dynamic_brands_db:3306/dynamic_brands_db"

def log(engine, sp_name, description, table=None, record_id=None, status="INFO", error=None):
    try:
        with engine.begin() as conn:
            conn.execute(text("""
                INSERT INTO process_log (sp_name, action_description, affected_table,
                                         affected_record_id, status, error_detail)
                VALUES (:sp, :desc, :tbl, :rid, :st, :err)
            """), {"sp": sp_name, "desc": description, "tbl": table,
                   "rid": record_id, "st": status, "err": error})
    except:
        pass

def wait_for_db(engine, db_name, retries=30, delay=2):
    print(f"Esperando a que {db_name} esté lista...")
    for i in range(retries):
        try:
            with engine.connect() as conn:
                conn.execute(text("SELECT 1"))
            print(f"  {db_name} lista!")
            return True
        except OperationalError:
            print(f"  Intento {i+1}/{retries}...")
            time.sleep(delay)
    raise Exception(f"No se pudo conectar a {db_name} después de {retries} intentos")

def run_etl():
    print("ETL Etheria Global <-> Dynamic Brands — Iniciando...")
    print("=" * 60)

    engine_pg = create_engine(PG_URL)
    engine_my = create_engine(MY_URL)

    wait_for_db(engine_pg, "Postgres")
    wait_for_db(engine_my, "MySQL")

    try:
        # ── LIMPIAR TABLAS ANALYTICS (idempotencia) ──
        with engine_pg.begin() as conn:
            conn.execute(text("""
                TRUNCATE TABLE
                    analytics.dw_fact_sales,
                    analytics.dw_dim_product,
                    analytics.dw_dim_brand,
                    analytics.dw_dim_country,
                    analytics.dw_dim_category,
                    analytics.dw_dim_time,
                    analytics.dw_dim_website
                RESTART IDENTITY CASCADE
            """))
        print("Tablas analytics limpiadas")

        # ── CREAR ESQUEMA ANALYTICS SI NO EXISTE ──
        with engine_pg.begin() as conn:
            conn.execute(text("CREATE SCHEMA IF NOT EXISTS analytics"))
        print("Esquema analytics verificado/creado")

        # ── EXTRACT: Dimensiones desde Postgres ──
        print("\nEXTRACT — Leyendo dimensiones desde Postgres...")

        df_products = pd.read_sql("""
            SELECT p.product_id, p.product_name, c.category_name, u.unit_code, p.enabled
            FROM products p
            JOIN categories c ON p.category_id = c.category_id
            JOIN measurement_units u ON p.unit_id = u.unit_id
        """, engine_pg)
        print(f"  Products: {len(df_products)} filas")

        df_countries_pg = pd.read_sql("""
            SELECT country_id, country_name, iso_code, region
            FROM countries WHERE enabled = TRUE
        """, engine_pg)
        print(f"  Countries PG: {len(df_countries_pg)} filas")

        df_categories = pd.read_sql("""
            SELECT category_id, category_name FROM categories
        """, engine_pg)
        print(f"  Categories: {len(df_categories)} filas")

        # ── EXTRACT: Dimensiones desde MySQL ──
        print("\nEXTRACT — Leyendo dimensiones desde MySQL...")

        df_brands = pd.read_sql("""
            SELECT b.brand_id, b.brand_name, b.ai_model_version as ai_model,
                   bf.focus_name as focus, NULL as description
            FROM Brands b
            LEFT JOIN Brand_focuses bf ON b.focus_id = bf.focus_id
            WHERE b.enabled = 1
        """, engine_my)
        print(f"  Brands: {len(df_brands)} filas")

        df_websites = pd.read_sql("""
            SELECT w.website_id, w.site_url as website_name, w.brand_id
            FROM Websites w
            WHERE w.enabled = 1
        """, engine_my)
        print(f"  Websites: {len(df_websites)} filas")

        df_countries_my = pd.read_sql("""
            SELECT country_id, country_name, iso_code, NULL as region
            FROM Countries WHERE enabled = 1
        """, engine_my)
        print(f"  Countries MY: {len(df_countries_my)} filas")

        # ── EXTRACT: Hechos (Ventas) desde MySQL ──
        print("\nEXTRACT — Leyendo hechos (ventas) desde MySQL...")

        df_orders = pd.read_sql("""
            SELECT
                o.order_id,
                oi.order_item_id,
                oi.website_product_id,
                pc.etheria_product_id,
                oi.quantity,
                oi.unit_price,
                oi.subtotal,
                o.total_amount_base,
                o.total_amount_local,
                o.currency_id,
                o.order_date as delivery_date,
                w.brand_id,
                w.website_id,
                c.country_id AS website_country_id
            FROM Orders o
            JOIN Order_items oi ON o.order_id = oi.order_id
            JOIN Website_products wp ON oi.website_product_id = wp.website_product_id
            JOIN Product_catalog pc ON wp.catalog_product_id = pc.catalog_product_id
            JOIN Websites w ON wp.website_id = w.website_id
            JOIN Countries c ON w.country_id = c.country_id
            WHERE o.enabled = 1
        """, engine_my)
        print(f"  Orders: {len(df_orders)} items")

        # ── TRANSFORM: Crear tabla de tiempo ──
        print("\nTRANSFORM — Procesando datos...")

        # Generar dim_time
        dates = pd.concat([
            pd.to_datetime(df_orders["delivery_date"], errors='coerce')
        ]).dropna().unique()

        df_time = pd.DataFrame({
            "date_key": [int(d.strftime("%Y%m%d")) for d in dates],
            "full_date": dates,
            "year": [d.year for d in dates],
            "quarter": [d.quarter for d in dates],
            "month": [d.month for d in dates],
            "week": [d.isocalendar()[1] for d in dates],
            "day": [d.day for d in dates],
            "day_of_week": [d.strftime("%A") for d in dates],
            "is_weekend": [d.weekday() >= 5 for d in dates]
        })
        print(f"  Dim Time: {len(df_time)} fechas únicas")

        # ── LOAD: Dimensiones en Analytics ──
        print("\nLOAD — Cargando dimensiones en analytics...")

        # Dim Product
        df_products_load = df_products.rename(columns={
            "product_id": "product_id",
            "product_name": "product_name",
            "category_name": "category_name",
            "unit_code": "unit_code",
            "enabled": "enabled"
        })[["product_id", "product_name", "category_name", "unit_code", "enabled"]]

        df_products_load.to_sql("dw_dim_product", engine_pg, schema="analytics",
                                if_exists="append", index=False, method="multi")
        print(f"  dw_dim_product: {len(df_products_load)} filas")

        # Dim Brand
        df_brands_load = df_brands.rename(columns={
            "brand_id": "brand_id",
            "brand_name": "brand_name",
            "description": "description",
            "focus": "focus",
            "ai_model": "ai_model"
        })[["brand_id", "brand_name", "description", "focus", "ai_model"]]

        df_brands_load.to_sql("dw_dim_brand", engine_pg, schema="analytics",
                               if_exists="append", index=False, method="multi")
        print(f"  dw_dim_brand: {len(df_brands_load)} filas")

        # Dim Country (combinar PG y MY)
        df_countries_all = pd.concat([
            df_countries_pg[["country_id", "country_name", "iso_code", "region"]],
            df_countries_my[["country_id", "country_name", "iso_code", "region"]]
        ]).drop_duplicates(subset=["country_id"])
        df_countries_all.to_sql("dw_dim_country", engine_pg, schema="analytics",
                                if_exists="append", index=False, method="multi")
        print(f"  dw_dim_country: {len(df_countries_all)} filas")

        # Dim Category
        df_categories.to_sql("dw_dim_category", engine_pg, schema="analytics",
                               if_exists="append", index=False, method="multi")
        print(f"  dw_dim_category: {len(df_categories)} filas")

        # Dim Website
        df_websites_load = df_websites.rename(columns={
            "website_id": "website_id",
            "website_url": "website_name",
            "brand_id": "brand_id"
        })[["website_id", "website_name", "brand_id"]]

        df_websites_load.to_sql("dw_dim_website", engine_pg, schema="analytics",
                                 if_exists="append", index=False, method="multi")
        print(f"  dw_dim_website: {len(df_websites_load)} filas")

        # Dim Time
        df_time.to_sql("dw_dim_time", engine_pg, schema="analytics",
                        if_exists="append", index=False, method="multi")
        print(f"  dw_dim_time: {len(df_time)} filas")

        # ── TRANSFORM: Fact Sales ──
        print("\nTRANSFORM — Calculando hechos de ventas...")

        # Obtener costos desde Postgres
        df_costs = pd.read_sql("""
            SELECT
                p.product_id,
                COALESCE(SUM(id.unit_cost * id.quantity), 0) AS total_import_cost,
                COALESCE(SUM(ic.amount), 0) AS total_logistics_cost
            FROM products p
            LEFT JOIN import_details id ON p.product_id = id.product_id
            LEFT JOIN import_costs ic ON id.import_id = ic.import_id
            WHERE p.enabled = TRUE
            GROUP BY p.product_id
        """, engine_pg)

        # Obtener category_id desde PostgreSQL products
        df_products_cat = pd.read_sql("""
            SELECT product_id, category_id FROM products
        """, engine_pg)
        
        # Join orders con products para obtener category_id
        df_orders = df_orders.merge(
            df_products_cat[["product_id", "category_id"]],
            left_on="etheria_product_id",
            right_on="product_id",
            how="left"
        ).drop(columns=["product_id"])  # Eliminar columna duplicada

        # Join orders con costos
        df_fact = df_orders.merge(
            df_costs[["product_id", "total_import_cost", "total_logistics_cost"]],
            left_on="etheria_product_id",
            right_on="product_id",
            how="left"
        ).fillna(0).drop(columns=["product_id"])

        # Calcular costos y métricas
        df_fact["shipping_cost"] = 0
        df_fact["total_cost"] = df_fact["total_import_cost"] + df_fact["total_logistics_cost"] + df_fact["shipping_cost"]
        df_fact["revenue"] = df_fact["subtotal"]
        df_fact["profit"] = df_fact["revenue"] - df_fact["total_cost"]
        df_fact["margin_percent"] = (df_fact["profit"] / df_fact["revenue"].replace(0, 1)) * 100
        # Renombrar para coincidir con el esquema de la tabla
        df_fact = df_fact.rename(columns={"total_import_cost": "import_cost"})

        # Obtener currency_code
        df_currency = pd.read_sql("SELECT currency_id, currency_code FROM Currencies", engine_my)
        df_fact = df_fact.merge(df_currency, on="currency_id", how="left")

        # Crear date_key
        df_fact["date_key"] = pd.to_datetime(df_fact["delivery_date"], errors='coerce').apply(
            lambda x: int(x.strftime("%Y%m%d")) if pd.notnull(x) else 0
        )

        # Preparar para carga
        df_fact_load = df_fact[[
            "order_id", "etheria_product_id", "brand_id", "website_id",
            "website_country_id", "category_id", "date_key",
            "quantity", "unit_price", "subtotal",
            "shipping_cost", "import_cost", "total_cost",
            "revenue", "profit", "margin_percent", "currency_code"
        ]].rename(columns={
            "etheria_product_id": "product_id",
            "website_country_id": "country_id",
            "subtotal": "total_amount"
        })

        # ── LOAD: Fact Sales ──
        print("\nLOAD — Cargando hechos en analytics.dw_fact_sales...")
        df_fact_load.to_sql("dw_fact_sales", engine_pg, schema="analytics",
                           if_exists="append", index=False, method="multi")
        print(f"  dw_fact_sales: {len(df_fact_load)} filas")

        # ── MANTENER ETL_PROFITABILITY_SUMMARY (original) ──
        print("\nLOAD — Cargando etl_profitability_summary...")

        base_currency = "USD"
        try:
            with engine_pg.connect() as conn:
                r = conn.execute(text("SELECT currency_code FROM currencies WHERE is_base = TRUE LIMIT 1"))
                row = r.fetchone()
                base_currency = row[0] if row else "USD"
        except:
            pass

        # Costos detallados
        q_costs = """
        SELECT
            p.product_id,
            p.product_name,
            cat.category_name,
            COALESCE(imp.total_cost_prod, 0) AS cost_product,
            COALESCE(log_c.total_logistics, 0) AS cost_logistics,
            COALESCE(tar.total_tariffs, 0) AS cost_tariffs,
            COALESCE(per.total_permits, 0) AS cost_permits,
            COALESCE(shp.total_shipping, 0) AS cost_shipping
        FROM products p
        JOIN categories cat ON p.category_id = cat.category_id
        LEFT JOIN (
            SELECT product_id, SUM(unit_cost * quantity) AS total_cost_prod
            FROM import_details GROUP BY product_id
        ) imp ON p.product_id = imp.product_id
        LEFT JOIN (
            SELECT id.product_id, SUM(ic.amount / NULLIF(sub.total_items, 0)) AS total_logistics
            FROM import_details id
            JOIN import_costs ic ON id.import_id = ic.import_id
            JOIN (SELECT import_id, COUNT(*) as total_items FROM import_details GROUP BY import_id) sub
              ON id.import_id = sub.import_id
            GROUP BY id.product_id
        ) log_c ON p.product_id = log_c.product_id
        LEFT JOIN (
            SELECT id.product_id, SUM(it.amount) AS total_tariffs
            FROM import_tariffs it
            JOIN import_details id ON it.import_detail_id = id.import_detail_id
            GROUP BY id.product_id
        ) tar ON p.product_id = tar.product_id
        LEFT JOIN (
            SELECT product_id, SUM(cost_amount) AS total_permits
            FROM product_permits GROUP BY product_id
        ) per ON p.product_id = per.product_id
        LEFT JOIN (
            SELECT product_id, SUM(unit_cost * quantity) AS total_shipping
            FROM dispatch_orders GROUP BY product_id
        ) shp ON p.product_id = shp.product_id
        WHERE p.enabled = TRUE
        """
        df_costs = pd.read_sql(q_costs, engine_pg)
        print(f"  Costos: {len(df_costs)} productos")

        q_sales = """
        SELECT
            pc.etheria_product_id,
            b.brand_name,
            w.site_url,
            c.country_name AS sale_country,
            cur.currency_code AS sale_currency_code,
            COUNT(DISTINCT o.order_id) AS total_orders,
            SUM(oi.quantity) AS total_units_sold,
            SUM(oi.subtotal) AS revenue_local,
            SUM(o.total_amount_base * (oi.subtotal / NULLIF(o.total_amount_local, 0))) AS revenue_base,
            COALESCE(SUM(sr.shipping_cost_base * (oi.subtotal / NULLIF(o.total_amount_local, 0))), 0) AS shipping_cost_base
        FROM Orders o
        JOIN Order_items oi ON o.order_id = oi.order_id
        JOIN Website_products wp ON oi.website_product_id = wp.website_product_id
        JOIN Product_catalog pc ON wp.catalog_product_id = pc.catalog_product_id
        JOIN Brands b ON pc.brand_id = b.brand_id
        JOIN Websites w ON wp.website_id = w.website_id
        JOIN Countries c ON w.country_id = c.country_id
        JOIN Currencies cur ON oi.currency_id = cur.currency_id
        LEFT JOIN Shipping_records sr ON o.order_id = sr.order_id
        WHERE o.enabled = 1
        GROUP BY pc.etheria_product_id, b.brand_name, w.site_url, c.country_name, cur.currency_code
        """
        df_sales = pd.read_sql(q_sales, engine_my)
        print(f"  Ventas: {len(df_sales)} combinaciones")

        df = pd.merge(df_sales, df_costs, left_on="etheria_product_id", right_on="product_id", how="left").fillna(0)

        total_u_prod = df.groupby("product_id")["total_units_sold"].transform("sum")
        share = df["total_units_sold"] / total_u_prod.replace(0, 1)

        df["cost_product_alloc"] = df["cost_product"] * share
        df["cost_logistics_alloc"] = df["cost_logistics"] * share
        df["cost_tariffs_alloc"] = df["cost_tariffs"] * share
        df["cost_permits_alloc"] = df["cost_permits"] * share
        df["cost_shipping_alloc"] = df["cost_shipping"] * share

        df["cost_total"] = (
            df["cost_product_alloc"] + df["cost_logistics_alloc"] +
            df["cost_tariffs_alloc"] + df["cost_permits_alloc"] +
            df["shipping_cost_base"] + df["cost_shipping_alloc"]
        )
        df["gross_margin"] = df["revenue_base"] - df["cost_total"]

        summary = df.groupby(["category_name", "brand_name", "site_url", "sale_country", "sale_currency_code"]).agg({
            "total_orders": "sum",
            "total_units_sold": "sum",
            "revenue_local": "sum",
            "revenue_base": "sum",
            "cost_product_alloc": "sum",
            "cost_logistics_alloc": "sum",
            "cost_tariffs_alloc": "sum",
            "cost_permits_alloc": "sum",
            "cost_shipping_alloc": "sum",
            "shipping_cost_base": "sum",
            "cost_total": "sum",
            "gross_margin": "sum"
        }).reset_index()

        summary["gross_margin_pct"] = (summary["gross_margin"] / summary["revenue_base"].replace(0, 1)) * 100
        summary["roi_pct"] = (summary["gross_margin"] / summary["cost_total"].replace(0, 1)) * 100
        summary["etl_run_at"] = pd.Timestamp.now()
        summary = summary.fillna(0)

        summary_out = pd.DataFrame({
            "category_name": summary["category_name"],
            "brand_name": summary["brand_name"],
            "site_url": summary["site_url"],
            "sale_country": summary["sale_country"],
            "sale_currency_code": summary["sale_currency_code"],
            "base_currency_code": base_currency,
            "total_orders": summary["total_orders"].astype(int),
            "total_units_sold": summary["total_units_sold"],
            "revenue_local": summary["revenue_local"],
            "revenue_base": summary["revenue_base"],
            "cost_product": summary["cost_product_alloc"],
            "cost_logistics": summary["cost_logistics_alloc"],
            "cost_tariffs": summary["cost_tariffs_alloc"],
            "cost_permits": summary["cost_permits_alloc"],
            "cost_shipping": summary["cost_shipping_alloc"] + summary["shipping_cost_base"],
            "cost_total": summary["cost_total"],
            "gross_margin": summary["gross_margin"],
            "gross_margin_pct": summary["gross_margin_pct"],
            "roi_pct": summary["roi_pct"],
            "etl_run_at": summary["etl_run_at"],
            "etl_period_from": "2025-01-01",
            "etl_period_to": "2025-12-31"
        })

        summary_out.to_sql("etl_profitability_summary", engine_pg, schema="analytics",
                           if_exists="replace", index=False, method="multi")
        print(f"  etl_profitability_summary: {len(summary_out)} filas")

        print("\n" + "=" * 60)
        print("ETL COMPLETADO EXITOSAMENTE")
        print("=" * 60)

        log(engine_pg, "etl_main", "ETL completado exitosamente", status="SUCCESS")

    except Exception as e:
        import traceback
        error_msg = traceback.format_exc()
        print(f"\nError ETL: {e}")
        print(error_msg)
        try:
            log(engine_pg, "etl_main", "Fallo crítico", status="ERROR", error=error_msg[:2000])
        except:
            pass
        sys.exit(1)

if __name__ == "__main__":
    run_etl()
