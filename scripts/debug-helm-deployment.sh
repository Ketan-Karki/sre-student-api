#!/bin/bash
# Script to debug Helm deployment issues

NAMESPACE=${1:-dev-student-api}

echo "===== Debugging Helm Deployment in Namespace: $NAMESPACE ====="

echo "1. Checking pods:"
kubectl get pods -n $NAMESPACE

echo -e "\n2. Checking pod details:"
POD_NAME=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=student-api -o name | head -1)
if [ -n "$POD_NAME" ]; then
  kubectl describe $POD_NAME -n $NAMESPACE
else
  echo "No pod found with label app.kubernetes.io/name=student-api"
  
  echo -e "\nListing all pods:"
  kubectl get pods -n $NAMESPACE -o wide
fi

echo -e "\n3. Checking deployment:"
kubectl get deployment -n $NAMESPACE

echo -e "\n4. Checking deployment details:"
kubectl describe deployment student-api -n $NAMESPACE 2>/dev/null || echo "Deployment student-api not found"

echo -e "\n5. Checking services:"
kubectl get svc -n $NAMESPACE

echo -e "\n6. Checking configmaps:"
kubectl get configmaps -n $NAMESPACE

echo -e "\n7. Checking secrets:"
kubectl get secrets -n $NAMESPACE

echo -e "\n8. Checking events:"
kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp'

echo -e "\n9. Checking pod logs (if available):"
if [ -n "$POD_NAME" ]; then
  kubectl logs $POD_NAME -n $NAMESPACE --tail=50
else
  echo "No pod available to get logs"
fi

echo -e "\n===== Debugging Complete ====="
