#!/bin/bash

set -e

echo "=== Clean Slate Reset for ArgoCD ==="

# Variables
NAMESPACE="student-api"
ARGOCD_NS="argocd"
APP_NAME="student-api"
REPO_URL="https://github.com/Ketan-Karki/student-api"

# Functions
clean_namespace() {
    echo "Step 1: Cleaning up namespace $NAMESPACE"
    
    # Check if namespace exists
    if kubectl get namespace $NAMESPACE &>/dev/null; then
        echo "Deleting namespace $NAMESPACE..."
        kubectl delete namespace $NAMESPACE
        
        echo "Waiting for namespace deletion..."
        while kubectl get namespace $NAMESPACE &>/dev/null; do
            echo -n "."
            sleep 2
        done
        echo -e "\nNamespace deleted"
    else
        echo "Namespace $NAMESPACE does not exist"
    fi
}

clean_argocd_config() {
    echo -e "\nStep 2: Cleaning ArgoCD configuration"
    
    # Remove repository credentials
    echo "Removing repository credentials..."
    kubectl get secrets -n $ARGOCD_NS | grep -i repo | awk '{print $1}' | while read -r secret; do
        echo "Deleting secret: $secret"
        kubectl delete secret -n $ARGOCD_NS "$secret" --ignore-not-found
    done
    
    # Reset ConfigMap
    echo "Resetting ArgoCD ConfigMap..."
    cat > /tmp/argocd-cm-minimal.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-cm
    app.kubernetes.io/part-of: argocd
data:
  timeout.reconciliation: 180s
EOF
    
    kubectl apply -f /tmp/argocd-cm-minimal.yaml
    rm /tmp/argocd-cm-minimal.yaml
}

create_fresh_application() {
    echo -e "\nStep 3: Creating fresh application configuration"
    
    # Delete existing application
    kubectl delete application $APP_NAME -n $ARGOCD_NS --ignore-not-found
    sleep 3
    
    # Create new application.yaml
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
      - ServerSideApply=true
EOF
    
    echo "Applying new application configuration..."
    kubectl apply -f /Users/ketan/Learning/sre-bootcamp-rest-api/argocd/application.yaml
}

restart_argocd() {
    echo -e "\nStep 4: Restarting ArgoCD components"
    kubectl rollout restart deployment/argocd-repo-server -n $ARGOCD_NS
    kubectl rollout restart deployment/argocd-application-controller -n $ARGOCD_NS
    echo "Waiting for components to restart..."
    sleep 15
}

# Main execution
echo "This will completely reset ArgoCD configuration and your application."
echo "This includes deleting the namespace $NAMESPACE and all its resources."
echo "Are you sure you want to continue? (y/n)"
read -p "> " CONFIRM

if [[ "$CONFIRM" != "y" ]]; then
    echo "Operation cancelled"
    exit 0
fi

# Execute steps
clean_namespace
clean_argocd_config
create_fresh_application
restart_argocd

# Final status check
echo -e "\n=== Reset Complete ==="
echo "Checking application status:"
kubectl get application $APP_NAME -n $ARGOCD_NS

echo -e "\nWould you like to open the ArgoCD UI? (y/n)"
read -p "> " OPEN_UI

if [[ "$OPEN_UI" == "y" ]]; then
    PASSWORD=$(kubectl -n $ARGOCD_NS get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    echo "Username: admin"
    echo "Password: $PASSWORD"
    
    echo "Starting port-forward to ArgoCD UI..."
    echo "Press Ctrl+C when done"
    kubectl port-forward svc/argocd-server -n $ARGOCD_NS 8080:443
fi
