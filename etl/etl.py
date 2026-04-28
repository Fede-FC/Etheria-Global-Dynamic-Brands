"""
=================================================================
ETL — Integración Etheria Global (PostgreSQL) + Dynamic Brands (MySQL)
=================================================================
Estrategia: ETL con repositorio centralizado en PostgreSQL.

Flujo:
  1. EXTRACT  — Lee datos de ambas fuentes (PG + MySQL)
  2. TRANSFORM — Cruza, normaliza y calcula métricas de rentabilidad
  3. LOAD      — Inserta en el schema 'analytics' de PostgreSQL

El schema 'analytics' actúa como Data Warehouse ligero al que
el dashboard gerencial consulta directamente.

Tablas analíticas generadas:
  analytics.unified_orders     — Vista unificada de órdenes con costos y márgenes
  analytics.brand_performance  — Efectividad por marca/sitio IA
  analytics.category_margins   — Margen por categoría de producto
  analytics.country_profitability — Rentabilidad por país considerando envío y permisos

Ejecución:
  pip install psycopg2-binary pymysql pandas python-dotenv
  python etl.py
=================================================================
"""

import os
import logging
from datetime import datetime
from decimal import Decimal

import psycopg2
import psycopg2.extras
import pymysql
import pandas as pd
from dotenv import load_dotenv

load_dotenv()

# ─────────────────────────────────────────────────────────────
# Configuración de conexiones
# ─────────────────────────────────────────────────────────────
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

# ─────────────────────────────────────────────────────────────
# Logging
# ─────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler("etl.log"),
        logging.StreamHandler()
    ]
)
log = logging.getLogger("ETL")


# =================================================================
# CONEXIONES
# =================================================================

def get_pg_conn():
    return psycopg2.connect(**PG_CONFIG)


def get_mysql_conn():
    return pymysql.connect(**MYSQL_CONFIG)


# =================================================================
# EXTRACT — Lectura de fuentes
# =================================================================

def extract_etheria(pg_conn) -> dict:
    """
    Extrae todas las tablas necesarias de Etheria Global (PostgreSQL).
    Retorna un dict de DataFrames.
    """
    log.info("EXTRACT — Leyendo Etheria Global (PostgreSQL)...")
    tables = {}

    queries = {
        "dispatch_orders": """
            SELECT
                do2.dispatch_order_id,
                do2.reference_order_id,
                do2.product_id,
                do2.quantity             AS dispatched_qty,
                do2.unit_cost_usd,
                do2.quantity * do2.unit_cost_usd AS total_product_cost_usd,
                do2.destination_country_iso,
                do2.brand_label,
                do2.packaging_permit_ok,
                do2.dispatch_date,
                do2.status               AS dispatch_status,
                p.product_name,
                p.base_cost_usd,
                c2.category_name,
                co.country_name          AS origin_country,
                co.iso_code              AS origin_iso
            FROM Dispatch_orders do2
            JOIN Products p       ON p.product_id    = do2.product_id
            JOIN Categories c2    ON c2.category_id  = p.category_id
            LEFT JOIN Countries co ON co.country_id  = p.origin_country_id
            WHERE do2.is_deleted = FALSE
        """,

        "import_costs": """
            SELECT
                id2.product_id,
                p.product_name,
                p.base_cost_usd,
                c.category_name,
                SUM(id2.quantity)                                   AS total_imported_qty,
                SUM(id2.subtotal_usd)                               AS total_product_cost_usd,
                SUM(lc.shipping_cost_usd + lc.insurance_cost_usd
                    + lc.port_handling_usd + lc.other_costs_usd)    AS total_logistic_cost_usd,
                SUM(id2.subtotal_usd + lc.shipping_cost_usd
                    + lc.insurance_cost_usd + lc.port_handling_usd
                    + lc.other_costs_usd)                           AS total_landed_cost_usd,
                CASE WHEN SUM(id2.quantity) > 0
                    THEN SUM(id2.subtotal_usd + lc.shipping_cost_usd
                             + lc.insurance_cost_usd + lc.port_handling_usd
                             + lc.other_costs_usd) / SUM(id2.quantity)
                    ELSE 0
                END                                                  AS landed_cost_per_unit_usd
            FROM Import_details id2
            JOIN Imports i         ON i.import_id    = id2.import_id
            JOIN Products p        ON p.product_id   = id2.product_id
            JOIN Categories c      ON c.category_id  = p.category_id
            LEFT JOIN Logistic_costs lc ON lc.import_id = id2.import_id
            WHERE i.status != 'CANCELLED'
            GROUP BY id2.product_id, p.product_name, p.base_cost_usd, c.category_name
        """,

        "permits_cost": """
            SELECT
                product_id,
                destination_country_iso,
                SUM(permit_cost_usd) AS total_permit_cost_usd
            FROM Country_product_permits
            WHERE is_deleted = FALSE AND status = 'ACTIVE'
            GROUP BY product_id, destination_country_iso
        """,

        "exchange_rates": """
            SELECT DISTINCT ON (country_id)
                country_id,
                currency_code,
                rate_to_usd,
                rate_date
            FROM Exchange_rates
            ORDER BY country_id, rate_date DESC
        """,
    }

    with pg_conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        for name, sql in queries.items():
            cur.execute(sql)
            rows = cur.fetchall()
            tables[name] = pd.DataFrame([dict(r) for r in rows])
            log.info(f"  Etheria → {name}: {len(tables[name])} filas")

    return tables


