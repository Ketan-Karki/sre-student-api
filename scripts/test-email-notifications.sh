#!/bin/bash
# Script to test email functionality for ArgoCD notifications

set -e

EMAIL=${1:-"ketankarki2626@gmail.com"}
SUBJECT=${2:-"ArgoCD Email Notification Test"}

echo "===== Testing Email Notification Functionality ====="

# Check if app password environment variable is set
if [ -z "$GMAIL_APP_PASSWORD" ]; then
  # If no app password provided, retrieve from ArgoCD config
  APP_PASSWORD=$(kubectl get -n argocd cm/argocd-notifications-cm -o jsonpath='{.data.service\.email}' | grep -o 'password: .*' | cut -d' ' -f2)
  
  # Check if we successfully retrieved the password
  if [ -z "$APP_PASSWORD" ]; then
    echo "ERROR: Could not retrieve Gmail password from ArgoCD ConfigMap."
    echo "Please provide the App Password as an environment variable:"
    echo "GMAIL_APP_PASSWORD=your_app_password ./scripts/test-email-notifications.sh"
    exit 1
  fi
  
  export GMAIL_APP_PASSWORD="$APP_PASSWORD"
fi

echo "Using password: $GMAIL_APP_PASSWORD"

# Create a test message file
cat > /tmp/argocd-test-email.txt << EOL
From: ketankarki2626@gmail.com
To: $EMAIL
Subject: $SUBJECT

This is a test email from the ArgoCD notification troubleshooting script.
If you are receiving this message, the email notification system is working properly.

Timestamp: $(date)
EOL

# Send test email using curl and Gmail SMTP
echo "Sending test email to $EMAIL..."
curl --url "smtps://smtp.gmail.com:465" \
     --ssl-reqd \
     --mail-from "ketankarki2626@gmail.com" \
     --mail-rcpt "$EMAIL" \
     --user "ketankarki2626@gmail.com:$GMAIL_APP_PASSWORD" \
     --upload-file /tmp/argocd-test-email.txt \
     --insecure \
     -v

# Clean up
rm -f /tmp/argocd-test-email.txt

echo -e "\n===== Email Test Complete ====="
echo "The email has been sent using Gmail SMTP directly."
echo "If you don't receive it:"
echo "1. Check the spam folder"
echo "2. Verify that your Gmail account allows 'less secure apps'"
echo "3. Consider creating an App Password: https://myaccount.google.com/apppasswords"
echo ""
echo "After May 2022, Google requires App Passwords for programmatic access to Gmail."
echo "To use App Passwords, you need to enable 2FA on your Google Account."
