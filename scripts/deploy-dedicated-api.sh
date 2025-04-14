#!/bin/bash

NAMESPACE="student-api"

echo "=== Deploying Dedicated API Service ==="

# Delete existing resources
echo "Cleaning up existing resources..."
kubectl delete deployment student-api -n $NAMESPACE --ignore-not-found=true
kubectl delete service student-api -n $NAMESPACE --ignore-not-found=true
kubectl delete configmap api-direct-config -n $NAMESPACE --ignore-not-found=true

# Apply the updated configuration
echo "Applying updated configuration..."
helm upgrade --install student-api ./helm-charts/student-api-helm -n $NAMESPACE --atomic

# Wait for the pod to be ready
echo "Waiting for the pod to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=student-api -n $NAMESPACE --timeout=60s || echo "Timeout waiting for pod"

# Test the service
echo "Testing service connectivity..."
kubectl run test-api -n $NAMESPACE --image=curlimages/curl --restart=Never --rm -it -- sh -c '
  echo "Testing / endpoint:"
  curl -s student-api:8080/
  echo -e "\n\nTesting /health endpoint:"
  curl -s student-api:8080/health
  echo -e "\n\nTesting /metrics endpoint:"
  curl -s student-api:8080/metrics
' || echo "Service test failed"

echo "=== Deployment Complete ==="
