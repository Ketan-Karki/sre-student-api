#!/bin/bash

NAMESPACE="student-api"

echo "=== Direct Fix for Student API ==="

# Check which port the pod is actually listening on
echo "Checking pod details..."
POD_NAME=$(kubectl get pod -n $NAMESPACE -l app=direct-api -o name | head -1)
if [ -n "$POD_NAME" ]; then
  echo "Found pod: $POD_NAME"
  echo "Checking what ports are open..."
  kubectl exec -n $NAMESPACE $POD_NAME -- netstat -tulpn || echo "netstat command not available"
  
  echo "Checking nginx configuration..."
  kubectl exec -n $NAMESPACE $POD_NAME -- cat /etc/nginx/conf.d/default.conf
  
  echo "Checking nginx process..."
  kubectl exec -n $NAMESPACE $POD_NAME -- ps aux | grep nginx
else
  echo "No pod found with label app=direct-api"
fi

# Fix the service to match the deployment
echo "Updating student-api service..."
kubectl patch svc student-api -n $NAMESPACE --type='json' -p='[{"op": "replace", "path": "/spec/selector", "value": {"app": "direct-api"}}]'

# Test the service - use port-forward for direct test
echo "Testing via port-forward..."
kubectl port-forward $POD_NAME 8080:80 -n $NAMESPACE &
PF_PID=$!
sleep 3
curl -v http://localhost:8080/health
kill $PF_PID

# Test the service via DNS
echo "Testing service via DNS..."
kubectl run test-dns -n $NAMESPACE --image=curlimages/curl --restart=Never --rm -i -- sh -c '
  echo "Checking DNS resolution..."
  nslookup student-api
  echo "Testing connection..."
  curl -v student-api:8080/health
  echo "Testing with specific connection parameters..."
  curl -v --connect-timeout 5 student-api.student-api.svc.cluster.local:8080/health
'

echo "=== Direct Fix Complete ==="
