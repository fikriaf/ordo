import axios, { AxiosInstance } from 'axios';
import { mcpServerService, MCPServer } from './mcp-server.service';
import logger from '../config/logger';
import { Tool } from '../types/plugin';

interface MCPTool {
  name: string;
  description: string;
  inputSchema: {
    type: 'object';
    properties: Record<string, any>;
    required?: string[];
  };
}

interface MCPToolsResponse {
  tools?: MCPTool[];
  result?: {
    tools: MCPTool[];
  };
}

interface MCPToolCallResponse {
  content?: Array<{
    type: string;
    text?: string;
    [key: string]: any;
  }>;
  result?: {
    content?: Array<{
      type: string;
      text?: string;
      [key: string]: any;
    }>;
    [key: string]: any;
  };
  [key: string]: any;
}

interface CachedTools {
  tools: Tool[];
  timestamp: number;
  serverId: string;
}

export class MCPClientService {
  private toolsCache: Map<string, CachedTools> = new Map();
  private readonly CACHE_TTL = 5 * 60 * 1000; // 5 minutes
  private httpClients: Map<string, AxiosInstance> = new Map();

  constructor() {
    logger.info('MCP Client Service initialized');
  }

  /**
   * Get all available tools from enabled MCP servers
   * Returns cached tools if available and not expired
   */
  async getAvailableTools(): Promise<Tool[]> {
    try {
      // Get all enabled MCP servers (with sensitive data for API calls)
      const servers = await mcpServerService.getAll();
      const enabledServers = servers.filter(s => s.is_enabled);

      if (enabledServers.length === 0) {
        logger.info('No enabled MCP servers found');
        return [];
      }

      const allTools: Tool[] = [];

      // Fetch tools from each server
      for (const server of enabledServers) {
        try {
          const tools = await this.getToolsFromServer(server);
          allTools.push(...tools);
        } catch (error: any) {
          logger.error(`Failed to fetch tools from MCP server ${server.name}`, {
            serverId: server.id,
            error: error.message,
          });
          // Continue with other servers even if one fails
        }
      }

      logger.info('Retrieved tools from MCP servers', {
        serverCount: enabledServers.length,
        toolCount: allTools.length,
      });

      return allTools;
    } catch (error: any) {
      logger.error('Error getting available MCP tools', { error: error.message });
      return []; // Return empty array on error to not break AI agent
    }
  }

  /**
   * Get tools from a specific MCP server (with caching)
   */
  private async getToolsFromServer(server: MCPServer): Promise<Tool[]> {
    // Check cache first
    const cached = this.toolsCache.get(server.id);
    const now = Date.now();

    if (cached && (now - cached.timestamp) < this.CACHE_TTL) {
      logger.debug(`Using cached tools for MCP server ${server.name}`, {
        serverId: server.id,
        toolCount: cached.tools.length,
      });
      return cached.tools;
    }

    // Fetch fresh tools
    logger.info(`Fetching tools from MCP server ${server.name}`, {
      serverId: server.id,
      transport: server.transport_type,
    });

    let mcpTools: MCPTool[];

    if (server.transport_type === 'http') {
      mcpTools = await this.fetchToolsHTTP(server);
    } else if (server.transport_type === 'sse') {
      mcpTools = await this.fetchToolsSSE(server);
    } else {
      throw new Error(`Unsupported transport type: ${server.transport_type}`);
    }

    // Convert MCP tools to our Tool format and add source metadata
    const tools: Tool[] = mcpTools.map(mcpTool => ({
      name: `${server.name}__${mcpTool.name}`, // Prefix with server name to avoid conflicts
      description: `[MCP: ${server.name}] ${mcpTool.description}`,
      parameters: mcpTool.inputSchema,
      source: 'mcp',
      serverId: server.id,
      serverName: server.name,
      originalName: mcpTool.name,
    } as Tool));

    // Update cache
    this.toolsCache.set(server.id, {
      tools,
      timestamp: now,
      serverId: server.id,
    });

    logger.info(`Cached ${tools.length} tools from MCP server ${server.name}`, {
      serverId: server.id,
    });

    return tools;
  }

