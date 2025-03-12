#!/bin/bash

# Start ArgoCD UI port-forward
echo "Starting port-forward to ArgoCD UI..."
echo "Access the UI at https://localhost:8080"
echo "Press Ctrl+C when done"

# Get admin password
ADMIN_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD UI:"
echo "Username: admin"
echo "Password: $ADMIN_PASSWORD"

# Start port-forward
kubectl port-forward svc/argocd-server -n argocd 8080:443
