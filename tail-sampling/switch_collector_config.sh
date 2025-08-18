#!/bin/bash

set -e

# Define colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables to track current state
CURRENT_CONFIG="with"
SPLUNK_ENABLED="false"

# Default to help if no arguments provided
if [ $# -eq 0 ]; then
    echo -e "${YELLOW}Usage:${NC} $0 [tail|no-tail|splunk-tail|splunk-no-tail|status]"
    echo
    echo "Options:"
    echo "  tail           - Switch to configuration with tail sampling"
    echo "  no-tail        - Switch to configuration without tail sampling"
    echo "  splunk-tail    - Switch to configuration with tail sampling and Splunk export"
    echo "  splunk-no-tail - Switch to configuration without tail sampling but with Splunk export"
    echo "  status         - Show current configuration"
    exit 1
fi

# Check for .env file when using Splunk options
check_splunk_env() {
    if [ ! -f ./.env ]; then
        echo -e "${YELLOW}Error:${NC} .env file not found"
        echo "Please create a .env file with your Splunk credentials:"
        echo "SPLUNK_ACCESS_TOKEN=your-access-token"
        echo "SPLUNK_REALM=your-realm (e.g., us1)"
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
}

# Function to display status
show_status() {
    if [[ "$CURRENT_CONFIG" == "with" ]]; then
        echo -e "${BLUE}Current configuration:${NC} With tail sampling"
    else
        echo -e "${BLUE}Current configuration:${NC} No tail sampling"
    fi
    
    if [[ "$SPLUNK_ENABLED" == "true" ]]; then
        echo -e "${GREEN}Splunk export:${NC} Enabled"
        if [ -n "$SPLUNK_REALM" ]; then
            echo -e "${GREEN}Splunk realm:${NC} $SPLUNK_REALM"
        fi
    else
        echo -e "${GREEN}Splunk export:${NC} Disabled"
    fi
}

case "$1" in
    "tail")
        echo -e "${BLUE}Switching to${NC} tail sampling configuration..."
        
        # Set collector config file
        export CONFIG_TYPE=with
        SPLUNK_ENABLED="false"
        
        # Reset to standard config if needed
        cp -f otel-collector-config-with-sampling.yaml.original otel-collector-config-with-sampling.yaml 2>/dev/null || true
        
        # Only restart the collector service to preserve Jaeger trace data
        docker compose stop otel-collector order-service
        # Use a single environment name but distinct service names based on CONFIG_TYPE
        export ENVIRONMENT="tail-sampling-demo"
        # Pass CONFIG_TYPE and ENVIRONMENT variables explicitly
        CONFIG_TYPE=with docker compose up -d otel-collector order-service
        
        # Set current state
        CURRENT_CONFIG="with"
        
        echo -e "${GREEN}Successfully switched to tail sampling configuration!${NC}"
        echo "Wait a moment for services to fully restart..."
        ;;
        
    "no-tail")
        echo -e "${BLUE}Switching to${NC} no tail sampling configuration..."
        
        # Set collector config file - use "no" as the service name prefix
        export CONFIG_TYPE=no
        SPLUNK_ENABLED="false"
        
        # Reset to standard config if needed
        cp -f otel-collector-config-no-sampling.yaml.original otel-collector-config-no-sampling.yaml 2>/dev/null || true
        
        # Only restart the collector service to preserve Jaeger trace data
        docker compose stop otel-collector order-service
        # Use a single environment name but distinct service names based on CONFIG_TYPE
        export ENVIRONMENT="tail-sampling-demo"
        # Pass CONFIG_TYPE and ENVIRONMENT variables explicitly
        CONFIG_TYPE=no docker compose up -d otel-collector order-service
        
        # Set current state
        CURRENT_CONFIG="no"
        
        echo -e "${GREEN}Successfully switched to no tail sampling configuration!${NC}"
        echo "Wait a moment for services to fully restart..."
        ;;
        
    "splunk-tail")
        echo -e "${BLUE}Switching to${NC} tail sampling with Splunk export..."
        
        # Check Splunk credentials
        check_splunk_env
        
        # Make backup of original config if it doesn't exist already
        if [ ! -f otel-collector-config-with-sampling.yaml.original ]; then
            cp otel-collector-config-with-sampling.yaml otel-collector-config-with-sampling.yaml.original
        fi
        
        # Set config file to use Splunk version
        cp otel-collector-config-with-sampling-splunk.yaml otel-collector-config-with-sampling.yaml
        
        # Only restart the collector service to preserve Jaeger trace data
        export CONFIG_TYPE=with
        # Use a single environment name but distinct service names based on CONFIG_TYPE
        export ENVIRONMENT="tail-sampling-demo"
        export SPLUNK_ACCESS_TOKEN=$SPLUNK_ACCESS_TOKEN
        export SPLUNK_REALM=$SPLUNK_REALM
        
        docker compose stop otel-collector order-service
        # Pass CONFIG_TYPE and ENVIRONMENT variables explicitly
        CONFIG_TYPE=with SPLUNK_ACCESS_TOKEN=$SPLUNK_ACCESS_TOKEN SPLUNK_REALM=$SPLUNK_REALM docker compose up -d otel-collector order-service
        
        # Set current state
        CURRENT_CONFIG="with"
        SPLUNK_ENABLED="true"
        
        echo -e "${GREEN}Successfully switched to tail sampling with Splunk export!${NC}"
        echo "Wait a moment for services to fully restart..."
        ;;
        
    "splunk-no-tail")
        echo -e "${BLUE}Switching to${NC} no tail sampling with Splunk export..."
        
        # Check Splunk credentials
        check_splunk_env
        
        # Make backup of original config if it doesn't exist already
        if [ ! -f otel-collector-config-no-sampling.yaml.original ]; then
            cp otel-collector-config-no-sampling.yaml otel-collector-config-no-sampling.yaml.original
        fi
        
        # Set config file to use Splunk version
        cp otel-collector-config-no-sampling-splunk.yaml otel-collector-config-no-sampling.yaml
        
        # Only restart the collector service to preserve Jaeger trace data
        export CONFIG_TYPE=no
        # Use a single environment name but distinct service names based on CONFIG_TYPE
        export ENVIRONMENT="tail-sampling-demo"
        export SPLUNK_ACCESS_TOKEN=$SPLUNK_ACCESS_TOKEN
        export SPLUNK_REALM=$SPLUNK_REALM
        
        docker compose stop otel-collector order-service
        # Pass CONFIG_TYPE and ENVIRONMENT variables explicitly
        CONFIG_TYPE=no SPLUNK_ACCESS_TOKEN=$SPLUNK_ACCESS_TOKEN SPLUNK_REALM=$SPLUNK_REALM docker compose up -d otel-collector order-service
        
        # Set current state
        CURRENT_CONFIG="no"
        SPLUNK_ENABLED="true"
        
        echo -e "${GREEN}Successfully switched to no tail sampling with Splunk export!${NC}"
        echo "Wait a moment for services to fully restart..."
        ;;
        
    "status")
        show_status
        ;;
        
    *)
        echo -e "${YELLOW}Unknown option:${NC} $1"
        echo -e "${YELLOW}Usage:${NC} $0 [tail|no-tail|splunk-tail|splunk-no-tail|status]"
        exit 1
        ;;
esac

# No backup functionality needed

# Show status if this isn't just a status request
if [ "$1" != "status" ]; then
    echo
    show_status

    echo
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Run './generate_load.sh' to generate traces"
    echo "2. Visit Jaeger UI to see results: http://localhost:16686"
fi

# If Splunk is enabled, add Splunk-specific information
if grep -q "^    traces/splunk:" "otel-collector-config-${CONFIG_TYPE}-sampling.yaml" 2>/dev/null; then
    echo "3. View traces in Splunk Observability Cloud:"
    echo "   - Log in to your Splunk account"
    echo "   - Navigate to APM > Traces"
fi