  /**
   * Fetch tools from HTTP-based MCP server
   */
  private async fetchToolsHTTP(server: MCPServer): Promise<MCPTool[]> {
    const client = this.getHTTPClient(server);

    // Get custom endpoint path from config, default to '/tools/list'
    const toolsPath = server.config?.tools_path || server.config?.toolsPath || '/tools/list';

    try {
      // Try with JSON-RPC format first (standard MCP)
      const response = await client.post<MCPToolsResponse>(toolsPath, {
        jsonrpc: '2.0',
        method: 'tools/list',
        params: {},
        id: 1,
      });

      // Handle different response formats
      if (response.data.result?.tools) {
        return response.data.result.tools;
      } else if (response.data.tools) {
        return response.data.tools;
      }

      return [];
    } catch (error: any) {
      // If JSON-RPC fails, try simple POST
      try {
        const response = await client.post<MCPToolsResponse>(toolsPath, {});
        return response.data.tools || response.data.result?.tools || [];
      } catch (fallbackError: any) {
        logger.error(`HTTP fetch tools failed for ${server.name}`, {
          serverId: server.id,
          error: error.message,
          fallbackError: fallbackError.message,
          status: error.response?.status,
          toolsPath,
        });
        throw new Error(`Failed to fetch tools via HTTP: ${error.message}`);
      }
    }
  }

  /**
   * Fetch tools from SSE-based MCP server
   * Uses EventSource-compatible streaming for real-time updates
   */
  private async fetchToolsSSE(server: MCPServer): Promise<MCPTool[]> {
    const toolsPath = server.config?.tools_path || server.config?.toolsPath || '/tools';

    return new Promise((resolve, reject) => {
      const timeout = server.config?.timeout || 30000;
      const url = `${server.server_url}${toolsPath}`;

      logger.info(`Connecting to SSE endpoint for tools: ${url}`, {
        serverId: server.id,
      });

      // Use axios with streaming for SSE
      const headers: Record<string, string> = {
        'Accept': 'text/event-stream',
        'Cache-Control': 'no-cache',
        ...server.headers,
      };

      if (server.api_key) {
        headers['Authorization'] = `Bearer ${server.api_key}`;
      }

      let tools: MCPTool[] = [];
      let buffer = '';

      axios.get(url, {
        headers,
        responseType: 'stream',
        timeout,
      })
        .then(response => {
          const stream = response.data;

          stream.on('data', (chunk: Buffer) => {
            buffer += chunk.toString();
            const lines = buffer.split('\n');
            buffer = lines.pop() || ''; // Keep incomplete line in buffer

            for (const line of lines) {
              if (line.startsWith('data: ')) {
                const data = line.slice(6).trim();
                if (data === '[DONE]' || data === '') continue;

                try {
                  const parsed = JSON.parse(data);
                  
                  // Handle different SSE response formats
                  if (parsed.tools) {
                    tools = parsed.tools;
                  } else if (parsed.result?.tools) {
                    tools = parsed.result.tools;
                  } else if (parsed.type === 'tools' && parsed.data) {
                    tools = parsed.data;
                  }

                  // If we got tools, resolve immediately
                  if (tools.length > 0) {
                    stream.destroy();
                    resolve(tools);
                  }
                } catch (e: any) {
                  logger.warn(`Failed to parse SSE data: ${data}`, {
                    serverId: server.id,
                    error: e.message,
                  });
                }
              }
            }
          });

          stream.on('end', () => {
            if (tools.length > 0) {
              resolve(tools);
            } else {
              reject(new Error('SSE stream ended without receiving tools'));
            }
          });

          stream.on('error', (error: Error) => {
            reject(new Error(`SSE stream error: ${error.message}`));
          });

          // Set timeout
          setTimeout(() => {
            stream.destroy();
            if (tools.length > 0) {
              resolve(tools);
            } else {
              reject(new Error('SSE connection timeout'));
            }
          }, timeout);
        })
        .catch(error => {
          logger.error(`SSE connection failed for ${server.name}`, {
            serverId: server.id,
            error: error.message,
            url,
          });
          reject(new Error(`SSE connection failed: ${error.message}`));
        });
    });
  }

