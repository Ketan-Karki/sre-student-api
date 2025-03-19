#!/bin/bash

# Don't exit on errors - continue with the script
set +e

NAMESPACE="student-api"
PVC_NAME="postgres-pvc"
echo "=== PostgreSQL Recovery Script ==="

# Function to handle timeout for commands
run_with_timeout() {
    local timeout=$1
    local command="${@:2}"
    
    echo "Running with $timeout second timeout: $command"
    
    # Start the command in the background
    eval "$command" &
    local pid=$!
    
    # Start a timer
    (
        sleep $timeout
        # If the process is still running after timeout, kill it
        if ps -p $pid > /dev/null; then
            echo "Command timed out after $timeout seconds: $command"
            kill -9 $pid 2>/dev/null || true
        fi
    ) &
    local timer_pid=$!
    
    # Wait for the command to finish
    wait $pid 2>/dev/null || true
    
    # Kill the timer
    kill -9 $timer_pid 2>/dev/null || true
}

# 1. Remove finalizers from stuck PVC and pods
echo -e "\nStep 1: Removing finalizers from stuck resources..."

# Check if PVC exists at all (with timeout)
run_with_timeout 5 "kubectl get pvc $PVC_NAME -n $NAMESPACE --no-headers --ignore-not-found"

# Get PVC in JSON format for patching (with timeout)
run_with_timeout 5 "kubectl get pvc $PVC_NAME -n $NAMESPACE -o json > /tmp/pvc.json || echo '{\"metadata\":{}}' > /tmp/pvc.json"

# Remove finalizers from the PVC JSON
if [ -s /tmp/pvc.json ] && [ -x "$(command -v jq)" ]; then
  cat /tmp/pvc.json | jq '.metadata.finalizers = null' > /tmp/pvc-nofinalizers.json 2>/dev/null || echo "Error processing PVC JSON"
  
  # Apply the modified PVC without finalizers (with timeout)
  echo "Removing finalizers from $PVC_NAME..."
  run_with_timeout 5 "kubectl replace --raw \"/api/v1/namespaces/$NAMESPACE/persistentvolumeclaims/$PVC_NAME\" -f /tmp/pvc-nofinalizers.json || echo 'PVC update failed, continuing...'"
else
  echo "Skipping PVC finalizer removal - either PVC doesn't exist or jq not installed"
fi

# Remove finalizers from any stuck postgres pods (with timeout)
echo "Finding stuck postgres pods..."
STUCK_PODS=$(run_with_timeout 5 "kubectl get pods -n $NAMESPACE -l app=postgres -o name" || echo "")

for POD in $STUCK_PODS; do
  POD_NAME=$(echo $POD | cut -d/ -f2)
  echo "Removing finalizers from pod $POD_NAME..."
  
  run_with_timeout 5 "kubectl get pod $POD_NAME -n $NAMESPACE -o json > /tmp/pod.json"
  
  if [ -s /tmp/pod.json ] && [ -x "$(command -v jq)" ]; then
    cat /tmp/pod.json | jq '.metadata.finalizers = null' > /tmp/pod-nofinalizers.json
    run_with_timeout 5 "kubectl replace --raw \"/api/v1/namespaces/$NAMESPACE/pods/$POD_NAME\" -f /tmp/pod-nofinalizers.json || echo 'Pod update failed, continuing...'"
  fi
done

# 2. Delete any remaining postgres-related resources
echo -e "\nStep 2: Deleting any remaining postgres resources..."

echo "Deleting postgres deployment..."
run_with_timeout 10 "kubectl delete deployment postgres -n $NAMESPACE --force --grace-period=0 --ignore-not-found=true"

echo "Deleting remaining postgres pods..."
run_with_timeout 10 "kubectl delete pods -n $NAMESPACE -l app=postgres --force --grace-period=0 --ignore-not-found=true"

echo "Deleting postgres PVC..."
run_with_timeout 10 "kubectl delete pvc $PVC_NAME -n $NAMESPACE --force --grace-period=0 --ignore-not-found=true"

echo "Brief pause before continuing..."
sleep 2

# 3. Clean up any orphaned volumes - now with specific targeting and robust timeouts
echo -e "\nStep 3: Checking for orphaned PVs..."

# Skip this step if we've been running too long to avoid hanging
echo "Do you want to check for orphaned PVs? (y/n)"
read -p "> " CHECK_PVS

if [ "$CHECK_PVS" = "y" ]; then
  # Find only the PVs that are likely related to our postgres-pvc (with timeout)
  echo "Finding PVs specifically related to $NAMESPACE/$PVC_NAME..."
  PV_CHECK_CMD="kubectl get pv -o json | jq -r '.items[] | select(.spec.claimRef.namespace == \"$NAMESPACE\" and .spec.claimRef.name == \"$PVC_NAME\") | .metadata.name'"
  
  ORPHANED_PVS=$(run_with_timeout 10 "$PV_CHECK_CMD" || echo "")
  
  if [ -n "$ORPHANED_PVS" ]; then
    echo "Found these PVs to clean up: $ORPHANED_PVS"
    
    echo "Would you like to delete these PVs? (y/n)"
    read -p "> " DELETE_PVS
    
    if [ "$DELETE_PVS" = "y" ]; then
      for PV in $ORPHANED_PVS; do
        echo "Processing PV: $PV"
        echo "Removing finalizers..."
        run_with_timeout 5 "kubectl patch pv $PV -p '{\"metadata\":{\"finalizers\":null}}'" || echo "Finalizer removal timed out, continuing"
        
        echo "Deleting PV..."
        run_with_timeout 5 "kubectl delete pv $PV --force --grace-period=0" || echo "PV deletion timed out, continuing"
      done
    else
      echo "Skipping PV deletion."
    fi
  else
    echo "No orphaned PVs found specific to $NAMESPACE/$PVC_NAME"
  fi
else
  echo "Skipping PV check and cleanup."
fi

# 4. Create new PVC and deployment
echo -e "\nStep 4: Creating fresh PostgreSQL resources..."

echo "Creating new PVC..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: $NAMESPACE
  labels:
    app: postgres
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

echo "Creating new postgres deployment with PGDATA environment variable..."
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: $NAMESPACE
  labels:
    app: postgres
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15.3-alpine
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_USER
          value: postgres
        - name: POSTGRES_PASSWORD
          value: postgres
        - name: POSTGRES_DB
          value: api
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        resources:
          limits:
            memory: 512Mi
          requests:
            memory: 256Mi
        volumeMounts:
        - mountPath: /var/lib/postgresql/data
          name: postgres-storage
      volumes:
      - name: postgres-storage
        persistentVolumeClaim:
          claimName: postgres-pvc
EOF

# 5. Monitor the new deployment
echo -e "\nStep 5: Monitoring new deployment..."
echo "Waiting for the deployment to start..."
sleep 5

echo "Current pods:"
kubectl get pods -n $NAMESPACE -l app=postgres

echo -e "\nEvents related to postgres:"
kubectl get events -n $NAMESPACE --field-selector involvedObject.name=postgres --sort-by='.lastTimestamp' | tail -5

echo -e "\n=== Recovery Process Complete ==="
echo "If pods are still not starting correctly, check logs with:"
echo "kubectl logs -n $NAMESPACE \$(kubectl get pods -n $NAMESPACE -l app=postgres -o jsonpath='{.items[0].metadata.name}')"
echo ""
echo "Or check events with:"
echo "kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp'"
