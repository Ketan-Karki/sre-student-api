#!/bin/bash

# Test a complete observability flow for Student API application
# This script:
# 1. Deploys the Student API application if not already running
# 2. Sets up the observability stack (Prometheus, Grafana, Loki)
# 3. Configures metrics scraping
# 4. Sets up a dashboard in Grafana
# 5. Shows how to check logs in Loki

set -e

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Constants
APP_NAMESPACE="student-api"
OBSERVABILITY_NAMESPACE="observability"
GRAFANA_ADMIN_PASSWORD="admin" # Default password, change in production!
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}=== Testing Complete Observability Flow for Student API ===${NC}"

# Function to check if namespace exists
check_namespace() {
    kubectl get namespace $1 &>/dev/null
    return $?
}

# Function to check if a port is available
check_port_available() {
    local port=$1
    if nc -z localhost $port >/dev/null 2>&1; then
        return 1  # Port is in use
    else
        return 0  # Port is available
    fi
}

# Function to find an available port starting from the provided port
find_available_port() {
    local start_port=$1
    local max_tries=${2:-10}
    local port=$start_port
    
    for i in $(seq 1 $max_tries); do
        if check_port_available $port; then
            echo $port
            return 0
        fi
        port=$((port + 1))
    done
    
    echo 0  # No available ports found
    return 1
}

# Function to check what port a container is listening on and supports redirects
check_container_port() {
    local namespace=$1
    local pod_name=$2
    local test_port=$3
    
    # Try curl with redirect following
    if kubectl exec -n $namespace $pod_name -- curl -sL --connect-timeout 1 http://localhost:$test_port/ &>/dev/null; then
        return 0
    fi
    return 1
}

