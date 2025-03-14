#!/bin/bash
set -e

# This script helps update the Discord webhook URL in the ArgoCD notifications ConfigMap

# Check if the user provided a webhook URL
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <new-webhook-url>"
    echo "Example: $0 https://discord.com/api/webhooks/1234567890/your-token"
    exit 1
fi

NEW_WEBHOOK_URL="$1"
NAMESPACE="argocd"
CONFIG_MAP_FILE="/Users/ketan/Learning/sre-bootcamp-rest-api/argocd/argocd-notifications-cm.yaml"

echo "Updating webhook URL in ConfigMap file..."

# Use sed to replace the webhook URL in the ConfigMap file
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS requires an empty string for -i
    sed -i '' "s|url: https://discord.com/api/webhooks/[^/]*/[^ ]*|url: $NEW_WEBHOOK_URL|g" "$CONFIG_MAP_FILE"
else
    # Linux doesn't require an empty string for -i
    sed -i "s|url: https://discord.com/api/webhooks/[^/]*/[^ ]*|url: $NEW_WEBHOOK_URL|g" "$CONFIG_MAP_FILE"
fi

echo "Applying updated ConfigMap..."
kubectl apply -f "$CONFIG_MAP_FILE"

echo "Restarting the ArgoCD notifications controller..."
kubectl rollout restart deployment argocd-notifications-controller -n "$NAMESPACE"
kubectl rollout status deployment argocd-notifications-controller -n "$NAMESPACE"

echo "Testing the new webhook..."
curl -s -X POST \
    -H "Content-Type: application/json" \
    -d '{"content": "Test message from update script", "embeds": [{"title": "Webhook Update Test", "description": "Testing if the new webhook URL works", "color": 3066993}]}' \
    "$NEW_WEBHOOK_URL"

echo -e "\nWebhook URL updated successfully. Run 'make test-notifications' to test notifications."
