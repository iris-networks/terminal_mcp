# MCP Terminal Server Architecture

## Overview

The MCP Terminal Server has been modularized into clean, reusable components following Go best practices. The architecture separates concerns into distinct modules, making the codebase maintainable, testable, and extensible.

## Project Structure

```
mcp-terminal-server/
├── main.go                          # Application entry point (69 lines)
├── internal/                        # Internal packages
│   ├── config/                      # Configuration management
│   │   └── config.go               # Config struct and parsing logic
│   ├── session/                     # Persistent shell session management
│   │   └── session.go              # Session manager and shell lifecycle
│   ├── executor/                    # Non-persistent command execution
│   │   └── executor.go             # Command execution logic
│   ├── handlers/                    # HTTP request handlers
│   │   └── http.go                 # HTTP routes and MCP protocol handling
│   └── tools/                       # MCP tools registration and management
│       └── tools.go                # Tool definitions and handlers
├── go.mod                          # Go module definition
├── go.sum                          # Go dependencies
└── docs/                           # Documentation
    ├── README.md                   # Main documentation
    ├── QUICK_START.md             # Quick start guide
    ├── GETTING_STARTED.md         # Detailed setup guide
    ├── VERCEL_AI_SDK.md           # Integration guide
    └── ARCHITECTURE.md            # This file
```

## Module Responsibilities

### 1. `main.go` (Entry Point)
**Lines of Code:** ~69 (vs 890+ in original)
**Responsibilities:**
- Application initialization
- Dependency injection
- Server startup (STDIO or HTTP mode)

**Key Features:**
- Clean, readable main function
- Proper dependency initialization order
- Centralized error handling

### 2. `internal/config` (Configuration Management)
**Responsibilities:**
- Configuration struct definition
- Command-line flag parsing
- Environment variable handling
- Default value management

**Key Features:**
- Platform-specific defaults
- Environment variable override support
- Clean separation of configuration logic

### 3. `internal/session` (Session Management)
**Responsibilities:**
- Persistent shell session lifecycle
- Shell process management
- Session cleanup and garbage collection
- Command execution in persistent context

**Key Features:**
- Thread-safe session management
- Automatic cleanup of inactive sessions
- Session state tracking (created, last used, PID)
- Robust error handling for dead sessions

### 4. `internal/executor` (Command Execution)
**Responsibilities:**
- Non-persistent command execution
- Timeout handling
- Platform-specific shell selection
- Output capture and formatting

**Key Features:**
- Context-based timeout management
- Cross-platform compatibility
- Flexible shell selection
- Comprehensive error handling

### 5. `internal/handlers` (HTTP Handlers)
**Responsibilities:**
- HTTP request routing
- MCP protocol implementation
- CORS handling
- JSON-RPC message processing

**Key Features:**
- RESTful API endpoints
- MCP protocol compliance
- Proper HTTP status codes
- CORS-enabled for web integration

### 6. `internal/tools` (Tools Registry)
**Responsibilities:**
- MCP tool definitions
- Tool registration with MCP server
- Tool handler implementations
- Schema generation for HTTP API

**Key Features:**
- Centralized tool management
- Type-safe tool definitions
- Consistent error handling
- Schema export for documentation

## Data Flow

### STDIO Mode Flow
```
main.go → config → tools.Registry → server.ServeStdio()
                     ↓
tools.Registry → executor/session → mcp.CallToolResult
```

### HTTP Mode Flow
```
main.go → config → handlers.HTTPServer → http.ListenAndServe()
           ↓
HTTP Request → handlers → tools.Registry → executor/session → JSON Response
```

## Key Design Principles

### 1. **Separation of Concerns**
- Each module has a single, well-defined responsibility
- No circular dependencies between modules
- Clear interfaces between components

### 2. **Dependency Injection**
- Dependencies are injected through constructors
- Makes testing easier and reduces coupling
- Clear dependency graph: `main → config → session/executor → tools → handlers`

### 3. **Interface-Based Design**
- Components interact through well-defined interfaces
- Easy to mock for testing
- Supports future extensibility

### 4. **Error Handling**
- Consistent error handling patterns across modules
- Proper error propagation with context
- User-friendly error messages

### 5. **Thread Safety**
- All shared state is properly protected with mutexes
- Goroutine-safe session management
- No data races in concurrent operations

## Benefits of Modularization

### ✅ **Maintainability**
- **Before:** 890+ lines in single file
- **After:** ~69 lines in main.go, logical modules
- Easier to understand and modify individual components

### ✅ **Testability**
- Each module can be unit tested independently
- Dependencies can be easily mocked
- Clear test boundaries

### ✅ **Reusability**
- Modules can be reused in other projects
- Clean interfaces allow for component swapping
- Easy to extend with new features

### ✅ **Performance**
- Better code organization enables compiler optimizations
- Reduced memory footprint through selective imports
- Efficient session management

### ✅ **Extensibility**
- New tools can be added without modifying existing code
- Additional transport modes (WebSocket, gRPC) can be added easily
- Plugin architecture possible

## Adding New Features

### Adding a New Tool
1. Define tool schema in `internal/tools/tools.go`
2. Implement handler function
3. Register with `RegisterTools()`

### Adding a New Transport
1. Create new handler in `internal/handlers/`
2. Implement transport-specific logic
3. Add startup logic in `main.go`

### Adding New Configuration
1. Add field to `Config` struct in `internal/config/`
2. Implement parsing logic
3. Use throughout application

## Testing Strategy

### Unit Tests
- Each module should have comprehensive unit tests
- Mock dependencies using interfaces
- Test error conditions and edge cases

### Integration Tests
- Test module interactions
- Verify HTTP API endpoints
- Test persistent session functionality

### End-to-End Tests
- Test complete workflows
- Verify both STDIO and HTTP modes
- Test session lifecycle management

## Performance Considerations

### Memory Management
- Sessions are automatically cleaned up after 30 minutes
- Efficient string handling in command output
- Minimal memory allocation in hot paths

### Concurrency
- Session manager handles concurrent access safely
- HTTP handlers support multiple simultaneous requests
- Proper context cancellation for timeouts

### Scalability
- Session management scales to hundreds of concurrent sessions
- HTTP server can handle high request volumes
- Minimal per-session overhead

## Future Enhancements

### Possible Improvements
1. **Plugin System**: Dynamic tool loading
2. **WebSocket Transport**: Real-time bidirectional communication
3. **Metrics**: Prometheus metrics for monitoring
4. **Authentication**: Token-based session authentication
5. **Clustering**: Multi-instance session sharing
6. **Streaming**: Real-time command output streaming

### Migration Path
The modular architecture makes it easy to add these features without disrupting existing functionality. Each enhancement can be implemented as a new module with minimal changes to existing code.

## Conclusion

The modularized architecture provides a solid foundation for the MCP Terminal Server, offering improved maintainability, testability, and extensibility while preserving all existing functionality. The clean separation of concerns makes the codebase more professional and easier to work with for both development and operations teams.