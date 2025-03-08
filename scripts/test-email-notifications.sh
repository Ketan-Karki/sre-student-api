#!/bin/bash
# Script to test email notifications

set -e

NAMESPACE="argocd"
EMAIL="ketankarki2626@gmail.com"

echo "===== Testing Email Notification Functionality ====="

# Debug - list all secrets in namespace
echo "Checking for notifications secret..."
kubectl get secrets -n $NAMESPACE | grep notifications

# Debug - check the structure of the secret
echo "Checking secret structure..."
kubectl get secret argocd-notifications-secret -n $NAMESPACE -o yaml | grep -v "password:\|token:" || echo "No secret found or wrong structure"

# Extract the actual password from the secret
if kubectl get secret argocd-notifications-secret -n $NAMESPACE &>/dev/null; then
  # Debug - list all keys in the secret
  echo "Keys in secret:"
  kubectl get secret argocd-notifications-secret -n $NAMESPACE -o jsonpath='{.data}' | jq '.'
  
  # Try to get the password directly
  PASSWORD=$(kubectl get secret argocd-notifications-secret -n $NAMESPACE -o jsonpath='{.data.email-password}' | base64 -d)
  if [ -z "$PASSWORD" ]; then
    echo "Error: Email password not found in argocd-notifications-secret!"
    echo "Available keys in secret:"
    kubectl get secret argocd-notifications-secret -n $NAMESPACE -o jsonpath='{.data}' | jq -r 'keys[]'
    echo "Run 'make setup-email-password' to set it up."
    exit 1
  else
    echo "Password found (length: ${#PASSWORD} characters)"
  fi
else
  echo "Error: argocd-notifications-secret not found!"
  echo "Run 'make setup-email-password' to create it."
  exit 1
fi

echo "Sending test email to $EMAIL..."

# Use the actual password from secret instead of variable reference
curl --url "smtps://smtp.gmail.com:465" \
  --ssl-reqd \
  --mail-from "$EMAIL" \
  --mail-rcpt "$EMAIL" \
  --user "$EMAIL:$PASSWORD" \
  -T <(echo -e "From: $EMAIL\nTo: $EMAIL\nSubject: ArgoCD Notification Test\n\nThis is a test email from ArgoCD notifications system.") \
  --verbose

if [ $? -eq 0 ]; then
  echo "✅ Email sent successfully!"
else
  echo "❌ Failed to send email. Check error above."
fi
