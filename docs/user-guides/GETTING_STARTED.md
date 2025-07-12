# Getting Started with MCP Terminal Server

This guide will help you get the MCP Terminal Server up and running with both stdio and SSE modes.

## Prerequisites

- Go 1.23 or later
- macOS or Linux operating system
- Terminal access

## Installation

### Option 1: Build from Source

1. Clone or download the source code
2. Navigate to the project directory
3. Build the server:
   ```bash
   go build -o mcp-terminal-server
   ```

### Option 2: Download Binary

Download the pre-built binary for your platform (if available) and make it executable:
```bash
chmod +x mcp-terminal-server
```

## Starting the Server

### Method 1: STDIO Mode (Default)

This is the standard mode for MCP servers, using stdin/stdout for communication:

```bash
./mcp-terminal-server
```

The server will start in stdio mode and wait for JSON-RPC messages.

### Method 2: SSE Mode (HTTP Server)

For web-based integrations and easier testing:

```bash
./mcp-terminal-server -sse
```

**Custom Host and Port:**
```bash
./mcp-terminal-server -sse -host 0.0.0.0 -port 3000
```

### Command Line Options

```bash
./mcp-terminal-server -help
```

Available options:
- `-sse`: Enable SSE mode (HTTP server)
- `-host string`: Host for SSE server (default "localhost")
- `-port string`: Port for SSE server (default "8080")
- `-help`: Show help

## Environment Variables

Configure the server behavior with environment variables:

```bash
# Set default command timeout (in seconds)
export MCP_COMMAND_TIMEOUT=60

# Set custom shell
export MCP_SHELL=/bin/zsh

# Start the server
./mcp-terminal-server
```

## Testing the Server

### Test STDIO Mode

Create a test script to send JSON-RPC messages:

```bash
cat > test_stdio.json << 'EOF'
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/list"
}
EOF

cat test_stdio.json | ./mcp-terminal-server
```

### Test SSE Mode

1. Start the server in SSE mode:
   ```bash
   ./mcp-terminal-server -sse
   ```

2. In another terminal, test the endpoints:
   ```bash
   # Check server info
   curl http://localhost:8080/
   
   # Test SSE endpoint
   curl -N -H "Accept: text/event-stream" http://localhost:8080/sse
   ```

3. Send a command via the message endpoint:
   ```bash
   curl -X POST http://localhost:8080/message \
     -H "Content-Type: application/json" \
     -d '{
       "jsonrpc": "2.0",
       "id": 1,
       "method": "tools/call",
       "params": {
         "name": "execute_command",
         "arguments": {
           "command": "echo Hello World"
         }
       }
     }'
   ```

## Server Output

### STDIO Mode Output
```
2024/01/15 10:30:00 Starting MCP Terminal Server on platform: darwin
2024/01/15 10:30:00 Default timeout: 30s
2024/01/15 10:30:00 Default shell: /bin/bash
2024/01/15 10:30:00 Starting STDIO server
```

### SSE Mode Output
```
2024/01/15 10:30:00 Starting MCP Terminal Server on platform: darwin
2024/01/15 10:30:00 Default timeout: 30s
2024/01/15 10:30:00 Default shell: /bin/bash
2024/01/15 10:30:00 Starting SSE server on localhost:8080
2024/01/15 10:30:00 Server endpoints:
2024/01/15 10:30:00   Info: http://localhost:8080/
2024/01/15 10:30:00   SSE: http://localhost:8080/sse
2024/01/15 10:30:00   Message: http://localhost:8080/message
```

## Troubleshooting

### Common Issues

**1. Port Already in Use (SSE Mode)**
```bash
# Check what's using the port
lsof -i :8080

# Use a different port
./mcp-terminal-server -sse -port 8081
```

**2. Permission Denied**
```bash
# Make the binary executable
chmod +x mcp-terminal-server
```

**3. Command Timeout**
```bash
# Increase timeout for long-running commands
export MCP_COMMAND_TIMEOUT=300
./mcp-terminal-server
```

**4. Shell Not Found**
```bash
# Check available shells
cat /etc/shells

# Set a specific shell
export MCP_SHELL=/bin/bash
./mcp-terminal-server
```

### Debug Mode

Enable verbose logging by checking the server output. All operations are logged with timestamps.

### Platform Issues

- **macOS**: Uses `/bin/bash` by default
- **Linux**: Uses `/bin/bash` by default
- **Unsupported platforms**: Will show an error message

## Next Steps

- [Connect to Vercel AI SDK](./VERCEL_AI_SDK.md)
- [Integrate with Claude Desktop](./README.md#claude-desktop)
- [Advanced Configuration](./README.md#configuration)

## Security Considerations

⚠️ **Important**: This server executes arbitrary commands with the permissions of the user running it. Only use in trusted environments and with trusted inputs.

- Commands run with the same permissions as the server process
- No built-in sandboxing or command filtering
- Timeouts help prevent runaway processes
- Review all commands before execution in production environments