# Makefile for building and running the Student API

# Variables
APP_NAME=main
GO=go
VERSION=1.0.0

# Targets
.PHONY: all build run clean migrate docker-build docker-run

all: build

build:
	docker build -t ketan-karki/student-api:$(VERSION) .

run: build
	docker run -d -p 8080:8080 ketan-karki/student-api:$(VERSION)

clean:
	rm -f $(APP_NAME)

migrate:
	$(GO) run -tags 'sqlite3' github.com/golang-migrate/migrate/v4/cmd/migrate@latest -path ./migrations -database $(DATABASE_URL) up

docker-build:
	docker build -t ketan-karki/student-api:$(VERSION) .

docker-run:
	docker run -d -p 8080:80 ketan-karki/student-api:$(VERSION)