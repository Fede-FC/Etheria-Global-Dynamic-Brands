FROM python:3.11-slim

WORKDIR /app

# Añadir pkg-config es vital para que mysqlclient se compile correctamente
RUN apt-get update && apt-get install -y \
    libpq-dev gcc default-libmysqlclient-dev pkg-config \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir pandas sqlalchemy psycopg2-binary pymysql cryptography

COPY etl.py .

CMD ["python", "etl.py"]
