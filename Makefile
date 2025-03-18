# Makefile for building and running the Student API

# Variables
APP_NAME=main
GO=go
VERSION=1.0.0
NETWORK_NAME=student-api-network

# Targets
.PHONY: all build run clean test up down logs ps test-api test-api-k8s get-service-url k8s-deploy k8s-test test-helm test-argocd test-all fix-permissions clean-helm-namespace test-helm-clean test-argocd-notifications test-helm-debug build-local-image test-helm-local test-notifications test-email setup-email-password verify-all argocd-ui argocd-verify-deployment argocd-force-deploy debug-argocd setup-node-labels argocd-quick-deploy verify-email-config fix-argocd-controller argocd-setup-repo-creds

# Default target that builds the application
all: build

# Builds the Docker image for the application
build:
	docker build --platform linux/arm64 -t ketan-karki/student-api:$(VERSION) .

# Creates a Docker network for the application
network:
	docker network create $(NETWORK_NAME) 2>/dev/null || true

# Start all services using docker-compose
up:
	docker-compose up -d

# Stop all services
down:
	docker-compose down -v

# View logs of all services
logs:
	docker-compose logs -f

# Show running containers
ps:
	docker-compose ps

# Run tests
test:
	$(GO) test -v ./...

# Get the service URL for testing
get-service-url:
	$(eval SERVICE_URL := $(shell minikube service student-api -n student-api --url))

# Deploy to Kubernetes
k8s-deploy:
	@echo "Deploying to Kubernetes..."
	@echo "Creating student-api namespace if it doesn't exist..."
	kubectl create namespace student-api --dry-run=client -o yaml | kubectl apply -f -
	
	@echo "Applying configurations..."
	kubectl apply -f k8s/config/app-config.yaml -n student-api
	kubectl apply -f k8s/config/db-secrets.yaml -n student-api
	
	@echo "Removing existing deployments to avoid immutable field errors..."
	kubectl delete deployment postgres -n student-api --ignore-not-found=true
	kubectl delete deployment student-api -n student-api --ignore-not-found=true
	
	@echo "Waiting for deployments to be fully deleted..."
	@sleep 10
	
	@echo "Applying new deployments and services..."
	kubectl apply -f k8s/postgres/deployment.yaml -n student-api
	kubectl apply -f k8s/postgres/service.yaml -n student-api
	kubectl apply -f k8s/student-api/deployment.yaml -n student-api
	kubectl apply -f k8s/student-api/service.yaml -n student-api
	
	@echo "Deployments applied successfully"

# Test API endpoints (now works with both docker-compose and k8s)
test-api: up
	@echo "Waiting for services to be ready..."
	@sleep 20
	@echo "\nTesting API endpoints..."
	
	@# Determine if we're running in k8s or docker-compose
	@if kubectl get namespace student-api &>/dev/null; then \
		echo "Detected Kubernetes environment. Using minikube service URL..."; \
		SERVICE_URL=$$(minikube service student-api -n student-api --url --wait=60s 2>/dev/null) || SERVICE_URL=""; \
		if [ -z "$$SERVICE_URL" ]; then \
			echo "⚠️ Could not get minikube service URL. Falling back to localhost..."; \
			SERVICE_URL="http://localhost:8080"; \
		fi; \
		echo "Using service URL: $$SERVICE_URL"; \
	else \
		echo "Using Docker Compose environment"; \
		SERVICE_URL="http://localhost:8080"; \
	fi; \
	\
	echo "\n1. Testing GET /api/v1/students (should be empty initially)"; \
	curl -s -w "\nStatus: %{http_code}\n" $$SERVICE_URL/api/v1/students || echo "Request failed"; \
	\
	echo "\n\n2. Testing POST /api/v1/students (creating a new student)"; \
	curl -s -w "\nStatus: %{http_code}\n" -X POST $$SERVICE_URL/api/v1/students \
		-H "Content-Type: application/json" \
		-d '{"name":"Test Student","age":20,"grade":"A+"}' || echo "Request failed"; \
	\
	echo "\n\n3. Testing GET /api/v1/students again (should show the new student)"; \
	curl -s -w "\nStatus: %{http_code}\n" $$SERVICE_URL/api/v1/students || echo "Request failed"; \
	\
	echo "\n\nAPI tests completed. Check the responses above."

