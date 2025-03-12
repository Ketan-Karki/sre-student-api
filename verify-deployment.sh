#!/bin/bash

set -e

echo "=== Verifying Student API Deployment ==="

NAMESPACE="student-api"
ARGOCD_NS="argocd"
APP_NAME="student-api"

# 1. Check if namespace exists
echo -e "\nStep 1: Checking if namespace exists"
if kubectl get namespace $NAMESPACE &>/dev/null; then
  echo "✅ Namespace $NAMESPACE exists"
else
  echo "❌ Namespace $NAMESPACE does not exist"
  echo "Creating namespace..."
  kubectl create namespace $NAMESPACE
fi

# 2. Check ArgoCD application status
echo -e "\nStep 2: Checking ArgoCD application status"
echo "ArgoCD application status:"
kubectl get application $APP_NAME -n $ARGOCD_NS

# 3. Check resources in namespace
echo -e "\nStep 3: Checking resources in namespace"
echo "Deployments:"
kubectl get deployments -n $NAMESPACE

echo -e "\nPods:"
kubectl get pods -n $NAMESPACE

echo -e "\nServices:"
kubectl get services -n $NAMESPACE

echo -e "\nConfigMaps:"
kubectl get configmaps -n $NAMESPACE

echo -e "\nPersistent Volume Claims:"
kubectl get pvc -n $NAMESPACE

# 4. Check for common issues
echo -e "\nStep 4: Checking for common issues"

# Check for ImagePullBackOff
IMAGEPULL_ISSUES=$(kubectl get pods -n $NAMESPACE | grep -E "ImagePull|ErrImage" | wc -l)
if [ "$IMAGEPULL_ISSUES" -gt 0 ]; then
  echo "❌ Found pods with image pull issues:"
  kubectl get pods -n $NAMESPACE | grep -E "ImagePull|ErrImage"
  echo -e "\nPod details:"
  POD_NAME=$(kubectl get pods -n $NAMESPACE | grep -E "ImagePull|ErrImage" | head -1 | awk '{print $1}')
  kubectl describe pod $POD_NAME -n $NAMESPACE | grep -A10 "Events:"
else
  echo "✅ No image pull issues detected"
fi

# Check for CrashLoopBackOff
CRASH_ISSUES=$(kubectl get pods -n $NAMESPACE | grep "CrashLoop" | wc -l)
if [ "$CRASH_ISSUES" -gt 0 ]; then
  echo "❌ Found pods with crash issues:"
  kubectl get pods -n $NAMESPACE | grep "CrashLoop"
  echo -e "\nPod logs:"
  POD_NAME=$(kubectl get pods -n $NAMESPACE | grep "CrashLoop" | head -1 | awk '{print $1}')
  kubectl logs $POD_NAME -n $NAMESPACE --tail=20
else
  echo "✅ No crash issues detected"
fi

# 5. Check service endpoints
echo -e "\nStep 5: Checking service endpoints"
echo "Service endpoints:"
kubectl get endpoints -n $NAMESPACE

# 6. Check Helm values being used
echo -e "\nStep 6: Checking Helm values used by ArgoCD"
echo "ArgoCD application parameters:"
kubectl get application $APP_NAME -n $ARGOCD_NS -o jsonpath='{.spec.source.helm.parameters}'

# 7. Check application logs if deployed
echo -e "\nStep 7: Checking application logs"
API_POD=$(kubectl get pods -n $NAMESPACE -l app=student-api -o name 2>/dev/null || echo "")
if [ -n "$API_POD" ]; then
  echo "Student API logs:"
  kubectl logs $API_POD -n $NAMESPACE --tail=20
else
  echo "No student-api pods found yet"
fi

# 8. Provide recommendations
echo -e "\n=== Deployment Verification Summary ==="
TOTAL_PODS=$(kubectl get pods -n $NAMESPACE 2>/dev/null | wc -l)
RUNNING_PODS=$(kubectl get pods -n $NAMESPACE 2>/dev/null | grep "Running" | wc -l)

if [ "$RUNNING_PODS" -eq 0 ]; then
  echo "❌ No pods are running. Deployment has issues."
  echo -e "\nRecommended actions:"
  echo "1. Check Helm chart templates for errors"
  echo "2. Verify image names and tags are correct"
  echo "3. Try syncing with REPLACE and FORCE options in ArgoCD UI"
  echo "4. Check storage class availability if PVCs are failing"
elif [ "$RUNNING_PODS" -lt "$TOTAL_PODS" ]; then
  echo "⚠️ Some pods are running, but not all."
  echo -e "\nRecommended actions:"
  echo "1. Check logs of failing pods"
  echo "2. Verify configuration in ConfigMaps"
  echo "3. Check for resource constraints"
else
  echo "✅ All pods are running. Deployment appears successful."
  echo -e "\nAccess your application:"
  INGRESS=$(kubectl get ingress -n $NAMESPACE 2>/dev/null)
  if [ -n "$INGRESS" ]; then
    echo "Via Ingress: $(kubectl get ingress -n $NAMESPACE -o jsonpath='{.items[0].spec.rules[0].host}')"
  else
    SERVICE_PORT=$(kubectl get svc nginx-service -n $NAMESPACE -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || echo "8080")
    echo "Port-forward: kubectl port-forward svc/nginx-service -n $NAMESPACE $SERVICE_PORT:$SERVICE_PORT"
    echo "Then access: http://localhost:$SERVICE_PORT"
  fi
fi

echo -e "\nDo you want to open the ArgoCD UI now? (y/n)"
read -p "> " OPEN_UI
if [[ "$OPEN_UI" == "y" ]]; then
  PASSWORD=$(kubectl -n $ARGOCD_NS get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
  echo "Username: admin"
  echo "Password: $PASSWORD"
  
  echo "Starting port-forward to ArgoCD UI..."
  echo "Press Ctrl+C when done"
  kubectl port-forward svc/argocd-server -n $ARGOCD_NS 8080:443
fi
