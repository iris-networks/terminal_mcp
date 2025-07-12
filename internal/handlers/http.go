package handlers

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"
	"crypto/rand"
	"encoding/hex"

	"github.com/mark3labs/mcp-go/mcp"
	"mcp-terminal-server/internal/config"
	"mcp-terminal-server/internal/executor"
	"mcp-terminal-server/internal/session"
	"mcp-terminal-server/internal/tools"
	"mcp-terminal-server/internal/sse"
)

// HTTPServer handles HTTP requests for the MCP server
type HTTPServer struct {
	config      *config.Config
	toolsRegistry *tools.Registry
	sessionManager *session.Manager
	executor    *executor.Executor
	broadcaster *sse.Broadcaster
}

// NewHTTPServer creates a new HTTP server
func NewHTTPServer(cfg *config.Config, toolsReg *tools.Registry, sm *session.Manager, exec *executor.Executor) *HTTPServer {
	return &HTTPServer{
		config:         cfg,
		toolsRegistry:  toolsReg,
		sessionManager: sm,
		executor:       exec,
		broadcaster:    sse.NewBroadcaster(),
	}
}

// SetupRoutes sets up all HTTP routes
func (h *HTTPServer) SetupRoutes(mux *http.ServeMux) {
	// Info endpoint
	mux.HandleFunc("/", h.handleInfo)

	// Direct execute endpoint - no session ID required
	mux.HandleFunc("/execute", h.handleDirectExecute)

	// Message endpoint - accepts any session ID
	mux.HandleFunc("/message", h.handleMessage)

	// SSE endpoint - Server-Sent Events
	mux.HandleFunc("/sse", h.handleSSE)
}

// handleInfo returns server information
func (h *HTTPServer) handleInfo(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	fmt.Fprintf(w, `{
		"name": "Terminal Command Executor",
		"version": "1.0.0",
		"description": "MCP server for executing terminal commands",
		"endpoints": {
			"execute": "/execute",
			"message": "/message",
			"sse": "/sse"
		},
		"platform": "%s",
		"shell": "%s",
		"session_info": "Use any session ID you want - no pre-registration required"
	}`, h.config.Platform, h.config.Shell)
}

// handleDirectExecute handles direct command execution without session management
func (h *HTTPServer) handleDirectExecute(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	h.setCORSHeaders(w)

	if r.Method == "OPTIONS" {
		w.WriteHeader(http.StatusOK)
		return
	}

	var req mcp.CallToolRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, fmt.Sprintf("Invalid JSON: %v", err), http.StatusBadRequest)
		return
	}

	// Execute the command using the executor
	result, err := h.executor.Execute(req)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(result)
}

// handleMessage handles MCP protocol messages
func (h *HTTPServer) handleMessage(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	h.setCORSHeaders(w)

	if r.Method == "OPTIONS" {
		w.WriteHeader(http.StatusOK)
		return
	}

	// Get session ID from query parameter - accept any value
	sessionID := r.URL.Query().Get("sessionId")
	if sessionID == "" {
		http.Error(w, "Missing sessionId parameter", http.StatusBadRequest)
		return
	}

	log.Printf("Processing request for session: %s", sessionID)

	var jsonReq map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&jsonReq); err != nil {
		http.Error(w, fmt.Sprintf("Invalid JSON: %v", err), http.StatusBadRequest)
		return
	}

	// Handle different MCP methods
	method, ok := jsonReq["method"].(string)
	if !ok {
		http.Error(w, "Missing method", http.StatusBadRequest)
		return
	}

	var response interface{}
	id := jsonReq["id"]

	switch method {
	case "tools/list":
		response = map[string]interface{}{
			"jsonrpc": "2.0",
			"id":      id,
			"result": map[string]interface{}{
				"tools": h.toolsRegistry.GetToolSchemas(),
			},
		}

	case "tools/call":
		response = h.handleToolCall(jsonReq, id)

	default:
		http.Error(w, fmt.Sprintf("Unknown method: %s", method), http.StatusBadRequest)
		return
	}

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(response)
}

// handleToolCall handles tool execution requests
func (h *HTTPServer) handleToolCall(jsonReq map[string]interface{}, id interface{}) map[string]interface{} {
	params, ok := jsonReq["params"].(map[string]interface{})
	if !ok {
		return h.createErrorResponse(id, -32600, "Missing params")
	}

	toolName, ok := params["name"].(string)
	if !ok {
		return h.createErrorResponse(id, -32600, "Missing tool name")
	}

	args, ok := params["arguments"].(map[string]interface{})
	if !ok {
		return h.createErrorResponse(id, -32600, "Missing arguments")
	}

	// Create CallToolRequest
	req := mcp.CallToolRequest{
		Params: mcp.CallToolParams{
			Name:      toolName,
			Arguments: args,
		},
	}

	// Execute the appropriate tool
	var result *mcp.CallToolResult
	var err error

	switch toolName {
	case "execute_command":
		result, err = h.executor.Execute(req)
	case "persistent_shell":
		result, err = h.handlePersistentShellCall(args)
	case "session_manager":
		result, err = h.handleSessionManagerCall(args)
	default:
		result = mcp.NewToolResultError(fmt.Sprintf("Unknown tool: %s", toolName))
	}

	if err != nil {
		return h.createErrorResponse(id, -32603, err.Error())
	}

	return map[string]interface{}{
		"jsonrpc": "2.0",
		"id":      id,
		"result":  result,
	}
}

