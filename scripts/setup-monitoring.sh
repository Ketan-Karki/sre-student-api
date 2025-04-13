#!/bin/bash

set -e

echo "=== Setting up PostgreSQL Monitoring Environment ==="

# Generate timestamp for uniqueness
TIMESTAMP=$(date +%s)
UNIQUE_RELEASE="postgres-$TIMESTAMP"
NAMESPACE="monitoring-$TIMESTAMP"

echo "1. Creating monitoring namespace $NAMESPACE..."
kubectl create namespace $NAMESPACE
kubectl label namespace $NAMESPACE app.kubernetes.io/managed-by=Helm

echo "2. Installing PostgreSQL with metrics enabled..."
helm install $UNIQUE_RELEASE ./helm-charts/student-api-helm -n $NAMESPACE \
  --set postgres.persistence.forceEmptyDir=true \
  --set postgres.image.tag=15.3 \
  --set postgres.exporter.image.repository=bitnami/postgres-exporter \
  --set postgres.exporter.image.tag=0.10.1 \
  --set namespace.name=$NAMESPACE \
  --set studentApi.image.repository=nginx \
  --set studentApi.image.tag=latest

echo "3. Waiting for pods to start (60 seconds)..."
sleep 60

echo "4. Checking PostgreSQL metrics..."
POSTGRES_POD=$(kubectl get pod -n $NAMESPACE -l app=postgres -o name | head -1 | sed 's|pod/||')
if [ -z "$POSTGRES_POD" ]; then
  echo "❌ No postgres pods found"
  exit 1
fi

echo "Found postgres pod: $POSTGRES_POD"

# Setup port-forwarding in the background
kubectl port-forward -n $NAMESPACE pod/$POSTGRES_POD 9187:9187 > /dev/null 2>&1 &
PF_PID=$!
sleep 2

# Check if metrics endpoint is accessible
METRICS=$(curl -s http://localhost:9187/metrics)
if [ $? -eq 0 ]; then
  echo "✅ Metrics endpoint accessible!"
  
  # Extract and display key metrics
  echo "5. Key PostgreSQL Metrics:"
  echo "===================="
  
  # PostgreSQL Version
  PG_VERSION=$(echo "$METRICS" | grep "pg_static.*version=" | sed -E 's/.*short_version="([^"]+)".*/\1/')
  echo "PostgreSQL Version: $PG_VERSION"
  
  # Up status
  PG_UP=$(echo "$METRICS" | grep -E "^pg_up " | awk '{print $2}')
  echo "Database Up: $PG_UP"
  
  # Connected clients
  PG_CONNECTIONS=$(echo "$METRICS" | grep "pg_stat_database_numbackends" | grep -v "datname=\"\"" | awk '{print $1 " " $2}')
  echo -e "\nActive Connections:"
  echo "$PG_CONNECTIONS"
  
  # Database statistics
  echo -e "\nDatabase Statistics:"
  echo "$METRICS" | grep -E "pg_stat_database_tup_(fetched|inserted|updated|deleted)" | head -12

  echo -e "\n=================="
  echo "All systems operational! Postgres metrics are being collected successfully."
else
  echo "❌ Failed to access metrics endpoint"
  kill $PF_PID 2>/dev/null || true
  exit 1
fi

# Clean up
kill $PF_PID 2>/dev/null || true

echo "=== Setup Complete ==="
echo "Namespace: $NAMESPACE"
echo "Release: $UNIQUE_RELEASE"
echo ""
echo "To view PostgreSQL metrics again:"
echo "  kubectl port-forward -n $NAMESPACE pod/$POSTGRES_POD 9187:9187"
echo "  curl http://localhost:9187/metrics"
echo ""
echo "To clean up:"
echo "  kubectl delete namespace $NAMESPACE"