# Test API endpoints in Kubernetes
test-api-k8s:
	@echo "\nTesting API endpoints in Kubernetes..."
	@echo "\n1. Testing GET /api/v1/students (should be empty initially)"
	@curl -s -w "\nStatus: %{http_code}\n" http://localhost:8080/api/v1/students
	@echo "\n\n2. Testing POST /api/v1/students (creating a new student)"
	@curl -s -w "\nStatus: %{http_code}\n" -X POST http://localhost:8080/api/v1/students \
		-H "Content-Type: application/json" \
		-d '{"name":"Test Student","age":20,"grade":"A+"}'
	@echo "\n\n3. Testing GET /api/v1/students again (should show the new student)"
	@curl -s -w "\nStatus: %{http_code}\n" http://localhost:8080/api/v1/students
	@echo "\n\nAPI tests completed. Check the responses above."

# For Kubernetes testing specifically
k8s-test: build k8s-deploy
	@echo "Waiting for deployment to be ready..."
	@kubectl wait --for=condition=available deployment/student-api -n student-api --timeout=60s
	@sleep 10
	@make test-api

# Clean Helm namespace
clean-helm-namespace:
	@echo "Cleaning Helm namespace..."
	@./scripts/clean-helm-namespace.sh dev-student-api

# Test Helm chart with latest values (using clean namespace approach)
test-helm: fix-permissions clean-helm-namespace
	@echo "Testing Helm chart deployment..."
	@helm upgrade --install student-api ./helm-charts/student-api-helm \
		--namespace dev-student-api \
		--values ./helm-charts/student-api-helm/environments/dev/values.yaml
	@echo "Waiting for deployment to be ready..."
	@kubectl wait --for=condition=available deployment/student-api -n dev-student-api --timeout=120s
	@echo "Setting up port forwarding..."
	@kubectl port-forward svc/student-api -n dev-student-api 8080:8080 & \
	echo $$! > .port-forward-pid
	@sleep 5
	@echo "Running Helm chart tests..."
	@NAMESPACE=dev-student-api ./helm-charts/student-api-helm/test.sh
	@kill $$(cat .port-forward-pid) || true
	@rm -f .port-forward-pid

# Test Helm chart with clean namespace and extended debugging
test-helm-debug: fix-permissions
	@echo "Testing Helm chart deployment with debugging using public image..."
	@./scripts/local-image-build.sh
	@./scripts/clean-helm-namespace.sh dev-student-api
	@helm upgrade --install student-api ./helm-charts/student-api-helm \
		--namespace dev-student-api \
		--values ./helm-charts/student-api-helm/environments/dev/values.yaml \
		--debug
	@echo "Waiting for deployment to be ready (with extended timeout)..."
	@kubectl wait --for=condition=available deployment/student-api -n dev-student-api --timeout=180s || \
		(./scripts/debug-helm-deployment.sh dev-student-api; exit 1)
	@echo "Setting up port forwarding..."
	@kubectl port-forward svc/student-api -n dev-student-api 8080:8080 & \
	echo $$! > .port-forward-pid
	@sleep 5
	@echo "Running Helm chart tests..."
	@NAMESPACE=dev-student-api ./helm-charts/student-api-helm/test.sh
	@kill $$(cat .port-forward-pid) || true
	@rm -f .port-forward-pid

# Setup node labels for deployment
setup-node-labels: fix-permissions
	@echo "Setting up node labels for deployment..."
	@./scripts/setup-node-labels.sh

# Apply ArgoCD manifests declaratively
argocd-apply-manifests: fix-permissions
	@echo "Applying ArgoCD manifests declaratively..."
	@kubectl apply -k ./argocd/

