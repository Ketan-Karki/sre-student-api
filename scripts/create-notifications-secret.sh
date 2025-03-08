#!/bin/bash
# Script to securely create ArgoCD notifications secret with email password

set -e

NAMESPACE="argocd"
PASSWORD=$1

if [ -z "$PASSWORD" ]; then
  echo "Error: No password provided! Usage: ./create-notifications-secret.sh <email-app-password>"
  exit 1
fi

echo "Creating ArgoCD notifications secret with provided app password..."

# Check if secret exists and create or update it
if kubectl get secret argocd-notifications-secret -n $NAMESPACE &>/dev/null; then
  # Update existing secret
  kubectl create secret generic argocd-notifications-secret \
    --from-literal=email-password="$PASSWORD" \
    --namespace $NAMESPACE \
    --dry-run=client -o yaml | kubectl apply -f -
else
  # Create new secret
  kubectl create secret generic argocd-notifications-secret \
    --from-literal=email-password="$PASSWORD" \
    --namespace $NAMESPACE
fi

# Verify secret was created properly
if kubectl get secret argocd-notifications-secret -n $NAMESPACE -o jsonpath='{.data}' | grep -q "email-password"; then
  echo "Secret created successfully."
else
  echo "Error: Failed to create secret with email-password key!"
  exit 1
fi

echo "Updating the ArgoCD notifications ConfigMap to use the secret..."
kubectl get configmap argocd-notifications-cm -n $NAMESPACE -o yaml | \
  sed 's/password: \$email-password/password: $email-password/g' | \
  kubectl apply -f -

echo "ConfigMap updated."
echo "Restarting ArgoCD notifications controller..."
kubectl rollout restart deployment argocd-notifications-controller -n $NAMESPACE
kubectl rollout status deployment argocd-notifications-controller -n $NAMESPACE

echo "Complete! Email notifications should now use the securely stored password."
