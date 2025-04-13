#!/bin/bash

echo "=== Cleaning ALL PVCs with postgres in name ==="

NAMESPACES=$(kubectl get ns -o jsonpath='{.items[*].metadata.name}')

for NS in $NAMESPACES; do
  echo "Checking namespace: $NS"
  
  # Get all PVCs with postgres in name
  PVCS=$(kubectl get pvc -n $NS 2>/dev/null | grep -i postgres | awk '{print $1}' || echo "")
  
  if [ -z "$PVCS" ]; then
    echo "  No postgres PVCs found in $NS"
    continue
  fi
  
  echo "  Found PVCs in $NS: $PVCS"
  
  for PVC in $PVCS; do
    echo "  Force deleting PVC: $PVC in namespace $NS"
    # Remove finalizers
    kubectl patch pvc $PVC -n $NS -p '{"metadata":{"finalizers":null}}' || echo "    Failed to patch finalizers"
    # Force delete
    kubectl delete pvc $PVC -n $NS --force --grace-period=0 || echo "    Failed to force delete"
  done
done

echo "=== Cleanup Complete ==="
