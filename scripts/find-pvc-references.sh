#!/bin/bash

echo "=== Searching for all 'postgres-pvc' references ==="

echo "1. Searching in template files..."
grep -r "postgres-pvc" ./helm-charts/student-api-helm/templates/

echo -e "\n2. Rendering all templates for inspection..."
helm template test-release ./helm-charts/student-api-helm > /tmp/all-templates.yaml

echo -e "\n3. Checking rendered templates..."
grep -n "postgres-pvc" /tmp/all-templates.yaml

echo -e "\n=== Search Complete ==="
