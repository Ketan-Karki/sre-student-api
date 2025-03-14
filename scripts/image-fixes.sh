#!/bin/bash

set -e

echo "=== Image Issue Resolution Tool ==="

# Variables
NAMESPACE="student-api" 
ARGOCD_NS="argocd"
APP_NAME="student-api"

# Functions
fix_image_tags() {
    echo "Updating image tags to use stable versions..."
    kubectl patch application $APP_NAME -n $ARGOCD_NS --type=merge -p '{
        "spec": {
            "source": {
                "helm": {
                    "parameters": [
                        {
                            "name": "studentApi.image.repository",
                            "value": "nginx"
                        },
                        {
                            "name": "studentApi.image.tag",
                            "value": "stable-alpine"
                        },
                        {
                            "name": "postgres.image.repository",
                            "value": "postgres"
                        },
                        {
                            "name": "postgres.image.tag",
                            "value": "15.3-alpine"
                        },
                        {
                            "name": "nginx.image.tag",
                            "value": "stable-alpine"
                        }
                    ]
                }
            }
        }
    }'
}

configure_registry_auth() {
    echo "Configuring registry authentication..."
    read -p "Docker Hub username: " DOCKER_USER
    read -s -p "Docker Hub password/token: " DOCKER_PASS
    echo ""
    
    kubectl create secret docker-registry docker-hub-secret \
        --namespace $NAMESPACE \
        --docker-server=https://index.docker.io/v1/ \
        --docker-username="$DOCKER_USER" \
        --docker-password="$DOCKER_PASS" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    echo "Updating deployments to use image pull secret..."
    kubectl get deployments -n $NAMESPACE -o name | while read deployment; do
        kubectl patch $deployment -n $NAMESPACE --type=strategic -p "{
            \"spec\": {
                \"template\": {
                    \"spec\": {
                        \"imagePullSecrets\": [{
                            \"name\": \"docker-hub-secret\"
                        }]
                    }
                }
            }
        }"
    done
}

# Main menu
while true; do
    echo -e "\nImage Fix Options:"
    echo "1. Update all images to stable versions"
    echo "2. Configure registry authentication"
    echo "3. Check image status"
    echo "4. Force pod recreation"
    echo "5. Exit"
    read -p "Select option (1-5): " OPTION

    case $OPTION in
        1)
            fix_image_tags
            echo "Image tags updated to stable versions"
            ;;
        2)
            configure_registry_auth
            echo "Registry authentication configured"
            ;;
        3)
            echo -e "\nChecking pod status..."
            kubectl get pods -n $NAMESPACE
            echo -e "\nPods with image issues:"
            kubectl get pods -n $NAMESPACE | grep -E "ImagePull|ErrImage"
            ;;
        4)
            echo "Deleting pods to force recreation..."
            kubectl get pods -n $NAMESPACE | grep -E "ImagePull|ErrImage" | awk '{print $1}' | xargs -r kubectl delete pod -n $NAMESPACE
            ;;
        5)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid option"
            ;;
    esac

    echo -e "\nDo you want to sync ArgoCD now? (y/n)"
    read -p "> " SYNC
    if [[ "$SYNC" == "y" ]]; then
        PASSWORD=$(kubectl -n $ARGOCD_NS get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
        echo "Username: admin"
        echo "Password: $PASSWORD"
        echo "Starting port-forward to ArgoCD UI..."
        echo "Press Ctrl+C when done"
        kubectl port-forward svc/argocd-server -n $ARGOCD_NS 8080:443
    fi
done
