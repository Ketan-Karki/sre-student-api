#!/bin/bash

NAMESPACE="student-api"

echo "=== Patching Student API Service ==="

# Check existing nginx pods
echo "Checking nginx pods:"
kubectl get pods -n $NAMESPACE -l app=nginx

# Patch the service to target nginx pods
echo "Patching service to target nginx pods:"
kubectl patch svc student-api -n $NAMESPACE --type='json' -p='[{"op": "replace", "path": "/spec/selector", "value": {"app": "nginx"}}]'

# Patch the service to use correct targetPort
echo "Patching service targetPort:"
kubectl patch svc student-api -n $NAMESPACE --type='json' -p='[{"op": "replace", "path": "/spec/ports/0/targetPort", "value": 80}]'

# Check the service after patching
echo "Service details after patching:"
kubectl get svc student-api -n $NAMESPACE -o yaml

# Test the service
echo "Testing service connectivity:"
kubectl run -n $NAMESPACE test-nginx --image=curlimages/curl --restart=Never --rm -it -- curl -v student-api:8080/

echo "=== Patching Complete ==="
