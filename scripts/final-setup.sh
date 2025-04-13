#!/bin/bash

set -e

echo "=== FINAL POSTGRESQL MONITORING SETUP ==="

# Generate timestamp for uniqueness
TIMESTAMP=$(date +%s)
UNIQUE_RELEASE="postgres-$TIMESTAMP"
NAMESPACE="db-$TIMESTAMP"

echo "1. Creating namespace $NAMESPACE..."
kubectl create namespace $NAMESPACE
kubectl label namespace $NAMESPACE app.kubernetes.io/managed-by=Helm

echo "2. Installing chart with postgres-exporter..."
helm install $UNIQUE_RELEASE ./helm-charts/student-api-helm -n $NAMESPACE \
  --set postgres.image.tag=15.3 \
  --set postgres.persistence.forceEmptyDir=true \
  --set postgres.exporter.image.repository=bitnami/postgres-exporter \
  --set postgres.exporter.image.tag=0.10.1 \
  --set namespace.name=$NAMESPACE \
  --set studentApi.image.repository=nginx \
  --set studentApi.image.tag=latest

echo "3. Waiting for pods to start (30 seconds)..."
sleep 30

echo "4. Checking pods..."
kubectl get pods -n $NAMESPACE

echo "5. Verifying postgres-exporter metrics..."
POSTGRES_POD=$(kubectl get pod -n $NAMESPACE -l app=postgres -o name | head -1 | sed 's|pod/||')
if [ -z "$POSTGRES_POD" ]; then
  echo "❌ No postgres pods found"
  exit 1
fi

echo "Found postgres pod: $POSTGRES_POD"

echo "6. Setting up port forwarding to access metrics..."
kubectl port-forward -n $NAMESPACE pod/$POSTGRES_POD 9187:9187 &
PF_PID=$!
sleep 3

echo "7. Checking metrics availability..."
curl -s -m 3 -o /dev/null -w "%{http_code}" http://localhost:9187/metrics
if [ $? -eq 0 ]; then
  echo "✅ Metrics endpoint is accessible!"
  echo "Some sample metrics:"
  curl -s http://localhost:9187/metrics | grep -E "^pg_up|^pg_stat_database_numbackends" | head -5
else
  echo "❌ Failed to access metrics endpoint"
fi

# Clean up
kill $PF_PID 2>/dev/null || true

echo "=== SETUP COMPLETE ==="
echo "Namespace: $NAMESPACE"
echo "Release: $UNIQUE_RELEASE"
echo ""
echo "To view PostgreSQL metrics:"
echo "  kubectl port-forward -n $NAMESPACE pod/$POSTGRES_POD 9187:9187"
echo "  curl http://localhost:9187/metrics"
