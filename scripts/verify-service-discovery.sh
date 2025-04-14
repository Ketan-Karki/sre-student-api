#!/bin/bash

NAMESPACE="student-api"

echo "=== Verifying Service Discovery ==="

# Check service endpoints
echo "Checking service endpoints..."
kubectl get endpoints -n $NAMESPACE student-api

# Test service discovery
echo "Testing service discovery..."
kubectl run -n $NAMESPACE test-curl --image=curlimages/curl --rm -it --restart=Never -- \
  curl -s -o /dev/null -w "%{http_code}" http://student-api:8080/health

# Check blackbox exporter config
echo "Checking Blackbox Exporter targets..."
kubectl get cm -n $NAMESPACE blackbox-exporter-config -o yaml | grep -A 5 "targets:"

echo "=== Verification Complete ==="
