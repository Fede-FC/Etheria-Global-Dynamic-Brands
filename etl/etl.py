import pandas as pd
from sqlalchemy import create_engine
import time
import sys

def run_etl():
    print("⏳ Esperando 20 segundos para que las bases de datos terminen de cargar datos...")
    time.sleep(20)
    print("🚀 Iniciando Proceso ETL — Etheria Global <-> Dynamic Brands...")

    engine_pg = create_engine('postgresql://etheria_user@etheria_global_db:5432/etheria_global_db')
    engine_my = create_engine('mysql+pymysql://dynamic_user:dynamic_password@dynamic_brands_db:3306/dynamic_brands_db')

    try:
        # ── EXTRACCIÓN: Costo unitario por producto (Postgres) ────────────────
        query_costos = """
            SELECT
                id.product_id,
                AVG(id.unit_cost_usd) AS costo_compra_usd,
                AVG(
                    id.unit_cost_usd +
                    COALESCE(lc.shipping_cost_usd + lc.insurance_cost_usd
                             + lc.port_handling_usd + lc.other_costs_usd, 0)
                    / NULLIF(i.total_cost_usd, 0) * id.unit_cost_usd
                ) AS costo_unitario_total_usd
            FROM import_details id
            JOIN imports i ON id.import_id = i.import_id
            LEFT JOIN logistic_costs lc ON i.import_id = lc.import_id
            GROUP BY id.product_id
        """
        df_costos = pd.read_sql(query_costos, engine_pg)
        print(f"  OK Postgres: {len(df_costos)} productos con costo extraidos")

        # ── EXTRACCIÓN: Ventas (MySQL) ─────────────────────────────────────────
        query_ventas = """
            SELECT
                pc.etheria_product_id,
                pc.branded_name,
                b.brand_name,
                w.site_url,
                c.iso_code   AS country_iso,
                o.order_id,
                o.total_amount_local,
                o.total_amount_usd,
                ex.rate_to_usd,
                ex.currency_code AS currency_iso,
                oi.quantity,
                oi.unit_price_local
            FROM Orders o
            JOIN Order_items oi          ON o.order_id              = oi.order_id
            JOIN Website_products wp     ON oi.website_product_id   = wp.website_product_id
            JOIN Product_catalog pc      ON wp.catalog_product_id   = pc.catalog_product_id
            JOIN Brands b                ON pc.brand_id              = b.brand_id
            JOIN Websites w              ON wp.website_id            = w.website_id
            JOIN Countries c             ON w.country_id             = c.country_id
            JOIN Exchange_rates ex       ON o.exchange_rate_id       = ex.exchange_rate_id
            WHERE o.status != 'CANCELLED'
        """
        df_ventas = pd.read_sql(query_ventas, engine_my)
        print(f"  OK MySQL: {len(df_ventas)} lineas de venta extraidas")

        # ── TRANSFORMACIÓN ────────────────────────────────────────────────────
        df = pd.merge(
            df_ventas,
            df_costos,
            left_on='etheria_product_id',
            right_on='product_id',
            how='left'
        )

        df['venta_usd']       = df['total_amount_usd']
        df['costo_total_usd'] = df['costo_unitario_total_usd'] * df['quantity']
        df['utilidad_bruta']  = df['venta_usd'] - df['costo_total_usd']
        df['margen_pct']      = (df['utilidad_bruta'] / df['venta_usd'].replace(0, None)) * 100
        df['roi_pct']         = (df['utilidad_bruta'] / df['costo_total_usd'].replace(0, None)) * 100
        print(f"  OK Transformacion: {len(df)} registros fusionados")

        # ── CARGA ─────────────────────────────────────────────────────────────
        df.to_sql('reporte_gerencial', engine_pg, if_exists='replace', index=False)
        print("  OK reporte_gerencial cargado en Postgres")

        # Resumen por pais
        df_pais = df.groupby(['country_iso', 'currency_iso']).agg(
            total_ventas_usd=('venta_usd', 'sum'),
            total_costo_usd=('costo_total_usd', 'sum'),
            utilidad_usd=('utilidad_bruta', 'sum'),
            margen_promedio_pct=('margen_pct', 'mean'),
            num_ordenes=('order_id', 'nunique')
        ).reset_index()
        df_pais['roi_pct'] = (df_pais['utilidad_usd'] / df_pais['total_costo_usd'].replace(0, None)) * 100
        df_pais.to_sql('resumen_por_pais', engine_pg, if_exists='replace', index=False)
        print("  OK resumen_por_pais cargado en Postgres")

        # Resumen por marca y sitio web
        df_marca = df.groupby(['brand_name', 'site_url']).agg(
            total_ventas_usd=('venta_usd', 'sum'),
            total_costo_usd=('costo_total_usd', 'sum'),
            utilidad_usd=('utilidad_bruta', 'sum'),
            margen_promedio_pct=('margen_pct', 'mean'),
            num_ordenes=('order_id', 'nunique'),
            num_productos=('etheria_product_id', 'nunique')
        ).reset_index()
        df_marca['roi_pct'] = (df_marca['utilidad_usd'] / df_marca['total_costo_usd'].replace(0, None)) * 100
        df_marca.to_sql('resumen_por_marca', engine_pg, if_exists='replace', index=False)
        print("  OK resumen_por_marca cargado en Postgres")

        print("\n ETL completado exitosamente.")

    except Exception as e:
        print(f"\n Error en ETL: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    run_etl()
