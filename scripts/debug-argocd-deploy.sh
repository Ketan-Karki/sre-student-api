#!/bin/bash
# Script to debug ArgoCD deployment issues

set -e

# Default values
NAMESPACE="argocd"
NODE_SELECTOR="dependent_services"
NODE_SELECTOR_KEY="role"

echo "=== ArgoCD Deployment Troubleshooter ==="

# Check if nodes with the label exist
echo "Checking if nodes with label '$NODE_SELECTOR_KEY=$NODE_SELECTOR' exist..."
if kubectl get nodes -l "$NODE_SELECTOR_KEY=$NODE_SELECTOR" -o name &>/dev/null; then
  echo "✅ Found nodes with label $NODE_SELECTOR_KEY=$NODE_SELECTOR"
  kubectl get nodes -l "$NODE_SELECTOR_KEY=$NODE_SELECTOR" -o wide
else
  echo "❌ No nodes with label '$NODE_SELECTOR_KEY=$NODE_SELECTOR' found."
  echo "Available nodes:"
  kubectl get nodes -o wide
  
  echo -e "\nAttempting to fix by applying label to minikube node..."
  kubectl label nodes minikube "$NODE_SELECTOR_KEY=$NODE_SELECTOR" --overwrite
  
  if kubectl get nodes -l "$NODE_SELECTOR_KEY=$NODE_SELECTOR" -o name &>/dev/null; then
    echo "✅ Successfully labeled minikube node with $NODE_SELECTOR_KEY=$NODE_SELECTOR"
  else
    echo "❌ Failed to label node. Please run: kubectl label nodes minikube $NODE_SELECTOR_KEY=$NODE_SELECTOR"
    exit 1
  fi
fi

# Check node capacity and conditions
echo -e "\n=== Node Capacity and Conditions ==="
kubectl describe node $NODE_SELECTOR | grep -A 10 "Capacity\|Conditions"

# Check for taints on the node
echo -e "\n=== Checking for taints on node ==="
kubectl describe node $NODE_SELECTOR | grep -A 5 "Taints"

# Check if ArgoCD pods are trying to schedule
echo -e "\n=== ArgoCD Pod Status ==="
kubectl get pods -n $NAMESPACE -o wide

# Check for pod scheduling issues
echo -e "\n=== Pod Scheduling Issues ==="
kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | grep -i "argocd\|fail\|error" | tail -15

# Check detailed pod status for argocd-server
echo -e "\n=== Detailed Status for argocd-server ==="
FAILED_POD=$(kubectl get pod -n $NAMESPACE -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].metadata.name}')
if [ ! -z "$FAILED_POD" ]; then
  kubectl describe pod $FAILED_POD -n $NAMESPACE
else
  echo "No argocd-server pod found"
fi

# Check detailed status for argocd-application-controller statefulset
echo -e "\n=== Detailed Status for argocd-application-controller (StatefulSet) ==="
kubectl get statefulset argocd-application-controller -n $NAMESPACE -o wide
echo -e "\nPod status:"
kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=argocd-application-controller
echo -e "\nEvents related to statefulset:"
kubectl get events -n $NAMESPACE --field-selector involvedObject.kind=StatefulSet,involvedObject.name=argocd-application-controller --sort-by='.lastTimestamp'

# Add a specific fix option for the statefulset
echo -e "\n=== StatefulSet Fix Options ==="
echo "To force continue without waiting for statefulset:"
echo "cd argocd && NODE_SELECTOR=\"dependent_services\" NODE_SELECTOR_KEY=\"role\" NAMESPACE=\"argocd\" SKIP_WAIT_STATEFULSET=true ./configure-argocd.sh"

# Emergency fix option - remove node selector
echo -e "\n=== Emergency Fix Options ==="
echo "If you want to remove the node selector constraint and allow ArgoCD to run on any node, run:"
echo "kubectl patch deployment argocd-server -n $NAMESPACE --type=json -p='[{\"op\":\"remove\",\"path\":\"/spec/template/spec/nodeSelector\"}]'"
echo "kubectl patch deployment argocd-repo-server -n $NAMESPACE --type=json -p='[{\"op\":\"remove\",\"path\":\"/spec/template/spec/nodeSelector\"}]'"
echo "kubectl patch deployment argocd-applicationset-controller -n $NAMESPACE --type=json -p='[{\"op\":\"remove\",\"path\":\"/spec/template/spec/nodeSelector\"}]'"
echo "kubectl patch deployment argocd-notifications-controller -n $NAMESPACE --type=json -p='[{\"op\":\"remove\",\"path\":\"/spec/template/spec/nodeSelector\"}]'"
echo "kubectl patch statefulset argocd-application-controller -n $NAMESPACE --type=json -p='[{\"op\":\"remove\",\"path\":\"/spec/template/spec/nodeSelector\"}]'"

echo -e "\n=== Suggestion ==="
echo "If 'dependent_services' is not the name of a node but a label, modify the nodeSelector in the script:"
echo "Change 'kubernetes.io/hostname: \$NODE_SELECTOR' to a proper label like 'role: \$NODE_SELECTOR'"
