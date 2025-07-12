# Makefile for MCP Terminal Server

.PHONY: build clean test run run-http test-http test-mcp install deps fmt vet lint help dev-setup build-all demo

# Default target
.DEFAULT_GOAL := help

# Build the server
build:
	go build -o mcp-terminal-server

# Clean build artifacts
clean:
	rm -f mcp-terminal-server
	rm -f mcp-terminal-server-*

# Run tests
test:
	go test ./...

# Run in STDIO mode (default)
run:
	./mcp-terminal-server

# Run in HTTP mode (StreamableHTTP transport)
run-http:
	./mcp-terminal-server --http --port 8080

# Test HTTP mode with MCP protocol
test-http: build
	@echo "Testing MCP StreamableHTTP transport..."
	@echo "Starting server in background..."
	@./mcp-terminal-server --http --port 8080 &
	@sleep 2
	@echo "Testing MCP initialize..."
	@curl -s -X POST http://localhost:8080/mcp \
		-H "Content-Type: application/json" \
		-d '{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "makefile-test", "version": "1.0.0"}}}' \
		| jq . || echo "jq not installed, showing raw response"
	@echo "Stopping server..."
	@pkill -f "mcp-terminal-server" || true

# Quick MCP protocol test (requires running server)
test-mcp:
	@echo "Testing MCP protocol (server must be running on port 8080)..."
	@echo "1. Initialize session:"
	@curl -s -X POST http://localhost:8080/mcp \
		-H "Content-Type: application/json" \
		-d '{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "test", "version": "1.0.0"}}}' \
		| jq . 2>/dev/null || curl -s -X POST http://localhost:8080/mcp \
		-H "Content-Type: application/json" \
		-d '{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "test", "version": "1.0.0"}}}'

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

# Demo: Full MCP protocol workflow
demo: build
	@echo "🚀 MCP Terminal Server Demo"
	@echo "Starting server..."
	@./mcp-terminal-server --http --port 8080 &
	@sleep 2
	@echo ""
	@echo "1️⃣ Initialize MCP session..."
	@RESPONSE=$$(curl -s -X POST http://localhost:8080/mcp \
		-H "Content-Type: application/json" \
		-d '{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "demo", "version": "1.0.0"}}}'); \
	echo "Response: $$RESPONSE" | jq . 2>/dev/null || echo "$$RESPONSE"
	@echo ""
	@echo "2️⃣ List available tools..."
	@SESSION_ID=$$(curl -s -D - -X POST http://localhost:8080/mcp \
		-H "Content-Type: application/json" \
		-d '{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "demo", "version": "1.0.0"}}}' \
		| grep -i "mcp-session-id" | cut -d: -f2 | tr -d ' \r\n' | head -1); \
	curl -s -X POST http://localhost:8080/mcp \
		-H "Content-Type: application/json" \
		-H "Mcp-Session-Id: $$SESSION_ID" \
		-d '{"jsonrpc": "2.0", "id": 2, "method": "tools/list"}' \
		| jq '.result.tools[].name' 2>/dev/null || echo "Tools listed (jq not available for pretty output)"
	@echo ""
	@echo "3️⃣ Execute a test command..."
	@SESSION_ID=$$(curl -s -D - -X POST http://localhost:8080/mcp \
		-H "Content-Type: application/json" \
		-d '{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "demo", "version": "1.0.0"}}}' \
		| grep -i "mcp-session-id" | cut -d: -f2 | tr -d ' \r\n' | head -1); \
	curl -s -X POST http://localhost:8080/mcp \
		-H "Content-Type: application/json" \
		-H "Mcp-Session-Id: $$SESSION_ID" \
		-d '{"jsonrpc": "2.0", "id": 3, "method": "tools/call", "params": {"name": "execute_command", "arguments": {"command": "echo Hello from MCP StreamableHTTP!"}}}' \
		| jq '.result.content[0].text' 2>/dev/null || echo "Command executed successfully"
	@echo ""
	@echo "✅ Demo complete! Stopping server..."
	@pkill -f "mcp-terminal-server" || true

# Show help
help:
	@echo "MCP Terminal Server - Makefile Commands"
	@echo ""
	@echo "Building:"
	@echo "  build      Build the server binary"
	@echo "  build-all  Build for multiple platforms (Linux, macOS)"
	@echo "  clean      Remove build artifacts"
	@echo "  install    Install to GOPATH/bin"
	@echo ""
	@echo "Running:"
	@echo "  run        Run in STDIO mode (default MCP transport)"
	@echo "  run-http   Run in HTTP mode (StreamableHTTP transport)"
	@echo ""
	@echo "Testing:"
	@echo "  test       Run Go tests"
	@echo "  test-http  Test HTTP mode with MCP protocol"
	@echo "  test-mcp   Quick MCP protocol test (requires running server)"
	@echo "  demo       Full MCP protocol demonstration"
	@echo ""
	@echo "Development:"
	@echo "  deps       Install/update dependencies"
	@echo "  fmt        Format Go code"
	@echo "  vet        Run Go vet"
	@echo "  lint       Run golangci-lint"
	@echo "  dev-setup  Setup development environment"
	@echo ""
	@echo "Usage Examples:"
	@echo "  make demo                      # See the full MCP protocol in action"
	@echo "  make build && make run-http    # Build and start HTTP server"
	@echo "  make test-http                 # Test the MCP protocol"
	@echo "  make fmt vet lint              # Code quality checks"