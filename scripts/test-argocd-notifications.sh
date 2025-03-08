#!/bin/bash
# Script to test ArgoCD notifications

set -e

cd /Users/ketan/Learning/sre-bootcamp-rest-api/argocd

echo "===== Testing ArgoCD Notifications ====="

# Step 0: Test Discord webhook directly to verify it works
echo "Testing Discord webhook directly..."
../scripts/test-discord-webhook.sh

# Step 1: Apply updated ArgoCD Notifications ConfigMap
echo "Applying updated ArgoCD Notifications ConfigMap..."
kubectl apply -f argocd-notifications-cm.yaml

# Step 2: Restart the ArgoCD notifications controller
echo "Restarting the ArgoCD notifications controller..."
kubectl rollout restart deployment argocd-notifications-controller -n argocd
kubectl rollout status deployment argocd-notifications-controller -n argocd

# Step 3: Enable notifications for the student-api application
echo "Enabling notifications for the student-api application..."
kubectl annotate application student-api -n argocd notifications.argoproj.io/subscribe.on-sync-status-change.discord=webhook --overwrite
kubectl annotate application student-api -n argocd notifications.argoproj.io/subscribe.on-health-status-change.discord=webhook --overwrite
kubectl annotate application student-api -n argocd notifications.argoproj.io/subscribe.on-sync-status-change.email=ketankarki2626@gmail.com --overwrite
kubectl annotate application student-api -n argocd notifications.argoproj.io/subscribe.on-health-status-change.email=ketankarki2626@gmail.com --overwrite

# Set an environmental annotation to force sync status change
echo "Setting annotations to reset notification status..."
kubectl annotate application student-api -n argocd \
  notifications.argoproj.io/notified.on-sync-status-change.discord=false \
  notifications.argoproj.io/notified.on-sync-status-change.email=false \
  notifications.argoproj.io/notified.on-health-status-change.discord=false \
  notifications.argoproj.io/notified.on-health-status-change.email=false \
  --overwrite

# Step 4: Force application to refresh and sync
echo "Forcing application refresh and sync..."
TIMESTAMP=$(date +%s)
kubectl patch application student-api -n argocd --type=merge -p "{\"metadata\":{\"annotations\":{\"force-sync-timestamp\":\"$TIMESTAMP\"}}}"

# Update sync policy to automated
echo "Enabling automated sync..."
kubectl patch application student-api -n argocd --type=merge -p '{"spec":{"syncPolicy":{"automated":{"selfHeal":true,"prune":true}}}}'

echo "Wait for sync to complete..."
sleep 15

echo "Check logs from the notifications controller for any errors:"
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-notifications-controller --tail=50 | grep -i 'error\|notif\|discord'

echo "===== Notification Test Complete ====="
echo "Check your email and Discord channel for notifications."
echo "If no notifications were received, check the logs above for errors."
