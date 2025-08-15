#!/bin/bash

# Script to set up Splunk Observability Cloud integration
# Usage: ./setup_splunk_integration.sh <access_token> <realm>

# Check parameters
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <access_token> <realm>"
    echo "Example: $0 abcdef123456 us1"
    exit 1
fi

ACCESS_TOKEN=$1
REALM=$2

echo "Setting up Splunk Observability Cloud integration..."
echo "Realm: $REALM"

# Create environment variables file
cat > .env << EOL
SPLUNK_ACCESS_TOKEN=$ACCESS_TOKEN
SPLUNK_REALM=$REALM
EOL

# Create Splunk-specific collector configuration
cat > otel-collector-splunk-config.yaml << EOL
receivers:
  # Receive data from the application
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

exporters:
  # Export to Splunk Observability Cloud
  splunk_hec:
    token: "\${SPLUNK_ACCESS_TOKEN}"
    endpoint: "https://ingest.\${SPLUNK_REALM}.signalfx.com/v2/trace"
    source: "otel-tail-sampling-demo"
    sourcetype: "otel-trace"
  
  # Debug exporter for console output
  debug:
    verbosity: detailed

processors:
  batch:
    # Increase timeout and size to handle more spans before export
    timeout: 10s
    send_batch_size: 8192
    send_batch_max_size: 0
  
  # Tail sampling policies remain unchanged from the Jaeger demo
  tail_sampling:
    decision_wait: 10s
    num_traces: 50000
    policies:
      [
        # Rule 1: Always sample traces with error status
        {
          name: "error-sampling",
          type: "status_code",
          status_code: {status_codes: ["ERROR"]}
        },
        # Rule 2: Always sample traces with high latency (>1.5s)
        {
          name: "latency-sampling",
          type: "latency",
          latency: {threshold_ms: 1500}
        },
        # Rule 3: Always sample traces with error attribute
        {
          name: "error-attribute-sampling",
          type: "string_attribute",
          string_attribute: {key: "error", values: ["true"]}
        },
        # Rule 4: Sample 10% of remaining traces (baseline)
        {
          name: "probabilistic-sampling",
          type: "probabilistic",
          probabilistic: {sampling_percentage: 10}
        }
      ]

extensions:
  health_check:
    endpoint: 0.0.0.0:13133
  pprof:
    endpoint: 0.0.0.0:1777

service:
  extensions: [health_check, pprof]
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch, tail_sampling]
      exporters: [splunk_hec, debug]
EOL

# Create Splunk-specific docker-compose file
cat > docker-compose-splunk.yaml << EOL
version: '3.8'

services:
  # OpenTelemetry Collector with Splunk export configuration
  otel-collector:
    image: otel/opentelemetry-collector-contrib:latest
    volumes:
      - ./otel-collector-splunk-config.yaml:/etc/otelcol-contrib/config.yaml
    ports:
      - "8888:8888"     # Prometheus metrics
      - "8889:8889"     # Prometheus exporter
      - "13133:13133"   # Health check
      - "1777:1777"     # pprof extension
      - "55679:55679"   # zpages extension
      - "24317:4317"    # OTLP gRPC receiver
      - "24318:4318"    # OTLP HTTP receiver
    environment:
      - SPLUNK_ACCESS_TOKEN=\${SPLUNK_ACCESS_TOKEN}
      - SPLUNK_REALM=\${SPLUNK_REALM}
    networks:
      - trace-demo

  # Order Service Flask application (unchanged)
  order-service:
    build: 
      context: ./app
    ports:
      - "5000:5000"
    environment:
      # Configure the app to send traces to the OTel Collector
      - OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317
      - OTEL_SERVICE_NAME=order-service
      - OTEL_RESOURCE_ATTRIBUTES=service.name=order-service,service.version=1.0.0,deployment.environment=demo
      # Send 100% of traces to the collector for tail sampling (crucial!)
      - OTEL_TRACES_SAMPLER=always_on
      - OTEL_TRACES_SAMPLER_ARG=1.0
      - OTEL_PYTHON_LOGGING_AUTO_INSTRUMENTATION_ENABLED=true
    depends_on:
      - otel-collector
    networks:
      - trace-demo

networks:
  trace-demo:
    driver: bridge
EOL

echo "Configuration files created successfully."
echo ""
echo "To run with Splunk integration:"
echo "-------------------------------"
echo "export \$(cat .env | xargs) && docker compose -f docker-compose-splunk.yaml up -d"
echo ""
echo "To generate test traffic:"
echo "------------------------"
echo "./generate_load.sh 200 0.05"
echo ""
echo "To switch back to the local Jaeger setup:"
echo "---------------------------------------"
echo "docker compose -f docker-compose-splunk.yaml down && docker compose up -d"
