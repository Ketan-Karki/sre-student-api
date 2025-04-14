#!/bin/bash

NAMESPACE="student-api"

echo "=== Verifying Student API Configuration ==="

# Delete the student-api pods
echo "Deleting student-api pods..."
kubectl delete pod -n $NAMESPACE -l app=student-api --force --grace-period=0

# Wait for new pod
echo "Waiting for new student-api pod..."
kubectl wait --for=condition=ready pod -l app=student-api -n $NAMESPACE --timeout=60s

# Get the pod name
POD_NAME=$(kubectl get pod -n $NAMESPACE -l app=student-api -o name | head -1)

if [ -n "$POD_NAME" ]; then
    echo "Testing configuration in $POD_NAME..."
    
    # Check nginx configuration
    echo "Checking nginx configuration..."
    kubectl exec -n $NAMESPACE $POD_NAME -- nginx -t
    
    # Test endpoints
    for endpoint in "/" "/health" "/metrics"; do
        echo "Testing $endpoint endpoint..."
        kubectl exec -n $NAMESPACE $POD_NAME -- curl -s -o /dev/null -w "%{http_code}" localhost:8080$endpoint
        echo ""
    done
    
    # Check mounted files
    echo "Checking mounted files..."
    kubectl exec -n $NAMESPACE $POD_NAME -- ls -l /etc/nginx/
    kubectl exec -n $NAMESPACE $POD_NAME -- ls -l /etc/nginx/html/
else
    echo "No student-api pod found!"
fi

echo "=== Verification Complete ==="
