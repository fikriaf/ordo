import axios from 'axios';
import env from '../config/env';
import logger from '../config/logger';
import pluginManager from './plugin-manager.service';
import { mcpClientService } from './mcp-client.service';
import { ActionContext, Tool } from '../types/plugin';
import { retryWithBackoff } from '../utils/retry';

interface Message {
  role: 'user' | 'assistant' | 'system';
  content: string;
}

interface ToolCall {
  id: string;
  type: 'function';
  function: {
    name: string;
    arguments: string;
  };
}

export class AIAgentService {
  private apiKey: string;
  private baseURL: string;
  private models: string[];
  private currentModelIndex: number = 0;

  constructor() {
    this.apiKey = env.OPENROUTER_API_KEY;
    this.baseURL = env.OPENROUTER_BASE_URL;
    this.models = env.AI_MODELS.split(',').map(m => m.trim()).filter(m => m.length > 0);
    
    if (this.models.length === 0) {
      this.models = ['anthropic/claude-3.5-sonnet']; // Fallback default
    }
    
    logger.info(`AI Agent initialized with ${this.models.length} models`, {
      primary: this.models[0],
      fallbacks: this.models.slice(1),
    });
  }

  private getCurrentModel(): string {
    return this.models[this.currentModelIndex % this.models.length];
  }

  private switchToNextModel(): void {
    this.currentModelIndex++;
    logger.info(`Switching to fallback model: ${this.getCurrentModel()}`);
  }

  async chat(
    userMessage: string,
    context: ActionContext,
    conversationHistory: Message[] = []
  ): Promise<{ response: string; toolCalls?: any[] }> {
    const maxRetries = this.models.length;
    let lastError: Error | null = null;

    for (let attempt = 0; attempt < maxRetries; attempt++) {
      try {
        const currentModel = this.getCurrentModel();
        
        // Get available tools from plugins and MCP servers
        const tools = await this.getAllAvailableTools();

        // Build messages array
        const messages: Message[] = [
          {
            role: 'system',
            content: `You are Ordo, an AI assistant that helps users interact with Solana blockchain. 
You can execute various blockchain operations through function calls.
Always be helpful, concise, and accurate. When users ask to perform blockchain operations, use the available tools.`,
          },
          ...conversationHistory,
          {
            role: 'user',
            content: userMessage,
          },
        ];

        logger.info('Sending request to OpenRouter', {
          model: currentModel,
          attempt: attempt + 1,
          toolsCount: tools.length,
        });

        // Call OpenRouter API with retry logic
        const response = await retryWithBackoff(
          async () => axios.post(
            `${this.baseURL}/chat/completions`,
            {
              model: currentModel,
              messages,
              tools: tools.length > 0 ? tools : undefined,
              tool_choice: 'auto',
            },
            {
              headers: {
                Authorization: `Bearer ${this.apiKey}`,
                'Content-Type': 'application/json',
                'HTTP-Referer': 'https://ordo.app',
                'X-Title': 'Ordo AI Assistant',
              },
              timeout: 30000, // 30 second timeout
            }
          ),
          {
            maxRetries: 3,
            initialDelay: 1000,
            onRetry: (error, retryAttempt) => {
              logger.warn('Retrying OpenRouter API call', {
                model: currentModel,
                attempt: retryAttempt,
                error: error.message,
              });
            },
          }
        );

        const choice = response.data.choices[0];
        const message = choice.message;

        // Check if LLM wants to call tools
        if (message.tool_calls && message.tool_calls.length > 0) {
          logger.info('LLM requested tool calls', {
            count: message.tool_calls.length,
            model: currentModel,
          });

          const toolResults = await this.executeToolCalls(message.tool_calls, context);

          // Send tool results back to LLM for final response
          const finalMessages: Message[] = [
            ...messages,
            {
              role: 'assistant',
              content: message.content || '',
            },
            ...toolResults.map((result) => ({
              role: 'system' as const,
              content: `Tool ${result.name} result: ${JSON.stringify(result.result)}`,
            })),
          ];

          const finalResponse = await retryWithBackoff(
            async () => axios.post(
              `${this.baseURL}/chat/completions`,
              {
                model: currentModel,
                messages: finalMessages,
              },
              {
                headers: {
                  Authorization: `Bearer ${this.apiKey}`,
                  'Content-Type': 'application/json',
                  'HTTP-Referer': 'https://ordo.app',
                  'X-Title': 'Ordo AI Assistant',
                },
                timeout: 30000,
              }
            ),
            {
              maxRetries: 3,
              initialDelay: 1000,
              onRetry: (error, retryAttempt) => {
                logger.warn('Retrying OpenRouter final response', {
                  model: currentModel,
                  attempt: retryAttempt,
                  error: error.message,
                });
              },
            }
          );

          return {
            response: finalResponse.data.choices[0].message.content,
            toolCalls: toolResults,
          };
        }

        // No tool calls, return direct response
        return {
          response: message.content,
        };
      } catch (error: any) {
        lastError = error;
        logger.error(`AI chat error with model ${this.getCurrentModel()}:`, {
          error: error.response?.data || error.message,
          attempt: attempt + 1,
        });

        // If not the last attempt, switch to next model
        if (attempt < maxRetries - 1) {
          this.switchToNextModel();
          logger.info(`Retrying with next model...`);
          continue;
        }
      }
    }

    // All models failed
    const errorMessage = lastError instanceof Error 
      ? lastError.message 
      : String(lastError);
    throw new Error(`AI chat failed with all ${maxRetries} models: ${errorMessage}`);
  }

