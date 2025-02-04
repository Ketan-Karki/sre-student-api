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
