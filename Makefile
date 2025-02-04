# Makefile for building and running the Student API

# Variables
APP_NAME=main
GO=go

# Targets
.PHONY: all build run clean

all: build

build:
	$(GO) build -o $(APP_NAME) .

run: build
	./$(APP_NAME)

clean:
	rm -f $(APP_NAME)

migrate:
	$(GO) run -tags 'sqlite3' github.com/golang-migrate/migrate/v4/cmd/migrate@latest -path ./migrations -database sqlite3://api.db up
