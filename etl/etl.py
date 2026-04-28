"""
=================================================================
ETL — Integración Etheria Global (PostgreSQL) + Dynamic Brands (MySQL)
=================================================================
Estrategia: ETL con repositorio centralizado en PostgreSQL.

Flujo:
  1. EXTRACT  — Lee datos de ambas fuentes (PG + MySQL)
  2. TRANSFORM — Cruza, normaliza y calcula métricas de rentabilidad
  3. LOAD      — Inserta en el schema 'analytics' de PostgreSQL

Tablas analíticas generadas:
  analytics.unified_orders        — Vista unificada de órdenes con costos y márgenes
  analytics.brand_performance     — Efectividad por marca/sitio IA
  analytics.category_margins      — Margen por categoría de producto
  analytics.country_profitability — Rentabilidad por país
=================================================================
"""

import os
import time
import logging
from datetime import datetime

import psycopg2
import psycopg2.extras
import pymysql
import pymysql.cursors
import pandas as pd
from dotenv import load_dotenv

load_dotenv()

PG_CONFIG = {
    "host":     os.getenv("PG_HOST",     "localhost"),
    "port":     int(os.getenv("PG_PORT", "5432")),
    "dbname":   os.getenv("PG_DB",       "etheria_global_db"),
    "user":     os.getenv("PG_USER",     "etheria_user"),
    "password": os.getenv("PG_PASSWORD", "etheria_pass"),
}

MYSQL_CONFIG = {
    "host":     os.getenv("MYSQL_HOST",     "localhost"),
    "port":     int(os.getenv("MYSQL_PORT", "3306")),
    "db":       os.getenv("MYSQL_DB",       "dynamic_brands_db"),
    "user":     os.getenv("MYSQL_USER",     "dynamic_user"),
    "password": os.getenv("MYSQL_PASSWORD", "dynamic_pass"),
    "charset":  "utf8mb4",
    "cursorclass": pymysql.cursors.DictCursor,
}

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler()]
)
log = logging.getLogger("ETL")


# =================================================================
# CONEXIONES CON RETRY
# =================================================================

def get_pg_conn(retries=20, delay=6):
    for attempt in range(1, retries + 1):
        try:
            conn = psycopg2.connect(**PG_CONFIG)
            log.info(f"  PostgreSQL conectado (intento {attempt})")
            return conn
        except Exception as e:
            log.warning(f"  PG intento {attempt}/{retries}: {e}")
            if attempt < retries:
                time.sleep(delay)
    raise RuntimeError("No se pudo conectar a PostgreSQL.")


def get_mysql_conn(retries=20, delay=6):
    for attempt in range(1, retries + 1):
        try:
            conn = pymysql.connect(**MYSQL_CONFIG)
            log.info(f"  MySQL conectado (intento {attempt})")
            return conn
        except Exception as e:
            log.warning(f"  MySQL intento {attempt}/{retries}: {e}")
            if attempt < retries:
                time.sleep(delay)
    raise RuntimeError("No se pudo conectar a MySQL.")


def wait_for_data(pg_conn, mysql_conn, retries=25, delay=8):
    """Espera a que los scripts de inicialización hayan cargado datos."""
    log.info("  Verificando datos en ambas DBs...")
    for attempt in range(1, retries + 1):
        try:
            with pg_conn.cursor() as cur:
                cur.execute("SELECT COUNT(*) FROM products")
                pg_count = cur.fetchone()[0]

            with mysql_conn.cursor() as cur:
                cur.execute("SELECT COUNT(*) FROM orders")
                row = cur.fetchone()
                mysql_count = row["COUNT(*)"] if isinstance(row, dict) else row[0]

            log.info(f"  PG products={pg_count}, MySQL orders={mysql_count}")
            if pg_count > 0 and mysql_count > 0:
                log.info("  Datos listos.")
                return
        except Exception as e:
            log.warning(f"  Espera datos intento {attempt}/{retries}: {e}")
            try:
                pg_conn.rollback()
            except Exception:
                pass

        log.info(f"  Esperando {delay}s...")
        time.sleep(delay)

    log.warning("  Se agotó la espera. Continuando de todas formas...")


