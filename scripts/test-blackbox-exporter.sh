#!/bin/bash
# Test script for Blackbox Exporter

set -e

NAMESPACE=${1:-"student-api"}
BLACKBOX_POD_PREFIX="blackbox-exporter"
TIMEOUT=30s

echo "=== Testing Blackbox Exporter Setup ==="
echo "Using namespace: $NAMESPACE"

# Step 1: Verify the Blackbox exporter pod is running
echo "Step 1: Checking if Blackbox exporter is running..."
BLACKBOX_POD=$(kubectl get pod -n $NAMESPACE -l app=blackbox-exporter -o name | head -1 | sed 's|pod/||')

if [ -z "$BLACKBOX_POD" ]; then
  echo "❌ Blackbox exporter pod not found!"
  echo "Available pods in namespace:"
  kubectl get pods -n $NAMESPACE
  exit 1
fi

echo "✅ Found Blackbox exporter pod: $BLACKBOX_POD"
kubectl get pod -n $NAMESPACE $BLACKBOX_POD -o wide

# Step 2: Check if Blackbox exporter is ready
echo -e "\nStep 2: Checking if Blackbox exporter is ready..."
READY_STATUS=$(kubectl get pod -n $NAMESPACE $BLACKBOX_POD -o jsonpath='{.status.containerStatuses[0].ready}')
if [ "$READY_STATUS" != "true" ]; then
  echo "❌ Blackbox exporter is not ready"
  kubectl describe pod -n $NAMESPACE $BLACKBOX_POD
  exit 1
fi

echo "✅ Blackbox exporter is ready"

# Step 3: Forward the Blackbox exporter port
echo -e "\nStep 3: Setting up port-forwarding to access Blackbox exporter..."
kubectl port-forward -n $NAMESPACE pod/$BLACKBOX_POD 9115:9115 > /dev/null 2>&1 &
PF_PID=$!

# Wait for port-forwarding to establish
sleep 2

# Step 4: Test access to the Blackbox exporter API
echo -e "\nStep 4: Testing access to Blackbox exporter API..."
if ! curl -s http://localhost:9115 > /dev/null; then
  echo "❌ Failed to access Blackbox exporter API"
  kill $PF_PID 2>/dev/null || true
  exit 1
fi

echo "✅ Successfully connected to Blackbox exporter API"

# Step 5: Verify the configured modules
echo -e "\nStep 5: Checking configured probe modules..."
MODULES=$(curl -s http://localhost:9115/config | grep -o '"modules":{[^}]*}')
echo "$MODULES" | grep -q "http_2xx" && echo "✅ http_2xx module is configured" || echo "❌ http_2xx module missing"
echo "$MODULES" | grep -q "http_post_2xx" && echo "✅ http_post_2xx module is configured" || echo "❌ http_post_2xx module missing"
echo "$MODULES" | grep -q "tcp_connect" && echo "✅ tcp_connect module is configured" || echo "❌ tcp_connect module missing"
echo "$MODULES" | grep -q "icmp" && echo "✅ icmp module is configured" || echo "❌ icmp module missing"

# Step 6: Test the probes manually
echo -e "\nStep 6: Testing probes against target endpoints..."

echo "Testing Student API health endpoint:"
curl -s "http://localhost:9115/probe?target=http://student-api:8080/health&module=http_2xx" | grep -q "probe_success 1" && \
  echo "✅ Student API health check successful" || echo "❌ Student API health check failed"

echo "Testing Postgres connection:"
curl -s "http://localhost:9115/probe?target=postgres:5432&module=tcp_connect" | grep -q "probe_success 1" && \
  echo "✅ Postgres connection check successful" || echo "❌ Postgres connection check failed"

echo "Testing Nginx frontend:"
curl -s "http://localhost:9115/probe?target=http://nginx-service:80/&module=http_2xx" | grep -q "probe_success 1" && \
  echo "✅ Nginx frontend check successful" || echo "❌ Nginx frontend check failed"

# Step 7: Check Prometheus integration 
echo -e "\nStep 7: Verifying Prometheus can scrape Blackbox exporter..."
if kubectl get service -n $NAMESPACE blackbox-exporter &>/dev/null; then
  SERVICE_ANNOTATIONS=$(kubectl get service -n $NAMESPACE blackbox-exporter -o jsonpath='{.metadata.annotations}')
  echo "$SERVICE_ANNOTATIONS" | grep -q "prometheus.io/scrape" && \
    echo "✅ Service has Prometheus scrape annotation" || echo "❌ Service missing Prometheus scrape annotation"
else
  echo "❌ Blackbox exporter service not found"
fi

# Clean up
kill $PF_PID 2>/dev/null || true

echo -e "\n=== Blackbox Exporter Test Results ==="
echo "You can manually test targets with:"
echo "curl \"http://localhost:9115/probe?target=http://your-target&module=http_2xx\""
echo "To view all metrics, run:"
echo "kubectl port-forward -n $NAMESPACE pod/$BLACKBOX_POD 9115:9115"
echo "Then visit: http://localhost:9115/metrics"
