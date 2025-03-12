#!/bin/bash

set -e

echo "=== Checking Final Deployment Status ==="
NAMESPACE="student-api"

echo "Pod status:"
kubectl get pods -n $NAMESPACE

echo -e "\nDeployments:"
kubectl get deployments -n $NAMESPACE

echo -e "\nServices:"
kubectl get services -n $NAMESPACE

echo -e "\nIngress (if any):"
kubectl get ingress -n $NAMESPACE 2>/dev/null || echo "No ingress resources found"

echo -e "\nPersistentVolumeClaims:"
kubectl get pvc -n $NAMESPACE

echo -e "\n=== Access Instructions ==="
echo "To access your application:"

# Check if nginx service exists
if kubectl get service nginx-service -n $NAMESPACE &>/dev/null; then
  SERVICE_PORT=$(kubectl get svc nginx-service -n $NAMESPACE -o jsonpath='{.spec.ports[0].port}')
  TARGET_PORT=$(kubectl get svc nginx-service -n $NAMESPACE -o jsonpath='{.spec.ports[0].targetPort}')
  
  echo "1. Port-forward the nginx service:"
  echo "   kubectl port-forward svc/nginx-service -n $NAMESPACE $SERVICE_PORT:$SERVICE_PORT"
  echo "2. Access in browser: http://localhost:$SERVICE_PORT"
fi

# Check if student-api service exists
if kubectl get service student-api -n $NAMESPACE &>/dev/null; then
  API_PORT=$(kubectl get svc student-api -n $NAMESPACE -o jsonpath='{.spec.ports[0].port}')
  
  echo -e "\nTo access the API directly:"
  echo "1. Port-forward the student-api service:"
  echo "   kubectl port-forward svc/student-api -n $NAMESPACE $API_PORT:$API_PORT"
  echo "2. Access API: http://localhost:$API_PORT"
fi

echo -e "\n=== Testing API functionality ==="
echo "To test if the API is working properly:"
echo "1. Port-forward the service as shown above"
echo "2. Use curl or a browser to access the endpoints:"
echo "   curl http://localhost:8080/api/students    # List students"
echo "   curl http://localhost:8080/api/health      # Health check"

echo -e "\n=== ArgoCD Status ==="
echo "To check ArgoCD status and logs:"
echo "1. Open ArgoCD UI:"
echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "   Then visit: https://localhost:8080"
echo "   Username: admin"
PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "Check ArgoCD docs")
echo "   Password: $PASSWORD"
