import { Router, Request, Response } from 'express';
import webhookService from '../services/webhook.service';
import { authenticate } from '../middleware/auth.middleware';
import logger from '../config/logger';

const router = Router();

/**
 * Create a new webhook
 * POST /api/v1/webhooks
 */
router.post('/', authenticate, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = (req as any).user.id;
    const { url, events, description, retryCount, timeoutSeconds, metadata } = req.body;

    if (!url) {
      res.status(400).json({
        success: false,
        error: 'url is required',
      });
    }

    if (!events || !Array.isArray(events) || events.length === 0) {
      res.status(400).json({
        success: false,
        error: 'events array is required and must not be empty',
      });
    }

    const webhook = await webhookService.createWebhook({
      userId,
      url,
      events,
      description,
      retryCount,
      timeoutSeconds,
      metadata,
    });

    res.json({
      success: true,
      data: webhook,
    });
  } catch (error: any) {
    logger.error('Create webhook error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to create webhook',
    });
  }
});

/**
 * Get user's webhooks
 * GET /api/v1/webhooks
 */
router.get('/', authenticate, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).user.id;

    const webhooks = await webhookService.getUserWebhooks(userId);

    res.json({
      success: true,
      data: {
        webhooks,
        count: webhooks.length,
      },
    });
  } catch (error: any) {
    logger.error('Get webhooks error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to get webhooks',
    });
  }
});

/**
 * Get webhook by ID
 * GET /api/v1/webhooks/:id
 */
router.get('/:id', authenticate, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = (req as any).user.id;
    const { id } = req.params;

    const webhook = await webhookService.getWebhook(id, userId);

    if (!webhook) {
      res.status(404).json({
        success: false,
        error: 'Webhook not found',
      });
    }

    res.json({
      success: true,
      data: webhook,
    });
  } catch (error: any) {
    logger.error('Get webhook error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to get webhook',
    });
  }
});

/**
 * Update webhook
 * PUT /api/v1/webhooks/:id
 */
router.put('/:id', authenticate, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).user.id;
    const { id } = req.params;
    const updates = req.body;

    const webhook = await webhookService.updateWebhook(id, userId, updates);

    res.json({
      success: true,
      data: webhook,
    });
  } catch (error: any) {
    logger.error('Update webhook error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to update webhook',
    });
  }
});

/**
 * Delete webhook
 * DELETE /api/v1/webhooks/:id
 */
router.delete('/:id', authenticate, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).user.id;
    const { id } = req.params;

    await webhookService.deleteWebhook(id, userId);

    res.json({
      success: true,
      message: 'Webhook deleted successfully',
    });
  } catch (error: any) {
    logger.error('Delete webhook error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to delete webhook',
    });
  }
});

/**
 * Toggle webhook active status
 * PATCH /api/v1/webhooks/:id/toggle
 */
router.patch('/:id/toggle', authenticate, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = (req as any).user.id;
    const { id } = req.params;
    const { isActive } = req.body;

    if (isActive === undefined) {
      res.status(400).json({
        success: false,
        error: 'isActive is required',
      });
    }

    await webhookService.toggleWebhook(id, userId, isActive);

    res.json({
      success: true,
      message: `Webhook ${isActive ? 'activated' : 'deactivated'}`,
    });
  } catch (error: any) {
    logger.error('Toggle webhook error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to toggle webhook',
    });
  }
});

/**
 * Test webhook
 * POST /api/v1/webhooks/:id/test
 */
router.post('/:id/test', authenticate, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).user.id;
    const { id } = req.params;

    const delivery = await webhookService.testWebhook(id, userId);

    res.json({
      success: true,
      data: delivery,
      message: delivery.status === 'success' 
        ? 'Webhook test successful' 
        : 'Webhook test failed',
    });
  } catch (error: any) {
    logger.error('Test webhook error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to test webhook',
    });
  }
});

/**
 * Get webhook deliveries
 * GET /api/v1/webhooks/:id/deliveries
 */
router.get('/:id/deliveries', authenticate, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).user.id;
    const { id } = req.params;
    const { limit = 50 } = req.query;

    const deliveries = await webhookService.getWebhookDeliveries(
      id,
      userId,
      parseInt(limit as string)
    );

    res.json({
      success: true,
      data: {
        deliveries,
        count: deliveries.length,
      },
    });
  } catch (error: any) {
    logger.error('Get webhook deliveries error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to get webhook deliveries',
    });
  }
});

/**
 * Get available event types
 * GET /api/v1/webhooks/events/available
 */
router.get('/events/available', authenticate, async (_req: Request, res: Response) => {
  try {
    const events = webhookService.getAvailableEvents();

    res.json({
      success: true,
      data: {
        events,
        count: events.length,
      },
    });
  } catch (error: any) {
    logger.error('Get available events error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to get available events',
    });
  }
});

/**
 * Cleanup old deliveries (admin only)
 * POST /api/v1/webhooks/cleanup
 */
router.post('/cleanup/deliveries', authenticate, async (req: Request, res: Response) => {
  try {
    const { daysToKeep = 30 } = req.body;

    const deletedCount = await webhookService.cleanupOldDeliveries(daysToKeep);

    res.json({
      success: true,
      data: {
        deletedCount,
      },
      message: `Cleaned up ${deletedCount} old webhook deliveries`,
    });
  } catch (error: any) {
    logger.error('Cleanup deliveries error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to cleanup deliveries',
    });
  }
});

export default router;
