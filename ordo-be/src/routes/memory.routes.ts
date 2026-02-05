import { Router, Request, Response } from 'express';
import agentMemoryService from '../services/agent-memory.service';
import { authenticate } from '../middleware/auth.middleware';
import logger from '../config/logger';

const router = Router();

/**
 * Store a new memory
 * POST /api/v1/memory/store
 */
router.post('/store', authenticate, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = (req as any).user.id;
    const {
      conversationId,
      content,
      memoryType,
      importanceScore,
      metadata,
      tags,
      expiresAt,
    } = req.body;

    if (!content) {
      res.status(400).json({
        success: false,
        error: 'content is required',
      });
    }

    if (!memoryType) {
      res.status(400).json({
        success: false,
        error: 'memoryType is required (conversation, decision, preference, fact, instruction)',
      });
    }

    const memory = await agentMemoryService.storeMemory({
      userId,
      conversationId,
      content,
      memoryType,
      importanceScore,
      metadata,
      tags,
      expiresAt: expiresAt ? new Date(expiresAt) : undefined,
    });

    res.json({
      success: true,
      data: memory,
    });
  } catch (error: any) {
    logger.error('Store memory error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to store memory',
    });
  }
});

/**
 * Semantic search for memories
 * POST /api/v1/memory/search
 */
router.post('/search', authenticate, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = (req as any).user.id;
    const { query, limit = 5, minSimilarity = 0.7 } = req.body;

    if (!query) {
      res.status(400).json({
        success: false,
        error: 'query is required',
      });
    }

    const results = await agentMemoryService.searchMemories(
      userId,
      query,
      limit,
      minSimilarity
    );

    res.json({
      success: true,
      data: {
        results,
        count: results.length,
      },
    });
  } catch (error: any) {
    logger.error('Search memories error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to search memories',
    });
  }
});

/**
 * Get recent memories
 * GET /api/v1/memory/recent
 */
router.get('/recent', authenticate, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).user.id;
    const { limit = 10, type } = req.query;

    const memories = await agentMemoryService.getRecentMemories(
      userId,
      parseInt(limit as string),
      type as string | undefined
    );

    res.json({
      success: true,
      data: {
        memories,
        count: memories.length,
      },
    });
  } catch (error: any) {
    logger.error('Get recent memories error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to get recent memories',
    });
  }
});

/**
 * Get memory by ID
 * GET /api/v1/memory/:id
 */
router.get('/:id', authenticate, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = (req as any).user.id;
    const { id } = req.params;

    const memory = await agentMemoryService.getMemory(id, userId);

    if (!memory) {
      res.status(404).json({
        success: false,
        error: 'Memory not found',
      });
    }

    res.json({
      success: true,
      data: memory,
    });
  } catch (error: any) {
    logger.error('Get memory error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to get memory',
    });
  }
});

/**
 * Delete a memory
 * DELETE /api/v1/memory/:id
 */
router.delete('/:id', authenticate, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).user.id;
    const { id } = req.params;

    await agentMemoryService.deleteMemory(id, userId);

    res.json({
      success: true,
      message: 'Memory deleted successfully',
    });
  } catch (error: any) {
    logger.error('Delete memory error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to delete memory',
    });
  }
});

/**
 * Update memory importance
 * PATCH /api/v1/memory/:id/importance
 */
router.patch('/:id/importance', authenticate, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = (req as any).user.id;
    const { id } = req.params;
    const { importanceScore } = req.body;

    if (importanceScore === undefined) {
      res.status(400).json({
        success: false,
        error: 'importanceScore is required',
      });
    }

    await agentMemoryService.updateImportance(id, userId, importanceScore);

    res.json({
      success: true,
      message: 'Memory importance updated',
    });
  } catch (error: any) {
    logger.error('Update memory importance error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to update memory importance',
    });
  }
});

/**
 * Get memory statistics
 * GET /api/v1/memory/stats
 */
router.get('/stats/user', authenticate, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).user.id;

    const stats = await agentMemoryService.getMemoryStats(userId);

    res.json({
      success: true,
      data: stats,
    });
  } catch (error: any) {
    logger.error('Get memory stats error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to get memory stats',
    });
  }
});

/**
 * Get memories by tags
 * POST /api/v1/memory/tags
 */
router.post('/tags', authenticate, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = (req as any).user.id;
    const { tags, limit = 10 } = req.body;

    if (!tags || !Array.isArray(tags)) {
      res.status(400).json({
        success: false,
        error: 'tags array is required',
      });
    }

    const memories = await agentMemoryService.getMemoriesByTags(userId, tags, limit);

    res.json({
      success: true,
      data: {
        memories,
        count: memories.length,
      },
    });
  } catch (error: any) {
    logger.error('Get memories by tags error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to get memories by tags',
    });
  }
});

/**
 * Cleanup expired memories (admin only)
 * POST /api/v1/memory/cleanup
 */
router.post('/cleanup', authenticate, async (_req: Request, res: Response) => {
  try {
    const deletedCount = await agentMemoryService.cleanupExpiredMemories();

    res.json({
      success: true,
      data: {
        deletedCount,
      },
      message: `Cleaned up ${deletedCount} expired memories`,
    });
  } catch (error: any) {
    logger.error('Cleanup expired memories error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to cleanup expired memories',
    });
  }
});

export default router;
