# Connecting MCP Terminal Server to Vercel AI SDK

This guide shows how to integrate the MCP Terminal Server with Vercel AI SDK using the new MCP tools feature for AI-powered terminal command execution.

## Prerequisites

- Node.js 18+ 
- Vercel AI SDK installed
- MCP Terminal Server built and running
- Basic knowledge of TypeScript/JavaScript

## Installation

First, install the required dependencies:

```bash
npm install ai @ai-sdk/openai @modelcontextprotocol/sdk
# or
yarn add ai @ai-sdk/openai @modelcontextprotocol/sdk
```

## Setup

### 1. Start MCP Terminal Server in HTTP Mode

```bash
./mcp-terminal-server --http --port 3001
```

### 2. Create MCP Tools Integration

Create a file `mcp-tools.ts`:

```typescript
import { createHttpTransport } from '@modelcontextprotocol/sdk/client/http.js';
import { MCPClient } from '@modelcontextprotocol/sdk/client/index.js';
import { tool } from 'ai';
import { z } from 'zod';

export async function createTerminalMCPTools(serverUrl: string = 'http://localhost:3001') {
  // Create HTTP transport for StreamableHTTP
  const transport = createHttpTransport(new URL(`${serverUrl}/mcp`));
  
  // Create MCP client
  const client = new MCPClient(
    {
      name: 'terminal-client',
      version: '1.0.0',
    },
    {
      capabilities: {},
    }
  );

  // Connect to the server
  await client.connect(transport);

  // Initialize the connection
  const initResult = await client.initialize();
  console.log('Connected to MCP Terminal Server:', initResult.serverInfo);

  // Get available tools from the server
  const toolsResult = await client.listTools();
  
  // Convert MCP tools to AI SDK tool format
  const aiTools: Record<string, any> = {};

  for (const mcpTool of toolsResult.tools) {
    aiTools[mcpTool.name] = tool({
      description: mcpTool.description,
      parameters: mcpTool.inputSchema as z.ZodSchema,
      execute: async (params) => {
        const result = await client.callTool({
          name: mcpTool.name,
          arguments: params,
        });
        
        return {
          result: result.content,
          isError: result.isError,
        };
      },
    });
  }

  return {
    tools: aiTools,
    client,
  };
}
```

### 3. Create Vercel AI SDK Integration

Create `ai-terminal-integration.ts`:

```typescript
import { openai } from '@ai-sdk/openai';
import { generateText } from 'ai';
import { createTerminalMCPTools } from './mcp-tools';

export async function runAITerminalSession(userPrompt: string, serverUrl?: string): Promise<string> {
  // Create MCP tools integration
  const { tools, client } = await createTerminalMCPTools(serverUrl);

  try {
    const result = await generateText({
      model: openai('gpt-4o'),
      tools, // Use converted MCP tools
      messages: [
        {
          role: 'system',
          content: `You are a helpful assistant that can execute terminal commands.
          
          Guidelines:
          - Always explain what commands you're going to run before executing them
          - Be careful with destructive commands
          - Use appropriate timeouts for long-running commands
          - Capture stderr when debugging issues
          - Provide clear explanations of command outputs
          
          Available tools:
          - execute_command: Execute single commands with timeout
          - persistent_shell: Execute commands in persistent shell sessions
          - session_manager: Manage shell sessions (list, close)`
        },
        {
          role: 'user',
          content: userPrompt,
        },
      ],
      maxToolRoundtrips: 5,
    });

    // Close the MCP connection
    await client.close();

    return result.text;
  } catch (error) {
    throw new Error(`AI Terminal Session failed: ${error instanceof Error ? error.message : 'Unknown error'}`);
  }
}
```

### 4. Example Usage

Create `example.ts`:

```typescript
import { runAITerminalSession } from './ai-terminal-integration';

async function main() {
  try {
    // Example 1: Basic system information
    console.log('=== System Information ===');
    const systemInfo = await runAITerminalSession(
      'Show me system information including OS, memory usage, and disk space'
    );
    console.log(systemInfo);

    // Example 2: File operations
    console.log('\n=== File Operations ===');
    const fileOps = await runAITerminalSession(
      'List all TypeScript files in the current directory and show their sizes'
    );
    console.log(fileOps);

    // Example 3: Development tasks
    console.log('\n=== Development Tasks ===');
    const devTasks = await runAITerminalSession(
      'Check if Node.js is installed and show the version. Then list all npm packages in package.json'
    );
    console.log(devTasks);

  } catch (error) {
    console.error('Error:', error);
  }
}

main();
```

