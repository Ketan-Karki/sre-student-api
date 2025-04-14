#!/bin/bash
# Script to debug HTTP services (student-api and nginx-service)

NAMESPACE="student-api"

echo "=== Debugging HTTP Services ==="

# Check student-api service
echo -e "\n--- Checking student-api service ---"
kubectl get svc -n $NAMESPACE student-api
kubectl get endpoints -n $NAMESPACE student-api

# Test HTTP connectivity to student-api
echo -e "\n--- Testing HTTP connectivity to student-api ---"
kubectl run -n $NAMESPACE curl-student-api --rm -it --image=curlimages/curl --restart=Never -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://student-api:8080 || echo "Connection failed"

# Check nginx-service
echo -e "\n--- Checking nginx-service ---"
kubectl get svc -n $NAMESPACE nginx-service
kubectl get endpoints -n $NAMESPACE nginx-service

# Test HTTP connectivity to nginx-service
echo -e "\n--- Testing HTTP connectivity to nginx-service ---"
kubectl run -n $NAMESPACE curl-nginx-service --rm -it --image=curlimages/curl --restart=Never -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://nginx-service || echo "Connection failed"

echo -e "\n=== Debugging Complete ==="
