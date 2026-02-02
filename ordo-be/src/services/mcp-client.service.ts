import axios, { AxiosInstance } from 'axios';
import * as https from 'https';
import * as http from 'http';
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

interface SSESession {
  sessionEndpoint: string;
  stream: any;
  messageQueue: Map<number, {resolve: Function, reject: Function}>;
  buffer: string;
}

export class MCPClientService {
  private toolsCache: Map<string, CachedTools> = new Map();
  private readonly CACHE_TTL = 5 * 60 * 1000; // 5 minutes
  private httpClients: Map<string, AxiosInstance> = new Map();
  private sseSessions: Map<string, SSESession> = new Map(); // serverId -> session

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
   * SSE servers use /sse for session, then POST to /tools via session endpoint
   */
  private async fetchToolsSSE(server: MCPServer): Promise<MCPTool[]> {
    logger.info(`[SSE] Starting fetchToolsSSE for ${server.name}`, {
      serverId: server.id,
      url: server.server_url,
    });

    // Check if we already have a session
    let session = this.sseSessions.get(server.id);
    
    if (!session) {
      logger.info(`[SSE] No existing session, creating new one for ${server.name}`);
      // Create new session
      session = await this.createSSESession(server);
      this.sseSessions.set(server.id, session);
      logger.info(`[SSE] Session created successfully for ${server.name}`);
    } else {
      logger.info(`[SSE] Using existing session for ${server.name}`);
    }

    // Get tools path from config, default to /tools
    const toolsPath = server.config?.tools_path || '/tools';

    // Send request to list tools
    try {
      logger.info(`[SSE] Sending request to ${toolsPath} for ${server.name}`);
      const response = await this.sendSSEMessage(server.id, toolsPath, {
        jsonrpc: '2.0',
        method: 'tools/list',
        params: {},
        id: Date.now(),
      });
      
      logger.info(`[SSE] Received response for ${server.name}`, {
        hasResult: !!response.result,
        hasTools: !!response.tools,
        response: JSON.stringify(response).substring(0, 500),
      });
      
      if (response.result?.tools) {
        logger.info(`[SSE] Found ${response.result.tools.length} tools in result for ${server.name}`);
        return response.result.tools;
      } else if (response.tools) {
        logger.info(`[SSE] Found ${response.tools.length} tools directly for ${server.name}`);
        return response.tools;
      }
      
      logger.warn(`[SSE] No tools found in response for ${server.name}`, {
        responseKeys: Object.keys(response),
      });
      return [];
    } catch (error: any) {
      // If session failed, try to recreate ONCE
      logger.warn(`[SSE] Session failed for ${server.name}, recreating...`, {
        serverId: server.id,
        error: error.message,
      });
      
      this.closeSSESession(server.id);
      
      try {
        session = await this.createSSESession(server);
        this.sseSessions.set(server.id, session);
        
        const response = await this.sendSSEMessage(server.id, toolsPath, {
          jsonrpc: '2.0',
          method: 'tools/list',
          params: {},
          id: Date.now(),
        });
        
        if (response.result?.tools) {
          return response.result.tools;
        } else if (response.tools) {
          return response.tools;
        }
        
        return [];
      } catch (retryError: any) {
        logger.error(`[SSE] Retry failed for ${server.name}`, {
          serverId: server.id,
          error: retryError.message,
        });
        throw retryError;
      }
    }
  }

