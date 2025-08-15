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
    if [ -n "$CONFIG_TYPE" ]; then
        if [[ "$CONFIG_TYPE" == "with" ]]; then
            echo -e "${BLUE}Current configuration:${NC} With tail sampling"
        else
            echo -e "${BLUE}Current configuration:${NC} No tail sampling"
        fi
    else
        echo -e "${YELLOW}Warning:${NC} CONFIG_TYPE not set, defaulting to no-tail sampling"
    fi
}

case "$1" in
    "tail")
        echo -e "${BLUE}Switching to${NC} tail sampling configuration..."
        
        # Restart the services with tail sampling config type
        CONFIG_TYPE=with docker compose down
        CONFIG_TYPE=with docker compose up -d
        
        # Set the environment variable for the current session
        export CONFIG_TYPE=with
        
        echo -e "${GREEN}Successfully switched to tail sampling configuration!${NC}"
        echo "Wait a moment for services to fully restart..."
        ;;
        
    "no-tail")
        echo -e "${BLUE}Switching to${NC} no tail sampling configuration..."
        
        # Restart the services with no-tail config type
        CONFIG_TYPE=no docker compose down
        CONFIG_TYPE=no docker compose up -d
        
        # Set the environment variable for the current session
        export CONFIG_TYPE=no
        
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
