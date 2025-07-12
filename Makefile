# Makefile for MCP Terminal Server

.PHONY: build clean test run run-http install deps fmt vet lint

# Build the server
build:
	go build -o mcp-terminal-server

# Clean build artifacts
clean:
	rm -f mcp-terminal-server

# Run tests
test:
	go test ./...

# Run in STDIO mode (default)
run:
	./mcp-terminal-server

# Run in HTTP mode
run-http:
	./mcp-terminal-server -sse -port 8080

# Install dependencies
deps:
	go mod tidy
	go mod download

# Format code
fmt:
	go fmt ./...

# Vet code
vet:
	go vet ./...

# Lint code (requires golangci-lint)
lint:
	golangci-lint run

# Install the server to GOPATH/bin
install:
	go install

# Build for multiple platforms
build-all:
	GOOS=linux GOARCH=amd64 go build -o mcp-terminal-server-linux-amd64
	GOOS=darwin GOARCH=amd64 go build -o mcp-terminal-server-darwin-amd64
	GOOS=darwin GOARCH=arm64 go build -o mcp-terminal-server-darwin-arm64

# Development setup
dev-setup: deps
	go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest