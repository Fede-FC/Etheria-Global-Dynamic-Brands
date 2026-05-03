"""
Admin API — CRUD básico para modificar datos en tiempo real.
Expone endpoints para que el formulario web interactúe con Postgres y MySQL.

Cambios respecto a la versión original:
  * /api/status y /api/etl-summary ahora consultan el esquema correcto
    `analytics.etl_profitability_summary` (la tabla la crea el ETL en
    el schema analytics, no en public).
  * /api/orders devuelve los DECIMAL como float, así el front puede
    usar toFixed sin romper el render.
  * Nuevo POST /api/brands           (crear marca).
  * Nuevo GET  /api/brand-focuses    (catálogo para el form de marcas).
  * Nuevo POST /api/websites         (crear sitio web).
  * Nuevo GET  /api/countries        (catálogo para sitios).
  * Nuevo GET  /api/order-statuses   (catálogo de estados).
  * Nuevo POST /api/inventory        (alta de Website_products).
  * Nuevo GET  /api/product-catalog  (catálogo para alta de inventario).
"""
from flask import Flask, jsonify, request, send_from_directory
from sqlalchemy import create_engine, text
from decimal import Decimal
from datetime import date, datetime
import os

app = Flask(__name__)

PG = create_engine("postgresql://etheria_user:etheria_password@etheria_global_db:5432/etheria_global_db")
MY = create_engine("mysql+pymysql://dynamic_user:dynamic_password@dynamic_brands_db:3306/dynamic_brands_db")


def _to_jsonable(v):
    """Convierte tipos no serializables (Decimal, date, datetime) a tipos JSON."""
    if isinstance(v, Decimal):
        return float(v)
    if isinstance(v, (date, datetime)):
        return v.isoformat()
    return v


def _row_to_dict(row):
    return {k: _to_jsonable(v) for k, v in row._mapping.items()}


def pg(sql, params=None):
    with PG.begin() as c:
        r = c.execute(text(sql), params or {})
        try:    return [_row_to_dict(row) for row in r]
        except: return []

def my(sql, params=None):
    with MY.begin() as c:
        r = c.execute(text(sql), params or {})
        try:    return [_row_to_dict(row) for row in r]
        except: return []

@app.route("/")
def index():
    return send_from_directory(".", "admin.html")

# ── Estado del sistema ────────────────────────────────────────────────────────
@app.route("/api/status")
def status():
    try:
        p = pg("SELECT COUNT(*) AS n FROM products")[0]["n"]
        b = my("SELECT COUNT(*) AS n FROM Brands")[0]["n"]
        o = my("SELECT COUNT(*) AS n FROM Orders")[0]["n"]
        # La tabla la crea el ETL en el schema analytics
        try:
            s = pg("SELECT COUNT(*) AS n FROM analytics.etl_profitability_summary")[0]["n"]
        except Exception:
            s = 0
        return jsonify({"products_pg": p, "brands_my": b, "orders_my": o, "etl_rows": s, "ok": True})
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)})

# ── PRODUCTOS (Postgres) ──────────────────────────────────────────────────────
@app.route("/api/products", methods=["GET"])
def get_products():
    rows = pg("""
        SELECT p.product_id, p.product_name, c.category_name,
               u.unit_code, p.enabled
        FROM products p
        JOIN categories c ON p.category_id = c.category_id
        JOIN measurement_units u ON p.unit_id = u.unit_id
        ORDER BY p.product_id
    """)
    return jsonify(rows)

@app.route("/api/products", methods=["POST"])
def create_product():
    d = request.json
    try:
        r = pg("""
            INSERT INTO products(product_name, category_id, unit_id)
            VALUES (:name, :cat, :unit) RETURNING product_id
        """, {"name": d["product_name"], "cat": d["category_id"], "unit": d["unit_id"]})
        return jsonify({"ok": True, "product_id": r[0]["product_id"]})
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 400

@app.route("/api/products/<int:pid>", methods=["PUT"])
def update_product(pid):
    d = request.json
    try:
        pg("UPDATE products SET product_name=:name, enabled=:en WHERE product_id=:id",
           {"name": d["product_name"], "en": d.get("enabled", True), "id": pid})
        return jsonify({"ok": True})
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 400

@app.route("/api/products/<int:pid>", methods=["DELETE"])
def disable_product(pid):
    try:
        pg("UPDATE products SET enabled=FALSE WHERE product_id=:id", {"id": pid})
        return jsonify({"ok": True})
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 400

# ── CATÁLOGOS auxiliares (Postgres) ──────────────────────────────────────────
@app.route("/api/categories")
def get_categories():
    return jsonify(pg("SELECT category_id, category_name FROM categories WHERE enabled=TRUE ORDER BY category_name"))

@app.route("/api/units")
def get_units():
    return jsonify(pg("SELECT unit_id, unit_code, unit_name FROM measurement_units WHERE enabled=TRUE"))

