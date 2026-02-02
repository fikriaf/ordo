import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { mcpServerService } from '../../services/mcp-server.service';
import { mcpClientService } from '../../services/mcp-client.service';
import logger from '../../config/logger';

const router = Router();

// Validation schemas
const createMCPServerSchema = z.object({
  name: z.string().min(1).max(100),
  description: z.string().optional(),
  transport_type: z.enum(['http', 'sse']),
  server_url: z.string().url().max(500),
  api_key: z.string().optional(),
  headers: z.record(z.string()).optional(),
  is_enabled: z.boolean().optional(),
  config: z.record(z.any()).optional(),
  metadata: z.record(z.any()).optional(),
});

const updateMCPServerSchema = z.object({
  name: z.string().min(1).max(100).optional(),
  description: z.string().optional(),
  transport_type: z.enum(['http', 'sse']).optional(),
  server_url: z.string().url().max(500).optional(),
  api_key: z.string().optional(),
  headers: z.record(z.string()).optional(),
  is_enabled: z.boolean().optional(),
  config: z.record(z.any()).optional(),
  metadata: z.record(z.any()).optional(),
});

// Get all MCP servers (with sensitive data)
router.get('/', async (_req: Request, res: Response) => {
  try {
    const servers = await mcpServerService.getAll();

    res.json({
      success: true,
      data: servers,
      count: servers.length,
    });
  } catch (error: any) {
    logger.error('Error in GET /admin/mcp-servers', { error });
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to retrieve MCP servers',
    });
  }
});

// Clear MCP tools cache (MUST be before /:id routes)
router.post('/cache/clear', async (req: Request, res: Response) => {
  try {
    const { serverId } = req.body;

    if (serverId) {
      mcpClientService.clearCache(serverId);
      mcpClientService.clearClients(serverId);
    } else {
      mcpClientService.clearCache();
      mcpClientService.clearClients();
    }

    res.json({
      success: true,
      message: serverId 
        ? `Cache cleared for server ${serverId}` 
        : 'All MCP cache cleared',
    });
  } catch (error: any) {
    logger.error('Error in POST /admin/mcp-servers/cache/clear', { error });
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to clear cache',
    });
  }
});

// Get MCP server by ID
router.get('/:id', async (req: Request, res: Response): Promise<void> => {
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

    res.json({
      success: true,
      data: server,
    });
  } catch (error: any) {
    logger.error('Error in GET /admin/mcp-servers/:id', { error });
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to retrieve MCP server',
    });
  }
});

// Create new MCP server
router.post('/', async (req: Request, res: Response): Promise<void> => {
  try {
    const validatedData = createMCPServerSchema.parse(req.body);
    const adminId = (req as any).user.id;

    const server = await mcpServerService.create(validatedData, adminId);

    res.status(201).json({
      success: true,
      data: server,
      message: 'MCP server created successfully',
    });
  } catch (error: any) {
    logger.error('Error in POST /admin/mcp-servers', { error });

    if (error instanceof z.ZodError) {
      res.status(400).json({
        success: false,
        error: 'Validation error',
        details: error.errors,
      });
      return;
    }

    res.status(500).json({
      success: false,
      error: error.message || 'Failed to create MCP server',
    });
  }
});

// Update MCP server
router.put('/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const validatedData = updateMCPServerSchema.parse(req.body);
    const adminId = (req as any).user.id;

    const server = await mcpServerService.update(id, validatedData, adminId);

    res.json({
      success: true,
      data: server,
      message: 'MCP server updated successfully',
    });
  } catch (error: any) {
    logger.error('Error in PUT /admin/mcp-servers/:id', { error });

    if (error instanceof z.ZodError) {
      res.status(400).json({
        success: false,
        error: 'Validation error',
        details: error.errors,
      });
      return;
    }

    if (error.message === 'MCP server not found') {
      res.status(404).json({
        success: false,
        error: error.message,
      });
      return;
    }

    res.status(500).json({
      success: false,
      error: error.message || 'Failed to update MCP server',
    });
  }
});

// Delete MCP server
router.delete('/:id', async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const adminId = (req as any).user.id;

    await mcpServerService.delete(id, adminId);

    res.json({
      success: true,
      message: 'MCP server deleted successfully',
    });
  } catch (error: any) {
    logger.error('Error in DELETE /admin/mcp-servers/:id', { error });
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to delete MCP server',
    });
  }
});

// Enable MCP server
router.put('/:id/enable', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const adminId = (req as any).user.id;

    const server = await mcpServerService.toggleEnabled(id, true, adminId);

    res.json({
      success: true,
      data: server,
      message: 'MCP server enabled successfully',
    });
  } catch (error: any) {
    logger.error('Error in PUT /admin/mcp-servers/:id/enable', { error });

    if (error.message === 'MCP server not found') {
      res.status(404).json({
        success: false,
        error: error.message,
      });
      return;
    }

    res.status(500).json({
      success: false,
      error: error.message || 'Failed to enable MCP server',
    });
  }
});

// Disable MCP server
router.put('/:id/disable', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const adminId = (req as any).user.id;

    const server = await mcpServerService.toggleEnabled(id, false, adminId);

    res.json({
      success: true,
      data: server,
      message: 'MCP server disabled successfully',
    });
  } catch (error: any) {
    logger.error('Error in PUT /admin/mcp-servers/:id/disable', { error });

    if (error.message === 'MCP server not found') {
      res.status(404).json({
        success: false,
        error: error.message,
      });
      return;
    }

    res.status(500).json({
      success: false,
      error: error.message || 'Failed to disable MCP server',
    });
  }
});

export default router;