# =================================================================
# EXTRACT
# =================================================================

def pg_query(pg_conn, name, sql):
    try:
        with pg_conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(sql)
            rows = cur.fetchall()
        df = pd.DataFrame([dict(r) for r in rows])
        log.info(f"  Etheria -> {name}: {len(df)} filas")
        return df
    except Exception as e:
        log.warning(f"  Etheria -> {name} falló: {e}")
        try:
            pg_conn.rollback()
        except Exception:
            pass
        return pd.DataFrame()


def mysql_query(mysql_conn, name, sql):
    try:
        with mysql_conn.cursor() as cur:
            cur.execute(sql)
            rows = cur.fetchall()
        df = pd.DataFrame(rows)
        log.info(f"  Dynamic -> {name}: {len(df)} filas")
        return df
    except Exception as e:
        log.warning(f"  Dynamic -> {name} falló: {e}")
        return pd.DataFrame()


def extract_etheria(pg_conn):
    log.info("EXTRACT — Etheria Global (PostgreSQL)...")
    return {
        "dispatch_orders": pg_query(pg_conn, "dispatch_orders", """
            SELECT do2.dispatch_order_id, do2.reference_order_id, do2.product_id,
                   do2.quantity AS dispatched_qty, do2.unit_cost_usd,
                   do2.quantity * do2.unit_cost_usd AS total_product_cost_usd,
                   do2.destination_country_iso, do2.brand_label,
                   do2.packaging_permit_ok, do2.dispatch_date,
                   do2.status AS dispatch_status,
                   p.product_name, p.base_cost_usd, c2.category_name,
                   co.country_name AS origin_country, co.iso_code AS origin_iso
            FROM Dispatch_orders do2
            JOIN Products p       ON p.product_id   = do2.product_id
            JOIN Categories c2    ON c2.category_id = p.category_id
            LEFT JOIN Countries co ON co.country_id = p.origin_country_id
            WHERE do2.is_deleted = FALSE
        """),
        "import_costs": pg_query(pg_conn, "import_costs", """
            SELECT id2.product_id, p.product_name, p.base_cost_usd, c.category_name,
                   SUM(id2.quantity) AS total_imported_qty,
                   SUM(id2.subtotal_usd) AS total_product_cost_usd,
                   SUM(lc.shipping_cost_usd + lc.insurance_cost_usd
                       + lc.port_handling_usd + lc.other_costs_usd) AS total_logistic_cost_usd,
                   SUM(id2.subtotal_usd + lc.shipping_cost_usd + lc.insurance_cost_usd
                       + lc.port_handling_usd + lc.other_costs_usd) AS total_landed_cost_usd,
                   CASE WHEN SUM(id2.quantity) > 0
                       THEN SUM(id2.subtotal_usd + lc.shipping_cost_usd + lc.insurance_cost_usd
                                + lc.port_handling_usd + lc.other_costs_usd) / SUM(id2.quantity)
                       ELSE 0 END AS landed_cost_per_unit_usd
            FROM Import_details id2
            JOIN Imports i        ON i.import_id   = id2.import_id
            JOIN Products p       ON p.product_id  = id2.product_id
            JOIN Categories c     ON c.category_id = p.category_id
            LEFT JOIN Logistic_costs lc ON lc.import_id = id2.import_id
            WHERE i.status != 'CANCELLED'
            GROUP BY id2.product_id, p.product_name, p.base_cost_usd, c.category_name
        """),
        "permits_cost": pg_query(pg_conn, "permits_cost", """
            SELECT product_id, destination_country_iso,
                   SUM(permit_cost_usd) AS total_permit_cost_usd
            FROM Country_product_permits
            WHERE is_deleted = FALSE AND status = 'ACTIVE'
            GROUP BY product_id, destination_country_iso
        """),
        "exchange_rates": pg_query(pg_conn, "exchange_rates", """
            SELECT DISTINCT ON (country_id)
                   country_id, currency_code, rate_to_usd, rate_date
            FROM Exchange_rates
            ORDER BY country_id, rate_date DESC
        """),
    }