// handlePersistentShellCall handles persistent shell command execution
func (h *HTTPServer) handlePersistentShellCall(args map[string]interface{}) (*mcp.CallToolResult, error) {
	command, ok := args["command"].(string)
	if !ok || command == "" {
		return mcp.NewToolResultError("Command is required"), nil
	}

	sessionID, ok := args["session_id"].(string)
	if !ok || sessionID == "" {
		return mcp.NewToolResultError("Session ID is required"), nil
	}

	// Get timeout
	timeout := h.config.DefaultTimeout
	if timeoutArg, ok := args["timeout"].(float64); ok && timeoutArg > 0 {
		timeout = time.Duration(timeoutArg) * time.Second
	}

	// Get shell
	shell := h.config.Shell
	if shellArg, ok := args["shell"].(string); ok && shellArg != "" {
		shell = shellArg
	}

	return h.sessionManager.ExecuteCommand(sessionID, command, timeout, shell, false)
}

// handleSessionManagerCall handles session management operations
func (h *HTTPServer) handleSessionManagerCall(args map[string]interface{}) (*mcp.CallToolResult, error) {
	action, ok := args["action"].(string)
	if !ok || action == "" {
		return mcp.NewToolResultError("Action is required"), nil
	}

	switch action {
	case "list":
		sessions := h.sessionManager.ListSessions()
		if len(sessions) == 0 {
			return mcp.NewToolResultText("No active sessions"), nil
		}

		resultText := "Active Sessions:\n"
		for id, info := range sessions {
			infoMap := info.(map[string]interface{})
			resultText += fmt.Sprintf("- %s: %s (PID: %v, Created: %s, Last Used: %s, Alive: %v)\n",
				id, infoMap["shell"], infoMap["pid"], infoMap["created"], infoMap["last_used"], infoMap["alive"])
		}

		return mcp.NewToolResultText(resultText), nil

	case "close":
		sessionID, ok := args["session_id"].(string)
		if !ok || sessionID == "" {
			return mcp.NewToolResultError("Session ID is required for close action"), nil
		}

		if err := h.sessionManager.CloseSession(sessionID); err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("Failed to close session: %v", err)), nil
		}

		return mcp.NewToolResultText(fmt.Sprintf("Session closed: %s", sessionID)), nil

	default:
		return mcp.NewToolResultError(fmt.Sprintf("Unknown action: %s", action)), nil
	}
}

// setCORSHeaders sets CORS headers for web integration
func (h *HTTPServer) setCORSHeaders(w http.ResponseWriter) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
}

// createErrorResponse creates a JSON-RPC error response
func (h *HTTPServer) createErrorResponse(id interface{}, code int, message string) map[string]interface{} {
	return map[string]interface{}{
		"jsonrpc": "2.0",
		"id":      id,
		"error": map[string]interface{}{
			"code":    code,
			"message": message,
		},
	}
}

// generateClientID generates a random client ID
func generateClientID() string {
	bytes := make([]byte, 8)
	rand.Read(bytes)
	return hex.EncodeToString(bytes)
}

// handleSSE handles Server-Sent Events connections
func (h *HTTPServer) handleSSE(w http.ResponseWriter, r *http.Request) {
	// Only allow GET requests for SSE
	if r.Method != "GET" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Get session ID from query parameter
	sessionID := r.URL.Query().Get("sessionId")
	if sessionID == "" {
		http.Error(w, "Missing sessionId parameter", http.StatusBadRequest)
		return
	}

	// Set SSE headers
	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Headers", "Cache-Control, Accept")
	w.Header().Set("Access-Control-Allow-Methods", "GET, OPTIONS")

	// Ensure we can flush responses
	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "Streaming unsupported", http.StatusInternalServerError)
		return
	}

	// Generate unique client ID and add to broadcaster
	clientID := generateClientID()
	client := h.broadcaster.AddClient(clientID, sessionID)
	defer h.broadcaster.RemoveClient(clientID)

	// Send initial connection event
	initialEvent := sse.Event{
		Type:      "connected",
		SessionID: sessionID,
		Data: map[string]interface{}{
			"message":   "SSE connection established",
			"clientId":  clientID,
			"sessionId": sessionID,
		},
		Timestamp: time.Now().Format(time.RFC3339),
	}
	fmt.Fprint(w, sse.FormatSSEMessage(initialEvent))
	flusher.Flush()

	// Create context and heartbeat ticker
	ctx := r.Context()
	heartbeatTicker := time.NewTicker(30 * time.Second)
	defer heartbeatTicker.Stop()

	log.Printf("SSE client %s connected for session: %s", clientID, sessionID)

	// Event loop
	for {
		select {
		case <-ctx.Done():
			// Client disconnected
			log.Printf("SSE client %s disconnected for session: %s", clientID, sessionID)
			return

		case event := <-client.Channel:
			// Received event from broadcaster
			fmt.Fprint(w, sse.FormatSSEMessage(event))
			flusher.Flush()

		case <-heartbeatTicker.C:
			// Send heartbeat
			heartbeatEvent := sse.Event{
				Type:      "heartbeat",
				SessionID: sessionID,
				Data: map[string]interface{}{
					"message": "heartbeat",
					"clients": h.broadcaster.GetSessionClients(sessionID),
				},
				Timestamp: time.Now().Format(time.RFC3339),
			}
			fmt.Fprint(w, sse.FormatSSEMessage(heartbeatEvent))
			flusher.Flush()
		}
	}
}