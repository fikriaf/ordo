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
        
        // Get available tools from plugins and MCP servers (filtered by user message)
        const tools = await this.getAllAvailableTools(userMessage);

        // Build messages array - SIMPLIFIED, no system prompt
        const messages: Message[] = [
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
              timeout: 15000, // 15 second timeout (reduced from 30s)
            }
          ),
          {
            maxRetries: 2, // Reduced from 3 to 2
            initialDelay: 500, // Reduced from 1000ms to 500ms
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
                timeout: 15000, // 15 second timeout (reduced from 30s)
              }
            ),
            {
              maxRetries: 2, // Reduced from 3 to 2
              initialDelay: 500, // Reduced from 1000ms to 500ms
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

  private async getAllAvailableTools(userMessage?: string): Promise<any[]> {
    // Get local plugin tools
    const pluginTools = this.getToolsFromPlugins();

    // Get remote MCP tools with strict timeout (5 seconds max)
    let mcpTools: any[] = [];
    try {
      const MCP_TOOLS_TIMEOUT = 5000; // 5 seconds max for MCP tools
      
      const mcpToolsList = await Promise.race([
        mcpClientService.getAvailableTools(),
        new Promise<never>((_, reject) => 
          setTimeout(() => reject(new Error('MCP tools fetch timeout')), MCP_TOOLS_TIMEOUT)
        )
      ]);
      
      mcpTools = mcpToolsList.map((tool: Tool) => ({
        type: 'function',
        function: {
          name: tool.name,
          description: tool.description,
          parameters: tool.parameters,
        },
      }));
    } catch (error: any) {
      logger.warn('Failed to fetch MCP tools (timeout or error), continuing with plugin tools only', {
        error: error.message,
      });
    }

    const allTools = [...pluginTools, ...mcpTools];

    // OPTIMIZATION: Filter tools based on user message to reduce token usage
    if (userMessage) {
      const relevantTools = this.filterRelevantTools(allTools, userMessage);
      
      logger.info('Filtered tools based on user query', {
        total: allTools.length,
        relevant: relevantTools.length,
        reduction: `${((1 - relevantTools.length / allTools.length) * 100).toFixed(1)}%`,
      });
      
      return relevantTools;
    }

    logger.info('Using all available tools (no filtering)', {
      pluginTools: pluginTools.length,
      mcpTools: mcpTools.length,
      total: allTools.length,
    });

    return allTools;
  }

  private filterRelevantTools(tools: any[], userMessage: string): any[] {
    const lowerMessage = userMessage.toLowerCase();
    
    // Define keyword mappings for tool categories
    const categoryKeywords: Record<string, string[]> = {
      balance: ['balance', 'wallet', 'how much', 'check', 'portfolio', 'holdings'],
      swap: ['swap', 'exchange', 'trade', 'convert', 'buy', 'sell'],
      transfer: ['send', 'transfer', 'pay', 'give'],
      price: ['price', 'cost', 'worth', 'value', 'how much is'],
      nft: ['nft', 'token', 'collectible', 'mint'],
      stake: ['stake', 'staking', 'unstake', 'validator'],
      lend: ['lend', 'lending', 'borrow', 'loan', 'supply'],
      liquidity: ['liquidity', 'pool', 'lp', 'add liquidity', 'remove liquidity'],
      bridge: ['bridge', 'cross-chain', 'transfer to'],
      analytics: ['analyze', 'analysis', 'stats', 'statistics', 'report'],
      risk: ['risk', 'safe', 'dangerous', 'security', 'audit'],
      evm: ['ethereum', 'eth', 'polygon', 'matic', 'bsc', 'binance', 'arbitrum', 'optimism'],
    };

    // Detect relevant categories
    const relevantCategories = new Set<string>();
    for (const [category, keywords] of Object.entries(categoryKeywords)) {
      if (keywords.some(keyword => lowerMessage.includes(keyword))) {
        relevantCategories.add(category);
      }
    }

    // If no specific category detected, include common tools
    if (relevantCategories.size === 0) {
      relevantCategories.add('balance');
      relevantCategories.add('price');
      relevantCategories.add('analytics');
    }

    // Filter tools based on relevant categories
    const relevantTools = tools.filter(tool => {
      const toolName = tool.function.name.toLowerCase();
      const toolDesc = tool.function.description?.toLowerCase() || '';
      
      // Check if tool matches any relevant category
      for (const category of relevantCategories) {
        const keywords = categoryKeywords[category];
        if (keywords.some(keyword => 
          toolName.includes(keyword) || toolDesc.includes(keyword)
        )) {
          return true;
        }
      }
      
      return false;
    });

    // Always include essential tools (max 5)
    const essentialToolNames = [
      'get_balance',
      'get_token_price',
      'get_portfolio',
      'analyze_token',
      'get_wallet_info',
    ];

    const essentialTools = tools.filter(tool => 
      essentialToolNames.some(name => tool.function.name.includes(name))
    );

    // Merge relevant and essential tools (remove duplicates)
    const toolNames = new Set(relevantTools.map(t => t.function.name));
    const finalTools = [...relevantTools];
    
    for (const tool of essentialTools) {
      if (!toolNames.has(tool.function.name)) {
        finalTools.push(tool);
        toolNames.add(tool.function.name);
      }
    }

    // Limit to max 20 tools to keep token usage reasonable
    return finalTools.slice(0, 20);
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
    context: ActionContext,
    conversationHistory: Message[] = []
  ): AsyncGenerator<any, void, unknown> {
    try {
      const currentModel = this.getCurrentModel();
      const tools = await this.getAllAvailableTools(userMessage); // Pass userMessage for filtering

      // SIMPLIFIED - no system prompt
      const messages: Message[] = [
        ...conversationHistory,
        {
          role: 'user',
          content: userMessage,
        },
      ];

      logger.info('Streaming request to OpenRouter', {
        model: currentModel,
        toolsAvailable: tools.length,
      });

      // Send initial request
      const response = await axios.post(
        `${this.baseURL}/chat/completions`,
        {
          model: currentModel,
          messages,
          tools: tools.length > 0 ? tools : undefined,
          tool_choice: 'auto',
          stream: false, // First get tool calls if any
        },
        {
          headers: {
            Authorization: `Bearer ${this.apiKey}`,
            'Content-Type': 'application/json',
            'HTTP-Referer': 'https://ordo.app',
            'X-Title': 'Ordo AI Assistant',
          },
          timeout: 15000, // Reduced from 30000
        }
      ).catch(async (error) => {
        // If 400 error, retry without tools (fallback)
        if (error.response?.status === 400) {
          logger.warn('Request failed with 400, retrying without tools', {
            error: error.response?.data,
          });
          
          return axios.post(
            `${this.baseURL}/chat/completions`,
            {
              model: currentModel,
              messages,
              stream: false,
            },
            {
              headers: {
                Authorization: `Bearer ${this.apiKey}`,
                'Content-Type': 'application/json',
                'HTTP-Referer': 'https://ordo.app',
                'X-Title': 'Ordo AI Assistant',
              },
              timeout: 15000,
            }
          );
        }
        throw error;
      });

      const message = response.data.choices[0].message;

      // Check if there are tool calls
      if (message.tool_calls && message.tool_calls.length > 0) {
        // Emit tool call events
        for (const toolCall of message.tool_calls) {
          yield {
            type: 'tool_call',
            toolId: toolCall.id,
            toolName: toolCall.function.name,
            arguments: JSON.parse(toolCall.function.arguments || '{}'),
          };
        }

        // Execute tools
        const toolResults = await this.executeToolCalls(message.tool_calls, context);

        // Emit tool results
        for (const result of toolResults) {
          yield {
            type: 'tool_result',
            toolId: result.id,
            toolName: result.name,
            result: result.result || result.error,
            error: result.error ? true : false,
          };
        }

        // Get final response with tool results
        const finalMessages = [
          ...messages,
          {
            role: 'assistant' as const,
            content: message.content || '',
            tool_calls: message.tool_calls,
          },
          ...toolResults.map((result) => ({
            role: 'tool' as const,
            tool_call_id: result.id,
            content: JSON.stringify(result.result || { error: result.error }),
          })),
        ];

        // Stream final response
        const finalResponse = await axios.post(
          `${this.baseURL}/chat/completions`,
          {
            model: currentModel,
            messages: finalMessages,
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
            timeout: 60000,
          }
        );

        let buffer = '';
        for await (const chunk of finalResponse.data) {
          buffer += chunk.toString();
          const lines = buffer.split('\n');
          buffer = lines.pop() || '';

          for (const line of lines) {
            if (line.startsWith('data: ')) {
              const data = line.slice(6).trim();
              if (data === '[DONE]') continue;
              if (!data) continue;

              try {
                const parsed = JSON.parse(data);
                const content = parsed.choices?.[0]?.delta?.content;
                if (content) {
                  yield {
                    type: 'token',
                    content,
                  };
                }
              } catch (e) {
                // Skip invalid JSON
              }
            }
          }
        }
      } else {
        // No tool calls, stream direct response
        const streamResponse = await axios.post(
          `${this.baseURL}/chat/completions`,
          {
            model: currentModel,
            messages,
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
            timeout: 60000,
          }
        );

        let buffer = '';
        for await (const chunk of streamResponse.data) {
          buffer += chunk.toString();
          const lines = buffer.split('\n');
          buffer = lines.pop() || '';

          for (const line of lines) {
            if (line.startsWith('data: ')) {
              const data = line.slice(6).trim();
              if (data === '[DONE]') continue;
              if (!data) continue;

              try {
                const parsed = JSON.parse(data);
                const content = parsed.choices?.[0]?.delta?.content;
                if (content) {
                  yield {
                    type: 'token',
                    content,
                  };
                }
              } catch (e) {
                // Skip invalid JSON
              }
            }
          }
        }
      }
    } catch (error: any) {
      logger.error('Chat stream error:', error);
      yield {
        type: 'error',
        error: error.message || 'Stream failed',
      };
    }
  }
}

export default new AIAgentService();
