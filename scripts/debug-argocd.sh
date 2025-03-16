#!/bin/bash

set -e

echo "=== Comprehensive ArgoCD and Helm Debugging ==="

# Variables
NAMESPACE="student-api"
ARGOCD_NS="argocd"
APP_NAME="student-api"
REPO_URL="https://github.com/Ketan-Karki/sre-student-api"
CHART_PATH="helm-charts/student-api-helm"

# Functions
check_application_status() {
    echo "Step 1: Checking application status"
    kubectl get application $APP_NAME -n $ARGOCD_NS -o yaml > /tmp/app-details.yaml
    
    echo "Sync status:"
    kubectl get application $APP_NAME -n $ARGOCD_NS -o jsonpath='{.status.sync.status}{"\n"}'
    
    echo "Health status:"
    kubectl get application $APP_NAME -n $ARGOCD_NS -o jsonpath='{.status.health.status}{"\n"}'
    
    echo -e "\nExtracted error messages:"
    kubectl get application $APP_NAME -n $ARGOCD_NS -o jsonpath='{.status.conditions[*].message}' || echo "No error messages found"
}

check_resources() {
    echo -e "\nStep 2: Checking deployed resources"
    
    echo "Namespace status:"
    kubectl get namespace $NAMESPACE 2>/dev/null || echo "Namespace $NAMESPACE does not exist"
    
    if kubectl get namespace $NAMESPACE &>/dev/null; then
        echo -e "\nResources in namespace:"
        kubectl get all -n $NAMESPACE
        
        echo -e "\nConfigMaps:"
        kubectl get cm -n $NAMESPACE
        
        echo -e "\nSecrets:"
        kubectl get secrets -n $NAMESPACE
        
        echo -e "\nPVCs:"
        kubectl get pvc -n $NAMESPACE
    fi
}

analyze_helm_chart() {
    echo -e "\nStep 3: Analyzing Helm chart"
    
    # Create temp directory for chart analysis
    TEMP_DIR=$(mktemp -d)
    echo "Created temporary workspace at: $TEMP_DIR"
    
    # Clone repository
    echo "Cloning repository for Helm testing..."
    git clone $REPO_URL $TEMP_DIR/repo || { echo "Failed to clone repository"; return 1; }
    
    CHART_DIR="$TEMP_DIR/repo/$CHART_PATH"
    if [ ! -d "$CHART_DIR" ]; then
        echo "❌ Chart directory not found at $CHART_PATH"
        return 1
    fi
    
    # Validate chart
    echo "Running helm lint..."
    helm lint "$CHART_DIR" > /tmp/helm-lint-output.txt || echo "⚠️ Helm lint found issues"
    
    # Template the chart
    echo "Running helm template..."
    helm template test "$CHART_DIR" > "$TEMP_DIR/manifests.yaml"
    
    echo "Generated resources:"
    grep -A1 "kind: " "$TEMP_DIR/manifests.yaml" | grep -v -- "--" | sort | uniq -c
    
    # Check for common issues
    echo -e "\nChecking for common issues..."
    
    echo "PVC configuration:"
    grep -A 20 "PersistentVolumeClaim" "$TEMP_DIR/manifests.yaml" || echo "No PVC definitions found"
    
    echo -e "\nDeployment selectors:"
    grep -A 10 "selector:" "$TEMP_DIR/manifests.yaml" || echo "No selectors found"
    
    # Cleanup
    rm -rf "$TEMP_DIR"
}

check_argocd_logs() {
    echo -e "\nStep 4: Checking ArgoCD logs"
    
    echo "Application controller logs (last 30 lines with errors):"
    kubectl logs -n $ARGOCD_NS -l app.kubernetes.io/name=argocd-application-controller --tail=100 | grep -i error | tail -30
    
    echo -e "\nRepo server logs (last 30 lines with errors):"
    kubectl logs -n $ARGOCD_NS -l app.kubernetes.io/name=argocd-repo-server --tail=100 | grep -i error | tail -30
}

test_deployment() {
    echo -e "\nStep 5: Testing deployment"
    
    # Create a test pod
    cat > /tmp/test-pod.yaml << EOF
apiVersion: v1
kind: Pod
metadata:
  name: debug-pod
  namespace: $NAMESPACE
spec:
  containers:
  - name: debug
    image: nicolaka/netshoot
    command: ['sleep', '3600']
EOF

    echo "Creating debug pod..."
    kubectl apply -f /tmp/test-pod.yaml
    
    echo "Waiting for debug pod to be ready..."
    kubectl wait --for=condition=ready pod/debug-pod -n $NAMESPACE --timeout=60s || echo "Debug pod not ready"
    
    if kubectl get pod debug-pod -n $NAMESPACE &>/dev/null; then
        echo -e "\nTesting service connectivity:"
        kubectl exec -it debug-pod -n $NAMESPACE -- curl -v student-api:8080 || echo "Service connectivity test failed"
    fi
}

# Main execution
check_application_status
check_resources
analyze_helm_chart
check_argocd_logs
test_deployment

# Cleanup
echo -e "\nCleaning up debug resources..."
kubectl delete pod debug-pod -n $NAMESPACE --ignore-not-found

echo -e "\n=== Debug Summary ==="
if grep -qi "error" /tmp/helm-lint-output.txt 2>/dev/null; then
    echo "❌ Helm chart has linting errors that need to be fixed"
elif grep -qi "warning" /tmp/helm-lint-output.txt 2>/dev/null; then
    echo "⚠️ Helm chart has warnings, but may still work"
else
    echo "✅ Helm chart passed linting"
fi

echo -e "\nRecommendations:"
echo "1. Check your Helm chart templates for syntax errors"
echo "2. Ensure all required values have defaults"
echo "3. For dry-run errors, try deploying with the 'Replace' option"
echo "4. Check the full debugging output for specific issues"

# Offer to open ArgoCD UI
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
