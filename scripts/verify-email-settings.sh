#!/bin/bash
# Script to verify email notification settings

set -e

NAMESPACE="argocd"
EMAIL_USER="ketankarki2626@gmail.com"

echo "===== Email Configuration Verification Tool ====="
echo

# List all secrets in the namespace
echo "Available secrets in namespace $NAMESPACE:"
kubectl get secrets -n $NAMESPACE

# Get the actual password from the secret (not the reference)
echo "1. Verifying email password in secret..."
if kubectl get secret argocd-notifications-secret -n $NAMESPACE &>/dev/null; then
  echo "Secret argocd-notifications-secret found."
  echo "Keys in secret:"
  kubectl get secret argocd-notifications-secret -n $NAMESPACE -o jsonpath='{.data}' | jq '.' || echo "Failed to parse secret data"
  
  PASSWORD=$(kubectl get secret argocd-notifications-secret -n $NAMESPACE -o jsonpath='{.data.email-password}' | base64 -d)
  if [ -z "$PASSWORD" ]; then
    echo "❌ Email password not found in argocd-notifications-secret under key 'email-password'!"
    echo "Available keys:"
    kubectl get secret argocd-notifications-secret -n $NAMESPACE -o jsonpath='{.data}' | jq -r 'keys[]' 2>/dev/null || echo "Could not list keys"
    echo "Run 'make setup-email-password' to set it up."
    
    # Try to find any password-like fields
    echo "Searching for any potential password fields in the secret..."
    kubectl get secret argocd-notifications-secret -n $NAMESPACE -o yaml | grep -B1 -A1 password || echo "No password fields found"
  else
    echo "✅ Email password found in secret (length: ${#PASSWORD} characters)"
  fi
else
  echo "❌ argocd-notifications-secret not found!"
  echo "Run 'make setup-email-password' to create it."
fi

# Verify the ConfigMap
echo
echo "2. Verifying email settings in ConfigMap..."
if kubectl get configmap argocd-notifications-cm -n $NAMESPACE &>/dev/null; then
  SERVICE_DEF=$(kubectl get configmap argocd-notifications-cm -n $NAMESPACE -o jsonpath='{.data.service\.email}')
  if echo "$SERVICE_DEF" | grep -q "\$email-password"; then
    echo "✅ Email service configured with variable reference"
    echo
    echo "Email service definition:"
    echo "------------------------"
    echo "$SERVICE_DEF"
  else
    echo "❌ Email service missing variable reference to password!"
    # Show the service definition
    echo "Current service definition:"
    echo "$SERVICE_DEF"
  fi
else
  echo "❌ argocd-notifications-cm not found!"
fi

# If password is found, test email directly
echo
echo "3. Testing SMTP connection to Gmail..."
echo "Testing direct connection to Gmail SMTP with your credentials..."

# Use the password directly instead of the variable reference
echo "FROM: $EMAIL_USER"

if [ ! -z "$PASSWORD" ]; then
  echo "PASSWORD: Using the value from the secret (length: ${#PASSWORD})"
  
  # Use actual password from secret instead of variable reference
  curl --url "smtps://smtp.gmail.com:465" \
    --ssl-reqd \
    --mail-from "$EMAIL_USER" \
    --mail-rcpt "$EMAIL_USER" \
    --user "$EMAIL_USER:$PASSWORD" \
    -T <(echo -e "From: $EMAIL_USER\nTo: $EMAIL_USER\nSubject: ArgoCD Email Test\n\nThis is a test email from ArgoCD Email Verification script.") \
    --verbose || echo -e "\n❌ SMTP test failed! Check error above."
else
  echo "PASSWORD: Not available - skipping SMTP test"
  echo "Run 'make setup-email-password' first to set up the email password."
fi

echo
echo "===== Email Configuration Verification Complete ====="