def extract_dynamic(mysql_conn) -> dict:
    """
    Extrae todas las tablas necesarias de Dynamic Brands (MySQL).
    Retorna un dict de DataFrames.
    """
    log.info("EXTRACT — Leyendo Dynamic Brands (MySQL)...")
    tables = {}

    queries = {
        "orders": """
            SELECT
                o.order_id,
                o.etheria_dispatch_id,
                o.total_amount_local,
                o.total_amount_usd,
                o.exchange_rate_snapshot,
                o.status                    AS order_status,
                o.order_date,
                w.site_url,
                w.marketing_focus,
                b.brand_name,
                b.brand_focus,
                b.ai_model_version,
                cu.country_name             AS sale_country,
                cu.iso_code                 AS sale_country_iso,
                cu.currency_code,
                ct.tax_rate_percent
            FROM Orders o
            JOIN Websites w         ON w.website_id   = o.website_id
            JOIN Brands b           ON b.brand_id     = w.brand_id
            JOIN Countries cu       ON cu.country_id  = w.country_id
            LEFT JOIN Country_taxes ct ON ct.country_id = cu.country_id
            WHERE o.is_deleted = 0
        """,

        "order_items": """
            SELECT
                oi.order_id,
                oi.quantity,
                oi.unit_price_local,
                oi.subtotal_local,
                pc.etheria_product_id,
                pc.branded_name,
                pc.health_claims,
                b.brand_name
            FROM Order_items oi
            JOIN Website_products wp     ON wp.website_product_id = oi.website_product_id
            JOIN Product_catalog pc      ON pc.catalog_product_id = wp.catalog_product_id
            JOIN Brands b                ON b.brand_id            = pc.brand_id
            WHERE oi.is_deleted = 0
        """,

        "shipping": """
            SELECT
                sr.order_id,
                sr.shipping_cost_local,
                sr.shipping_cost_usd,
                sr.status               AS shipping_status,
                c.courier_name
            FROM Shipping_records sr
            JOIN Couriers c ON c.courier_id = sr.courier_id
            WHERE sr.is_deleted = 0
        """,

        "websites": """
            SELECT
                w.website_id,
                w.site_url,
                w.marketing_focus,
                w.status,
                w.launch_date,
                b.brand_name,
                b.brand_focus,
                b.ai_model_version,
                cu.country_name,
                cu.iso_code,
                cu.currency_code
            FROM Websites w
            JOIN Brands b     ON b.brand_id    = w.brand_id
            JOIN Countries cu ON cu.country_id = w.country_id
            WHERE w.is_deleted = 0
        """,
    }

    with mysql_conn.cursor() as cur:
        for name, sql in queries.items():
            cur.execute(sql)
            rows = cur.fetchall()
            tables[name] = pd.DataFrame(rows)
            log.info(f"  Dynamic → {name}: {len(tables[name])} filas")

    return tables


# =================================================================
# TRANSFORM — Cruce y cálculo de métricas
# =================================================================