  /**
   * Create SSE session with MCP server using native Node.js HTTP
   * SSE endpoint is always /sse for session establishment
   */
  private async createSSESession(server: MCPServer): Promise<SSESession> {
    return new Promise((resolve, reject) => {
      // SSE endpoint is always /sse for establishing session
      const sseEndpoint = '/sse';
      const url = new URL(`${server.server_url}${sseEndpoint}`);
      const timeout = server.config?.timeout || 30000;

      logger.info(`Creating SSE session: ${url.href}`, {
        serverId: server.id,
      });

      const headers: Record<string, string> = {
        'Accept': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive',
        ...server.headers,
      };

      if (server.api_key) {
        headers['Authorization'] = `Bearer ${server.api_key}`;
      }

      let sessionEndpoint: string | null = null;
      let buffer = '';
      let req: any = null;
      const messageQueue = new Map<number, {resolve: Function, reject: Function}>();
      let isResolved = false;

      const protocol = url.protocol === 'https:' ? https : http;

      const options = {
        hostname: url.hostname,
        port: url.port || (url.protocol === 'https:' ? 443 : 80),
        path: url.pathname + url.search,
        method: 'GET',
        headers,
      };

      req = protocol.request(options, (res) => {
        logger.info(`SSE connection established, status: ${res.statusCode}`, {
          serverId: server.id,
        });

        res.setEncoding('utf8');

        res.on('data', (chunk: string) => {
          buffer += chunk;
          const lines = buffer.split('\n');
          buffer = lines.pop() || '';

          for (const line of lines) {
            if (line.startsWith('event: ')) {
              const eventType = line.slice(7).trim();
              logger.debug(`[SSE] Event type: ${eventType}`, { serverId: server.id });
            } else if (line.startsWith('data: ')) {
              const data = line.slice(6).trim();
              if (data === '' || data === '[DONE]') continue;

              logger.debug(`[SSE] Data received: ${data.substring(0, 200)}`, {
                serverId: server.id,
              });

              // Check if this is session endpoint
              if (data.startsWith('/message')) {
                if (!sessionEndpoint) {
                  sessionEndpoint = data;
                  logger.info(`SSE session established: ${sessionEndpoint}`, {
                    serverId: server.id,
                  });
                  
                  // Resolve with session - stream continues listening
                  if (!isResolved) {
                    isResolved = true;
                    resolve({
                      sessionEndpoint,
                      stream: res,
                      messageQueue,
                      buffer,
                    });
                  }
                }
                continue;
              }

              // Try to parse as JSON response
              try {
                const parsed = JSON.parse(data);
                
                logger.debug(`[SSE] Parsed JSON, id: ${parsed.id}, has result: ${!!parsed.result}`, {
                  serverId: server.id,
                });
                
                // Check if this is a response to a request
                if (parsed.id && messageQueue.has(parsed.id)) {
                  const handler = messageQueue.get(parsed.id)!;
                  messageQueue.delete(parsed.id);
                  
                  // Clear timeout if it exists
                  if ((handler as any).timeout) {
                    clearTimeout((handler as any).timeout);
                  }
                  
                  logger.info(`[SSE] Response received for request ${parsed.id}`, {
                    serverId: server.id,
                    hasError: !!parsed.error,
                    hasResult: !!parsed.result,
                  });
                  
                  if (parsed.error) {
                    handler.reject(new Error(parsed.error.message || 'SSE request failed'));
                  } else {
                    handler.resolve(parsed);
                  }
                } else {
                  logger.debug(`[SSE] JSON parsed but no matching request in queue`, {
                    serverId: server.id,
                    parsedId: parsed.id,
                    queueSize: messageQueue.size,
                  });
                }
              } catch (e) {
                // Not JSON, might be ping or other message
                if (data.includes('ping')) {
                  logger.debug(`[SSE] Ping received`, { serverId: server.id });
                } else {
                  logger.debug(`[SSE] Data not JSON: ${data.substring(0, 100)}`, {
                    serverId: server.id,
                  });
                }
              }
            } else if (line.startsWith(': ')) {
              // SSE comment (often used for keep-alive pings)
              logger.debug(`[SSE] Comment/ping: ${line.substring(0, 50)}`, {
                serverId: server.id,
              });
            }
          }
        });

        res.on('error', (error: Error) => {
          logger.error(`SSE stream error`, {
            serverId: server.id,
            error: error.message,
          });
          // Reject all pending requests
          messageQueue.forEach((handler) => {
            if ((handler as any).timeout) {
              clearTimeout((handler as any).timeout);
            }
            handler.reject(new Error(`SSE stream error: ${error.message}`));
          });
          messageQueue.clear();
          
          if (!isResolved) {
            isResolved = true;
            reject(new Error(`SSE stream error: ${error.message}`));
          }
        });

        res.on('end', () => {
          logger.warn(`SSE stream ended`, {
            serverId: server.id,
            pendingRequests: messageQueue.size,
            queueIds: Array.from(messageQueue.keys()),
          });
          
          // Only reject pending requests if there are any
          if (messageQueue.size > 0) {
            messageQueue.forEach((handler, requestId) => {
              if ((handler as any).timeout) {
                clearTimeout((handler as any).timeout);
              }
              logger.error(`Rejecting pending request ${requestId} due to stream end`, {
                serverId: server.id,
              });
              handler.reject(new Error('SSE stream ended'));
            });
            messageQueue.clear();
          }
        });

        res.on('close', () => {
          logger.info(`SSE stream closed`, {
            serverId: server.id,
          });
        });
      });

      req.on('error', (error: Error) => {
        logger.error(`SSE connection failed`, {
          serverId: server.id,
          error: error.message,
          url: url.href,
        });
        if (!isResolved) {
          isResolved = true;
          reject(new Error(`SSE connection failed: ${error.message}`));
        }
      });

      // Timeout for session establishment only
      setTimeout(() => {
        if (!isResolved) {
          isResolved = true;
          if (req) {
            req.destroy();
          }
          reject(new Error('SSE session establishment timeout'));
        }
      }, timeout);

      req.end();
    });
  }

