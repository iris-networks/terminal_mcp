package main

import (
	"fmt"
	"log"
	"net/http"

	"github.com/mark3labs/mcp-go/server"
	"mcp-terminal-server/internal/config"
	"mcp-terminal-server/internal/executor"
	"mcp-terminal-server/internal/handlers"
	"mcp-terminal-server/internal/session"
	"mcp-terminal-server/internal/tools"
)

func main() {
	// Initialize configuration
	cfg := config.NewConfig()
	cfg.ParseFlags()

	// Initialize components
	sessionManager := session.NewManager(cfg)
	exec := executor.New(cfg)
	toolsRegistry := tools.NewRegistry(cfg, sessionManager, exec)

	// Create MCP server
	mcpServer := server.NewMCPServer(
		"Terminal Command Executor",
		"1.0.0",
		server.WithToolCapabilities(false),
		server.WithRecovery(),
	)

	// Register tools
	toolsRegistry.RegisterTools(mcpServer)

	// Log startup information
	log.Printf("Starting MCP Terminal Server on platform: %s", cfg.Platform)
	log.Printf("Default timeout: %v", cfg.DefaultTimeout)
	log.Printf("Default shell: %s", cfg.Shell)

	if cfg.SSEMode {
		// HTTP mode
		log.Printf("Starting HTTP server on %s:%s", cfg.Host, cfg.Port)

		// Create HTTP server
		httpServer := handlers.NewHTTPServer(cfg, toolsRegistry, sessionManager, exec)

		// Setup HTTP routes
		mux := http.NewServeMux()
		httpServer.SetupRoutes(mux)

		addr := fmt.Sprintf("%s:%s", cfg.Host, cfg.Port)
		log.Printf("Server endpoints:")
		log.Printf("  Info: http://%s/", addr)
		log.Printf("  Execute: http://%s/execute (direct command execution)", addr)
		log.Printf("  Message: http://%s/message?sessionId=<any-id> (MCP protocol)", addr)

		if err := http.ListenAndServe(addr, mux); err != nil {
			log.Fatalf("HTTP server error: %v", err)
		}
	} else {
		// STDIO mode
		log.Printf("Starting STDIO server")
		if err := server.ServeStdio(mcpServer); err != nil {
			log.Fatalf("STDIO server error: %v", err)
		}
	}
}