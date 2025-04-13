#!/bin/bash

echo "=== FORCEFUL CLEANUP OF KUBERNETES RESOURCES ==="

# Function to force delete a resource
force_delete() {
  local resource_type=$1
  local name=$2
  local namespace=$3
  
  echo "Force deleting $resource_type: $name in namespace: $namespace"
  
  # Remove finalizers
  kubectl patch $resource_type $name ${namespace:+-n $namespace} --type='json' -p='[{"op": "remove", "path": "/metadata/finalizers"}]' 2>/dev/null || true
  
  # Force delete
  kubectl delete $resource_type $name ${namespace:+-n $namespace} --force --grace-period=0 2>/dev/null || true
  
  echo "Done with $resource_type: $name"
}

echo "1. Finding and cleaning all postgres PVCs in ALL namespaces..."
for ns in $(kubectl get ns -o name | cut -d/ -f2); do
  echo "Checking namespace: $ns"
  for pvc in $(kubectl get pvc -n $ns -o name 2>/dev/null | grep -i postgres | cut -d/ -f2 || echo ""); do
    force_delete pvc $pvc $ns
  done
done

echo "2. Finding and cleaning all lingering PVs..."
for pv in $(kubectl get pv -o name | cut -d/ -f2); do
  echo "Checking PV: $pv"
  claim=$(kubectl get pv $pv -o jsonpath='{.spec.claimRef.name}' 2>/dev/null || echo "")
  if [[ -n "$claim" && "$claim" == *"postgres"* ]]; then
    echo "Found postgres-related PV: $pv with claim: $claim"
    force_delete pv $pv ""
  fi
done

echo "3. Cleaning up additional named PVCs..."
for ns in $(kubectl get ns -o name | cut -d/ -f2); do
  for pattern in "data-storage" "student-api-postgres" "postgres-data"; do
    for pvc in $(kubectl get pvc -n $ns -o name 2>/dev/null | grep -i $pattern | cut -d/ -f2 || echo ""); do
      force_delete pvc $pvc $ns
    done
  done
done

echo "4. Killing any kube API operations that might be hanging..."
pids=$(ps aux | grep -i "\-\-grace\-period" | grep -v grep | awk '{print $2}')
if [[ -n "$pids" ]]; then
  echo "Killing hanging kubectl processes: $pids"
  kill -9 $pids || true
fi

echo "5. Final check for terminating resources..."
kubectl get pvc --all-namespaces | grep Terminating || echo "No terminating PVCs found"
kubectl get pv | grep Terminating || echo "No terminating PVs found"

echo "=== CLEANUP COMPLETE ==="
