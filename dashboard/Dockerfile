FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY dashboard_api.py .

EXPOSE 5050

CMD ["python", "dashboard_api.py"]
