# Tail Sampling Demo for Video Presentation

This project demonstrates tail sampling with OpenTelemetry for a video presentation.

## Project Overview

This demo showcases tail sampling using:

- A Python Flask application (simulated Order Service)
- OpenTelemetry for instrumentation
- OpenTelemetry Collector for tail sampling
- Jaeger for trace visualization (as a stand-in for Splunk Observability Cloud)

## Tail Sampling Rules

The demo implements the following sampling policies:

1. **Error Sampling**: Captures 100% of traces with error status
2. **Latency Sampling**: Captures 100% of traces with latency > 1.5s
3. **Error Attribute Sampling**: Captures 100% of traces with the error attribute
4. **Probabilistic Sampling**: Captures 10% of all other traces

## Project Structure

```
tail-sampling/
├── app/
│   ├── app.py               # Flask application with OTel instrumentation
│   ├── Dockerfile           # Container definition for the app
│   └── requirements.txt     # Python dependencies
├── docker-compose.yaml      # Orchestrates all services
├── generate_load.sh         # Script to generate test traffic
├── otel-collector-config-with-sampling.yaml  # OTel Collector config with tail sampling
├── otel-collector-config-no-sampling.yaml  # OTel Collector config without tail sampling
├── otel-collector-config-with-sampling-splunk.yaml  # Tail sampling with Splunk export
├── otel-collector-config-no-sampling-splunk.yaml  # No tail sampling with Splunk export
├── switch_collector_config.sh  # Script to switch between configurations
├── README.md               # This file
└── splunk_integration.md   # Instructions for Splunk Observability Cloud
```

## Running the Demo

### Standard Demo

1. Build and start the services:
   ```
   docker compose up -d
   ```

2. Generate some load to see sampling in action:
   ```
   ./generate_load.sh
   ```

3. View traces in Jaeger UI: http://localhost:16686

### Before/After Tail Sampling Comparison

The demo includes a script to switch between two collector configurations to demonstrate the impact of tail sampling:

1. Start with no tail sampling:
   ```
   ./switch_collector_config.sh no-tail
   ```

2. Generate load and observe all traces in Jaeger:
   ```
   ./generate_load.sh
   ```

3. Switch to tail sampling configuration:
   ```
   ./switch_collector_config.sh tail
   ```

4. Generate load again and observe how tail sampling affects trace volume:
   ```
   ./generate_load.sh
   ```

5. Compare the number of traces and their characteristics in Jaeger UI

6. Check current configuration status any time:
   ```
   ./switch_collector_config.sh status
   ```

## Expected Results

After generating 200 requests:
- Approximately 20 error traces (10% of total)
- Approximately 20 high-latency traces (10% of total)
- Approximately 16 "normal" traces (10% of the remaining 80%)
- Total: ~56 traces in Jaeger instead of 200

## Splunk Observability Cloud Integration

This demo supports exporting traces to both Jaeger (default) and Splunk Observability Cloud.

### Using the Switch Script for Splunk Integration

1. Create a `.env` file with your Splunk credentials:
   ```
   SPLUNK_ACCESS_TOKEN=your-access-token
   SPLUNK_REALM=your-realm (e.g., us1)
   ```

2. To switch to a configuration that exports to Splunk:
   ```
   # With tail sampling and Splunk export
   ./switch_collector_config.sh splunk-tail
   
   # Without tail sampling but with Splunk export
   ./switch_collector_config.sh splunk-no-tail
   ```

3. For more details on Splunk Observability Cloud integration, see [splunk_integration.md](splunk_integration.md).

## Video Talking Points

1. **Introduction to Tail Sampling**:
   - Decision made after the trace is complete
   - Collects more context for better decisions
   - Preserves important traces while reducing volume

2. **The Problem with Head Sampling**:
   - Decisions are made at span creation time
   - No knowledge of future spans or trace outcome
   - May miss important traces (errors, high latency)

3. **Demonstration Flow**:
   - Show the application generating mixed traffic
   - Explain the sampling rules in the collector
   - Compare the number of traces generated vs captured
   - Verify that all error and high-latency traces are preserved

4. **Splunk Observability Cloud Migration**:
   - Show how the same sampling rules apply
   - Only the export destination changes
