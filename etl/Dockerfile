FROM python:3.11-slim

WORKDIR /app

# Instalamos dependencias del sistema para los drivers de Postgres y MySQL
RUN apt-get update && apt-get install -y \
    libpq-dev \
    gcc \
    default-libmysqlclient-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Instalamos las librerías de Python
RUN pip install --no-cache-dir pandas sqlalchemy psycopg2 pymysql

# Copiamos solo los archivos del ETL
COPY etl.py .

# Ejecuta el script y el contenedor se apaga al terminar
CMD ["python", "etl.py"]