#!/bin/bash

# Create namespace if it doesn't exist
kubectl create namespace student-api 2>/dev/null || true

# Cleanup any existing resources
echo "Cleaning up existing resources..."
kubectl delete deployment student-api -n student-api 2>/dev/null || true
kubectl delete configmap student-api-config -n student-api 2>/dev/null || true

# Wait for cleanup
sleep 5

# Apply ConfigMap
echo "Applying ConfigMap..."
kubectl apply -f k8s/config/app-config.yaml

# Apply Deployment
echo "Applying Deployment..."
kubectl apply -f k8s/student-api/deployment.yaml

# Wait for deployment to be ready
echo "Waiting for deployment to be ready..."
kubectl wait --for=condition=available deployment/student-api -n student-api --timeout=60s

# Get pod name (only after deployment is ready)
POD_NAME=$(kubectl get pods -n student-api -l app=student-api --field-selector status.phase=Running -o jsonpath='{.items[0].metadata.name}')

# Check environment variables in the pod
echo "Checking environment variables in pod $POD_NAME..."
kubectl exec -n student-api $POD_NAME -- env | sort

# Check pod status
echo "Pod status:"
kubectl get pods -n student-api -o wide

# Watch pod logs
echo "Pod logs:"
kubectl logs -n student-api $POD_NAME --follow --tail=20
