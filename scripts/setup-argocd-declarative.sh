#!/bin/bash
# Script to set up ArgoCD declaratively

set -e

# Set defaults
NAMESPACE="argocd"
ROLLOUT_TIMEOUT="${ROLLOUT_TIMEOUT:-240s}"
NODE_SELECTOR_KEY="${NODE_SELECTOR_KEY:-role}"
NODE_SELECTOR="${NODE_SELECTOR:-dependent_services}"
SKIP_NODE_SELECTOR="${SKIP_NODE_SELECTOR:-false}"
SKIP_WAIT_STATEFULSET="${SKIP_WAIT_STATEFULSET:-false}"

# Get the project root directory (where this script lives)
PROJECT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

echo "Setting up ArgoCD declaratively..."

# Create namespace if it doesn't exist
kubectl get namespace $NAMESPACE >/dev/null 2>&1 || kubectl create namespace $NAMESPACE

# Install ArgoCD core components
echo "Installing ArgoCD core components..."
curl -sSL https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml | \
  kubectl apply -n $NAMESPACE -f -

# Apply node selector patch if needed
if [ "$SKIP_NODE_SELECTOR" != "true" ]; then
  echo "Setting node selector for ArgoCD components..."
  for deployment in argocd-server argocd-repo-server argocd-applicationset-controller argocd-notifications-controller; do
    echo "Setting node selector for $deployment to $NODE_SELECTOR_KEY=$NODE_SELECTOR"
    kubectl patch deployment $deployment -n $NAMESPACE --type=json \
      -p="[{\"op\": \"add\", \"path\": \"/spec/template/spec/nodeSelector\", \"value\": {\"$NODE_SELECTOR_KEY\": \"$NODE_SELECTOR\"}}]"
  done

  kubectl patch statefulset argocd-application-controller -n $NAMESPACE --type=json \
    -p="[{\"op\": \"add\", \"path\": \"/spec/template/spec/nodeSelector\", \"value\": {\"$NODE_SELECTOR_KEY\": \"$NODE_SELECTOR\"}}]"
else
  echo "Skipping node selector setup as requested..."
fi

# Apply the repository secret with actual values instead of variables
echo "Applying repository secret..."
GIT_USERNAME=${GIT_USERNAME:-""}
GIT_PASSWORD=${GIT_PASSWORD:-""}
cat "${PROJECT_ROOT}/argocd/repository-secret.yaml" | \
  sed "s/\${GIT_USERNAME}/$GIT_USERNAME/g" | \
  sed "s/\${GIT_PASSWORD}/$GIT_PASSWORD/g" | \
  kubectl apply -f -

# Apply other ArgoCD resources
echo "Applying declarative ArgoCD configurations..."
kubectl apply -k "${PROJECT_ROOT}/argocd/"

# Fix resource constraints if running in a resource-limited environment
if [ -n "$FIX_RESOURCES" ] && [ "$FIX_RESOURCES" = "true" ]; then
  echo "Applying resource constraint fixes for resource-limited environments..."
  kubectl patch statefulset argocd-application-controller -n $NAMESPACE --type=json \
    -p='[{"op":"replace","path":"/spec/template/spec/containers/0/resources/requests/cpu","value":"100m"},
          {"op":"replace","path":"/spec/template/spec/containers/0/resources/requests/memory","value":"128Mi"},
          {"op":"replace","path":"/spec/template/spec/containers/0/resources/limits/cpu","value":"300m"},
          {"op":"replace","path":"/spec/template/spec/containers/0/resources/limits/memory","value":"256Mi"}]'
fi

# Wait for ArgoCD server and repo server to be ready
echo "Waiting for critical ArgoCD components to be ready..."
kubectl rollout status deployment argocd-server -n $NAMESPACE --timeout=$ROLLOUT_TIMEOUT || echo "⚠️ Warning: argocd-server deployment rollout timed out"
kubectl rollout status deployment argocd-repo-server -n $NAMESPACE --timeout=$ROLLOUT_TIMEOUT || echo "⚠️ Warning: argocd-repo-server deployment rollout timed out"

# Wait for application controller if not skipped
if [ "$SKIP_WAIT_STATEFULSET" != "true" ]; then
  echo "Waiting for argocd-application-controller statefulset..."
  kubectl rollout status statefulset argocd-application-controller -n $NAMESPACE --timeout=$ROLLOUT_TIMEOUT || echo "⚠️ Warning: argocd-application-controller statefulset rollout timed out"
else
  echo "Skipping wait for application-controller statefulset as requested"
fi

# Restart any pods that might be in a bad state
echo "Checking for pods in Completed state that should be running..."
for deployment in argocd-notifications-controller argocd-applicationset-controller; do
  COMPLETED_PODS=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=$deployment -o jsonpath='{.items[?(@.status.phase=="Succeeded")].metadata.name}')
  if [ -n "$COMPLETED_PODS" ]; then
    echo "Restarting $deployment deployment to fix Completed pods..."
    kubectl rollout restart deployment $deployment -n $NAMESPACE
  fi
done

echo "ArgoCD setup complete!"
echo "Admin password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)"
