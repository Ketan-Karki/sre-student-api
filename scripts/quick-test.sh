#!/bin/bash

NAMESPACE="student-api"

echo "=== Quick Test ==="

# Apply configuration changes
echo "Applying configuration..."
helm upgrade student-api ./helm-charts/student-api-helm -n $NAMESPACE --force

# Force restart the pod
echo "Forcing restart of student-api pod..."
kubectl delete pod -n $NAMESPACE -l app=student-api --force --grace-period=0

# Wait for new pod
echo "Waiting for pod..."
sleep 10
POD_NAME=$(kubectl get pods -n $NAMESPACE -l app=student-api -o name | head -1)

if [ -n "$POD_NAME" ]; then
  echo "Pod is starting: $POD_NAME"
  kubectl wait --for=condition=ready $POD_NAME -n $NAMESPACE --timeout=60s
  
  # Check the nginx configuration
  echo "Checking nginx configuration..."
  kubectl exec -n $NAMESPACE $POD_NAME -- cat /etc/nginx/conf.d/default.conf
  
  # Test the endpoints
  echo "Testing health endpoint..."
  kubectl exec -n $NAMESPACE $POD_NAME -- curl -s localhost:8080/health
  
  # Check service connection
  echo "Testing service connectivity..."
  kubectl run -n $NAMESPACE curl-test --image=curlimages/curl --rm -it -- \
    sh -c "curl -s student-api:8080/health; echo"
else
  echo "No pod found!"
fi

echo "=== Test Complete ==="
