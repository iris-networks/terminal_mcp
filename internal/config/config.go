package config

import (
	"flag"
	"os"
	"runtime"
	"strconv"
	"time"
)

// Config holds the server configuration
type Config struct {
	DefaultTimeout time.Duration
	Platform       string
	Shell          string
	SSEMode        bool
	Port           string
	Host           string
}

// NewConfig creates a new configuration with defaults
func NewConfig() *Config {
	cfg := &Config{
		DefaultTimeout: 30 * time.Second,
		Platform:       runtime.GOOS,
		SSEMode:        false,
		Port:           "8080",
		Host:           "localhost",
	}

	switch cfg.Platform {
	case "darwin", "linux":
		cfg.Shell = "/bin/bash"
	default:
		cfg.Shell = "/bin/sh"
	}

	return cfg
}

// ParseFlags parses command line flags and environment variables
func (c *Config) ParseFlags() {
	var (
		sseMode = flag.Bool("sse", false, "Enable SSE mode (HTTP server)")
		port    = flag.String("port", "8080", "Port for SSE server")
		host    = flag.String("host", "localhost", "Host for SSE server")
		help    = flag.Bool("help", false, "Show help")
	)
	flag.Parse()

	if *help {
		flag.Usage()
		os.Exit(0)
	}

	c.SSEMode = *sseMode
	c.Port = *port
	c.Host = *host

	// Check for timeout environment variable
	if timeoutStr := os.Getenv("MCP_COMMAND_TIMEOUT"); timeoutStr != "" {
		if timeout, err := strconv.Atoi(timeoutStr); err == nil {
			c.DefaultTimeout = time.Duration(timeout) * time.Second
		}
	}

	// Check for custom shell environment variable
	if shell := os.Getenv("MCP_SHELL"); shell != "" {
		c.Shell = shell
	}
}