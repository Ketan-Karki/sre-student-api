#!/bin/bash
# Fix script for image pull issues and monitoring setup

set -e

NAMESPACE="student-api"

echo "=== Fixing Image and Monitoring Setup ==="

# 1. Fix the nginx image tag - the 66779b1 tag doesn't exist
echo "Updating nginx image configuration..."
kubectl patch deployment nginx -n $NAMESPACE --type=json \
  -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/image", "value": "nginx:latest"}]'

# Wait for the nginx deployment to become ready
echo "Waiting for nginx deployment to become ready..."
kubectl rollout status deployment nginx -n $NAMESPACE --timeout=60s || true

# 2. Check student-api service
echo "Checking student-api service..."
kubectl get svc student-api -n $NAMESPACE

# 3. Create a debug pod to test connectivity
echo "Creating debug pod to test internal connectivity..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: debug-pod
  namespace: $NAMESPACE
spec:
  containers:
  - name: debug
    image: curlimages/curl
    command: ["sleep", "3600"]
EOF

# Wait for the debug pod to be ready
echo "Waiting for debug pod to be ready..."
kubectl wait --for=condition=ready pod/debug-pod -n $NAMESPACE --timeout=60s

# 4. Test connectivity from the debug pod
echo "Testing connectivity from debug pod..."
echo "Testing postgres-service (TCP):"
kubectl exec -n $NAMESPACE debug-pod -- sh -c "nc -zv postgres-service 5432; echo \$?"

echo "Testing student-api (HTTP):"
kubectl exec -n $NAMESPACE debug-pod -- sh -c "curl -s -o /dev/null -w '%{http_code}' http://student-api:8080/ || echo 'Connection failed'"

echo "Testing nginx-service (HTTP):"
kubectl exec -n $NAMESPACE debug-pod -- sh -c "curl -s -o /dev/null -w '%{http_code}' http://nginx-service/ || echo 'Connection failed'"

# 5. Update the Helm chart and upgrade the release
echo "Updating Helm release..."
helm upgrade student-api ./helm-charts/student-api-helm -n $NAMESPACE --set nginx.image.tag=latest

# 6. Create NodePort service for Blackbox exporter
echo "Creating NodePort service for Blackbox exporter..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: blackbox-nodeport
  namespace: $NAMESPACE
spec:
  selector:
    app: blackbox-exporter
  ports:
  - port: 9115
    targetPort: 9115
    nodePort: 30115
  type: NodePort
EOF

echo "=== Setup Complete ==="
echo "To test the Blackbox exporter with PostgreSQL:"
echo "  1. Access the Blackbox exporter: http://$(minikube ip):30115"
echo "  2. Test the TCP probe: http://$(minikube ip):30115/probe?target=postgres-service:5432&module=tcp_connection"
echo ""
echo "To clean up the debug pod when done:"
echo "  kubectl delete pod debug-pod -n $NAMESPACE"
