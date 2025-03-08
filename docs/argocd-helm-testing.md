# ArgoCD and Helm Testing Documentation

This document provides instructions for testing the ArgoCD configuration and Helm chart deployment for the Student API application.

## Prerequisites

- Kubernetes cluster running
- kubectl configured
- Helm installed
- ArgoCD installed in the cluster

## Testing Components

The testing suite has several components:

1. **ArgoCD Configuration Testing**

   - Tests RBAC settings
   - Tests notifications system
   - Verifies ArgoCD applications

2. **Helm Chart Testing**

   - Tests deployment in clean namespace
   - Validates application functionality
   - Checks service endpoints

3. **Combined E2E Testing**
   - Tests ArgoCD and Helm together
   - Verifies GitOps workflow

## Running Tests

### Quick Test (Everything)

```bash
make test-all
```

### Test Only ArgoCD Configuration

```bash
make test-argocd
```

### Test Only Helm Chart Deployment

```bash
make test-helm
```

### Test Only Notifications

```bash
make test-argocd-notifications
```

## Manual Verification

### Accessing ArgoCD UI

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Then navigate to https://localhost:8080 in your browser.
Login with username: admin and the password from the secret.

### Getting ArgoCD Admin Password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Testing Discord Webhook Directly

```bash
./scripts/test-discord-webhook.sh
```

## Troubleshooting

### If Helm Chart Deployment Fails

The most common issue is existing resources. Use the clean namespace approach:

```bash
make clean-helm-namespace
make test-helm
```

#### Image Pull Issues

If you encounter `ImagePullBackOff` errors, it's likely because the Docker image is not available. You have two options:

1. Use a local image:

   ```bash
   make test-helm-local
   ```

   This will build a local Docker image and load it into Minikube before running the tests.

2. Use a public image (automatically done with `test-helm-debug`):
   ```bash
   make test-helm-debug
   ```
   This modifies the values file to use publicly available images.

For more detailed debugging when deployments aren't becoming ready:

```bash
make test-helm-debug
```

This will run an enhanced test with:

- Extended timeout (180s instead of 60s)
- Helm with debug output enabled
- Automatic deployment diagnostics if the pod doesn't become ready
- Full pod, deployment, service, and event information

You can also run the debugging script manually on any namespace:

```bash
./scripts/debug-helm-deployment.sh dev-student-api
```

### If Notifications Aren't Working

1. Check the notification controller logs:

```bash
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-notifications-controller
```

2. Verify email and Discord webhook configurations

3. Reset notification status and force a sync:

```bash
kubectl annotate application student-api -n argocd \
  notifications.argoproj.io/notified.on-sync-status-change.discord=false \
  notifications.argoproj.io/notified.on-sync-status-change.email=false \
  --overwrite
```

### Troubleshooting ArgoCD Notifications

For a more comprehensive test of notifications, use:

```bash
# Trigger notifications by forcing sync status changes
make test-notifications
```

If notifications are still not working:

1. **Check Discord webhook manually:**

   ```bash
   ./scripts/test-discord-webhook.sh
   ```

2. **Check notification controller logs:**

   ```bash
   kubectl logs -n argocd deployment/argocd-notifications-controller
   ```

3. **Verify notification configurations:**

   ```bash
   kubectl get configmap argocd-notifications-cm -n argocd -o yaml
   ```

4. **Check application subscriptions:**

   ```bash
   kubectl get application student-api -n argocd -o yaml | grep -i notification
   ```

5. **Restart notification controller:**

   ```bash
   kubectl rollout restart deployment argocd-notifications-controller -n argocd
   kubectl rollout status deployment argocd-notifications-controller -n argocd
   ```

6. **Force notification reset:**

   ```bash
   kubectl annotate application student-api -n argocd \
     notifications.argoproj.io/notified.on-sync-status-change.discord=false \
     notifications.argoproj.io/notified.on-sync-status-change.email=false \
     --overwrite
   ```

7. **Validate Discord configuration format:**
   The Discord configuration is sensitive to format changes. Ensure it follows this format:
   ```yaml
   service.discord: |
     method: POST
     url: https://discord.com/api/webhooks/your-webhook-url
     headers:
     - name: Content-Type
       value: application/json
   ```

#### Common Errors and Fixes

1. **Error: "service type 'discord' is not supported"**

   The Discord service configuration format changed in newer versions of ArgoCD (2.3+). Use:

   ```yaml
   # For ArgoCD v2.3.x+
   service.discord.webhook: |
     url: https://discord.com/api/webhooks/your-webhook-url

   # Update subscriptions to use:
   notifications.argoproj.io/subscribe.on-sync-status-change.discord: webhook
   ```

   And in templates:

   ```yaml
   discord.webhook:
     embeds:
       - title: Title
         description: Description
   ```

2. **No notifications being sent but no errors in logs**

   Try:

   ```bash
   # Restart the notifications controller
   kubectl rollout restart deployment argocd-notifications-controller -n argocd

   # Reset notification status on the application
   kubectl annotate application student-api -n argocd \
     notifications.argoproj.io/notified.on-sync-status-change.discord=false \
     --overwrite
   ```

## Successful Deployment Verification

After fixing all the issues, a successful deployment should show:

1. All pods in `Running` state with `1/1` Ready status
2. Pod logs showing:
   - Database initialization
   - API server startup
   - Successful API health check response
3. Services properly created and accessible
4. No ImagePullBackOff or other errors in events

Example of successful pod status:
