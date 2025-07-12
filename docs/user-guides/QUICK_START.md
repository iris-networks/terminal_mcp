# Quick Start Guide

## HTTP Mode (StreamableHTTP Transport)

### 1. Start the Server
```bash
./mcp-terminal-server --http --port 8080
```

### 2. Initialize MCP Session
```bash
# First, initialize a session
curl -X POST http://localhost:8080/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "initialize",
    "params": {
      "protocolVersion": "2024-11-05",
      "capabilities": {},
      "clientInfo": {"name": "quick-start", "version": "1.0.0"}
    }
  }'

# Response will include session ID in Mcp-Session-Id header
```

### 3. Execute Commands

**Get session ID from initialize response, then:**
```bash
# Replace <session-id> with actual session ID from step 2
curl -X POST http://localhost:8080/mcp \
  -H "Content-Type: application/json" \
  -H "Mcp-Session-Id: <session-id>" \
  -d '{
    "jsonrpc": "2.0",
    "id": 2,
    "method": "tools/call",
    "params": {
      "name": "execute_command",
      "arguments": {
        "command": "echo Hello StreamableHTTP!"
      }
    }
  }'
```

### 4. List Available Tools
```bash
curl -X POST http://localhost:8080/mcp \
  -H "Content-Type: application/json" \
  -H "Mcp-Session-Id: <session-id>" \
  -d '{
    "jsonrpc": "2.0",
    "id": 3,
    "method": "tools/list"
  }'
```

### 5. Persistent Shell Sessions

**Use the same shell across multiple commands:**
```bash
# Command 1: pwd
curl -X POST http://localhost:8080/mcp \
  -H "Content-Type: application/json" \
  -H "Mcp-Session-Id: <session-id>" \
  -d '{
    "jsonrpc": "2.0", "id": 4, "method": "tools/call",
    "params": {
      "name": "persistent_shell",
      "arguments": {"command": "pwd", "session_id": "shell-session-1"}
    }
  }'

# Command 2: cd /tmp (directory change persists!)
curl -X POST http://localhost:8080/mcp \
  -H "Content-Type: application/json" \
  -H "Mcp-Session-Id: <session-id>" \
  -d '{
    "jsonrpc": "2.0", "id": 5, "method": "tools/call",
    "params": {
      "name": "persistent_shell",
      "arguments": {"command": "cd /tmp", "session_id": "shell-session-1"}
    }
  }'

# Command 3: pwd (shows /tmp!)
curl -X POST http://localhost:8080/mcp \
  -H "Content-Type: application/json" \
  -H "Mcp-Session-Id: <session-id>" \
  -d '{
    "jsonrpc": "2.0", "id": 6, "method": "tools/call",
    "params": {
      "name": "persistent_shell",
      "arguments": {"command": "pwd", "session_id": "shell-session-1"}
    }
  }'
```

## STDIO Mode (Traditional MCP)

### 1. Start the Server
```bash
./mcp-terminal-server
```

### 2. Send Commands via stdin
```bash
echo '{"jsonrpc": "2.0", "id": 1, "method": "tools/call", "params": {"name": "execute_command", "arguments": {"command": "echo Hello World"}}}' | ./mcp-terminal-server
```

## Configuration

### Environment Variables
```bash
# Set default timeout (seconds)
export MCP_COMMAND_TIMEOUT=60

# Set custom shell
export MCP_SHELL=/bin/zsh

# Start server
./mcp-terminal-server --http --port 8080
```

### Command Line Options
```bash
# Custom host and port
./mcp-terminal-server --http --host 0.0.0.0 --port 3000

# Show help
./mcp-terminal-server --help
```

## Examples

### Execute with Timeout
```bash
curl -X POST http://localhost:8080/mcp \
  -H "Content-Type: application/json" \
  -H "Mcp-Session-Id: <session-id>" \
  -d '{
    "jsonrpc": "2.0",
    "id": 7,
    "method": "tools/call",
    "params": {
      "name": "execute_command",
      "arguments": {
        "command": "sleep 2 && echo Done",
        "timeout": 5
      }
    }
  }'
```

### Execute with Custom Shell
```bash
curl -X POST http://localhost:8080/mcp \
  -H "Content-Type: application/json" \
  -H "Mcp-Session-Id: <session-id>" \
  -d '{
    "jsonrpc": "2.0",
    "id": 8,
    "method": "tools/call",
    "params": {
      "name": "execute_command",
      "arguments": {
        "command": "echo $0",
        "shell": "/bin/bash"
      }
    }
  }'
```

### Capture stderr Separately
```bash
curl -X POST http://localhost:8080/mcp \
  -H "Content-Type: application/json" \
  -H "Mcp-Session-Id: <session-id>" \
  -d '{
    "jsonrpc": "2.0",
    "id": 9,
    "method": "tools/call",
    "params": {
      "name": "execute_command",
      "arguments": {
        "command": "echo stdout && echo stderr >&2",
        "capture_stderr": true
      }
    }
  }'
```

## Integration with Vercel AI SDK

See [VERCEL_AI_SDK.md](VERCEL_AI_SDK.md) for complete integration examples.

## Key Features

✅ **No session pre-registration** - Use any session ID you want  
✅ **Three execution modes** - Non-persistent, persistent shell, and direct execution  
✅ **🎉 Persistent shell sessions** - Maintain shell state between commands  
✅ **Full MCP compatibility** - Works with all MCP clients  
✅ **Configurable timeouts** - Per-command or global defaults  
✅ **Platform support** - macOS and Linux  
✅ **Error handling** - Comprehensive error responses  
✅ **CORS enabled** - Ready for web integration  
✅ **Session management** - List and close active shell sessions  

## Troubleshooting

**Port already in use:**
```bash
./mcp-terminal-server --http --port 8081
```

**Permission denied:**
```bash
chmod +x mcp-terminal-server
```

**Command not found:**
```bash
./mcp-terminal-server --help
```

That's it! The server is now ready for both traditional MCP clients and modern web integrations using the standards-compliant StreamableHTTP transport.