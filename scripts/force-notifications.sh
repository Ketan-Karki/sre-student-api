#!/bin/bash
# Script to force ArgoCD notifications by manipulating application sync state

APP_NAME=${1:-student-api}

echo "===== Forcing Notifications for Application: $APP_NAME ====="

# Reset notification status
echo "1. Resetting notification status..."
kubectl annotate application $APP_NAME -n argocd \
  notifications.argoproj.io/notified.on-sync-status-change.discord=false \
  notifications.argoproj.io/notified.on-sync-status-change.email=false \
  notifications.argoproj.io/notified.on-health-status-change.discord=false \
  notifications.argoproj.io/notified.on-health-status-change.email=false \
  --overwrite

# Ensure application has notification subscriptions
echo "2. Confirming notification subscriptions are set..."
kubectl annotate application $APP_NAME -n argocd \
  notifications.argoproj.io/subscribe.on-sync-status-change.discord=webhook \
  notifications.argoproj.io/subscribe.on-sync-status-change.email=ketankarki2626@gmail.com \
  notifications.argoproj.io/subscribe.on-health-status-change.discord=webhook \
  notifications.argoproj.io/subscribe.on-health-status-change.email=ketankarki2626@gmail.com \
  --overwrite

# Force app out of sync by temporarily changing an annotation
echo "3. Forcing application out of sync with a temporary annotation..."
TIMESTAMP=$(date +%s)
kubectl patch application $APP_NAME -n argocd --type=merge \
  -p "{\"metadata\":{\"annotations\":{\"temporary-change\":\"$TIMESTAMP\"}}}"

echo "4. Waiting for out-of-sync notification to trigger (10s)..."
sleep 10

# Verify notification controller status
echo "5. Checking notification controller pod status..."
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-notifications-controller

# Restart notification controller to pick up changes
echo "5b. Restarting notification controller to pick up changes..."
kubectl rollout restart deployment/argocd-notifications-controller -n argocd
kubectl rollout status deployment/argocd-notifications-controller -n argocd

# Trigger sync with the application
echo "6. Triggering application sync..."
# Try argocd CLI if available, otherwise use kubectl
if command -v argocd &>/dev/null; then
  argocd app sync $APP_NAME --force
else
  kubectl patch application $APP_NAME -n argocd --type=merge \
    -p '{"operation":{"sync":{"revision":"HEAD","syncStrategy":{"hook":{}},"prune":true}}}'
fi

echo "7. Waiting for sync notification to trigger (20s)..."
sleep 20

# Check notification logs
echo "8. Checking notification controller logs for notification events:"
kubectl logs deployment/argocd-notifications-controller -n argocd --tail=30 | grep -E 'notification|trigger|discord|error|webhook' || echo "No relevant log entries found"

echo "===== Detailed Notification Debugging ====="

# Check if the notification controller is running and responding
echo "9. Verify notification service is properly configured:"
kubectl get cm argocd-notifications-cm -n argocd -o yaml | grep -A5 "service\."

# Check that the application has the required annotations
echo "10. Verify application has notification annotations:"
kubectl get application $APP_NAME -n argocd -o yaml | grep -i notifications

# Check all triggered notifications
echo "11. Check all triggered notifications:"
kubectl get application $APP_NAME -n argocd -o yaml | grep -i notified

# Check ArgoCD version
echo "12. Check ArgoCD version (different versions use different notification formats):"
kubectl get deployment argocd-notifications-controller -n argocd -o jsonpath='{.spec.template.spec.containers[0].image}'
echo ""

# Create test hook with curl to verify webhook directly
echo "13. Testing Discord webhook directly with curl..."
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "content": "Test from ArgoCD notification troubleshooting script",
    "embeds": [
      {
        "title": "Webhook Test",
        "description": "Testing webhook from troubleshooting script",
        "color": 5025616
      }
    ]
  }' \
  https://discord.com/api/webhooks/1347263141410635827/LJXyvLmdvU-SRjYX1kpY7JxYOQcyKcpuF5iK05nJQEmPv9qZrmQMdfILAu-vmVYPJqWz

echo "===== Test Complete ====="
echo "If notifications were sent, check your Discord channel and email now."
echo "If no notifications were received, review the logs and verify configuration."
