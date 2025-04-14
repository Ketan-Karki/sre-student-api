#!/bin/bash

set -e
NAMESPACE="student-api"

echo "=== Verifying Student API Setup ==="

# Delete existing deployment and configmap to ensure clean state
echo "Cleaning up existing resources..."
kubectl delete deployment student-api -n $NAMESPACE --ignore-not-found=true
kubectl delete configmap student-api-config -n $NAMESPACE --ignore-not-found=true

# Apply Helm changes
echo "Applying Helm changes..."
helm upgrade --install student-api ./helm-charts/student-api-helm -n $NAMESPACE

# Wait for new pod with increased timeout
echo "Waiting for student-api pod to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=student-api -n $NAMESPACE --timeout=120s

# Get pod name
POD_NAME=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=student-api -o name | head -1)

if [ -n "$POD_NAME" ]; then
    echo "Pod $POD_NAME is ready"
    
    # Wait for nginx to be ready
    echo "Waiting for nginx to start..."
    sleep 5
    
    # Test nginx configuration
    echo "Testing nginx configuration..."
    kubectl exec -n $NAMESPACE $POD_NAME -- nginx -t
    
    # Test endpoints using wget instead of curl
    echo "Testing endpoints..."
    for endpoint in "/" "/health" "/metrics"; do
        echo "Testing $endpoint..."
        kubectl exec -n $NAMESPACE $POD_NAME -- wget -q -O- --timeout=10 http://localhost:8080$endpoint || echo "Failed to access $endpoint"
    done
    
    # Show pod logs
    echo "Pod logs:"
    kubectl logs -n $NAMESPACE $POD_NAME
else
    echo "No student-api pod found!"
    kubectl get pods -n $NAMESPACE
fi

echo "=== Verification Complete ==="
