#!/bin/bash

# Working HTTP Examples for MCP Terminal Server
# This script demonstrates the new HTTP mode with user-defined session IDs

set -e

echo "=== MCP Terminal Server HTTP Examples ==="

# Configuration
PORT=8090
HOST=localhost
SERVER_URL="http://$HOST:$PORT"

# Check if server is running
if ! curl -s "$SERVER_URL/" > /dev/null 2>&1; then
    echo "ERROR: Server not running at $SERVER_URL"
    echo "Start the server with: ./mcp-terminal-server -sse -port $PORT"
    exit 1
fi

echo "✅ Server is running at $SERVER_URL"
echo ""

# Show server info
echo "=== Server Information ==="
curl -s "$SERVER_URL/" | jq .
echo ""

# Example 1: List available tools
echo "=== Example 1: List Available Tools ==="
curl -s -X POST "$SERVER_URL/message?sessionId=session-001" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/list"
  }' | jq .
echo ""

# Example 2: Execute a simple command
echo "=== Example 2: Execute Simple Command ==="
curl -s -X POST "$SERVER_URL/message?sessionId=session-002" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/call",
    "params": {
      "name": "execute_command",
      "arguments": {
        "command": "echo Hello from HTTP!"
      }
    }
  }' | jq .
echo ""

# Example 3: Execute command with timeout
echo "=== Example 3: Execute Command with Timeout ==="
curl -s -X POST "$SERVER_URL/message?sessionId=session-003" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/call",
    "params": {
      "name": "execute_command",
      "arguments": {
        "command": "sleep 1 && echo Done!",
        "timeout": 5
      }
    }
  }' | jq .
echo ""

# Example 4: Execute command with custom shell
echo "=== Example 4: Execute Command with Custom Shell ==="
curl -s -X POST "$SERVER_URL/message?sessionId=session-004" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/call",
    "params": {
      "name": "execute_command",
      "arguments": {
        "command": "echo $0",
        "shell": "/bin/bash"
      }
    }
  }' | jq .
echo ""

# Example 5: Execute command with stderr capture
echo "=== Example 5: Execute Command with stderr Capture ==="
curl -s -X POST "$SERVER_URL/message?sessionId=session-005" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/call",
    "params": {
      "name": "execute_command",
      "arguments": {
        "command": "echo stdout && echo stderr >&2",
        "capture_stderr": true
      }
    }
  }' | jq .
echo ""

# Example 6: Direct execute endpoint (no session required)
echo "=== Example 6: Direct Execute Endpoint ==="
curl -s -X POST "$SERVER_URL/execute" \
  -H "Content-Type: application/json" \
  -d '{
    "params": {
      "name": "execute_command",
      "arguments": {
        "command": "pwd"
      }
    }
  }' | jq .
echo ""

# Example 7: Multiple commands with same session
echo "=== Example 7: Multiple Commands with Same Session ==="
SESSION_ID="persistent-session-$(date +%s)"
echo "Using session: $SESSION_ID"

echo "Command 1:"
curl -s -X POST "$SERVER_URL/message?sessionId=$SESSION_ID" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/call",
    "params": {
      "name": "execute_command",
      "arguments": {
        "command": "echo First command"
      }
    }
  }' | jq .

echo "Command 2:"
curl -s -X POST "$SERVER_URL/message?sessionId=$SESSION_ID" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 2,
    "method": "tools/call",
    "params": {
      "name": "execute_command",
      "arguments": {
        "command": "echo Second command"
      }
    }
  }' | jq .
echo ""

# Example 8: Error handling
echo "=== Example 8: Error Handling ==="
curl -s -X POST "$SERVER_URL/message?sessionId=error-session" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/call",
    "params": {
      "name": "execute_command",
      "arguments": {
        "command": "nonexistent_command_xyz"
      }
    }
  }' | jq .
echo ""

echo "=== All Examples Completed! ==="
echo ""
echo "🎉 The HTTP mode with user-defined session IDs is working perfectly!"
echo "   • Use any session ID you want - no pre-registration required"
echo "   • Session IDs are just identifiers for your convenience"
echo "   • Both /message and /execute endpoints are available"