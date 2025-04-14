#!/bin/bash

NAMESPACE="student-api"

echo "=== Configuring Services ==="

# Configure student-api pod
STUDENT_API_POD=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=student-api -o name | head -1)
if [ -n "$STUDENT_API_POD" ]; then
    echo "Configuring student-api pod..."
    
    # Create nginx configuration
    kubectl exec -n $NAMESPACE $STUDENT_API_POD -- sh -c '
        echo "events { worker_connections 1024; }
        http {
            server {
                listen 8080;
                root /usr/share/nginx/html;
                
                location / {
                    try_files \$uri \$uri/ =404;
                }
                
                location /health {
                    access_log off;
                    return 200 '\''{"status":"ok"}'\'';
                    add_header Content-Type application/json;
                }
                
                location /metrics {
                    access_log off;
                    return 200 '\''# TYPE test_metric gauge\ntest_metric 1'\'';
                    add_header Content-Type text/plain;
                }
            }
        }" > /etc/nginx/nginx.conf'
    
    # Create index.html
    kubectl exec -n $NAMESPACE $STUDENT_API_POD -- sh -c '
        echo "<html><body><h1>Student API</h1></body></html>" > /usr/share/nginx/html/index.html'
    
    # Reload nginx
    kubectl exec -n $NAMESPACE $STUDENT_API_POD -- nginx -s reload
fi

# Verify student-api is working
echo "Verifying student-api..."
kubectl run -n $NAMESPACE curl-test --rm -i --tty --restart=Never --image=curlimages/curl -- \
    curl -v http://student-api:8080/health

echo "=== Configuration Complete ==="
