# Integrating with Splunk Observability Cloud

This document describes how to modify the tail sampling demo to send traces to Splunk Observability Cloud instead of Jaeger.

## Prerequisites

To integrate with Splunk Observability Cloud, you will need:

1. A Splunk Observability Cloud account
2. An access token with traces write permissions
3. Your Splunk realm (e.g., `us1`, `eu0`, etc.)

## Configuration Changes

### 1. Create Environment Variables File

Create a `.env` file in the root directory to store your Splunk credentials:

```bash
SPLUNK_ACCESS_TOKEN=your-access-token
SPLUNK_REALM=us1  # Replace with your realm
```

### 2. Update OpenTelemetry Collector Configuration

Create a new configuration file for Splunk integration:

```yaml
# otel-collector-splunk-config.yaml
receivers:
  # Receive data from the application (same as before)
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

exporters:
  # Replace Jaeger exporter with Splunk exporter
  splunk_hec:
    token: "${SPLUNK_ACCESS_TOKEN}"
    endpoint: "https://ingest.${SPLUNK_REALM}.signalfx.com/v2/trace"
    source: "otel-tail-sampling-demo"
    sourcetype: "otel-trace"
  
  # Still keep logging exporter for debugging
  logging:
    verbosity: detailed
    sampling_initial: 5
    sampling_thereafter: 200

processors:
  # Same processors as before
  batch:
    timeout: 10s
    send_batch_size: 8192
    send_batch_max_size: 0
  
  # Tail sampling policies remain unchanged
  tail_sampling:
    decision_wait: 10s
    num_traces: 50000
    policies:
      [
        {
          name: "error-sampling",
          type: "status_code",
          status_code: {status_codes: ["ERROR"]}
        },
        {
          name: "latency-sampling",
          type: "latency",
          latency: {threshold_ms: 1500}
        },
        {
          name: "error-attribute-sampling",
          type: "string_attribute",
          string_attribute: {key: "error", values: ["true"]}
        },
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
      # Replace exporters with Splunk exporter
      exporters: [splunk_hec, logging]
```

### 3. Update Docker Compose Configuration

Create a new Docker Compose file for Splunk integration:

```yaml
# docker-compose-splunk.yaml
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
      - "4317:4317"     # OTLP gRPC receiver
      - "4318:4318"     # OTLP HTTP receiver
    environment:
      - SPLUNK_ACCESS_TOKEN=${SPLUNK_ACCESS_TOKEN}
      - SPLUNK_REALM=${SPLUNK_REALM}
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
```

## Running with Splunk Integration

1. Add your credentials to `.env` file
2. Start the services with:

```bash
export $(cat .env | xargs) && docker-compose -f docker-compose-splunk.yaml up
```

3. Generate traffic using the load generation script:

```bash
./generate_load.sh 200 0.05
```

4. View the traces in Splunk Observability Cloud:
   - Log in to your Splunk Observability Cloud account
   - Navigate to APM > Traces
   - Filter for service name "order-service"
   - Observe that only the sampled traces (errors, high latency, and 10% of normal traces) appear

## Key Points for the Video

1. **Sampling Consistency**: The same sampling rules apply regardless of the backend (Jaeger or Splunk)
2. **Decoupled Logic**: Tail sampling logic is completely handled by OpenTelemetry Collector, not the backend
3. **Configuration Simplicity**: The only change needed is the export destination
4. **End-to-End Demo**: Validate that the same sampling patterns show up in Splunk as they did in Jaeger
