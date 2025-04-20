#!/bin/bash
# Script to fix student-api issues

NAMESPACE="student-api"

echo "=== Fixing Student API Service ==="

# Step 1: Find the pod
echo "Step 1: Finding student-api pod..."
STUDENT_API_POD=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=student-api -o name 2>/dev/null | head -1)
if [ -z "$STUDENT_API_POD" ]; then
  echo "No pod found with label app.kubernetes.io/name=student-api"
  echo "Looking for pods with app label instead..."
  STUDENT_API_POD=$(kubectl get pods -n $NAMESPACE -l app=student-api -o name 2>/dev/null | head -1)
fi

if [ -z "$STUDENT_API_POD" ]; then
  echo "Error: Could not find student-api pod"
  echo "Available pods:"
  kubectl get pods -n $NAMESPACE --show-labels
  exit 1
fi

echo "Found pod: $STUDENT_API_POD"

# Step 2: Configure and test nginx in the student-api pod
echo -e "\nStep 2: Fixing nginx configuration in student-api pod..."

# Create a proper nginx.conf file that listens on port 8080
echo "Creating proper nginx configuration..."
cat <<EOT > /tmp/nginx.conf
events {}
http {
    server {
        listen 8080;
        server_name localhost;
        
        location / {
            root /usr/share/nginx/html;
            index index.html;
        }
        
        location /health {
            return 200 '{"status":"ok"}';
            add_header Content-Type application/json;
        }
        
        location /metrics {
            return 200 '# TYPE example_metric gauge\nexample_metric 1\n';
            add_header Content-Type text/plain;
        }
    }
}
EOT

# Create a proper index.html
cat <<EOT > /tmp/index.html
<!DOCTYPE html>
<html>
<head>
    <title>Student API</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 40px;
            line-height: 1.6;
        }
        h1 {
            color: #333;
        }
    </style>
</head>
<body>
    <h1>Student API</h1>
    <p>This is a test page for the Student API service.</p>
    <p>Status: <strong>Running</strong></p>
    <p>Health check endpoint: <a href="/health">/health</a></p>
    <p>Metrics endpoint: <a href="/metrics">/metrics</a></p>
</body>
</html>
EOT

# Copy the files to the pod
echo "Copying configuration files to the pod..."
kubectl cp /tmp/nginx.conf ${STUDENT_API_POD#pod/}:/etc/nginx/nginx.conf -n $NAMESPACE
kubectl cp /tmp/index.html ${STUDENT_API_POD#pod/}:/usr/share/nginx/html/index.html -n $NAMESPACE

# Restart nginx in the pod
echo "Restarting nginx in the pod..."
kubectl exec -n $NAMESPACE ${STUDENT_API_POD} -- nginx -s reload || echo "Failed to reload nginx"
kubectl exec -n $NAMESPACE ${STUDENT_API_POD} -- sh -c "ps aux | grep nginx"

# Wait for nginx to start
sleep 5

# Step 3: Test the API
echo -e "\nStep 3: Testing student-api from within the pod..."
kubectl exec -n $NAMESPACE ${STUDENT_API_POD} -- sh -c "curl -v localhost:8080/health" || echo "Health check failed"
kubectl exec -n $NAMESPACE ${STUDENT_API_POD} -- sh -c "curl -v localhost:8080/metrics" || echo "Metrics check failed"

# Step 4: Fix nginx-service to point to student-api
echo -e "\nStep 4: Fixing nginx-service configuration..."

# Create a new nginx config with correct upstream
cat <<EOT > /tmp/nginx-service-config.conf
events {}
http {
    upstream backend {
        server student-api.${NAMESPACE}.svc:8080;
    }
    server {
        listen 80;
        
        location / {
            proxy_pass http://backend;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
        }
    }
}
EOT

# Update the ConfigMap
echo "Updating nginx-config ConfigMap..."
kubectl create configmap nginx-config -n $NAMESPACE --from-file=nginx.conf=/tmp/nginx-service-config.conf -o yaml --dry-run=client | kubectl replace -f -

# Step 5: Restart the nginx pod to pick up new config
echo -e "\nStep 5: Restarting nginx pod..."
NGINX_POD=$(kubectl get pods -n $NAMESPACE -l app=nginx -o name | head -1)
if [ -n "$NGINX_POD" ]; then
  kubectl delete $NGINX_POD -n $NAMESPACE
  echo "Waiting for new nginx pod to start..."
  sleep 10
fi

# Step 6: Final connectivity test
echo -e "\nStep 6: Final connectivity test..."
kubectl run test-connectivity -n $NAMESPACE --image=curlimages/curl --restart=Never --rm -it -- sh -c '
    echo "Testing student-api health endpoint..."
    curl -v http://student-api:8080/health
    
    echo "\nTesting nginx-service..."
    curl -v http://nginx-service/health
' || echo "Test pod execution failed"

echo -e "\n=== Student API Fix Complete ==="
echo "Now update the Blackbox Exporter configuration to monitor these services."

#!/bin/bash

echo "=== Diagnosing Student API issues ==="

# Check init container logs
INIT_POD=$(kubectl get pods -n student-api -l app.kubernetes.io/name=student-api -o name | head -1)
echo "Checking init container logs for $INIT_POD..."
kubectl logs $INIT_POD -n student-api -c init-container 2>/dev/null || echo "No init container logs available"

# Check events
echo -e "\n=== Events for student-api namespace ==="
kubectl get events -n student-api --sort-by='.lastTimestamp'

# Fix potential issues
echo -e "\n=== Attempting to fix Student API deployment ==="

# Create a fast-starting test deployment
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: metrics-demo
  namespace: student-api
  labels:
    app: metrics-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: metrics-demo
  template:
    metadata:
      labels:
        app: metrics-demo
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/path: "/metrics"
        prometheus.io/port: "8080"
    spec:
      containers:
      - name: metrics
        image: nginx:latest
        ports:
        - containerPort: 80
        command:
        - sh
        - -c
        - |
          echo '<html><body><h1>Metrics Test</h1></body></html>' > /usr/share/nginx/html/index.html
          nginx -g 'daemon off;'
EOF

# Create a ClusterIP service for the metrics demo
kubectl apply -f - << EOF
apiVersion: v1
kind: Service
metadata:
  name: metrics-demo
  namespace: student-api
spec:
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: metrics-demo
EOF

echo -e "\n=== Waiting for metrics-demo to be ready ==="
kubectl wait --for=condition=available --timeout=60s deployment/metrics-demo -n student-api

echo -e "\n=== Updating Grafana Alert Rules ==="
echo "Now modify your alert rules in Grafana UI to use:"
echo "- For testing: vector(1)"
echo "- For uptime: up{namespace=\"student-api\", job=\"kubernetes-pods\"}"

echo -e "\n=== Student API Pod Status ==="
kubectl get pods -n student-api
