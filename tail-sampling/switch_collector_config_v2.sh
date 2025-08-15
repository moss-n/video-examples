#!/bin/bash

set -e

# Define colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default to help if no arguments provided
if [ $# -eq 0 ]; then
    echo -e "${YELLOW}Usage:${NC} $0 [tail|no-tail|status]"
    echo
    echo "Options:"
    echo "  tail    - Switch to configuration with tail sampling"
    echo "  no-tail - Switch to configuration without tail sampling"
    echo "  status  - Show current configuration"
    exit 1
fi

# Function to display status
show_status() {
    if [ -L "otel-collector-config.yaml" ]; then
        current=$(readlink otel-collector-config.yaml)
        if [[ "$current" == *"no-sampling"* ]]; then
            echo -e "${BLUE}Current configuration:${NC} No tail sampling"
        else
            echo -e "${BLUE}Current configuration:${NC} With tail sampling"
        fi
    else
        echo -e "${YELLOW}Warning:${NC} otel-collector-config.yaml is not a symlink"
    fi
}

case "$1" in
    "tail")
        echo -e "${BLUE}Switching to${NC} tail sampling configuration..."
        if [ -f "otel-collector-config-with-sampling.yaml" ]; then
            # Save the original file if it's not a symlink
            if [ ! -L "otel-collector-config.yaml" ]; then
                cp otel-collector-config.yaml otel-collector-config-with-sampling.yaml
            fi
            
            # Remove existing symlink or file
            rm -f otel-collector-config.yaml
            
            # Create symlink
            ln -sf otel-collector-config-with-sampling.yaml otel-collector-config.yaml
            
            # Restart collector
            echo "Restarting collector..."
            docker compose restart otel-collector
            
            # Keep Jaeger running to preserve trace history
            echo "Preserving Jaeger trace history..."
            
            # Restart the order-service container with tail sampling config type
            echo "Ensuring order-service is running with CONFIG_TYPE=tail..."
            CONFIG_TYPE=tail docker compose up -d order-service
            
            echo -e "${GREEN}Successfully switched to tail sampling configuration!${NC}"
            echo "Wait a moment for services to fully restart..."
        else
            echo "Creating tail sampling config from existing config..."
            cp otel-collector-config.yaml otel-collector-config-with-sampling.yaml
            
            # Now switch to the new file
            rm -f otel-collector-config.yaml
            ln -sf otel-collector-config-with-sampling.yaml otel-collector-config.yaml
            
            # Restart collector
            echo "Restarting collector..."
            docker compose restart otel-collector
            
            # Keep Jaeger running to preserve trace history
            echo "Preserving Jaeger trace history..."
            
            # Restart the order-service container with tail sampling config type
            echo "Ensuring order-service is running with CONFIG_TYPE=tail..."
            CONFIG_TYPE=tail docker compose up -d order-service
            
            echo -e "${GREEN}Created and switched to tail sampling configuration!${NC}"
        fi
        ;;
        
    "no-tail")
        echo -e "${BLUE}Switching to${NC} no tail sampling configuration..."
        if [ ! -f "otel-collector-config-no-sampling.yaml" ]; then
            echo "Error: otel-collector-config-no-sampling.yaml not found"
            exit 1
        fi
        
        # Remove existing symlink or file
        rm -f otel-collector-config.yaml
        
        # Create symlink
        ln -sf otel-collector-config-no-sampling.yaml otel-collector-config.yaml
        
        # Restart collector
        echo "Restarting collector..."
        docker compose restart otel-collector
        
        # Keep Jaeger running to preserve trace history
        echo "Preserving Jaeger trace history..."
        
        # Restart the order-service container with no-tail config type
        echo "Ensuring order-service is running with CONFIG_TYPE=no-tail..."
        CONFIG_TYPE=no-tail docker compose up -d order-service
        
        echo -e "${GREEN}Successfully switched to no tail sampling configuration!${NC}"
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
echo "2. Visit Jaeger UI to see results: http://localhost:16686"
