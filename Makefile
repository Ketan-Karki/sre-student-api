# Makefile for building and running the Student API

# Variables
APP_NAME=main
GO=go
VERSION=1.0.0
NETWORK_NAME=student-api-network

# Targets
.PHONY: all build run clean test up down logs ps test-api test-api-k8s

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

# Test API endpoints
test-api: up
	@echo "Waiting for services to be ready..."
	@sleep 10
	@echo "\nTesting API endpoints..."
	@echo "\n1. Testing GET /api/v1/students (should be empty initially)"
	@curl -s -w "\nStatus: %{http_code}\n" http://localhost:8080/api/v1/students
	@echo "\n\n2. Testing POST /api/v1/students (creating a new student)"
	@curl -s -w "\nStatus: %{http_code}\n" -X POST http://localhost:8080/api/v1/students \
		-H "Content-Type: application/json" \
		-d '{"name":"Test Student","age":20,"grade":"A+"}'
	@echo "\n\n3. Testing GET /api/v1/students again (should show the new student)"
	@curl -s -w "\nStatus: %{http_code}\n" http://localhost:8080/api/v1/students
	@echo "\n\nAPI tests completed. Check the responses above."

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

# Cleans up the application and Docker resources
clean:
	docker-compose down -v
	docker rmi ketan-karki/student-api:$(VERSION) 2>/dev/null || true
	docker network rm $(NETWORK_NAME) 2>/dev/null || true