  /**
   * Execute a tool call on an MCP server
   */
  async executeTool(
    toolName: string,
    args: Record<string, any>
  ): Promise<any> {
    // Parse tool name to extract server name and original tool name
    const parts = toolName.split('__');
    if (parts.length !== 2) {
      throw new Error(`Invalid MCP tool name format: ${toolName}`);
    }

    const [serverName, originalToolName] = parts;

    // Find the server
    const servers = await mcpServerService.getAll();
    const server = servers.find(s => s.name === serverName && s.is_enabled);

    if (!server) {
      throw new Error(`MCP server not found or disabled: ${serverName}`);
    }

    logger.info(`Executing MCP tool ${originalToolName} on server ${serverName}`, {
      serverId: server.id,
      args,
    });

    let result: any;

    if (server.transport_type === 'http') {
      result = await this.executeHTTP(server, originalToolName, args);
    } else if (server.transport_type === 'sse') {
      result = await this.executeSSE(server, originalToolName, args);
    } else {
      throw new Error(`Unsupported transport type: ${server.transport_type}`);
    }

    logger.info(`MCP tool executed successfully: ${originalToolName}`, {
      serverId: server.id,
    });

    return result;
  }

  /**
   * Execute tool via HTTP
   */
  private async executeHTTP(
    server: MCPServer,
    toolName: string,
    args: Record<string, any>
  ): Promise<any> {
    const client = this.getHTTPClient(server);

    // Get custom endpoint path from config, default to '/tools/call'
    let executePath = server.config?.execute_path || server.config?.executePath || '/tools/call';

    // Support path templates like '/tools/{name}'
    if (executePath.includes('{name}')) {
      executePath = executePath.replace('{name}', toolName);
    }

    try {
      // Try with JSON-RPC format first (standard MCP)
      const response = await client.post<MCPToolCallResponse>(executePath, {
        jsonrpc: '2.0',
        method: 'tools/call',
        params: {
          name: toolName,
          arguments: args,
        },
        id: Date.now(),
      });

      // Handle different response formats
      if (response.data.result) {
        const result = response.data.result;
        // Extract text content if available
        if (result.content) {
          const content = Array.isArray(result.content) ? result.content : [result.content];
          const textContent = content
            .filter((c: any) => c.type === 'text' && c.text)
            .map((c: any) => c.text)
            .join('\n');
          return textContent || result;
        }
        return result;
      }

      // Extract text content from direct response
      const content = response.data.content || [];
      const textContent = content
        .filter(c => c.type === 'text' && c.text)
        .map(c => c.text)
        .join('\n');

      return textContent || response.data;
    } catch (error: any) {
      // If JSON-RPC fails, try simple POST
      try {
        const response = await client.post<MCPToolCallResponse>(executePath, {
          name: toolName,
          arguments: args,
        });

        // Extract text content from response
        const content = response.data.content || [];
        const textContent = content
          .filter(c => c.type === 'text' && c.text)
          .map(c => c.text)
          .join('\n');

        return textContent || response.data;
      } catch (fallbackError: any) {
        logger.error(`HTTP tool execution failed for ${toolName}`, {
          serverId: server.id,
          error: error.message,
          fallbackError: fallbackError.message,
          status: error.response?.status,
          executePath,
        });
        throw new Error(`Tool execution failed: ${error.message}`);
      }
    }
  }

