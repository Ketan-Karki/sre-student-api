# Build stage
FROM golang:1.23.5-alpine AS builder
WORKDIR /app

# Install only essential build dependencies
RUN apk add --no-cache ca-certificates tzdata

# Copy dependency files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build static binary with additional optimization flags
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o /app/main .

# Runtime stage
FROM scratch
WORKDIR /app

# Copy only necessary files
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=builder /app/main /app/main
COPY --from=builder /app/.env /app/.env

# Security settings
USER 1001:1001

# Application port
EXPOSE 8080

# Runtime command
ENTRYPOINT ["/app/main"]
