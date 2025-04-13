#!/bin/bash

set -e

NAMESPACE="student-api"
RELEASE_NAME="student-api"

echo "=== Complete Reset of Helm Environment ==="

echo "1. Deleting Helm release..."
helm delete $RELEASE_NAME -n $NAMESPACE --no-hooks || echo "No release to delete"

echo "2. Finding and force deleting any lingering PVCs..."
PVCS=$(kubectl get pvc -n $NAMESPACE --no-headers 2>/dev/null | awk '{print $1}' || echo "")
if [ -n "$PVCS" ]; then
  for PVC in $PVCS; do
    echo "Force deleting PVC: $PVC"
    kubectl patch pvc $PVC -n $NAMESPACE -p '{"metadata":{"finalizers":null}}' || true
    kubectl delete pvc $PVC -n $NAMESPACE --force --grace-period=0 || true
  done
fi

echo "3. Deleting namespace..."
kubectl delete namespace $NAMESPACE || echo "No namespace to delete"

echo "4. Waiting to ensure namespace is fully deleted..."
until kubectl get namespace $NAMESPACE 2>&1 | grep -q "not found"; do
  echo "Waiting for namespace deletion to complete..."
  sleep 3
done

echo "5. Check for any lingering PVs or PVCs..."
kubectl get pv | grep -E 'postgres-pvc|postgres-data|student-api' || echo "No lingering PVs"

echo "6. Creating fresh namespace..."
kubectl create namespace $NAMESPACE

echo "7. Labeling namespace for Helm..."
kubectl label namespace $NAMESPACE app.kubernetes.io/managed-by=Helm

echo "8. Installing Helm chart..."
helm install $RELEASE_NAME ./helm-charts/student-api-helm -n $NAMESPACE \
  --set postgres.image.tag=15.3 \
  --set studentApi.image.repository=nginx \
  --set studentApi.image.tag=latest \
  --timeout 10m

echo "=== Setup Complete ==="
