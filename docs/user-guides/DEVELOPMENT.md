# Development Guide

This guide covers development workflows, testing, and contribution guidelines for the MCP Terminal Server.

## Development Setup

### Prerequisites

- Go 1.23 or later
- Git
- Terminal/command line access

### Initial Setup

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd mcp-terminal-server
   ```

2. **Install dependencies**
   ```bash
   go mod download
   ```

3. **Build the project**
   ```bash
   go build -o mcp-terminal-server
   ```

4. **Run tests** (when available)
   ```bash
   go test ./...
   ```

## Project Structure

```
mcp-terminal-server/
├── main.go                    # Application entry point
├── internal/                  # Internal packages
│   ├── config/               # Configuration management
│   ├── session/              # Session management
│   ├── executor/             # Command execution
│   ├── handlers/             # HTTP handlers
│   └── tools/                # MCP tools
├── docs/                     # Documentation
└── go.mod                    # Go module definition
```

## Development Workflow

### Making Changes

1. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**
   - Follow Go conventions and best practices
   - Keep functions small and focused
   - Add appropriate error handling
   - Update documentation as needed

3. **Test your changes**
   ```bash
   # Build and test
   go build -o mcp-terminal-server
   ./mcp-terminal-server -help
   
   # Test HTTP mode
   ./mcp-terminal-server -sse -port 8080
   
   # Test STDIO mode
   ./mcp-terminal-server
   ```

4. **Commit your changes**
   ```bash
   git add .
   git commit -m "feat: add your feature description"
   ```

### Code Style

- Follow standard Go formatting: `go fmt`
- Use meaningful variable and function names
- Add comments for exported functions and types
- Keep functions under 50 lines when possible
- Use early returns to reduce nesting

### Testing

#### Manual Testing

**HTTP Mode Testing:**
```bash
# Start server
./mcp-terminal-server -sse -port 8080

# Test tools/list endpoint
curl -X POST "http://localhost:8080/message?sessionId=test" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc": "2.0", "id": 1, "method": "tools/list"}'

# Test execute_command
curl -X POST "http://localhost:8080/message?sessionId=test" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0", "id": 1, "method": "tools/call",
    "params": {
      "name": "execute_command",
      "arguments": {"command": "echo Hello World"}
    }
  }'
```

**STDIO Mode Testing:**
```bash
# Create test script
cat > test_stdin.json << 'EOF'
{"jsonrpc": "2.0", "id": 1, "method": "tools/call", "params": {"name": "execute_command", "arguments": {"command": "echo Hello World"}}}
EOF

# Test STDIO mode
./mcp-terminal-server < test_stdin.json
```

#### Unit Testing (Future)

When implementing unit tests:

```bash
# Run all tests
go test ./...

# Run tests with coverage
go test -cover ./...

# Run specific package tests
go test ./internal/session/
```

## Adding New Features

### Adding a New Tool

1. **Define the tool in `internal/tools/tools.go`**
   ```go
   func (r *Registry) registerMyNewTool(server *server.MCPServer) {
       myNewTool := mcp.NewTool("my_new_tool",
           mcp.WithDescription("Description of what this tool does"),
           mcp.WithInputSchema(mcp.ToolInputSchema{
               Type: "object",
               Properties: map[string]mcp.ToolInputProperty{
                   "param1": {
                       Type:        "string",
                       Description: "Description of param1",
                   },
               },
               Required: []string{"param1"},
           }),
       )
       
       server.AddTool(myNewTool, r.handleMyNewTool)
   }
   ```

2. **Implement the handler**
   ```go
   func (r *Registry) handleMyNewTool(arguments map[string]interface{}) *mcp.CallToolResult {
       param1, ok := arguments["param1"].(string)
       if !ok {
           return mcp.NewToolResultError("param1 is required")
       }
       
       // Your implementation here
       
       return mcp.NewToolResultText("Tool executed successfully")
   }
   ```

3. **Register the tool**
   ```go
   func (r *Registry) RegisterTools(server *server.MCPServer) {
       // ... existing tools
       r.registerMyNewTool(server)
   }
   ```

### Adding Configuration Options

1. **Add to Config struct in `internal/config/config.go`**
   ```go
   type Config struct {
       // ... existing fields
       MyNewOption string
   }
   ```

2. **Add flag parsing**
   ```go
   func (c *Config) ParseFlags() {
       // ... existing flags
       flag.StringVar(&c.MyNewOption, "my-option", "default", "Description")
       flag.Parse()
   }
   ```

3. **Add environment variable support**
   ```go
   func NewConfig() *Config {
       return &Config{
           // ... existing defaults
           MyNewOption: getEnv("MCP_MY_OPTION", "default"),
       }
   }
   ```

## Debugging

### Logging

Add debug logging throughout your code:

```go
import "log"

