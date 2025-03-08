#!/bin/bash

# Set up error handling
set -e

# Check environment
NAMESPACE=${NAMESPACE:-student-api}
PORT=${PORT:-8080}
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
kubectl wait --for=condition=available deployment/student-api -n $NAMESPACE --timeout=$TIMEOUT

# Set up port forwarding using TEST_PORT locally to avoid conflicts
echo "Setting up port forwarding..."
kubectl port-forward svc/student-api -n $NAMESPACE $TEST_PORT:$PORT &
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
until curl -s --head $SERVICE_URL/api/v1/healthcheck > /dev/null 2>&1; do
  RETRY_COUNT=$((RETRY_COUNT+1))
  if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
    echo "Service not accessible after $MAX_RETRIES attempts. Exiting."
    kill $PF_PID || true
    exit 1
  fi
  echo "Waiting for service to be accessible (attempt $RETRY_COUNT of $MAX_RETRIES)..."
  sleep 5
done

# Test endpoints
echo -e "\n1. Testing GET /api/v1/students (should be empty initially)"
curl -s -w "\nStatus: %{http_code}\n" $SERVICE_URL/api/v1/students

echo -e "\n2. Testing POST /api/v1/students (creating a new student)"
curl -s -w "\nStatus: %{http_code}\n" -X POST $SERVICE_URL/api/v1/students \
    -H "Content-Type: application/json" \
    -d '{"name":"Test Student","age":20,"grade":"A+"}'

echo -e "\n3. Testing GET /api/v1/students again (should show the new student)"
curl -s -w "\nStatus: %{http_code}\n" $SERVICE_URL/api/v1/students

echo -e "\n4. Testing healthcheck endpoint"
curl -s -w "\nStatus: %{http_code}\n" $SERVICE_URL/api/v1/healthcheck

echo -e "\nAPI tests completed. Check the responses above."

# Clean up
kill $PF_PID || true
