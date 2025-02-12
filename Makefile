# Makefile for building and running the Student API

# Variables
APP_NAME=main
GO=go

# Targets
.PHONY: all build run clean migrate docker-build docker-run

all: build

build:
	docker build -t ketan-karki/student-api .

run: build
	docker run -d -p 8080:8080 ketan-karki/student-api

clean:
	rm -f $(APP_NAME)

migrate:
	$(GO) run -tags 'sqlite3' github.com/golang-migrate/migrate/v4/cmd/migrate@latest -path ./migrations -database $(DATABASE_URL) up

docker-build:
	docker build -t ketan-karki/student-api .

docker-run:
	docker run -d -p 8080:80 ketan-karki/student-api