  /**
   * Execute tool via SSE
   * Uses EventSource-compatible streaming for real-time execution
   */
  private async executeSSE(
    server: MCPServer,
    toolName: string,
    args: Record<string, any>
  ): Promise<any> {
    let executePath = server.config?.execute_path || server.config?.executePath || '/tools';

    // Support path templates like '/tools/{name}'
    if (executePath.includes('{name}')) {
      executePath = executePath.replace('{name}', toolName);
    }

    return new Promise((resolve, reject) => {
      const timeout = server.config?.timeout || 30000;
      const url = `${server.server_url}${executePath}`;

      logger.info(`Executing tool via SSE: ${toolName}`, {
        serverId: server.id,
        url,
      });

      const headers: Record<string, string> = {
        'Accept': 'text/event-stream',
        'Content-Type': 'application/json',
        'Cache-Control': 'no-cache',
        ...server.headers,
      };

      if (server.api_key) {
        headers['Authorization'] = `Bearer ${server.api_key}`;
      }

      let result: any = null;
      let buffer = '';

      axios.post(url, {
        name: toolName,
        arguments: args,
      }, {
        headers,
        responseType: 'stream',
        timeout,
      })
        .then(response => {
          const stream = response.data;

          stream.on('data', (chunk: Buffer) => {
            buffer += chunk.toString();
            const lines = buffer.split('\n');
            buffer = lines.pop() || '';

            for (const line of lines) {
              if (line.startsWith('data: ')) {
                const data = line.slice(6).trim();
                if (data === '[DONE]' || data === '') continue;

                try {
                  const parsed = JSON.parse(data);
                  
                  // Handle different SSE response formats
                  if (parsed.result) {
                    result = parsed.result;
                  } else if (parsed.content) {
                    const content = Array.isArray(parsed.content) ? parsed.content : [parsed.content];
                    const textContent = content
                      .filter((c: any) => c.type === 'text' && c.text)
                      .map((c: any) => c.text)
                      .join('\n');
                    result = textContent || parsed;
                  } else {
                    result = parsed;
                  }

                  // If we got a result, we can resolve
                  if (result !== null) {
                    stream.destroy();
                    resolve(result);
                  }
                } catch (e: any) {
                  logger.warn(`Failed to parse SSE execution data: ${data}`, {
                    serverId: server.id,
                    error: e.message,
                  });
                }
              }
            }
          });

          stream.on('end', () => {
            if (result !== null) {
              resolve(result);
            } else {
              reject(new Error('SSE execution stream ended without result'));
            }
          });

          stream.on('error', (error: Error) => {
            reject(new Error(`SSE execution error: ${error.message}`));
          });

          setTimeout(() => {
            stream.destroy();
            if (result !== null) {
              resolve(result);
            } else {
              reject(new Error('SSE execution timeout'));
            }
          }, timeout);
        })
        .catch(error => {
          logger.error(`SSE tool execution failed for ${toolName}`, {
            serverId: server.id,
            error: error.message,
            url,
          });
          reject(new Error(`SSE execution failed: ${error.message}`));
        });
    });
  }

  /**
   * Get or create HTTP client for a server
   */
  private getHTTPClient(server: MCPServer): AxiosInstance {
    let client = this.httpClients.get(server.id);

    if (!client) {
      const headers: Record<string, string> = {
        'Content-Type': 'application/json',
        ...server.headers,
      };

      if (server.api_key) {
        headers['Authorization'] = `Bearer ${server.api_key}`;
      }

      client = axios.create({
        baseURL: server.server_url,
        headers,
        timeout: server.config?.timeout || 30000,
      });

      this.httpClients.set(server.id, client);
    }

    return client;
  }

  /**
   * Clear cache for a specific server or all servers
   */
  clearCache(serverId?: string): void {
    if (serverId) {
      this.toolsCache.delete(serverId);
      logger.info(`Cleared MCP tools cache for server ${serverId}`);
    } else {
      this.toolsCache.clear();
      logger.info('Cleared all MCP tools cache');
    }
  }

  /**
   * Clear HTTP clients
   */
  clearClients(serverId?: string): void {
    if (serverId) {
      this.httpClients.delete(serverId);
    } else {
      this.httpClients.clear();
    }
  }
}

export const mcpClientService = new MCPClientService();