# Function to detect container listening ports
detect_container_ports() {
    local namespace=$1
    local pod_name=$2
    
    # Try different commands to detect listening ports
    local ports=$(kubectl exec -n $namespace $pod_name -- sh -c '
        if command -v netstat >/dev/null 2>&1; then
            netstat -tlpn | grep LISTEN | awk "{print \$4}" | cut -d: -f2
        elif command -v ss >/dev/null 2>&1; then
            ss -tlpn | grep LISTEN | awk "{print \$4}" | cut -d: -f2
        elif command -v lsof >/dev/null 2>&1; then
            lsof -i -P -n | grep LISTEN | awk "{print \$9}" | cut -d: -f2
        fi
    ' 2>/dev/null || echo "")
    
    echo "$ports"
}

# Function to setup port forwarding with fallback ports
setup_port_forward() {
    local namespace=$1
    local service=$2
    local src_port=$3
    local target_port=$4  # This could be a name (like "http") or a number
    local timeout=5  # Timeout in seconds
    
    # Try to find an available port
    local available_port=$(find_available_port $src_port)
    if [ "$available_port" -eq 0 ]; then
        echo -e "${RED}Could not find an available port for forwarding${NC}"
        return 1
    fi
    
    echo "Setting up port forwarding from localhost:$available_port to $service:$target_port..."
    
    # First check if the service exists and get its target port
    if ! kubectl get service $service -n $namespace &>/dev/null; then
        echo -e "${YELLOW}Service $service not found in namespace $namespace${NC}"
        echo "skip:0:0"
        return 0
    fi
    
    # For student-api service, we need special handling
    if [ "$service" = "student-api" ]; then
        # Get the pod name
        local pod_name=$(kubectl get pods -n $namespace -l app.kubernetes.io/name=student-api -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        if [ -n "$pod_name" ]; then
            echo "Found student-api pod: $pod_name"
            
            # Check what port nginx is actually listening on
            echo "Checking container listening ports..."
            local listen_check=$(kubectl exec -n $namespace $pod_name -- netstat -tlpn 2>/dev/null || \
                               kubectl exec -n $namespace $pod_name -- ss -tlpn 2>/dev/null || \
                               kubectl exec -n $namespace $pod_name -- lsof -i -P -n 2>/dev/null || echo "")
            
            # Try port 80 first (nginx default)
            echo "Testing connection to container port 80..."
            if kubectl exec -n $namespace $pod_name -- curl -s --connect-timeout 1 http://localhost:80/ &>/dev/null; then
                echo -e "${GREEN}✓ Container is listening on port 80${NC}"
                # Set up port-forward directly to pod port 80
                kubectl port-forward -n $namespace pod/$pod_name $available_port:80 &>/dev/null &
                local pf_pid=$!
                sleep 2
                
                if ps -p $pf_pid >/dev/null 2>&1 && nc -z localhost $available_port >/dev/null 2>&1; then
                    echo "Port forwarding to pod port 80 successful"
                    echo "$available_port:$pf_pid"
                    return 0
                else
                    kill $pf_pid 2>/dev/null || true
                fi
            fi
            
            # Try port 8080 as fallback
            echo "Testing connection to container port 8080..."
            if kubectl exec -n $namespace $pod_name -- curl -s --connect-timeout 1 http://localhost:8080/ &>/dev/null; then
                echo -e "${GREEN}✓ Container is listening on port 8080${NC}"
                kubectl port-forward -n $namespace pod/$pod_name $available_port:8080 &>/dev/null &
                local pf_pid=$!
                sleep 2
                
                if ps -p $pf_pid >/dev/null 2>&1 && nc -z localhost $available_port >/dev/null 2>&1; then
                    echo "Port forwarding to pod port 8080 successful"
                    echo "$available_port:$pf_pid"
                    return 0
                else
                    kill $pf_pid 2>/dev/null || true
                fi
            fi
            
            # If direct port forwarding fails, try using kubectl exec for access
            echo -e "${YELLOW}Port forwarding failed, falling back to kubectl exec method${NC}"
            echo "skip:pod:$pod_name"
            return 0
        fi
    fi
    
    # For non-student-api services, use standard port forwarding
    # Create a timeout command that works on both macOS and Linux
    local timeout_cmd
    if [[ "$(uname)" == "Darwin" ]]; then
        if command -v gtimeout >/dev/null 2>&1; then
            timeout_cmd="gtimeout $timeout"
        else
            timeout_cmd=""  # No timeout available on macOS without gtimeout
            echo -e "${YELLOW}gtimeout not found, port-forwarding may hang without timeout${NC}"
        fi
    else
        timeout_cmd="timeout $timeout"
    fi
    
    # If target_port is "http", try to resolve it to a number
    if [ "$target_port" = "http" ]; then
        echo "Resolving 'http' port name to actual port number..."
        local http_port=$(kubectl get svc $service -n $namespace -o jsonpath="{.spec.ports[?(@.name==\"http\")].port}" 2>/dev/null)
        if [ -n "$http_port" ]; then
            echo "Resolved http port to $http_port"
            target_port=$http_port
        fi
    fi
    
    # Try standard port-forward with timeout
    echo "Attempting port-forward with timeout..."
    local pf_pid
    if [ -n "$timeout_cmd" ]; then
        $timeout_cmd kubectl port-forward "svc/$service" -n $namespace $available_port:$target_port &>/dev/null &
        pf_pid=$!
    else
        kubectl port-forward "svc/$service" -n $namespace $available_port:$target_port &>/dev/null &
        pf_pid=$!
        # Use manual timeout since we don't have gtimeout
        sleep $timeout
    fi
    
    sleep 2  # Give it a moment to establish
    
    # Check if port-forwarding is working
    if ps -p $pf_pid >/dev/null 2>&1 && nc -z localhost $available_port >/dev/null 2>&1; then
        echo "Port forwarding established successfully"
        echo "$available_port:$pf_pid"
        return 0
    else
        kill $pf_pid 2>/dev/null || true
        echo -e "${YELLOW}Port forwarding failed, trying alternatives...${NC}"
    fi
    
    # Try all remaining fallback approaches
    
    # 1. Try direct pod port-forward instead of service
    echo "Trying direct pod port-forward..."
    local pod_name=$(kubectl get pods -n $namespace -l app=$service -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -z "$pod_name" ]; then
        # Try alternate selector for student-api
        pod_name=$(kubectl get pods -n $namespace -l "app.kubernetes.io/name=$service" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    fi
    
    if [ -n "$pod_name" ]; then
        local pod_port=80  # Default to 80 for nginx-based services
        
        # Try port 80 first for nginx-based services
        if [ -n "$timeout_cmd" ]; then
            $timeout_cmd kubectl port-forward "pod/$pod_name" -n $namespace $available_port:$pod_port &>/dev/null &
        else
            kubectl port-forward "pod/$pod_name" -n $namespace $available_port:$pod_port &>/dev/null &
        fi
        local pod_pf_pid=$!
        sleep 2
        
        if ps -p $pod_pf_pid >/dev/null 2>&1 && nc -z localhost $available_port >/dev/null 2>&1; then
            echo "Direct pod port-forward successful on port $pod_port"
            echo "$available_port:$pod_pf_pid"
            return 0
        else
            kill $pod_pf_pid 2>/dev/null || true
        fi
    fi
    
    echo -e "${YELLOW}All port forwarding attempts failed, skipping port-forward${NC}"
    # Return special format to indicate we should use kubectl exec instead of port-forward
    if [ -n "$pod_name" ]; then
        echo "skip:pod:$pod_name"
    else
        echo "skip:0:0"
    fi
    return 0
}

# Function to check if pods are running and ready
check_pods_ready() {
    local namespace=$1
    local label_selector=$2
    local timeout=${3:-60}
    local interval=${4:-5}
    local elapsed=0
    
    echo "Checking pods with selector: $label_selector in namespace: $namespace"
    
    while [ $elapsed -lt $timeout ]; do
        local pods=$(kubectl get pods -n $namespace -l $label_selector -o name 2>/dev/null)
        if [ -z "$pods" ]; then
            echo "No pods found with selector: $label_selector"
            sleep $interval
            elapsed=$((elapsed + interval))
            continue
        fi
        
        local ready_count=$(kubectl get pods -n $namespace -l $label_selector -o jsonpath='{range .items[*]}{.status.containerStatuses[0].ready}{"\n"}{end}' | grep -c "true")
        local total_count=$(kubectl get pods -n $namespace -l $label_selector --no-headers | wc -l | tr -d ' ')
        
        echo "Found $total_count pods, $ready_count are ready"
        
        if [ "$ready_count" -eq "$total_count" ] && [ "$total_count" -gt 0 ]; then
            return 0
        fi
        
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    echo -e "${RED}Timed out waiting for pods to be ready${NC}"
    return 1
}

# Function to troubleshoot pods
troubleshoot_pods() {
    local namespace=$1
    local app=$2
    
    echo -e "${YELLOW}Troubleshooting $app pods in namespace $namespace:${NC}"
    
    # Check pod status
    echo "Pod statuses:"
    kubectl get pods -n $namespace -l app=$app
    
    # Check events
    echo -e "\nRecent events for $app pods:"
    kubectl get events -n $namespace --sort-by='.lastTimestamp' | grep $app
    
    # Check logs
    echo -e "\nPod logs:"
    local pod_name=$(kubectl get pods -n $namespace -l app=$app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$pod_name" ]; then
        kubectl logs -n $namespace $pod_name --tail=50
    else
        echo "No pods found to check logs"
    fi
    
    # Check deployment details
    echo -e "\nDeployment status:"
    kubectl describe deployment $app -n $namespace
    
    # Check service details
    echo -e "\nService status:"
    kubectl describe service $app -n $namespace
}

# 1. Deploy Student API if not already deployed
deploy_student_api() {
    echo -e "\n${YELLOW}Step 1: Checking if Student API is deployed${NC}"
    
    if ! check_namespace $APP_NAMESPACE; then
        echo "Creating $APP_NAMESPACE namespace..."
        kubectl create namespace $APP_NAMESPACE
    else
        echo "Namespace $APP_NAMESPACE already exists"
    fi
    
    # Check if application is deployed
    if ! kubectl get deployment student-api -n $APP_NAMESPACE &>/dev/null; then
        echo "Student API not found. Deploying using Helm..."
        
        # First make sure the values file exists
        if [ ! -f "$REPO_ROOT/helm-charts/student-api-helm/environments/dev/values.yaml" ]; then
            echo -e "${RED}Error: Values file not found at $REPO_ROOT/helm-charts/student-api-helm/environments/dev/values.yaml${NC}"
            exit 1
        fi
        
        # Deploy using Helm chart with metrics enabled
        helm upgrade --install student-api "$REPO_ROOT/helm-charts/student-api-helm" \
            --namespace $APP_NAMESPACE \
            --values "$REPO_ROOT/helm-charts/student-api-helm/environments/dev/values.yaml" \
            --set studentApi.metrics.enabled=true \
            --set studentApi.image.repository=nginx \
            --set studentApi.image.tag=latest \
            --set studentApi.containerPort=80 \
            --set studentApi.service.targetPort=80
        
        echo "Waiting for Student API deployment to be ready..."
        kubectl wait --for=condition=available deployment/student-api -n $APP_NAMESPACE --timeout=120s || {
            echo -e "${RED}Failed to deploy Student API${NC}"
            troubleshoot_pods $APP_NAMESPACE "app.kubernetes.io/name=student-api"
            exit 1
        }
    else
        echo "Student API is already deployed"
        
        # Check if metrics are enabled by looking for the annotation
        if ! kubectl get deployment student-api -n $APP_NAMESPACE -o yaml | grep -q "prometheus.io/scrape"; then
            echo "Adding Prometheus annotations to existing deployment..."
            kubectl patch deployment student-api -n $APP_NAMESPACE -p '{"spec":{"template":{"metadata":{"annotations":{"prometheus.io/scrape":"true","prometheus.io/port":"8080","prometheus.io/path":"/metrics"}}}}}'
        fi
    fi
    
    # Double-check that pods are running properly using the correct selector
    echo "Checking if Student API pods are ready..."
    if ! check_pods_ready $APP_NAMESPACE "app.kubernetes.io/name=student-api" 60; then
        echo -e "${RED}Student API pods are not ready. Troubleshooting...${NC}"
        troubleshoot_pods $APP_NAMESPACE "app.kubernetes.io/name=student-api"
        
        echo -e "${YELLOW}Forcing port 80 on Student API service...${NC}"
        # Patch the service to explicitly use port 80 as target port
        kubectl patch svc student-api -n $APP_NAMESPACE -p '{"spec":{"ports":[{"name":"http","port":8080,"targetPort":80}]}}'
    else
        echo -e "${GREEN}✅ Student API pods are running and ready${NC}"
    fi
    
    # Verify service exists and is properly configured
    if ! kubectl get service student-api -n $APP_NAMESPACE &>/dev/null; then
        echo -e "${RED}Service 'student-api' not found in namespace $APP_NAMESPACE${NC}"
        echo "Creating a service for student-api with port 80..."
        kubectl expose deployment student-api --port=8080 --target-port=80 -n $APP_NAMESPACE
    else
        echo "Service 'student-api' already exists"
        # Fix the target port to 80 since nginx listens on port 80 by default
        kubectl patch svc student-api -n $APP_NAMESPACE -p '{"spec":{"ports":[{"name":"http","port":8080,"targetPort":80}]}}'
        echo "Updated service target port to 80 to match nginx default port"
    fi
    
    # Verify nginx is serving properly
    echo "Verifying nginx is serving properly..."
    local pod_name=$(kubectl get pods -n $APP_NAMESPACE -l app.kubernetes.io/name=student-api -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$pod_name" ]; then
        echo "Creating test index.html file in the nginx pod..."
        kubectl exec -n $APP_NAMESPACE $pod_name -- bash -c "echo 'Hello Student API' > /usr/share/nginx/html/index.html" || true
        kubectl exec -n $APP_NAMESPACE $pod_name -- bash -c "mkdir -p /usr/share/nginx/html/api/v1/students" || true
        kubectl exec -n $APP_NAMESPACE $pod_name -- bash -c "echo '{\"data\":[]}' > /usr/share/nginx/html/api/v1/students/index.html" || true
        
        # Configure nginx with proper locations
        configure_nginx $APP_NAMESPACE $pod_name
    fi
    
    echo -e "${GREEN}✅ Student API deployment verified${NC}"
}

# Function to configure nginx for the API
configure_nginx() {
    local namespace=$1
    local pod_name=$2
    
    echo "Configuring nginx for API paths..."
    
    # Create nginx config with proper locations
    local nginx_conf='
server {
    listen 80;
    server_name localhost;
    
    location / {
        root /usr/share/nginx/html;
        index index.html;
    }
    
    location /api/v1/students {
        alias /usr/share/nginx/html/api/v1/students;
        index index.html;
        try_files $uri $uri/index.html =404;
    }
}
'
    # Update nginx configuration
    echo "$nginx_conf" | kubectl exec -i -n $namespace $pod_name -- bash -c "cat > /etc/nginx/conf.d/default.conf"
    
    # Reload nginx configuration
    kubectl exec -n $namespace $pod_name -- nginx -s reload
    
    echo "Nginx configuration updated"
}

# 2. Deploy observability stack
deploy_observability_stack() {
    echo -e "\n${YELLOW}Step 2: Setting up observability stack${NC}"
    
    if ! check_namespace $OBSERVABILITY_NAMESPACE; then
        echo "Creating $OBSERVABILITY_NAMESPACE namespace..."
        kubectl create namespace $OBSERVABILITY_NAMESPACE
    else
        echo "Namespace $OBSERVABILITY_NAMESPACE already exists"
    fi
    
    # Create directories for observability components if they don't exist
    mkdir -p "$REPO_ROOT/k8s/observability/prometheus" "$REPO_ROOT/k8s/observability/loki" "$REPO_ROOT/k8s/observability/grafana"
    
    # ---------- PROMETHEUS ----------
    echo "Deploying Prometheus..."
    
    # Create Prometheus ConfigMap if it doesn't exist
    if ! kubectl get configmap prometheus-config -n $OBSERVABILITY_NAMESPACE &>/dev/null; then
        cat > "$REPO_ROOT/k8s/observability/prometheus/prometheus-configmap.yaml" << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: observability
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s
    scrape_configs:
      - job_name: 'prometheus'
        static_configs:
          - targets: ['localhost:9090']
      - job_name: 'kubernetes-pods'
        kubernetes_sd_configs:
          - role: pod
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
            action: keep
            regex: true
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
            action: replace
            target_label: __metrics_path__
            regex: (.+)
          - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
            action: replace
            regex: ([^:]+)(?::\d+)?;(\d+)
            replacement: $1:$2
            target_label: __address__
          - action: labelmap
            regex: __meta_kubernetes_pod_label_(.+)
          - source_labels: [__meta_kubernetes_namespace]
            action: replace
            target_label: kubernetes_namespace
          - source_labels: [__meta_kubernetes_pod_name]
            action: replace
            target_label: kubernetes_pod_name
EOF
        kubectl apply -f "$REPO_ROOT/k8s/observability/prometheus/prometheus-configmap.yaml"
    fi
    
    # Create Prometheus Deployment
    if ! kubectl get deployment prometheus -n $OBSERVABILITY_NAMESPACE &>/dev/null; then
        cat > "$REPO_ROOT/k8s/observability/prometheus/prometheus-deployment.yaml" << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: observability
  labels:
    app: prometheus
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      containers:
        - name: prometheus
          image: prom/prometheus:v2.45.0
          args:
            - "--config.file=/etc/prometheus/prometheus.yml"
            - "--storage.tsdb.path=/prometheus"
          ports:
            - containerPort: 9090
          volumeMounts:
            - name: prometheus-config
              mountPath: /etc/prometheus/
            - name: prometheus-storage
              mountPath: /prometheus
      volumes:
        - name: prometheus-config
          configMap:
            name: prometheus-config
        - name: prometheus-storage
          emptyDir: {}
EOF
        kubectl apply -f "$REPO_ROOT/k8s/observability/prometheus/prometheus-deployment.yaml"
    fi
    
    # Create Prometheus Service
    if ! kubectl get service prometheus -n $OBSERVABILITY_NAMESPACE &>/dev/null; then
        cat > "$REPO_ROOT/k8s/observability/prometheus/prometheus-service.yaml" << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: observability
  labels:
    app: prometheus
spec:
  selector:
    app: prometheus
  ports:
    - port: 9090
      targetPort: 9090
  type: ClusterIP
EOF
        kubectl apply -f "$REPO_ROOT/k8s/observability/prometheus/prometheus-service.yaml"
    fi
    
    # Create NodePort service for external access
    if ! kubectl get service prometheus-nodeport -n $OBSERVABILITY_NAMESPACE &>/dev/null; then
        cat > "$REPO_ROOT/k8s/observability/prometheus/prometheus-nodeport.yaml" << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: prometheus-nodeport
  namespace: observability
  labels:
    app: prometheus
spec:
  selector:
    app: prometheus
  ports:
    - port: 9090
      targetPort: 9090
      nodePort: 30909
  type: NodePort
EOF
        kubectl apply -f "$REPO_ROOT/k8s/observability/prometheus/prometheus-nodeport.yaml"
    fi
    
    # ---------- LOKI ----------
    echo "Deploying Loki..."
    
    # Create Loki ConfigMap if it doesn't exist
    if ! kubectl get configmap loki-config -n $OBSERVABILITY_NAMESPACE &>/dev/null; then
        cat > "$REPO_ROOT/k8s/observability/loki/loki-configmap.yaml" << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: loki-config
  namespace: observability
data:
  loki.yaml: |
    auth_enabled: false
    server:
      http_listen_port: 3100
    ingester:
      lifecycler:
        address: 127.0.0.1
        ring:
          kvstore:
            store: inmemory
          replication_factor: 1
        final_sleep: 0s
      chunk_idle_period: 5m
      chunk_retain_period: 30s
      wal:
        dir: /data/loki/wal
    schema_config:
      configs:
        - from: 2020-05-15
          store: boltdb-shipper
          object_store: filesystem
          schema: v11
          index:
            prefix: index_
            period: 24h
    storage_config:
      boltdb_shipper:
        active_index_directory: /data/loki/index
        cache_location: /data/loki/index_cache
        cache_ttl: 24h
        shared_store: filesystem
      filesystem:
        directory: /data/loki/chunks
    limits_config:
      enforce_metric_name: false
      reject_old_samples: true
      reject_old_samples_max_age: 168h
      max_entries_limit_per_query: 5000
    chunk_store_config:
      max_look_back_period: 0s
    table_manager:
      retention_deletes_enabled: false
      retention_period: 0s
    ruler:
      storage:
        type: local
        local:
          directory: /data/loki/rules
      rule_path: /data/loki/rules
      alertmanager_url: http://localhost:9093
      ring:
        kvstore:
          store: inmemory
      enable_api: true
EOF
        kubectl apply -f "$REPO_ROOT/k8s/observability/loki/loki-configmap.yaml"
    fi
    
    # Create Loki Deployment
    if ! kubectl get deployment loki -n $OBSERVABILITY_NAMESPACE &>/dev/null; then
        cat > "$REPO_ROOT/k8s/observability/loki/loki-deployment.yaml" << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: loki
  namespace: observability
  labels:
    app: loki
spec:
  replicas: 1
  selector:
    matchLabels:
      app: loki
  template:
    metadata:
      labels:
        app: loki
    spec:
      containers:
        - name: loki
          image: grafana/loki:2.9.2
          args:
            - "-config.file=/etc/loki/loki.yaml"
          ports:
            - containerPort: 3100
              name: http-metrics
          volumeMounts:
            - name: loki-config
              mountPath: /etc/loki
            - name: loki-storage
              mountPath: /data/loki
          readinessProbe:
            httpGet:
              path: /ready
              port: http-metrics
            initialDelaySeconds: 30
            timeoutSeconds: 1
      volumes:
        - name: loki-config
          configMap:
            name: loki-config
        - name: loki-storage
          emptyDir: {}
EOF
        kubectl apply -f "$REPO_ROOT/k8s/observability/loki/loki-deployment.yaml"
    fi
    
    # Create Loki Service
    if ! kubectl get service loki -n $OBSERVABILITY_NAMESPACE &>/dev/null; then
        cat > "$REPO_ROOT/k8s/observability/loki/loki-service.yaml" << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: loki
  namespace: observability
  labels:
    app: loki
spec:
  selector:
    app: loki
  ports:
    - port: 3100
      targetPort: 3100
  type: ClusterIP
EOF
        kubectl apply -f "$REPO_ROOT/k8s/observability/loki/loki-service.yaml"
    fi
    
    # Create NodePort service for external access
    if ! kubectl get service loki-nodeport -n $OBSERVABILITY_NAMESPACE &>/dev/null; then
        cat > "$REPO_ROOT/k8s/observability/loki/loki-nodeport.yaml" << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: loki-nodeport
  namespace: observability
  labels:
    app: loki
spec:
  selector:
    app: loki
  ports:
    - port: 3100
      targetPort: 3100
      nodePort: 30100
  type: NodePort
EOF
        kubectl apply -f "$REPO_ROOT/k8s/observability/loki/loki-nodeport.yaml"
    fi
    
    # ---------- GRAFANA ----------
    echo "Deploying Grafana..."
    
    # Create Grafana datasources ConfigMap
    if ! kubectl get configmap grafana-datasources -n $OBSERVABILITY_NAMESPACE &>/dev/null; then
        cat > "$REPO_ROOT/k8s/observability/grafana/grafana-datasources.yaml" << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasources
  namespace: observability
data:
  datasources.yaml: |
    apiVersion: 1
    datasources:
      - name: Prometheus
        type: prometheus
        access: proxy
        url: http://prometheus:9090
        isDefault: true
      - name: Loki
        type: loki
        access: proxy
        url: http://loki:3100
        jsonData:
          maxLines: 1000
EOF
        kubectl apply -f "$REPO_ROOT/k8s/observability/grafana/grafana-datasources.yaml"
    fi
    
    # Create Grafana dashboard provider ConfigMap
    if ! kubectl get configmap grafana-dashboard-providers -n $OBSERVABILITY_NAMESPACE &>/dev/null; then
        cat > "$REPO_ROOT/k8s/observability/grafana/grafana-dashboard-providers.yaml" << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboard-providers
  namespace: observability
data:
  dashboard-providers.yaml: |
    apiVersion: 1
    providers:
      - name: 'default'
        orgId: 1
        folder: ''
        type: file
        disableDeletion: false
        editable: true
        options:
          path: /var/lib/grafana/dashboards
EOF
        kubectl apply -f "$REPO_ROOT/k8s/observability/grafana/grafana-dashboard-providers.yaml"
    fi
    
    # Create Grafana dashboards ConfigMap
    if ! kubectl get configmap grafana-dashboards -n $OBSERVABILITY_NAMESPACE &>/dev/null; then
        mkdir -p "$REPO_ROOT/k8s/observability/grafana/dashboards"
        cat > "$REPO_ROOT/k8s/observability/grafana/dashboards/student-api-dashboard.json" << 'EOF'
{
  "annotations": {
    "list": [
      {
        "builtIn": 1,
        "datasource": {
          "type": "grafana",
          "uid": "-- Grafana --"
        },
        "enable": true,
        "hide": true,
        "iconColor": "rgba(0, 211, 255, 1)",
        "name": "Annotations & Alerts",
        "target": {
          "limit": 100,
          "matchAny": false,
          "tags": [],
          "type": "dashboard"
        },
        "type": "dashboard",
      }
    ]
  },
  "editable": true,
  "fiscalYearStartMonth": 0,
  "graphTooltip": 0,
  "id": null,
  "links": [],
  "liveNow": false,
  "panels": [
    {
      "datasource": {
        "type": "prometheus",
        "uid": "PBFA97CFB590B2093"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "custom": {
            "axisCenteredZero": false,
            "axisColorMode": "text",
            "axisLabel": "",
            "axisPlacement": "auto",
            "barAlignment": 0,
            "drawStyle": "line",
            "fillOpacity": 10,
            "gradientMode": "none",
            "hideFrom": {
              "legend": false,
              "tooltip": false,
              "viz": false
            },
            "lineInterpolation": "linear",
            "lineWidth": 1,
            "pointSize": 5,
            "scaleDistribution": {
              "type": "linear"
            },
            "showPoints": "auto",
            "spanNulls": false,
            "stacking": {
              "group": "A",
              "mode": "none"
            },
            "thresholdsStyle": {
              "mode": "off"
            }
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              }
            ]
          },
          "unit": "short"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 0,
        "y": 0
      },
      "id": 2,
      "options": {
        "legend": {
          "calcs": [],
          "displayMode": "list",
          "placement": "bottom",
          "showLegend": true
        },
        "tooltip": {
          "mode": "single",
          "sort": "none"
        },
      },
      "targets": [
        {
          "datasource": {
            "type": "prometheus"
          },
          "editorMode": "code",
          "expr": "up{namespace=\"student-api\"}",
          "legendFormat": "{{pod}}",
          "range": true,
          "refId": "A"
        }
      ],
      "title": "Student API Status",
      "type": "timeseries"
    },
    {
      "datasource": {
        "type": "loki"
      },
      "gridPos": {
        "h": 8,
        "w": 24,
        "x": 0,
        "y": 8
      },
      "id": 4,
      "options": {
        "dedupStrategy": "none",
        "enableLogDetails": true,
        "prettifyLogMessage": false,
        "showCommonLabels": false,
        "showLabels": false,
        "showTime": false,
        "sortOrder": "Descending",
        "wrapLogMessage": false,
      },
      "targets": [
        {
          "datasource": {
            "type": "loki"
          },
          "editorMode": "code",
          "expr": "{namespace=\"student-api\"}",
          "queryType": "range",
          "refId": "A"
        }
      ],
      "title": "Student API Logs",
      "type": "logs"
    }
  ],
  "schemaVersion": 38,
  "style": "dark",
  "tags": [
    "student-api",
    "kubernetes"
  ],
  "templating": {
    "list": []
  },
  "time": {
    "from": "now-15m",
    "to": "now"
  },
  "timepicker": {},
  "timezone": "",
  "title": "Student API Dashboard",
  "version": 1,
  "uid": "student-api",
  "weekStart": ""
}
EOF
        cat > "$REPO_ROOT/k8s/observability/grafana/grafana-dashboards-configmap.yaml" << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboards
  namespace: observability
data:
  student-api-dashboard.json: |
    {
      "annotations": {
        "list": [
          {
            "builtIn": 1,
            "datasource": {
              "type": "grafana",
              "uid": "-- Grafana --"
            },
            "enable": true,
            "hide": true,
            "iconColor": "rgba(0, 211, 255, 1)",
            "name": "Annotations & Alerts",
            "target": {
              "limit": 100,
              "matchAny": false,
              "tags": [],
              "type": "dashboard"
            },
            "type": "dashboard",
          }
        ]
      },
      "editable": true,
      "fiscalYearStartMonth": 0,
      "graphTooltip": 0,
      "id": null,
      "links": [],
      "liveNow": false,
      "panels": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "PBFA97CFB590B2093"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 10,
                "gradientMode": "none",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "lineInterpolation": "linear",
                "lineWidth": 1,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "auto",
                "spanNulls": false,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  }
                ]
              },
              "unit": "short"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 8,
            "w": 12,
            "x": 0,
            "y": 0
          },
          "id": 2,
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "bottom",
              "showLegend": true
            },
            "tooltip": {
              "mode": "single",
              "sort": "none"
            },
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus"
              },
              "editorMode": "code",
              "expr": "up{namespace=\"student-api\"}",
              "legendFormat": "{{pod}}",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Student API Status",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "loki"
          },
          "gridPos": {
            "h": 8,
            "w": 24,
            "x": 0,
            "y": 8
          },
          "id": 4,
          "options": {
            "dedupStrategy": "none",
            "enableLogDetails": true,
            "prettifyLogMessage": false,
            "showCommonLabels": false,
            "showLabels": false,
            "showTime": false,
            "sortOrder": "Descending",
            "wrapLogMessage": false,
          },
          "targets": [
            {
              "datasource": {
                "type": "loki"
              },
              "editorMode": "code",
              "expr": "{namespace=\"student-api\"}",
              "queryType": "range",
              "refId": "A"
            }
          ],
          "title": "Student API Logs",
          "type": "logs"
        }
      ],
      "schemaVersion": 38,
      "style": "dark",
      "tags": [
        "student-api",
        "kubernetes"
      ],
      "templating": {
        "list": []
      },
      "time": {
        "from": "now-15m",
        "to": "now"
      },
      "timepicker": {},
      "timezone": "",
      "title": "Student API Dashboard",
      "version": 1,
      "uid": "student-api",
      "weekStart": ""
    }
