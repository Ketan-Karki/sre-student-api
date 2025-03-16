#!/bin/bash

set -e

echo "=== Final ArgoCD Deployment Fix ==="

NAMESPACE="student-api"
ARGOCD_NS="argocd"
APP_NAME="student-api"

# 1. Check application status and error
echo "Step 1: Checking application status and error"
echo "Current application status:"
kubectl get application $APP_NAME -n $ARGOCD_NS

# Get error message safely
ERROR=$(kubectl get application $APP_NAME -n $ARGOCD_NS -o jsonpath="{.status.conditions[0].message}" 2>/dev/null || echo "No error message found")
echo -e "\nError message: $ERROR"

# 2. Clean up existing namespace (with option to cancel)
echo -e "\nStep 2: Do you want to delete the existing namespace for a clean slate? (y/n)"
echo "WARNING: This will delete ALL resources in the $NAMESPACE namespace!"
read -p "> " DELETE_NS

if [[ "$DELETE_NS" == "y" ]]; then
  echo "Deleting namespace $NAMESPACE..."
  kubectl delete namespace $NAMESPACE --ignore-not-found=true
  
  echo "Waiting for namespace to be deleted..."
  while kubectl get namespace $NAMESPACE &>/dev/null; do
    echo -n "."
    sleep 2
  done
  echo "Namespace deleted"
fi

# 3. Create simplified application with fixes
echo -e "\nStep 3: Creating simplified application definition"

# Create backup of current application
BACKUP_FILE="/tmp/argocd-app-backup-$(date +%s).yaml"
kubectl get application $APP_NAME -n $ARGOCD_NS -o yaml > $BACKUP_FILE 2>/dev/null || echo "No existing application to backup"
echo "Backup saved to $BACKUP_FILE"

# Create simplified application
cat > /Users/ketan/Learning/sre-bootcamp-rest-api/argocd/application.yaml << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: student-api
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/Ketan-Karki/sre-student-api
    targetRevision: main
    path: helm-charts/student-api-helm
    helm:
      valueFiles:
        - environments/prod/values.yaml
      parameters:
        - name: namespace.name
          value: student-api
  destination:
    server: https://kubernetes.default.svc
    namespace: student-api
  syncPolicy:
    automated: {}
    syncOptions:
      - CreateNamespace=true
EOF

echo "Created simplified application.yaml"

# 4. Apply the application
echo -e "\nStep 4: Applying the application"
kubectl apply -f /Users/ketan/Learning/sre-bootcamp-rest-api/argocd/application.yaml
echo "Application applied"

# 5. Create namespace manually
echo -e "\nStep 5: Creating namespace manually"
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
echo "Namespace created/verified"

# 6. Restart ArgoCD components
echo -e "\nStep 6: Restarting ArgoCD components"
kubectl rollout restart deployment/argocd-repo-server -n $ARGOCD_NS
echo "ArgoCD repo server restarted"

# Find the right controller component
CONTROLLER_EXISTS=$(kubectl get statefulset -n $ARGOCD_NS 2>/dev/null | grep application-controller || echo "")
if [ -n "$CONTROLLER_EXISTS" ]; then
  kubectl rollout restart statefulset/argocd-application-controller -n $ARGOCD_NS
  echo "ArgoCD application controller (statefulset) restarted"
else
  kubectl rollout restart deployment/argocd-application-controller -n $ARGOCD_NS 2>/dev/null || \
    echo "No application controller found - may not need restart"
fi

# 7. Repair any PVC issues by updating helmfile
echo -e "\nStep 7: Checking for PVC issues in values file..."
VALUES_FILE="/Users/ketan/Learning/sre-bootcamp-rest-api/helm-charts/student-api-helm/environments/prod/values.yaml"

if [ -f "$VALUES_FILE" ]; then
  echo "Values file found. Would you like to modify it to fix common storage issues? (y/n)"
  read -p "> " MODIFY_VALUES
  
  if [[ "$MODIFY_VALUES" == "y" ]]; then
    # Create backup
    cp "$VALUES_FILE" "${VALUES_FILE}.bak"
    echo "Backup created at ${VALUES_FILE}.bak"
    
    # Update storage settings
    # (Replace this with actual modifications if needed)
    echo "Would need to modify values file here if specific changes were needed"
    echo "No changes made to values file"
  fi
else
  echo "Values file not found at $VALUES_FILE"
fi

# 8. Check status after changes
echo -e "\nStep 8: Waiting for changes to take effect..."
sleep 10
echo "Current application status:"
kubectl get application $APP_NAME -n $ARGOCD_NS

# 9. Force sync if needed
echo -e "\nStep 9: Do you want to force a sync with replace? (y/n)"
read -p "> " DO_SYNC

if [[ "$DO_SYNC" == "y" ]]; then
  echo "Would you like to open the ArgoCD UI to perform the sync? (y/n)"
  read -p "> " OPEN_UI
  
  if [[ "$OPEN_UI" == "y" ]]; then
    PASSWORD=$(kubectl -n $ARGOCD_NS get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "Could not get password")
    echo -e "\nArgoCD UI Access:"
    echo "Username: admin"
    echo "Password: $PASSWORD"
    echo -e "\nSync instructions:"
    echo "1. Click on the 'student-api' application"
    echo "2. Click 'SYNC'"
    echo "3. Check 'REPLACE' and 'FORCE' options"  
    echo "4. Click 'SYNCHRONIZE'"
    
    echo -e "\nStarting port-forward to ArgoCD UI..."
    echo "Access at https://localhost:8080"
    echo "Press Ctrl+C when done with sync"
    kubectl port-forward svc/argocd-server -n $ARGOCD_NS 8080:443
  fi
fi

echo -e "\n=== Fix completed ==="
echo "If problems persist:"
echo "1. Check for errors in the Helm chart itself"
echo "2. Try completely deleting the namespace and application, then recreate"
echo "3. Visit ArgoCD UI to see detailed error messages"
