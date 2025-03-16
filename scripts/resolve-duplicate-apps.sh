#!/bin/bash

set -e

echo "=== Resolving Duplicate ArgoCD Applications ==="

# List all applications
echo "Current applications in ArgoCD:"
kubectl get applications -n argocd

# Check for ApplicationSet
echo -e "\nChecking for ApplicationSets:"
if kubectl get applicationset -n argocd student-api-appset 2>/dev/null; then
    echo -e "\nApplicationSet 'student-api-appset' found. This is likely generating multiple applications."
    echo "Current ApplicationSet configuration:"
    kubectl get applicationset -n argocd student-api-appset -o yaml | grep -A 20 "spec:"
else
    echo "No ApplicationSet named 'student-api-appset' found."
    
    # Check for any other ApplicationSets
    OTHER_APPSETS=$(kubectl get applicationset -n argocd -o name 2>/dev/null)
    if [ ! -z "$OTHER_APPSETS" ]; then
        echo -e "\nOther ApplicationSets found:"
        echo "$OTHER_APPSETS"
    else
        echo "No ApplicationSets found at all."
    fi
fi

# Find all application definition files
echo -e "\nAll application definitions in the repository:"
find /Users/ketan/Learning/sre-bootcamp-rest-api -name "*.yaml" -exec grep -l "kind: Application\|kind: ApplicationSet" {} \; | sort

echo -e "\n=== RECOMMENDED SOLUTION ==="
echo "Option 1: Keep only the single application approach (recommended if you're just starting):"
echo "1. Delete the environment-specific applications:"
echo "   kubectl delete application -n argocd student-api-dev"
echo "   kubectl delete application -n argocd student-api-prod"
echo ""
echo "2. Delete the ApplicationSet if it exists:"
echo "   kubectl delete applicationset -n argocd student-api-appset"
echo ""
echo "3. Apply your single application manifest:"
echo "   kubectl apply -f /Users/ketan/Learning/sre-bootcamp-rest-api/argocd/application.yaml"
echo ""
echo "Option 2: Switch to using only the ApplicationSet for multi-environment deployment:"
echo "1. Delete the single application:"
echo "   kubectl delete application -n argocd student-api"
echo ""
echo "2. Update your ApplicationSet configuration if needed"
echo ""
echo "Which option would you like to proceed with? (Enter 1 or 2)"
read -p "> " option

if [ "$option" = "1" ]; then
    echo -e "\nExecuting Option 1: Keeping single application approach..."
    echo "Deleting environment-specific applications..."
    kubectl delete application -n argocd student-api-dev || echo "student-api-dev already deleted"
    kubectl delete application -n argocd student-api-prod || echo "student-api-prod already deleted"
    
    echo "Deleting ApplicationSet if it exists..."
    kubectl delete applicationset -n argocd student-api-appset 2>/dev/null || echo "No ApplicationSet to delete"
    
    echo "Applying single application manifest..."
    kubectl apply -f /Users/ketan/Learning/sre-bootcamp-rest-api/argocd/application.yaml
    
    echo -e "\nVerifying cleanup..."
    kubectl get applications -n argocd
elif [ "$option" = "2" ]; then
    echo -e "\nExecuting Option 2: Using ApplicationSet for multi-environment deployment..."
    echo "Deleting single application..."
    kubectl delete application -n argocd student-api || echo "student-api already deleted"
    
    if ! kubectl get applicationset -n argocd student-api-appset 2>/dev/null; then
        echo "No ApplicationSet found. You'll need to create one."
        echo "Example template has been saved to /Users/ketan/Learning/sre-bootcamp-rest-api/argocd/applicationset.yaml"
        
        # Create example ApplicationSet file
        cat > /Users/ketan/Learning/sre-bootcamp-rest-api/argocd/applicationset.yaml << EOF
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: student-api-appset
  namespace: argocd
spec:
  generators:
  - list:
      elements:
      - env: dev
        namespace: dev-student-api
      - env: prod
        namespace: prod-student-api
  template:
    metadata:
      name: student-api-{{env}}
      namespace: argocd
    spec:
      project: default
      source:
        repoURL: https://github.com/Ketan-Karki/sre-student-api
        targetRevision: HEAD
        path: helm-charts/student-api-helm
        helm:
          valueFiles:
          - environments/{{env}}/values.yaml
      destination:
        server: https://kubernetes.default.svc
        namespace: {{namespace}}
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
        - CreateNamespace=true
EOF
        
        echo "Apply it with: kubectl apply -f /Users/ketan/Learning/sre-bootcamp-rest-api/argocd/applicationset.yaml"
    else
        echo "ApplicationSet already exists. You might want to check its configuration and update if needed."
    fi
else
    echo "Invalid option. Please run the script again and choose 1 or 2."
fi

echo -e "\n=== Resolution process completed ==="
