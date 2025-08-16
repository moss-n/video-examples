# Splunk Integration for Tail Sampling Demo

This document explains how to use Splunk Observability Cloud with the tail sampling demo.

## Prerequisites

1. A Splunk Observability Cloud account with access token
2. Docker and Docker Compose installed

## Setup

1. Create a `.env` file in the project root with your Splunk credentials:
   ```
   SPLUNK_ACCESS_TOKEN=your-access-token
   SPLUNK_REALM=us1  # or your specific realm
   ```

   You can copy from the template and add your values:
   ```
   cp .env.example .env
   ```

## Usage

The existing `switch_collector_config.sh` script has been enhanced to support Splunk integration:

### Switch to Tail Sampling with Splunk

```bash
./switch_collector_config.sh splunk-tail
```

This will:
- Configure the OpenTelemetry collector to use tail sampling
- Enable the Splunk exporter
- Restart only the necessary services (collector and order-service)
- Preserve existing traces in Jaeger

### Switch to No Tail Sampling with Splunk

```bash
./switch_collector_config.sh splunk-no-tail
```

This will do the same but with tail sampling disabled.

### Check Current Status

```bash
./switch_collector_config.sh status
```

This shows the current configuration, including whether Splunk export is enabled.

## Generate Test Load

After switching to the desired configuration, generate some load to see the difference in sampled traces:

```bash
./generate_load.sh
```

## View Traces

### In Splunk Observability Cloud

1. Log in to your Splunk Observability Cloud account
2. Navigate to APM > Traces
3. Filter by service name "order-service"

### In Local Jaeger

The local Jaeger UI is still available at:
```
http://localhost:16686
```

## Architecture

This integration:
- Uses the same Docker services as the original demo
- Directly integrates Splunk exporters into the existing OpenTelemetry collector configurations
- Uses environment variable substitution to conditionally enable Splunk pipelines
- Allows you to switch between tail sampling and no tail sampling modes with or without Splunk
- Preserves trace data in Jaeger while also sending to Splunk
- Demonstrates the effects of tail sampling in both backends

## Reverting to Jaeger-only

To revert to the Jaeger-only setup (without Splunk export):

```bash
./switch_collector_config.sh tail
# or
./switch_collector_config.sh no-tail
```

## Using Splunk Distribution of OpenTelemetry Collector

For production deployments, consider using the Splunk Distribution of OpenTelemetry Collector. This provides:

1. Better default configurations for Splunk
2. Additional processors and exporters specific to Splunk
3. Enterprise support from Splunk
4. Regular security updates

To use the Splunk distribution, change the collector image in `docker-compose.yaml`:

```yaml
otel-collector:
  image: quay.io/signalfx/splunk-otel-collector:latest
  # Rest of the configuration remains the same
```
