#!/bin/bash

# SSE Examples for MCP Terminal Server
# This script demonstrates Server-Sent Events (SSE) functionality

set -e

echo "🌊 MCP Terminal Server - SSE Examples"
echo "====================================="

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

# Function to create SSE client test
test_sse_connection() {
    local session_id="$1"
    local description="$2"
    
    echo "🔗 $description"
    echo "Session: $session_id"
    echo "SSE URL: $SERVER_URL/sse?sessionId=$session_id"
    
    # Test SSE connection with curl
    echo "📡 Testing SSE connection (5 second timeout)..."
    timeout 5 curl -s -N \
        -H "Accept: text/event-stream" \
        -H "Cache-Control: no-cache" \
        "$SERVER_URL/sse?sessionId=$session_id" || true
    
    echo ""
    echo "✅ SSE connection test completed"
    echo ""
}

# Function to send command via SSE
send_sse_command() {
    local session_id="$1"
    local command="$2"
    local description="$3"
    
    echo "📤 $description"
    echo "Session: $session_id | Command: $command"
    
    # Send command via POST while potentially having SSE connection open
    curl -s -X POST "$SERVER_URL/message?sessionId=$session_id" \
        -H "Content-Type: application/json" \
        -d "{
            \"jsonrpc\": \"2.0\",
            \"id\": $(date +%s),
            \"method\": \"tools/call\",
            \"params\": {
                \"name\": \"execute_command\",
                \"arguments\": {
                    \"command\": \"$command\"
                }
            }
        }" | jq -r '.result.content[0].text' | sed 's/^/    /'
    
    echo ""
}

# Function to demonstrate SSE with background listener
test_sse_with_background_listener() {
    local session_id="$1"
    local description="$2"
    
    echo "🎯 $description"
    echo "Session: $session_id"
    
    # Start SSE listener in background
    echo "🔊 Starting SSE listener in background..."
    timeout 10 curl -s -N \
        -H "Accept: text/event-stream" \
        -H "Cache-Control: no-cache" \
        "$SERVER_URL/sse?sessionId=$session_id" > /tmp/sse_output_$session_id.log 2>&1 &
    
    SSE_PID=$!
    echo "SSE listener PID: $SSE_PID"
    
    # Give the SSE connection time to establish
    sleep 2
    
    # Send some commands
    echo "📤 Sending commands while SSE is listening..."
    send_sse_command "$session_id" "echo 'Hello from SSE test!'" "Test command 1"
    send_sse_command "$session_id" "date" "Test command 2"
    send_sse_command "$session_id" "pwd" "Test command 3"
    
    # Wait a bit for SSE to capture events
    sleep 3
    
    # Stop SSE listener
    if kill $SSE_PID 2>/dev/null; then
        echo "🛑 Stopped SSE listener"
    fi
    
    # Show SSE output if available
    if [ -f "/tmp/sse_output_$session_id.log" ]; then
        echo "📋 SSE Events Received:"
        cat "/tmp/sse_output_$session_id.log" | sed 's/^/    /'
        rm -f "/tmp/sse_output_$session_id.log"
    fi
    
    echo ""
}

# Example 1: Basic SSE connection test
echo "=== Example 1: Basic SSE Connection Test ==="
echo "Testing if SSE endpoint is available and responsive"
echo ""

test_sse_connection "sse-test-1" "Basic SSE connection check"

# Example 2: SSE with command execution
echo "=== Example 2: SSE with Command Execution ==="
echo "Testing SSE while sending commands to the same session"
echo ""

test_sse_with_background_listener "sse-cmd-test" "SSE with command execution"

# Example 3: Multiple SSE connections
echo "=== Example 3: Multiple SSE Sessions ==="
echo "Testing multiple independent SSE connections"
echo ""

echo "🔀 Testing multiple SSE sessions simultaneously..."
for i in {1..3}; do
    session_id="multi-sse-$i"
    echo "Session $i: $session_id"
    
    # Test each SSE connection briefly
    timeout 3 curl -s -N \
        -H "Accept: text/event-stream" \
        -H "Cache-Control: no-cache" \
        "$SERVER_URL/sse?sessionId=$session_id" > /tmp/sse_multi_$i.log 2>&1 &
    
    PIDS[$i]=$!
done

echo "Started ${#PIDS[@]} SSE connections"
sleep 5

# Send commands to each session
for i in {1..3}; do
    session_id="multi-sse-$i"
    send_sse_command "$session_id" "echo 'Message from session $i'" "Command to session $i"
done

sleep 2

# Clean up
for i in {1..3}; do
    if [ -n "${PIDS[$i]}" ]; then
        kill ${PIDS[$i]} 2>/dev/null || true
    fi
    if [ -f "/tmp/sse_multi_$i.log" ]; then
        echo "Session $i SSE output:"
        cat "/tmp/sse_multi_$i.log" | head -10 | sed 's/^/    /'
        rm -f "/tmp/sse_multi_$i.log"
    fi
done

echo ""

# Example 4: SSE Error Handling
echo "=== Example 4: SSE Error Handling ==="
echo "Testing SSE behavior with invalid session IDs and error conditions"
echo ""

