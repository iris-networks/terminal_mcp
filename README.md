# MCP Terminal Server

A Model Context Protocol (MCP) server written in Go that provides secure terminal command execution with configurable timeouts and platform-specific support.

## Features

- **Cross-platform support**: Works on macOS and Linux
- **Configurable timeouts**: Set custom timeout values for command execution
- **Secure execution**: Commands run in controlled environment with proper error handling
- **Platform-aware**: Automatically detects and adapts to the host platform
- **Flexible shell support**: Configurable shell for command execution
- **Multiple transport modes**: 
  - STDIO mode for traditional MCP clients
  - HTTP mode for web-based integrations
  - **🌊 Server-Sent Events (SSE)**: Real-time event streaming for live command monitoring
- **REST API**: HTTP endpoints for easy integration with web applications
- **Flexible session management**: Use any session ID you want - no pre-registration required
- **🎉 Persistent shell sessions**: Maintain shell state between commands (working directory, environment variables, etc.)

## Quick Start

```bash
# Build the server
go build -o mcp-terminal-server

# Run in HTTP mode with SSE support
./mcp-terminal-server -sse -port 8080

# Run in STDIO mode (default)
./mcp-terminal-server
```

## 🚀 Quick Testing

### Test HTTP Transport
```bash
# Run HTTP examples (works without SSE)
chmod +x http_examples.sh
./http_examples.sh
```

### Test SSE Transport
```bash
# Run comprehensive SSE tests
chmod +x sse_examples.sh
./sse_examples.sh
```

### Test Persistent Shell
```bash
# Test persistent shell functionality
chmod +x persistent_shell_examples.sh
./persistent_shell_examples.sh
```

### Test with Web Client
```bash
# Start server with SSE
./mcp-terminal-server -sse -port 8080

# Open the web client in your browser
open sse_test_client.html
# Or manually navigate to: file:///path/to/sse_test_client.html
```

### Manual SSE Testing
```bash
# Test SSE connection with curl
curl -H "Accept: text/event-stream" \
     -H "Cache-Control: no-cache" \
     "http://localhost:8080/sse?sessionId=test"

# Send a command while SSE is running
curl -X POST "http://localhost:8080/message?sessionId=test" \
     -H "Content-Type: application/json" \
     -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"execute_command","arguments":{"command":"echo Hello SSE!"}}}'
```

## Documentation

📚 **[Complete Documentation](docs/README.md)**

- [**Quick Start Guide**](docs/user-guides/QUICK_START.md) - Get up and running in minutes
- [**Getting Started**](docs/user-guides/GETTING_STARTED.md) - Comprehensive setup and configuration
- [**Vercel AI SDK Integration**](docs/user-guides/VERCEL_AI_SDK.md) - Connect to Vercel AI SDK
- [**Architecture Overview**](docs/architecture/ARCHITECTURE.md) - System design and modular structure

## Available Tools

1. **execute_command** - Execute single commands with timeout
2. **persistent_shell** - Execute commands in persistent shell sessions
3. **session_manager** - Manage shell sessions (list, close)

## Server Endpoints

When running in HTTP mode (`-sse` flag), the server provides these endpoints:

- **`GET /`** - Server information and available endpoints
- **`POST /execute`** - Direct command execution (no session required)
- **`POST /message?sessionId=<id>`** - MCP protocol endpoint with session support
- **`GET /sse?sessionId=<id>`** - Server-Sent Events stream for real-time monitoring

### SSE Events

The SSE endpoint streams these event types:
- **`connected`** - Initial connection established
- **`heartbeat`** - Periodic connection health check (every 30s)
- **`session_status`** - Session information updates (every 5s)

## Platform Support

- **macOS (darwin)**: Full support
- **Linux**: Full support

## Integration

### Claude Desktop

Add to your `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "terminal": {
      "command": "/path/to/mcp-terminal-server",
      "env": {
        "MCP_COMMAND_TIMEOUT": "30"
      }
    }
  }
}
```

### Other MCP Clients

The server follows the standard MCP protocol and should work with any compliant MCP client.

## Development

### Building

```bash
go build -o mcp-terminal-server
```

### Dependencies

- `github.com/mark3labs/mcp-go` - MCP Go library
- Go 1.23+ (automatically managed)

## Integration with Iris Agent

This MCP server is used by the [Iris Computer Use Agent](https://agent.tryiris.dev), our advanced computer use agent for automated terminal interactions.

## License

This project is provided as-is for development purposes.