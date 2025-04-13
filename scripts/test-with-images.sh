#!/bin/bash

set -e

echo "=== INSTALLING WITH CORRECT IMAGES ==="

# Generate timestamp for uniqueness
TIMESTAMP=$(date +%s)
UNIQUE_RELEASE="pg-$TIMESTAMP"
NAMESPACE="ns-$TIMESTAMP"

echo "1. Creating new namespace $NAMESPACE..."
kubectl create namespace $NAMESPACE
kubectl label namespace $NAMESPACE app.kubernetes.io/managed-by=Helm

# Use accessible image tags
echo "2. Installing with accessible images and emptyDir..."
helm install $UNIQUE_RELEASE ./helm-charts/student-api-helm -n $NAMESPACE \
  --set postgres.persistence.enabled=false \
  --set postgres.persistence.forceEmptyDir=true \
  --set postgres.image.repository=postgres \
  --set postgres.image.tag=15.3 \
  --set postgres.exporter.image.repository=bitnami/postgres-exporter \
  --set postgres.exporter.image.tag=0.10.1 \
  --set nginx.image.repository=nginx \
  --set nginx.image.tag=1.21 \
  --set namespace.name=$NAMESPACE \
  --set studentApi.image.repository=nginx \
  --set studentApi.image.tag=latest

echo "3. Waiting for pods to start..."
echo "Checking pods every 5 seconds..."
for i in {1..12}; do
  echo "Check $i of 12..."
  kubectl get pods -n $NAMESPACE
  sleep 5
done

echo "=== INSTALLATION COMPLETE ==="
echo "Namespace: $NAMESPACE"
echo "Release: $UNIQUE_RELEASE"
echo ""
echo "To test DB metrics: ./scripts/test-db-metrics.sh $NAMESPACE"
echo "Manual test command: kubectl port-forward -n $NAMESPACE svc/postgres-service 5432:5432"
