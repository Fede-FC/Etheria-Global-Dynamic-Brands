FROM python:3.11-slim

WORKDIR /app

# Solo instalamos lo necesario para PostgreSQL
RUN apt-get update && apt-get install -y \
    libpq-dev gcc \
    && rm -rf /var/lib/apt/lists/*

# Instalamos dependencias. Usamos psycopg2-binary para evitar compilar libpq
RUN pip install --no-cache-dir Flask SQLAlchemy psycopg2-binary pymysql

COPY . /app

# Asegúrate de que el nombre del archivo no tenga espacios o usa comillas
CMD ["python", "admin_api.py"]