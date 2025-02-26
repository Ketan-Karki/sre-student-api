#!/bin/bash

# Function to wait for pod readiness
wait_for_api() {
    echo "Waiting for API to be ready..."
    kubectl wait --for=condition=ready pod -l app=student-api -n student-api --timeout=60s
}

# Wait for API readiness
wait_for_api

# Port forward with error handling
echo "Setting up port forwarding..."
kubectl port-forward -n student-api svc/student-api 8080:8080 &
PF_PID=$!

# Wait for port-forward to be ready
echo "Waiting for port-forward to be ready..."
for i in {1..10}; do
    if curl -s http://localhost:8080/api/v1/healthcheck > /dev/null; then
        echo "Port-forward is ready"
        break
    fi
    if [ $i -eq 10 ]; then
        echo "Port-forward failed to become ready"
        kill $PF_PID
        exit 1
    fi
    sleep 2
done

# Run tests
make test-api-k8s

# Clean up
kill $PF_PID
