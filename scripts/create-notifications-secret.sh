#!/bin/bash
# Create a separate secret for ArgoCD notifications

set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <app-password>"
  echo "Example: $0 abcdefghijklmnop"
  exit 1
fi

APP_PASSWORD=$1

echo "Creating ArgoCD notifications secret with provided app password..."
kubectl -n argocd create secret generic argocd-notifications-secret \
  --from-literal=email.password=$APP_PASSWORD \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Secret created successfully."
echo "Updating the ArgoCD notifications ConfigMap to use the secret..."

# Create a temporary file to store the modified ConfigMap
TMP_FILE=$(mktemp)

# Retrieve the existing ConfigMap
kubectl -n argocd get cm argocd-notifications-cm -o yaml > $TMP_FILE

# Update the email configuration to use the secret
sed -i.bak 's/password: .*$/password: \$email-password/' $TMP_FILE

# Apply the changes
kubectl apply -f $TMP_FILE

# Clean up
rm $TMP_FILE $TMP_FILE.bak

echo "ConfigMap updated."
echo "Restarting ArgoCD notifications controller..."
kubectl -n argocd rollout restart deployment argocd-notifications-controller
kubectl -n argocd rollout status deployment argocd-notifications-controller

echo "Complete! Email notifications should now use the securely stored password."
