#!/bin/bash

set -e

NAMESPACE="argocd"
APP_NAME="student-api"
echo "=== Syncing ArgoCD Application with New PVC ==="

# Apply the updated application manifest
echo "Applying updated application manifest..."
kubectl apply -f /Users/ketan/Learning/sre-bootcamp-rest-api/argocd/application.yaml

# Wait for application to be processed
echo "Waiting for application to be processed..."
sleep 5

# Check application status
echo "Application status:"
kubectl get application $APP_NAME -n $NAMESPACE

# Force a refresh of the application
echo "Forcing application refresh..."
kubectl patch application $APP_NAME -n $NAMESPACE --type=merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

# Wait for refresh to be processed
echo "Waiting for refresh to be processed..."
sleep 5

# Sync the application
echo "Syncing application..."
kubectl patch application $APP_NAME -n $NAMESPACE --type=merge -p '{"operation":{"sync":{"revision":"HEAD","prune":true}}}'

# Check application resources
echo -e "\nChecking application resources..."
echo "Postgres pods:"
kubectl get pods -n student-api -l app=postgres

echo "PersistentVolumeClaims:"
kubectl get pvc -n student-api

echo -e "\n=== Sync Complete ==="
echo "To check the application in ArgoCD UI:"
echo "kubectl port-forward svc/argocd-server -n argocd 8080:443"
