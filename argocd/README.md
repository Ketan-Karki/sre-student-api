# ArgoCD Configuration for Student API

This directory contains the ArgoCD configuration for deploying the Student API application using GitOps principles.

## Prerequisites

1. A Kubernetes cluster with ArgoCD installed
2. Access to the GitHub repository
3. Proper permissions to deploy applications in the cluster

## Setup Instructions

### 1. Install ArgoCD (if not already installed)

```bash
# Create ArgoCD namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Access ArgoCD UI (Port forwarding)
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

### 2. Configure GitHub Repository Access

If your repository is private, you'll need to configure ArgoCD to access it:

```bash
# Create a secret with your GitHub credentials
kubectl create secret generic github-repo-creds \
  --namespace argocd \
  --from-literal=username=YOUR_GITHUB_USERNAME \
  --from-literal=password=YOUR_GITHUB_TOKEN

# Add the repository to ArgoCD
argocd repo add https://github.com/Ketan-Karki/student-api.git \
  --username YOUR_GITHUB_USERNAME \
  --password YOUR_GITHUB_TOKEN
```

### 3. Deploy the Application

```bash
# Apply the ArgoCD Application manifest
kubectl apply -f application.yaml
```

## How It Works

1. When code is pushed to the main/master branch, the GitHub Actions workflow builds and pushes a new container image.
2. After successful image build, a second workflow updates the Helm chart's values.yaml with the new image tag.
3. ArgoCD detects the change in the Git repository and automatically syncs the application with the new configuration.
4. The application is deployed with the latest version of the code.

## Monitoring Deployments

You can monitor the deployment status through the ArgoCD UI or using the ArgoCD CLI:

```bash
# Check application status
argocd app get student-api

# Sync application manually (if needed)
argocd app sync student-api
```

## Troubleshooting

If the application fails to sync:

1. Check the ArgoCD UI for error messages
2. Verify that the GitHub repository is accessible
3. Check that the Helm chart is valid
4. Ensure the Kubernetes cluster has the necessary resources
