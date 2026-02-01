import { Router, Request, Response } from 'express';
import healthService from '../services/health.service';
import logger from '../config/logger';

const router = Router();

// Basic health check - fast, minimal overhead
router.get('/', async (_req: Request, res: Response) => {
  try {
    const health = await healthService.getBasicHealth();
    const statusCode = health.status === 'healthy' ? 200 : 503;
    res.status(statusCode).json(health);
  } catch (error) {
    logger.error('Health check error:', error);
    res.status(503).json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      error: 'Health check failed',
    });
  }
});

// Detailed health check - includes dependency checks
router.get('/detailed', async (_req: Request, res: Response) => {
  try {
    const health = await healthService.getDetailedHealth();
    const statusCode = health.status === 'healthy' ? 200 : 
                      health.status === 'degraded' ? 200 : 503;
    res.status(statusCode).json(health);
  } catch (error) {
    logger.error('Detailed health check error:', error);
    res.status(503).json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      error: 'Detailed health check failed',
    });
  }
});

export default router;
