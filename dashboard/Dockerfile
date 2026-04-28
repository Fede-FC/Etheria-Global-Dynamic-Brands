FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y \
    libpq-dev \
    gcc \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir flask sqlalchemy psycopg2 pandas

COPY dashboard_api.py .
COPY dashboard.html .

EXPOSE 5000

CMD ["python", "dashboard_api.py"]
