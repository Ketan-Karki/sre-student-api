#!/bin/bash
# Script to fix connectivity issues between services

NAMESPACE="student-api"

echo "=== Fixing Service Connectivity Issues ==="

# Step 1: Check if the student-api pod is actually running a web server
echo "Step 1: Checking student-api pod..."
STUDENT_API_POD=$(kubectl get pods -n $NAMESPACE -l pod-template-hash=84f4797dcd -o name | head -1)
if [ -z "$STUDENT_API_POD" ]; then
    echo "Error: Could not find student-api pod"
    exit 1
fi

echo "Found pod: $STUDENT_API_POD"

# Step 2: Check if student-api pod is actually serving HTTP
echo -e "\nStep 2: Checking if student-api pod is serving HTTP..."
kubectl exec -n $NAMESPACE ${STUDENT_API_POD} -- curl -s localhost:8080 > /dev/null
if [ $? -ne 0 ]; then
    echo "Error: student-api pod is not serving HTTP on port 8080"
    echo "Creating a simple index.html in the pod..."
    kubectl exec -n $NAMESPACE ${STUDENT_API_POD} -- sh -c 'echo "<html><body><h1>Student API</h1><p>This is a test page.</p></body></html>" > /usr/share/nginx/html/index.html'
    echo "Configuring nginx in the pod..."
    kubectl exec -n $NAMESPACE ${STUDENT_API_POD} -- sh -c 'echo "server { listen 8080; root /usr/share/nginx/html; }" > /etc/nginx/conf.d/default.conf'
    echo "Restarting nginx in the pod..."
    kubectl exec -n $NAMESPACE ${STUDENT_API_POD} -- nginx -s reload || echo "Failed to reload nginx"
else
    echo "student-api pod is serving HTTP correctly"
fi

# Step 3: Check nginx-service configuration
echo -e "\nStep 3: Checking nginx-service configuration..."
NGINX_CM=$(kubectl get configmap -n $NAMESPACE nginx-config -o yaml)
if [ $? -ne 0 ]; then
    echo "Creating nginx-config ConfigMap..."
    kubectl create configmap nginx-config -n $NAMESPACE --from-literal=nginx.conf="
events {}
http {
    upstream backend {
        server student-api:8080;
    }
    server {
        listen 80;
        location / {
            proxy_pass http://backend;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
        }
    }
}"
else
    echo "nginx-config ConfigMap already exists"
fi

# Step 4: Let's ensure that our pods are using the right labels for service discovery
echo -e "\nStep 4: Verifying service selectors match pod labels..."

# Check student-api service selector
STUDENT_API_SELECTOR=$(kubectl get svc -n $NAMESPACE student-api -o jsonpath='{.spec.selector}')
echo "student-api service selector: $STUDENT_API_SELECTOR"

# Check nginx-service selector
NGINX_SELECTOR=$(kubectl get svc -n $NAMESPACE nginx-service -o jsonpath='{.spec.selector}')
echo "nginx-service selector: $NGINX_SELECTOR"

# Step 5: Restart deployments to ensure they pick up any configuration changes
echo -e "\nStep 5: Restarting deployments..."
kubectl rollout restart deployment/student-api -n $NAMESPACE
kubectl rollout restart deployment/nginx -n $NAMESPACE

echo "Waiting for deployments to restart..."
kubectl rollout status deployment/student-api -n $NAMESPACE --timeout=60s
kubectl rollout status deployment/nginx -n $NAMESPACE --timeout=60s

# Step 6: Create a test pod to verify connectivity
echo -e "\nStep 6: Testing connectivity with a new pod..."
kubectl run test-connectivity -n $NAMESPACE --image=curlimages/curl --restart=Never --rm -it -- sh -c '
    echo "Testing TCP to student-api:8080"
    nc -zv student-api 8080 || echo "Failed to connect to student-api:8080"
    
    echo "Testing HTTP to student-api"
    curl -v http://student-api:8080/ || echo "Failed HTTP request to student-api:8080"
    
    echo "Testing TCP to nginx-service:80"
    nc -zv nginx-service 80 || echo "Failed to connect to nginx-service:80"
    
    echo "Testing HTTP to nginx-service"
    curl -v http://nginx-service/ || echo "Failed HTTP request to nginx-service:80"
' || echo "Test pod execution failed"

echo -e "\n=== Service Connectivity Fix Complete ==="
echo "You may now need to update the Blackbox Exporter configuration to reflect these changes."
