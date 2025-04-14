#!/bin/bash
# Script to fix application configuration issues for monitoring

set -e

NAMESPACE="student-api"

echo "=== Fixing Application Configuration for Monitoring ==="

# 1. Check nginx pod status and fix if needed
echo "Checking nginx pod status..."
NGINX_PODS=$(kubectl get pods -n $NAMESPACE -l app=nginx -o name)
if [ -z "$NGINX_PODS" ]; then
  echo "No nginx pods found! This is unexpected."
else
  echo "Found nginx pods: $NGINX_PODS"
  echo "Checking readiness issues..."
  
  # Get nginx pod status
  NGINX_STATUS=$(kubectl get pods -n $NAMESPACE -l app=nginx -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}')
  if [ "$NGINX_STATUS" != "True" ]; then
    echo "Nginx pod is not ready. Checking events..."
    NGINX_POD=$(kubectl get pods -n $NAMESPACE -l app=nginx -o name | head -1 | sed 's|pod/||')
    kubectl describe pod -n $NAMESPACE $NGINX_POD
    
    echo "Restarting nginx deployment to attempt fix..."
    kubectl rollout restart deployment nginx -n $NAMESPACE
    kubectl rollout status deployment nginx -n $NAMESPACE --timeout=60s
  else
    echo "Nginx pod is ready, but endpoints may be misconfigured."
    echo "Forcing endpoint refresh by restarting the deployment..."
    kubectl rollout restart deployment nginx -n $NAMESPACE
    kubectl rollout status deployment nginx -n $NAMESPACE --timeout=60s
  fi
fi

# 2. Check student-api configuration
echo -e "\nChecking student-api configuration..."
STUDENT_API_PORT=$(kubectl get svc -n $NAMESPACE student-api -o jsonpath='{.spec.ports[0].port}')
STUDENT_API_TARGET_PORT=$(kubectl get svc -n $NAMESPACE student-api -o jsonpath='{.spec.ports[0].targetPort}')
echo "Service port: $STUDENT_API_PORT, Target port: $STUDENT_API_TARGET_PORT"

# Check if the container is actually listening on the configured port
STUDENT_API_POD=$(kubectl get pods -n $NAMESPACE -l app=student-api -o name | head -1 | sed 's|pod/||')
if [ -n "$STUDENT_API_POD" ]; then
  echo "Checking exposed ports on student-api pod..."
  kubectl get pod -n $NAMESPACE $STUDENT_API_POD -o jsonpath='{.spec.containers[0].ports[*].containerPort}'
  echo ""
  
  echo "Restarting student-api deployment to refresh endpoints..."
  kubectl rollout restart deployment student-api -n $NAMESPACE
  kubectl rollout status deployment student-api -n $NAMESPACE --timeout=60s
fi

# 3. Update Blackbox Exporter configuration
echo -e "\nUpdating Blackbox Exporter configuration..."
helm upgrade student-api ./helm-charts/student-api-helm -n $NAMESPACE

# 4. Apply a NodePort service for the Blackbox exporter for easier access
echo -e "\nCreating NodePort service for Blackbox exporter..."
cat > /tmp/blackbox-nodeport.yaml << EOF
apiVersion: v1
kind: Service
metadata:
  name: blackbox-exporter-nodeport
  namespace: $NAMESPACE
spec:
  selector:
    app: blackbox-exporter
  ports:
  - name: http
    port: 9115
    targetPort: 9115
    nodePort: 30115
  type: NodePort
EOF

kubectl apply -f /tmp/blackbox-nodeport.yaml

echo -e "\n=== Setup Complete ==="
echo "To access Blackbox exporter externally:"
echo "  http://$(minikube ip):30115"
echo ""
echo "To test TCP probe to PostgreSQL:"
echo "  http://$(minikube ip):30115/probe?target=postgres-service.student-api.svc.cluster.local:5432&module=tcp_connection"
echo ""
echo "For troubleshooting specific services, use:"
echo "  kubectl run -n $NAMESPACE debug --image=nicolaka/netshoot --rm -it -- bash"