def transform(etheria: dict, dynamic: dict) -> dict:
    """
    Cruza los datos de ambas fuentes y calcula las métricas
    que la gerencia necesita.
    """
    log.info("TRANSFORM — Cruzando datos y calculando métricas...")

    orders    = dynamic["orders"].copy()
    items     = dynamic["order_items"].copy()
    shipping  = dynamic["shipping"].copy()
    dispatch  = etheria["dispatch_orders"].copy()
    imp_costs = etheria["import_costs"].copy()
    permits   = etheria["permits_cost"].copy()

    # Convertir tipos numéricos
    for col in ["total_amount_usd", "exchange_rate_snapshot"]:
        orders[col] = pd.to_numeric(orders[col], errors="coerce")
    for col in ["shipping_cost_usd"]:
        shipping[col] = pd.to_numeric(shipping[col], errors="coerce")
    for col in ["unit_cost_usd", "total_product_cost_usd"]:
        dispatch[col] = pd.to_numeric(dispatch[col], errors="coerce")
    for col in ["landed_cost_per_unit_usd", "total_landed_cost_usd"]:
        imp_costs[col] = pd.to_numeric(imp_costs[col], errors="coerce")

    # ── 1. UNIFIED ORDERS ────────────────────────────────────────
    # Unir órdenes con ítems
    orders_items = orders.merge(items, on="order_id", how="left")

    # Unir con envíos
    orders_full = orders_items.merge(shipping, on="order_id", how="left")

    # Unir con despachos Etheria (clave de integración ETL)
    orders_full = orders_full.merge(
        dispatch[["dispatch_order_id", "reference_order_id", "product_id",
                  "unit_cost_usd", "category_name", "origin_country",
                  "destination_country_iso"]],
        left_on="etheria_dispatch_id",
        right_on="dispatch_order_id",
        how="left"
    )

    # Unir costo landed por producto
    orders_full = orders_full.merge(
        imp_costs[["product_id", "landed_cost_per_unit_usd"]],
        on="product_id",
        how="left"
    )

    # Unir costo de permisos por producto + país destino
    orders_full = orders_full.merge(
        permits.rename(columns={"destination_country_iso": "sale_country_iso"}),
        on=["product_id", "sale_country_iso"],
        how="left"
    )
    orders_full["total_permit_cost_usd"] = orders_full["total_permit_cost_usd"].fillna(0)

    # Calcular costo total real por unidad (landed + permiso prorrateado)
    orders_full["real_cost_per_unit_usd"] = (
        orders_full["landed_cost_per_unit_usd"].fillna(orders_full["unit_cost_usd"])
        + orders_full["total_permit_cost_usd"] / orders_full["quantity"].replace(0, 1)
    )

    # Revenue en USD (precio venta / tipo de cambio)
    orders_full["revenue_usd"] = (
        orders_full["subtotal_local"] / orders_full["exchange_rate_snapshot"]
    )

    # Costo total de la línea
    orders_full["total_cost_usd"] = (
        orders_full["real_cost_per_unit_usd"] * orders_full["quantity"]
        + orders_full["shipping_cost_usd"].fillna(0)
    )

    # Margen bruto
    orders_full["gross_margin_usd"]     = orders_full["revenue_usd"] - orders_full["total_cost_usd"]
    orders_full["gross_margin_pct"]     = (
        orders_full["gross_margin_usd"] / orders_full["revenue_usd"].replace(0, 1) * 100
    ).round(2)

    unified_orders = orders_full[[
        "order_id", "order_date", "order_status",
        "brand_name", "brand_focus", "ai_model_version",
        "site_url", "marketing_focus",
        "sale_country", "sale_country_iso", "currency_code",
        "etheria_product_id", "branded_name", "category_name",
        "quantity", "unit_price_local", "subtotal_local",
        "exchange_rate_snapshot",
        "revenue_usd", "unit_cost_usd", "landed_cost_per_unit_usd",
        "real_cost_per_unit_usd", "shipping_cost_usd",
        "total_permit_cost_usd", "total_cost_usd",
        "gross_margin_usd", "gross_margin_pct",
        "tax_rate_percent", "courier_name", "shipping_status",
    ]].copy()

    log.info(f"  unified_orders: {len(unified_orders)} filas")

    # ── 2. BRAND PERFORMANCE ─────────────────────────────────────
    brand_perf = unified_orders.groupby(
        ["brand_name", "brand_focus", "ai_model_version", "site_url",
         "sale_country", "sale_country_iso"]
    ).agg(
        total_orders        = ("order_id",         "nunique"),
        total_units_sold    = ("quantity",          "sum"),
        total_revenue_usd   = ("revenue_usd",       "sum"),
        total_cost_usd      = ("total_cost_usd",    "sum"),
        total_margin_usd    = ("gross_margin_usd",  "sum"),
        avg_margin_pct      = ("gross_margin_pct",  "mean"),
        avg_order_value_usd = ("revenue_usd",       "mean"),
    ).reset_index()

    brand_perf["avg_margin_pct"]      = brand_perf["avg_margin_pct"].round(2)
    brand_perf["avg_order_value_usd"] = brand_perf["avg_order_value_usd"].round(4)

    log.info(f"  brand_performance: {len(brand_perf)} filas")

    # ── 3. CATEGORY MARGINS ──────────────────────────────────────
    cat_margins = unified_orders.groupby("category_name").agg(
        total_orders        = ("order_id",                  "nunique"),
        total_units_sold    = ("quantity",                  "sum"),
        total_revenue_usd   = ("revenue_usd",               "sum"),
        avg_base_cost_usd   = ("unit_cost_usd",             "mean"),
        avg_landed_cost_usd = ("landed_cost_per_unit_usd",  "mean"),
        avg_real_cost_usd   = ("real_cost_per_unit_usd",    "mean"),
        total_cost_usd      = ("total_cost_usd",            "sum"),
        total_margin_usd    = ("gross_margin_usd",          "sum"),
        avg_margin_pct      = ("gross_margin_pct",          "mean"),
    ).reset_index()

    cat_margins["markup_x"] = (
        cat_margins["total_revenue_usd"] / cat_margins["total_cost_usd"].replace(0, 1)
    ).round(2)

    log.info(f"  category_margins: {len(cat_margins)} filas")

    # ── 4. COUNTRY PROFITABILITY ──────────────────────────────────
    country_profit = unified_orders.groupby(
        ["sale_country", "sale_country_iso", "currency_code", "tax_rate_percent"]
    ).agg(
        total_orders        = ("order_id",               "nunique"),
        total_units_sold    = ("quantity",               "sum"),
        total_revenue_usd   = ("revenue_usd",            "sum"),
        total_cost_usd      = ("total_cost_usd",         "sum"),
        total_margin_usd    = ("gross_margin_usd",       "sum"),
        avg_margin_pct      = ("gross_margin_pct",       "mean"),
        total_shipping_usd  = ("shipping_cost_usd",      "sum"),
        total_permit_usd    = ("total_permit_cost_usd",  "sum"),
    ).reset_index()

    country_profit["tax_impact_usd"] = (
        country_profit["total_revenue_usd"] * country_profit["tax_rate_percent"] / 100
    ).round(4)
    country_profit["net_margin_after_tax_usd"] = (
        country_profit["total_margin_usd"] - country_profit["tax_impact_usd"]
    ).round(4)
    country_profit["net_margin_pct"] = (
        country_profit["net_margin_after_tax_usd"]
        / country_profit["total_revenue_usd"].replace(0, 1) * 100
    ).round(2)

    log.info(f"  country_profitability: {len(country_profit)} filas")

    return {
        "unified_orders":       unified_orders,
        "brand_performance":    brand_perf,
        "category_margins":     cat_margins,
        "country_profitability": country_profit,
    }


