#!/bin/bash

set -e

echo "=== Simple Repository Access Setup for ArgoCD ==="

# Variables
REPO_URL="https://github.com/Ketan-Karki/sre-student-api"
ARGOCD_NAMESPACE="argocd"
APP_NAME="student-api"

# 1. Create credentials secret
echo -e "\nStep 1: Creating repository credentials"
echo "Enter your GitHub username:"
read -p "> " GITHUB_USERNAME
echo "Enter your GitHub personal access token (not password):"
read -s -p "> " GITHUB_TOKEN
echo ""

# Simple secret name to avoid issues - FIXED: Convert username to lowercase
SECRET_NAME="repo-$(echo ${GITHUB_USERNAME} | tr '[:upper:]' '[:lower:]')"

# Create secret for ArgoCD repositories
echo "Creating repository secret..."
kubectl create secret generic $SECRET_NAME \
  --namespace $ARGOCD_NAMESPACE \
  --from-literal=type=git \
  --from-literal=url="$REPO_URL" \
  --from-literal=username="$GITHUB_USERNAME" \
  --from-literal=password="$GITHUB_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Secret created successfully with name: $SECRET_NAME"

# 2. Create a temporary file with repositories configuration
echo -e "\nStep 2: Creating repositories configuration"
cat > /tmp/repos.yaml << EOF
data:
  repositories: |
    - url: $REPO_URL
      usernameSecret:
        name: $SECRET_NAME
        key: username
      passwordSecret:
        name: $SECRET_NAME
        key: password
EOF

echo "Repository configuration created"

# 3. Apply the configuration to the ConfigMap
echo -e "\nStep 3: Updating ArgoCD ConfigMap"
echo "Checking if ConfigMap exists..."
if kubectl get cm argocd-cm -n $ARGOCD_NAMESPACE &> /dev/null; then
  echo "Patching existing ConfigMap..."
  kubectl patch cm argocd-cm -n $ARGOCD_NAMESPACE --patch-file /tmp/repos.yaml
else
  echo "Creating new ConfigMap..."
  kubectl create configmap argocd-cm -n $ARGOCD_NAMESPACE --from-literal=repositories="- url: $REPO_URL
    usernameSecret:
      name: $SECRET_NAME
      key: username
    passwordSecret:
      name: $SECRET_NAME
      key: password"
fi

echo "ConfigMap updated successfully"

# 4. Restart ArgoCD components
echo -e "\nStep 4: Restarting ArgoCD components"
echo "Restarting repo server..."
kubectl rollout restart deployment argocd-repo-server -n $ARGOCD_NAMESPACE
echo "Restarting application controller..."
# Fix: Use statefulset instead of deployment for application controller
kubectl rollout restart statefulset argocd-application-controller -n $ARGOCD_NAMESPACE || echo "Note: If this failed, the controller might be deployed differently in your setup"

# 4.5 Directly delete the conflicting application
echo -e "\nStep 4.5: Removing conflicting application..."
echo "Deleting student-api-prod application..."
kubectl delete application student-api-prod -n $ARGOCD_NAMESPACE --ignore-not-found=true

echo "Waiting for deletion to complete..."
sleep 5

echo "Waiting for components to restart..."
sleep 10

# 5. Update and apply application.yaml with simplified configuration
echo -e "\nStep 5: Updating Application manifest"
APP_YAML="/Users/ketan/Learning/sre-bootcamp-rest-api/argocd/application.yaml"

# Create a backup
cp "$APP_YAML" "${APP_YAML}.bak" 2>/dev/null || echo "No existing application.yaml to backup"

# Create a clean application.yaml with comprehensive ignoreDifferences
cat > "$APP_YAML" << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: student-api
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "1"
spec:
  project: default
  source:
    repoURL: $REPO_URL
    targetRevision: HEAD
    path: helm-charts/student-api-helm
    helm:
      valueFiles:
        - environments/prod/values.yaml
      parameters:
        - name: nginx.configMap.name
          value: nginx-config
        # Use a different namespace to avoid conflicts
        - name: namespace.name
          value: student-api
  destination:
    server: https://kubernetes.default.svc
    # Use a different namespace to avoid conflicts with prod-student-api
    namespace: student-api
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
      - ApplyOutOfSyncOnly=true
      - ServerSideApply=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
  # Comprehensive ignoreDifferences to handle all immutable fields
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/selector
        - /spec/template/metadata/labels
    - group: ""
      kind: PersistentVolumeClaim
      jsonPointers:
        - /spec/volumeName
        - /spec/storageClassName
        - /spec/volumeMode
EOF

echo "Application manifest updated with comprehensive immutable field handling"

# 6. Delete and re-apply application
echo -e "\nStep 6: Recreating application"
echo "Deleting application if it exists..."
kubectl delete application $APP_NAME -n $ARGOCD_NAMESPACE --ignore-not-found=true

echo "Waiting a few seconds..."
sleep 3

echo "Creating application..."
kubectl apply -f "$APP_YAML"

# 7. Verify deployment
echo -e "\nStep 7: Verifying deployment"
echo "Waiting for application to be created..."
sleep 5

echo "Application status:"
kubectl get application $APP_NAME -n $ARGOCD_NAMESPACE

# 8. Show how to access UI
echo -e "\n=== Setup completed ==="
echo "To check the application in ArgoCD UI:"
echo ""
echo "1. Start port-forward with: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "2. Open https://localhost:8080 in your browser"
echo "3. Login credentials:"
echo "   Username: admin"
ADMIN_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "Error getting password")
echo "   Password: $ADMIN_PASSWORD"
echo ""
echo "4. Click on the 'student-api' application to view its status"
echo ""
echo "If repository access issues persist:"
echo "1. Check repo server logs: kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server --tail=20"
echo "2. Consider temporarily making the repository public for testing"
echo "3. Make sure your GitHub token has the 'repo' scope permissions"
echo ""
echo "Would you like to open the ArgoCD UI now? (y/n)"
read -p "> " OPEN_UI

if [ "$OPEN_UI" = "y" ]; then
  echo "Starting port-forward to ArgoCD UI..."
  echo "Access at https://localhost:8080"
  echo "Press Ctrl+C when done"
  kubectl port-forward svc/argocd-server -n argocd 8080:443
fi
