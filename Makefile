# Makefile for building and running the Student API

# Variables
APP_NAME=main
GO=go
VERSION=1.0.0
NETWORK_NAME=student-api-network

# Targets
.PHONY: all build run clean migrate docker-run network redis-start redis-cli up down logs ps

# Default target that builds the application
# This target is the default entry point for the Makefile
all: build

# Builds the Docker image for the application
# This target creates a Docker image with the specified version
build:
	docker build -t ketan-karki/student-api:$(VERSION) .

# Creates a Docker network for the application
# This target creates a Docker network for the application to use
network:
	docker network create $(NETWORK_NAME) 2>/dev/null || true

# Starts a Redis container connected to the application network
# This target starts a Redis container and connects it to the application network
redis-start: network
	docker run --name redis-cache --network $(NETWORK_NAME) -d redis 2>/dev/null || true

# Opens a Redis CLI session
# This target opens a Redis CLI session for interacting with the Redis container
redis-cli:
	docker exec -it redis-cache redis-cli

# Builds the image and starts the Redis container
# This target builds the Docker image and starts the Redis container
run: build redis-start
	docker run --network $(NETWORK_NAME) -p 8080:8080 ketan-karki/student-api:$(VERSION)

# Cleans up the application and Docker resources
# This target removes the application and Docker resources
clean:
	rm -f $(APP_NAME)
	docker rm -f redis-cache 2>/dev/null || true
	docker network rm $(NETWORK_NAME) 2>/dev/null || true

# Runs database migrations
# This target runs database migrations using the migrate tool
migrate:
	$(GO) run -tags 'sqlite3' github.com/golang-migrate/migrate/v4/cmd/migrate@latest -path ./migrations -database $(DATABASE_URL) up

# Check if the SQLite database exists and creates it if not
# This target checks if the SQLite database exists and creates it if not
check-db:
	@if [ ! -f ./data/api.db ]; then \
		mkdir -p ./data; \
		touch ./data/api.db; \
		echo "Created new SQLite database"; \
	else \
		echo "SQLite database exists"; \
	fi

# Check and apply migrations
# This target checks and applies database migrations
check-migrations: check-db
	@echo "Checking and applying database migrations..."
	@$(GO) run -tags 'sqlite3' github.com/golang-migrate/migrate/v4/cmd/migrate@latest \
		-path ./migrations \
		-database "sqlite3://./data/api.db" \
		up

# Docker Compose commands
up: check-migrations
	docker-compose up --build -d
	@echo "Waiting for services to be healthy..."
	@timeout=60; \
	elapsed=0; \
	while [ $$elapsed -lt $$timeout ]; do \
		if docker-compose ps | grep -q "healthy"; then \
			echo "Services are healthy!"; \
			exit 0; \
		fi; \
		sleep 5; \
		elapsed=$$((elapsed + 5)); \
		echo "Still waiting for services... ($$elapsed seconds)"; \
	done; \
	echo "Warning: Timeout waiting for services to be healthy"

down:
	docker-compose down

logs:
	docker-compose logs -f

ps:
	docker-compose ps