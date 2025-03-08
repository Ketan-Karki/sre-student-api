#!/bin/bash
# Script to generate a verification summary for Helm deployment

NAMESPACE=${1:-dev-student-api}
echo "===== Verification Summary for: $NAMESPACE ====="

# Check all deployments
echo "Deployment Status:"
kubectl get deployments -n $NAMESPACE -o custom-columns=NAME:.metadata.name,READY:.status.readyReplicas,DESIRED:.spec.replicas,AVAILABLE:.status.availableReplicas

# Check all services
echo -e "\nService Status:"
kubectl get services -n $NAMESPACE -o custom-columns=NAME:.metadata.name,TYPE:.spec.type,CLUSTER-IP:.spec.clusterIP,EXTERNAL-IP:.status.loadBalancer.ingress[0].ip,PORT:.spec.ports[0].port

# Check API health
echo -e "\nAPI Health Check:"
# Find the API service port
API_PORT=$(kubectl get svc student-api -n $NAMESPACE -o jsonpath="{.spec.ports[0].port}" 2>/dev/null || echo "8080")

# Start port-forward in background
kubectl port-forward svc/student-api -n $NAMESPACE 9999:$API_PORT &> /dev/null &
PF_PID=$!

# Give it time to establish
sleep 3

# Check health endpoint
HEALTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9999/api/v1/healthcheck 2>/dev/null || echo "Failed")
if [ "$HEALTH_STATUS" == "200" ]; then
  echo "✅ API health check passed (HTTP 200)"
else
  echo "❌ API health check failed (HTTP $HEALTH_STATUS)"
fi

# Cleanup
kill $PF_PID &> /dev/null || true

echo -e "\n===== Verification Complete ====="
echo "Deployment is $([ "$HEALTH_STATUS" == "200" ] && echo "healthy ✅" || echo "not healthy ❌")"