# =================================================================
# LOAD — Escritura en schema analytics (PostgreSQL)
# =================================================================

def create_analytics_schema(pg_conn):
    """Crea el schema analytics y las tablas destino si no existen."""
    log.info("LOAD — Preparando schema analytics en PostgreSQL...")
    ddl = """
    CREATE SCHEMA IF NOT EXISTS analytics;

    DROP TABLE IF EXISTS analytics.unified_orders CASCADE;
    CREATE TABLE analytics.unified_orders (
        order_id                INT,
        order_date              TIMESTAMP,
        order_status            VARCHAR(30),
        brand_name              VARCHAR(150),
        brand_focus             VARCHAR(100),
        ai_model_version        VARCHAR(50),
        site_url                VARCHAR(500),
        marketing_focus         VARCHAR(200),
        sale_country            VARCHAR(100),
        sale_country_iso        CHAR(3),
        currency_code           CHAR(3),
        etheria_product_id      INT,
        branded_name            VARCHAR(150),
        category_name           VARCHAR(100),
        quantity                INT,
        unit_price_local        NUMERIC(14,2),
        subtotal_local          NUMERIC(14,2),
        exchange_rate_snapshot  NUMERIC(18,6),
        revenue_usd             NUMERIC(14,4),
        unit_cost_usd           NUMERIC(12,4),
        landed_cost_per_unit_usd NUMERIC(12,4),
        real_cost_per_unit_usd  NUMERIC(12,4),
        shipping_cost_usd       NUMERIC(12,2),
        total_permit_cost_usd   NUMERIC(12,2),
        total_cost_usd          NUMERIC(14,4),
        gross_margin_usd        NUMERIC(14,4),
        gross_margin_pct        NUMERIC(6,2),
        tax_rate_percent        NUMERIC(5,2),
        courier_name            VARCHAR(100),
        shipping_status         VARCHAR(30),
        etl_loaded_at           TIMESTAMP DEFAULT NOW()
    );

    DROP TABLE IF EXISTS analytics.brand_performance CASCADE;
    CREATE TABLE analytics.brand_performance (
        brand_name              VARCHAR(150),
        brand_focus             VARCHAR(100),
        ai_model_version        VARCHAR(50),
        site_url                VARCHAR(500),
        sale_country            VARCHAR(100),
        sale_country_iso        CHAR(3),
        total_orders            INT,
        total_units_sold        NUMERIC(14,3),
        total_revenue_usd       NUMERIC(14,4),
        total_cost_usd          NUMERIC(14,4),
        total_margin_usd        NUMERIC(14,4),
        avg_margin_pct          NUMERIC(6,2),
        avg_order_value_usd     NUMERIC(14,4),
        etl_loaded_at           TIMESTAMP DEFAULT NOW()
    );

    DROP TABLE IF EXISTS analytics.category_margins CASCADE;
    CREATE TABLE analytics.category_margins (
        category_name           VARCHAR(100),
        total_orders            INT,
        total_units_sold        NUMERIC(14,3),
        total_revenue_usd       NUMERIC(14,4),
        avg_base_cost_usd       NUMERIC(12,4),
        avg_landed_cost_usd     NUMERIC(12,4),
        avg_real_cost_usd       NUMERIC(12,4),
        total_cost_usd          NUMERIC(14,4),
        total_margin_usd        NUMERIC(14,4),
        avg_margin_pct          NUMERIC(6,2),
        markup_x                NUMERIC(6,2),
        etl_loaded_at           TIMESTAMP DEFAULT NOW()
    );

    DROP TABLE IF EXISTS analytics.country_profitability CASCADE;
    CREATE TABLE analytics.country_profitability (
        sale_country                VARCHAR(100),
        sale_country_iso            CHAR(3),
        currency_code               CHAR(3),
        tax_rate_percent            NUMERIC(5,2),
        total_orders                INT,
        total_units_sold            NUMERIC(14,3),
        total_revenue_usd           NUMERIC(14,4),
        total_cost_usd              NUMERIC(14,4),
        total_margin_usd            NUMERIC(14,4),
        avg_margin_pct              NUMERIC(6,2),
        total_shipping_usd          NUMERIC(12,4),
        total_permit_usd            NUMERIC(12,4),
        tax_impact_usd              NUMERIC(14,4),
        net_margin_after_tax_usd    NUMERIC(14,4),
        net_margin_pct              NUMERIC(6,2),
        etl_loaded_at               TIMESTAMP DEFAULT NOW()
    );
    """
    with pg_conn.cursor() as cur:
        cur.execute(ddl)
    pg_conn.commit()
    log.info("  Schema analytics y tablas creadas.")


