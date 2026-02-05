/**
 * Portfolio Routes
 * Portfolio aggregation and analytics
 */

import { Router, Response } from 'express';
import { query, validationResult } from 'express-validator';
import { authenticate } from '../middleware/auth.middleware';
import { AuthenticatedRequest } from '../types';
import portfolioService from '../services/portfolio.service';
import birdeyeService from '../services/birdeye.service';
import logger from '../config/logger';

const router = Router();

// All routes require authentication
router.use(authenticate);

/**
 * GET /api/v1/portfolio/summary
 * Get portfolio summary across all chains
 */
router.get('/summary', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.id;

    const summary = await portfolioService.getPortfolioSummary(userId);

    return res.json({
      success: true,
      data: summary,
    });
  } catch (error: any) {
    logger.error('Get portfolio summary error:', error);
    return res.status(500).json({
      success: false,
      error: error.message || 'Failed to get portfolio summary',
    });
  }
});

/**
 * GET /api/v1/portfolio/performance
 * Get portfolio performance metrics
 */
router.get('/performance', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.id;

    const performance = await portfolioService.getPerformanceMetrics(userId);

    return res.json({
      success: true,
      data: performance,
    });
  } catch (error: any) {
    logger.error('Get portfolio performance error:', error);
    return res.status(500).json({
      success: false,
      error: error.message || 'Failed to get portfolio performance',
    });
  }
});

/**
 * GET /api/v1/market/token/:address
 * Get token market data
 */
router.get('/market/token/:address', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { address } = req.params;

    const marketData = await birdeyeService.getTokenMarketData(address);

    if (!marketData) {
      return res.status(404).json({
        success: false,
        error: 'Token market data not found',
      });
    }

    return res.json({
      success: true,
      data: marketData,
    });
  } catch (error: any) {
    logger.error('Get token market data error:', error);
    return res.status(500).json({
      success: false,
      error: error.message || 'Failed to get token market data',
    });
  }
});

/**
 * GET /api/v1/market/trending
 * Get trending tokens
 */
router.get(
  '/market/trending',
  [
    query('limit').optional().isInt({ min: 1, max: 100 }).withMessage('Limit must be between 1-100'),
  ],
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          success: false,
          errors: errors.array(),
        });
      }

      const limit = req.query.limit ? parseInt(req.query.limit as string) : 20;

      const trending = await birdeyeService.getTrendingTokens(limit);

      return res.json({
        success: true,
        data: trending,
        count: trending.length,
      });
    } catch (error: any) {
      logger.error('Get trending tokens error:', error);
      return res.status(500).json({
        success: false,
        error: error.message || 'Failed to get trending tokens',
      });
    }
  }
);

/**
 * GET /api/v1/price/:address/history
 * Get price history for a token
 */
router.get(
  '/price/:address/history',
  [
    query('timeframe').optional().isIn(['1H', '4H', '1D', '1W', '1M']).withMessage('Invalid timeframe'),
  ],
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          success: false,
          errors: errors.array(),
        });
      }

      const { address } = req.params;
      const timeframe = (req.query.timeframe as '1H' | '4H' | '1D' | '1W' | '1M') || '1D';

      const history = await birdeyeService.getPriceHistory(address, timeframe);

      if (!history) {
        return res.status(404).json({
          success: false,
          error: 'Price history not found',
        });
      }

      return res.json({
        success: true,
        data: history,
      });
    } catch (error: any) {
      logger.error('Get price history error:', error);
      return res.status(500).json({
        success: false,
        error: error.message || 'Failed to get price history',
      });
    }
  }
);

export default router;
