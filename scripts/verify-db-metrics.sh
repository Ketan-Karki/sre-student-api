#!/bin/bash

set -e

NAMESPACE=${1:-$(kubectl get ns | grep -E "ns-[0-9]+" | head -1 | awk '{print $1}')}
TIMEOUT=30

if [ -z "$NAMESPACE" ]; then
  echo "❌ No valid namespace found. Please specify a namespace."
  exit 1
fi

echo "=== Verifying PostgreSQL Metrics Exporter ==="
echo "Using namespace: $NAMESPACE"

# Check if postgres pod is running
echo "1. Checking postgres pod with exporter..."
POSTGRES_POD=$(kubectl get pod -n $NAMESPACE -l app=postgres -o name | head -1 | sed 's|pod/||')

if [ -z "$POSTGRES_POD" ]; then
  echo "❌ No postgres pods found"
  exit 1
fi

echo "Found postgres pod: $POSTGRES_POD"

# Check if postgres-exporter container is running
EXPORTER_RUNNING=$(kubectl get pod -n $NAMESPACE $POSTGRES_POD -o jsonpath='{.status.containerStatuses[?(@.name=="postgres-exporter")].ready}')
if [ "$EXPORTER_RUNNING" != "true" ]; then
  echo "❌ postgres-exporter container is not ready"
  kubectl describe pod -n $NAMESPACE $POSTGRES_POD
  exit 1
fi

echo "✅ postgres-exporter container is running"

# Check the metrics endpoint
echo "2. Testing metrics endpoint..."
echo "Setting up port-forward to pod $POSTGRES_POD..."
kubectl port-forward -n $NAMESPACE pod/$POSTGRES_POD 9187:9187 > /dev/null 2>&1 &
PF_PID=$!
sleep 2

echo "Checking metrics endpoint..."
if ! curl -s http://localhost:9187/metrics > /dev/null; then
  echo "❌ Failed to access metrics endpoint"
  kill $PF_PID 2>/dev/null || true
  exit 1
fi

echo "✅ Metrics endpoint accessible!"

# Display key PostgreSQL metrics
echo "3. Displaying key PostgreSQL metrics..."
curl -s http://localhost:9187/metrics | grep -E "^pg_up|^pg_stat_database_numbackends|^pg_settings_|^pg_stat_activity_" | head -10

# Clean up
kill $PF_PID 2>/dev/null || true

echo "=== Verification Complete ==="
echo "PostgreSQL Exporter is working correctly!"
echo "You can view additional metrics by running:"
echo "  kubectl port-forward -n $NAMESPACE pod/$POSTGRES_POD 9187:9187"
echo "  curl http://localhost:9187/metrics"