def load_dataframe(pg_conn, df: pd.DataFrame, table: str):
    """Carga un DataFrame en una tabla analytics usando COPY para rendimiento."""
    if df.empty:
        log.warning(f"  DataFrame vacío, se omite carga de analytics.{table}")
        return

    df = df.where(pd.notnull(df), None)  # NaN → None (NULL en SQL)

    cols = ", ".join(df.columns)
    placeholders = ", ".join(["%s"] * len(df.columns))
    sql = f"INSERT INTO analytics.{table} ({cols}) VALUES ({placeholders})"

    rows = [tuple(r) for r in df.itertuples(index=False, name=None)]

    with pg_conn.cursor() as cur:
        psycopg2.extras.execute_batch(cur, sql, rows, page_size=500)
    pg_conn.commit()
    log.info(f"  Cargado analytics.{table}: {len(rows)} filas")


def load(pg_conn, datasets: dict):
    create_analytics_schema(pg_conn)
    for table_name, df in datasets.items():
        load_dataframe(pg_conn, df, table_name)


# =================================================================
# MAIN
# =================================================================

def run_etl():
    log.info("=" * 60)
    log.info("  INICIO ETL — %s", datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
    log.info("=" * 60)

    pg_conn    = None
    mysql_conn = None

    try:
        pg_conn    = get_pg_conn()
        mysql_conn = get_mysql_conn()

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
            pg_conn.rollback()
        raise

    finally:
        if mysql_conn:
            mysql_conn.close()
        if pg_conn:
            pg_conn.close()


if __name__ == "__main__":
    run_etl()
