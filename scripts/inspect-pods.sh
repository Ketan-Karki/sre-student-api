#!/bin/bash
# Script to inspect pod details in the student-api namespace

NAMESPACE="student-api"

echo "=== Inspecting Pods in $NAMESPACE namespace ==="

# List all pods
echo -e "\n--- All Pods ---"
kubectl get pods -n $NAMESPACE

# Find student-api pods
echo -e "\n--- Student API Pods ---"
STUDENT_API_PODS=$(kubectl get pods -n $NAMESPACE -l app=student-api -o name)
if [ -n "$STUDENT_API_PODS" ]; then
    echo "Found pods: $STUDENT_API_PODS"
    for POD in $STUDENT_API_PODS; do
        echo -e "\nDetails for $POD:"
        kubectl describe pod -n $NAMESPACE ${POD#pod/}
        echo -e "\nLogs for $POD:"
        kubectl logs -n $NAMESPACE ${POD#pod/} --tail=20
    done
else
    echo "No student-api pods found. Looking for pods with matching labels:"
    kubectl get pods -n $NAMESPACE --show-labels
fi

# Find nginx pods
echo -e "\n--- NGINX Pods ---"
NGINX_PODS=$(kubectl get pods -n $NAMESPACE -l app=nginx -o name)
if [ -n "$NGINX_PODS" ]; then
    echo "Found pods: $NGINX_PODS"
    for POD in $NGINX_PODS; do
        echo -e "\nDetails for $POD:"
        kubectl describe pod -n $NAMESPACE ${POD#pod/}
        echo -e "\nLogs for $POD:"
        kubectl logs -n $NAMESPACE ${POD#pod/} --tail=20
    done
else
    echo "No nginx pods found. Looking for pods with matching labels:"
    kubectl get pods -n $NAMESPACE --show-labels
fi

# Check connectivity from within the cluster using a test pod
echo -e "\n--- Testing connectivity with debug pod ---"
kubectl run -n $NAMESPACE debug-pod --image=nicolaka/netshoot --restart=Never --rm -it -- \
  bash -c '
    echo "Testing TCP to postgres-service:5432"
    nc -zv postgres-service 5432 || echo "Failed to connect to postgres-service:5432"
    
    echo "Testing TCP to student-api:8080"
    nc -zv student-api 8080 || echo "Failed to connect to student-api:8080"
    
    echo "Testing TCP to nginx-service:80"
    nc -zv nginx-service 80 || echo "Failed to connect to nginx-service:80"
    
    echo "Testing HTTP to student-api"
    curl -v --connect-timeout 5 http://student-api:8080/ || echo "Failed HTTP request to student-api:8080"
    
    echo "Testing HTTP to nginx-service"
    curl -v --connect-timeout 5 http://nginx-service/ || echo "Failed HTTP request to nginx-service:80"
  ' || echo "Debug pod execution failed"

echo -e "\n=== Inspection Complete ==="
