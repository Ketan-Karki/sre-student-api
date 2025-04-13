#!/bin/bash

echo "=== NUCLEAR OPTION - REMOVING EVERYTHING ==="

# Kill any hanging kubectl processes
echo "Killing any kubectl processes..."
pkill -f kubectl || true

echo "1. Removing all helm releases in all namespaces..."
for ns in $(kubectl get ns -o name 2>/dev/null | cut -d/ -f2); do
  echo "Checking namespace: $ns"
  for release in $(helm list -n "$ns" -q 2>/dev/null); do
    echo "  Deleting release: $release in $ns"
    helm delete "$release" -n "$ns" --no-hooks 2>/dev/null || true
  done
done

NAMESPACE="student-api"
echo "2. Removing all PVCs in $NAMESPACE namespace..."
for pvc in $(kubectl get pvc -n "$NAMESPACE" -o name 2>/dev/null | cut -d/ -f2); do
  echo "  Removing PVC: $pvc"
  kubectl patch pvc "$pvc" -n "$NAMESPACE" --type json -p='[{"op": "remove", "path": "/metadata/finalizers"}]' 2>/dev/null || true
  kubectl delete pvc "$pvc" -n "$NAMESPACE" --force --grace-period=0 2>/dev/null || true
done

echo "3. Forcibly removing all PVs with postgres in name..."
for pv in $(kubectl get pv 2>/dev/null | grep -E "postgres|student-api" | awk '{print $1}'); do
  echo "  Removing PV: $pv"
  kubectl patch pv "$pv" --type json -p='[{"op": "remove", "path": "/metadata/finalizers"}]' 2>/dev/null || true
  kubectl delete pv "$pv" --force --grace-period=0 2>/dev/null || true
done

echo "4. Force deleting namespace..."
kubectl delete namespace "$NAMESPACE" --force --grace-period=0 2>/dev/null || true

echo "5. Waiting for namespace to be completely gone..."
end=$((SECONDS+30))
while [ $SECONDS -lt $end ]; do
  if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    echo "  Namespace gone!"
    break
  fi
  echo "  Still waiting for namespace deletion..."
  sleep 2
done

echo "6. Creating fresh namespace..."
kubectl create namespace "$NAMESPACE" || true
kubectl label namespace "$NAMESPACE" app.kubernetes.io/managed-by=Helm

# Use a completely unique timestamp for release
TIMESTAMP=$(date +%s)
RELEASE_NAME="api-$TIMESTAMP"

echo "=== NUCLEAR CLEANUP COMPLETE ==="
echo ""
echo "Now run: helm install $RELEASE_NAME ./helm-charts/student-api-helm -n $NAMESPACE --set postgres.persistence.forceEmptyDir=true"
echo ""
