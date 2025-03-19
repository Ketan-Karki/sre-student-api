#!/bin/bash

NAMESPACE="student-api"
echo "=== Force PVC Cleanup Script ==="

# 1. Check for any terminating PVCs
echo "Step 1: Finding terminating PVCs..."
TERMINATING_PVCS=$(kubectl get pvc -n $NAMESPACE -o jsonpath='{.items[?(@.metadata.deletionTimestamp!=null)].metadata.name}')

if [ -z "$TERMINATING_PVCS" ]; then
  echo "No terminating PVCs found. Checking if postgres-pvc exists..."
  if kubectl get pvc postgres-pvc -n $NAMESPACE &>/dev/null; then
    echo "postgres-pvc exists but is not terminating."
  else
    echo "No postgres-pvc found at all. Ready to create a new one."
  fi
else
  echo "Found terminating PVCs: $TERMINATING_PVCS"
  
  for PVC in $TERMINATING_PVCS; do
    echo "Processing PVC: $PVC"
    
    # Get PVC details
    echo "Getting details of stuck PVC..."
    kubectl get pvc $PVC -n $NAMESPACE -o yaml > /tmp/stuck-pvc.yaml
    
    # Find associated PV
    PV_NAME=$(grep -A 1 "volumeName:" /tmp/stuck-pvc.yaml | grep -v "volumeName:" | tr -d " " || echo "")
    
    # Force removal of finalizers from PVC
    echo "Removing finalizers from PVC..."
    kubectl patch pvc $PVC -n $NAMESPACE --type=json -p='[{"op": "remove", "path": "/metadata/finalizers"}]' || true
    
    # Force delete the PVC
    echo "Force deleting PVC..."
    kubectl delete pvc $PVC -n $NAMESPACE --force --grace-period=0 || true
    
    # Clean up associated PV if found
    if [ -n "$PV_NAME" ]; then
      echo "Found associated PV: $PV_NAME"
      echo "Removing finalizers from PV..."
      kubectl patch pv $PV_NAME --type=json -p='[{"op": "remove", "path": "/metadata/finalizers"}]' || true
      
      echo "Force deleting PV..."
      kubectl delete pv $PV_NAME --force --grace-period=0 || true
    fi
  done
fi

# 2. Wait a moment to ensure deletion is processed
echo -e "\nStep 2: Waiting for deletion to complete..."
sleep 5

# 3. Create a new PVC with unique name
echo -e "\nStep 3: Creating new PVC with unique name..."
NEW_PVC_NAME="postgres-data-$(date +%s)"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: $NEW_PVC_NAME
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

# 4. Create new deployment that uses this PVC
echo -e "\nStep 4: Creating new deployment with unique PVC..."
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
            memory: 128Mi
        volumeMounts:
        - mountPath: /var/lib/postgresql/data
          name: postgres-storage
      volumes:
      - name: postgres-storage
        persistentVolumeClaim:
          claimName: $NEW_PVC_NAME
EOF

# 5. Wait for pod to start
echo -e "\nStep 5: Waiting for pod to start..."
sleep 10

echo "Current pods:"
kubectl get pods -n $NAMESPACE -l app=postgres

echo "Events related to postgres deployment:"
kubectl get events -n $NAMESPACE --field-selector involvedObject.kind=Deployment,involvedObject.name=postgres --sort-by='.lastTimestamp' | tail -5

echo -e "\n=== Cleanup Complete ==="
echo "New PVC name: $NEW_PVC_NAME"
echo "You may need to update any references to the old PVC name in other resources."
