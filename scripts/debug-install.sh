#!/bin/bash

set -e

echo "=== DEBUGGING HELM TEMPLATE ==="

# Generate timestamp for uniqueness
TIMESTAMP=$(date +%s)
UNIQUE_RELEASE="debug-$TIMESTAMP"
NAMESPACE="debug-$TIMESTAMP"

echo "1. Creating debug namespace $NAMESPACE..."
kubectl create namespace $NAMESPACE

echo "2. Rendering template for inspection..."
helm template $UNIQUE_RELEASE ./helm-charts/student-api-helm \
  --set postgres.persistence.forceEmptyDir=true \
  --set postgres.image.tag=15.3 \
  --set namespace.name=$NAMESPACE \
  --debug > debug-template.yaml

echo "3. Checking for 'postgres-pvc' references..."
grep -n "postgres-pvc" debug-template.yaml || echo "No 'postgres-pvc' references found!"

echo "=== DEBUG COMPLETE ==="
echo "Template saved to debug-template.yaml"
echo "Fix any hard-coded 'postgres-pvc' references in your templates"
