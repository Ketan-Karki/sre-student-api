#!/bin/bash
# Quick script to check Blackbox exporter deployment status

set -e

NAMESPACE=${1:-"student-api"}

echo "=== Checking Blackbox Exporter Status ==="
echo "Namespace: $NAMESPACE"

# Check if the deployment exists
echo "Checking for Blackbox exporter deployment..."
if kubectl get deployment -n $NAMESPACE | grep -q blackbox-exporter; then
  echo "✅ Deployment exists"
  kubectl get deployment -n $NAMESPACE | grep blackbox-exporter
else
  echo "❌ Deployment not found!"
  echo "All deployments in namespace:"
  kubectl get deployment -n $NAMESPACE
fi

# Check if the service exists
echo -e "\nChecking for Blackbox exporter service..."
if kubectl get service -n $NAMESPACE | grep -q blackbox-exporter; then
  echo "✅ Service exists"
  kubectl get service -n $NAMESPACE | grep blackbox-exporter
else
  echo "❌ Service not found!"
  echo "All services in namespace:"
  kubectl get service -n $NAMESPACE
fi

# Check for pods
echo -e "\nChecking for Blackbox exporter pods..."
if kubectl get pods -n $NAMESPACE -l app=blackbox-exporter 2>/dev/null | grep -q blackbox-exporter; then
  echo "✅ Pods exist"
  kubectl get pods -n $NAMESPACE -l app=blackbox-exporter
else
  echo "❌ Pods not found with label app=blackbox-exporter!"
  echo "Alternative: Checking for pods with name containing blackbox-exporter..."
  kubectl get pods -n $NAMESPACE | grep blackbox-exporter || echo "No pods containing blackbox-exporter found!"
fi

# Print all resources to help with troubleshooting
echo -e "\n=== All resources in namespace $NAMESPACE ==="
kubectl get all -n $NAMESPACE

echo -e "\n=== Troubleshooting Next Steps ==="
echo "1. Make sure your Helm release includes the blackbox-exporter section"
echo "2. Verify that you have templates for Blackbox exporter (deployment.yaml, service.yaml)"
echo "3. Try running: helm template . | grep -A 20 blackbox-exporter"
echo "4. Check Helm logs: helm install --debug --dry-run <release-name> ."
echo "5. To port-forward using pod instead of service:"
echo "   kubectl port-forward -n $NAMESPACE \$(kubectl get pods -n $NAMESPACE -l app=blackbox-exporter -o name | head -1) 9115:9115"
