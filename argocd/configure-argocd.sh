#!/bin/bash
# Script to configure ArgoCD with custom settings

set -e

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Set default values and allow overrides from environment
NODE_SELECTOR=${NODE_SELECTOR:-"dependent_services"}
NODE_SELECTOR_KEY=${NODE_SELECTOR_KEY:-"role"}
NAMESPACE=${NAMESPACE:-"argocd"}
SKIP_NODE_SELECTOR=${SKIP_NODE_SELECTOR:-"false"}
SKIP_WAIT_STATEFULSET=${SKIP_WAIT_STATEFULSET:-"false"}
ROLLOUT_TIMEOUT=${ROLLOUT_TIMEOUT:-"180s"}

echo "Configuring ArgoCD with custom settings..."
echo "Target namespace: $NAMESPACE"
if [ "$SKIP_NODE_SELECTOR" = "true" ]; then
  echo "Node selector: DISABLED"
else
  echo "Node selector: $NODE_SELECTOR_KEY=$NODE_SELECTOR"
fi

# Create namespace if it doesn't exist
kubectl get namespace $NAMESPACE &>/dev/null || kubectl create namespace $NAMESPACE

# Install ArgoCD with node selector if not already installed
if ! kubectl get deployment argocd-server -n $NAMESPACE &>/dev/null; then
  echo "Installing ArgoCD in namespace $NAMESPACE..."
  
  # Get the latest ArgoCD install manifest
  curl -sL https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml > argocd-install.yaml
  
  # Add node selector to all deployments and statefulsets in the manifest if not skipped
  if [ "$SKIP_NODE_SELECTOR" != "true" ]; then
    echo "Adding node selector to deployments and statefulsets..."
    sed -i.bak -e "/kind: Deployment/,/spec:/s/spec:/spec:\n  template:\n    spec:\n      nodeSelector:\n        $NODE_SELECTOR_KEY: $NODE_SELECTOR/g" argocd-install.yaml
    sed -i.bak -e "/kind: StatefulSet/,/spec:/s/spec:/spec:\n  template:\n    spec:\n      nodeSelector:\n        $NODE_SELECTOR_KEY: $NODE_SELECTOR/g" argocd-install.yaml
  fi
  
  # Update namespace in the manifest
  sed -i.bak "s/namespace: argocd/namespace: $NAMESPACE/g" argocd-install.yaml
  
  # Apply the modified manifest
  kubectl apply -f argocd-install.yaml -n $NAMESPACE
  rm -f argocd-install.yaml.bak
else
  echo "ArgoCD already installed in namespace $NAMESPACE..."
  
  if [ "$SKIP_NODE_SELECTOR" = "true" ]; then
    echo "Removing node selector constraints..."
    for deployment in argocd-server argocd-repo-server argocd-applicationset-controller argocd-notifications-controller; do
      echo "Removing node selector for $deployment"
      kubectl patch deployment $deployment -n $NAMESPACE --type=json -p='[{"op":"remove","path":"/spec/template/spec/nodeSelector"}]' 2>/dev/null || echo "No node selector found for $deployment"
    done
    echo "Removing node selector for argocd-application-controller"
    kubectl patch statefulset argocd-application-controller -n $NAMESPACE --type=json -p='[{"op":"remove","path":"/spec/template/spec/nodeSelector"}]' 2>/dev/null || echo "No node selector found for argocd-application-controller"
  else
    echo "Updating node affinity..."
    # Update node selector on existing deployments
    for deployment in argocd-server argocd-repo-server argocd-applicationset-controller argocd-notifications-controller; do
      echo "Setting node selector for $deployment to $NODE_SELECTOR_KEY=$NODE_SELECTOR"
      kubectl patch deployment $deployment -n $NAMESPACE --type=json \
        -p="[{\"op\": \"add\", \"path\": \"/spec/template/spec/nodeSelector\", \"value\": {\"$NODE_SELECTOR_KEY\": \"$NODE_SELECTOR\"}}]"
    done
    
    # Update node selector on statefulset
    kubectl patch statefulset argocd-application-controller -n $NAMESPACE --type=json \
      -p="[{\"op\": \"add\", \"path\": \"/spec/template/spec/nodeSelector\", \"value\": {\"$NODE_SELECTOR_KEY\": \"$NODE_SELECTOR\"}}]"
  fi
fi