  /**
   * Send message via SSE session and wait for response
   */
  private async sendSSEMessage(
    serverId: string,
    path: string,
    body: any
  ): Promise<any> {
    const session = this.sseSessions.get(serverId);
    if (!session) {
      throw new Error('No SSE session found');
    }

    const server = await mcpServerService.getById(serverId);
    if (!server) {
      throw new Error('Server not found');
    }

    return new Promise((resolve, reject) => {
      const url = `${server.server_url}${session.sessionEndpoint}`;
      const timeout = server.config?.timeout || 30000;
      const requestId = body.id || Date.now();

      logger.info(`Sending SSE message to ${path}`, {
        serverId,
        requestId,
        url,
        queueSize: session.messageQueue.size,
      });

      // Register response handler BEFORE sending request
      session.messageQueue.set(requestId, { resolve, reject });

      const headers: Record<string, string> = {
        'Content-Type': 'application/json',
        ...server.headers,
      };

      if (server.api_key) {
        headers['Authorization'] = `Bearer ${server.api_key}`;
      }

      logger.debug(`[SSE] Request body:`, {
        serverId,
        requestId,
        body: JSON.stringify(body),
      });

      // Send POST request
      axios.post(url, body, {
        headers,
        timeout: 10000, // Short timeout for POST itself
      })
        .then(response => {
          logger.info(`[SSE] POST request completed, waiting for SSE response...`, {
            serverId,
            requestId,
            status: response.status,
            statusText: response.statusText,
            queueSize: session.messageQueue.size,
          });
          
          // Response will come via SSE stream
          // Set timeout for response
          const responseTimeout = setTimeout(() => {
            if (session.messageQueue.has(requestId)) {
              session.messageQueue.delete(requestId);
              logger.error(`[SSE] Response timeout for request ${requestId}`, {
                serverId,
                path,
                queueSize: session.messageQueue.size,
              });
              reject(new Error('SSE response timeout'));
            }
          }, timeout);

          // Store timeout so we can clear it if response arrives
          (session.messageQueue.get(requestId) as any).timeout = responseTimeout;
        })
        .catch(error => {
          session.messageQueue.delete(requestId);
          logger.error(`SSE message send failed`, {
            serverId,
            requestId,
            error: error.message,
            status: error.response?.status,
            data: error.response?.data,
          });
          reject(new Error(`SSE message send failed: ${error.message}`));
        });
    });
  }

  /**
   * Close SSE session
   */
  private closeSSESession(serverId: string): void {
    const session = this.sseSessions.get(serverId);
    if (session) {
      if (session.stream) {
        session.stream.destroy();
      }
      // Reject all pending requests
      session.messageQueue.forEach((handler) => {
        handler.reject(new Error('Session closed'));
      });
      this.sseSessions.delete(serverId);
      logger.info(`SSE session closed`, { serverId });
    }
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
   * Uses session-based SSE for execution
   */
  private async executeSSE(
    server: MCPServer,
    toolName: string,
    args: Record<string, any>
  ): Promise<any> {
    // Check if we have a session
    let session = this.sseSessions.get(server.id);
    
    if (!session) {
      // Create new session
      session = await this.createSSESession(server);
      this.sseSessions.set(server.id, session);
    }

    // Get execute path from config, default to /tools/{name}
    let executePath = server.config?.execute_path || '/tools/{name}';
    if (executePath.includes('{name}')) {
      executePath = executePath.replace('{name}', toolName);
    }

    // Send tools/call request via session
    try {
      const response = await this.sendSSEMessage(server.id, executePath, {
        jsonrpc: '2.0',
        method: 'tools/call',
        params: {
          name: toolName,
          arguments: args,
        },
        id: Date.now(),
      });
      
      // Extract result
      if (response.result) {
        const result = response.result;
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
      
      return response;
    } catch (error: any) {
      // If session failed, try to recreate
      logger.warn(`SSE execution failed, recreating session...`, {
        serverId: server.id,
        error: error.message,
      });
      
      this.closeSSESession(server.id);
      session = await this.createSSESession(server);
      this.sseSessions.set(server.id, session);
      
      const response = await this.sendSSEMessage(server.id, executePath, {
        jsonrpc: '2.0',
        method: 'tools/call',
        params: {
          name: toolName,
          arguments: args,
        },
        id: Date.now(),
      });
      
      if (response.result) {
        const result = response.result;
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
      
      return response;
    }
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
   * Clear HTTP clients and SSE sessions
   */
  clearClients(serverId?: string): void {
    if (serverId) {
      this.httpClients.delete(serverId);
      this.closeSSESession(serverId);
    } else {
      this.httpClients.clear();
      // Close all SSE sessions
      this.sseSessions.forEach((_, id) => this.closeSSESession(id));
    }
  }
}

export const mcpClientService = new MCPClientService();
