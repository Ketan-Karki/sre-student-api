#!/bin/bash

NAMESPACE="student-api"

echo "=== Debugging Student API ==="

# Force restart student-api
echo "Restarting student-api deployment..."
kubectl delete pod -n $NAMESPACE -l app=student-api --force --grace-period=0 || true

echo "Applying configuration..."
helm upgrade --install student-api ./helm-charts/student-api-helm -n $NAMESPACE

echo "Waiting for pod to start..."
sleep 5

# Get pod name
POD_NAME=$(kubectl get pod -n $NAMESPACE -l app=student-api -o name | head -1)
if [ -z "$POD_NAME" ]; then
  echo "No student-api pod found. Checking pods with all labels..."
  kubectl get pods -n $NAMESPACE --show-labels
  exit 1
fi

echo "Found pod: $POD_NAME"

# Check pod details
echo "Pod details:"
kubectl describe pod -n $NAMESPACE ${POD_NAME#pod/}

# Check if nginx is running
echo "Checking nginx process:"
kubectl exec -n $NAMESPACE ${POD_NAME#pod/} -- ps aux || echo "Failed to check processes"

# Check port binding
echo "Checking port binding:"
kubectl exec -n $NAMESPACE ${POD_NAME#pod/} -- netstat -tulpn || echo "netstat not available"

# Check if nginx configuration is valid
echo "Checking nginx configuration:"
kubectl exec -n $NAMESPACE ${POD_NAME#pod/} -- nginx -t || echo "Failed to check nginx config"

# Check the service configuration
echo "Checking service configuration:"
kubectl get svc -n $NAMESPACE student-api -o yaml

echo "=== Debug Complete ==="
