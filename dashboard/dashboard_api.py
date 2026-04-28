from flask import Flask, jsonify, send_from_directory
from sqlalchemy import create_engine, text
import pandas as pd
import os

app = Flask(__name__)

DB_URL = 'postgresql://etheria_user@etheria_global_db:5432/etheria_global_db'

def get_engine():
    return create_engine(DB_URL)

def table_exists(engine, name):
    with engine.connect() as conn:
        result = conn.execute(text(
            "SELECT EXISTS (SELECT 1 FROM information_schema.tables "
            "WHERE table_schema='public' AND table_name=:t)"
        ), {"t": name})
        return result.scalar()

@app.route('/')
def index():
    return send_from_directory('.', 'dashboard.html')

@app.route('/api/kpis')
def kpis():
    try:
        engine = get_engine()
        if not table_exists(engine, 'reporte_gerencial'):
            return jsonify({"error": "ETL aún no ha corrido"}), 503

        df = pd.read_sql("SELECT * FROM reporte_gerencial", engine)
        df_pais = pd.read_sql("SELECT * FROM resumen_por_pais", engine)

        return jsonify({
            "total_revenue_usd": round(float(df['venta_usd'].sum()), 2),
            "total_cost_usd":    round(float(df['costo_total_usd'].sum()), 2),
            "total_margin_usd":  round(float(df['utilidad_bruta'].sum()), 2),
            "avg_margin_pct":    round(float(df['margen_pct'].mean()), 2),
            "total_orders":      int(df['order_id'].nunique()),
            "sites_active":      int(df['site_url'].nunique()),
            "countries_active":  int(df['country_iso'].nunique()),
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/by_country')
def by_country():
    try:
        engine = get_engine()
        if not table_exists(engine, 'resumen_por_pais'):
            return jsonify([]), 503
        df = pd.read_sql("SELECT * FROM resumen_por_pais ORDER BY total_ventas_usd DESC", engine)
        df = df.fillna(0)
        return jsonify(df.to_dict(orient='records'))
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/by_brand')
def by_brand():
    try:
        engine = get_engine()
        if not table_exists(engine, 'resumen_por_marca'):
            return jsonify([]), 503
        df = pd.read_sql("SELECT * FROM resumen_por_marca ORDER BY total_ventas_usd DESC", engine)
        df = df.fillna(0)
        return jsonify(df.to_dict(orient='records'))
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/recent_orders')
def recent_orders():
    try:
        engine = get_engine()
        if not table_exists(engine, 'reporte_gerencial'):
            return jsonify([]), 503
        df = pd.read_sql("""
            SELECT
                order_id,
                brand_name,
                country_iso          AS sale_country_iso,
                country_iso          AS sale_country,
                branded_name,
                quantity,
                unit_price_local,
                currency_iso         AS currency_code,
                venta_usd            AS revenue_usd,
                costo_unitario_total_usd AS real_cost_per_unit_usd,
                utilidad_bruta       AS gross_margin_usd,
                margen_pct           AS gross_margin_pct
            FROM reporte_gerencial
            ORDER BY order_id DESC
            LIMIT 50
        """, engine)
        df = df.fillna(0)
        return jsonify(df.to_dict(orient='records'))
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/by_category')
def by_category():
    try:
        engine = get_engine()
        if not table_exists(engine, 'reporte_gerencial'):
            return jsonify([]), 503
        df = pd.read_sql("""
            SELECT
                country_iso AS categoria,
                SUM(venta_usd) AS revenue,
                SUM(costo_total_usd) AS costo,
                AVG(margen_pct) AS margen_pct
            FROM reporte_gerencial
            GROUP BY country_iso
            ORDER BY revenue DESC
        """, engine)
        df = df.fillna(0)
        return jsonify(df.to_dict(orient='records'))
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/cost_breakdown')
def cost_breakdown():
    try:
        engine = get_engine()
        if not table_exists(engine, 'resumen_por_pais'):
            return jsonify([]), 503
        df = pd.read_sql("""
            SELECT
                country_iso,
                total_costo_usd  AS costo_producto,
                (total_ventas_usd - total_costo_usd) AS margen_bruto
            FROM resumen_por_pais
            ORDER BY total_ventas_usd DESC
        """, engine)
        df = df.fillna(0)
        return jsonify(df.to_dict(orient='records'))
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
