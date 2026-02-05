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
   * CRITICAL: For Daemon Intel MCP, use GET /tools endpoint (no SSE needed for listing!)
   * SSE is only needed for tool execution, not for listing tools
   */
  private async fetchToolsSSE(server: MCPServer): Promise<MCPTool[]> {
    logger.info(`[SSE] Starting fetchToolsSSE for ${server.name}`, {
      serverId: server.id,
      url: server.server_url,
    });

    // CRITICAL: Check if server has a dedicated /tools endpoint (like Daemon Intel)
    // If yes, use HTTP GET instead of SSE for listing tools
    const toolsPath = server.config?.tools_path || '/tools';
    
    // Try HTTP GET first for tools listing (Daemon Intel pattern)
    try {
      logger.info(`[SSE] Trying HTTP GET ${toolsPath} for ${server.name}`);
      
      const url = `${server.server_url}${toolsPath}`;
      const protocol = url.startsWith('https') ? https : http;
      
      const response = await new Promise<any>((resolve, reject) => {
        const req = protocol.request(url, {
          method: 'GET',
          headers: {
            'Accept': 'application/json',
            ...server.headers,
          },
        }, (res) => {
          let data = '';
          res.on('data', (chunk) => {
            data += chunk;
          });
          res.on('end', () => {
            try {
              const parsed = JSON.parse(data);
              resolve(parsed);
            } catch (e) {
              reject(new Error(`Failed to parse tools response: ${e}`));
            }
          });
        });
        
        req.on('error', reject);
        req.setTimeout(10000, () => {
          req.destroy();
          reject(new Error('Request timeout'));
        });
        req.end();
      });
      
      // Parse response - could be array or object with tools property
      let tools: MCPTool[] = [];
      if (Array.isArray(response)) {
        tools = response;
      } else if (response.tools && Array.isArray(response.tools)) {
        tools = response.tools;
      } else if (response.result?.tools && Array.isArray(response.result.tools)) {
        tools = response.result.tools;
      }
      
      if (tools.length > 0) {
        logger.info(`[SSE] Successfully fetched ${tools.length} tools via HTTP GET for ${server.name}`);
        return tools;
      }
      
      logger.info(`[SSE] HTTP GET returned no tools, falling back to SSE method for ${server.name}`);
    } catch (error: any) {
      logger.info(`[SSE] HTTP GET failed (${error.message}), falling back to SSE method for ${server.name}`);
    }

    // Fallback: Use SSE method for servers that require it (like Fetch MCP)
    logger.info(`[SSE] Using SSE method for ${server.name}`);
    
    // Check if we already have a session
    let session = this.sseSessions.get(server.id);
    
    if (!session) {
      logger.info(`[SSE] No existing session, creating new one for ${server.name}`);
      // Create new session
      session = await this.createSSESession(server);
      this.sseSessions.set(server.id, session);
      logger.info(`[SSE] Session created successfully for ${server.name}`);
      
      // CRITICAL: Wait for stream to be fully ready before sending requests
      // Intel API needs time to set up stream reference
      await new Promise(resolve => setTimeout(resolve, 2000));
      logger.info(`[SSE] Session stabilized for ${server.name}`);
    } else {
      logger.info(`[SSE] Using existing session for ${server.name}`);
    }

    // Send request to list tools via SSE
    try {
      logger.info(`[SSE] Sending tools/list request via SSE for ${server.name}`);
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
      // CRITICAL: DON'T close session on error! Session must stay alive!
      // Only log the error and try to recreate session if it's a connection error
      logger.error(`[SSE] Request failed for ${server.name}`, {
        serverId: server.id,
        error: error.message,
      });
      
      // Check if it's a connection error (stream ended/closed)
      if (error.message.includes('stream ended') || error.message.includes('stream closed') || error.message.includes('stream error')) {
        logger.warn(`[SSE] Connection error detected, recreating session for ${server.name}`);
        this.closeSSESession(server.id);
        
        try {
          session = await this.createSSESession(server);
          this.sseSessions.set(server.id, session);
          
          // CRITICAL: Wait for stream to be fully ready
          await new Promise(resolve => setTimeout(resolve, 1000));
          logger.info(`[SSE] Session recreated and stabilized for ${server.name}`);
          
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
      } else {
        // Not a connection error - just throw it
        // DON'T close the session!
        throw error;
      }
    }
  }

  /**
   * Create SSE session with MCP server using native Node.js HTTP
   * CRITICAL: Connection must stay open for session to persist!
   * CRITICAL: Do NOT destroy the stream - keep it alive!
   */
  private async createSSESession(server: MCPServer): Promise<SSESession> {
    return new Promise((resolve, reject) => {
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
        // CRITICAL: Keep connection alive - don't use agent pooling
        agent: false,
      };

      req = protocol.request(options, (res) => {
        (res as any).startTime = Date.now();
        
        logger.info(`SSE connection established, status: ${res.statusCode}`, {
          serverId: server.id,
        });

        if (res.statusCode !== 200) {
          logger.error(`SSE connection failed with status ${res.statusCode}`, {
            serverId: server.id,
          });
          if (!isResolved) {
            isResolved = true;
            reject(new Error(`SSE connection failed with status ${res.statusCode}`));
          }
          return;
        }

        res.setEncoding('utf8');
        
        // CRITICAL: Keep stream flowing - don't let it pause
        // CRITICAL: Don't call res.pause() or res.destroy()!
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
                  
                  // Resolve with session - stream MUST continue listening!
                  if (!isResolved) {
                    isResolved = true;
                    // Return session object but keep stream alive
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
          const endTime = Date.now();
          logger.warn(`SSE stream ended`, {
            serverId: server.id,
            pendingRequests: messageQueue.size,
            queueIds: Array.from(messageQueue.keys()),
            streamDuration: endTime - (res as any).startTime,
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

      // CRITICAL: Don't end the request - keep it open!
      // CRITICAL: Don't call req.end() with a callback that destroys it!
      req.end();
      
      // CRITICAL: Keep the request object alive - don't let it be garbage collected
      (req as any).keepAlive = true;
    });
  }

  /**
   * Send message via SSE session and wait for response
   * Response can come via POST body (Intel API) or SSE stream (standard MCP)
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
      // POST to session endpoint (e.g. /messages?session_id=xxx)
      const url = `${server.server_url}${session.sessionEndpoint}`;
      const timeout = server.config?.timeout || 30000;
      const requestId = body.id || Date.now();

      logger.info(`Sending SSE message to session endpoint`, {
        serverId,
        requestId,
        url,
        targetPath: path,
        queueSize: session.messageQueue.size,
      });

      // Register response handler for SSE stream response
      session.messageQueue.set(requestId, { resolve, reject });

      const headers: Record<string, string> = {
        'Content-Type': 'application/json',
        ...server.headers,
      };

      if (server.api_key) {
        headers['Authorization'] = `Bearer ${server.api_key}`;
      }

      // Use native HTTP for POST - use URL string directly like in test file
      const postBody = JSON.stringify(body);

      logger.info(`[SSE] Request details:`, {
        serverId,
        requestId,
        body: postBody,
        url,
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(postBody),
        },
      });

      // CRITICAL: Use URL string directly, not parsed URL object
      // CRITICAL: Don't include extra headers - keep it minimal like test file
      const postProtocol = url.startsWith('https') ? https : http;
      
      const postReq = postProtocol.request(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(postBody),
          // DON'T include server headers here - might interfere
        },
        agent: false,
      }, (postRes) => {
        let responseData = '';
        
        postRes.on('data', (chunk) => {
          responseData += chunk;
        });

        postRes.on('end', () => {
          logger.info(`[SSE] POST response received`, {
            serverId,
            requestId,
            status: postRes.statusCode,
            hasData: !!responseData,
            dataPreview: responseData.substring(0, 200),
          });
          
          // Handle error status codes first (before parsing)
          if (postRes.statusCode && postRes.statusCode >= 400) {
            session.messageQueue.delete(requestId);
            logger.error(`[SSE] POST failed with status ${postRes.statusCode}`, {
              serverId,
              requestId,
              data: responseData,
            });
            reject(new Error(`POST failed: ${postRes.statusCode} - ${responseData}`));
            return;
          }
          
          // Try to parse response as JSON
          let parsedData = null;
          try {
            parsedData = responseData ? JSON.parse(responseData) : null;
          } catch (parseError: any) {
            // Not JSON - might be plain text or empty
            logger.debug(`[SSE] Response is not JSON`, {
              serverId,
              requestId,
              data: responseData.substring(0, 100),
            });
          }
          
          // Check if response came directly in POST body (Intel API pattern)
          if (postRes.statusCode === 200 && parsedData) {
            // Response in POST body - resolve immediately
            session.messageQueue.delete(requestId);
            logger.info(`[SSE] Response received in POST body (hybrid mode)`, {
              serverId,
              requestId,
            });
            resolve(parsedData);
          } else if (postRes.statusCode === 202) {
            // 202 Accepted - response will come via SSE stream
            logger.info(`[SSE] POST accepted, waiting for SSE response...`, {
              serverId,
              requestId,
              queueSize: session.messageQueue.size,
            });
            
            // Set timeout for SSE response
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

            (session.messageQueue.get(requestId) as any).timeout = responseTimeout;
          } else if (postRes.statusCode === 200 && !parsedData) {
            // 200 but no JSON - might be waiting for SSE response
            logger.info(`[SSE] POST returned 200 with no JSON, waiting for SSE response...`, {
              serverId,
              requestId,
              queueSize: session.messageQueue.size,
            });
            
            // Set timeout for SSE response
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

            (session.messageQueue.get(requestId) as any).timeout = responseTimeout;
          } else {
            // Unexpected status
            session.messageQueue.delete(requestId);
            logger.error(`[SSE] Unexpected POST status ${postRes.statusCode}`, {
              serverId,
              requestId,
              data: responseData,
            });
            reject(new Error(`Unexpected status: ${postRes.statusCode} - ${responseData}`));
          }
        });
      });

      postReq.on('error', (error) => {
        session.messageQueue.delete(requestId);
        logger.error(`SSE POST request failed`, {
          serverId,
          requestId,
          error: error.message,
        });
        reject(new Error(`POST request failed: ${error.message}`));
      });

      postReq.write(postBody);
      postReq.end();
    });
  }

  /**
   * Close SSE session
   * CRITICAL: Only call this when absolutely necessary!
   * Closing the stream will invalidate the session on the server!
   */
  private closeSSESession(serverId: string): void {
    const session = this.sseSessions.get(serverId);
    if (session) {
      logger.warn(`Closing SSE session - this will invalidate the session!`, { serverId });
      
      // Reject all pending requests
      session.messageQueue.forEach((handler) => {
        if ((handler as any).timeout) {
          clearTimeout((handler as any).timeout);
        }
        handler.reject(new Error('Session closed'));
      });
      session.messageQueue.clear();
      
      // CRITICAL: Only destroy stream if it exists and is not already destroyed
      if (session.stream && !session.stream.destroyed) {
        try {
          session.stream.destroy();
        } catch (e: any) {
          logger.error(`Error destroying SSE stream`, {
            serverId,
            error: e.message,
          });
        }
      }
      
      this.sseSessions.delete(serverId);
      logger.info(`SSE session closed and removed`, { serverId });
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
      
      // CRITICAL: Wait for stream to be fully ready
      await new Promise(resolve => setTimeout(resolve, 1000));
      logger.info(`[SSE] Session stabilized for tool execution`, {
        serverId: server.id,
      });
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
      // CRITICAL: DON'T close session on error! Only recreate if connection error
      logger.error(`SSE execution failed for ${toolName}`, {
        serverId: server.id,
        error: error.message,
      });
      
      // Check if it's a connection error
      if (error.message.includes('stream ended') || error.message.includes('stream closed') || error.message.includes('stream error')) {
        logger.warn(`SSE connection error, recreating session...`, {
          serverId: server.id,
        });
        
        this.closeSSESession(server.id);
        session = await this.createSSESession(server);
        this.sseSessions.set(server.id, session);
        
        // CRITICAL: Wait for stream to be fully ready
        await new Promise(resolve => setTimeout(resolve, 1000));
        logger.info(`[SSE] Session recreated and stabilized for tool execution`, {
          serverId: server.id,
        });
        
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
      } else {
        // Not a connection error - just throw it
        throw error;
      }
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
