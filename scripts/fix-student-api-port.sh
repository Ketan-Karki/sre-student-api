#!/bin/bash

NAMESPACE="student-api"

echo "=== Fixing Student API Port ==="

# Delete the deployment and service
echo "Deleting existing resources..."
kubectl delete deployment,service student-api -n $NAMESPACE

# Apply the updated Helm chart
echo "Applying Helm changes..."
helm upgrade --install student-api ./helm-charts/student-api-helm -n $NAMESPACE

# Wait for the pod to be ready
echo "Waiting for pod to be ready..."
sleep 10
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=student-api -n $NAMESPACE --timeout=60s || echo "Timeout waiting for pod"

# Get pod details
echo "Pod details:"
STUDENT_POD=$(kubectl get pod -n $NAMESPACE -l app.kubernetes.io/name=student-api -o name | head -1)
if [ -n "$STUDENT_POD" ]; then
  echo "Pod: $STUDENT_POD"
  kubectl describe pod -n $NAMESPACE ${STUDENT_POD#pod/}
  
  # Check container port
  echo "Container ports:"
  kubectl get pod -n $NAMESPACE ${STUDENT_POD#pod/} -o jsonpath='{.spec.containers[0].ports[*]}' | jq
fi

# Test service connection
echo "Testing service connection..."
kubectl run test-svc -n $NAMESPACE --image=curlimages/curl --restart=Never --rm -it -- curl -v student-api:8080 || echo "Service test failed"

echo "=== Fix Complete ==="
