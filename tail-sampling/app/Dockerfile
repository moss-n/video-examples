FROM python:3.10-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

# We need to configure OpenTelemetry properly when starting the app
ENV PYTHONUNBUFFERED=1

# Start the Flask application with OpenTelemetry instrumentation
CMD ["python", "app.py"]
