#!/bin/bash
# Script to configure ArgoCD with custom settings

set -e

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "Configuring ArgoCD with custom settings..."

# Apply custom configurations
echo "Applying ArgoCD ConfigMap..."
kubectl apply -f argocd-cm.yaml

echo "Applying ArgoCD RBAC ConfigMap..."
kubectl apply -f argocd-rbac-cm.yaml

echo "Applying ArgoCD Notifications ConfigMap..."
kubectl apply -f argocd-notifications-cm.yaml

# Restart ArgoCD components to apply changes
echo "Restarting ArgoCD components to apply changes..."
kubectl rollout restart deployment argocd-server -n argocd
kubectl rollout restart deployment argocd-repo-server -n argocd
kubectl rollout restart deployment argocd-applicationset-controller -n argocd
kubectl rollout restart deployment argocd-notifications-controller -n argocd
kubectl rollout restart statefulset argocd-application-controller -n argocd

# Wait for ArgoCD to be ready
echo "Waiting for ArgoCD components to be ready..."
kubectl rollout status deployment argocd-server -n argocd
kubectl rollout status deployment argocd-repo-server -n argocd
kubectl rollout status deployment argocd-applicationset-controller -n argocd
kubectl rollout status deployment argocd-notifications-controller -n argocd
kubectl rollout status statefulset argocd-application-controller -n argocd

# Get the admin password
echo "Getting ArgoCD admin password..."
ADMIN_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD admin password: $ADMIN_PASSWORD"

# Apply the application manifests if they don't exist
echo "Checking for existing ArgoCD applications..."
if ! kubectl get applications.argoproj.io student-api -n argocd &>/dev/null; then
  echo "Applying ArgoCD application manifest..."
  kubectl apply -f application.yaml
fi

if ! kubectl get applicationsets.argoproj.io student-api-appset -n argocd &>/dev/null; then
  echo "Applying ArgoCD ApplicationSet manifest..."
  kubectl apply -f applicationset.yaml
fi

echo "Setting up port forwarding to access ArgoCD UI..."
echo "To access ArgoCD UI, run: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "Then navigate to https://localhost:8080 in your browser"
echo "Login with username: admin and password: $ADMIN_PASSWORD"

echo "ArgoCD configuration complete!"