# ── TIPO DE CAMBIO (Postgres) ─────────────────────────────────────────────────
@app.route("/api/exchange-rates", methods=["GET"])
def get_rates():
    rows = pg("""
        SELECT er.exchange_rate_id, c1.currency_code AS currency,
               c2.currency_code AS base_currency,
               er.rate, er.rate_date, er.source
        FROM exchange_rates er
        JOIN currencies c1 ON er.currency_id = c1.currency_id
        JOIN currencies c2 ON er.base_currency_id = c2.currency_id
        ORDER BY er.rate_date DESC, c1.currency_code
    """)
    return jsonify(rows)

@app.route("/api/exchange-rates", methods=["POST"])
def create_rate():
    d = request.json
    try:
        pg("""
            INSERT INTO exchange_rates(currency_id, base_currency_id, rate, rate_date, source)
            VALUES (
                (SELECT currency_id FROM currencies WHERE currency_code=:cur),
                (SELECT currency_id FROM currencies WHERE is_base=TRUE LIMIT 1),
                :rate, :date, :source
            )
            ON CONFLICT (currency_id, base_currency_id, rate_date) DO UPDATE SET rate=:rate
        """, {"cur": d["currency_code"], "rate": d["rate"],
              "date": d["rate_date"], "source": d.get("source","Manual")})
        return jsonify({"ok": True})
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 400

# ── ÓRDENES (MySQL) ───────────────────────────────────────────────────────────
@app.route("/api/orders", methods=["GET"])
def get_orders():
    rows = my("""
        SELECT o.order_id, CONCAT(cu.first_name,' ',cu.last_name) AS customer,
               w.site_url, os.status_code AS status,
               o.total_amount_local, cur.currency_code,
               o.total_amount_base, o.order_date
        FROM Orders o
        JOIN Customers cu       ON o.customer_id   = cu.customer_id
        JOIN Websites w         ON o.website_id     = w.website_id
        JOIN Order_statuses os  ON o.status_id      = os.status_id
        JOIN Currencies cur     ON o.currency_id    = cur.currency_id
        ORDER BY o.order_date DESC LIMIT 50
    """)
    return jsonify(rows)

@app.route("/api/orders/<int:oid>/status", methods=["PUT"])
def update_order_status(oid):
    d = request.json
    try:
        my("""
            UPDATE Orders o
            JOIN Order_statuses os ON os.status_code = :code
            SET o.status_id = os.status_id
            WHERE o.order_id = :id
        """, {"code": d["status_code"], "id": oid})
        return jsonify({"ok": True})
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 400

# ── ESTADOS / FOCOS / PAÍSES (catálogos MySQL) ────────────────────────────────
@app.route("/api/order-statuses")
def get_order_statuses():
    return jsonify(my("SELECT status_id, status_code FROM Order_statuses ORDER BY status_id"))

@app.route("/api/brand-focuses")
def get_brand_focuses():
    return jsonify(my("SELECT focus_id, focus_name FROM Brand_focuses ORDER BY focus_name"))

@app.route("/api/countries")
def get_countries_my():
    return jsonify(my("SELECT country_id, country_name, iso_code FROM Countries WHERE enabled=1 ORDER BY country_name"))

# ── MARCAS (MySQL) ────────────────────────────────────────────────────────────
@app.route("/api/brands", methods=["GET"])
def get_brands():
    return jsonify(my("""
        SELECT b.brand_id, b.brand_name, bf.focus_name,
               b.ai_model_version, b.enabled
        FROM Brands b JOIN Brand_focuses bf ON b.focus_id=bf.focus_id
        ORDER BY b.brand_id
    """))

@app.route("/api/brands", methods=["POST"])
def create_brand():
    """Alta de marca. Requiere brand_name y focus_id; ai_model_version es opcional."""
    d = request.json or {}
    try:
        my("""
            INSERT INTO Brands(brand_name, focus_id, ai_model_version, enabled)
            VALUES (:name, :focus, :ai, 1)
        """, {
            "name":  d["brand_name"],
            "focus": d["focus_id"],
            "ai":    d.get("ai_model_version") or "manual"
        })
        return jsonify({"ok": True})
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 400

@app.route("/api/brands/<int:bid>", methods=["PUT"])
def update_brand(bid):
    d = request.json
    try:
        my("UPDATE Brands SET brand_name=:name, enabled=:en WHERE brand_id=:id",
           {"name": d["brand_name"], "en": d.get("enabled", 1), "id": bid})
        return jsonify({"ok": True})
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 400

# ── SITIOS WEB (MySQL) ────────────────────────────────────────────────────────
@app.route("/api/websites", methods=["GET"])
def get_websites():
    return jsonify(my("""
        SELECT w.website_id, b.brand_name, c.country_name,
               w.site_url, os.status_code AS status
        FROM Websites w
        JOIN Brands b          ON w.brand_id  = b.brand_id
        JOIN Countries c       ON w.country_id = c.country_id
        JOIN Order_statuses os ON w.status_id  = os.status_id
        ORDER BY w.website_id
    """))

