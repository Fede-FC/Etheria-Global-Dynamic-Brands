"""
=================================================================
API Backend — Dashboard Gerencial
=================================================================
Servidor Flask que expone los datos del schema analytics
al dashboard HTML.

Ejecución:
  pip install flask flask-cors psycopg2-binary python-dotenv
  python dashboard_api.py
=================================================================
"""

import os
from flask import Flask, jsonify
from flask_cors import CORS
import psycopg2
import psycopg2.extras
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)
CORS(app)

PG_CONFIG = {
    "host":     os.getenv("PG_HOST",     "localhost"),
    "port":     int(os.getenv("PG_PORT", "5432")),
    "dbname":   os.getenv("PG_DB",       "etheria_global_db"),
    "user":     os.getenv("PG_USER",     "etheria_user"),
    "password": os.getenv("PG_PASSWORD", "etheria_pass"),
}


def query(sql, params=None):
    conn = psycopg2.connect(**PG_CONFIG)
    with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        cur.execute(sql, params)
        rows = cur.fetchall()
    conn.close()
    return [dict(r) for r in rows]


# ── KPIs globales ────────────────────────────────────────────
@app.route("/api/kpis")
def kpis():
    rows = query("""
        SELECT
            COUNT(DISTINCT order_id)            AS total_orders,
            ROUND(SUM(revenue_usd)::NUMERIC, 2) AS total_revenue_usd,
            ROUND(SUM(total_cost_usd)::NUMERIC, 2) AS total_cost_usd,
            ROUND(SUM(gross_margin_usd)::NUMERIC, 2) AS total_margin_usd,
            ROUND(AVG(gross_margin_pct)::NUMERIC, 2) AS avg_margin_pct,
            COUNT(DISTINCT sale_country_iso)    AS countries_active,
            COUNT(DISTINCT brand_name)          AS brands_active,
            COUNT(DISTINCT site_url)            AS sites_active
        FROM analytics.unified_orders
    """)
    return jsonify(rows[0] if rows else {})


# ── Rentabilidad por país ────────────────────────────────────
@app.route("/api/country_profitability")
def country_profitability():
    rows = query("""
        SELECT
            sale_country,
            sale_country_iso,
            currency_code,
            tax_rate_percent,
            total_orders,
            ROUND(total_revenue_usd::NUMERIC, 2)        AS total_revenue_usd,
            ROUND(total_cost_usd::NUMERIC, 2)           AS total_cost_usd,
            ROUND(total_margin_usd::NUMERIC, 2)         AS total_margin_usd,
            ROUND(avg_margin_pct::NUMERIC, 2)           AS avg_margin_pct,
            ROUND(total_shipping_usd::NUMERIC, 2)       AS total_shipping_usd,
            ROUND(total_permit_usd::NUMERIC, 2)         AS total_permit_usd,
            ROUND(tax_impact_usd::NUMERIC, 2)           AS tax_impact_usd,
            ROUND(net_margin_after_tax_usd::NUMERIC, 2) AS net_margin_after_tax_usd,
            ROUND(net_margin_pct::NUMERIC, 2)           AS net_margin_pct
        FROM analytics.country_profitability
        ORDER BY total_revenue_usd DESC
    """)
    return jsonify(rows)


# ── Efectividad de marcas IA ─────────────────────────────────
@app.route("/api/brand_performance")
def brand_performance():
    rows = query("""
        SELECT
            brand_name,
            brand_focus,
            ai_model_version,
            site_url,
            sale_country,
            total_orders,
            ROUND(total_revenue_usd::NUMERIC, 2)    AS total_revenue_usd,
            ROUND(total_cost_usd::NUMERIC, 2)       AS total_cost_usd,
            ROUND(total_margin_usd::NUMERIC, 2)     AS total_margin_usd,
            ROUND(avg_margin_pct::NUMERIC, 2)       AS avg_margin_pct,
            ROUND(avg_order_value_usd::NUMERIC, 2)  AS avg_order_value_usd
        FROM analytics.brand_performance
        ORDER BY total_revenue_usd DESC
    """)
    return jsonify(rows)


# ── Márgenes por categoría ───────────────────────────────────
@app.route("/api/category_margins")
def category_margins():
    rows = query("""
        SELECT
            category_name,
            total_orders,
            ROUND(total_revenue_usd::NUMERIC, 2)    AS total_revenue_usd,
            ROUND(avg_base_cost_usd::NUMERIC, 4)    AS avg_base_cost_usd,
            ROUND(avg_landed_cost_usd::NUMERIC, 4)  AS avg_landed_cost_usd,
            ROUND(avg_real_cost_usd::NUMERIC, 4)    AS avg_real_cost_usd,
            ROUND(total_margin_usd::NUMERIC, 2)     AS total_margin_usd,
            ROUND(avg_margin_pct::NUMERIC, 2)       AS avg_margin_pct,
            markup_x
        FROM analytics.category_margins
        ORDER BY total_margin_usd DESC
    """)
    return jsonify(rows)


# ── Órdenes recientes ────────────────────────────────────────
@app.route("/api/recent_orders")
def recent_orders():
    rows = query("""
        SELECT
            order_id,
            TO_CHAR(order_date, 'DD/MM/YYYY') AS order_date,
            brand_name,
            sale_country,
            currency_code,
            branded_name,
            category_name,
            quantity,
            ROUND(unit_price_local::NUMERIC, 2)     AS unit_price_local,
            ROUND(revenue_usd::NUMERIC, 2)           AS revenue_usd,
            ROUND(real_cost_per_unit_usd::NUMERIC, 4) AS real_cost_per_unit_usd,
            ROUND(gross_margin_usd::NUMERIC, 2)     AS gross_margin_usd,
            ROUND(gross_margin_pct::NUMERIC, 2)     AS gross_margin_pct,
            order_status
        FROM analytics.unified_orders
        ORDER BY order_date DESC
        LIMIT 50
    """)
    return jsonify(rows)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5050, debug=False)
