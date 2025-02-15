# Build stage
FROM golang:1.23.5-alpine AS builder
WORKDIR /app

# Install only essential build dependencies
RUN apk add --no-cache ca-certificates=20241121-r1 tzdata=2025a-r0

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

# Environment variables
ENV PORT=8080 \
    GIN_MODE=release \
    DATABASE_URL=./api.db \
    DATABASE_MAX_CONNECTIONS=10 \
    DATABASE_MAX_IDLE_CONNECTIONS=5 \
    DATABASE_MAX_LIFETIME=1h \
    LOG_LEVEL=info \
    ALLOWED_ORIGINS=* \
    REDIS_URL=redis-cache:6379

# Healthcheck
HEALTHCHECK --interval=10s --timeout=5s --retries=3 CMD nc -z redis-cache 6379 || exit 1

# Runtime command
ENTRYPOINT ["/app/main"]