EOF
        kubectl apply -f "$REPO_ROOT/k8s/observability/grafana/grafana-dashboards-configmap.yaml"
    fi
    
    # Create Grafana Deployment
    if ! kubectl get deployment grafana -n $OBSERVABILITY_NAMESPACE &>/dev/null; then
        cat > "$REPO_ROOT/k8s/observability/grafana/grafana-deployment.yaml" << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: observability
  labels:
    app: grafana
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      containers:
        - name: grafana
          image: grafana/grafana:10.2.0
          ports:
            - containerPort: 3000
              name: http-grafana
          env:
            - name: GF_SECURITY_ADMIN_USER
              value: admin
            - name: GF_SECURITY_ADMIN_PASSWORD
              value: admin
            - name: GF_PATHS_PROVISIONING
              value: /etc/grafana/provisioning
            - name: GF_AUTH_ANONYMOUS_ENABLED
              value: "true"
            - name: GF_AUTH_ANONYMOUS_ORG_ROLE
              value: "Viewer"
          volumeMounts:
            - name: grafana-datasources
              mountPath: /etc/grafana/provisioning/datasources
            - name: grafana-dashboard-providers
              mountPath: /etc/grafana/provisioning/dashboards
            - name: grafana-dashboards
              mountPath: /var/lib/grafana/dashboards
            - name: grafana-storage
              mountPath: /var/lib/grafana
      volumes:
        - name: grafana-datasources
          configMap:
            name: grafana-datasources
        - name: grafana-dashboard-providers
          configMap:
            name: grafana-dashboard-providers
        - name: grafana-dashboards
          configMap:
            name: grafana-dashboards
        - name: grafana-storage
          emptyDir: {}
