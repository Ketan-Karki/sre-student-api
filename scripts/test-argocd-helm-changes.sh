#!/bin/bash
# Script to test the ArgoCD configuration and Helm chart changes

set -e

echo "===== Testing ArgoCD Configuration Changes ====="

# Step 1: Apply ArgoCD configurations
echo "Applying ArgoCD ConfigMaps..."
cd /Users/ketan/Learning/sre-bootcamp-rest-api/argocd
kubectl apply -f argocd-cm.yaml
kubectl apply -f argocd-rbac-cm.yaml
kubectl apply -f argocd-notifications-cm.yaml

# Step 2: Verify ArgoCD components restart correctly
echo "Verifying ArgoCD components restart correctly..."
kubectl rollout restart deployment argocd-server -n argocd
kubectl rollout restart deployment argocd-repo-server -n argocd
kubectl rollout status deployment argocd-server -n argocd
kubectl rollout status deployment argocd-repo-server -n argocd

# Step 3: Test RBAC policies
echo "Testing RBAC policies..."
# Get admin password
ADMIN_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "Admin password: $ADMIN_PASSWORD"
echo "Use this password to log in and test RBAC policies manually"

# Step 4: Deploy an application to test notifications
echo "Deploying a test application to trigger notifications..."
kubectl apply -f application.yaml

echo "===== Testing Helm Chart Updates ====="

# Step 5: Clean up the namespace completely for a fresh start
echo "Cleaning up the namespace completely for a fresh start..."
cd /Users/ketan/Learning/sre-bootcamp-rest-api
./scripts/clean-helm-namespace.sh dev-student-api

# Step 6: Deploy the updated Helm chart
echo "Deploying the updated Helm chart..."
helm upgrade --install student-api ./helm-charts/student-api-helm \
  --namespace dev-student-api \
  --values ./helm-charts/student-api-helm/environments/dev/values.yaml

# Step 7: Wait for the deployment to be ready
echo "Waiting for deployment to be ready..."
kubectl wait --for=condition=available deployment/student-api -n dev-student-api --timeout=60s

# Step 8: Run API tests using the test script directly
echo "Running API tests..."
TEST_PORT=8899 NAMESPACE=dev-student-api ./helm-charts/student-api-helm/test.sh

echo "===== Testing ArgoCD UI ====="
echo "To access ArgoCD UI, run: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "Then navigate to https://localhost:8080 in your browser"
echo "Login with username: admin and password: $ADMIN_PASSWORD"
