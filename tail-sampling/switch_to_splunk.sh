#!/bin/bash

set -e

# Define colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check for .env file
if [ ! -f ./.env ]; then
    echo -e "${YELLOW}Error:${NC} .env file not found"
    echo "Please create a .env file with your Splunk credentials:"
    echo "SPLUNK_ACCESS_TOKEN=your-access-token"
    echo "SPLUNK_REALM=your-realm (e.g., us1)"
    exit 1
fi

# Default to help if no arguments provided
if [ $# -eq 0 ]; then
    echo -e "${YELLOW}Usage:${NC} $0 [tail|no-tail|status]"
    echo
    echo "Options:"
    echo "  tail    - Switch to tail sampling configuration with Splunk export"
    echo "  no-tail - Switch to configuration without tail sampling with Splunk export"
    echo "  status  - Show current configuration"
    exit 1
fi

# Load environment variables from .env file
source ./.env

# Check if required variables are set
if [ -z "$SPLUNK_ACCESS_TOKEN" ] || [ -z "$SPLUNK_REALM" ]; then
    echo -e "${YELLOW}Error:${NC} Missing required environment variables"
    echo "Please make sure SPLUNK_ACCESS_TOKEN and SPLUNK_REALM are set in your .env file"
    exit 1
fi

# Function to display status
show_status() {
    if [ -n "$CONFIG_TYPE" ]; then
        if [[ "$CONFIG_TYPE" == "with" ]]; then
            echo -e "${BLUE}Current configuration:${NC} With tail sampling, exporting to Splunk"
        else
            echo -e "${BLUE}Current configuration:${NC} No tail sampling, exporting to Splunk"
        fi
        echo -e "${GREEN}Splunk realm:${NC} $SPLUNK_REALM"
    else
        echo -e "${YELLOW}Warning:${NC} CONFIG_TYPE not set, defaulting to no-tail sampling"
    fi
}

# Edit collector yaml to enable Splunk pipeline
enable_splunk_pipeline() {
    local config_file=$1
    # Uncomment the Splunk pipeline
    sed -i 's/# traces\/splunk:/traces\/splunk:/g' $config_file
    sed -i 's/#   receivers:/  receivers:/g' $config_file
    sed -i 's/#   processors:/  processors:/g' $config_file
    sed -i 's/#   exporters:/  exporters:/g' $config_file
}

case "$1" in
    "tail")
        echo -e "${BLUE}Switching to${NC} tail sampling configuration with Splunk export..."
        
        # Copy the template to a temporary file
        cp ./otel-collector-config-with-sampling-splunk.yaml ./otel-collector-config-with-sampling-temp.yaml
        
        # Enable Splunk pipeline
        enable_splunk_pipeline ./otel-collector-config-with-sampling-temp.yaml
        
        # Only restart the collector service to preserve Jaeger trace data
        CONFIG_TYPE=with SPLUNK_ACCESS_TOKEN=$SPLUNK_ACCESS_TOKEN SPLUNK_REALM=$SPLUNK_REALM \
        docker compose stop otel-collector order-service
        
        # Update the collector configuration path to use the temporary file
        CONFIG_TYPE=with SPLUNK_ACCESS_TOKEN=$SPLUNK_ACCESS_TOKEN SPLUNK_REALM=$SPLUNK_REALM \
        docker compose up -d otel-collector order-service
        
        # Set the environment variable for the current session
        export CONFIG_TYPE=with
        
        echo -e "${GREEN}Successfully switched to tail sampling with Splunk export!${NC}"
        echo "Wait a moment for services to fully restart..."
        ;;
        
    "no-tail")
        echo -e "${BLUE}Switching to${NC} no tail sampling configuration with Splunk export..."
        
        # Copy the template to a temporary file
        cp ./otel-collector-config-no-sampling-splunk.yaml ./otel-collector-config-no-sampling-temp.yaml
        
        # Enable Splunk pipeline
        enable_splunk_pipeline ./otel-collector-config-no-sampling-temp.yaml
        
        # Only restart the collector service to preserve Jaeger trace data
        CONFIG_TYPE=no SPLUNK_ACCESS_TOKEN=$SPLUNK_ACCESS_TOKEN SPLUNK_REALM=$SPLUNK_REALM \
        docker compose stop otel-collector order-service
        
        # Update the collector configuration path to use the temporary file
        CONFIG_TYPE=no SPLUNK_ACCESS_TOKEN=$SPLUNK_ACCESS_TOKEN SPLUNK_REALM=$SPLUNK_REALM \
        docker compose up -d otel-collector order-service
        
        # Set the environment variable for the current session
        export CONFIG_TYPE=no
        
        echo -e "${GREEN}Successfully switched to no tail sampling with Splunk export!${NC}"
        echo "Wait a moment for services to fully restart..."
        ;;
        
    "status")
        show_status
        ;;
        
    *)
        echo -e "${YELLOW}Unknown option:${NC} $1"
        echo -e "${YELLOW}Usage:${NC} $0 [tail|no-tail|status]"
        exit 1
        ;;
esac

# Final status
if [ "$1" != "status" ]; then
    echo
    show_status
fi

echo
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Run './generate_load.sh' to generate traces"
echo "2. View traces in Splunk Observability Cloud"
echo "   - Log in to your Splunk account"
echo "   - Navigate to APM > Traces"
