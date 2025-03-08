#!/bin/bash
# Script to fix permissions for all executable files in the project

echo "Fixing permissions for all scripts in the project..."

# Fix permissions for scripts in scripts directory
echo "Setting permissions for scripts/*.sh"
find "$(dirname "$0")" -name "*.sh" -exec chmod +x {} \;

# Fix permissions for scripts in helm-charts directory
echo "Setting permissions for helm-charts/*/*.sh"
find "$(dirname "$0")/../helm-charts" -name "*.sh" -exec chmod +x {} \;

# Fix permissions for scripts in argocd directory
echo "Setting permissions for argocd/*.sh"
find "$(dirname "$0")/../argocd" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

echo "All script permissions fixed."