# Apply custom configurations
echo "Applying ArgoCD ConfigMap..."
kubectl apply -f argocd-cm.yaml -n $NAMESPACE

echo "Applying ArgoCD RBAC ConfigMap..."
kubectl apply -f argocd-rbac-cm.yaml -n $NAMESPACE

echo "Applying ArgoCD Notifications ConfigMap..."
kubectl apply -f argocd-notifications-cm.yaml -n $NAMESPACE

# Restart ArgoCD components to apply changes
echo "Restarting ArgoCD components to apply changes..."
kubectl rollout restart deployment argocd-server -n $NAMESPACE
kubectl rollout restart deployment argocd-repo-server -n $NAMESPACE
kubectl rollout restart deployment argocd-applicationset-controller -n $NAMESPACE
kubectl rollout restart deployment argocd-notifications-controller -n $NAMESPACE
kubectl rollout restart statefulset argocd-application-controller -n $NAMESPACE

# Wait for ArgoCD to be ready
echo "Waiting for ArgoCD components to be ready (timeout: $ROLLOUT_TIMEOUT)..."
echo "Waiting for argocd-server deployment..."
kubectl rollout status deployment argocd-server -n $NAMESPACE --timeout=$ROLLOUT_TIMEOUT || echo "⚠️ Warning: argocd-server deployment rollout timed out"

echo "Waiting for argocd-repo-server deployment..."
kubectl rollout status deployment argocd-repo-server -n $NAMESPACE --timeout=$ROLLOUT_TIMEOUT || echo "⚠️ Warning: argocd-repo-server deployment rollout timed out"

echo "Waiting for argocd-applicationset-controller deployment..."
kubectl rollout status deployment argocd-applicationset-controller -n $NAMESPACE --timeout=$ROLLOUT_TIMEOUT || echo "⚠️ Warning: argocd-applicationset-controller deployment rollout timed out"

echo "Waiting for argocd-notifications-controller deployment..."
kubectl rollout status deployment argocd-notifications-controller -n $NAMESPACE --timeout=$ROLLOUT_TIMEOUT || echo "⚠️ Warning: argocd-notifications-controller deployment rollout timed out"

if [ "$SKIP_WAIT_STATEFULSET" = "true" ]; then
  echo "Skipping wait for argocd-application-controller statefulset as requested"
else
  echo "Waiting for argocd-application-controller statefulset... (may take longer than deployments)"
  kubectl rollout status statefulset argocd-application-controller -n $NAMESPACE --timeout=$ROLLOUT_TIMEOUT || {
    echo "⚠️ Warning: argocd-application-controller statefulset rollout timed out"
    echo "Checking statefulset status:"
    kubectl get statefulset argocd-application-controller -n $NAMESPACE -o wide
    echo "Checking pod status:"
    kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=argocd-application-controller
    echo "Proceeding anyway, since the server components are ready"
  }
fi

# Get the admin password
echo "Getting ArgoCD admin password..."
ADMIN_PASSWORD=$(kubectl -n $NAMESPACE get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD admin password: $ADMIN_PASSWORD"

# Apply the application manifests if they don't exist
echo "Checking for existing ArgoCD applications..."
if ! kubectl get applications.argoproj.io student-api -n $NAMESPACE &>/dev/null; then
  echo "Applying ArgoCD application manifest..."
  kubectl apply -f application.yaml -n $NAMESPACE
fi

if ! kubectl get applicationsets.argoproj.io student-api-appset -n $NAMESPACE &>/dev/null; then
  echo "Applying ArgoCD ApplicationSet manifest..."
  kubectl apply -f applicationset.yaml -n $NAMESPACE
fi

# Verify deployment on correct node
if [ "$SKIP_NODE_SELECTOR" != "true" ]; then
  echo "Verifying deployment on nodes with $NODE_SELECTOR_KEY=$NODE_SELECTOR..."
  kubectl get pods -n $NAMESPACE -o wide | grep -i "$NODE_SELECTOR" || echo "⚠️  Warning: Some ArgoCD pods may not be running on nodes with $NODE_SELECTOR_KEY=$NODE_SELECTOR"
fi

echo "Setting up port forwarding to access ArgoCD UI..."
echo "To access ArgoCD UI, run: kubectl port-forward svc/argocd-server -n $NAMESPACE 8080:443"
echo "Then navigate to https://localhost:8080 in your browser"
echo "Login with username: admin and password: $ADMIN_PASSWORD"

echo "ArgoCD configuration complete!"
