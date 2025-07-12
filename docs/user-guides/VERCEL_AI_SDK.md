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


## Streamable example
```ts
export class TerminalAgentTool extends BaseTool {
    private mcpTools: any;
    private hitlTool: HITLTool;
    private mcpClient = null;
    private platform = null;

    constructor(options: TerminalAgentToolOptions) {
        super({
            statusCallback: options.statusCallback,
            abortController: options.abortController,
        });
        this.hitlTool = new HITLTool({
            statusCallback: options.statusCallback,
            abortController: options.abortController,
        });
        this.platform = os.platform();
        this.emitStatus(`Terminal Agent initialized`, StatusEnum.RUNNING);
    }


    private async initializeMCP() {
        const url = new URL('http://localhost:8080/mcp');
        const mcpClient = await createMCPClient({
            transport: new StreamableHTTPClientTransport(url, {
                sessionId: 'session_123',
            }),
        });

        this.mcpClient = mcpClient;

        this.mcpTools = await mcpClient.tools();
        console.log(this.mcpTools)

        console.log(this.mcpTools)
        this.mcpTools.hitlTool = this.hitlTool.getToolDefinition();
        console.log('[BrowserAgent] MCP client initialized with HITL tool support');
    }



    /**
     * Get the system prompt for the terminal agent
     */
    private getSystemPrompt(): string {
        return `You are an elite AI system operator with access to a terminal. Each command executes independently in the /config directory.
......`;
    }


    /**
     * Execute natural language instruction by calling the AI model.
     */
    private async executeInstruction(instruction: string, maxSteps: number): Promise<string> {
        try {
            console.log("MCP initializing");
            await this.initializeMCP();

            console.log("MCP initialized");
            const result = await generateText({
                model: google('gemini-2.5-flash'),
                tools: this.mcpTools,
                messages: [
                    {
                        role: 'system',
                        content: this.getSystemPrompt()
                    },
                    {
                        role: 'user',
                        content: `${instruction}\n\nComplete this task in maximum ${maxSteps} steps.`
                    }
                ],
                maxSteps: maxSteps,
                abortSignal: this.abortController.signal
            });

            await this.mcpClient.close();
            return result.text;
        } catch (error) {
            this.emitStatus(`Error executing instruction: ${error.message}`, StatusEnum.ERROR);
            return `Error: ${error.message}`;
        }
    }

    /**
     * Get the AI SDK tool definition for the "wild" agent.
     */
    getToolDefinition() {
        return tool({
            description:
                `Terminal agent with secure access to unix utilities. Can take upto three tasks at once in natural language achieve those tasks through terminal.`,
            parameters: z.object({
                instruction: z.string().describe(
                    `A high-level command that can be completed through temrinal tools.`
                ),
                maxSteps: z.number().describe('The maximum number of steps it would take a user with terminal access.').min(2).max(10),
            }),
            execute: async ({ instruction, maxSteps }) => this.executeInstruction(instruction, maxSteps),
        });
    }
}
```