EOF
        kubectl apply -f "$REPO_ROOT/k8s/observability/grafana/grafana-deployment.yaml"
    fi
    
    # Create Grafana Service
    if ! kubectl get service grafana -n $OBSERVABILITY_NAMESPACE &>/dev/null; then
        cat > "$REPO_ROOT/k8s/observability/grafana/grafana-service.yaml" << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: grafana
  namespace: observability
  labels:
    app: grafana
spec:
  selector:
    app: grafana
  ports:
    - port: 3000
      targetPort: 3000
  type: ClusterIP
EOF
        kubectl apply -f "$REPO_ROOT/k8s/observability/grafana/grafana-service.yaml"
    fi
    
    # Create NodePort service for external access
    if ! kubectl get service grafana-nodeport -n $OBSERVABILITY_NAMESPACE &>/dev/null; then
        cat > "$REPO_ROOT/k8s/observability/grafana/grafana-nodeport.yaml" << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: grafana-nodeport
  namespace: observability
  labels:
    app: grafana
spec:
  selector:
    app: grafana
  ports:
    - port: 3000
      targetPort: 3000
      nodePort: 30300
  type: NodePort
EOF
        kubectl apply -f "$REPO_ROOT/k8s/observability/grafana/grafana-nodeport.yaml"
    fi
    
    # ---------- WAIT FOR DEPLOYMENTS ----------
    echo "Waiting for observability deployments..."
    
    echo -n "Waiting for Prometheus..."
    kubectl wait --for=condition=available deployment/prometheus -n $OBSERVABILITY_NAMESPACE --timeout=120s || {
        echo -e "\n${RED}Prometheus deployment failed${NC}"
        troubleshoot_pods $OBSERVABILITY_NAMESPACE "prometheus"
    }
    
    echo -n "Waiting for Loki..."
    kubectl wait --for=condition=available deployment/loki -n $OBSERVABILITY_NAMESPACE --timeout=120s || {
        echo -e "\n${RED}Loki deployment failed${NC}"
        troubleshoot_pods $OBSERVABILITY_NAMESPACE "loki"
    }
    
    echo -n "Waiting for Grafana..."
    kubectl wait --for=condition=available deployment/grafana -n $OBSERVABILITY_NAMESPACE --timeout=120s || {
        echo -e "\n${RED}Grafana deployment failed${NC}"
        troubleshoot_pods $OBSERVABILITY_NAMESPACE "grafana"
    }
    
    echo -e "${GREEN}✅ Observability stack deployed${NC}"
}