def extract_dynamic(mysql_conn):
    log.info("EXTRACT — Dynamic Brands (MySQL)...")
    return {
        "orders": mysql_query(mysql_conn, "orders", """
            SELECT o.order_id, o.etheria_dispatch_id, o.total_amount_local,
                   o.total_amount_usd, o.exchange_rate_snapshot,
                   o.status AS order_status, o.order_date,
                   w.site_url, w.marketing_focus,
                   b.brand_name, b.brand_focus, b.ai_model_version,
                   cu.country_name AS sale_country,
                   cu.iso_code AS sale_country_iso, cu.currency_code,
                   ct.tax_rate_percent
            FROM Orders o
            JOIN Websites w    ON w.website_id  = o.website_id
            JOIN Brands b      ON b.brand_id    = w.brand_id
            JOIN Countries cu  ON cu.country_id = w.country_id
            LEFT JOIN Country_taxes ct ON ct.country_id = cu.country_id
            WHERE o.is_deleted = 0
        """),
        "order_items": mysql_query(mysql_conn, "order_items", """
            SELECT oi.order_id, oi.quantity, oi.unit_price_local, oi.subtotal_local,
                   pc.etheria_product_id, pc.branded_name, pc.health_claims, b.brand_name
            FROM Order_items oi
            JOIN Website_products wp ON wp.website_product_id = oi.website_product_id
            JOIN Product_catalog pc  ON pc.catalog_product_id = wp.catalog_product_id
            JOIN Brands b            ON b.brand_id            = pc.brand_id
            WHERE oi.is_deleted = 0
        """),
        "shipping": mysql_query(mysql_conn, "shipping", """
            SELECT sr.order_id, sr.shipping_cost_local, sr.shipping_cost_usd,
                   sr.status AS shipping_status, c.courier_name
            FROM Shipping_records sr
            JOIN Couriers c ON c.courier_id = sr.courier_id
            WHERE sr.is_deleted = 0
        """),
        "websites": mysql_query(mysql_conn, "websites", """
            SELECT w.website_id, w.site_url, w.marketing_focus, w.status, w.launch_date,
                   b.brand_name, b.brand_focus, b.ai_model_version,
                   cu.country_name, cu.iso_code, cu.currency_code
            FROM Websites w
            JOIN Brands b     ON b.brand_id    = w.brand_id
            JOIN Countries cu ON cu.country_id = w.country_id
            WHERE w.is_deleted = 0
        """),
    }


# =================================================================
# TRANSFORM
# =================================================================

def to_num(df, cols):
    for col in cols:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce")


