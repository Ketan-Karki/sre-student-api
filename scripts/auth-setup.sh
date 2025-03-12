#!/bin/bash

set -e

echo "=== ArgoCD Repository Authentication Setup ==="

# Variables
REPO_URL="https://github.com/Ketan-Karki/student-api"
ARGOCD_NS="argocd"
APP_NAME="student-api"

# Functions
setup_auth() {
    local auth_type=$1
    local secret_name

    case $auth_type in
        "basic")
            echo "Enter GitHub username:"
            read -p "> " GITHUB_USERNAME
            echo "Enter GitHub personal access token (not password):"
            read -s -p "> " GITHUB_TOKEN
            echo ""
            
            secret_name="repo-${GITHUB_USERNAME}"
            kubectl create secret generic $secret_name \
                --namespace $ARGOCD_NS \
                --from-literal=type=git \
                --from-literal=url="$REPO_URL" \
                --from-literal=username="$GITHUB_USERNAME" \
                --from-literal=password="$GITHUB_TOKEN" \
                --dry-run=client -o yaml | kubectl apply -f -
            ;;
        "ssh")
            read -p "Path to SSH private key: " SSH_KEY_PATH
            if [ ! -f "$SSH_KEY_PATH" ]; then
                echo "Error: SSH key not found at $SSH_KEY_PATH"
                return 1
            fi
            
            secret_name="repo-ssh-key"
            kubectl create secret generic $secret_name \
                --namespace $ARGOCD_NS \
                --from-file=sshPrivateKey="$SSH_KEY_PATH" \
                --dry-run=client -o yaml | kubectl apply -f -
            REPO_URL=$(echo "$REPO_URL" | sed 's|https://github.com/|git@github.com:|')
            ;;
        "none")
            secret_name=""
            ;;
    esac

    echo "Secret '$secret_name' created"
    echo "$secret_name"
}

update_argocd_config() {
    local auth_type=$1
    local secret_name=$2
    
    # Create ConfigMap patch based on auth type
    if [ "$auth_type" = "basic" ]; then
        cat > /tmp/repo-cm.yaml << EOF
repositories: |
    - url: $REPO_URL
      usernameSecret:
        name: $secret_name
        key: username
      passwordSecret:
        name: $secret_name
        key: password
EOF
    elif [ "$auth_type" = "ssh" ]; then
        cat > /tmp/repo-cm.yaml << EOF
repositories: |
    - url: $REPO_URL
      sshPrivateKeySecret:
        name: $secret_name
        key: sshPrivateKey
EOF
    else
        cat > /tmp/repo-cm.yaml << EOF
repositories: |
    - url: $REPO_URL
EOF
    fi

    # Update ConfigMap
    if kubectl get cm argocd-cm -n $ARGOCD_NS &> /dev/null; then
        kubectl patch cm argocd-cm -n $ARGOCD_NS --patch-file /tmp/repo-cm.yaml
    else
        kubectl create configmap argocd-cm -n $ARGOCD_NS --from-file=repositories=/tmp/repo-cm.yaml
    fi
    
    rm /tmp/repo-cm.yaml
}

# Main script
echo "Choose authentication method:"
echo "1. Username/token (recommended)"
echo "2. SSH key"
echo "3. No authentication (public repo)"
read -p "Select option (1-3): " AUTH_OPTION

case $AUTH_OPTION in
    1) 
        SECRET_NAME=$(setup_auth "basic")
        update_argocd_config "basic" "$SECRET_NAME"
        ;;
    2)
        SECRET_NAME=$(setup_auth "ssh")
        update_argocd_config "ssh" "$SECRET_NAME"
        ;;
    3)
        setup_auth "none"
        update_argocd_config "none" ""
        ;;
    *)
        echo "Invalid option"
        exit 1
        ;;
esac

# Restart ArgoCD components
echo "Restarting ArgoCD components..."
kubectl rollout restart deployment argocd-repo-server -n $ARGOCD_NS
kubectl rollout restart deployment argocd-application-controller -n $ARGOCD_NS

echo "Waiting for restart..."
sleep 10

# Verify setup
echo "Verifying repository connection..."
if kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-repo-server -n $ARGOCD_NS --timeout=30s; then
    echo "✅ Repository server ready"
else
    echo "⚠️ Repository server not ready, check logs"
fi

# Offer UI access
echo -e "\nWould you like to open ArgoCD UI? (y/n)"
read -p "> " OPEN_UI

if [[ "$OPEN_UI" == "y" ]]; then
    PASSWORD=$(kubectl -n $ARGOCD_NS get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    echo "Username: admin"
    echo "Password: $PASSWORD"
    echo "Starting port-forward..."
    kubectl port-forward svc/argocd-server -n $ARGOCD_NS 8080:443
fi
