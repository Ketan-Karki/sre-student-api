#!/bin/bash

echo "Checking ArgoCD server status..."

# Wait for ArgoCD server pod to be ready
while ! kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].status.phase}' 2>/dev/null | grep -q "Running"; do
    echo "Waiting for ArgoCD server pod to be ready..."
    sleep 5
done

# Additional check to ensure the container is truly ready
while ! kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null | grep -q "true"; do
    echo "Waiting for ArgoCD server container to be ready..."
    sleep 5
done

# Get admin password
PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo "ArgoCD admin username: admin"
echo "ArgoCD admin password: $PASSWORD"
echo "Starting port forwarding to ArgoCD UI (namespace: argocd)..."
echo "Access the UI at: https://localhost:9090"
echo "Press Ctrl+C to stop port forwarding when done."

# Start port forwarding
kubectl port-forward svc/argocd-server -n argocd 9090:443
