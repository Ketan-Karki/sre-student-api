#!/bin/bash
# Script to fix ArgoCD application controller resource constraints

set -e

NAMESPACE="argocd"

echo "===== ArgoCD StatefulSet Resource Optimizer ====="

# Check if application controller exists
if ! kubectl get statefulset argocd-application-controller -n $NAMESPACE &>/dev/null; then
  echo "❌ argocd-application-controller statefulset not found in namespace $NAMESPACE"
  exit 1
fi

echo "Checking current statefulset resource settings..."
kubectl get statefulset argocd-application-controller -n $NAMESPACE -o yaml | grep -A 10 resources || echo "No resource limits found"

echo -e "\n1. Reducing resource requests to minimum viable settings..."
kubectl patch statefulset argocd-application-controller -n $NAMESPACE --type=json \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/resources","value":{"requests":{"cpu":"100m","memory":"128Mi"},"limits":{"cpu":"300m","memory":"256Mi"}}}]'

echo -e "\n2. Adding priority class to make scheduling more likely..."
kubectl patch statefulset argocd-application-controller -n $NAMESPACE --type=strategic \
  -p='{"spec":{"template":{"spec":{"priorityClassName":"system-cluster-critical"}}}}'

echo -e "\n3. Removing affinity constraints temporarily..."
kubectl patch statefulset argocd-application-controller -n $NAMESPACE --type=json \
  -p='[{"op":"remove","path":"/spec/template/spec/nodeSelector"}]'

echo -e "\n4. Scaling statefulset to 0 and back to 1 for reset..."
kubectl scale statefulset argocd-application-controller --replicas=0 -n $NAMESPACE
sleep 3
kubectl scale statefulset argocd-application-controller --replicas=1 -n $NAMESPACE

echo -e "\n5. Checking pod status after adjustment..."
sleep 5
kubectl get pods -n $NAMESPACE | grep argocd-application-controller

echo -e "\nNote: You can restore the node selector with:"
echo "kubectl patch statefulset argocd-application-controller -n $NAMESPACE --type=json \\"
echo "  -p='[{\"op\": \"add\", \"path\": \"/spec/template/spec/nodeSelector\", \"value\": {\"role\": \"dependent_services\"}}]'"

echo -e "\n===== Resource Adjustment Complete ====="
echo "Monitor the pod with: kubectl get pods -n $NAMESPACE -w | grep application-controller"
