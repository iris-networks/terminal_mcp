package executor

import (
	"context"
	"fmt"
	"os/exec"
	"strings"
	"time"

	"github.com/mark3labs/mcp-go/mcp"
	"mcp-terminal-server/internal/config"
)

// Executor handles non-persistent command execution
type Executor struct {
	config *config.Config
}

// New creates a new executor
func New(cfg *config.Config) *Executor {
	return &Executor{
		config: cfg,
	}
}

// Execute executes a command in a non-persistent manner
func (e *Executor) Execute(request mcp.CallToolRequest) (*mcp.CallToolResult, error) {
	args := request.GetArguments()

	command, ok := args["command"].(string)
	if !ok || command == "" {
		return mcp.NewToolResultError("Command is required"), nil
	}

	// Get timeout
	timeout := e.config.DefaultTimeout
	if timeoutArg, ok := args["timeout"].(float64); ok && timeoutArg > 0 {
		timeout = time.Duration(timeoutArg) * time.Second
	}

	// Get shell
	shell := e.config.Shell
	if shellArg, ok := args["shell"].(string); ok && shellArg != "" {
		shell = shellArg
	}

	// Get capture_stderr option
	captureStderr := false
	if captureStderrArg, ok := args["capture_stderr"].(bool); ok {
		captureStderr = captureStderrArg
	}

	// Create context with timeout
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	// Execute command
	var cmd *exec.Cmd
	switch e.config.Platform {
	case "darwin", "linux":
		cmd = exec.CommandContext(ctx, shell, "-c", command)
	default:
		return mcp.NewToolResultError(fmt.Sprintf("Platform %s not supported", e.config.Platform)), nil
	}

	var stdout, stderr strings.Builder
	cmd.Stdout = &stdout

	if captureStderr {
		cmd.Stderr = &stderr
	} else {
		cmd.Stderr = &stdout
	}

	err := cmd.Run()

	result := map[string]interface{}{
		"stdout":          stdout.String(),
		"platform":        e.config.Platform,
		"shell":           shell,
		"timeout_seconds": timeout.Seconds(),
		"command":         command,
	}

	if captureStderr {
		result["stderr"] = stderr.String()
	}

	if err != nil {
		result["error"] = err.Error()
		if exitErr, ok := err.(*exec.ExitError); ok {
			result["exit_code"] = exitErr.ExitCode()
		}
	} else {
		result["exit_code"] = 0
	}

	return mcp.NewToolResultText(fmt.Sprintf("Command executed.\nOutput: %s\nExit Code: %v\nPlatform: %s\nShell: %s",
		result["stdout"], result["exit_code"], result["platform"], result["shell"])), nil
}