log.Printf("Debug: Processing request for session: %s", sessionID)
```

### HTTP Debugging

Use curl with verbose output:

```bash
curl -v -X POST "http://localhost:8080/message?sessionId=debug" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc": "2.0", "id": 1, "method": "tools/list"}'
```

### STDIO Debugging

Use JSON pretty printing:

```bash
echo '{"jsonrpc": "2.0", "id": 1, "method": "tools/list"}' | \
  ./mcp-terminal-server | jq '.'
```

## Performance Considerations

### Memory Management

- Use `context.Context` for request cancellation
- Implement proper cleanup for sessions
- Avoid memory leaks in goroutines

### Concurrency

- Use mutexes for shared state
- Implement proper session cleanup
- Handle concurrent HTTP requests safely

### Error Handling

- Always check for errors
- Provide meaningful error messages
- Log errors appropriately
- Use proper HTTP status codes

## Building for Production

### Build Optimization

```bash
# Build with optimizations
go build -ldflags="-s -w" -o mcp-terminal-server

# Cross-compilation
GOOS=linux GOARCH=amd64 go build -o mcp-terminal-server-linux
GOOS=darwin GOARCH=amd64 go build -o mcp-terminal-server-darwin
```

### Configuration Management

Use environment variables for production:

```bash
export MCP_COMMAND_TIMEOUT=60
export MCP_SHELL=/bin/bash
./mcp-terminal-server -sse -port 8080
```

## Contributing

### Pull Request Guidelines

1. **Fork the repository**
2. **Create a feature branch**
3. **Make your changes**
4. **Test thoroughly**
5. **Submit a pull request**

### Code Review Checklist

- [ ] Code follows Go conventions
- [ ] Functions are well-documented
- [ ] Error handling is appropriate
- [ ] Tests are included (when applicable)
- [ ] Documentation is updated
- [ ] No breaking changes (or clearly documented)

### Issue Reporting

When reporting issues:

1. **Provide system information**
   - OS and version
   - Go version
   - Server version

2. **Include reproduction steps**
   - Exact commands run
   - Expected vs actual behavior
   - Error messages

3. **Attach relevant logs**
   - Server output
   - Client requests/responses

## Common Development Tasks

### Updating Dependencies

```bash
# Update all dependencies
go get -u ./...

# Update specific dependency
go get -u github.com/mark3labs/mcp-go
```

### Code Formatting

```bash
# Format all code
go fmt ./...

# Run linter (if available)
golint ./...
```

### Documentation Updates

After making changes:

1. Update relevant documentation files
2. Update code comments
3. Update README if needed
4. Test documentation examples

## Troubleshooting

### Common Issues

1. **Build failures**
   - Check Go version compatibility
   - Ensure dependencies are downloaded
   - Verify module path

2. **Runtime errors**
   - Check file permissions
   - Verify shell availability
   - Review timeout settings

3. **HTTP mode issues**
   - Verify port availability
   - Check CORS settings
   - Review request format

### Getting Help

- Review existing documentation
- Check GitHub issues
- Test with minimal examples
- Enable debug logging