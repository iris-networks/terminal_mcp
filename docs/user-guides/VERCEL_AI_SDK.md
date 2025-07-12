# Connecting MCP Terminal Server to Vercel AI SDK

This guide shows how to integrate the MCP Terminal Server with Vercel AI SDK for AI-powered terminal command execution.

## Prerequisites

- Node.js 18+ 
- Vercel AI SDK installed
- MCP Terminal Server built and running
- Basic knowledge of TypeScript/JavaScript

## Installation

First, install the required dependencies:

```bash
npm install ai @ai-sdk/openai @modelcontextprotocol/sdk-client
# or
yarn add ai @ai-sdk/openai @modelcontextprotocol/sdk-client
```

## Setup

### 1. Start MCP Terminal Server in SSE Mode

```bash
./mcp-terminal-server -sse -port 3001
```

### 2. Create MCP Client

Create a file `mcp-client.ts`:

```typescript
import { Client } from '@modelcontextprotocol/sdk-client';
import { SSEClientTransport } from '@modelcontextprotocol/sdk-client/sse';

export class MCPTerminalClient {
  private client: Client;
  private transport: SSEClientTransport;

  constructor(private serverUrl: string = 'http://localhost:3001') {
    this.transport = new SSEClientTransport(
      new URL('/sse', serverUrl),
      new URL('/message', serverUrl)
    );
    this.client = new Client({
      name: 'vercel-ai-mcp-client',
      version: '1.0.0',
    }, {
      capabilities: {
        tools: {}
      }
    });
  }

  async connect(): Promise<void> {
    await this.client.connect(this.transport);
  }

  async disconnect(): Promise<void> {
    await this.client.close();
  }

  async executeCommand(command: string, options?: {
    timeout?: number;
    shell?: string;
    captureStderr?: boolean;
  }): Promise<string> {
    const result = await this.client.callTool({
      name: 'execute_command',
      arguments: {
        command,
        ...options
      }
    });

    if (result.isError) {
      throw new Error(`Command execution failed: ${result.content[0]?.text || 'Unknown error'}`);
    }

    return result.content[0]?.text || '';
  }

  async listTools(): Promise<any[]> {
    const result = await this.client.listTools();
    return result.tools || [];
  }
}
```

### 3. Create Vercel AI SDK Integration

Create `ai-terminal-integration.ts`:

```typescript
import { openai } from '@ai-sdk/openai';
import { generateText, tool } from 'ai';
import { z } from 'zod';
import { MCPTerminalClient } from './mcp-client';

const mcpClient = new MCPTerminalClient();

// Define the terminal execution tool for AI
const executeTerminalCommand = tool({
  description: 'Execute terminal commands on the system',
  parameters: z.object({
    command: z.string().describe('The terminal command to execute'),
    timeout: z.number().optional().describe('Timeout in seconds (default: 30)'),
    shell: z.string().optional().describe('Shell to use (default: system shell)'),
    captureStderr: z.boolean().optional().describe('Capture stderr separately'),
  }),
  execute: async ({ command, timeout, shell, captureStderr }) => {
    try {
      const result = await mcpClient.executeCommand(command, {
        timeout,
        shell,
        captureStderr,
      });
      return {
        success: true,
        output: result,
      };
    } catch (error) {
      return {
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error',
      };
    }
  },
});

export async function runAITerminalSession(userPrompt: string): Promise<string> {
  // Connect to MCP server
  await mcpClient.connect();

  try {
    const result = await generateText({
      model: openai('gpt-4'),
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
          - execute_command: Execute terminal commands with configurable options`
        },
        {
          role: 'user',
          content: userPrompt,
        },
      ],
      tools: {
        execute_command: executeTerminalCommand,
      },
      maxToolRoundtrips: 5,
    });

    return result.text;
  } finally {
    await mcpClient.disconnect();
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

### Custom MCP Client Configuration

```typescript
const mcpClient = new MCPTerminalClient('http://localhost:3001');

// With custom configuration
const mcpClient = new MCPTerminalClient('http://your-server:3001');
```

## Error Handling

### Robust Error Handling Example

```typescript
import { MCPTerminalClient } from './mcp-client';

async function safeExecuteCommand(command: string): Promise<{
  success: boolean;
  output?: string;
  error?: string;
}> {
  const client = new MCPTerminalClient();
  
  try {
    await client.connect();
    const output = await client.executeCommand(command, {
      timeout: 30, // 30 second timeout
      captureStderr: true,
    });
    
    return {
      success: true,
      output,
    };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error',
    };
  } finally {
    await client.disconnect();
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
import { MCPTerminalClient } from '../mcp-client';

describe('MCPTerminalClient', () => {
  let client: MCPTerminalClient;

  beforeEach(() => {
    client = new MCPTerminalClient('http://localhost:3001');
  });

  test('should execute simple command', async () => {
    await client.connect();
    const result = await client.executeCommand('echo "Hello World"');
    expect(result).toContain('Hello World');
    await client.disconnect();
  });

  test('should handle command timeout', async () => {
    await client.connect();
    await expect(
      client.executeCommand('sleep 10', { timeout: 1 })
    ).rejects.toThrow();
    await client.disconnect();
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

This integration provides a powerful way to combine AI capabilities with terminal command execution through the MCP protocol.