@app.route("/api/websites", methods=["POST"])
def create_website():
    """Alta de sitio web. brand_id, country_id, site_url son obligatorios."""
    d = request.json or {}
    try:
        my("""
            INSERT INTO Websites(brand_id, country_id, site_url, marketing_focus,
                                 status_id, launch_date, enabled)
            VALUES (:brand, :country, :url, :focus,
                    COALESCE(
                        (SELECT status_id FROM Order_statuses WHERE status_code=:status_code LIMIT 1),
                        (SELECT status_id FROM Order_statuses WHERE status_code='ACTIVE' LIMIT 1)
                    ),
                    CURDATE(), 1)
        """, {
            "brand":   d["brand_id"],
            "country": d["country_id"],
            "url":     d["site_url"],
            "focus":   d.get("marketing_focus", ""),
            "status_code": d.get("status_code", "ACTIVE")
        })
        return jsonify({"ok": True})
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 400

@app.route("/api/websites/<int:wid>/status", methods=["PUT"])
def toggle_website(wid):
    d = request.json
    try:
        my("""
            UPDATE Websites w
            JOIN Order_statuses os ON os.status_code = :code
            SET w.status_id = os.status_id
            WHERE w.website_id = :id
        """, {"code": d["status_code"], "id": wid})
        return jsonify({"ok": True})
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 400

# ── INVENTARIO (MySQL) ────────────────────────────────────────────────────────
@app.route("/api/inventory", methods=["GET"])
def get_inventory():
    return jsonify(my("""
        SELECT wp.website_product_id,
               pc.branded_name, b.brand_name, w.site_url,
               COALESCE(SUM(im.quantity),0) AS stock_actual
        FROM Website_products wp
        JOIN Product_catalog pc ON wp.catalog_product_id = pc.catalog_product_id
        JOIN Brands b           ON pc.brand_id = b.brand_id
        JOIN Websites w         ON wp.website_id = w.website_id
        LEFT JOIN Inventory_movements im ON wp.website_product_id = im.website_product_id
        GROUP BY wp.website_product_id, pc.branded_name, b.brand_name, w.site_url
        ORDER BY stock_actual ASC
    """))

@app.route("/api/inventory", methods=["POST"])
def create_inventory_item():
    """Alta de Website_products: publica un producto del catálogo en un sitio.
    Opcionalmente registra el stock inicial mediante un movimiento IN."""
    d = request.json or {}
    try:
        r = my("""
            INSERT INTO Website_products(website_id, catalog_product_id, is_featured, enabled)
            VALUES (:web, :cat, :feat, 1)
        """, {
            "web":  d["website_id"],
            "cat":  d["catalog_product_id"],
            "feat": 1 if d.get("is_featured") else 0
        })
        # recuperar el id recién creado
        new_id_row = my("SELECT LAST_INSERT_ID() AS id")
        new_id = new_id_row[0]["id"] if new_id_row else None

        initial = int(d.get("initial_stock") or 0)
        if new_id and initial > 0:
            my("""
                INSERT INTO Inventory_movements(website_product_id, movement_type,
                                                quantity, reference_type, notes)
                VALUES (:wp, 'IN', :qty, 'MANUAL', :notes)
            """, {"wp": new_id, "qty": initial, "notes": d.get("notes", "Stock inicial")})
        return jsonify({"ok": True, "website_product_id": new_id})
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 400

@app.route("/api/inventory/adjust", methods=["POST"])
def adjust_inventory():
    d = request.json
    try:
        qty = int(d["quantity"])
        direction = "IN" if qty > 0 else "OUT"
        my("""
            INSERT INTO Inventory_movements(website_product_id, movement_type, quantity,
                                           reference_type, notes)
            VALUES (:wp, :mvtype, :qty, 'MANUAL', :notes)
        """, {"wp": d["website_product_id"], "mvtype": direction,
              "qty": qty, "notes": d.get("notes", "Ajuste manual")})
        return jsonify({"ok": True})
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 400

# ── PRODUCT_CATALOG (MySQL) ───────────────────────────────────────────────────
@app.route("/api/product-catalog")
def get_product_catalog():
    """Catálogo Brand×Producto, requerido para dar de alta inventario."""
    return jsonify(my("""
        SELECT pc.catalog_product_id, pc.branded_name, b.brand_name
        FROM Product_catalog pc
        JOIN Brands b ON pc.brand_id = b.brand_id
        WHERE pc.enabled = 1
        ORDER BY b.brand_name, pc.branded_name
    """))

# ── RESUMEN ETL ───────────────────────────────────────────────────────────────
@app.route("/api/etl-summary", methods=["GET"])
def etl_summary():
    try:
        # La tabla vive en el schema analytics, no en public
        rows = pg("SELECT * FROM analytics.etl_profitability_summary ORDER BY revenue_base DESC")
        return jsonify(rows)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001, debug=False)