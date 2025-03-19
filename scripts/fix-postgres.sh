#!/bin/bash

set -e

NAMESPACE="student-api"
echo "=== PostgreSQL Deployment Fix Script ==="

# 1. Gather information about the current state
echo -e "\nStep 1: Gathering current deployment information"
echo "Current postgres pods:"
kubectl get pods -n $NAMESPACE -l app=postgres
echo -e "\nPod details:"
POSTGRES_POD=$(kubectl get pods -n $NAMESPACE -l app=postgres -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$POSTGRES_POD" ]; then
  kubectl describe pod $POSTGRES_POD -n $NAMESPACE
  echo -e "\nContainer logs (if available):"
  kubectl logs $POSTGRES_POD -n $NAMESPACE --container postgres --tail=30 2>/dev/null || echo "No logs available"
fi

# 2. Check PVCs
echo -e "\nStep 2: Checking PVCs"
kubectl get pvc -n $NAMESPACE
echo -e "\nPVC details:"
kubectl get pvc -n $NAMESPACE -o yaml | grep -A 5 "volumeName\|storageClassName"

# 3. Apply fixes
echo -e "\nStep 3: Applying fixes to Postgres deployment"

# Create a deployment file that we can reference later
cat > /tmp/postgres-deployment.yaml << EOF
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

echo "Creating service if it doesn't exist..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: postgres-service
  namespace: $NAMESPACE
  labels:
    app: postgres
spec:
  selector:
    app: postgres
  ports:
  - port: 5432
    targetPort: 5432
  type: ClusterIP
EOF

# 4. Recreate PVC if needed
echo -e "\nStep 4: Do you want to recreate the postgres PVC? This will delete any existing data (y/n)"
read -p "> " RECREATE_PVC

if [ "$RECREATE_PVC" = "y" ]; then
  echo "Deleting the postgres deployment first..."
  kubectl delete deployment postgres -n $NAMESPACE

  echo "Waiting for deployment to be deleted..."
  sleep 5

  echo "Deleting existing PVC..."
  kubectl delete pvc postgres-pvc -n $NAMESPACE --ignore-not-found=true

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

  echo "Recreating the postgres deployment..."
  kubectl apply -f /tmp/postgres-deployment.yaml
else
  echo "Skipping PVC recreation."
fi

# 5. Check results
echo -e "\nStep 5: Checking deployment status"
echo "Waiting for pods to restart..."
sleep 10

echo "Current pods:"
kubectl get pods -n $NAMESPACE -l app=postgres

echo -e "\nIf the pod is still not ready, check the logs:"
NEW_POD=$(kubectl get pods -n $NAMESPACE -l app=postgres -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$NEW_POD" ]; then
  echo "kubectl logs $NEW_POD -n $NAMESPACE"
fi

echo -e "\n=== Fix Process Complete ==="
echo "If problems persist, consider:"
echo "1. Manually verify PostgreSQL configuration"
echo "2. Check if your cluster has enough resources"
echo "3. Check the Kubernetes events: kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp'"
echo "4. Consider using a pre-populated database image"
