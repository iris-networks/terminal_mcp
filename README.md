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
  - **🌐 StreamableHTTP transport**: Standards-compliant HTTP-based MCP transport for web integrations
- **Flexible session management**: Use any session ID you want - no pre-registration required
- **🎉 Persistent shell sessions**: Maintain shell state between commands (working directory, environment variables, etc.)

## Quick Start

```bash
# Build the server
go build -o mcp-terminal-server

# Run in HTTP mode with StreamableHTTP transport
./mcp-terminal-server --http --port 8080

# Run in STDIO mode (default)
./mcp-terminal-server
```

## 🚀 Quick Testing

### Test StreamableHTTP Transport
```bash
# Start server in HTTP mode
./mcp-terminal-server --http --port 8080

# Test MCP initialization
curl -X POST http://localhost:8080/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "test-client", "version": "1.0.0"}}}'

# Test tools listing (use session ID from initialize response)
curl -X POST http://localhost:8080/mcp \
  -H "Content-Type: application/json" \
  -H "Mcp-Session-Id: <session-id>" \
  -d '{"jsonrpc": "2.0", "id": 2, "method": "tools/list"}'

# Execute a command
curl -X POST http://localhost:8080/mcp \
  -H "Content-Type: application/json" \
  -H "Mcp-Session-Id: <session-id>" \
  -d '{"jsonrpc": "2.0", "id": 3, "method": "tools/call", "params": {"name": "execute_command", "arguments": {"command": "echo Hello StreamableHTTP!"}}}'
```

### Test Persistent Shell
```bash
# Test persistent shell functionality
chmod +x examples/persistent_shell_examples.sh
./examples/persistent_shell_examples.sh
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

When running in HTTP mode (`--http` flag), the server provides:

- **`POST /mcp`** - StreamableHTTP transport endpoint for all MCP operations
  - Supports `initialize`, `tools/list`, `tools/call` methods
  - Requires `Mcp-Session-Id` header for authenticated requests
  - Returns session ID in response headers for `initialize` calls

### MCP Protocol Support

The server implements the [Model Context Protocol](https://modelcontextprotocol.io/) specification:
- **JSON-RPC 2.0** communication
- **Session management** with UUID-based session IDs
- **Tool execution** with structured input/output
- **Error handling** with standard JSON-RPC error codes

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

## Production Deployment

For production environments, it's recommended to run the server with proper process management and security measures:

### Process Management
- **s6**: Lightweight process supervision with automatic restart
- **systemd**: Full-featured service management with resource limits
- **Docker**: Containerized deployment with security isolation
- **Supervisor**: Python-based process management

### Security Features
- **Non-root execution**: Run with dedicated user account for limited privileges
- **Resource limits**: CPU, memory, and file access restrictions
- **Network isolation**: Bind to localhost only for enhanced security
- **AppArmor/SELinux**: Additional mandatory access controls
- **File permissions**: Restricted access to necessary directories only

📋 **See [Process Management Guide](docs/user-guides/PROCESS_MANAGEMENT.md) for detailed setup instructions**

## Integration with Iris Agent

This MCP server is used by the [Iris Computer Use Agent](https://agent.tryiris.dev), our advanced computer use agent for automated terminal interactions.

## License

This project is provided as-is for development purposes.