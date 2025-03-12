#!/bin/bash

set -e

echo "=== Repository Authentication Fix for ArgoCD ==="

# Variables
REPO_URL="https://github.com/Ketan-Karki/student-api"
ARGOCD_NS="argocd"
APP_NAME="student-api"

# Functions
setup_basic_auth() {
    echo -e "\nStep 1: Creating repository credentials"
    echo "Enter your GitHub username:"
    read -p "> " GITHUB_USERNAME
    echo "Enter your GitHub personal access token (not password):"
    read -s -p "> " GITHUB_TOKEN
    echo ""

    # Create secret with clear name
    SECRET_NAME="repo-${GITHUB_USERNAME}"
    
    echo "Creating repository secret..."
    kubectl create secret generic $SECRET_NAME \
      --namespace $ARGOCD_NS \
      --from-literal=type=git \
      --from-literal=url="$REPO_URL" \
      --from-literal=username="$GITHUB_USERNAME" \
      --from-literal=password="$GITHUB_TOKEN" \
      --dry-run=client -o yaml | kubectl apply -f -
      
    echo "Secret created successfully with name: $SECRET_NAME"
    return 0
}

update_argocd_cm() {
    local SECRET_NAME=$1
    echo -e "\nUpdating ArgoCD ConfigMap..."
    
    # Create temporary repositories configuration
    cat > /tmp/repos.yaml << EOF
repositories: |
  - url: $REPO_URL
    usernameSecret:
      name: $SECRET_NAME
      key: username
    passwordSecret:
      name: $SECRET_NAME
      key: password
EOF

    if kubectl get cm argocd-cm -n $ARGOCD_NS &> /dev/null; then
        echo "Patching existing ConfigMap..."
        kubectl patch cm argocd-cm -n $ARGOCD_NS --patch "$(cat /tmp/repos.yaml)"
    else
        echo "Creating new ConfigMap..."
        kubectl create configmap argocd-cm -n $ARGOCD_NS --from-file=repositories=/tmp/repos.yaml
    fi
    
    rm /tmp/repos.yaml
}

create_application() {
    echo -e "\nCreating optimized application.yaml..."
    
    cat > /Users/ketan/Learning/sre-bootcamp-rest-api/argocd/application.yaml << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: student-api
  namespace: argocd
spec:
  project: default
  source:
    repoURL: $REPO_URL
    targetRevision: main
    path: helm-charts/student-api-helm
    helm:
      valueFiles:
        - environments/prod/values.yaml
      parameters:
        - name: nginx.configMap.name
          value: nginx-config
  destination:
    server: https://kubernetes.default.svc
    namespace: student-api
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF

    echo "Application manifest created"
}

restart_argocd() {
    echo -e "\nRestarting ArgoCD components..."
    kubectl rollout restart deployment argocd-repo-server -n $ARGOCD_NS
    kubectl rollout restart deployment argocd-application-controller -n $ARGOCD_NS
    echo "Waiting for components to restart..."
    sleep 10
}

# Main script

echo "Choose authentication method:"
echo "1. Basic username/token authentication (recommended)"
echo "2. SSH key authentication"
echo "3. Simple direct configuration"
read -p "Select option (1-3): " AUTH_METHOD

case $AUTH_METHOD in
    1)
        setup_basic_auth
        update_argocd_cm $SECRET_NAME
        ;;
    2)
        echo "SSH authentication setup..."
        read -p "Path to your SSH private key: " SSH_KEY_PATH
        
        if [ -f "$SSH_KEY_PATH" ]; then
            SSH_KEY=$(cat "$SSH_KEY_PATH")
            kubectl create secret generic repo-ssh-key \
              --namespace $ARGOCD_NS \
              --from-literal=sshPrivateKey="$SSH_KEY" \
              --dry-run=client -o yaml | kubectl apply -f -
              
            # Update ConfigMap for SSH
            SSH_REPO_URL=$(echo "$REPO_URL" | sed 's|https://github.com/|git@github.com:|')
            cat > /tmp/ssh-repos.yaml << EOF
repositories: |
  - url: $SSH_REPO_URL
    sshPrivateKeySecret:
      name: repo-ssh-key
      key: sshPrivateKey
EOF
            kubectl patch cm argocd-cm -n $ARGOCD_NS --patch "$(cat /tmp/ssh-repos.yaml)"
            rm /tmp/ssh-repos.yaml
        else
            echo "Error: SSH key file not found at $SSH_KEY_PATH"
            exit 1
        fi
        ;;
    3)
        echo "Simple configuration without credentials..."
        # For public repositories or when using other authentication methods
        cat > /tmp/simple-repos.yaml << EOF
repositories: |
  - url: $REPO_URL
EOF
        kubectl patch cm argocd-cm -n $ARGOCD_NS --patch "$(cat /tmp/simple-repos.yaml)"
        rm /tmp/simple-repos.yaml
        ;;
    *)
        echo "Invalid option selected"
        exit 1
        ;;
esac

# Common steps for all methods
create_application
restart_argocd

# Delete and recreate application
echo -e "\nRecreating application..."
kubectl delete application $APP_NAME -n $ARGOCD_NS --ignore-not-found=true
sleep 3
kubectl apply -f /Users/ketan/Learning/sre-bootcamp-rest-api/argocd/application.yaml

# Offer to open ArgoCD UI
echo -e "\n=== Repository authentication setup completed ==="
echo "Would you like to open the ArgoCD UI? (y/n)"
read -p "> " OPEN_UI

if [[ "$OPEN_UI" == "y" ]]; then
    PASSWORD=$(kubectl -n $ARGOCD_NS get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    echo "Username: admin"
    echo "Password: $PASSWORD"
    
    echo "Starting port-forward to ArgoCD UI..."
    echo "Access at https://localhost:8080"
    echo "Press Ctrl+C when done"
    kubectl port-forward svc/argocd-server -n $ARGOCD_NS 8080:443
fi
