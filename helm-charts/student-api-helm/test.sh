#!/bin/bash

# Set up error handling
set -e

# Check environment
NAMESPACE=${NAMESPACE:-student-api}
PORT=${PORT:-80}  # Changed to 80 for nginx
TEST_PORT=${TEST_PORT:-8888}  # Use a different port for testing
TIMEOUT=${TIMEOUT:-60s}

# Output configuration
echo "Testing with configuration:"
echo "  Namespace: $NAMESPACE"
echo "  API Port: $PORT"
echo "  Test Port: $TEST_PORT" 
echo "  Timeout: $TIMEOUT"

# Wait for the deployment to be ready
echo "Waiting for deployment to be ready..."
kubectl wait --for=condition=available deployment/nginx -n $NAMESPACE --timeout=$TIMEOUT

# Set up port forwarding using TEST_PORT locally to avoid conflicts
echo "Setting up port forwarding..."
kubectl port-forward svc/nginx-service -n $NAMESPACE $TEST_PORT:$PORT &
PF_PID=$!

# Give port forwarding time to establish
sleep 5

# Use TEST_PORT for testing
SERVICE_URL="http://localhost:$TEST_PORT"
echo "Service URL: $SERVICE_URL"

# Check if service is accessible
echo "Checking if service is accessible..."
RETRY_COUNT=0
MAX_RETRIES=10
until curl -s --head $SERVICE_URL/ > /dev/null 2>&1; do  
  RETRY_COUNT=$((RETRY_COUNT+1))
  if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
    echo "Service not accessible after $MAX_RETRIES attempts. Exiting."
    kill $PF_PID || true
    exit 1
  fi
  echo "Waiting for service to be accessible (attempt $RETRY_COUNT of $MAX_RETRIES)..."
  sleep 5
done

# Test endpoints - Modified for nginx
echo -e "\n1. Testing root endpoint (should return nginx welcome page)"
curl -s -w "\nStatus: %{http_code}\n" $SERVICE_URL/

echo -e "\nAPI tests completed. Check the responses above."

# Clean up
kill $PF_PID || true