  private async getAllAvailableTools(): Promise<any[]> {
    // Get local plugin tools
    const pluginTools = this.getToolsFromPlugins();

    // Get remote MCP tools
    let mcpTools: any[] = [];
    try {
      const mcpToolsList = await mcpClientService.getAvailableTools();
      mcpTools = mcpToolsList.map((tool: Tool) => ({
        type: 'function',
        function: {
          name: tool.name,
          description: tool.description,
          parameters: tool.parameters,
        },
      }));

      logger.info('Merged tools from plugins and MCP servers', {
        pluginTools: pluginTools.length,
        mcpTools: mcpTools.length,
        total: pluginTools.length + mcpTools.length,
      });
    } catch (error: any) {
      logger.error('Failed to fetch MCP tools, continuing with plugin tools only', {
        error: error.message,
      });
    }

    return [...pluginTools, ...mcpTools];
  }

  private getToolsFromPlugins(): any[] {
    const actions = pluginManager.getAvailableActions();

    return actions.map((action) => ({
      type: 'function',
      function: {
        name: action.name,
        description: action.description,
        parameters: {
          type: 'object',
          properties: action.parameters.reduce((acc, param) => {
            acc[param.name] = {
              type: param.type,
              description: param.description,
            };
            return acc;
          }, {} as Record<string, any>),
          required: action.parameters.filter((p) => p.required).map((p) => p.name),
        },
      },
    }));
  }

  private async executeToolCalls(
    toolCalls: ToolCall[],
    context: ActionContext
  ): Promise<any[]> {
    const results = [];

    for (const toolCall of toolCalls) {
      try {
        const functionName = toolCall.function.name;
        const argsString = toolCall.function.arguments || '{}';
        const args = JSON.parse(argsString);

        logger.info(`Executing tool: ${functionName}`, { args });

        let result: any;

        // Check if this is an MCP tool (contains __)
        if (functionName.includes('__')) {
          // Execute via MCP client
          result = await mcpClientService.executeTool(functionName, args);
        } else {
          // Execute via plugin manager
          result = await pluginManager.executeAction(functionName, args, context);
        }

        results.push({
          id: toolCall.id,
          name: functionName,
          result,
        });
      } catch (error: any) {
        logger.error(`Tool execution failed: ${toolCall.function.name}`, error);
        results.push({
          id: toolCall.id,
          name: toolCall.function.name,
          error: error.message,
        });
      }
    }

    return results;
  }

  async *chatStream(
    userMessage: string,
    _context: ActionContext,
    conversationHistory: Message[] = []
  ): AsyncGenerator<string, void, unknown> {
    try {
      const currentModel = this.getCurrentModel();
      const tools = await this.getAllAvailableTools();

      const messages: Message[] = [
        {
          role: 'system',
          content: `You are Ordo, an AI assistant that helps users interact with Solana blockchain. 
You can execute various blockchain operations through function calls.
Always be helpful, concise, and accurate.`,
        },
        ...conversationHistory,
        {
          role: 'user',
          content: userMessage,
        },
      ];

      logger.info('Streaming request to OpenRouter', {
        model: currentModel,
      });

      const response = await axios.post(
        `${this.baseURL}/chat/completions`,
        {
          model: currentModel,
          messages,
          tools: tools.length > 0 ? tools : undefined,
          tool_choice: 'auto',
          stream: true,
        },
        {
          headers: {
            Authorization: `Bearer ${this.apiKey}`,
            'Content-Type': 'application/json',
            'HTTP-Referer': 'https://ordo.app',
            'X-Title': 'Ordo AI Assistant',
          },
          responseType: 'stream',
          timeout: 60000, // 60 second timeout for streaming
        }
      );

      for await (const chunk of response.data) {
        const lines = chunk.toString().split('\n').filter((line: string) => line.trim() !== '');
        
        for (const line of lines) {
          if (line.startsWith('data: ')) {
            const data = line.slice(6);
            if (data === '[DONE]') {
              return;
            }

            try {
              const parsed = JSON.parse(data);
              const content = parsed.choices[0]?.delta?.content;
              if (content) {
                yield content;
              }
            } catch (e) {
              // Skip invalid JSON
            }
          }
        }
      }
    } catch (error: any) {
      logger.error('AI chat stream error:', error.response?.data || error.message);
      throw new Error(`AI chat stream failed: ${error.message}`);
    }
  }
}

export default new AIAgentService();
