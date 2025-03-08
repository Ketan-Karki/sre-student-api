#!/bin/bash
# Script to test Discord webhook directly

WEBHOOK_URL="https://discord.com/api/webhooks/1347263141410635827/LJXyvLmdvU-SRjYX1kpY7JxYOQcyKcpuF5iK05nJQEmPv9qZrmQMdfILAu-vmVYPJqWz"

echo "Testing Discord webhook with a simple message..."
curl -X POST -H "Content-Type: application/json" \
  -d '{
    "content": "This is a test message from curl",
    "embeds": [{
      "title": "Test Message",
      "description": "Testing Discord webhook from command line",
      "color": 5025616
    }]
  }' \
  $WEBHOOK_URL

echo -e "\n\nIf you see no error message, the webhook should work. Check Discord for the message."
