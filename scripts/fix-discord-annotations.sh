#!/bin/bash
set -e

NAMESPACE="argocd"
APPLICATION="student-api"

echo "===== Fixing Discord Annotation Issues ====="

# 1. Dump all current annotations for debugging
echo "Current annotations:"
kubectl get application $APPLICATION -n $NAMESPACE -o jsonpath='{.metadata.annotations}' | jq .

# 2. Remove ALL discord-related annotations
echo "Removing ALL discord-related annotations..."
kubectl annotate application $APPLICATION -n $NAMESPACE \
  notifications.argoproj.io/subscribe.on-sync-status-change.discord- \
  notifications.argoproj.io/subscribe.on-health-status-change.discord- \
  notifications.argoproj.io/notified.on-sync-status-change.discord- \
  notifications.argoproj.io/notified.on-health-status-change.discord- \
  --overwrite 2>/dev/null || true

# 3. Reset notification tracking
echo "Resetting notification tracking..."
kubectl annotate application $APPLICATION -n $NAMESPACE \
  notified.notifications.argoproj.io- \
  --overwrite 2>/dev/null || true

# 4. Restart notification controller
echo "Restarting notification controller..."
kubectl rollout restart deployment argocd-notifications-controller -n $NAMESPACE
kubectl rollout status deployment argocd-notifications-controller -n $NAMESPACE

echo "===== Verification ====="
echo "Checking for any remaining discord annotations:"
kubectl get application $APPLICATION -n $NAMESPACE -o jsonpath='{.metadata.annotations}' | grep -i discord || echo "✅ No discord annotations found"

echo "Checking webhook annotations exist:"
kubectl get application $APPLICATION -n $NAMESPACE -o jsonpath='{.metadata.annotations}' | grep -i webhook || echo "⚠️ No webhook annotations found"

echo "===== Fix Complete ====="
echo "Run 'make test-notifications' to test if notifications are working correctly now"
