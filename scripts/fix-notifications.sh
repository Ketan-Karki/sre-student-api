#!/bin/bash
set -e

NAMESPACE="argocd"

# Function to fix email password
fix_email_password() {
    # Get email password from environment variable or prompt for it
    if [ -z "$EMAIL_PASSWORD" ]; then
        if [ -f ~/.argocd/email-password ]; then
            EMAIL_PASSWORD=$(cat ~/.argocd/email-password)
        else
            echo "EMAIL_PASSWORD environment variable not set and ~/.argocd/email-password doesn't exist"
            read -s -p "Enter email password: " EMAIL_PASSWORD
            echo ""
        fi
    fi

    # Create email-password in secret
    kubectl patch secret argocd-notifications-secret -n $NAMESPACE --type=merge \
        -p "{\"stringData\": {\"email-password\": \"$EMAIL_PASSWORD\"}}"
    
    echo "✅ Email password updated in argocd-notifications-secret"
}

# Function to fix notifications configuration
fix_notifications_config() {
    # First, completely remove ALL notification annotations
    kubectl annotate application student-api -n $NAMESPACE \
      notifications.argoproj.io/subscribe.on-sync-status-change.discord- \
      notifications.argoproj.io/subscribe.on-health-status-change.discord- \
      notifications.argoproj.io/notified.on-sync-status-change.discord- \
      notifications.argoproj.io/notified.on-health-status-change.discord- \
      notifications.argoproj.io/subscribe.on-sync-status-change.webhook- \
      notifications.argoproj.io/subscribe.on-health-status-change.webhook- \
      notifications.argoproj.io/notified.on-sync-status-change.webhook- \
      notifications.argoproj.io/notified.on-health-status-change.webhook- \
      notified.notifications.argoproj.io- \
      --overwrite 2>/dev/null || true
    
    # Then set only webhook and email annotations correctly
    kubectl annotate application student-api -n $NAMESPACE \
      notifications.argoproj.io/subscribe.on-sync-status-change.webhook="webhook" \
      notifications.argoproj.io/subscribe.on-health-status-change.webhook="webhook" \
      notifications.argoproj.io/subscribe.on-sync-status-change.email="ketankarki2626@gmail.com" \
      notifications.argoproj.io/subscribe.on-health-status-change.email="ketankarki2626@gmail.com" \
      --overwrite
    
    echo "✅ Notification subscription annotations updated"
    
    # Apply the ConfigMap 
    kubectl apply -f /Users/ketan/Learning/sre-bootcamp-rest-api/argocd/argocd-notifications-cm.yaml
    echo "✅ Updated notifications ConfigMap"
}

# Main function
echo "Fixing notification configuration..."
fix_email_password
fix_notifications_config

# Restart notification controller
echo "Restarting notification controller..."
kubectl rollout restart deployment argocd-notifications-controller -n $NAMESPACE
kubectl rollout status deployment argocd-notifications-controller -n $NAMESPACE

echo "Notification configuration fixed!"
echo "Run this to test notifications:"
echo "make test-notifications"