## Advanced Integration

### Web Application Example

Create a Next.js API route `pages/api/terminal.ts`:

```typescript
import { NextApiRequest, NextApiResponse } from 'next';
import { runAITerminalSession } from '../../lib/ai-terminal-integration';

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { prompt } = req.body;

  if (!prompt) {
    return res.status(400).json({ error: 'Prompt is required' });
  }

  try {
    const result = await runAITerminalSession(prompt);
    res.status(200).json({ result });
  } catch (error) {
    console.error('Terminal execution error:', error);
    res.status(500).json({ 
      error: 'Failed to execute terminal command',
      details: error instanceof Error ? error.message : 'Unknown error'
    });
  }
}
```

### React Component Example

```typescript
import React, { useState } from 'react';

export default function TerminalChat() {
  const [prompt, setPrompt] = useState('');
  const [response, setResponse] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!prompt.trim()) return;

    setLoading(true);
    try {
      const res = await fetch('/api/terminal', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ prompt }),
      });

      const data = await res.json();
      if (res.ok) {
        setResponse(data.result);
      } else {
        setResponse(`Error: ${data.error}`);
      }
    } catch (error) {
      setResponse(`Error: ${error instanceof Error ? error.message : 'Unknown error'}`);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="max-w-4xl mx-auto p-6">
      <h1 className="text-2xl font-bold mb-6">AI Terminal Assistant</h1>
      
      <form onSubmit={handleSubmit} className="mb-6">
        <div className="flex gap-2">
          <input
            type="text"
            value={prompt}
            onChange={(e) => setPrompt(e.target.value)}
            placeholder="Ask me to run terminal commands..."
            className="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            disabled={loading}
          />
          <button
            type="submit"
            disabled={loading || !prompt.trim()}
            className="px-6 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600 disabled:opacity-50"
          >
            {loading ? 'Running...' : 'Execute'}
          </button>
        </div>
      </form>

      {response && (
        <div className="bg-gray-100 rounded-lg p-4">
          <h3 className="font-semibold mb-2">Response:</h3>
          <pre className="whitespace-pre-wrap text-sm">{response}</pre>
        </div>
      )}
    </div>
  );
}
```

## Configuration Options

### Environment Variables

```bash
# MCP Server Configuration
export MCP_COMMAND_TIMEOUT=60
export MCP_SHELL=/bin/zsh

# OpenAI API Configuration
export OPENAI_API_KEY=your-api-key-here
```

### Custom MCP Transport Configuration

```typescript
import { createHttpTransport } from '@modelcontextprotocol/sdk/client/http.js';
import { createStdioTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { createMCPClient } from '@modelcontextprotocol/sdk/client/index.js';
import { StreamableHTTPClientTransport } from '@modelcontextprotocol/sdk/client/http.js';

// Method 1: Using createHttpTransport (current approach)
const httpTransport = createHttpTransport(new URL('http://localhost:3001/mcp'));

// Method 2: Using StreamableHTTPClientTransport with session management
async function initializeMCPWithSession() {
    const url = new URL('http://localhost:8080/mcp');
    const mcpClient = await createMCPClient({
        transport: new StreamableHTTPClientTransport(url, {
            sessionId: 'session_123',
        }),
    });

    const mcpTools = await mcpClient.tools();
    console.log('[BrowserAgent] MCP client initialized with tools:', mcpTools);
    
    return { mcpClient, mcpTools };
}

// Method 3: Remote HTTP transport
const remoteTransport = createHttpTransport(new URL('https://your-server.com/mcp'));

// Method 4: Local stdio transport (if running locally)
const stdioTransport = createStdioTransport({
  command: './mcp-terminal-server',
  args: [],
});

// Use with MCP client (Method 1)
const client = new MCPClient(clientInfo, capabilities);
await client.connect(httpTransport); // or stdioTransport

// Alternative usage with session management (Method 2)
const { mcpClient, mcpTools } = await initializeMCPWithSession();
```

## Error Handling

### Robust Error Handling Example

