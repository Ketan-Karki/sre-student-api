#!/bin/bash
# Comprehensive verification script for Blackbox exporter

set -e

NAMESPACE="student-api"
EXPORTER_NAME="blackbox-exporter"

echo "=== Blackbox Exporter Verification ==="

# 1. Check if the pod is running
echo "Step 1: Checking if Blackbox exporter pod is running..."
POD_NAME=$(kubectl get pod -n $NAMESPACE -l app=$EXPORTER_NAME -o name | head -1)
if [ -z "$POD_NAME" ]; then
  echo "❌ Blackbox exporter pod not found"
  echo "Available pods in namespace:"
  kubectl get pods -n $NAMESPACE
  exit 1
fi

echo "✅ Found pod: $POD_NAME"
kubectl get pod -n $NAMESPACE ${POD_NAME#pod/} -o wide

# 2. Check services
echo -e "\nStep 2: Checking Blackbox exporter services..."
kubectl get svc -n $NAMESPACE -l app=$EXPORTER_NAME

# Check if NodePort service exists
NODEPORT_SVC=$(kubectl get svc -n $NAMESPACE blackbox-nodeport -o name 2>/dev/null || echo "")
if [ -z "$NODEPORT_SVC" ]; then
  echo "❌ NodePort service not found"
  
  echo "Creating NodePort service for Blackbox exporter..."
  kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: blackbox-nodeport
  namespace: $NAMESPACE
  labels:
    app: $EXPORTER_NAME
spec:
  selector:
    app: $EXPORTER_NAME
  ports:
  - port: 9115
    targetPort: 9115
    nodePort: 30115
  type: NodePort
EOF

  echo "Waiting for service to be available..."
  sleep 5
else
  echo "✅ NodePort service exists"
fi

# 3. Test with port-forwarding (more reliable than NodePort)
echo -e "\nStep 3: Testing with port-forwarding..."
# Kill any existing port-forwards
pkill -f "kubectl port-forward.*9115" >/dev/null 2>&1 || true
sleep 2

# Start port-forwarding
kubectl port-forward -n $NAMESPACE ${POD_NAME} 9115:9115 >/dev/null 2>&1 &
PF_PID=$!

# Wait for port-forward to establish
echo "Waiting for port-forwarding to establish..."
sleep 3

# Test local access
if curl -s --connect-timeout 5 localhost:9115 >/dev/null; then
  echo "✅ Port-forwarding successful"
else
  echo "❌ Port-forwarding failed"
  kill $PF_PID 2>/dev/null || true
  exit 1
fi

# 4. Test PostgreSQL probe
echo -e "\nStep 4: Testing PostgreSQL probe via port-forward..."
RESULT=$(curl -s "http://localhost:9115/probe?target=postgres-service:5432&module=tcp_connection")

if echo "$RESULT" | grep -q "probe_success 1"; then
  echo "✅ PostgreSQL probe successful!"
else
  echo "❌ PostgreSQL probe failed:"
  echo "$RESULT" | grep -E "probe_success|error"
fi

# 5. Get detailed information about the configuration
echo -e "\nStep 5: Checking Blackbox exporter configuration..."
CONFIG=$(curl -s "http://localhost:9115/config")
echo "Available modules:"
echo "$CONFIG" | grep -o '"[^"]*":{"prober":"[^"]*"' | tr -d '"' | sed 's/{prober:/: /'

# 6. Clean up
echo -e "\nCleaning up..."
kill $PF_PID 2>/dev/null || true

echo -e "\n=== Final steps for manual testing ==="
echo "1. Access the Blackbox exporter UI:"
echo "   kubectl port-forward -n $NAMESPACE $POD_NAME 9115:9115"
echo "   Then browse to: http://localhost:9115"
echo ""
echo "2. Test the PostgreSQL probe:"
echo "   curl \"http://localhost:9115/probe?target=postgres-service:5432&module=tcp_connection\""
echo ""
echo "3. To access via NodePort (if working):"
echo "   MINIKUBE_IP=\$(minikube ip)"
echo "   curl \"http://\$MINIKUBE_IP:30115/probe?target=postgres-service:5432&module=tcp_connection\""
