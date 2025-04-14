#!/bin/bash

NAMESPACE="student-api"

echo "=== Fixing Pod Labels ==="

# Delete existing deployment
echo "Deleting existing student-api deployment..."
kubectl delete deployment student-api -n $NAMESPACE --ignore-not-found=true

# Apply Helm changes
echo "Applying Helm changes..."
helm upgrade --install student-api ./helm-charts/student-api-helm -n $NAMESPACE

# Wait for new pod
echo "Waiting for pod to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=student-api -n $NAMESPACE --timeout=60s

# Verify labels
echo "Verifying pod labels..."
kubectl get pods -n $NAMESPACE --show-labels

echo "=== Fix Complete ==="