```typescript
import { createTerminalMCPTools } from './mcp-tools';
import { generateText } from 'ai';
import { openai } from '@ai-sdk/openai';

async function safeExecuteCommand(command: string, serverUrl?: string): Promise<{
  success: boolean;
  output?: string;
  error?: string;
}> {
  let client;
  try {
    const { tools, client: mcpClient } = await createTerminalMCPTools(serverUrl);
    client = mcpClient;
    
    const result = await generateText({
      model: openai('gpt-4o'),
      tools,
      messages: [
        {
          role: 'system',
          content: 'Execute the requested command and return the output. Handle errors gracefully.'
        },
        {
          role: 'user',
          content: `Execute this command: ${command}`,
        },
      ],
      maxToolRoundtrips: 1,
    });
    
    return {
      success: true,
      output: result.text,
    };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error',
    };
  } finally {
    // Always close the MCP client
    if (client) {
      try {
        await client.close();
      } catch (closeError) {
        console.warn('Failed to close MCP client:', closeError);
      }
    }
  }
}
```

## Security Best Practices

1. **Input Validation**: Always validate and sanitize commands
2. **Rate Limiting**: Implement rate limiting for API endpoints
3. **Command Filtering**: Consider implementing command allow/deny lists
4. **Timeouts**: Set appropriate timeouts for all operations
5. **Logging**: Log all command executions for audit trails

### Example Security Middleware

```typescript
const DANGEROUS_COMMANDS = ['rm -rf', 'sudo', 'chmod 777', 'mkfs'];

function validateCommand(command: string): boolean {
  return !DANGEROUS_COMMANDS.some(dangerous => 
    command.toLowerCase().includes(dangerous)
  );
}

// Use in your API route
if (!validateCommand(prompt)) {
  return res.status(400).json({ error: 'Command not allowed' });
}
```

## Testing

### Unit Tests

```typescript
import { createTerminalMCPTools } from '../mcp-tools';
import { runAITerminalSession } from '../ai-terminal-integration';

describe('Terminal MCP Integration', () => {
  const testServerUrl = 'http://localhost:3001';

  test('should create MCP tools successfully', async () => {
    const { tools, client } = await createTerminalMCPTools(testServerUrl);
    expect(tools).toBeDefined();
    expect(tools.execute_command).toBeDefined();
    expect(tools.persistent_shell).toBeDefined();
    expect(tools.session_manager).toBeDefined();
    
    // Clean up
    await client.close();
  });

  test('should execute simple command through AI', async () => {
    const result = await runAITerminalSession(
      'Execute echo "Hello World" and return the output',
      testServerUrl
    );
    expect(result).toContain('Hello World');
  });

  test('should handle command errors gracefully', async () => {
    const result = await runAITerminalSession(
      'Execute an invalid command like "invalidcommand123"',
      testServerUrl
    );
    expect(result).toContain('error');
  });

  test('should work with persistent shell sessions', async () => {
    const result = await runAITerminalSession(
      'Create a new shell session, change to /tmp directory, then list the current directory',
      testServerUrl
    );
    expect(result).toContain('/tmp');
  });
});
```

## Deployment

### Docker Example

```dockerfile
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./
RUN npm ci --only=production

# Copy application code
COPY . .

# Build the application
RUN npm run build

# Expose port
EXPOSE 3000

# Start the application
CMD ["npm", "start"]
```

### Production Considerations

1. **Process Management**: Use PM2 or similar for the MCP server
2. **Monitoring**: Implement health checks and monitoring
3. **Scaling**: Consider multiple MCP server instances
4. **Caching**: Cache frequent command results when appropriate

## What's New

This integration now uses the latest Vercel AI SDK v5 MCP tools feature, which provides:

- **Native MCP Support**: Direct integration with MCP servers without custom wrappers
- **Type Safety**: Full TypeScript support with proper type inference
- **Better Performance**: Optimized connection handling and resource management
- **StreamableHTTP Transport**: Uses the standard MCP StreamableHTTP transport for better compatibility

## Migration from SSE

If you were using the previous SSE-based integration:

1. **Update dependencies**: Add `@modelcontextprotocol/sdk`
2. **Change server startup**: Use `--http` instead of `--sse` flag
3. **Update transport**: Switch from SSE to StreamableHTTP transport
4. **Use new MCP tools**: Replace `experimental_createMCPClient` with native MCP SDK

This integration provides a powerful and standards-compliant way to combine AI capabilities with terminal command execution through the MCP protocol.