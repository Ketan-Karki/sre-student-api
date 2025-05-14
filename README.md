# Student API

## SRE Bootcamp - CI/CD, GitOps, and Monitoring Implementation

This repository contains a comprehensive Student Management System API with complete CI/CD pipeline, GitOps implementation using ArgoCD, and comprehensive monitoring using both RED and USE Methods.

## Application Components

- REST API for a complete Student Management System built with Go and Gin framework
- Role-Based Access Control (RBAC) for secure access
- PostgreSQL database for persistent storage
- Kubernetes deployment configurations with resource management
- Helm charts for deployment across multiple environments
- ArgoCD configuration for GitOps-based continuous deployment
- Comprehensive monitoring using both RED and USE Methods
- CI/CD pipeline with GitHub Actions

## Purpose of the Repository

This repository contains the source code for the Student Management System API, a RESTful API designed to manage student records, attendance, grades, assignments, and parent-teacher communication. The API is built using Go and the Gin framework, providing a robust and scalable solution for school management services. The system implements role-based access control to ensure appropriate permissions for faculty, staff, and parents.

## API Endpoints

The Student Management System API provides the following endpoints:

### Authentication

- `POST /api/v1/auth/register` - Register a new user
- `POST /api/v1/auth/login` - Authenticate and receive a token

### Students

- `GET /api/v1/students` - Get all students (faculty, staff, parents)
- `GET /api/v1/students/:id` - Get student by ID (faculty, staff, parents)
- `POST /api/v1/students` - Create a new student (faculty, staff only)
- `PUT /api/v1/students/:id` - Update student information (faculty, staff only)
- `DELETE /api/v1/students/:id` - Delete a student (faculty, staff only)

### Users

- `GET /api/v1/users` - Get all users (faculty, staff only)
- `GET /api/v1/users/:id` - Get user by ID (faculty, staff only)
- `PUT /api/v1/users/:id` - Update user information (faculty, staff only)
- `DELETE /api/v1/users/:id` - Delete a user (staff only)

### Attendance

- `POST /api/v1/attendance` - Record attendance (faculty, staff only)
- `GET /api/v1/attendance/:id` - Get attendance record by ID (faculty, staff only)
- `PUT /api/v1/attendance/:id` - Update attendance record (faculty, staff only)
- `GET /api/v1/attendance/student/:studentId` - Get all attendance records for a student (faculty, staff only)
- `GET /api/v1/attendance/date-range` - Get attendance records within a date range (faculty, staff only)

### Assignments

- `GET /api/v1/assignments` - Get all assignments (faculty, staff, parents)
- `GET /api/v1/assignments/:id` - Get assignment by ID (faculty, staff, parents)
- `POST /api/v1/assignments` - Create a new assignment (faculty only)
- `PUT /api/v1/assignments/:id` - Update assignment information (faculty only)
- `DELETE /api/v1/assignments/:id` - Delete an assignment (faculty only)

### Grades

- `GET /api/v1/grades/:id` - Get grade by ID (faculty, staff, parents)
- `POST /api/v1/grades` - Create a grade for an assignment (faculty only)
- `PUT /api/v1/grades/:id` - Update a grade (faculty only)
- `GET /api/v1/grades/student/:studentId` - Get all grades for a student (faculty, staff, parents)
- `GET /api/v1/grades/assignment/:assignmentId` - Get all grades for an assignment (faculty only)

### Parent-Teacher Communication

- `POST /api/v1/forum/posts` - Create a new forum post (faculty, staff, parents)
- `GET /api/v1/forum/posts/:id` - Get forum post by ID with its comments (faculty, staff, parents)
- `PUT /api/v1/forum/posts/:id` - Update a forum post (post author only)
- `DELETE /api/v1/forum/posts/:id` - Delete a forum post (post author, staff, or faculty)
- `GET /api/v1/forum/posts/student/:studentId` - Get all forum posts for a student (faculty, staff, parents)
- `POST /api/v1/forum/comments` - Create a comment on a forum post (faculty, staff, parents)
- `PUT /api/v1/forum/comments/:id` - Update a comment (comment author only)
- `GET /api/v1/forum/posts/:postId/comments` - Get all comments for a forum post (faculty, staff, parents)

