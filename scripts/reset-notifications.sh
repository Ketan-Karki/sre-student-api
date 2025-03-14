#!/bin/bash
set -e

NAMESPACE="argocd"
APPLICATION="student-api"

# Reset everything related to notifications
echo "===== Complete Notifications Reset ====="

# 1. Reset all notification annotations
echo "Clearing all notification annotations..."
kubectl annotate application $APPLICATION -n $NAMESPACE \
  notifications.argoproj.io/subscribe.on-sync-status-change.discord- \
  notifications.argoproj.io/subscribe.on-health-status-change.discord- \
  notifications.argoproj.io/notified.on-sync-status-change.discord- \
  notifications.argoproj.io/notified.on-health-status-change.discord- \
  notifications.argoproj.io/subscribe.on-sync-status-change.webhook- \
  notifications.argoproj.io/subscribe.on-health-status-change.webhook- \
  notifications.argoproj.io/notified.on-sync-status-change.webhook- \
  notifications.argoproj.io/notified.on-health-status-change.webhook- \
  notifications.argoproj.io/subscribe.on-sync-status-change.email- \
  notifications.argoproj.io/subscribe.on-health-status-change.email- \
  notifications.argoproj.io/notified.on-sync-status-change.email- \
  notifications.argoproj.io/notified.on-health-status-change.email- \
  notifications.argoproj.io/subscribe- \
  notified.notifications.argoproj.io- \
  --overwrite 2>/dev/null || true

# 2. Set ONLY webhook and email annotations (no discord)
echo "Setting correct notification annotations..."
kubectl annotate application $APPLICATION -n $NAMESPACE \
  notifications.argoproj.io/subscribe.on-sync-status-change.webhook="webhook" \
  notifications.argoproj.io/subscribe.on-health-status-change.webhook="webhook" \
  notifications.argoproj.io/subscribe.on-sync-status-change.email="ketankarki2626@gmail.com" \
  notifications.argoproj.io/subscribe.on-health-status-change.email="ketankarki2626@gmail.com" \
  --overwrite

# Extra step - Check that all discord annotations are removed
echo "Double checking all discord annotations are removed..."
ANNOTATIONS=$(kubectl get application $APPLICATION -n $NAMESPACE -o jsonpath='{.metadata.annotations}')
if [[ "$ANNOTATIONS" == *"discord"* ]]; then
  echo "⚠️ Discord annotations still found! Removing them again..."
  kubectl annotate application $APPLICATION -n $NAMESPACE \
    notifications.argoproj.io/subscribe.on-sync-status-change.discord- \
    notifications.argoproj.io/subscribe.on-health-status-change.discord- \
    notifications.argoproj.io/notified.on-sync-status-change.discord- \
    notifications.argoproj.io/notified.on-health-status-change.discord- \
    --overwrite 2>/dev/null || true
fi

# 3. Verify Discord webhook directly
echo "Testing Discord webhook directly..."
DISCORD_URL=$(kubectl get cm argocd-notifications-cm -n $NAMESPACE -o jsonpath='{.data.service\.webhook}' | grep url | awk '{print $2}')

if [ -z "$DISCORD_URL" ]; then
  echo "❌ Discord webhook URL not found in ConfigMap"
  exit 1
fi

echo "Testing webhook: $DISCORD_URL"
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{"content": "Test message from reset script", "embeds": [{"title": "Reset Test", "description": "Testing if webhook works after reset", "color": 3066993}]}' \
  "$DISCORD_URL"

# 4. Restart notification controller
echo "Restarting notification controller..."
kubectl rollout restart deployment argocd-notifications-controller -n $NAMESPACE
kubectl rollout status deployment argocd-notifications-controller -n $NAMESPACE

# 5. Manually trigger a notification by causing sync status change
echo "Triggering a sync to generate notifications..."
kubectl patch application $APPLICATION -n $NAMESPACE --type=merge \
  -p "{\"metadata\":{\"annotations\":{\"force-sync-timestamp\":\"$(date +%s)\"}}}"

echo "Waiting for notifications to be generated (15 seconds)..."
sleep 15

echo "===== Reset Complete ====="
echo "Check Discord for notifications and run 'kubectl logs -n argocd deployment/argocd-notifications-controller' to see notification logs"
