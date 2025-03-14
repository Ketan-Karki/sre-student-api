#!/bin/bash
set -e

# Update this to match the URL in your ConfigMap
WEBHOOK_URL="https://discord.com/api/webhooks/1350127006787965008/JK5lUezX-oh4eJy2S5BSpwpC5vsry7W1gNv5Qm2h4BWbCGL-6L_9G-9LphRTPQHSRtc8"

echo "Testing Discord webhook directly..."
response=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d '{
        "content": "Testing webhook from script",
        "embeds": [
            {
                "title": "Test Message",
                "description": "This is a direct test of the Discord webhook",
                "color": 5025616
            }
        ]
    }' \
    "$WEBHOOK_URL")

echo "Response: $response"

# Check if curl succeeded
if [ $? -eq 0 ]; then
    if [[ "$response" == *"Unknown Webhook"* ]]; then
        echo "❌ Discord webhook test failed: Unknown Webhook"
        echo "The webhook URL is invalid. Please update the webhook URL:"
        echo "1. Create a new webhook in Discord Server Settings -> Integrations -> Webhooks"
        echo "2. Copy the Webhook URL"
        echo "3. Update the URL in argocd/argocd-notifications-cm.yaml"
    elif [ -z "$response" ]; then
        echo "✅ Discord webhook test likely passed (empty response indicates success)"
    else
        echo "❌ Discord webhook test failed"
        echo "Response: $response"
    fi
else
    echo "❌ Discord webhook request failed"
fi
