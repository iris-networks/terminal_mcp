#!/bin/bash

# Persistent Shell Examples for MCP Terminal Server
# This script demonstrates the new persistent shell functionality

set -e

echo "🚀 MCP Terminal Server - Persistent Shell Examples"
echo "=================================================="

# Configuration
PORT=8080
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

# Function to execute persistent shell command
exec_persistent() {
    local session_id="$1"
    local command="$2"
    local description="$3"
    
    echo "📝 $description"
    echo "Session: $session_id | Command: $command"
    
    local result=$(curl -s -X POST "$SERVER_URL/message?sessionId=management" \
        -H "Content-Type: application/json" \
        -d "{
            \"jsonrpc\": \"2.0\",
            \"id\": $(date +%s),
            \"method\": \"tools/call\",
            \"params\": {
                \"name\": \"persistent_shell\",
                \"arguments\": {
                    \"command\": \"$command\",
                    \"session_id\": \"$session_id\"
                }
            }
        }")
    
    echo "📤 Output:"
    echo "$result" | jq -r '.result.content[0].text' | sed 's/^/    /'
    echo ""
}

# Function to list sessions
list_sessions() {
    echo "📋 Listing Active Sessions:"
    curl -s -X POST "$SERVER_URL/message?sessionId=management" \
        -H "Content-Type: application/json" \
        -d '{
            "jsonrpc": "2.0",
            "id": 1,
            "method": "tools/call",
            "params": {
                "name": "session_manager",
                "arguments": {
                    "action": "list"
                }
            }
        }' | jq -r '.result.content[0].text' | sed 's/^/    /'
    echo ""
}

# Example 1: Basic session persistence
echo "=== Example 1: Basic Session Persistence ==="
echo "Demonstrating how commands maintain state in the same session"
echo ""

exec_persistent "demo-session" "pwd" "Check current directory"
exec_persistent "demo-session" "mkdir -p myproject && cd myproject" "Create and enter directory"
exec_persistent "demo-session" "pwd" "Verify directory change persisted"
exec_persistent "demo-session" "echo 'Hello World' > hello.txt" "Create a file"
exec_persistent "demo-session" "ls -la" "List files to verify creation"
exec_persistent "demo-session" "cat hello.txt" "Read the file content"

# Example 2: Environment variables persistence
echo "=== Example 2: Environment Variables Persistence ==="
echo "Demonstrating how environment variables persist across commands"
echo ""

exec_persistent "env-session" "export PROJECT_NAME=MyApp" "Set environment variable"
exec_persistent "env-session" "export VERSION=1.0.0" "Set another environment variable"
exec_persistent "env-session" "echo \"Project: \$PROJECT_NAME v\$VERSION\"" "Use environment variables"
exec_persistent "env-session" "env | grep -E '(PROJECT_NAME|VERSION)'" "Show environment variables"

# Example 3: Multiple independent sessions
echo "=== Example 3: Multiple Independent Sessions ==="
echo "Demonstrating how different sessions are isolated from each other"
echo ""

exec_persistent "session-a" "cd /tmp && pwd" "Session A: Change to /tmp"
exec_persistent "session-b" "cd /Users && pwd" "Session B: Change to /Users (independent)"
exec_persistent "session-a" "pwd" "Session A: Still in /tmp"
exec_persistent "session-b" "pwd" "Session B: Still in /Users"

# Example 4: Working with development tools
echo "=== Example 4: Development Workflow ==="
echo "Demonstrating a typical development workflow"
echo ""

exec_persistent "dev-session" "cd /tmp && mkdir -p my-node-project && cd my-node-project" "Create project directory"
exec_persistent "dev-session" "npm init -y" "Initialize Node.js project"
exec_persistent "dev-session" "echo 'console.log(\"Hello from Node!\");' > index.js" "Create main file"
exec_persistent "dev-session" "node index.js" "Run the Node.js script"
exec_persistent "dev-session" "ls -la" "Show project files"

# Show session management
echo "=== Session Management ==="
list_sessions

# Example 5: Session cleanup
echo "=== Example 5: Session Cleanup ==="
echo "Demonstrating how to close specific sessions"
echo ""

echo "🗑️  Closing 'demo-session':"
curl -s -X POST "$SERVER_URL/message?sessionId=management" \
    -H "Content-Type: application/json" \
    -d '{
        "jsonrpc": "2.0",
        "id": 1,
        "method": "tools/call",
        "params": {
            "name": "session_manager",
            "arguments": {
                "action": "close",
                "session_id": "demo-session"
            }
        }
    }' | jq -r '.result.content[0].text' | sed 's/^/    /'
echo ""

echo "📋 Sessions after cleanup:"
list_sessions

# Example 6: Comparison with non-persistent execution
echo "=== Example 6: Comparison with Non-Persistent Execution ==="
echo "Showing the difference between persistent and non-persistent commands"
echo ""

echo "🔄 Non-persistent commands (each command starts fresh):"
echo ""

for i in {1..3}; do
    echo "Non-persistent command $i: pwd"
    curl -s -X POST "$SERVER_URL/message?sessionId=comparison" \
        -H "Content-Type: application/json" \
        -d '{
            "jsonrpc": "2.0",
            "id": 1,
            "method": "tools/call",
            "params": {
                "name": "execute_command",
                "arguments": {
                    "command": "cd /tmp && pwd"
                }
            }
        }' | jq -r '.result.content[0].text' | grep "Output:" | sed 's/^/    /'
done

echo ""
echo "🔗 Persistent commands (maintains state):"
echo ""

exec_persistent "persistent-comparison" "pwd" "Command 1: Check initial directory"
exec_persistent "persistent-comparison" "cd /tmp" "Command 2: Change to /tmp" 
exec_persistent "persistent-comparison" "pwd" "Command 3: Verify we're still in /tmp"

# Final session list
echo "=== Final Session Status ==="
list_sessions

echo "🎉 Persistent Shell Examples Completed!"
echo ""
echo "Key Features Demonstrated:"
echo "  ✅ Directory changes persist between commands"
echo "  ✅ Environment variables persist between commands"  
echo "  ✅ Multiple independent sessions can run simultaneously"
echo "  ✅ Each session maintains its own shell process (different PIDs)"
echo "  ✅ Sessions can be managed (listed and closed)"
echo "  ✅ Sessions automatically clean up after 30 minutes of inactivity"
echo ""
echo "Use Cases:"
echo "  🔨 Development workflows (npm, git, build tools)"
echo "  📁 File system navigation and manipulation"
echo "  🔧 Configuration and environment setup"
echo "  📊 Data processing pipelines"
echo "  🧪 Testing and debugging"run-http