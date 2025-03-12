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

## Helm as Source of Truth

The application is configured to use Helm charts and values files as the source of truth for GitOps:

- **Chart Structure**: The Helm chart in `helm-charts/student-api-helm` defines the application structure
- **Values Files**: Environment-specific values in `environments/[env]/values.yaml` control deployment parameters
- **Sync Configuration**: ArgoCD monitors both chart templates and values files for changes
- **Automated Sync**: Any changes to either charts or values will trigger a redeployment

### Verifying Helm Integration

To manually verify that ArgoCD is correctly using Helm charts and values as the source of truth:

1. **Access the Application UI**:

   - Open the ArgoCD UI and navigate to the student-api application

2. **Check Sync Tool**:

   - Click on "APP DETAILS" in the top right corner
   - Under "PARAMETERS" tab, verify that "Values Files" shows `environments/prod/values.yaml`
   - The source of parameters should be shown as "helm"

3. **Verify Values File Usage**:

   - In the "MANIFEST" tab, check that the generated resources use parameters from your values file
   - Key settings like `replicas`, `image.tag`, and resource limits should match your values file

4. **Test a Parameter Change**:
   - Make a change to your values file, commit and push
   - ArgoCD should detect the change and show the app as "Out of sync"
   - After syncing, verify the change was applied to your cluster

For detailed verification steps, see [ArgoCD Verification Guide](../docs/argocd-verification.md).

### Environments

Multiple deployment environments are supported via different values files:

- **Development**: `environments/dev/values.yaml`
- **Production**: `environments/prod/values.yaml`

To switch environments, modify the `valueFiles` section in the ArgoCD Application definition.

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

### Repository Authentication Errors

If you encounter errors like:

```
Unable to sync: error resolving repo revision: rpc error: code = Unknown desc = failed to list refs: authentication required
```

This means ArgoCD cannot access your GitHub repository because it's private or requires authentication. To fix this:

1. **Using the fix script**:

   ```bash
   ./scripts/fix-argocd-repo-auth.sh
   ```

   The script will guide you through adding authentication for your repository.

2. **Manual method using ArgoCD CLI**:

   ```bash
   # Login to ArgoCD
   argocd login <argocd-server> --username admin

   # Add repository credentials
   argocd repo add https://github.com/Ketan-Karki/student-api.git \
     --username YOUR_GITHUB_USERNAME \
     --password YOUR_GITHUB_TOKEN

   # Refresh application
   argocd app refresh student-api

   # Sync application
   argocd app sync student-api
   ```

3. **Manual method using kubectl**:

   ```bash
   # Create a secret with GitHub credentials
   kubectl create secret generic github-repo-creds \
     --namespace argocd \
     --from-literal=username=YOUR_GITHUB_USERNAME \
     --from-literal=password=YOUR_GITHUB_TOKEN

   # Update the application to use these credentials
   # Either edit the application manifest or use kubectl patch
   ```

For SSH authentication or more advanced repo configuration, refer to the [ArgoCD documentation](https://argo-cd.readthedocs.io/en/stable/user-guide/private-repositories/).

### Multiple Applications Appearing in ArgoCD

If you see multiple applications (`student-api`, `student-api-dev`, `student-api-prod`), you're encountering a conflict between:

1. The single Application manifest (`application.yaml`)
2. An ApplicationSet that's generating environment-specific applications

To resolve this:

```bash
# See what applications exist
kubectl get applications -n argocd

# Run the resolution script for guided cleanup
./scripts/resolve-duplicate-apps.sh
```

#### Option 1: Keep only the single application approach

This is recommended if you're just starting or want a simpler setup:

```bash
# Delete environment-specific apps
kubectl delete application -n argocd student-api-dev
kubectl delete application -n argocd student-api-prod

# Delete the ApplicationSet (if it exists)
kubectl delete applicationset -n argocd student-api-appset

# Apply your single application manifest
kubectl apply -f argocd/application.yaml
```

#### Option 2: Use only ApplicationSet for multi-environment deployment

This is more advanced but better for managing multiple environments:

```bash
# Delete the single application
kubectl delete application -n argocd student-api

# Make sure your ApplicationSet is properly configured
kubectl apply -f argocd/applicationset.yaml
```

Both approaches work with Helm charts as the source of truth, but they differ in how environment-specific configurations are managed.