### Reports

- `GET /api/v1/reports/attendance` - Generate attendance report (faculty, staff only)
- `GET /api/v1/reports/grades` - Generate grades report (faculty, staff only)
- `GET /api/v1/reports/student/:studentId` - Generate comprehensive student activity report (faculty, staff only)
- `GET /api/v1/reports/student/:studentId/parent` - Generate student activity report for parents (parent access only)

### System

- `GET /api/v1/healthcheck` - Check system health (public endpoint)

## Local Setup Instructions

To set up the project locally, follow these steps:

1. **Clone the repository:**

   ```bash
   git clone https://github.com/ketan-karki/sre-student-api.git
   cd student-api
   ```

2. **Install Go:**
   Ensure you have Go installed on your machine. You can download it from [the official Go website](https://golang.org/dl/).

3. **Install dependencies:**
   Navigate to the project directory and run the following command to install the necessary dependencies:

   ```bash
   go mod tidy
   ```

4. **Run the application:**
   To start the API server, use the following command:

   ```bash
   go run main.go
   ```

5. **Access the API:**
   The API will be running at `http://localhost:8080`. You can use tools like Postman or curl to interact with the endpoints.

## API Endpoints

- `GET /students`: Retrieve a list of students.
- `POST /students`: Create a new student record.
- `GET /students/:id`: Retrieve a specific student by ID.
- `PUT /students/:id`: Update a student's information.
- `DELETE /students/:id`: Delete a student record.

## Docker Instructions

## Prerequisites

- Ensure that you have Docker installed on your machine.
- Ensure that you have Make installed on your machine.

## Make Targets

To manage and run the application using Make, you can use the following targets:

- **build**: Build the Docker image for the application.

  ```bash
  make build
  ```

- **network**: Create a Docker network for the application.

  ```bash
  make network
  ```

- **redis-start**: Start a Redis container connected to the application network.

  ```bash
  make redis-start
  ```

- **run**: Build the application and start it along with the Redis container.

  ```bash
  make run
  ```

- **clean**: Remove the application binary, stop Redis, and remove the network.

  ```bash
  make clean
  ```

- **migrate**: Run database migrations.

  ```bash
  make migrate
  ```

- **docker-build**: Build the Docker image for the application.

  ```bash
  make docker-build
  ```

- **docker-run**: Start the application using Docker.

  ```bash
  make docker-run
  ```

- **up**: Use Docker Compose to build and start the application in detached mode.

  ```bash
  make up
  ```

- **down**: Stop the application and remove containers.

  ```bash
  make down
  ```

- **logs**: View logs from the running containers.

  ```bash
  make logs
  ```

- **ps**: List running containers.
  ```bash
  make ps
  ```

## Building the Docker Image

To build the Docker image, run the following command in the root of the project:

```bash
docker build -t ketan-karki/student-api .
```

## Running the Docker Container

To run the Docker container, use the following command:

```bash
docker run -d -p 8080:80 ketan-karki/student-api
```

## Kubernetes Deployment

### Prerequisites

- Kubernetes cluster (local or cloud-based)
- kubectl configured to interact with your cluster
- Helm v3 or later installed
- Access to container images (or ability to build them)
- For local development: Minikube or Docker Desktop with Kubernetes

### Deployment Options

You can deploy the Student API application using one of the following methods:

#### Option 1: Quick Deployment with Helm

```bash
# Create namespace
kubectl create namespace student-api

# Install using Helm
helm install student-api ./helm-charts/student-api-helm \
  --namespace student-api \
  --values ./helm-charts/student-api-helm/environments/prod/values.yaml
```

#### Option 2: GitOps-Based Deployment with ArgoCD

See the [ArgoCD Configuration](#argocd-configuration) section below.

#### Option 3: Step-by-Step Manual Deployment

1. **Create the namespace:**

   ```bash
   kubectl create namespace student-api
   ```

2. **Deploy PostgreSQL:**

   ```bash
   kubectl apply -f k8s/config/db-secrets.yaml
   kubectl apply -f k8s/postgres/deployment.yaml
   kubectl apply -f k8s/postgres/service.yaml
   ```

3. **Deploy the Student API:**

   ```bash
   kubectl apply -f k8s/config/app-config.yaml
   kubectl apply -f k8s/student-api/deployment.yaml
   kubectl apply -f k8s/student-api/service.yaml
   ```

4. **Deploy NGINX:**
   ```bash
   kubectl apply -f k8s/config/nginx-config.yaml
   kubectl apply -f k8s/deployments/nginx-deployment.yaml
   kubectl apply -f k8s/services/nginx-service.yaml
   ```

### Verifying Deployment

After deployment, verify that all components are running:

```bash
# Check all resources
kubectl get all -n student-api

# Verify pod status
kubectl get pods -n student-api

# Check services
kubectl get svc -n student-api
```

You can also use our verification script:

```bash
./verify-deployment.sh
```

### Accessing the Application

The application is exposed through the NGINX service:

1. **Port Forwarding (Development):**

   ```bash
   kubectl port-forward svc/nginx-service 8080:80 -n student-api
   ```

   Then access the application at: http://localhost:8080

2. **LoadBalancer (Cloud Providers):**

   ```bash
   export SERVICE_IP=$(kubectl get svc -n student-api nginx-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
   echo http://$SERVICE_IP
   ```

3. **NodePort (Minikube):**
   ```bash
   minikube service nginx-service -n student-api
   ```

### Troubleshooting

If you encounter issues with your deployment:

1. **Check pod status:**

   ```bash
   kubectl describe pod -n student-api <pod-name>
   ```

2. **View logs:**

   ```bash
   kubectl logs -n student-api <pod-name>
   ```

3. **Fix service connectivity:**

   ```bash
   ./scripts/fix-service-connectivity.sh student-api
   ```

4. **Fix database issues:**
   ```bash
   ./scripts/verify-postgres.sh student-api
   ```

### Monitoring Setup

To set up monitoring for your application:

```bash
# Deploy monitoring components
./scripts/setup-monitoring.sh

# Verify Blackbox exporter setup
./scripts/verify-blackbox.sh
```

Access Prometheus at: http://localhost:9090 (after port-forwarding)
Access Grafana at: http://localhost:3000 (after port-forwarding)

#### Monitoring Architecture

Our monitoring implementation follows the standard Prometheus architecture:

![Prometheus Architecture](https://prometheus.io/assets/architecture.png)

**Components implemented:**

- Prometheus Server - Scrapes and stores metrics from the Student API
- Exporters - Including Blackbox exporter for endpoint monitoring, Node Exporter, and Kube-State-Metrics
- Grafana - For visualization and dashboarding
- AlertManager - For handling and routing alerts
- Loki - For log aggregation and querying
- Promtail - For log collection

**Key features utilized:**

- Service discovery for Kubernetes pods using annotations
- Multi-dimensional data model with proper labeling
- Time series metrics collection via HTTP pull model
- Dashboards for visualizing application performance
- Dual monitoring methodologies: RED and USE

**Monitoring Methodologies:**

1. **RED Method (Service-Centric):**
   - Rate - Requests per second
   - Errors - Failed requests
   - Duration - Request latency

2. **USE Method (Resource-Centric):**
   - Utilization - Percentage of time the resource is busy
   - Saturation - Degree to which a resource has extra work it can't service
   - Errors - Count of error events or failures

**Metrics collected:**

- Application metrics (RED Method):
  - HTTP request rates, latencies, and error rates
  - Database connection metrics
  - Endpoint-specific performance metrics

- Resource metrics (USE Method):
  - CPU utilization, saturation, and errors
  - Memory utilization, saturation, and errors
  - Network interface utilization, saturation, and errors
  - Storage device utilization, saturation, and errors
  - Container resource utilization and saturation

**How to access Prometheus UI:**

```bash
# Port forward the Prometheus server
kubectl port-forward svc/prometheus-nodeport -n observability 9090:9090
```

**How to access Grafana dashboards:**

```bash
# Port forward the Grafana server
kubectl port-forward svc/grafana-nodeport -n observability 3000:3000
```

Default Grafana login is admin/admin

**Testing your monitoring setup:**

```bash
# Verify Prometheus is scraping targets
./scripts/test-observability.sh

# Generate test traffic
kubectl exec -n student-api $(kubectl get pods -n student-api -l app.kubernetes.io/name=student-api -o name | head -1) -- curl -s http://localhost/api/v1/students

# Test USE Method metrics collection
./scripts/verify-node-exporter.sh
./scripts/verify-kube-state-metrics.sh
```

#### Monitoring Troubleshooting Guide

This section covers troubleshooting for both RED Method (service-centric) and USE Method (resource-centric) monitoring issues.

**Service Performance Issues (RED Method)**

```bash
# Verify metrics endpoint is accessible
kubectl port-forward svc/student-api -n student-api 8080:8080
curl http://localhost:8080/metrics

# Check recent error logs
kubectl logs -n student-api -l app=student-api --tail=100

# Check database connection metrics
kubectl port-forward -n student-api pod/<postgres-pod> 9187:9187
curl http://localhost:9187/metrics | grep pg_stat_activity
```

**Resource Issues (USE Method)**

```bash
# Check Node Exporter metrics
kubectl port-forward -n observability svc/prometheus-node-exporter 9100:9100
curl http://localhost:9100/metrics

# Check Kube State Metrics
kubectl port-forward -n observability svc/kube-state-metrics 8080:8080
curl http://localhost:8080/metrics

# Diagnose high CPU/Memory usage
kubectl top nodes
kubectl top pods -n student-api
```

**Alert Troubleshooting**

```bash
# Check AlertManager configuration
kubectl get configmap -n observability prometheus-alertmanager -o yaml

# Check active alerts
kubectl port-forward -n observability svc/alertmanager 9093:9093
curl -s http://localhost:9093/api/v1/alerts | jq
```

#### Logging with Loki

The project uses Grafana Loki for log aggregation and management. Loki is designed to be cost-effective and highly scalable, focusing on logs instead of metrics.

**Loki Architecture**

![Loki Architecture](https://grafana.com/docs/loki/latest/fundamentals/architecture/loki_architecture_components.svg)

Our logging implementation follows the Loki-based logging stack:

1. **Loki Server** - The main component responsible for storing and querying logs
2. **Log Collection** - Kubernetes logs are collected and shipped to Loki
3. **Grafana** - For querying and visualizing logs using LogQL

**Key Features Implemented:**

- Efficient log storage using compressed chunks
- Label-based indexing for optimized queries
- Integration with Grafana for unified observability
- LogQL for powerful log querying capabilities

**How to access Loki logs:**

```bash
# Through Grafana (recommended)
kubectl port-forward svc/grafana-nodeport -n observability 3000:3000
# Then navigate to Explore and select Loki as the data source

# Direct Loki API access
kubectl port-forward svc/loki-nodeport -n observability 30100:3100
```

**Querying logs with LogQL:**

Basic queries to get you started with LogQL:

- View all logs from student-api: `{namespace="student-api"}`
- Filter by log level: `{namespace="student-api"} |= "ERROR"`
- Filter by container: `{namespace="student-api", container="student-api"}`

**Available Grafana Dashboards:**

The following pre-configured dashboards are available:

1. **RED Method Dashboard**
   - Service-centric view of the API performance
   - Panels for request rates, error rates, and latency
   - Breakdowns by endpoint and error type

2. **USE Method Dashboard**
   - Resource-centric view of system components
   - CPU, Memory, Network, and Disk metrics
   - Utilization, Saturation, and Error metrics for each resource

**Creating Custom Dashboards:**

You can also create your own custom dashboards:

1. Access the Grafana UI at http://localhost:3000 (after port forwarding)
2. Log in with admin/admin (and change the password if prompted)
3. Click on "+ Create" in the left sidebar and select "Dashboard"
4. Click "Add visualization" and select your data source:
   - Choose "Prometheus" for metrics data
   - Choose "Loki" for log data

5. For RED Method metrics, try these queries:
   - Application uptime: `up{namespace="student-api"}`
   - HTTP request rate: `sum(rate(http_request_duration_seconds_count{namespace="student-api"}[5m])) by (path)`
   - Request duration (p95): `histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{namespace="student-api"}[5m])) by (le, path))`

6. For USE Method metrics, try these queries:
   - CPU utilization: `100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)`
   - Memory saturation: `node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100`
   - Disk utilization: `rate(node_disk_io_time_seconds_total[5m]) * 100`
   - Network errors: `rate(node_network_transmit_errs_total[5m]) + rate(node_network_receive_errs_total[5m])`

7. For Loki logs, try:
   - All logs: `{namespace="student-api"}`
   - Error logs: `{namespace="student-api"} |= "error" | json`

8. Save your dashboard with a descriptive name

For more information on building dashboards, see [Grafana Dashboard Documentation](https://grafana.com/docs/grafana/latest/dashboards/).

**Testing your logging setup:**

## CI/CD Pipeline

This project uses GitHub Actions for continuous integration and deployment. The pipeline automatically builds and pushes Docker images to both GitHub Container Registry (GHCR) and Docker Hub when:

- Changes are pushed to main/master branch (for specific file paths)
- A new tag is created (v\*)
- A pull request is opened against main/master branch
- Weekly on Mondays (scheduled builds)
- Manual workflow dispatch

### CI/CD Workflow

1. **Build and Test:**
   - Checkout code
   - Set up Go environment
   - Build the application
   - Run tests
   - Run linting with golangci-lint

2. **Docker Image Build and Push:**
   - Build multi-architecture Docker images
   - Push to both GHCR and Docker Hub
   - Apply appropriate tags

3. **Helm Values Update:**
   - Automatic update of Helm chart values.yaml files
   - Different environments (dev/prod) are updated based on the trigger type
   - Changes are committed back to the repository

### Docker Image Tags

The pipeline generates several types of tags for the Docker image:

- Branch name (e.g., `main`, `feature-branch`)
- Git commit SHA
- Semantic version tags when a version tag is pushed (e.g., `v1.0.0`, `v1.0`, `v1`)

### Accessing the Docker Images

**From GitHub Container Registry:**
```bash
docker pull ghcr.io/ketan-karki/student-api:tag
```

**From Docker Hub:**
```bash
docker pull ketankarki/student-api:tag
```

## Testing the Application

### Local Development

```bash
# Build and run locally
make build
make up

# Run tests
make test
make test-api
```

### Kubernetes Deployment

```bash
# Deploy to Kubernetes
make k8s-deploy
make k8s-test
```

### Helm Chart Testing

```bash
# Test Helm chart deployment
make test-helm
```

### ArgoCD and GitOps Testing

This project includes comprehensive testing for ArgoCD configuration and GitOps workflows:

```bash
# Test ArgoCD configuration
make test-argocd

# Test ArgoCD notifications
make test-argocd-notifications

# Run all tests (ArgoCD + Helm)
make test-all
```

For detailed information on testing the ArgoCD and Helm components, see [ArgoCD and Helm Testing Documentation](./docs/argocd-helm-testing.md).

## ArgoCD Configuration

### Setting Up ArgoCD Server

1. **Install ArgoCD in your Kubernetes cluster:**

   ```bash
   # Create a dedicated namespace for ArgoCD
   kubectl create namespace argocd

   # Install ArgoCD components
   kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

   # Or use our setup script
   ./scripts/setup-argocd-declarative.sh
   ```

2. **Access the ArgoCD UI:**

   ```bash
   # Port forward the ArgoCD server to your local machine
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   ```

   Then access the UI at: https://localhost:8080

3. **Get the initial admin password:**

   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
   ```

   Use username: `admin` and the retrieved password to log in.

4. **Configure GitHub Repository Access:**

   ```bash
   # Using our helper script
   ./scripts/simple-repo-auth.sh
   ```

   Or manually:

   ```bash
   # Create a secret with your GitHub credentials
   kubectl create secret generic github-repo-creds \
     --namespace argocd \
     --from-literal=username=YOUR_GITHUB_USERNAME \
     --from-literal=password=YOUR_GITHUB_TOKEN
   ```

5. **Deploy the Application:**

   ```bash
   # Apply the ArgoCD Application manifest
   kubectl apply -f argocd/application.yaml
   ```

### Verifying ArgoCD Deployment

To verify that ArgoCD is properly deploying your application:

```bash
# Check the application status
kubectl get applications -n argocd

# View detailed sync status
kubectl describe application student-api -n argocd

# Run our verification script
./scripts/deployment-verify.sh
```

### Troubleshooting ArgoCD

If you encounter issues with ArgoCD:

1. **Reset ArgoCD configuration:**

   ```bash
   ./scripts/reset-argocd.sh
   ```

2. **Debug ArgoCD deployment:**

   ```bash
   ./scripts/debug-argocd-deploy.sh
   ```

3. **Fix repository authentication:**
   ```bash
   ./scripts/simple-repo-auth.sh
   ```

For more detailed ArgoCD configuration and troubleshooting, see [ArgoCD README](./argocd/README.md).

## Email Notifications Setup

To set up email notifications securely:

1. Create a directory for credentials: `mkdir -p ~/.argocd`
2. Store your email password securely: `echo "your-password-here" > ~/.argocd/email-password`
3. Set permissions: `chmod 600 ~/.argocd/email-password`
4. Run the fix-notifications script: `./scripts/fix-notifications.sh`

Alternatively, you can set the EMAIL_PASSWORD environment variable:

```
export EMAIL_PASSWORD="your-password-here"
./scripts/fix-notifications.sh
```

## Directory Structure

- `/argocd`: ArgoCD configuration files
- `/docs`: Documentation including monitoring implementation guides
- `/helm-charts`: Helm charts for deployment
   - `/observability`: Charts for Prometheus, Grafana, Loki, and other monitoring tools
   - `/student-api-helm`: Main application Helm chart
- `/k8s`: Kubernetes manifests
- `/middleware`: Application middleware
- `/models`: Database models
- `/routes`: API routes
- `/scripts`: Testing and utility scripts
- `/migrations`: Database migration files
- `/test`: Test files

### Contribution Guidelines

I welcome contributions to enhance the Student API. Please fork the repository and submit a pull request with your changes. Ensure your code adheres to the project's coding standards and includes appropriate tests.

## References

- [RED Method by Tom Wilkie](https://grafana.com/blog/2018/08/02/the-red-method-how-to-instrument-your-services/) - Service-centric monitoring methodology
- [USE Method by Brendan Gregg](https://www.brendangregg.com/usemethod.html) - Resource-centric monitoring methodology
- [Prometheus Documentation](https://prometheus.io/docs/introduction/overview/) - Time series database for metrics
- [Grafana Documentation](https://grafana.com/docs/) - Visualization and dashboarding
- [Loki Documentation](https://grafana.com/docs/loki/latest/) - Log aggregation system
- [Node Exporter Documentation](https://github.com/prometheus/node_exporter) - System metrics exporter
- [Kube State Metrics](https://github.com/kubernetes/kube-state-metrics) - Kubernetes object metrics
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/) - GitOps continuous delivery

## License

This project is licensed under the MIT License.

## Contact

For any questions or support, please contact the project maintainer at [ketankarki2626@gmail.com].
