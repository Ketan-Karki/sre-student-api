#!/bin/bash

# Wait for the deployment to be ready
echo "Waiting for deployment to be ready..."
kubectl wait --for=condition=available deployment/student-api -n student-api --timeout=60s

# Use localhost:8080 for testing
SERVICE_URL="http://localhost:8080"
echo "Service URL: $SERVICE_URL"

# Test endpoints
echo -e "\n1. Testing GET /api/v1/students (should be empty initially)"
curl -s -w "\nStatus: %{http_code}\n" $SERVICE_URL/api/v1/students

echo -e "\n2. Testing POST /api/v1/students (creating a new student)"
curl -s -w "\nStatus: %{http_code}\n" -X POST $SERVICE_URL/api/v1/students \
    -H "Content-Type: application/json" \
    -d '{"name":"Test Student","age":20,"grade":"A+"}'

echo -e "\n3. Testing GET /api/v1/students again (should show the new student)"
curl -s -w "\nStatus: %{http_code}\n" $SERVICE_URL/api/v1/students

echo -e "\nAPI tests completed. Check the responses above."
