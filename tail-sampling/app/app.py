from flask import Flask, request
import random
import time
import logging
import os

# OpenTelemetry imports
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.resources import Resource
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Configure OpenTelemetry
# Get configuration type to include in the service name
config_type = os.environ.get("CONFIG_TYPE", "unknown")
service_name = f"order-service-{config_type}"

# Get environment name from environment variables
environment_name = os.environ.get("ENVIRONMENT", "tail-sampling-demo")

resource = Resource.create({
    "service.name": os.environ.get("OTEL_SERVICE_NAME", service_name),
    "service.version": "1.0.0",
    "deployment.environment": environment_name
})

# Set up the tracer
trace.set_tracer_provider(TracerProvider(resource=resource))
tracer = trace.get_tracer(__name__)

# Configure exporter
otlp_endpoint = os.environ.get("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector:4317")
span_exporter = OTLPSpanExporter(endpoint=otlp_endpoint, insecure=True)

# Add span processor to the tracer
span_processor = BatchSpanProcessor(span_exporter)
trace.get_tracer_provider().add_span_processor(span_processor)

# Create Flask app
app = Flask(__name__)

# Instrument Flask with OpenTelemetry
FlaskInstrumentor().instrument_app(app)
RequestsInstrumentor().instrument()

@app.route('/')
def index():
    return "Order Service Demo for Tail Sampling. Use /checkout to simulate orders."

@app.route('/checkout')
def checkout():
    # Get current span for adding attributes
    current_span = trace.get_current_span()
    
    # Generate a random order ID
    order_id = f"order-{random.randint(10000, 99999)}"
    current_span.set_attribute("order.id", order_id)
    
    # Add customer ID attribute
    customer_id = f"cust-{random.randint(1000, 9999)}"
    current_span.set_attribute("customer.id", customer_id)
    
    # Simulate different scenarios
    scenario = "normal"
    
    # 1. High Latency (10% chance, over 1.5 seconds)
    if random.random() < 0.1:
        scenario = "high_latency"
        logger.info(f"Order {order_id}: Processing slowly...")
        current_span.set_attribute("scenario", "high_latency")
        time.sleep(1.6 + random.random() * 0.5)
        logger.info(f"Order {order_id}: Completed with high latency")
        return {"order_id": order_id, "status": "completed", "message": "Checkout processed slowly"}, 200

    # 2. Errors (10% chance)
    if random.random() < 0.1:
        scenario = "error"
        logger.error(f"Order {order_id}: Failed to process!")
        current_span.set_attribute("scenario", "error")
        current_span.set_attribute("issue_detected", "true")  # Use string "true" to match YAML config
        
        # Set standard OpenTelemetry error status
        current_span.set_status(trace.StatusCode.ERROR, "Checkout failed: Inventory unavailable")
        
        # Errors can be fast or slow
        time.sleep(0.1 + random.random() * 0.5)
        return {"order_id": order_id, "status": "failed", "message": "Checkout failed: Inventory unavailable"}, 500

    # 3. Normal operation
    logger.info(f"Order {order_id}: Processing normally...")
    current_span.set_attribute("scenario", "normal")
    time.sleep(0.1 + random.random() * 0.3)
    logger.info(f"Order {order_id}: Completed successfully")
    return {"order_id": order_id, "status": "completed", "message": "Checkout successful"}, 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
