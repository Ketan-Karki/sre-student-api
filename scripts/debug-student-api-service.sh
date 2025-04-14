#!/bin/bash

NAMESPACE="student-api"

echo "=== Debugging Student API Service ==="

# Get all pods in the namespace
echo "Current pods:"
kubectl get pods -n $NAMESPACE --show-labels

# Get details about the student-api service
echo -e "\nService details:"
kubectl get service student-api -n $NAMESPACE -o yaml

# Check service endpoints
echo -e "\nService endpoints:"
kubectl get endpoints student-api -n $NAMESPACE -o yaml

# Direct test to the pod IP
echo -e "\nDirect test to the student-api pod:"
STUDENT_POD=$(kubectl get pod -n $NAMESPACE -l app.kubernetes.io/name=student-api,pod-template-hash=84f47455f5 -o name | grep -v nginx | head -1)
if [ -n "$STUDENT_POD" ]; then
  POD_IP=$(kubectl get ${STUDENT_POD} -n $NAMESPACE -o jsonpath='{.status.podIP}')
  echo "Testing direct connection to ${POD_IP}:8080"
  kubectl run test-direct -n $NAMESPACE --image=curlimages/curl --rm -it --restart=Never -- curl -v ${POD_IP}:8080/health
else
  echo "No student-api pod found!"
fi

# Fix the service by patching it
echo -e "\nPatching student-api service to target the correct pod:"
kubectl patch service student-api -n $NAMESPACE --type='json' -p='[{"op": "replace", "path": "/spec/selector", "value": {"pod-template-hash": "84f47455f5"}}]'

# Test the service after patching
echo -e "\nTesting the service after patching:"
kubectl run test-service -n $NAMESPACE --image=curlimages/curl --rm -it --restart=Never -- curl -v student-api:8080/health

echo "=== Debugging Complete ==="
