#!/bin/bash

set -e

echo "=== Setting up PostgreSQL Monitoring Environment ==="

# Generate timestamp for uniqueness
TIMESTAMP=$(date +%s)
UNIQUE_RELEASE="pg-$TIMESTAMP"
NAMESPACE="mon-$TIMESTAMP"

echo "1. Creating monitoring namespace $NAMESPACE..."
kubectl create namespace $NAMESPACE
kubectl label namespace $NAMESPACE app.kubernetes.io/managed-by=Helm

echo "2. Installing PostgreSQL with metrics enabled..."
helm install $UNIQUE_RELEASE ./helm-charts/student-api-helm -n $NAMESPACE \
  --set postgres.persistence.enabled=false \
  --set postgres.persistence.forceEmptyDir=true \
  --set postgres.image.tag=15.3 \
  --set postgres.exporter.image.repository=bitnami/postgres-exporter \
  --set postgres.exporter.image.tag=0.10.1 \
  --set namespace.name=$NAMESPACE \
  --set studentApi.image.repository=nginx \
  --set studentApi.image.tag=latest

echo "3. Waiting for pods to start (30 seconds)..."
sleep 30

echo "4. Checking pod status..."
kubectl get pods -n $NAMESPACE

echo "5. Checking postgres-exporter logs..."
POSTGRES_POD=$(kubectl get pod -n $NAMESPACE -l app=postgres -o name | head -1 | sed 's|pod/||')
if [ -z "$POSTGRES_POD" ]; then
  echo "❌ No postgres pods found"
  exit 1
fi

echo "Found postgres pod: $POSTGRES_POD"
kubectl logs -n $NAMESPACE $POSTGRES_POD -c postgres-exporter

echo "=== Setup Complete ==="
echo "Namespace: $NAMESPACE"
echo "Release: $UNIQUE_RELEASE"
echo ""
echo "To view PostgreSQL metrics:"
echo "  kubectl port-forward -n $NAMESPACE pod/$POSTGRES_POD 9187:9187"
echo "  curl http://localhost:9187/metrics"
