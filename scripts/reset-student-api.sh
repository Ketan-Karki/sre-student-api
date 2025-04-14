#!/bin/bash

NAMESPACE="student-api"

echo "=== Full Reset of Student API ==="

# Delete deployments and services
echo "Deleting all student-api resources..."
kubectl delete deployment,service student-api -n $NAMESPACE

# Apply updated configuration
echo "Applying updated configuration..."
helm upgrade --install student-api ./helm-charts/student-api-helm -n $NAMESPACE

# Wait for pod to be ready
echo "Waiting for new pods (this may take a moment)..."
sleep 10

# Check labels
echo "Checking pod labels:"
kubectl get pods -n $NAMESPACE --show-labels

# Wait for pod to be ready
echo "Waiting for pod to be ready..."
kubectl wait --for=condition=ready pod -l app=student-api -n $NAMESPACE --timeout=60s || echo "Timeout waiting for pod"

# Check service
echo "Checking service endpoints:"
kubectl get endpoints -n $NAMESPACE student-api

# Test connectivity with curl
echo "Testing service connectivity:"
kubectl run test-curl -n $NAMESPACE --image=curlimages/curl --rm -it --restart=Never -- curl -v student-api:8080/health || echo "Connection test failed"

echo "=== Reset Complete ==="
