#!/bin/bash
# Create a separate secret for ArgoCD notifications

set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <app-password>"
  echo "Example: $0 abcdefghijklmnop"
  exit 1
fi

APP_PASSWORD=$1

echo "Creating ArgoCD notifications secret with provided app password..."
kubectl -n argocd create secret generic argocd-notifications-secret \
  --from-literal=email.password=$APP_PASSWORD \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Secret created successfully."
echo "Updating the ArgoCD notifications ConfigMap to use the secret..."

# Create a temporary file to store the modified ConfigMap
TMP_FILE=$(mktemp)

# Retrieve the existing ConfigMap
kubectl -n argocd get cm argocd-notifications-cm -o yaml > $TMP_FILE

# Update the email configuration to use the secret
sed -i.bak 's/password: .*$/password: \$email-password/' $TMP_FILE

# Apply the changes
kubectl apply -f $TMP_FILE

# Clean up
rm $TMP_FILE $TMP_FILE.bak

echo "ConfigMap updated."

# Check if dependent_services node exists
if kubectl get nodes dependent_services &>/dev/null; then
  echo "The node 'dependent_services' exists. Applying required node affinity."
  # Create a temporary file for the deployment patch
  NODE_AFFINITY_PATCH=$(mktemp)

  # Create a patch to add nodeAffinity to the deployment
  cat > $NODE_AFFINITY_PATCH << EOF
spec:
  template:
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: kubernetes.io/hostname
                operator: In
                values:
                - dependent_services
EOF
else
  echo "Warning: Node 'dependent_services' not found. Applying preferred node affinity instead."
  # List available nodes for reference
  echo "Available nodes:"
  kubectl get nodes -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[-1].type,READY:.status.conditions[-1].status
  
  # Create a temporary file for the deployment patch with preferred affinity
  NODE_AFFINITY_PATCH=$(mktemp)

  # Create a patch with preferred affinity to allow scheduling anywhere but prefer worker nodes if available
  cat > $NODE_AFFINITY_PATCH << EOF
spec:
  template:
    spec:
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            preference:
              matchExpressions:
              - key: node-role.kubernetes.io/worker
                operator: Exists
EOF
fi

# Apply the node affinity patch to the deployment
echo "Adding node affinity to ArgoCD notifications controller..."
kubectl -n argocd patch deployment argocd-notifications-controller --patch "$(cat $NODE_AFFINITY_PATCH)"

# Clean up the patch file
rm $NODE_AFFINITY_PATCH

echo "Restarting ArgoCD notifications controller..."
kubectl -n argocd rollout restart deployment argocd-notifications-controller
kubectl -n argocd rollout status deployment argocd-notifications-controller

echo "Complete! Email notifications should now use the securely stored password."
