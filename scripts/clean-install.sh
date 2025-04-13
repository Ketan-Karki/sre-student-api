#!/bin/bash

set -e

# Kill any hanging kubectl processes
echo "Killing any hanging kubectl processes..."
pkill -9 kubectl || true

# Unique timestamp
TIMESTAMP=$(date +%s)
VOLUME_NAME="db-storage-$TIMESTAMP"
RELEASE_NAME="api-$TIMESTAMP"  # Use timestamp in release name for uniqueness
NAMESPACE="student-api"

echo "=== Clean installation of Helm chart ==="
echo "Using volume name: $VOLUME_NAME"
echo "Using release name: $RELEASE_NAME"

# Force delete previous release if it exists
echo "1. Checking for existing Helm release..."
if helm status student-api -n $NAMESPACE &>/dev/null; then
  echo "Found existing release, removing..."
  helm delete student-api -n $NAMESPACE --no-hooks || true
  # Delete Helm secrets directly
  kubectl delete secret -n $NAMESPACE -l name=student-api,owner=helm --ignore-not-found
  # Give Kubernetes a moment to clean up
  sleep 3
fi

# Recreate namespace
echo "2. Creating fresh namespace..."
kubectl delete namespace $NAMESPACE --ignore-not-found --wait=false
sleep 2

# Force create namespace (might already be in process of deleting, which is fine)
kubectl create namespace $NAMESPACE
kubectl label namespace $NAMESPACE app.kubernetes.io/managed-by=Helm

echo "3. Forcefully removing problematic PVC..."
kubectl delete pvc postgres-pvc -n $NAMESPACE --force --grace-period=0 --ignore-not-found
sleep 2  # Give k8s time to process deletion

echo "4. Installing chart with new release name..."
# Install chart with the unique release name and forcing emptyDir
helm install $RELEASE_NAME ./helm-charts/student-api-helm -n $NAMESPACE \
  --set postgres.image.tag=15.3 \
  --set postgres.persistence.forceEmptyDir=true \
  --set postgres.persistence.name=$VOLUME_NAME \
  --set studentApi.image.repository=nginx \
  --set studentApi.image.tag=latest \
  --timeout 5m

echo "=== Installation complete ==="
echo "To test DB metrics, use: ./scripts/test-db-metrics.sh $NAMESPACE $RELEASE_NAME"
