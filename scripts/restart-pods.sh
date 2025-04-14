#!/bin/bash

NAMESPACE="student-api"

echo "Forcing restart of deployments..."

# Delete pods to force restart
kubectl delete pod -n $NAMESPACE -l app=student-api --force --grace-period=0
kubectl delete pod -n $NAMESPACE -l app=nginx --force --grace-period=0
kubectl delete pod -n $NAMESPACE -l app=postgres --force --grace-period=0
kubectl delete pod -n $NAMESPACE -l app=blackbox-exporter --force --grace-period=0

# Delete the debug pod if it exists
kubectl delete pod -n $NAMESPACE debug-pod --ignore-not-found=true

echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=student-api -n $NAMESPACE --timeout=120s
kubectl wait --for=condition=ready pod -l app=nginx -n $NAMESPACE --timeout=120s
kubectl wait --for=condition=ready pod -l app=postgres -n $NAMESPACE --timeout=120s
kubectl wait --for=condition=ready pod -l app=blackbox-exporter -n $NAMESPACE --timeout=120s

echo "Current pod status:"
kubectl get pods -n $NAMESPACE
