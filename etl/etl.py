import sys
import time
import pandas as pd
from sqlalchemy import create_engine, text
from sqlalchemy.exc import OperationalError

PG_URL = "postgresql+psycopg2://etheria_user:etheria_password@etheria_global_db:5432/etheria_global_db"
MY_URL = "mysql+pymysql://dynamic_user:dynamic_password@dynamic_brands_db:3306/dynamic_brands_db"

def log(engine, sp_name, description, table=None, record_id=None, status="INFO", error=None):
    with engine.begin() as conn:
        conn.execute(text("""
            INSERT INTO process_log (sp_name, action_description, affected_table,
                                     affected_record_id, status, error_detail)
            VALUES (:sp, :desc, :tbl, :rid, :st, :err)
        """), {"sp": sp_name, "desc": description, "tbl": table,
               "rid": record_id, "st": status, "err": error})

def get_base_currency(engine):
    with engine.connect() as conn:
        r = conn.execute(text(
            "SELECT currency_code FROM currencies WHERE is_base = TRUE LIMIT 1"
        ))
        row = r.fetchone()
        return row[0] if row else "USD"

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

    engine_pg = create_engine(PG_URL)
    engine_my = create_engine(MY_URL)

    wait_for_db(engine_pg, "Postgres")
    wait_for_db(engine_my, "MySQL")

    try:
        base_currency = get_base_currency(engine_pg)
        log(engine_pg, "etl_main", f"ETL iniciado. Moneda base: {base_currency}", status="INFO")

        # ── QUERY 1: Costos desde Postgres ──
        q_costs = """
        SELECT
            p.product_id,
            p.product_name,
            cat.category_name,
            COALESCE(imp.total_cost_prod, 0) AS cost_product,
            COALESCE(log_c.total_logistics, 0) AS cost_logistics,
            COALESCE(tar.total_tariffs, 0)   AS cost_tariffs,
            COALESCE(per.total_permits, 0)   AS cost_permits,
            COALESCE(shp.total_shipping, 0)  AS cost_shipping
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
        log(engine_pg, "etl_costs", f"Extraídos {len(df_costs)} productos", "products", status="SUCCESS")
        print(f"  Costos: {len(df_costs)} productos cargados")

        # ── QUERY 2: Ventas desde MySQL ──
        q_sales = """
        SELECT
            pc.etheria_product_id,
            b.brand_name,
            w.site_url,
            c.country_name    AS sale_country,
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
        print(f"  Ventas: {len(df_sales)} combinaciones cargadas")

        # ── TRANSFORMACIÓN ──
        df = pd.merge(df_sales, df_costs, left_on="etheria_product_id", right_on="product_id", how="left")
        df = df.fillna(0)

        # Prorrateo de costos fijos según unidades vendidas
        total_u_prod = df.groupby("product_id")["total_units_sold"].transform("sum")
        share = df["total_units_sold"] / total_u_prod.replace(0, 1)

        df["cost_product_alloc"] = df["cost_product"] * share
        df["cost_logistics_alloc"] = df["cost_logistics"] * share
        df["cost_tariffs_alloc"] = df["cost_tariffs"] * share
        df["cost_permits_alloc"] = df["cost_permits"] * share
        df["cost_shipping_alloc"] = df["cost_shipping"] * share

        df["cost_total"] = (
            df["cost_product_alloc"] +
            df["cost_logistics_alloc"] +
            df["cost_tariffs_alloc"] +
            df["cost_permits_alloc"] +
            df["shipping_cost_base"] +
            df["cost_shipping_alloc"]
        )

        df["gross_margin"] = df["revenue_base"] - df["cost_total"]

        # Sumarización
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

        # Mapeo de columnas al schema de Postgres
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

        # ── CARGA ──
        summary_out.to_sql("etl_profitability_summary", engine_pg, if_exists="replace", index=False, method="multi")

        log(engine_pg, "etl_load", f"Carga exitosa: {len(summary_out)} filas", "etl_profitability_summary", status="SUCCESS")
        print(f"ETL completado — {len(summary_out)} filas en etl_profitability_summary.")

    except Exception as e:
        import traceback
        error_msg = traceback.format_exc()
        print(f"Error ETL: {e}")
        print(error_msg)
        try: log(engine_pg, "etl_main", "Fallo crítico", status="ERROR", error=error_msg[:2000])
        except: pass
        sys.exit(1)

if __name__ == "__main__":
    run_etl()