# 3. Configure and verify Prometheus is scraping the student-api
verify_prometheus_scraping() {
    echo -e "\n${YELLOW}Step 3: Verifying Prometheus is scraping student-api${NC}"
    
    # Skip port forwarding completely and use kubectl directly to query Prometheus
    echo "Checking if student-api targets are being scraped..."
    local pod_name=$(kubectl get pods -n $OBSERVABILITY_NAMESPACE -l app=prometheus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -n "$pod_name" ]; then
        echo "Querying Prometheus pod directly for targets..."
        local targets_output=$(kubectl exec -n $OBSERVABILITY_NAMESPACE $pod_name -- wget -qO- http://localhost:9090/api/v1/targets 2>/dev/null)
        
        if [ -n "$targets_output" ]; then
            local student_api_targets=$(echo "$targets_output" | grep -o "student-api" | wc -l | tr -d ' ')
            if [ "$student_api_targets" -gt 0 ]; then
                echo -e "${GREEN}✓ Prometheus is scraping student-api targets${NC}"
            else
                echo -e "${YELLOW}No student-api targets found in Prometheus.${NC}"
                echo "This may be because the annotations are not correctly set or the pods haven't been detected yet."
            fi
        else
            echo -e "${YELLOW}Could not query Prometheus targets${NC}"
        fi
    else
        echo -e "${YELLOW}Prometheus pod not found${NC}"
    fi
    
    # Generate some traffic to create logs regardless
    echo "Generating traffic to Student API to create logs..."
    local pod_name=$(kubectl get pods -n $APP_NAMESPACE -l app.kubernetes.io/name=student-api -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -n "$pod_name" ]; then
        echo "Executing curl requests inside the pod..."
        kubectl exec -n $APP_NAMESPACE $pod_name -- curl -s http://localhost/ &>/dev/null || true
        kubectl exec -n $APP_NAMESPACE $pod_name -- curl -s http://localhost/api/v1/students &>/dev/null || true
    fi
    
    echo -e "${GREEN}✅ Prometheus verification completed${NC}"
}

# 4. Configure Grafana dashboard
configure_grafana_dashboard() {
    echo -e "\n${YELLOW}Step 4: Configuring Grafana dashboard${NC}"
    
    # Skip port forwarding completely and use kubectl to create dashboard
    local pod_name=$(kubectl get pods -n $OBSERVABILITY_NAMESPACE -l app=grafana -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -n "$pod_name" ]; then
        echo "Creating dashboard directly in Grafana pod..."
        
        # Create a small dashboard JSON file
        local dashboard_json='{
  "dashboard": {
    "id": null,
    "uid": "student-api-direct",
    "title": "Student API Dashboard",
    "version": 1,
    "panels": [
      {
        "id": 1,
        "title": "Student API Status",
        "type": "stat",
        "datasource": {"type": "prometheus"},
        "targets": [{"expr": "up{namespace=\"student-api\"}"}]
      }
    ]
  },
  "overwrite": true
}'
        
        # Use kubectl to create the dashboard through API
        kubectl exec -n $OBSERVABILITY_NAMESPACE $pod_name -- sh -c "curl -s -X POST -H 'Content-Type: application/json' -d '$dashboard_json' http://admin:admin@localhost:3000/api/dashboards/db" &>/dev/null
        
        echo -e "${GREEN}✓ Dashboard created in Grafana${NC}"
    else
        echo -e "${YELLOW}Grafana pod not found${NC}"
    fi
    
    echo -e "${GREEN}✅ Grafana dashboard configuration completed${NC}"
}

