# Student API - Operations Scripts

This directory contains scripts for deploying, testing, and maintaining the Student API and PostgreSQL database.

## Available Scripts

### Setup and Installation

- `final-setup.sh`: Installs the PostgreSQL database with metrics exporter in a dedicated namespace
- `setup-monitoring.sh`: Sets up a monitoring environment for PostgreSQL
- `setup-monitoring-fixed.sh`: Fixed version that ensures proper metrics collection
- `test-with-images.sh`: Tests the deployment with specific image versions
- `clean-install.sh`: Performs a clean installation with emptyDir for storage

### Troubleshooting

- `clean-lingering-pvs.sh`: Cleans up lingering Persistent Volumes
- `clean-all-pvc.sh`: Removes all PVCs with postgres in name
- `emergency-cleanup.sh`: Emergency script to clean up everything
- `reset-helm-env.sh`: Resets the Helm environment
- `nuke-all.sh`: Nuclear option that removes everything
- `force-cleanup.sh`: Force cleanup of Kubernetes resources
- `find-pvc-references.sh`: Finds all references to "postgres-pvc" in templates

### Testing

- `test-db-metrics.sh`: Tests the PostgreSQL metrics exporter
- `verify-db-metrics.sh`: Verifies and displays PostgreSQL metrics

## Usage Examples

Test PostgreSQL metrics:

```bash
./scripts/test-db-metrics.sh <namespace>
```

Set up a new monitoring environment:

```bash
./scripts/final-setup.sh
```

View metrics from a running PostgreSQL instance:

```bash
kubectl port-forward -n <namespace> <postgres-pod> 9187:9187
curl http://localhost:9187/metrics
```

Clean up lingering resources:

```bash
./scripts/clean-lingering-pvs.sh
```