def transform(etheria, dynamic):
    log.info("TRANSFORM — Cruzando datos...")

    orders    = dynamic.get("orders",      pd.DataFrame()).copy()
    items     = dynamic.get("order_items", pd.DataFrame()).copy()
    shipping  = dynamic.get("shipping",    pd.DataFrame()).copy()
    dispatch  = etheria.get("dispatch_orders", pd.DataFrame()).copy()
    imp_costs = etheria.get("import_costs",    pd.DataFrame()).copy()
    permits   = etheria.get("permits_cost",    pd.DataFrame()).copy()

    if orders.empty:
        log.warning("  Sin órdenes. Tablas analíticas estarán vacías.")
        return {k: pd.DataFrame() for k in
                ["unified_orders", "brand_performance", "category_margins", "country_profitability"]}

    to_num(orders,    ["total_amount_usd", "exchange_rate_snapshot", "tax_rate_percent"])
    to_num(shipping,  ["shipping_cost_usd", "shipping_cost_local"])
    to_num(dispatch,  ["unit_cost_usd", "total_product_cost_usd"])
    to_num(imp_costs, ["landed_cost_per_unit_usd", "total_landed_cost_usd"])
    to_num(items,     ["quantity", "unit_price_local", "subtotal_local"])

    # Merge pipeline
    df = orders.copy()
    if not items.empty:
        df = df.merge(items, on="order_id", how="left")
    if not shipping.empty:
        df = df.merge(shipping, on="order_id", how="left")

    if not dispatch.empty and "dispatch_order_id" in dispatch.columns:
        d_cols = [c for c in ["dispatch_order_id", "product_id", "unit_cost_usd",
                               "category_name", "origin_country", "destination_country_iso"]
                  if c in dispatch.columns]
        df = df.merge(dispatch[d_cols], left_on="etheria_dispatch_id",
                      right_on="dispatch_order_id", how="left")

    if not imp_costs.empty and "product_id" in imp_costs.columns:
        df = df.merge(imp_costs[["product_id", "landed_cost_per_unit_usd"]],
                      on="product_id", how="left")

    if not permits.empty and "product_id" in permits.columns and "sale_country_iso" in df.columns:
        df = df.merge(
            permits.rename(columns={"destination_country_iso": "sale_country_iso"}),
            on=["product_id", "sale_country_iso"], how="left"
        )

    # Garantizar columnas numéricas
    for col in ["unit_cost_usd", "landed_cost_per_unit_usd", "shipping_cost_usd",
                "quantity", "subtotal_local", "exchange_rate_snapshot",
                "total_permit_cost_usd", "tax_rate_percent"]:
        if col not in df.columns:
            df[col] = 0.0
        df[col] = pd.to_numeric(df[col], errors="coerce").fillna(0)

    df["exchange_rate_snapshot"] = df["exchange_rate_snapshot"].replace(0, 1)

    df["real_cost_per_unit_usd"] = (
        df["landed_cost_per_unit_usd"].fillna(df["unit_cost_usd"])
        + df["total_permit_cost_usd"] / df["quantity"].replace(0, 1)
    )
    df["revenue_usd"]       = df["subtotal_local"] / df["exchange_rate_snapshot"]
    df["total_cost_usd"]    = df["real_cost_per_unit_usd"] * df["quantity"] + df["shipping_cost_usd"]
    df["gross_margin_usd"]  = df["revenue_usd"] - df["total_cost_usd"]
    df["gross_margin_pct"]  = (df["gross_margin_usd"] / df["revenue_usd"].replace(0, 1) * 100).round(2)

    desired = ["order_id","order_date","order_status","brand_name","brand_focus",
               "ai_model_version","site_url","marketing_focus","sale_country",
               "sale_country_iso","currency_code","etheria_product_id","branded_name",
               "category_name","quantity","unit_price_local","subtotal_local",
               "exchange_rate_snapshot","revenue_usd","unit_cost_usd",
               "landed_cost_per_unit_usd","real_cost_per_unit_usd","shipping_cost_usd",
               "total_permit_cost_usd","total_cost_usd","gross_margin_usd",
               "gross_margin_pct","tax_rate_percent","courier_name","shipping_status"]
    unified_orders = df[[c for c in desired if c in df.columns]].copy()
    log.info(f"  unified_orders: {len(unified_orders)} filas")

    # Brand performance
    g_cols = [c for c in ["brand_name","brand_focus","ai_model_version","site_url",
                           "sale_country","sale_country_iso"] if c in unified_orders.columns]
    brand_perf = unified_orders.groupby(g_cols).agg(
        total_orders=("order_id","nunique"), total_units_sold=("quantity","sum"),
        total_revenue_usd=("revenue_usd","sum"), total_cost_usd=("total_cost_usd","sum"),
        total_margin_usd=("gross_margin_usd","sum"), avg_margin_pct=("gross_margin_pct","mean"),
        avg_order_value_usd=("revenue_usd","mean")
    ).reset_index() if g_cols else pd.DataFrame()
    log.info(f"  brand_performance: {len(brand_perf)} filas")

    # Category margins
    cat_margins = pd.DataFrame()
    if "category_name" in unified_orders.columns:
        cat_margins = unified_orders.groupby("category_name").agg(
            total_orders=("order_id","nunique"), total_units_sold=("quantity","sum"),
            total_revenue_usd=("revenue_usd","sum"), avg_base_cost_usd=("unit_cost_usd","mean"),
            avg_landed_cost_usd=("landed_cost_per_unit_usd","mean"),
            avg_real_cost_usd=("real_cost_per_unit_usd","mean"),
            total_cost_usd=("total_cost_usd","sum"), total_margin_usd=("gross_margin_usd","sum"),
            avg_margin_pct=("gross_margin_pct","mean")
        ).reset_index()
        cat_margins["markup_x"] = (cat_margins["total_revenue_usd"] /
                                   cat_margins["total_cost_usd"].replace(0,1)).round(2)
    log.info(f"  category_margins: {len(cat_margins)} filas")

    # Country profitability
    cp_cols = [c for c in ["sale_country","sale_country_iso","currency_code","tax_rate_percent"]
               if c in unified_orders.columns]
    country_profit = pd.DataFrame()
    if cp_cols:
        country_profit = unified_orders.groupby(cp_cols).agg(
            total_orders=("order_id","nunique"), total_units_sold=("quantity","sum"),
            total_revenue_usd=("revenue_usd","sum"), total_cost_usd=("total_cost_usd","sum"),
            total_margin_usd=("gross_margin_usd","sum"), avg_margin_pct=("gross_margin_pct","mean"),
            total_shipping_usd=("shipping_cost_usd","sum"),
            total_permit_usd=("total_permit_cost_usd","sum")
        ).reset_index()
        country_profit["tax_rate_percent"] = pd.to_numeric(
            country_profit.get("tax_rate_percent", 0), errors="coerce").fillna(0)
        country_profit["tax_impact_usd"] = (
            country_profit["total_revenue_usd"] * country_profit["tax_rate_percent"] / 100).round(4)
        country_profit["net_margin_after_tax_usd"] = (
            country_profit["total_margin_usd"] - country_profit["tax_impact_usd"]).round(4)
        country_profit["net_margin_pct"] = (
            country_profit["net_margin_after_tax_usd"] /
            country_profit["total_revenue_usd"].replace(0,1) * 100).round(2)
    log.info(f"  country_profitability: {len(country_profit)} filas")

    return {"unified_orders": unified_orders, "brand_performance": brand_perf,
            "category_margins": cat_margins, "country_profitability": country_profit}


