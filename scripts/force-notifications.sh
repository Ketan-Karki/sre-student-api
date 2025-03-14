#!/bin/bash
set -e

# This script forces notifications for ArgoCD applications
# to test the notification system

APP_NAME="${1:-student-api}"
NAMESPACE="${2:-argocd}"

echo "===== Forcing Notifications for Application: $APP_NAME ====="

# 1. Reset notification status
echo "1. Resetting notification status..."
kubectl annotate application $APP_NAME -n $NAMESPACE \
  notified.notifications.argoproj.io- \
  notifications.argoproj.io/notified.on-health-status-change.email- \
  notifications.argoproj.io/notified.on-sync-status-change.email- \
  notifications.argoproj.io/notified.on-health-status-change.webhook- \
  notifications.argoproj.io/notified.on-sync-status-change.webhook- \
  --overwrite 2>/dev/null || true

# 2. Set subscription - ONLY webhook and email (no discord)
echo "2. Confirming notification subscriptions are set..."
kubectl annotate application $APP_NAME -n $NAMESPACE \
  notifications.argoproj.io/subscribe.on-health-status-change.email="ketankarki2626@gmail.com" \
  notifications.argoproj.io/subscribe.on-sync-status-change.email="ketankarki2626@gmail.com" \
  notifications.argoproj.io/subscribe.on-health-status-change.webhook="webhook" \
  notifications.argoproj.io/subscribe.on-sync-status-change.webhook="webhook" \
  --overwrite

# 3. Force application to go out of sync with a temporary annotation
echo "3. Forcing application out of sync with a temporary annotation..."
TIMESTAMP=$(date +%s)
kubectl patch application $APP_NAME -n $NAMESPACE --type=merge -p "{\"metadata\":{\"annotations\":{\"temporary-change\":\"$TIMESTAMP\"}}}"

# 4. Wait for out-of-sync notification
echo "4. Waiting for out-of-sync notification to trigger (10s)..."
sleep 10

# 5. Check notification controller pod
echo "5. Checking notification controller pod status..."
kubectl get pods -n argocd -l app.kubernetes.io/component=notifications-controller

# 5b. Restart notification controller to ensure it picks up configuration changes
echo "5b. Restarting notification controller to pick up changes..."
kubectl rollout restart deployment argocd-notifications-controller -n $NAMESPACE
kubectl rollout status deployment argocd-notifications-controller -n $NAMESPACE

# 6. Trigger sync
echo "6. Triggering application sync..."
kubectl patch application $APP_NAME -n $NAMESPACE --type=merge -p "{\"metadata\":{\"annotations\":{\"force-sync-timestamp\":\"$TIMESTAMP\"}}}"

# 7. Wait for sync notification
echo "7. Waiting for sync notification to trigger (20s)..."
sleep 20

# 8. Check notification controller logs
echo "8. Checking notification controller logs for notification events:"
kubectl logs deployment/argocd-notifications-controller -n $NAMESPACE --tail=30 | grep -E 'notification|trigger|webhook|error|send' || echo "No relevant log entries found"

# 9. Detailed notification debugging
echo "===== Detailed Notification Debugging ====="
echo "9. Verify notification service is properly configured:"
kubectl get cm argocd-notifications-cm -n $NAMESPACE -o yaml | grep -A5 "service\."

echo "10. Verify application has notification annotations:"
kubectl get application $APP_NAME -n $NAMESPACE -o jsonpath='{.metadata.annotations}' | grep -i "notif\|subscribe" | tr ',' '\n'

echo "11. Check all triggered notifications:"
kubectl get application $APP_NAME -n $NAMESPACE -o jsonpath='{.metadata.annotations}' | grep -i "notified\|notify" | tr ',' '\n'

echo "12. Check ArgoCD version (different versions use different notification formats):"
kubectl get deployment argocd-server -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].image}'

echo "13. Testing Discord webhook directly with curl..."
DISCORD_URL=$(kubectl get cm argocd-notifications-cm -n $NAMESPACE -o jsonpath='{.data.service\.webhook}' | grep url | awk '{print $2}')
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{"content": "Test message from shell", "embeds": [{"title": "Manual Test", "description": "Testing webhook directly from script", "color": 5025616}]}' \
  $DISCORD_URL

echo "===== Test Complete ====="
echo "If notifications were sent, check your Discord channel and email now."
echo "If no notifications were received, review the logs and verify configuration."