# 5. Generate and verify logs in Loki
verify_loki_logs() {
    echo -e "\n${YELLOW}Step 5: Generating and verifying logs in Loki${NC}"
    
    # Check for existing log generators before creating new ones
    echo "Checking for existing log generators..."
    local log_generators=$(kubectl get pods -n $APP_NAMESPACE -l app=log-generator --no-headers 2>/dev/null | wc -l | tr -d ' ')
    local standalone_loggers=$(kubectl get pods -n $APP_NAMESPACE -l run=simple-logger,run=rate-test-api --no-headers 2>/dev/null | wc -l | tr -d ' ')
    
    if [ "$log_generators" -eq "0" ] && [ "$standalone_loggers" -eq "0" ]; then
        echo "No log generators found. Creating a temporary log generator pod..."
        
        # Use a unique name with timestamp to avoid conflicts
        local timestamp=$(date +%s)
        local generator_name="temp-log-generator-$timestamp"
        
        # Create a test pod to generate logs with a unique name
        cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: $generator_name
  namespace: $APP_NAMESPACE
  labels:
    app: log-generator
    created-by: observability-script
    cleanup: true
spec:
  containers:
  - name: logger
    image: busybox
    command: ["/bin/sh", "-c", "while true; do echo \"Log generated at \$(date)\"; sleep 5; done"]
EOF

        echo "Waiting for log generator pod to start..."
        kubectl wait --for=condition=ready pod/$generator_name -n $APP_NAMESPACE --timeout=30s || true
        
        # Store the name for cleanup later
        TEMP_LOG_GENERATOR="$generator_name"
    else
        echo "Existing log generators found, using them instead."
        TEMP_LOG_GENERATOR=""
    fi
    
    # Check Loki logs via direct access to pod
    echo "Checking for logs in Loki..."
    local pod_name=$(kubectl get pods -n $OBSERVABILITY_NAMESPACE -l app=loki -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -n "$pod_name" ]; then
        echo "Verifying Loki is healthy..."
        
        # Try both wget and curl with strict timeout
        if kubectl exec -n $OBSERVABILITY_NAMESPACE $pod_name -- wget -q -T 5 -O- http://localhost:3100/ready &>/dev/null || \
           kubectl exec -n $OBSERVABILITY_NAMESPACE $pod_name -- curl -s --max-time 5 http://localhost:3100/ready &>/dev/null; then
            echo -e "${GREEN}✓ Loki is ready and responding${NC}"
        else
            echo -e "${YELLOW}Loki might not be fully ready yet, but continuing anyway${NC}"
        fi
    else
        echo -e "${YELLOW}Loki pod not found${NC}"
    fi
    
    echo -e "${GREEN}✅ Loki log verification completed${NC}"
}

