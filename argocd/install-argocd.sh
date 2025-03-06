#!/bin/bash
# Script to install ArgoCD in a Kubernetes cluster

set -e

echo "Installing ArgoCD..."

# Create namespace
kubectl create namespace argocd || echo "Namespace argocd already exists"

# Apply ArgoCD installation manifest
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
echo "Waiting for ArgoCD components to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
kubectl wait --for=condition=available --timeout=300s deployment/argocd-repo-server -n argocd
kubectl wait --for=condition=ready --timeout=300s pod -l app.kubernetes.io/name=argocd-application-controller -n argocd

# Get the initial admin password
echo "Getting initial admin password..."
INITIAL_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "Initial admin password: $INITIAL_PASSWORD"
echo "Please save this password for logging into ArgoCD"

# Apply the application manifests
echo "Applying ArgoCD application manifests..."
kubectl apply -f application.yaml

# Port forward to access ArgoCD UI
echo "Setting up port forwarding to access ArgoCD UI..."
echo "To access ArgoCD UI, run: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "Then navigate to https://localhost:8080 in your browser"
echo "Login with username: admin and password: $INITIAL_PASSWORD"

echo "ArgoCD installation complete!"
