#!/bin/bash

set -e

echo "=== ArgoCD Parameters vs Helm Values Comparison ==="

# Determine project root and set paths more robustly
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
VALUES_FILE_RELATIVE="helm-charts/student-api-helm/environments/prod/values.yaml"
VALUES_FILE="$PROJECT_ROOT/$VALUES_FILE_RELATIVE"

NAMESPACE="argocd"
APP_NAME="student-api"

echo "Using values file: $VALUES_FILE"

# Check if the values file exists
if [ ! -f "$VALUES_FILE" ]; then
    echo "Error: Values file not found at $VALUES_FILE"
    echo "Current directory: $(pwd)"
    echo "Looking for possible values files:"
    find "$PROJECT_ROOT" -name "values.yaml" | grep -v "charts/"
    exit 1
fi

# Display the first few lines of the values file for debugging
echo -e "\nFirst 10 lines of values file for verification:"
head -n 10 "$VALUES_FILE"

# Full content of values file for debugging
echo -e "\nFull content of values file for verification:"
cat "$VALUES_FILE"

# Check if yq is installed
if ! command -v yq &> /dev/null; then
    echo "Error: yq command not found. Please install it with:"
    echo "  brew install yq"
    
    # Fall back to grep for basic extraction
    echo -e "\nFalling back to grep for values extraction..."
    echo "studentApi.replicas: $(grep -A 5 "studentApi:" "$VALUES_FILE" | grep "replicas:" | awk '{print $2}')"
    echo "studentApi.image.repository: $(grep -A 3 "image:" "$VALUES_FILE" | grep "repository:" | awk '{print $2}')"
    echo "studentApi.image.tag: $(grep -A 4 "image:" "$VALUES_FILE" | grep "tag:" | awk '{print $2}')"
    echo "nginx.configMap.name: $(grep -A 5 "nginx:" "$VALUES_FILE" | grep "name:" | head -n 1 | awk '{print $2}')"
    echo "namespace.name: $(grep -A 2 "namespace:" "$VALUES_FILE" | grep "name:" | awk '{print $2}' | tr -d '"')"
else
    # Detect yq version and use appropriate syntax - more robust version detection
    YQ_VERSION_OUTPUT=$(yq --version 2>&1)
    echo "YQ version info: $YQ_VERSION_OUTPUT"
    
    echo -e "\nExtracting key values from Helm values file using yq..."
    
    # Try different yq syntaxes based on common versions - more comprehensive approach
    
    # First, try yq v4 syntax
    STUDENT_API_REPLICAS=$(yq '.studentApi.replicas // "Not found"' "$VALUES_FILE" 2>/dev/null || echo "Error extracting replicas")
    STUDENT_API_IMAGE_REPO=$(yq '.studentApi.image.repository // "Not found"' "$VALUES_FILE" 2>/dev/null || echo "Error extracting repo")
    STUDENT_API_IMAGE_TAG=$(yq '.studentApi.image.tag // "Not found"' "$VALUES_FILE" 2>/dev/null || echo "Error extracting tag")
    NGINX_CONFIGMAP_NAME=$(yq '.nginx.configMap.name // "Not found"' "$VALUES_FILE" 2>/dev/null || echo "Error extracting configmap")
    NAMESPACE_NAME=$(yq '.namespace.name // "Not found"' "$VALUES_FILE" 2>/dev/null || echo "Error extracting namespace")
    
    # If any value is "Error extracting", try yq v3 syntax
    if [[ "$STUDENT_API_REPLICAS" == "Error extracting"* ]]; then
        echo "Trying yq v3 syntax..."
        STUDENT_API_REPLICAS=$(yq r "$VALUES_FILE" 'studentApi.replicas' 2>/dev/null || echo "Not found")
        STUDENT_API_IMAGE_REPO=$(yq r "$VALUES_FILE" 'studentApi.image.repository' 2>/dev/null || echo "Not found")
        STUDENT_API_IMAGE_TAG=$(yq r "$VALUES_FILE" 'studentApi.image.tag' 2>/dev/null || echo "Not found")
        NGINX_CONFIGMAP_NAME=$(yq r "$VALUES_FILE" 'nginx.configMap.name' 2>/dev/null || echo "Not found")
        NAMESPACE_NAME=$(yq r "$VALUES_FILE" 'namespace.name' 2>/dev/null || echo "Not found")
    fi
    
    echo -e "\nKey values from Helm chart ($VALUES_FILE):"
    echo "--------------------------------------------------------"
    echo "studentApi.replicas:       $STUDENT_API_REPLICAS"
    echo "studentApi.image.repository: $STUDENT_API_IMAGE_REPO"
    echo "studentApi.image.tag:      $STUDENT_API_IMAGE_TAG"
    echo "nginx.configMap.name:      $NGINX_CONFIGMAP_NAME"
    echo "namespace.name:            $NAMESPACE_NAME"
    echo "--------------------------------------------------------"
fi

echo -e "\nParameters from ArgoCD application:"
if command -v argocd &> /dev/null; then
    # For users with argocd CLI installed
    echo "Using ArgoCD CLI to fetch parameters..."
    PARAMS=$(argocd app get $APP_NAME -o json | jq '.spec.source.helm.parameters')
    if [ "$PARAMS" == "null" ] || [ -z "$PARAMS" ] || [ "$PARAMS" == "[]" ]; then
        echo "No explicit parameters found in ArgoCD Application. This is normal if using values files."
    else
        echo "$PARAMS" | jq -r '.[] | "\(.name): \(.value)"'
    fi
    
    # Show the valueFiles being used
    VALUE_FILES=$(argocd app get $APP_NAME -o json | jq -r '.spec.source.helm.valueFiles[]')
    echo -e "\nUsing Helm values files:"
    echo "$VALUE_FILES"
else
    # For users without argocd CLI
    echo "ArgoCD CLI not found. Using kubectl to extract parameters (limited info)..."
    echo "Helm configuration:"
    kubectl get application $APP_NAME -n $NAMESPACE -o jsonpath='{.spec.source.helm}' 2>/dev/null || echo "No helm configuration found"
    
    echo -e "\nValue files configured in Application:"
    kubectl get application $APP_NAME -n $NAMESPACE -o jsonpath='{.spec.source.helm.valueFiles}' 2>/dev/null || echo "No value files found"
fi

# Add a new section to check actual deployed resources
echo -e "\nChecking actual deployed resources:"
echo "1. Deployment replicas:"
kubectl get deployment -n student-api student-api -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "Deployment not found"

echo -e "\n2. Deployment image repository and tag:"
kubectl get deployment -n student-api student-api -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "Image info not found"

echo -e "\n3. ConfigMap name:"
kubectl get configmap -n student-api -o name 2>/dev/null || echo "ConfigMap not found"

echo -e "\n4. All resources in student-api namespace:"
kubectl get all -n student-api 2>/dev/null || echo "No resources found"

echo -e "\nTo verify the applied configuration:"
echo "  1. Check the PARAMETERS tab in ArgoCD UI"
echo "  2. Compare with the values above"
echo "  3. Note: The actual deployed resources may differ from values file"
echo "     if you've made direct changes without updating the values file"
echo ""
echo "=== Verification completed ==="
