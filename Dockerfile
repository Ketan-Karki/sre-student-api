# Build stage
FROM golang:1.23.5-alpine AS builder
WORKDIR /app

# Install build dependencies
RUN apk add --no-cache ca-certificates=20241121-r1 tzdata=2025a-r0 gcc musl-dev

# Copy dependency files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build binary
RUN CGO_ENABLED=1 GOOS=linux go build -ldflags="-w -s" -o /app/main .

# Runtime stage
FROM alpine:3.19
WORKDIR /app

# Install runtime dependencies
RUN apk add --no-cache ca-certificates=20241121-r1 tzdata=2025a-r0 postgresql-client

# Copy necessary files
COPY --from=builder /app/main /app/main
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

# Create app directory with proper permissions
RUN mkdir -p /app/data && \
    addgroup -S appgroup && \
    adduser -S appuser -G appgroup && \
    chown -R appuser:appgroup /app

# Security settings
USER appuser

# Application port
EXPOSE 8080

# Environment variables
ENV GIN_MODE=debug \
    DATABASE_URL=postgresql://postgres:postgres@db:5432/student_api?sslmode=disable

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/api/v1/healthcheck || exit 1

# Runtime command
CMD ["/app/main"]
