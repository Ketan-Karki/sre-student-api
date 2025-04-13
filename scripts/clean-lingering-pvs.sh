#!/bin/bash

set -e

echo "=== Cleaning up lingering PVs ==="

# Find PVs in Released state
RELEASED_PVS=$(kubectl get pv -o=jsonpath='{range .items[?(@.status.phase=="Released")]}{.metadata.name}{"\n"}{end}')

if [ -z "$RELEASED_PVS" ]; then
  echo "No Released PVs found."
  exit 0
fi

echo "Found the following Released PVs:"
echo "$RELEASED_PVS"

echo -n "Do you want to delete these PVs? (y/n): "
read CONFIRM

if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  echo "Aborted."
  exit 0
fi

# Patch and delete the PVs
for PV in $RELEASED_PVS; do
  echo "Cleaning up PV: $PV"
  
  # Remove finalizers
  echo "Removing finalizers..."
  kubectl patch pv $PV -p '{"metadata":{"finalizers":null}}'
  
  # Delete the PV
  echo "Deleting PV..."
  kubectl delete pv $PV --wait=false
done

echo "PV cleanup initiated. This may take some time to complete."
