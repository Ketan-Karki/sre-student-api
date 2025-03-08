#!/bin/bash
# Script to set up node labels for ArgoCD deployment

set -e

echo "Setting up node labels for deployment..."

# Check if minikube is running
if ! kubectl get nodes minikube &>/dev/null; then
  echo "❌ Minikube node not found. Is minikube running?"
  exit 1
fi

# Add the dependent_services role label to the minikube node
echo "Adding 'role=dependent_services' label to minikube node..."
kubectl label nodes minikube role=dependent_services --overwrite

echo "Verifying labels on minikube node..."
kubectl get nodes minikube --show-labels

echo "✅ Node labels configured successfully"
