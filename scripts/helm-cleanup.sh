#!/bin/bash
# Script to clean up resources before Helm deployment

NAMESPACE=${1:-student-api}
RELEASE_NAME=${2:-student-api}

echo "Cleaning up resources in namespace: $NAMESPACE"

# Delete the problematic ConfigMap
echo "Deleting nginx-config ConfigMap..."
kubectl delete configmap nginx-config -n $NAMESPACE --ignore-not-found=true

# Delete any other potentially conflicting resources
echo "Checking for other potential conflicts..."
SERVICES=$(kubectl get svc -n $NAMESPACE -o name)
DEPLOYMENTS=$(kubectl get deploy -n $NAMESPACE -o name)
CONFIGMAPS=$(kubectl get cm -n $NAMESPACE -o name)

if [[ -n "$SERVICES" || -n "$DEPLOYMENTS" || -n "$CONFIGMAPS" ]]; then
  echo "Existing resources found in namespace:"
  echo "Services:"
  kubectl get svc -n $NAMESPACE
  echo "Deployments:"
  kubectl get deploy -n $NAMESPACE
  echo "ConfigMaps:"
  kubectl get cm -n $NAMESPACE
  
  echo ""
  echo "⚠️ You may need to delete these resources if they conflict with your Helm release."
  echo "To delete all resources from namespace:"
  echo "kubectl delete all --all -n $NAMESPACE"
  echo ""
  
  read -p "Do you want to delete all resources in the namespace? (y/n): " CONFIRM
  if [[ "$CONFIRM" == "y" ]]; then
    echo "Deleting all resources in namespace $NAMESPACE..."
    kubectl delete all --all -n $NAMESPACE
    kubectl delete cm --all -n $NAMESPACE
    echo "Waiting for resources to be deleted..."
    sleep 5
  fi
fi

echo "Ready to deploy with Helm!"
echo "Run: helm upgrade --install $RELEASE_NAME ./helm-charts/student-api-helm -n $NAMESPACE"
