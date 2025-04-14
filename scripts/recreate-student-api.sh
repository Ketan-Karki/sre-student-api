#!/bin/bash

NAMESPACE="student-api"
DEPLOYMENT="student-api"

echo "=== Recreating Student API Deployment ==="

# Delete the deployment completely
echo "Deleting existing deployment..."
kubectl delete deployment $DEPLOYMENT -n $NAMESPACE

# Apply the updated Helm chart
echo "Applying updated Helm chart..."
helm upgrade --install student-api ./helm-charts/student-api-helm -n $NAMESPACE

# Wait for new pod to become ready
echo "Waiting for new pod to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=student-api -n $NAMESPACE --timeout=60s

# Check if the service endpoints are updated
echo "Checking service endpoints..."
kubectl get endpoints -n $NAMESPACE student-api

# Test connectivity
echo "Testing connectivity..."
POD_NAME=$(kubectl get pod -n $NAMESPACE -l app.kubernetes.io/name=student-api -o name | head -1)
if [ -n "$POD_NAME" ]; then
  echo "Testing from pod $POD_NAME..."
  kubectl exec -n $NAMESPACE $POD_NAME -- curl -s localhost:8080/health || echo "Health endpoint not responding"
else
  echo "No student-api pod found"
fi

echo "=== Recreation Complete ==="
