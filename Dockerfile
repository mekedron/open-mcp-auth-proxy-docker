# Build stage
FROM golang:1.21-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git make

# Set working directory
WORKDIR /build

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the binary with CGO disabled for static linking
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o openmcpauthproxy ./cmd/proxy

# Runtime stage
FROM alpine:latest

# Install ca-certificates for HTTPS requests
RUN apk --no-cache add ca-certificates

# Create non-root user
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

# Set working directory
WORKDIR /app

# Copy binary from builder
COPY --from=builder /build/openmcpauthproxy .

# Copy default configuration
COPY config.yaml .

# Change ownership to non-root user
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Expose proxy port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/.well-known/protected-resource-metadata || exit 1

# Run the proxy
ENTRYPOINT ["./openmcpauthproxy"]

# Default to demo mode (can be overridden)
CMD ["--demo"]