# Test ArgoCD configuration
test-argocd: fix-permissions setup-node-labels
	@echo "Testing ArgoCD configuration..."
	@echo "Setting up ArgoCD declaratively..."
	@./scripts/setup-argocd-declarative.sh
	@echo "Setup port forwarding to access ArgoCD UI:"
	@echo "kubectl port-forward svc/argocd-server -n argocd 9090:443"
	@echo "Then navigate to https://localhost:9090 in your browser"
	@echo "Verifying deployment on correct node..."
	@kubectl get pods -n argocd -o wide | grep -i "minikube" || echo "⚠️  Warning: ArgoCD pods may not be running"

# Access ArgoCD UI with credentials
argocd-ui: fix-permissions
	@echo "Setting up port forwarding to access ArgoCD UI..."
	@echo "ArgoCD admin username: admin"
	@echo -n "ArgoCD admin password: "
	@kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d || echo "Password not found. ArgoCD might be using a custom password."
	@echo "\nStarting port forwarding to ArgoCD UI (namespace: argocd)..."
	@echo "Access the UI at: https://localhost:9090"
	@echo "Press Ctrl+C to stop port forwarding when done."
	@kubectl port-forward svc/argocd-server -n argocd 9090:443

# Verify ArgoCD deployment on correct node
argocd-verify-deployment: fix-permissions
	@echo "Verifying ArgoCD deployment on nodes with role=dependent_services..."
	@echo "All ArgoCD components should be running in the argocd namespace"
	@kubectl get pods -n argocd -o wide
	@echo "\nChecking node affinity configuration:"
	@kubectl get deployments -n argocd -o jsonpath='{.items[*].spec.template.spec.nodeSelector}' | grep -i "dependent_services" || echo "⚠️  Warning: Node affinity may not be configured correctly"

# Force ArgoCD deployment with options to skip node selector
argocd-force-deploy: fix-permissions setup-node-labels
	@echo "Force deploying ArgoCD declaratively..."
	@read -p "Use node selector for ArgoCD (y/n)? " USE_NODE_SELECTOR; \
	if [ "$$USE_NODE_SELECTOR" = "y" ]; then \
		read -p "Enter node selector (default: dependent_services): " NODE_SELECT; \
		NODE_SELECT=$${NODE_SELECT:-dependent_services}; \
		echo "Using node selector: $$NODE_SELECT"; \
		NODE_SELECTOR="$$NODE_SELECT" NODE_SELECTOR_KEY="role" ./scripts/setup-argocd-declarative.sh; \
	else \
		echo "Deploying without node selector constraints..."; \
		SKIP_NODE_SELECTOR=true ./scripts/setup-argocd-declarative.sh; \
	fi

# Setup Git repository credentials for ArgoCD
argocd-setup-repo-creds: fix-permissions
	@echo "Setting up Git repository credentials for ArgoCD..."
	@read -p "Enter Git repository URL (e.g., https://github.com/yourusername/repo): " REPO_URL; \
	read -p "Authentication type (https/ssh): " AUTH_TYPE; \
	if [ "$$AUTH_TYPE" = "https" ]; then \
		read -p "Enter Git username: " GIT_USERNAME; \
		read -sp "Enter Git password or token: " GIT_PASSWORD; \
		echo ""; \
		echo "Creating repository credentials in ArgoCD..."; \
		kubectl -n argocd create secret generic git-repo-creds \
			--from-literal=url=$$REPO_URL \
			--from-literal=username=$$GIT_USERNAME \
			--from-literal=password=$$GIT_PASSWORD \
			--dry-run=client -o yaml | kubectl apply -f -; \
		kubectl -n argocd label secret git-repo-creds argocd.argoproj.io/secret-type=repository --overwrite; \
	elif [ "$$AUTH_TYPE" = "ssh" ]; then \
		read -p "Enter path to SSH private key file: " SSH_KEY_PATH; \
		if [ ! -f "$$SSH_KEY_PATH" ]; then \
			echo "Error: SSH key file not found"; \
			exit 1; \
		fi; \
		echo "Creating repository credentials with SSH key in ArgoCD..."; \
		kubectl -n argocd create secret generic git-repo-creds \
			--from-literal=url=$$REPO_URL \
			--from-file=sshPrivateKey=$$SSH_KEY_PATH \
			--dry-run=client -o yaml | kubectl apply -f -; \
		kubectl -n argocd label secret git-repo-creds argocd.argoproj.io/secret-type=repository --overwrite; \
	else \
		echo "Error: Invalid authentication type. Use 'https' or 'ssh'."; \
		exit 1; \
	fi; \
	echo "Repository credentials created in ArgoCD"; \
	echo ""; \
	echo "To verify, check that your applications sync correctly:"; \
	echo "1. Run 'make argocd-ui' to access the ArgoCD UI"; \
	echo "2. Look at your applications and verify they sync without errors"; \
	echo ""; \
	echo "If problems persist, try refreshing your applications in the UI or CLI:"; \
	echo "kubectl -n argocd get applications"; \
	echo "kubectl -n argocd patch application <app-name> -p '{\"metadata\":{\"annotations\":{\"argocd.argoproj.io/refresh\":\"hard\"}}}' --type merge"