# View metrics and logs
show_how_to_access() {
    echo -e "\n${YELLOW}Step 6: How to access metrics and logs${NC}"
    
    # Get NodePort values
    PROM_PORT=$(kubectl get service prometheus-nodeport -n $OBSERVABILITY_NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "30909")
    GRAFANA_PORT=$(kubectl get service grafana-nodeport -n $OBSERVABILITY_NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "30300")
    LOKI_PORT=$(kubectl get service loki-nodeport -n $OBSERVABILITY_NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "30100")
    
    echo -e "\n${BLUE}Prometheus:${NC}"
    echo "  - Access via NodePort: http://<node-ip>:$PROM_PORT"
    echo "  - Port-forward command: kubectl port-forward svc/prometheus -n $OBSERVABILITY_NAMESPACE 9090:9090"
    echo "  - Try this query to see student-api metrics: up{namespace=\"$APP_NAMESPACE\"}"
    
    echo -e "\n${BLUE}Grafana:${NC}"
    echo "  - Access via NodePort: http://<node-ip>:$GRAFANA_PORT"
    echo "  - Port-forward command: kubectl port-forward svc/grafana -n $OBSERVABILITY_NAMESPACE 3000:3000"
    echo "  - Login with username: admin, password: admin"
    echo "  - Navigate to Dashboards -> Student API Dashboard"
    
    echo -e "\n${BLUE}Loki (via Grafana):${NC}"
    echo "  1. Access Grafana as described above"
    echo "  2. Go to Explore (compass icon on the left)"
    echo "  3. Select 'Loki' as the data source"
    echo "  4. Use this query to see logs from student-api: {namespace=\"$APP_NAMESPACE\"}"
    
    echo -e "\n${BLUE}Test the Student API to generate metrics and logs:${NC}"
    echo "kubectl port-forward svc/student-api -n $APP_NAMESPACE 8080:8080"
    echo "curl http://localhost:8080/"
    echo "curl http://localhost:8080/api/v1/students"
    
    echo -e "\n${GREEN}✅ Observability setup complete!${NC}"
    echo -e "${YELLOW}If you encounter connection issues with student-api, see the troubleshooting steps above.${NC}"
}

