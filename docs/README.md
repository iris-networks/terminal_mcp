# MCP Terminal Server Documentation

Welcome to the MCP Terminal Server documentation. This server provides a Model Context Protocol (MCP) implementation for executing terminal commands with support for both persistent and non-persistent execution modes.

## Quick Navigation

### User Guides
- [**Quick Start Guide**](user-guides/QUICK_START.md) - Get up and running in minutes
- [**Getting Started**](user-guides/GETTING_STARTED.md) - Comprehensive setup and configuration
- [**Vercel AI SDK Integration**](user-guides/VERCEL_AI_SDK.md) - Connect to Vercel AI SDK
- [**Process Management**](user-guides/PROCESS_MANAGEMENT.md) - Production deployment with s6, systemd, and security

### Architecture
- [**Architecture Overview**](architecture/ARCHITECTURE.md) - System design and modular structure

### API Reference
- [**HTTP API**](api/) - RESTful endpoints and MCP protocol
- [**Tools Reference**](api/) - Available MCP tools and their parameters

### Examples
- [**Usage Examples**](examples/) - Common use cases and code samples

## Key Features

- **Persistent Shell Sessions**: Maintain state between commands
- **Non-Persistent Execution**: Run isolated commands with timeouts
- **Cross-Platform Support**: Works on macOS and Linux
- **HTTP & STDIO Modes**: Flexible deployment options
- **Session Management**: Create, list, and close shell sessions
- **Configurable Timeouts**: Per-command and default timeout settings

## Quick Start

```bash
# Build the server
go build -o mcp-terminal-server

# Run in HTTP mode
./mcp-terminal-server --http --port 8080

# Run in STDIO mode (default)
./mcp-terminal-server
```

## Available Tools

1. **execute_command** - Execute single commands with timeout
2. **persistent_shell** - Execute commands in persistent shell sessions
3. **session_manager** - Manage shell sessions (list, close)

## Support

For detailed setup instructions, see the [Getting Started Guide](user-guides/GETTING_STARTED.md).

For integration with web applications, see the [Vercel AI SDK Guide](user-guides/VERCEL_AI_SDK.md).

For understanding the system architecture, see the [Architecture Overview](architecture/ARCHITECTURE.md).