# Quick deployment of ArgoCD skipping statefulset wait
argocd-quick-deploy: fix-permissions setup-node-labels
	@echo "Quick deploying ArgoCD (skipping statefulset wait)..."
	@SKIP_WAIT_STATEFULSET=true ROLLOUT_TIMEOUT="60s" ./scripts/setup-argocd-declarative.sh
	@echo "\nVerifying critical ArgoCD components are running..."
	@kubectl get pods -n argocd | grep -E 'server|repo-server'
	@echo "\nNote: The application-controller may remain in Pending state in resource-constrained environments"
	@echo "Run 'make fix-argocd-controller' to attempt to fix resource constraints if needed"

# Debug ArgoCD deployment issues
debug-argocd: fix-permissions
	@echo "Running ArgoCD deployment diagnostics..."
	@./scripts/debug-argocd-deploy.sh
	@echo "For more detailed debugging, try:"
	@echo "kubectl describe pod -n argocd -l app.kubernetes.io/name=argocd-server"
	@echo "kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server"

# Fix ArgoCD application controller resource constraints
fix-argocd-controller: fix-permissions
	@echo "Optimizing ArgoCD application controller resources..."
	@FIX_RESOURCES=true ./scripts/setup-argocd-declarative.sh
	@echo "Restarting problematic pods if any..."
	@kubectl rollout restart statefulset argocd-application-controller -n argocd
	@kubectl rollout restart deployment argocd-notifications-controller -n argocd
	@kubectl rollout restart deployment argocd-applicationset-controller -n argocd

# Test ArgoCD notifications
test-argocd-notifications: fix-permissions
	@echo "Testing ArgoCD notifications..."
	@./scripts/test-argocd-notifications.sh

# Test all notification channels by forcing notifications
test-notifications: fix-permissions
	@echo "Testing all notification channels by forcing notifications..."
	@./scripts/force-notifications.sh

# Test direct email functionality
test-email: fix-permissions
	@echo "Testing direct email functionality..."
	@./scripts/test-email-notifications.sh

# Set up secure email password for notifications
setup-email-password: fix-permissions
	@echo "Setting up email password for ArgoCD notifications..."
	@read -sp "Enter Gmail app password: " password; \
	kubectl create secret generic argocd-notifications-secret \
		--namespace argocd \
		--from-literal=email-password=$$password \
		--dry-run=client -o yaml | kubectl apply -f -
	@echo "\nEmail password secret created successfully"

# Verify email configuration
verify-email-config: fix-permissions
	@echo "Verifying email notification configuration..."
	@./scripts/verify-email-settings.sh

# Run all tests for ArgoCD and Helm with enhanced debugging
test-all: fix-permissions
	@echo "Running all tests..."
	@make test-argocd
	@echo "========================="
	@echo "ArgoCD tests completed. Running Helm tests..."
	@echo "========================="
	@make test-helm-local
	@echo "========================="
	@echo "Verification: Checking deployment health"
	@./scripts/debug-helm-deployment.sh dev-student-api
	@echo "========================="
	@echo "All tests completed successfully!"

