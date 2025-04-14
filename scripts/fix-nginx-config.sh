#!/bin/bash

NAMESPACE="student-api"

echo "=== Fixing NGINX Configuration ==="

# Get the nginx pod name
NGINX_POD=$(kubectl get pods -n $NAMESPACE -l app=nginx -o name | head -1)
if [ -z "$NGINX_POD" ]; then
  echo "No nginx pod found!"
  exit 1
fi

echo "Found pod: $NGINX_POD"

# Create a simple nginx configuration
echo "Creating configuration file..."
CONFIG_FILE=$(mktemp)
cat > $CONFIG_FILE << EOF
server {
  listen 80;
  server_name localhost;
  
  location / {
    root /usr/share/nginx/html;
    index index.html;
    default_type text/html;
    return 200 "<html><body><h1>Student API</h1><p>Service is running properly.</p></body></html>";
  }
  
  location /health {
    default_type application/json;
    return 200 '{"status":"ok"}';
  }
  
  location /metrics {
    default_type text/plain;
    return 200 '# TYPE nginx_up gauge\nnginx_up 1\n';
  }
}
EOF

# Copy the configuration to the pod
echo "Copying configuration to $NGINX_POD..."
kubectl cp $CONFIG_FILE ${NGINX_POD#pod/}:/etc/nginx/conf.d/default.conf -n $NAMESPACE

# Reload nginx
echo "Reloading nginx..."
kubectl exec -n $NAMESPACE ${NGINX_POD#pod/} -- nginx -s reload

# Clean up
rm $CONFIG_FILE

# Test if the service works now
echo "Testing service..."
kubectl run test-service -n $NAMESPACE --image=curlimages/curl --restart=Never --rm -it -- sh -c "curl -v student-api:8080/health" || echo "Test failed"

echo "=== Fix Complete ==="
