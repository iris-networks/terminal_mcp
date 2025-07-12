#!/bin/bash

# Simple SSE Test - Demonstrates true Server-Sent Events
# This shows the correct SSE pattern: GET for events, POST for commands

set -e

echo "🌊 Simple SSE Test - True Server-Sent Events"
echo "============================================="

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

# Test 1: Basic SSE Connection (Pure Server-Sent Events)
echo "=== Test 1: Pure SSE Connection ==="
echo "🔗 Starting SSE connection (receive-only) for 10 seconds..."
echo "This is what SSE actually is - a one-way stream from server to client"
echo ""

timeout 10 curl -s -N \
    -H "Accept: text/event-stream" \
    -H "Cache-Control: no-cache" \
    "$SERVER_URL/sse?sessionId=pure-sse-test" &

SSE_PID=$!
echo "SSE client PID: $SSE_PID"
echo "SSE will run for 10 seconds, receiving heartbeats and connection events..."
echo ""

# Wait for SSE to finish
wait $SSE_PID 2>/dev/null || true
echo "✅ SSE connection completed"
echo ""

# Test 2: SSE + Command Execution (Proper Pattern)
echo "=== Test 2: SSE + Separate Command Execution ==="
echo "This demonstrates the correct pattern:"
echo "  1. SSE connection receives events (GET)"
echo "  2. Commands are sent via separate HTTP calls (POST)"
echo "  3. Commands should trigger events on the SSE stream"
echo ""

session_id="proper-sse-test"

# Start SSE listener in background
echo "🔊 Starting SSE listener..."
timeout 20 curl -s -N \
    -H "Accept: text/event-stream" \
    -H "Cache-Control: no-cache" \
    "$SERVER_URL/sse?sessionId=$session_id" > /tmp/sse_events.log 2>&1 &

SSE_PID=$!
echo "SSE listener PID: $SSE_PID"

# Give SSE time to connect
sleep 2

echo ""
echo "📤 Now sending commands via HTTP POST (while SSE listens)..."

# Send some commands
echo "Command 1: echo 'Hello SSE World'"
curl -s -X POST "$SERVER_URL/message?sessionId=$session_id" \
    -H "Content-Type: application/json" \
    -d '{
        "jsonrpc": "2.0",
        "id": 1,
        "method": "tools/call",
        "params": {
            "name": "execute_command",
            "arguments": {
                "command": "echo Hello SSE World"
            }
        }
    }' | jq -r '.result.content[0].text'

echo ""
echo "Command 2: pwd"
curl -s -X POST "$SERVER_URL/message?sessionId=$session_id" \
    -H "Content-Type: application/json" \
    -d '{
        "jsonrpc": "2.0",
        "id": 2,
        "method": "tools/call",
        "params": {
            "name": "execute_command",
            "arguments": {
                "command": "pwd"
            }
        }
    }' | jq -r '.result.content[0].text'

echo ""
echo "Command 3: date"
curl -s -X POST "$SERVER_URL/message?sessionId=$session_id" \
    -H "Content-Type: application/json" \
    -d '{
        "jsonrpc": "2.0",
        "id": 3,
        "method": "tools/call",
        "params": {
            "name": "execute_command",
            "arguments": {
                "command": "date"
            }
        }
    }' | jq -r '.result.content[0].text'

# Wait a bit for any events to be captured
sleep 5

# Stop SSE listener
if kill $SSE_PID 2>/dev/null; then
    echo "🛑 Stopped SSE listener"
fi

echo ""
echo "📋 SSE Events Received During Command Execution:"
if [ -f "/tmp/sse_events.log" ]; then
    cat "/tmp/sse_events.log"
    rm -f "/tmp/sse_events.log"
else
    echo "No SSE events file found"
fi

echo ""
echo "=== Analysis ==="
echo "✅ SSE connection: GET request, receives server events"
echo "✅ Command execution: POST requests, triggers actions"
echo "❓ Expected: Commands should trigger events on SSE stream"
echo "❓ Current: SSE only shows heartbeats (implementation needs command event broadcasting)"
echo ""
echo "🎯 This is the CORRECT SSE pattern!"
echo "   SSE = Server pushes events to client (one-way)"
echo "   Commands = Client sends requests to server (separate channel)"