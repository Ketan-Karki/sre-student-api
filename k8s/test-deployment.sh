#!/bin/bash

# Set up docker env for minikube
echo "Setting up docker environment..."
eval $(minikube docker-env)

# Build and load image
echo "Building and loading image..."
make build
minikube image load ketan-karki/student-api:1.0.0

# Add wait function
wait_for_pods() {
    echo "Waiting for pods to be ready..."
    kubectl wait --for=condition=ready pods --all -n student-api --timeout=120s
}

# 1. Create namespaces
echo "Creating namespaces..."
kubectl apply -f k8s/namespaces/namespaces.yaml

# 2. Deploy applications
echo "Deploying applications..."
kubectl apply -f k8s/student-api/deployment.yaml
kubectl apply -f k8s/postgres/deployment.yaml

# Wait for pods to be ready
wait_for_pods

# 3. Verify deployments
echo "Verifying deployments in student-api namespace..."
kubectl get deployments -n student-api

# 4. Check pods and their node assignments
echo "Checking pods and their node assignments..."
kubectl get pods -n student-api -o wide

# 5. Verify node labels
echo "Verifying node labels..."
kubectl get nodes --show-labels

# 6. Test service connectivity (assuming service is set up)
echo "Testing service connectivity..."
kubectl get svc -n student-api
