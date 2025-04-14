#!/bin/bash

NAMESPACE="student-api"

echo "=== Clean Deployment of Student API ==="

# Delete existing deployment and any lingering pods
echo "Cleaning up existing resources..."
kubectl delete deployment student-api -n $NAMESPACE --ignore-not-found=true
kubectl delete pod -n $NAMESPACE -l app=student-api --force --grace-period=0 --ignore-not-found=true

# Apply the updated configuration
echo "Applying configuration..."
helm upgrade --install student-api ./helm-charts/student-api-helm -n $NAMESPACE

# Wait for pod to start
echo "Waiting for pods to start..."
kubectl get pods -n $NAMESPACE --watch &
WATCH_PID=$!

# Give it some time to start
sleep 20
kill $WATCH_PID

# Get pod information
POD=$(kubectl get pod -n $NAMESPACE -l app=student-api -o name | head -1)
if [ -n "$POD" ]; then
  echo "Pod is running: $POD"
  echo "Testing connectivity..."
  echo "Creating test pod..."
  kubectl run -n $NAMESPACE test-curl --image=curlimages/curl --restart=Never -- sleep 60

  # Wait for test pod to be ready
  kubectl wait --for=condition=ready pod/test-curl -n $NAMESPACE --timeout=30s

  # Test the connection
  echo "Testing service discovery and connectivity..."
  kubectl exec -n $NAMESPACE test-curl -- curl -v student-api:8080/health || echo "Connection failed"
  
  # Cleanup
  echo "Cleaning up test pod..."
  kubectl delete pod -n $NAMESPACE test-curl --force --grace-period=0
else
  echo "No student-api pod found!"
fi

echo "=== Deployment Complete ==="
