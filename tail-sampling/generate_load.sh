#!/bin/bash

# Configuration
NUM_REQUESTS=${1:-100}  # Default to 100 requests if not specified
DELAY=${2:-0.05}        # Default delay between requests (seconds)
URL="http://localhost:5000/checkout"

# Print header
echo "========================================="
echo "Generating $NUM_REQUESTS requests to $URL"
echo "Delay between requests: $DELAY seconds"
echo "========================================="
echo ""

# Initialize counters
success=0
errors=0
total=0

# Function to send request and process response
send_request() {
    response=$(curl -s -w "%{http_code}" -o /dev/null "$URL")
    total=$((total+1))
    
    if [ "$response" == "200" ]; then
        success=$((success+1))
        echo -ne "Requests: $total/$NUM_REQUESTS | Success: $success | Errors: $errors\r"
    else
        errors=$((errors+1))
        echo -ne "Requests: $total/$NUM_REQUESTS | Success: $success | Errors: $errors\r"
    fi
}

# Generate load
start_time=$(date +%s)
echo "Starting load generation at $(date)"

for i in $(seq 1 "$NUM_REQUESTS"); do
    send_request
    sleep "$DELAY"
done

end_time=$(date +%s)
duration=$((end_time - start_time))

# Print summary
echo -e "\n"
echo "========== Load Test Complete =========="
echo "Total requests: $total"
echo "Successful requests: $success"
echo "Failed requests: $errors"
echo "Error rate: $(echo "scale=2; $errors/$total*100" | bc -l)%"
echo "Total duration: $duration seconds"
echo "========================================"

echo -e "\nTip: View the traces in Jaeger UI at http://localhost:16686"
