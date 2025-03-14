#!/bin/bash

set -e

echo "=== Database Cleanup Script ==="

# Function to cleanup Docker Compose database
cleanup_docker_db() {
    echo "Cleaning up Docker Compose database..."
    if ! docker-compose ps | grep -q "db.*running"; then
        echo "❌ Docker Compose database is not running"
        return 1
    fi
    docker-compose exec -T db psql -U postgres -d student_api -c "DELETE FROM students;"
    echo "✅ Docker Compose database cleaned"
}

# Function to find postgres namespaces
find_postgres_namespaces() {
    echo "Searching for postgres pods in all namespaces..."
    kubectl get pods --all-namespaces -l app=postgres 2>/dev/null | grep -v "NAMESPACE"
    if [ $? -ne 0 ]; then
        echo "No postgres pods found in any namespace"
        return 1
    fi
}

# Function to cleanup Kubernetes database
cleanup_k8s_db() {
    echo "Cleaning up Kubernetes database..."
    
    echo -e "\nAvailable namespaces with postgres pods:"
    find_postgres_namespaces
    
    # Get namespace from user
    read -p "Enter namespace from the list above: " NAMESPACE
    NAMESPACE=${NAMESPACE:-default}
    
    # Check if namespace exists
    if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
        echo "❌ Namespace $NAMESPACE not found"
        return 1
    fi
    
    # Get postgres pod name with namespace
    POSTGRES_POD=$(kubectl get pod -n "$NAMESPACE" -l app=postgres --field-selector status.phase=Running -o jsonpath="{.items[*].metadata.name}" | cut -d' ' -f1)
    if [ -z "$POSTGRES_POD" ]; then
        echo "❌ No running postgres pod found in namespace $NAMESPACE"
        return 1
    fi
    
    # Execute cleanup command
    kubectl exec -i "$POSTGRES_POD" -n "$NAMESPACE" -- psql -U postgres -d student_api -c "DELETE FROM students;"
    echo "✅ Kubernetes database cleaned"
}

# Main menu
echo "Choose environment to clean:"
echo "1. Docker Compose"
echo "2. Kubernetes"
echo "3. Both"
read -p "Select option (1-3): " OPTION

case $OPTION in
    1)
        cleanup_docker_db
        ;;
    2)
        cleanup_k8s_db
        ;;
    3)
        cleanup_docker_db
        echo -e "\nProceeding with Kubernetes cleanup..."
        cleanup_k8s_db
        ;;
    *)
        echo "Invalid option"
        exit 1
        ;;
esac

echo "Database cleanup completed!"