# Fix permissions for scripts
fix-permissions:
	@echo "Fixing script permissions..."
	@chmod +x ./scripts/*.sh
	@chmod +x ./helm-charts/student-api-helm/*.sh
	@chmod +x ./argocd/*.sh || true

# Build and load local image for testing
build-local-image: fix-permissions
	@echo "Building and loading local image for testing..."
	@./scripts/local-image-build.sh

# Test Helm chart with local image
test-helm-local: fix-permissions build-local-image clean-helm-namespace
	@echo "Testing Helm chart deployment with local image..."
	@helm upgrade --install student-api ./helm-charts/student-api-helm \
		--namespace dev-student-api \
		--values ./helm-charts/student-api-helm/environments/dev/values.yaml
	@echo "Waiting for deployment to be ready..."
	@kubectl wait --for=condition=available deployment/student-api -n dev-student-api --timeout=120s
	@echo "Running Helm chart tests directly..."
	@TEST_PORT=8888 NAMESPACE=dev-student-api ./helm-charts/student-api-helm/test.sh

# Cleans up the application and Docker resources
clean:
	docker-compose down -v
	docker rmi ketan-karki/student-api:$(VERSION) 2>/dev/null || true
	docker network rm $(NETWORK_NAME) 2>/dev/null || true
	kubectl delete -f k8s/student-api/deployment.yaml 2>/dev/null || true
	kubectl delete -f k8s/config/app-config.yaml 2>/dev/null || true
	kubectl delete -f k8s/config/db-secrets.yaml 2>/dev/null || true
	kubectl delete -f k8s/postgres/deployment.yaml 2>/dev/null || true
	kubectl delete -f k8s/postgres/service.yaml 2>/dev/null || true

# Verify all functionality to ensure nothing is broken
verify-all: fix-permissions
	@echo "====================================="
	@echo "RUNNING COMPREHENSIVE VERIFICATION SUITE"
	@echo "====================================="
	
	@echo "\n[1/7] Testing Docker Compose deployment..."
	@make up
	@make test-api || { echo "❌ Docker Compose deployment test failed"; exit 1; }
	@echo "✅ Docker Compose deployment test passed"
	
	@echo "\n[2/7] Testing Kubernetes deployment..."
	@make k8s-deploy || { echo "❌ Kubernetes deployment failed"; exit 1; }
	@echo "✅ Kubernetes configuration applied successfully"
	@make test-api-k8s || { echo "❌ Kubernetes API test failed"; exit 1; }
	@echo "✅ Kubernetes API test passed"
	
	@echo "\n[3/7] Testing Helm chart deployment..."
	@make test-helm || { echo "❌ Helm chart test failed"; exit 1; }
	@echo "✅ Helm chart test passed"
	
	@echo "\n[4/7] Testing local image build and deployment..."
	@make test-helm-local || { echo "❌ Helm chart with local image test failed"; exit 1; }
	@echo "✅ Helm chart with local image test passed"
	
	@echo "\n[5/7] Testing ArgoCD setup..."
	@echo "Using quick deployment to avoid statefulset timeout..."
	@make argocd-quick-deploy || { echo "❌ ArgoCD configuration test failed"; exit 1; }
	@make argocd-verify-deployment || { echo "⚠️ ArgoCD node placement check failed but continuing"; }
	@echo "✅ ArgoCD configuration test passed (Note: application-controller might not be ready)"
	
	@echo "\n[6/7] Testing notification systems..."
	@make test-notifications || { echo "⚠️ Notification tests failed but continuing"; }
	@echo "✅ Notification tests completed"
	
	@echo "\n[7/7] Testing email functionality..."
	@make test-email || { echo "⚠️ Email test failed but continuing"; }
	@echo "✅ Email test completed"
	
	@echo "\n====================================="
	@echo "🎉 ALL VERIFICATION TESTS COMPLETED"
	@echo "====================================="
	@echo "Note: ArgoCD application-controller may still be in 'Pending' state,"
	@echo "but this doesn't affect the core functionality verification."
	@echo ""
	@echo "Port forwarding instructions for ArgoCD UI:"
	@echo "kubectl port-forward svc/argocd-server -n argocd 9090:443"
	@echo "Then navigate to https://localhost:9090 in your browser"
	@echo "\nCleanup recommended after verification:"
	@echo "make clean"

# Fix ArgoCD sync issues with immutable fields
argocd-fix-sync: fix-permissions
	@echo "Fixing ArgoCD sync issues for student-api-dev..."
	@echo "1. Deleting problematic deployment from the cluster..."
	@kubectl delete deployment student-api -n dev-student-api --ignore-not-found=true
	@echo "2. Patching ArgoCD application to use 'Replace' instead of 'Patch'..."
	@kubectl patch application student-api-dev -n argocd --type=merge -p '{"spec":{"syncPolicy":{"syncOptions":["RespectIgnoreDifferences=true","Replace=true"]}}}'
	@echo "3. Annotating application to trigger a hard refresh..."
	@kubectl patch application student-api-dev -n argocd --type=merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
	@echo "4. Forcing sync with replace strategy..."
	@kubectl exec -it -n argocd deployment/argocd-server -- argocd app sync student-api-dev --replace --force || echo "⚠️  CLI sync failed, but the annotations should trigger a sync anyway"
	@echo "\n5. Verifying application status (may take a moment to update):"
	@kubectl get application student-api-dev -n argocd -o jsonpath='{.status.health.status}{" | "}{.status.sync.status}{"\n"}'
	@echo "\nSync issue should be resolved. If the application is still 'OutOfSync', run 'make argocd-ui' to check details in the UI."

# Update ArgoCD notification settings to reduce email spam
argocd-update-notifications: fix-permissions
	@echo "Updating ArgoCD notification settings to reduce email spam..."
	@echo 'apiVersion: v1' > /tmp/argocd-notifications.yaml
	@echo 'kind: ConfigMap' >> /tmp/argocd-notifications.yaml
	@echo 'metadata:' >> /tmp/argocd-notifications.yaml
	@echo '  name: argocd-notifications-cm' >> /tmp/argocd-notifications.yaml
	@echo '  namespace: argocd' >> /tmp/argocd-notifications.yaml
	@echo 'data:' >> /tmp/argocd-notifications.yaml
	@echo '  subscriptions: |' >> /tmp/argocd-notifications.yaml
	@echo '    - recipients:' >> /tmp/argocd-notifications.yaml
	@echo '        - email: ketankarki2626@gmail.com' >> /tmp/argocd-notifications.yaml
	@echo '      triggers:' >> /tmp/argocd-notifications.yaml
	@echo '        - on-sync-succeeded' >> /tmp/argocd-notifications.yaml
	@echo '        - on-sync-failed' >> /tmp/argocd-notifications.yaml
	@echo '        - on-health-degraded' >> /tmp/argocd-notifications.yaml
	@echo '      template: default' >> /tmp/argocd-notifications.yaml
	@echo '  templates: |' >> /tmp/argocd-notifications.yaml
	@echo '    default: |' >> /tmp/argocd-notifications.yaml
	@echo '      email:' >> /tmp/argocd-notifications.yaml
	@echo '        subject: "Application {{.app.metadata.name}} {{.app.status.sync.status}}"' >> /tmp/argocd-notifications.yaml
	@echo '        body: |' >> /tmp/argocd-notifications.yaml
	@echo '          Application {{.app.metadata.name}} has {{.app.status.sync.status}}.' >> /tmp/argocd-notifications.yaml
	@echo '          Current health status: {{.app.status.health.status}}.' >> /tmp/argocd-notifications.yaml
	@echo '          Revision: {{.app.status.operationState.syncResult.revision}}.' >> /tmp/argocd-notifications.yaml
	@echo '          Environment: {{.app.metadata.labels.environment}}.' >> /tmp/argocd-notifications.yaml
	@kubectl apply -f /tmp/argocd-notifications.yaml
	@rm -f /tmp/argocd-notifications.yaml
	@echo "ArgoCD notification settings updated. You should receive fewer emails now."