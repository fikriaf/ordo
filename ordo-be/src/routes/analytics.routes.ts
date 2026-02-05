/**
 * Analytics Routes
 * Enhanced data and analytics via Helius
 */

import { Router, Request, Response } from 'express';
import heliusService from '../services/helius.service';
import logger from '../config/logger';
import { authenticate } from '../middleware/auth.middleware';

const router = Router();

// Apply authentication to all routes
router.use(authenticate);

/**
 * GET /api/v1/analytics/transactions/:address
 * Get enhanced transaction history for an address
 */
router.get('/transactions/:address', async (req: Request, res: Response) => {
  try {
    const { address } = req.params;
    const limit = parseInt(req.query.limit as string) || 10;

    logger.info('Getting enhanced transactions', { address, limit });

    const transactions = await heliusService.getEnhancedTransactions(address, limit);

    res.json({
      success: true,
      data: {
        address,
        transactions,
        count: transactions.length,
      },
    });
  } catch (error: any) {
    logger.error('Get enhanced transactions error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to get enhanced transactions',
    });
  }
});

/**
 * GET /api/v1/analytics/transaction/:signature
 * Get parsed transaction by signature
 */
router.get('/transaction/:signature', async (req: Request, res: Response): Promise<void> => {
  try {
    const { signature } = req.params;

    logger.info('Getting parsed transaction', { signature });

    const transaction = await heliusService.getParsedTransaction(signature);

    if (!transaction) {
      res.status(404).json({
        success: false,
        error: 'Transaction not found',
      });
    }

    res.json({
      success: true,
      data: transaction,
    });
  } catch (error: any) {
    logger.error('Get parsed transaction error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to get parsed transaction',
    });
  }
});

/**
 * GET /api/v1/analytics/token/:mintAddress
 * Get token metadata
 */
router.get('/token/:mintAddress', async (req: Request, res: Response): Promise<void> => {
  try {
    const { mintAddress } = req.params;

    logger.info('Getting token metadata', { mintAddress });

    const metadata = await heliusService.getTokenMetadata(mintAddress);

    if (!metadata) {
      res.status(404).json({
        success: false,
        error: 'Token metadata not found',
      });
    }

    res.json({
      success: true,
      data: metadata,
    });
  } catch (error: any) {
    logger.error('Get token metadata error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to get token metadata',
    });
  }
});

/**
 * GET /api/v1/analytics/nfts/:address
 * Get NFTs owned by address
 */
router.get('/nfts/:address', async (req: Request, res: Response) => {
  try {
    const { address } = req.params;
    const limit = parseInt(req.query.limit as string) || 100;

    logger.info('Getting NFTs by owner', { address, limit });

    const nfts = await heliusService.getNFTsByOwner(address, limit);

    res.json({
      success: true,
      data: {
        address,
        nfts,
        count: nfts.length,
      },
    });
  } catch (error: any) {
    logger.error('Get NFTs error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to get NFTs',
    });
  }
});

/**
 * GET /api/v1/analytics/balances/:address
 * Get token balances with metadata
 */
router.get('/balances/:address', async (req: Request, res: Response) => {
  try {
    const { address } = req.params;

    logger.info('Getting token balances with metadata', { address });

    const balances = await heliusService.getTokenBalancesWithMetadata(address);

    res.json({
      success: true,
      data: {
        address,
        balances,
        count: balances.length,
      },
    });
  } catch (error: any) {
    logger.error('Get token balances error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to get token balances',
    });
  }
});

/**
 * GET /api/v1/analytics/search
 * Search assets by name/symbol
 */
router.get('/search', async (req: Request, res: Response): Promise<void> => {
  try {
    const query = req.query.q as string;
    const limit = parseInt(req.query.limit as string) || 20;

    if (!query) {
      res.status(400).json({
        success: false,
        error: 'Query parameter "q" is required',
      });
    }

    logger.info('Searching assets', { query, limit });

    const assets = await heliusService.searchAssets(query, limit);

    res.json({
      success: true,
      data: {
        query,
        assets,
        count: assets.length,
      },
    });
  } catch (error: any) {
    logger.error('Search assets error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to search assets',
    });
  }
});

/**
 * GET /api/v1/analytics/activity/:address
 * Get address activity summary
 */
router.get('/activity/:address', async (req: Request, res: Response) => {
  try {
    const { address } = req.params;

    logger.info('Getting address activity', { address });

    const activity = await heliusService.getAddressActivity(address);

    res.json({
      success: true,
      data: activity,
    });
  } catch (error: any) {
    logger.error('Get address activity error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to get address activity',
    });
  }
});

export default router;
