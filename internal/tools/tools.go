package tools

import (
	"context"
	"fmt"
	"time"

	"github.com/mark3labs/mcp-go/mcp"
	"github.com/mark3labs/mcp-go/server"
	"mcp-terminal-server/internal/config"
	"mcp-terminal-server/internal/executor"
	"mcp-terminal-server/internal/session"
)

// Registry holds all the tools and their dependencies
type Registry struct {
	config         *config.Config
	sessionManager *session.Manager
	executor       *executor.Executor
}

// NewRegistry creates a new tools registry
func NewRegistry(cfg *config.Config, sm *session.Manager, exec *executor.Executor) *Registry {
	return &Registry{
		config:         cfg,
		sessionManager: sm,
		executor:       exec,
	}
}

// RegisterTools registers all tools with the MCP server
func (r *Registry) RegisterTools(s *server.MCPServer) {
	// Register execute_command tool
	executeCommandTool := mcp.NewTool("execute_command",
		mcp.WithDescription("Execute terminal commands with configurable timeout (non-persistent)"),
		mcp.WithString("command",
			mcp.Required(),
			mcp.Description("The command to execute"),
		),
		mcp.WithNumber("timeout",
			mcp.Description("Timeout in seconds (optional, defaults to 30)"),
		),
		mcp.WithString("shell",
			mcp.Description("Shell to use for execution (optional, defaults to system shell)"),
		),
		mcp.WithBoolean("capture_stderr",
			mcp.Description("Whether to capture stderr separately (optional, defaults to false)"),
		),
	)

	// Register persistent_shell tool
	persistentShellTool := mcp.NewTool("persistent_shell",
		mcp.WithDescription("Execute commands in persistent shell sessions - maintains state between commands"),
		mcp.WithString("command",
			mcp.Required(),
			mcp.Description("The command to execute"),
		),
		mcp.WithString("session_id",
			mcp.Required(),
			mcp.Description("Session ID to maintain persistent shell state"),
		),
		mcp.WithNumber("timeout",
			mcp.Description("Timeout in seconds (optional, defaults to 30)"),
		),
		mcp.WithString("shell",
			mcp.Description("Shell to use for execution (optional, defaults to system shell)"),
		),
	)

	// Register session_manager tool
	sessionTool := mcp.NewTool("session_manager",
		mcp.WithDescription("Manage persistent shell sessions"),
		mcp.WithString("action",
			mcp.Required(),
			mcp.Description("Action: 'list' to show sessions, 'close' to close a session"),
			mcp.Enum("list", "close"),
		),
		mcp.WithString("session_id",
			mcp.Description("Session ID (required for 'close' action)"),
		),
	)

	// Add tool handlers
	s.AddTool(executeCommandTool, r.handleExecuteCommand)
	s.AddTool(persistentShellTool, r.handlePersistentShell)
	s.AddTool(sessionTool, r.handleSessionManager)
}

// handleExecuteCommand handles non-persistent command execution
func (r *Registry) handleExecuteCommand(ctx context.Context, request mcp.CallToolRequest) (*mcp.CallToolResult, error) {
	return r.executor.Execute(request)
}

// handlePersistentShell handles persistent shell command execution
func (r *Registry) handlePersistentShell(ctx context.Context, request mcp.CallToolRequest) (*mcp.CallToolResult, error) {
	args := request.GetArguments()

	command, ok := args["command"].(string)
	if !ok || command == "" {
		return mcp.NewToolResultError("Command is required"), nil
	}

	sessionID, ok := args["session_id"].(string)
	if !ok || sessionID == "" {
		return mcp.NewToolResultError("Session ID is required"), nil
	}

	// Get timeout
	timeout := r.config.DefaultTimeout
	if timeoutArg, ok := args["timeout"].(float64); ok && timeoutArg > 0 {
		timeout = time.Duration(timeoutArg) * time.Second
	}

	// Get shell
	shell := r.config.Shell
	if shellArg, ok := args["shell"].(string); ok && shellArg != "" {
		shell = shellArg
	}

	return r.sessionManager.ExecuteCommand(sessionID, command, timeout, shell, false)
}

