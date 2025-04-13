#!/bin/bash

set -e

NAMESPACE=${1:-$(kubectl get ns | grep -E "pg-[0-9]+" | head -1 | awk '{print $1}')}
TIMEOUT=30

if [ -z "$NAMESPACE" ]; then
  echo "❌ No valid namespace found. Please specify a namespace."
  exit 1
fi

echo "=== Testing PostgreSQL Metrics Exporter ==="
echo "Using namespace: $NAMESPACE"

# Check if postgres pod is running with exporter
echo "1. Checking postgres-exporter container..."
POD_NAME=$(kubectl get pod -n $NAMESPACE -l app=postgres -o name 2>/dev/null | head -1 | sed 's|pod/||')

if [ -z "$POD_NAME" ]; then
    echo "❌ No postgres pods found"
    echo "Available pods:"
    kubectl get pods -n $NAMESPACE
    exit 1
fi

echo "Found postgres pod: $POD_NAME"

# Check if the pod is running
POD_STATUS=$(kubectl get pod -n $NAMESPACE $POD_NAME -o jsonpath='{.status.phase}' 2>/dev/null)
if [ "$POD_STATUS" != "Running" ]; then
    echo "❌ Pod $POD_NAME is not running (status: $POD_STATUS)"
    kubectl describe pod -n $NAMESPACE $POD_NAME
    exit 1
fi

# Check containers in pod
CONTAINERS=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.spec.containers[*].name}' 2>/dev/null)
echo "Pod has containers: $CONTAINERS"

# Check for postgres-exporter container
if ! echo "$CONTAINERS" | grep -q postgres-exporter; then
    echo "❌ postgres-exporter container not found in pod $POD_NAME"
    exit 1
fi

echo "✅ postgres-exporter container exists"

# Test metrics endpoint
echo -e "\n2. Testing metrics endpoint..."
kubectl port-forward -n $NAMESPACE pod/$POD_NAME 9187:9187 &
PF_PID=$!
sleep 5

curl -s localhost:9187/metrics > /dev/null
if [ $? -eq 0 ]; then
    echo "✅ Metrics endpoint is accessible"
    
    # Show metrics sample
    echo -e "\nSample metrics:"
    curl -s localhost:9187/metrics | grep -E "^pg_up|^pg_stat_database_numbackends" | head -5
else
    echo "❌ Cannot access metrics endpoint"
fi

# Cleanup
kill $PF_PID 2>/dev/null || true
echo -e "\n=== Test Complete ==="
