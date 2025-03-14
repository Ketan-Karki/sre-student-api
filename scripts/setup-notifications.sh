#!/bin/bash
set -e

NAMESPACE="argocd"
DISCORD_WEBHOOK="https://discord.com/api/webhooks/1350041639560810518/4bsC9mOaTHv-h0grVpKLjkv3Nja_LPqtWoXiQnFm2B0CN4pyDdER7I1PlecJ9MVzdj2e"

# Function to setup email password
setup_email() {
    echo "Setting up email notifications..."
    read -sp "Enter Gmail app password: " password
    echo
    
    kubectl create secret generic argocd-notifications-secret \
        --namespace $NAMESPACE \
        --from-literal=email-password="$password" \
        --dry-run=client -o yaml | kubectl apply -f -
}

# Function to verify Discord webhook
verify_discord() {
    echo "Verifying Discord webhook..."
    response=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -d '{"content": "ArgoCD notifications test", "username": "ArgoCD Bot"}' \
        "$DISCORD_WEBHOOK")
    
    status_code=$(echo "$response" | tail -n1)
    response_body=$(echo "$response" | head -n-1)
    
    if [ "$status_code" = "204" ] || [ "$status_code" = "200" ]; then
        echo "✅ Discord webhook verified successfully"
    else
        echo "❌ Discord webhook verification failed"
        echo "Status code: $status_code"
        echo "Response: $response_body"
        exit 1
    fi
}

# Main setup
echo "Setting up ArgoCD notifications..."
setup_email
verify_discord

echo "Restarting ArgoCD notifications controller..."
kubectl rollout restart deployment argocd-notifications-controller -n $NAMESPACE
kubectl rollout status deployment argocd-notifications-controller -n $NAMESPACE

echo "Notifications setup complete!"
