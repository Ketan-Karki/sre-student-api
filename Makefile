# Makefile for building and running the Student API

# Variables
APP_NAME=main
GO=go
VERSION=1.0.0
NETWORK_NAME=student-api-network

# Targets
.PHONY: all build run clean migrate docker-build docker-run network redis-start redis-cli up down logs ps

all: build

build:
	docker build -t ketan-karki/student-api:$(VERSION) .

network:
	docker network create $(NETWORK_NAME) 2>/dev/null || true

redis-start: network
	docker run --name redis-cache --network $(NETWORK_NAME) -d redis 2>/dev/null || true

redis-cli:
	docker exec -it redis-cache redis-cli

run: build redis-start
	docker run --network $(NETWORK_NAME) -p 8080:8080 ketan-karki/student-api:$(VERSION)

clean:
	rm -f $(APP_NAME)
	docker rm -f redis-cache 2>/dev/null || true
	docker network rm $(NETWORK_NAME) 2>/dev/null || true

migrate:
	$(GO) run -tags 'sqlite3' github.com/golang-migrate/migrate/v4/cmd/migrate@latest -path ./migrations -database $(DATABASE_URL) up

docker-build:
	docker build -t ketan-karki/student-api:$(VERSION) .

docker-run: redis-start
	docker run --network $(NETWORK_NAME) -p 8080:8080 ketan-karki/student-api:$(VERSION)

# Docker Compose commands
up:
	docker-compose up --build -d

down:
	docker-compose down

logs:
	docker-compose logs -f

ps:
	docker-compose ps