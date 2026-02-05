import { Router, Request, Response } from 'express';
import priceFeedService from '../services/price-feed.service';
import { authenticate } from '../middleware/auth.middleware';
import logger from '../config/logger';

const router = Router();

/**
 * Get price for a single token
 * GET /api/v1/price/:tokenMint
 */
router.get('/:tokenMint', authenticate, async (req: Request, res: Response) => {
  try {
    const { tokenMint } = req.params;
    const { pythPriceId } = req.query;

    const priceData = await priceFeedService.getPrice(
      tokenMint,
      pythPriceId as string | undefined
    );

    res.json({
      success: true,
      data: {
        tokenMint,
        ...priceData,
      },
    });
  } catch (error: any) {
    logger.error('Get price error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to get price',
    });
  }
});

/**
 * Get prices for multiple tokens (batch)
 * POST /api/v1/price/batch
 * Body: { tokens: [{ tokenMint: string, pythPriceId?: string }] }
 */
router.post('/batch', authenticate, async (req: Request, res: Response): Promise<void> => {
  try {
    const { tokens } = req.body;

    if (!tokens || !Array.isArray(tokens)) {
      res.status(400).json({
        success: false,
        error: 'tokens array is required',
      });
    }

    const prices = await priceFeedService.getBatchPrices(tokens);

    // Convert Map to object for JSON response
    const pricesObject: Record<string, any> = {};
    prices.forEach((value, key) => {
      pricesObject[key] = value;
    });

    res.json({
      success: true,
      data: {
        prices: pricesObject,
        count: prices.size,
      },
    });
  } catch (error: any) {
    logger.error('Batch price fetch error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to fetch batch prices',
    });
  }
});

/**
 * Get SOL price
 * GET /api/v1/price/sol
 */
router.get('/sol/current', authenticate, async (_req: Request, res: Response) => {
  try {
    const price = await priceFeedService.getSolPrice();

    res.json({
      success: true,
      data: {
        symbol: 'SOL',
        price,
        currency: 'USD',
      },
    });
  } catch (error: any) {
    logger.error('Get SOL price error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to get SOL price',
    });
  }
});

/**
 * Get USDC price
 * GET /api/v1/price/usdc
 */
router.get('/usdc/current', authenticate, async (_req: Request, res: Response) => {
  try {
    const price = await priceFeedService.getUsdcPrice();

    res.json({
      success: true,
      data: {
        symbol: 'USDC',
        price,
        currency: 'USD',
      },
    });
  } catch (error: any) {
    logger.error('Get USDC price error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to get USDC price',
    });
  }
});

/**
 * Get supported tokens
 * GET /api/v1/price/supported
 */
router.get('/supported/tokens', authenticate, async (_req: Request, res: Response) => {
  try {
    const tokens = priceFeedService.getSupportedTokens();

    res.json({
      success: true,
      data: {
        tokens,
        count: tokens.length,
      },
    });
  } catch (error: any) {
    logger.error('Get supported tokens error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to get supported tokens',
    });
  }
});

/**
 * Get cache statistics (admin only)
 * GET /api/v1/price/cache/stats
 */
router.get('/cache/stats', authenticate, async (_req: Request, res: Response) => {
  try {
    const stats = priceFeedService.getCacheStats();

    res.json({
      success: true,
      data: stats,
    });
  } catch (error: any) {
    logger.error('Get cache stats error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to get cache stats',
    });
  }
});

/**
 * Clear price cache (admin only)
 * DELETE /api/v1/price/cache
 */
router.delete('/cache', authenticate, async (req: Request, res: Response) => {
  try {
    const { tokenMint } = req.query;

    priceFeedService.clearCache(tokenMint as string | undefined);

    res.json({
      success: true,
      message: tokenMint
        ? `Cache cleared for token: ${tokenMint}`
        : 'All price cache cleared',
    });
  } catch (error: any) {
    logger.error('Clear cache error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to clear cache',
    });
  }
});

export default router;
