#!/bin/bash

NAMESPACE="student-api"

echo "=== PVC Emergency Fix ==="

echo "1. Checking for any postgres PVCs in the namespace..."
kubectl get pvc -n $NAMESPACE | grep postgres || echo "No postgres PVCs found"

echo "2. Force deleting any problematic PVCs..."
for pvc in postgres-pvc postgres-storage student-api-postgres-data student-api-data-storage; do
  echo "Removing PVC: $pvc"
  kubectl patch pvc $pvc -n $NAMESPACE --type json -p='[{"op": "remove", "path": "/metadata/finalizers"}]' 2>/dev/null || true
  kubectl delete pvc $pvc -n $NAMESPACE --force --grace-period=0 2>/dev/null || true
done

echo "3. Checking for any PVs potentially keeping the PVCs alive..."
PVS=$(kubectl get pv | grep -E "postgres|student-api" | awk '{print $1}')
if [ -n "$PVS" ]; then
  echo "Found problematic PVs: $PVS"
  for pv in $PVS; do
    echo "Removing PV: $pv"
    kubectl patch pv $pv --type json -p='[{"op": "remove", "path": "/metadata/finalizers"}]' 2>/dev/null || true
    kubectl delete pv $pv --force --grace-period=0 2>/dev/null || true
  done
else
  echo "No problematic PVs found"
fi

echo "=== Fix complete ==="
echo "Now run ./scripts/clean-install.sh"
