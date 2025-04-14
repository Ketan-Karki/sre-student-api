#!/bin/bash
# Script to test Blackbox exporter functionality

set -e

NAMESPACE="student-api"
POD_NAME=$(kubectl get pod -n $NAMESPACE -l app=blackbox-exporter -o name | head -1)

if [ -z "$POD_NAME" ]; then
  echo "❌ No Blackbox exporter pod found"
  exit 1
fi

echo "Found Blackbox exporter pod: $POD_NAME"
echo "Setting up port forwarding..."

# Kill any existing port-forward processes
pkill -f "kubectl port-forward.*9115" || true
sleep 2

# Start port forwarding in the background
kubectl port-forward -n $NAMESPACE $POD_NAME 9115:9115 &
PF_PID=$!

# Give the port forward a moment to establish
echo "Waiting for port-forward to establish..."
sleep 5

# Check if the port forward is working
if ! nc -z localhost 9115 >/dev/null 2>&1; then
  echo "❌ Port forwarding failed. Unable to connect to port 9115"
  kill $PF_PID 2>/dev/null || true
  exit 1
fi

echo "✅ Port forwarding established successfully"

# Function to test a probe
test_probe() {
  local target=$1
  local module=$2
  local description=$3
  
  echo -e "\n--- Testing $description ---"
  echo "Target: $target"
  echo "Module: $module"
  
  local result
  result=$(curl -s "http://localhost:9115/probe?target=$target&module=$module")
  
  if echo "$result" | grep -q "probe_success 1"; then
    echo "✅ Probe successful"
  else
    echo "❌ Probe failed"
    echo "Results:"
    echo "$result" | grep -E "probe_success|probe_http_status_code|probe_duration_seconds"
  fi
}

# Test the configuration itself
echo -e "\nTesting Blackbox exporter configuration..."
curl -s http://localhost:9115/config | grep -q "tcp_connection" && echo "✅ tcp_connection module configured correctly" || echo "❌ tcp_connection module not found"

# Test different probes
test_probe "student-api.student-api.svc.cluster.local:8080" "http_2xx" "Student API"
test_probe "postgres-service.student-api.svc.cluster.local:5432" "tcp_connection" "PostgreSQL database"
test_probe "nginx-service.student-api.svc.cluster.local:80" "http_2xx" "Nginx frontend"

# Try with simpler names (sometimes DNS resolution works better this way)
echo -e "\n--- Testing with shorter service names ---"
test_probe "student-api:8080" "http_2xx" "Student API (short name)"
test_probe "postgres-service:5432" "tcp_connection" "PostgreSQL database (short name)"
test_probe "nginx-service:80" "http_2xx" "Nginx frontend (short name)"

# Clean up
echo -e "\nCleaning up port-forward..."
kill $PF_PID 2>/dev/null || true

echo -e "\nTo continue testing manually, run:"
echo "kubectl port-forward -n $NAMESPACE $POD_NAME 9115:9115"
echo "Then access http://localhost:9115 in your browser"