// handleSessionManager handles session management operations
func (r *Registry) handleSessionManager(ctx context.Context, request mcp.CallToolRequest) (*mcp.CallToolResult, error) {
	args := request.GetArguments()

	action, ok := args["action"].(string)
	if !ok || action == "" {
		return mcp.NewToolResultError("Action is required"), nil
	}

	switch action {
	case "list":
		sessions := r.sessionManager.ListSessions()
		if len(sessions) == 0 {
			return mcp.NewToolResultText("No active sessions"), nil
		}

		result := "Active Sessions:\n"
		for id, info := range sessions {
			infoMap := info.(map[string]interface{})
			result += fmt.Sprintf("- %s: %s (PID: %v, Created: %s, Last Used: %s, Alive: %v)\n",
				id, infoMap["shell"], infoMap["pid"], infoMap["created"], infoMap["last_used"], infoMap["alive"])
		}

		return mcp.NewToolResultText(result), nil

	case "close":
		sessionID, ok := args["session_id"].(string)
		if !ok || sessionID == "" {
			return mcp.NewToolResultError("Session ID is required for close action"), nil
		}

		if err := r.sessionManager.CloseSession(sessionID); err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("Failed to close session: %v", err)), nil
		}

		return mcp.NewToolResultText(fmt.Sprintf("Session closed: %s", sessionID)), nil

	default:
		return mcp.NewToolResultError(fmt.Sprintf("Unknown action: %s", action)), nil
	}
}

// GetToolSchemas returns the tool schemas for HTTP handlers
func (r *Registry) GetToolSchemas() []map[string]interface{} {
	return []map[string]interface{}{
		{
			"name":        "execute_command",
			"description": "Execute terminal commands with configurable timeout (non-persistent)",
			"inputSchema": map[string]interface{}{
				"type": "object",
				"properties": map[string]interface{}{
					"command": map[string]interface{}{
						"type":        "string",
						"description": "The command to execute",
					},
					"timeout": map[string]interface{}{
						"type":        "number",
						"description": "Timeout in seconds (optional, defaults to 30)",
					},
					"shell": map[string]interface{}{
						"type":        "string",
						"description": "Shell to use for execution (optional, defaults to system shell)",
					},
					"capture_stderr": map[string]interface{}{
						"type":        "boolean",
						"description": "Whether to capture stderr separately (optional, defaults to false)",
					},
				},
				"required": []string{"command"},
			},
		},
		{
			"name":        "persistent_shell",
			"description": "Execute commands in persistent shell sessions - maintains state between commands",
			"inputSchema": map[string]interface{}{
				"type": "object",
				"properties": map[string]interface{}{
					"command": map[string]interface{}{
						"type":        "string",
						"description": "The command to execute",
					},
					"session_id": map[string]interface{}{
						"type":        "string",
						"description": "Session ID to maintain persistent shell state",
					},
					"timeout": map[string]interface{}{
						"type":        "number",
						"description": "Timeout in seconds (optional, defaults to 30)",
					},
					"shell": map[string]interface{}{
						"type":        "string",
						"description": "Shell to use for execution (optional, defaults to system shell)",
					},
				},
				"required": []string{"command", "session_id"},
			},
		},
		{
			"name":        "session_manager",
			"description": "Manage persistent shell sessions",
			"inputSchema": map[string]interface{}{
				"type": "object",
				"properties": map[string]interface{}{
					"action": map[string]interface{}{
						"type":        "string",
						"description": "Action: 'list' to show sessions, 'close' to close a session",
						"enum":        []string{"list", "close"},
					},
					"session_id": map[string]interface{}{
						"type":        "string",
						"description": "Session ID (required for 'close' action)",
					},
				},
				"required": []string{"action"},
			},
		},
	}
}