# =================================================================
# LOAD
# =================================================================

def create_analytics_schema(pg_conn):
    log.info("LOAD — Creando schema analytics...")
    ddl = """
    CREATE SCHEMA IF NOT EXISTS analytics;

    DROP TABLE IF EXISTS analytics.unified_orders CASCADE;
    CREATE TABLE analytics.unified_orders (
        order_id INT, order_date TIMESTAMP, order_status VARCHAR(30),
        brand_name VARCHAR(150), brand_focus VARCHAR(100), ai_model_version VARCHAR(50),
        site_url VARCHAR(500), marketing_focus VARCHAR(200),
        sale_country VARCHAR(100), sale_country_iso CHAR(3), currency_code CHAR(3),
        etheria_product_id INT, branded_name VARCHAR(150), category_name VARCHAR(100),
        quantity INT, unit_price_local NUMERIC(14,2), subtotal_local NUMERIC(14,2),
        exchange_rate_snapshot NUMERIC(18,6), revenue_usd NUMERIC(14,4),
        unit_cost_usd NUMERIC(12,4), landed_cost_per_unit_usd NUMERIC(12,4),
        real_cost_per_unit_usd NUMERIC(12,4), shipping_cost_usd NUMERIC(12,2),
        total_permit_cost_usd NUMERIC(12,2), total_cost_usd NUMERIC(14,4),
        gross_margin_usd NUMERIC(14,4), gross_margin_pct NUMERIC(6,2),
        tax_rate_percent NUMERIC(5,2), courier_name VARCHAR(100),
        shipping_status VARCHAR(30), etl_loaded_at TIMESTAMP DEFAULT NOW()
    );

    DROP TABLE IF EXISTS analytics.brand_performance CASCADE;
    CREATE TABLE analytics.brand_performance (
        brand_name VARCHAR(150), brand_focus VARCHAR(100), ai_model_version VARCHAR(50),
        site_url VARCHAR(500), sale_country VARCHAR(100), sale_country_iso CHAR(3),
        total_orders INT, total_units_sold NUMERIC(14,3),
        total_revenue_usd NUMERIC(14,4), total_cost_usd NUMERIC(14,4),
        total_margin_usd NUMERIC(14,4), avg_margin_pct NUMERIC(6,2),
        avg_order_value_usd NUMERIC(14,4), etl_loaded_at TIMESTAMP DEFAULT NOW()
    );

    DROP TABLE IF EXISTS analytics.category_margins CASCADE;
    CREATE TABLE analytics.category_margins (
        category_name VARCHAR(100), total_orders INT, total_units_sold NUMERIC(14,3),
        total_revenue_usd NUMERIC(14,4), avg_base_cost_usd NUMERIC(12,4),
        avg_landed_cost_usd NUMERIC(12,4), avg_real_cost_usd NUMERIC(12,4),
        total_cost_usd NUMERIC(14,4), total_margin_usd NUMERIC(14,4),
        avg_margin_pct NUMERIC(6,2), markup_x NUMERIC(6,2),
        etl_loaded_at TIMESTAMP DEFAULT NOW()
    );

    DROP TABLE IF EXISTS analytics.country_profitability CASCADE;
    CREATE TABLE analytics.country_profitability (
        sale_country VARCHAR(100), sale_country_iso CHAR(3), currency_code CHAR(3),
        tax_rate_percent NUMERIC(5,2), total_orders INT, total_units_sold NUMERIC(14,3),
        total_revenue_usd NUMERIC(14,4), total_cost_usd NUMERIC(14,4),
        total_margin_usd NUMERIC(14,4), avg_margin_pct NUMERIC(6,2),
        total_shipping_usd NUMERIC(12,4), total_permit_usd NUMERIC(12,4),
        tax_impact_usd NUMERIC(14,4), net_margin_after_tax_usd NUMERIC(14,4),
        net_margin_pct NUMERIC(6,2), etl_loaded_at TIMESTAMP DEFAULT NOW()
    );
    """
    with pg_conn.cursor() as cur:
        cur.execute(ddl)
    pg_conn.commit()
    log.info("  Schema analytics listo.")


