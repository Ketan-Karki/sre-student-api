#!/bin/bash

set -e

echo "=== SIMPLIFIED INSTALLATION SCRIPT ==="

# Generate timestamp for uniqueness
TIMESTAMP=$(date +%s)
UNIQUE_RELEASE="postgres-$TIMESTAMP"
NAMESPACE="pg-$TIMESTAMP"

echo "1. Creating new namespace $NAMESPACE..."
kubectl create namespace $NAMESPACE
kubectl label namespace $NAMESPACE app.kubernetes.io/managed-by=Helm

echo "2. Installing with unique release name $UNIQUE_RELEASE..."
helm install $UNIQUE_RELEASE ./helm-charts/student-api-helm -n $NAMESPACE \
  --set postgres.persistence.forceEmptyDir=true \
  --set postgres.image.tag=15.3 \
  --set studentApi.image.repository=nginx \
  --set studentApi.image.tag=latest \
  --set namespace.name=$NAMESPACE

echo "3. Waiting for pods to start..."
kubectl -n $NAMESPACE wait --for=condition=Ready pods --all --timeout=120s || true

echo "=== INSTALLATION COMPLETE ==="
echo "New namespace: $NAMESPACE"
echo "Release name: $UNIQUE_RELEASE"
echo ""
echo "Check pods with: kubectl get pods -n $NAMESPACE"
echo "Test DB metrics with: ./scripts/test-db-metrics.sh $NAMESPACE"
