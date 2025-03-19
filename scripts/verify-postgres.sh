#!/bin/bash

set -e

NAMESPACE="student-api"
echo "=== PostgreSQL Verification and Fix Script ==="

# Check pod status
echo -e "\nStep 1: Checking PostgreSQL pod status"
POSTGRES_POD=$(kubectl get pods -n $NAMESPACE -l app=postgres -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -z "$POSTGRES_POD" ]; then
  echo "❌ No PostgreSQL pods found!"
  echo "Checking for recent pod terminations..."
  kubectl get events -n $NAMESPACE --field-selector involvedObject.kind=Pod,reason=Killing --sort-by='.lastTimestamp' | tail -5
else
  echo "Pod: $POSTGRES_POD"
  POD_STATUS=$(kubectl get pod $POSTGRES_POD -n $NAMESPACE -o jsonpath='{.status.phase}')
  echo "Status: $POD_STATUS"
  
  if [ "$POD_STATUS" = "Pending" ]; then
    echo -e "\nInvestigating Pending status..."
    echo "Pod scheduling issues:"
    kubectl get pod $POSTGRES_POD -n $NAMESPACE -o jsonpath='{.status.conditions[?(@.type=="PodScheduled")].message}'
    echo ""
  
    echo "Checking PVC status:"
    kubectl get pvc -n $NAMESPACE
    
    echo -e "\nChecking volume status:"
    PV_NAME=$(kubectl get pvc postgres-pvc -n $NAMESPACE -o jsonpath='{.spec.volumeName}' 2>/dev/null || echo "")
    if [ -n "$PV_NAME" ]; then
      kubectl get pv $PV_NAME
    else
      echo "⚠️ No PV bound to the PVC yet"
    fi
  fi
  
  if [ "$POD_STATUS" = "Running" ]; then
    echo -e "\nContainer status:"
    kubectl get pod $POSTGRES_POD -n $NAMESPACE -o jsonpath='{.status.containerStatuses[0].ready}{"\n"}'
    
    echo -e "\nChecking PostgreSQL logs:"
    kubectl logs $POSTGRES_POD -n $NAMESPACE --tail=20
    
    # Test database connection
    echo -e "\nTesting database connection:"
    kubectl exec -n $NAMESPACE $POSTGRES_POD -- pg_isready -U postgres || echo "⚠️ Database is not ready"
  fi
  
  # Show recent pod events
  echo -e "\nRecent pod events:"
  kubectl get events -n $NAMESPACE --field-selector involvedObject.name=$POSTGRES_POD --sort-by='.lastTimestamp' | tail -5
fi

# Fix common issues
echo -e "\nStep 2: Applying fixes for common issues"

if [ "$POD_STATUS" = "Pending" ]; then
  echo "Would you like to recreate the PostgreSQL deployment with updated settings? (y/n)"
  read -p "> " RECREATE_DEPLOYMENT
  
  if [ "$RECREATE_DEPLOYMENT" = "y" ]; then
    echo "Deleting deployment and recreating..."
    kubectl delete deployment postgres -n $NAMESPACE --ignore-not-found=true
    
    echo "Creating deployment with improved configuration..."
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
          claimName: postgres-pvc
EOF
  
    # Wait for pod to start
    echo "Waiting for new pod to start..."
    sleep 10
    kubectl get pods -n $NAMESPACE -l app=postgres
  fi
elif [ "$POD_STATUS" = "Running" ]; then
  CONTAINER_READY=$(kubectl get pod $POSTGRES_POD -n $NAMESPACE -o jsonpath='{.status.containerStatuses[0].ready}')
  if [ "$CONTAINER_READY" != "true" ]; then
    echo "Would you like to restart the pod? (y/n)"
    read -p "> " RESTART_POD
    
    if [ "$RESTART_POD" = "y" ]; then
      echo "Deleting pod to force restart..."
      kubectl delete pod $POSTGRES_POD -n $NAMESPACE
      
      # Wait for pod to restart
      echo "Waiting for pod to restart..."
      sleep 10
      kubectl get pods -n $NAMESPACE -l app=postgres
    fi
  fi
fi

# Verify final status
echo -e "\nStep 3: Final verification"
echo "Current pods:"
kubectl get pods -n $NAMESPACE -l app=postgres

# Check if pod is running successfully
NEW_POD=$(kubectl get pods -n $NAMESPACE -l app=postgres -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$NEW_POD" ]; then
  NEW_STATUS=$(kubectl get pod $NEW_POD -n $NAMESPACE -o jsonpath='{.status.phase}')
  if [ "$NEW_STATUS" = "Running" ]; then
    READY=$(kubectl get pod $NEW_POD -n $NAMESPACE -o jsonpath='{.status.containerStatuses[0].ready}')
    if [ "$READY" = "true" ]; then
      echo "✅ PostgreSQL pod is running and ready!"
      
      # Print connection information
      echo -e "\nConnection information:"
      echo "Host: postgres-service.$NAMESPACE.svc.cluster.local"
      echo "Port: 5432"
      echo "User: postgres"
      echo "Password: postgres"
      echo "Database: api"
      
      echo -e "\nYou can connect to the database using:"
      echo "kubectl exec -it $NEW_POD -n $NAMESPACE -- psql -U postgres -d api"
    else
      echo "⚠️ PostgreSQL pod is running but not ready"
      echo "Check logs for more details:"
      echo "kubectl logs $NEW_POD -n $NAMESPACE"
    fi
  else
    echo "⚠️ PostgreSQL pod is in $NEW_STATUS state"
    echo "Check pod description for more details:"
    echo "kubectl describe pod $NEW_POD -n $NAMESPACE"
  fi
else
  echo "❌ No PostgreSQL pods found after fix attempt"
fi

echo -e "\n=== Verification Complete ==="