def load_dataframe(pg_conn, df, table):
    if df.empty:
        log.warning(f"  Omitiendo analytics.{table} (vacío)")
        return
    df = df.where(pd.notnull(df), None)
    cols = ", ".join(df.columns)
    placeholders = ", ".join(["%s"] * len(df.columns))
    sql = f"INSERT INTO analytics.{table} ({cols}) VALUES ({placeholders})"
    rows = [tuple(r) for r in df.itertuples(index=False, name=None)]
    with pg_conn.cursor() as cur:
        psycopg2.extras.execute_batch(cur, sql, rows, page_size=500)
    pg_conn.commit()
    log.info(f"  Cargado analytics.{table}: {len(rows)} filas")


def load(pg_conn, datasets):
    create_analytics_schema(pg_conn)
    for name, df in datasets.items():
        load_dataframe(pg_conn, df, name)


# =================================================================
# MAIN
# =================================================================

def run_etl():
    log.info("=" * 60)
    log.info("  INICIO ETL — %s", datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
    log.info("=" * 60)

    pg_conn = mysql_conn = None
    try:
        pg_conn    = get_pg_conn()
        mysql_conn = get_mysql_conn()
        wait_for_data(pg_conn, mysql_conn)
        etheria_data = extract_etheria(pg_conn)
        dynamic_data = extract_dynamic(mysql_conn)
        datasets     = transform(etheria_data, dynamic_data)
        load(pg_conn, datasets)
        log.info("=" * 60)
        log.info("  ETL COMPLETADO EXITOSAMENTE")
        log.info("=" * 60)
    except Exception as e:
        log.error("ETL FALLÓ: %s", str(e), exc_info=True)
        if pg_conn:
            try: pg_conn.rollback()
            except Exception: pass
        raise
    finally:
        for c in [mysql_conn, pg_conn]:
            if c:
                try: c.close()
                except Exception: pass


if __name__ == "__main__":
    run_etl()
