#!/bin/bash
# Script to build and load the Docker image into Minikube

set -e

echo "Building student-api Docker image for local use..."
docker build -t student-api:latest .

# Check if using Minikube
if command -v minikube &> /dev/null; then
  echo "Loading image into Minikube..."
  minikube image load student-api:latest
  
  # Update values file to use the local image
  echo "Updating values file to use local image..."
  cat > ./helm-charts/student-api-helm/environments/dev/values.yaml << EOF
# Values for student-api chart in development environment
namespace:
  create: true
  name: dev-student-api

studentApi:
  image:
    repository: student-api
    tag: latest
    pullPolicy: Never  # Use Never for local images
  replicas: 1
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 200m
      memory: 256Mi
  service:
    type: ClusterIP
    port: 8080

postgres:
  image:
    repository: postgres
    tag: latest
    pullPolicy: IfNotPresent
  replicas: 1
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 200m
      memory: 256Mi
  database:
    name: api
    user: postgres
    password: postgres
  persistence:
    enabled: true
    size: 1Gi

nginx:
  enabled: true
  image:
    repository: nginx
    tag: latest
    pullPolicy: IfNotPresent
  replicas: 1
EOF

  echo "Local development setup complete!"
  echo "You can now run 'make test-helm' or 'make test-helm-debug'"
  
else
  echo "Minikube not found. Setting up for generic Kubernetes..."
  # Update values file to use publicly available image
  cat > ./helm-charts/student-api-helm/environments/dev/values.yaml << EOF
# Values for student-api chart in development environment
namespace:
  create: true
  name: dev-student-api

studentApi:
  image:
    repository: docker.io/bitnami/nginx
    tag: latest
    pullPolicy: Always
  replicas: 1
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 200m
      memory: 256Mi
  service:
    type: ClusterIP
    port: 8080

postgres:
  image:
    repository: postgres
    tag: latest
    pullPolicy: IfNotPresent
  replicas: 1
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 200m
      memory: 256Mi
  database:
    name: api
    user: postgres
    password: postgres
  persistence:
    enabled: true
    size: 1Gi

nginx:
  enabled: true
  image:
    repository: nginx
    tag: latest
    pullPolicy: IfNotPresent
  replicas: 1
EOF

  echo "Setup complete with publicly available image!"
  echo "You can now run 'make test-helm' or 'make test-helm-debug'"
fi
