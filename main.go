package main

import (
	"fmt"
	"log"

	"github.com/mark3labs/mcp-go/server"
	"mcp-terminal-server/internal/config"
	"mcp-terminal-server/internal/executor"
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

	if cfg.HTTPMode {
		// HTTP mode with StreamableHTTP transport
		addr := fmt.Sprintf("%s:%s", cfg.Host, cfg.Port)
		log.Printf("Starting StreamableHTTP server on %s", addr)

		// Create StreamableHTTP server
		streamableServer := server.NewStreamableHTTPServer(mcpServer)

		log.Printf("Server endpoint:")
		log.Printf("  MCP: http://%s/mcp (StreamableHTTP transport)", addr)

		if err := streamableServer.Start(addr); err != nil {
			log.Fatalf("StreamableHTTP server error: %v", err)
		}
	} else {
		// STDIO mode
		log.Printf("Starting STDIO server")
		if err := server.ServeStdio(mcpServer); err != nil {
			log.Fatalf("STDIO server error: %v", err)
		}
	}
}