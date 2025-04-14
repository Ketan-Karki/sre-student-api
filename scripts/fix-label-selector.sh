#!/bin/bash

NAMESPACE="student-api"

echo "=== Fixing Label Selector ==="

# Check pod labels
echo "Checking pod labels..."
kubectl get pods -n $NAMESPACE --show-labels

# Get current deployment yaml
echo "Checking deployment..."
kubectl get deployment student-api -n $NAMESPACE -o yaml > /tmp/student-api-deployment.yaml

# Apply label to existing pod
echo "Applying label to running pod..."
POD_NAME=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=student-api -o name | head -1)
if [ -n "$POD_NAME" ]; then
  echo "Found pod: $POD_NAME"
  kubectl label $POD_NAME -n $NAMESPACE app=student-api --overwrite
else
  echo "No student-api pod found with app.kubernetes.io/name=student-api label"
fi

# Test connection to the service
echo "Testing connection to student-api service..."
kubectl run curl-test -n $NAMESPACE --image=curlimages/curl --restart=Never -- \
  sh -c "curl -v http://student-api:8080/health || echo 'Connection failed'"

echo "Waiting for test pod..."
sleep 10

echo "Pod logs:"
kubectl logs -n $NAMESPACE curl-test

# Cleanup
echo "Cleaning up..."
kubectl delete pod -n $NAMESPACE curl-test --ignore-not-found=true

echo "=== Fix Complete ==="
