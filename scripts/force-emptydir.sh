#!/bin/bash

set -e

echo "=== FORCE INSTALLATION WITH EMPTYDIR ==="

# Generate timestamp for uniqueness
TIMESTAMP=$(date +%s)
UNIQUE_RELEASE="pg-$TIMESTAMP"
NAMESPACE="ns-$TIMESTAMP"

echo "1. Creating new namespace $NAMESPACE..."
kubectl create namespace $NAMESPACE
kubectl label namespace $NAMESPACE app.kubernetes.io/managed-by=Helm

echo "2. Installing with emptyDir and skipping PVC creation..."
helm install $UNIQUE_RELEASE ./helm-charts/student-api-helm -n $NAMESPACE \
  --set postgres.persistence.enabled=false \
  --set postgres.persistence.forceEmptyDir=true \
  --set postgres.image.repository=postgres \
  --set postgres.image.tag=15.3 \
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
