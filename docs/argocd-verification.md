# ArgoCD UI Verification Guide

This guide shows you how to manually verify that ArgoCD is using Helm charts and values as the source of truth.

## Accessing the Application

1. Access the ArgoCD UI by port forwarding:

   ```bash
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   ```

2. Open your browser and navigate to: https://localhost:8080

3. Log in with your admin credentials:

   ```bash
   # Get the admin password if you haven't changed it
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
   ```

4. Click on the "student-api" application from the applications list

## Verifying Helm as the Sync Tool

1. In the application details page, look at the **SYNC POLICY** section:

   - It should show "Automated" with "Self Heal" enabled

2. Click on the **APP DETAILS** button (top right corner)

   - Under "SYNC OPTIONS," it should list all the sync options including the ones we defined
   - The "SYNC TOOL" section should indicate Helm

3. Click on the **Parameters** tab:
   - This shows all parameters extracted from your Helm values files
   - The source of these parameters should be shown as "helm"

## Verifying the Correct Values File

1. In the application details page, click on the **APP DETAILS** button

2. Navigate to the **PARAMETERS** tab

3. In the PARAMETERS tab, you should see:

   - At the top: **Values Files** showing `environments/prod/values.yaml`
   - The **PARAMETERS** section listing all parameters from your Helm chart
   - Each parameter should have:
     - Name (the parameter path like `studentApi.replicas`)
     - Value (the actual value from your values file)
     - Source (should say "helm")

4. If any parameter shows "default value" or "override", it means:

   - "default value" - Value is from the chart's default values.yaml
   - "override" - Value was explicitly set in the Application CR or command line

5. Key parameters to verify:

   - `studentApi.replicas`: Number of API pods
   - `studentApi.image.repository` and `studentApi.image.tag`: Your container image
   - `nginx.configMap.name`: Should be "nginx-config" as specified in fileParameters
   - `namespace.name`: Your target namespace

6. If you don't see the expected values:
   - Make sure you're using the correct values file path in your Application spec
   - Verify the path is relative to the chart directory
   - Check for typos in the parameter names in your values file

## Comparing Parameters with Values File

1. In the **PARAMETERS** tab, you'll see all the parameters being used

2. To compare with your values file:

   ```bash
   # View your values file content
   cat /Users/ketan/Learning/sre-bootcamp-rest-api/helm-charts/student-api-helm/environments/prod/values.yaml
   ```

3. Verify key parameters like:

   - `studentApi.replicas`: Should match what's in your values file
   - `studentApi.image.repository` and `studentApi.image.tag`
   - `nginx.configMap.name`: Should be "nginx-config" as specified in fileParameters

4. You can also see the rendered templates in the **MANIFEST** tab:
   - This shows exactly what Kubernetes resources will be created
   - Parameters from your values file should be correctly inserted into these templates

## Verifying Parameter Changes

To verify that changes to values files are detected:

1. Make a small change to the values file:

   ```bash
   # Change the replica count temporarily
   yq e '.studentApi.replicas = 3' -i /Users/ketan/Learning/sre-bootcamp-rest-api/helm-charts/student-api-helm/environments/prod/values.yaml

   # In a real scenario, commit and push this change
   git add .
   git commit -m "Test: Update replica count"
   git push
   ```

2. In ArgoCD UI, you should see:

   - The application becomes "Out of sync"
   - Clicking on the "DIFF" tab will show what changed
   - The change in replica count should be highlighted

3. After syncing, check that the changes were applied:

   ```bash
   kubectl get deployment -n student-api
   ```

4. Revert your changes after testing:

   ```bash
   # Revert to original replica count
   yq e '.studentApi.replicas = 1' -i /Users/ketan/Learning/sre-bootcamp-rest-api/helm-charts/student-api-helm/environments/prod/values.yaml

   # In a real scenario, commit and push this change
   git add .
   git commit -m "Revert: Reset replica count"
   git push
   ```

## Troubleshooting Common Issues

### Mismatch Between Values File and Actual Deployment

If you notice that your deployed resources don't match your values file:

1. **Verify ArgoCD is using the correct values file**:

   - In the ArgoCD UI, check the APP DETAILS > PARAMETERS section
   - Confirm the values file path matches what you expect

2. **Force a clean sync with replace**:

   - In ArgoCD UI, click SYNC with the "REPLACE" option enabled
   - This forces resources to be recreated with the correct values

3. **Check for fileParameters in your Application definition**:
   - These can override values from your values file
   - Review your application.yaml for any fileParameters

### Image Pull Errors

If you see `ErrImagePull` or `ImagePullBackOff` errors:

1. **Verify image existence**:

   ```bash
   # For public images
   docker pull ketan-karki/student-api:stable
   docker pull postgres:15.3
   ```

2. **Check image registry credentials**:

   ```bash
   # View existing secrets
   kubectl get secrets -n student-api
   ```

3. **Update image references** in your values file to use known good images:

   ```yaml
   studentApi:
     image:
       repository: ketan-karki/student-api
       tag: latest # Or a specific known good tag

   postgres:
     image:
       repository: postgres
       tag: 15.3-alpine # Alpine variants are smaller and often work better
   ```

4. **For local development**, consider using a local image registry or minikube's built-in docker:
   ```bash
   eval $(minikube docker-env)
   docker build -t student-api:local .
   ```
   Then update your values to use `student-api:local` with `pullPolicy: Never`

### Init Container Failures

For pods stuck in `Init:0/1` state:

1. **Check init container logs**:

   ```bash
   kubectl logs -n student-api <pod-name> -c <init-container-name>
   ```

2. **Describe the pod** for more details:
   ```bash
   kubectl describe pod -n student-api <pod-name>
   ```
