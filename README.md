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
- **REST API**: HTTP endpoints for easy integration with web applications
- **Flexible session management**: Use any session ID you want - no pre-registration required
- **🎉 Persistent shell sessions**: Maintain shell state between commands (working directory, environment variables, etc.)

## Quick Start

```bash
# Build the server
go build -o mcp-terminal-server

# Run in HTTP mode
./mcp-terminal-server -sse -port 8080

# Run in STDIO mode (default)
./mcp-terminal-server
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