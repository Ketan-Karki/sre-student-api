#!/bin/bash
# Script to debug Blackbox exporter connectivity issues

set -e

NAMESPACE="student-api"
POD_NAME=$(kubectl get pod -n $NAMESPACE -l app=blackbox-exporter -o name | head -1 | sed 's|pod/||')

if [ -z "$POD_NAME" ]; then
  echo "❌ No Blackbox exporter pod found"
  exit 1
fi

echo "Found Blackbox exporter pod: $POD_NAME"

# Check if the services exist
echo -e "\n--- Checking student-api services ---"
kubectl get svc -n $NAMESPACE student-api 2>/dev/null && echo "✅ student-api service exists" || echo "❌ student-api service doesn't exist"
kubectl get svc -n $NAMESPACE nginx-service 2>/dev/null && echo "✅ nginx-service exists" || echo "❌ nginx-service doesn't exist"
kubectl get svc -n $NAMESPACE postgres-service 2>/dev/null && echo "✅ postgres-service exists" || echo "❌ postgres-service doesn't exist"

# Check endpoints for the services
echo -e "\n--- Checking service endpoints ---"
echo "student-api endpoints:"
kubectl get endpoints -n $NAMESPACE student-api -o yaml | grep -A10 "subsets:"
echo "nginx-service endpoints:"
kubectl get endpoints -n $NAMESPACE nginx-service -o yaml | grep -A10 "subsets:"
echo "postgres-service endpoints:"
kubectl get endpoints -n $NAMESPACE postgres-service -o yaml | grep -A10 "subsets:"

# Check connectivity from inside the Blackbox exporter pod
echo -e "\n--- Testing network connectivity from Blackbox exporter ---"
echo "Testing connection to student-api:8080..."
kubectl exec -n $NAMESPACE $POD_NAME -- wget -T 2 -O- --quiet http://student-api:8080/ || echo "❌ Could not connect to student-api:8080"

echo "Testing connection to nginx-service:80..."
kubectl exec -n $NAMESPACE $POD_NAME -- wget -T 2 -O- --quiet http://nginx-service:80/ || echo "❌ Could not connect to nginx-service:80"

echo "Testing connection to postgres-service:5432..."
kubectl exec -n $NAMESPACE $POD_NAME -- timeout 2 bash -c "</dev/tcp/postgres-service/5432" && echo "✅ TCP connection to postgres-service:5432 successful" || echo "❌ TCP connection to postgres-service:5432 failed"

# Check the actual Blackbox configuration being used
echo -e "\n--- Current Blackbox configuration ---"
kubectl exec -n $NAMESPACE $POD_NAME -- cat /etc/blackbox_exporter/blackbox.yml

echo -e "\n--- Recommendations ---"
echo "1. Verify that the student-api and nginx pods are actually serving HTTP traffic"
echo "2. Try testing HTTP endpoints directly from another pod:"
echo "   kubectl run -n $NAMESPACE curl --image=curlimages/curl --restart=Never --rm -it -- curl http://student-api:8080/"
echo "3. Verify health endpoints exist for your applications"
echo "4. Check for any firewall or network policy restrictions"
