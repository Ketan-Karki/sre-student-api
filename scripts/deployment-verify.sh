#!/bin/bash

set -e

echo "=== Comprehensive Deployment Verification ==="

# Variables
NAMESPACE="student-api"
ARGOCD_NS="argocd"
APP_NAME="student-api"

# Functions
check_prerequisites() {
    echo "Checking prerequisites..."
    command -v kubectl >/dev/null 2>&1 || { echo "kubectl required but not found"; exit 1; }
    command -v helm >/dev/null 2>&1 || { echo "helm required but not found"; exit 1; }
}

check_argocd_status() {
    echo -e "\nChecking ArgoCD application status..."
    kubectl get application $APP_NAME -n $ARGOCD_NS -o yaml > /tmp/app-status.yaml
    
    echo "Sync status:"
    kubectl get application $APP_NAME -n $ARGOCD_NS -o jsonpath='{.status.sync.status}{"\n"}'
    
    echo "Health status:"
    kubectl get application $APP_NAME -n $ARGOCD_NS -o jsonpath='{.status.health.status}{"\n"}'
    
    echo -e "\nError conditions:"
    kubectl get application $APP_NAME -n $ARGOCD_NS -o jsonpath='{.status.conditions[*].message}' || echo "No error conditions found"
}

check_resources() {
    echo -e "\nChecking Kubernetes resources..."
    
    # Check namespace
    if ! kubectl get namespace $NAMESPACE &>/dev/null; then
        echo "❌ Namespace $NAMESPACE does not exist"
        return 1
    fi
    
    # List all resources
    echo -e "\nDeployments:"
    kubectl get deployments -n $NAMESPACE
    
    echo -e "\nPods:"
    kubectl get pods -n $NAMESPACE
    
    echo -e "\nServices:"
    kubectl get services -n $NAMESPACE
    
    echo -e "\nConfigMaps:"
    kubectl get configmaps -n $NAMESPACE
    
    echo -e "\nPVCs:"
    kubectl get pvc -n $NAMESPACE
}

check_logs() {
    echo -e "\nChecking logs..."
    
    # ArgoCD logs
    echo "ArgoCD controller logs (errors only):"
    kubectl logs -n $ARGOCD_NS -l app.kubernetes.io/name=argocd-application-controller --tail=50 | grep -i error
    
    # Application logs
    echo -e "\nApplication pod logs:"
    kubectl get pods -n $NAMESPACE -o name | while read pod; do
        echo -e "\nLogs for $pod:"
        kubectl logs $pod -n $NAMESPACE --tail=20
    done
}

test_connectivity() {
    echo -e "\nTesting service connectivity..."
    
    # Create debug pod
    cat > /tmp/debug-pod.yaml << EOF
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

    kubectl apply -f /tmp/debug-pod.yaml
    echo "Waiting for debug pod..."
    kubectl wait --for=condition=ready pod/debug-pod -n $NAMESPACE --timeout=30s
    
    echo "Testing service endpoints..."
    kubectl exec -it debug-pod -n $NAMESPACE -- curl -v student-api:8080 || echo "Service connectivity test failed"
    
    kubectl delete pod debug-pod -n $NAMESPACE --ignore-not-found
}

# ...rest of implementation...
