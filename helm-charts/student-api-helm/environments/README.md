# Environment Configuration

This directory contains environment-specific configurations for the Student API deployment. The following environments are supported:

- **Development (`dev/`)**: Local development environment with minimal resources
- **Staging (`staging/`)**: Pre-production environment that mirrors production
- **Production (`prod/`)**: Production environment with production-grade settings

## Environment Variables

All environments use the following environment variables, which can be set in the respective `values.yaml` files:

### Application Configuration
- `LOG_LEVEL`: Logging level (debug, info, warn, error, fatal, panic)
- `GIN_MODE`: Gin framework mode (debug, release, test)
- `PORT`: Port the application listens on

### Database Configuration
- `DB_HOST`: Database host
- `DB_PORT`: Database port
- `DB_USER`: Database username
- `DB_PASSWORD`: Database password
- `DB_NAME`: Database name
- `DB_SSLMODE`: SSL mode for database connection
- `DATABASE_URL`: Alternative to individual DB_* variables

## Deploying to Different Environments

### Development
```bash
helm upgrade --install student-api-dev . \
  --namespace dev-student-api \
  -f environments/dev/values.yaml
```

### Staging
```bash
helm upgrade --install student-api-staging . \
  --namespace staging-student-api \
  -f environments/staging/values.yaml
```

### Production
```bash
helm upgrade --install student-api-prod . \
  --namespace prod-student-api \
  -f environments/prod/values.yaml
```

## Secrets Management

For production environments, it's recommended to use a secrets manager or Kubernetes secrets instead of storing sensitive information in values files. Example:

```yaml
# values.yaml
postgres:
  database:
    passwordSecret: postgres-credentials
    passwordSecretKey: password

# Then create the secret separately:
kubectl create secret generic postgres-credentials \
  --from-literal=password=your-secure-password \
  --namespace=prod-student-api
```

## Best Practices

1. Always use the same base configuration across environments
2. Only override what's necessary in environment-specific values files
3. Use resource requests and limits consistently
4. Regularly sync staging with production configurations
5. Use tags instead of 'latest' for production deployments
6. Document all environment-specific configurations in this file
