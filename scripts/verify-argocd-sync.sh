#!/bin/bash

set -e

NAMESPACE="argocd"
APP_NAME="student-api"
APP_NAMESPACE="student-api"
echo "=== Final ArgoCD Sync Verification ==="

# Check ArgoCD application status
echo "Step 1: Checking ArgoCD application status..."
SYNC_STATUS=$(kubectl get application $APP_NAME -n $NAMESPACE -o jsonpath='{.status.sync.status}')
HEALTH_STATUS=$(kubectl get application $APP_NAME -n $NAMESPACE -o jsonpath='{.status.health.status}')

echo "Current status:"
echo "  Sync status: $SYNC_STATUS"
echo "  Health status: $HEALTH_STATUS"

# Check for any errors
echo -e "\nStep 2: Checking for sync errors..."
SYNC_ERRORS=$(kubectl get application $APP_NAME -n $NAMESPACE -o jsonpath='{.status.conditions[?(@.type=="SyncError")].message}')
if [ -z "$SYNC_ERRORS" ]; then
  echo "✅ No sync errors detected"
else
  echo "❌ Sync errors found:"
  echo "$SYNC_ERRORS"
fi

# Verify all PostgreSQL pods are running
echo -e "\nStep 3: Verifying PostgreSQL deployment..."
POSTGRES_PODS=$(kubectl get pods -n $APP_NAMESPACE -l app=postgres -o name)
if [ -z "$POSTGRES_PODS" ]; then
  echo "❌ No PostgreSQL pods found"
else
  echo "PostgreSQL pods:"
  kubectl get pods -n $APP_NAMESPACE -l app=postgres
  
  READY_COUNT=$(kubectl get pods -n $APP_NAMESPACE -l app=postgres -o jsonpath='{.items[0].status.containerStatuses[0].ready}')
  if [ "$READY_COUNT" = "true" ]; then
    echo "✅ PostgreSQL pod is ready"
  else
    echo "❌ PostgreSQL pod is not ready"
  fi
fi

# Verify PVC status
echo -e "\nStep 4: Verifying PVCs..."
PVC_NAME="postgres-data-1742397241"
if kubectl get pvc $PVC_NAME -n $APP_NAMESPACE &>/dev/null; then
  PVC_STATUS=$(kubectl get pvc $PVC_NAME -n $APP_NAMESPACE -o jsonpath='{.status.phase}')
  echo "PVC $PVC_NAME status: $PVC_STATUS"
  
  if [ "$PVC_STATUS" = "Bound" ]; then
    echo "✅ PVC is correctly bound"
    
    # Show PVC details
    echo "PVC details:"
    kubectl get pvc $PVC_NAME -n $APP_NAMESPACE -o wide
  else
    echo "❌ PVC is not bound"
  fi
else
  echo "❌ PVC $PVC_NAME not found"
fi

# Check for lingering old PVCs
OLD_PVC=$(kubectl get pvc -n $APP_NAMESPACE | grep "postgres-pvc" || echo "")
if [ -n "$OLD_PVC" ]; then
  echo -e "\nOld PVC still found:"
  echo "$OLD_PVC"
  
  echo "Would you like to force delete the old PVC? (y/n)"
  read -p "> " DELETE_OLD_PVC
  
  if [ "$DELETE_OLD_PVC" = "y" ]; then
    echo "Forcing deletion of old PVC..."
    kubectl patch pvc postgres-pvc -n $APP_NAMESPACE --type=json -p='[{"op":"remove","path":"/metadata/finalizers"}]' || true
    kubectl delete pvc postgres-pvc -n $APP_NAMESPACE --force --grace-period=0 || true
    echo "Deletion initiated. It may take a few moments to complete."
  fi
fi

# Wait for sync to complete if needed
if [ "$SYNC_STATUS" != "Synced" ] || [ "$HEALTH_STATUS" != "Healthy" ]; then
  echo -e "\nStep 5: Application is not fully synced and healthy yet."
  echo "Would you like to wait for sync to complete? (y/n)"
  read -p "> " WAIT_FOR_SYNC
  
  if [ "$WAIT_FOR_SYNC" = "y" ]; then
    echo "Waiting for application to sync and become healthy..."
    echo "This may take a few minutes..."
    
    for i in $(seq 1 12); do
      SYNC_STATUS=$(kubectl get application $APP_NAME -n $NAMESPACE -o jsonpath='{.status.sync.status}')
      HEALTH_STATUS=$(kubectl get application $APP_NAME -n $NAMESPACE -o jsonpath='{.status.health.status}')
      
      echo "[$i/12] Current status: Sync: $SYNC_STATUS, Health: $HEALTH_STATUS"
      
      if [ "$SYNC_STATUS" = "Synced" ] && [ "$HEALTH_STATUS" = "Healthy" ]; then
        echo "✅ Application is now synced and healthy!"
        break
      fi
      
      if [ $i -eq 12 ]; then
        echo "⚠️ Timeout waiting for application to sync and become healthy."
        echo "Please check the ArgoCD UI or run 'kubectl get application $APP_NAME -n $NAMESPACE -o yaml' for more details."
      fi
      
      sleep 10
    done
  fi
else
  echo -e "\n✅ Application is already synced and healthy!"
fi

echo -e "\n=== Verification Complete ==="
echo "Your PostgreSQL database is now running with a new PVC: $PVC_NAME"
echo "The ArgoCD application has been updated to refer to this new PVC."
echo "To access your PostgreSQL database:"
echo "kubectl exec -it \$(kubectl get pods -n $APP_NAMESPACE -l app=postgres -o jsonpath='{.items[0].metadata.name}') -n $APP_NAMESPACE -- psql -U postgres -d api"
