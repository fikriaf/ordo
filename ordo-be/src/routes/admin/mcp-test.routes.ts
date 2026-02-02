import { Router, Request, Response } from 'express';
import { mcpClientService } from '../../services/mcp-client.service';
import { mcpServerService } from '../../services/mcp-server.service';
import logger from '../../config/logger';

const router = Router();

// Test MCP server connection and tool discovery
router.post('/test/:id', async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    
    const server = await mcpServerService.getById(id);
    if (!server) {
      res.status(404).json({
        success: false,
        error: 'MCP server not found',
      });
      return;
    }

    logger.info(`Testing MCP server: ${server.name}`, {
      serverId: id,
      transport: server.transport_type,
    });

    // Clear cache for this server
    mcpClientService.clearCache(id);
    mcpClientService.clearClients(id);

    // Try to fetch tools from THIS specific server only
    const startTime = Date.now();
    let tools: any[] = [];
    let error: string | null = null;

    try {
      // Directly test this server, regardless of is_enabled status
      tools = await (mcpClientService as any).getToolsFromServer(server);
    } catch (err: any) {
      error = err.message;
      logger.error(`MCP test failed for ${server.name}`, {
        serverId: id,
        error: err.message,
        stack: err.stack,
      });
    }

    const duration = Date.now() - startTime;

    res.json({
      success: !error,
      data: {
        server: {
          id: server.id,
          name: server.name,
          transport_type: server.transport_type,
          server_url: server.server_url,
          is_enabled: server.is_enabled,
        },
        test: {
          duration_ms: duration,
          tools_found: tools.length,
          tools: tools.map((t: any) => ({
            name: t.name,
            originalName: t.originalName,
            description: t.description,
          })),
          error,
        },
      },
    });
  } catch (error: any) {
    logger.error('Error in MCP test endpoint', { error });
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to test MCP server',
    });
  }
});

export default router;
