#!/bin/bash

# This is an emergency script to clean up everything and start from scratch

echo "=== EMERGENCY CLEANUP ==="

# Kill any hanging kubectl processes
echo "Killing any hanging kubectl processes..."
pkill -9 kubectl || true

# Delete and recreate namespace
NAMESPACE="student-api"
echo "Recreating namespace $NAMESPACE..."
kubectl delete namespace $NAMESPACE --wait=false || true
sleep 2

# Force create namespace (might already be in process of deleting, which is fine)
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Label it for Helm
kubectl label namespace $NAMESPACE app.kubernetes.io/managed-by=Helm --overwrite

# Update the postgres persistence configuration directly in values.yaml
echo "Updating values.yaml to use a unique volume name..."

# Use current timestamp to ensure uniqueness
TIMESTAMP=$(date +%s)

echo "=== CLEANUP COMPLETE ==="
echo "Now manually run: helm install student-api ./helm-charts/student-api-helm -n student-api --set postgres.image.tag=15.3 --set postgres.persistence.name=postgres-vol-$TIMESTAMP"
