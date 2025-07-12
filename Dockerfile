# Multi-stage build for terminal-mcp server
FROM --platform=$BUILDPLATFORM golang:1.23-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git ca-certificates

# Set working directory
WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build arguments for cross-compilation
ARG TARGETOS
ARG TARGETARCH

# Build the binary
RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build -ldflags="-w -s" -o mcp-terminal-server .

# Final stage - minimal image
FROM alpine:latest

# Install runtime dependencies
RUN apk add --no-cache bash ca-certificates

# Create non-root user
RUN addgroup -g 1001 -S mcp && \
    adduser -S -D -H -u 1001 -h /app -s /sbin/nologin -G mcp -g mcp mcp

# Set working directory
WORKDIR /app

# Copy binary from builder
COPY --from=builder /app/mcp-terminal-server .

# Change ownership
RUN chown mcp:mcp /app/mcp-terminal-server && \
    chmod +x /app/mcp-terminal-server

# Switch to non-root user
USER mcp

# Set default environment variables
ENV MCP_COMMAND_TIMEOUT=30
ENV MCP_SHELL=/bin/bash

# Expose port for HTTP mode
EXPOSE 8080

# Default command
ENTRYPOINT ["./mcp-terminal-server"]