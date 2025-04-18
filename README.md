# Student API

## SRE Bootcamp - CI/CD and GitOps Implementation

This repository contains a Student API application with complete CI/CD pipeline and GitOps implementation using ArgoCD.

## Application Components

- REST API for managing student records
- PostgreSQL database for persistent storage
- Kubernetes deployment configurations
- Helm charts for deployment
- ArgoCD configuration for GitOps

## Purpose of the Repository

This repository contains the source code for the Student API, a RESTful API designed to manage student records. The API is built using Go and the Gin framework, providing a robust and scalable solution for student data management.

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

#### Prometheus Architecture

Our monitoring implementation follows the standard Prometheus architecture:

![Prometheus Architecture](https://prometheus.io/assets/architecture.png)

**Components implemented:**

- Prometheus Server - Scrapes and stores metrics from the Student API
- Exporters - Including Blackbox exporter for endpoint monitoring
- Grafana - For visualization and dashboarding
- AlertManager - For handling and routing alerts

**Key features utilized:**

- Service discovery for Kubernetes pods using annotations
- Multi-dimensional data model with proper labeling
- Time series metrics collection via HTTP pull model
- Dashboards for visualizing application performance

**Metrics collected:**

- Application uptime and availability
- HTTP request counts, latencies, and error rates
- Database connection metrics
- System metrics (CPU, memory, disk usage)

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

**Creating Custom Grafana Dashboards:**

While a pre-configured dashboard is deployed automatically, you can create your own dashboards:

1. Access the Grafana UI at http://localhost:3000 (after port forwarding)
2. Log in with admin/admin (and change the password if prompted)
3. Click on "+ Create" in the left sidebar and select "Dashboard"
4. Click "Add visualization" and select your data source:
   - Choose "Prometheus" for metrics data
   - Choose "Loki" for log data
5. For Prometheus metrics, try these queries:
   - Application uptime: `up{namespace="student-api"}`
   - HTTP request rate: `sum(rate(http_request_duration_seconds_count{namespace="student-api"}[5m])) by (path)`
   - Request duration (p95): `histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{namespace="student-api"}[5m])) by (le, path))`
6. For Loki logs, try:
   - All logs: `{namespace="student-api"}`
   - Error logs: `{namespace="student-api"} |= "error" | json`
7. Save your dashboard with a descriptive name

For more information on building dashboards, see [Grafana Dashboard Documentation](https://grafana.com/docs/grafana/latest/dashboards/).

**Testing your logging setup:**

```bash
# Verify Loki is collecting logs
./scripts/test-observability.sh

# Generate some log entries
kubectl exec -n student-api $(kubectl get pods -n student-api -l app.kubernetes.io/name=student-api -o name | head -1) -- curl -s http://localhost/api/v1/students
```

For more information on using Loki, see [Grafana Loki Documentation](https://grafana.com/docs/loki/latest/).

## CI/CD Pipeline

This project uses GitHub Actions for continuous integration and deployment. The pipeline automatically builds and pushes Docker images to GitHub Container Registry (GHCR) when:

- Changes are pushed to main/master branch
- A new tag is created (v\*)
- A pull request is opened against main/master branch

### Docker Image Tags

The pipeline generates several types of tags for the Docker image:

- Branch name (e.g., `main`, `feature-branch`)
- Git commit SHA
- Semantic version tags when a version tag is pushed (e.g., `v1.0.0`, `v1.0`, `v1`)

### Accessing the Docker Image

To pull the Docker image from GHCR:

```bash
docker pull ghcr.io/OWNER/REPO_NAME:tag
```

Replace `OWNER/REPO_NAME` with your GitHub username and repository name.

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
- `/helm-charts`: Helm charts for deployment
- `/k8s`: Kubernetes manifests
- `/scripts`: Testing and utility scripts
- `/src`: Application source code

### Contribution Guidelines

I welcome contributions to enhance the Student API. Please fork the repository and submit a pull request with your changes. Ensure your code adheres to the project's coding standards and includes appropriate tests.

## License

This project is licensed under the MIT License.

## Contact

For any questions or support, please contact the project maintainer at [ketankarki2626@gmail.com].