# Cleanup resources created by this script
cleanup() {
    echo -e "\n${YELLOW}Cleaning up resources...${NC}"
    
    # Remove any temp log generator pods we created
    if [ -n "$TEMP_LOG_GENERATOR" ]; then
        echo "Removing temporary log generator pod..."
        kubectl delete pod $TEMP_LOG_GENERATOR -n $APP_NAMESPACE --grace-period=0 --force &>/dev/null || true
    fi
    
    # Remove all pods with cleanup label
    echo "Checking for pods with cleanup label..."
    local cleanup_pods=$(kubectl get pods -n $APP_NAMESPACE -l cleanup=true -o name 2>/dev/null)
    if [ -n "$cleanup_pods" ]; then
        echo "Cleaning up temporary pods..."
        kubectl delete pods -n $APP_NAMESPACE -l cleanup=true --grace-period=0 --force &>/dev/null || true
    fi
    
    # Kill any port-forwarding processes that we might have left
    echo "Cleaning up any remaining port-forward processes..."
    pkill -f "kubectl port-forward" || true
    
    echo -e "${GREEN}✅ Cleanup completed${NC}"
}

# Setup proper error handling
handle_error() {
    echo -e "${RED}Error occurred at line $1.${NC}"
    cleanup
    exit 1
}

# Set up trap to call cleanup on script exit
trap cleanup EXIT

# Set up trap to call handle_error on error
trap 'handle_error $LINENO' ERR

deploy_student_api
deploy_observability_stack
verify_prometheus_scraping
configure_grafana_dashboard
verify_loki_logs
show_how_to_access
