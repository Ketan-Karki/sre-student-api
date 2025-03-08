#!/bin/bash
# Script to completely clean the Helm namespace

NAMESPACE=${1:-dev-student-api}

echo "Cleaning up namespace $NAMESPACE..."

# Check if namespace exists
if kubectl get namespace $NAMESPACE >/dev/null 2>&1; then
  echo "Namespace $NAMESPACE exists. Deleting it..."
  kubectl delete namespace $NAMESPACE
  
  # Wait for namespace to be fully deleted
  echo "Waiting for namespace to be deleted..."
  while kubectl get namespace $NAMESPACE >/dev/null 2>&1; do
    echo "Namespace still exists, waiting..."
    sleep 2
  done
  
  echo "Namespace deleted successfully."
fi

# Recreate namespace with proper Helm annotations
echo "Creating new namespace $NAMESPACE..."
kubectl create namespace $NAMESPACE
kubectl label namespace $NAMESPACE app.kubernetes.io/managed-by=Helm
kubectl annotate namespace $NAMESPACE meta.helm.sh/release-name=student-api
kubectl annotate namespace $NAMESPACE meta.helm.sh/release-namespace=$NAMESPACE

echo "Namespace $NAMESPACE is ready for Helm deployments."
