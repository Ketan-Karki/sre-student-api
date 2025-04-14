#!/bin/bash

NAMESPACE="student-api"

echo "=== Testing Service Connectivity ==="

# Create a test pod that stays alive
kubectl run test-pod -n $NAMESPACE --image=nginx --restart=Never

# Wait for pod to be ready
echo "Waiting for test pod..."
kubectl wait --for=condition=ready pod/test-pod -n $NAMESPACE --timeout=30s

# Test endpoints
echo "Testing student-api endpoints..."
kubectl exec -n $NAMESPACE test-pod -- curl -v http://student-api:8080/health
kubectl exec -n $NAMESPACE test-pod -- curl -v http://student-api:8080/metrics

# Clean up
echo "Cleaning up..."
kubectl delete pod test-pod -n $NAMESPACE

echo "=== Test Complete ==="
