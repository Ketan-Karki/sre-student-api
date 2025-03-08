# Gmail App Passwords for ArgoCD Notifications

## Why You Need App Passwords

After May 2022, Google no longer allows "less secure apps" to access Gmail accounts using just your regular password. Instead, you need to:

1. Enable 2-Step Verification on your Google Account
2. Generate an App Password specifically for ArgoCD

## Creating an App Password

1. Go to your [Google Account](https://myaccount.google.com/)
2. Select "Security"
3. Under "Signing in to Google," select "2-Step Verification" (You must enable this first)
4. At the bottom of the page, select "App passwords"
5. Enter a name like "ArgoCD Notifications"
6. Click "Create"
7. Google will generate a 16-character password - copy it

## Using the App Password with ArgoCD

Run our script to create the Kubernetes secret and update the ConfigMap:

```bash
./scripts/create-notifications-secret.sh YOUR_APP_PASSWORD
```

## Testing Email Delivery

Run our email test script:

```bash
./scripts/test-email-notifications.sh
```

## Troubleshooting

If emails still aren't being delivered:

1. Verify your App Password is correctly stored in the Kubernetes secret:

   ```bash
   kubectl -n argocd get secret argocd-notifications-secret -o yaml
   ```

2. Check the notifications controller logs for email-specific errors:

   ```bash
   kubectl -n argocd logs deployment/argocd-notifications-controller | grep -i "email\|smtp\|mail"
   ```

3. Try a different email address as recipient

4. Check your spam folder

5. Verify that your Gmail account doesn't have additional security settings that block this type of access