echo "🚫 Testing SSE with missing session ID..."
timeout 3 curl -s -N \
    -H "Accept: text/event-stream" \
    -H "Cache-Control: no-cache" \
    "$SERVER_URL/sse" || echo "Expected error: missing sessionId"

echo ""
echo "🚫 Testing SSE with invalid endpoint..."
timeout 3 curl -s -N \
    -H "Accept: text/event-stream" \
    -H "Cache-Control: no-cache" \
    "$SERVER_URL/invalid-sse?sessionId=test" || echo "Expected error: invalid endpoint"

echo ""

# Example 5: SSE Persistent Shell Integration
echo "=== Example 5: SSE with Persistent Shell ==="
echo "Testing SSE with persistent shell commands"
echo ""

session_id="sse-persistent"
echo "🔗 Testing SSE with persistent shell session: $session_id"

# Start SSE listener
timeout 15 curl -s -N \
    -H "Accept: text/event-stream" \
    -H "Cache-Control: no-cache" \
    "$SERVER_URL/sse?sessionId=$session_id" > /tmp/sse_persistent.log 2>&1 &

SSE_PID=$!
sleep 2

# Send persistent shell commands
echo "📤 Sending persistent shell commands..."
curl -s -X POST "$SERVER_URL/message?sessionId=$session_id" \
    -H "Content-Type: application/json" \
    -d '{
        "jsonrpc": "2.0",
        "id": 1,
        "method": "tools/call",
        "params": {
            "name": "persistent_shell",
            "arguments": {
                "command": "pwd",
                "session_id": "sse-shell-session"
            }
        }
    }' | jq -r '.result.content[0].text' | sed 's/^/    /'

curl -s -X POST "$SERVER_URL/message?sessionId=$session_id" \
    -H "Content-Type: application/json" \
    -d '{
        "jsonrpc": "2.0",
        "id": 2,
        "method": "tools/call",
        "params": {
            "name": "persistent_shell",
            "arguments": {
                "command": "cd /tmp && pwd",
                "session_id": "sse-shell-session"
            }
        }
    }' | jq -r '.result.content[0].text' | sed 's/^/    /'

sleep 5

# Stop SSE and show output
if kill $SSE_PID 2>/dev/null; then
    echo "🛑 Stopped SSE listener"
fi

if [ -f "/tmp/sse_persistent.log" ]; then
    echo "📋 SSE Events from Persistent Shell:"
    cat "/tmp/sse_persistent.log" | sed 's/^/    /'
    rm -f "/tmp/sse_persistent.log"
fi

echo ""

# Example 6: SSE Performance Test
echo "=== Example 6: SSE Performance Test ==="
echo "Testing SSE with rapid command execution"
echo ""

session_id="sse-performance"
echo "⚡ Testing SSE performance with rapid commands"

# Start SSE listener
timeout 20 curl -s -N \
    -H "Accept: text/event-stream" \
    -H "Cache-Control: no-cache" \
    "$SERVER_URL/sse?sessionId=$session_id" > /tmp/sse_perf.log 2>&1 &

SSE_PID=$!
sleep 2

echo "📤 Sending 10 rapid commands..."
for i in {1..10}; do
    curl -s -X POST "$SERVER_URL/message?sessionId=$session_id" \
        -H "Content-Type: application/json" \
        -d "{
            \"jsonrpc\": \"2.0\",
            \"id\": $i,
            \"method\": \"tools/call\",
            \"params\": {
                \"name\": \"execute_command\",
                \"arguments\": {
                    \"command\": \"echo 'Rapid command $i - $(date +%s.%3N)'\"
                }
            }
        }" > /dev/null &
done

wait  # Wait for all background curl commands to complete
sleep 5

# Stop SSE and show output
if kill $SSE_PID 2>/dev/null; then
    echo "🛑 Stopped SSE listener"
fi

if [ -f "/tmp/sse_perf.log" ]; then
    echo "📊 SSE Performance Test Results:"
    cat "/tmp/sse_perf.log" | wc -l | sed 's/^/    Total events: /'
    echo "    Sample events:"
    cat "/tmp/sse_perf.log" | head -20 | sed 's/^/    /'
    rm -f "/tmp/sse_perf.log"
fi

echo ""

# Summary
echo "=== SSE Testing Summary ==="
echo ""
echo "🎉 SSE Examples Completed!"
echo ""
echo "Tests Performed:"
echo "  ✅ Basic SSE connection"
echo "  ✅ SSE with command execution"
echo "  ✅ Multiple SSE sessions"
echo "  ✅ SSE error handling"
echo "  ✅ SSE with persistent shell"
echo "  ✅ SSE performance testing"
echo ""
echo "📝 SSE Endpoint: $SERVER_URL/sse?sessionId=<session-id>"
echo "📝 Headers required: Accept: text/event-stream, Cache-Control: no-cache"
echo ""
echo "🔧 If SSE is not working, check:"
echo "  • Server started with -sse flag"
echo "  • SSE endpoint implemented in server"
echo "  • Proper headers sent"
echo "  • Network connectivity"
echo ""

# Clean up any remaining temp files
rm -f /tmp/sse_*.log