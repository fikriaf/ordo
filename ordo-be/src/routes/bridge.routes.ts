import { Router, Request, Response } from 'express';
import { authenticate } from '../middleware/auth.middleware';
import bridgeService from '../services/bridge.service';
import logger from '../config/logger';

const router = Router();

/**
 * POST /api/v1/bridge/quote
 * Get bridge quote
 */
router.post('/quote', authenticate, async (req: Request, res: Response): Promise<void> => {
  try {
    const { sourceChain, destinationChain, sourceToken, destinationToken, amount, protocol } = req.body;

    // Validation
    if (!sourceChain || !destinationChain || !sourceToken || !destinationToken || !amount || !protocol) {
      res.status(400).json({
        success: false,
        error: 'Missing required fields: sourceChain, destinationChain, sourceToken, destinationToken, amount, protocol',
      });
    }

    if (amount <= 0) {
      res.status(400).json({
        success: false,
        error: 'Amount must be greater than 0',
      });
    }

    if (!['wormhole', 'mayan', 'debridge'].includes(protocol)) {
      res.status(400).json({
        success: false,
        error: 'Invalid protocol. Must be: wormhole, mayan, or debridge',
      });
    }

    const quote = await bridgeService.getQuote({
      sourceChain,
      destinationChain,
      sourceToken,
      destinationToken,
      amount,
      protocol,
    });

    res.json({
      success: true,
      data: quote,
    });
  } catch (error: any) {
    logger.error('Bridge quote endpoint error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to get bridge quote',
    });
  }
});

/**
 * POST /api/v1/bridge/execute
 * Execute bridge transaction
 */
router.post('/execute', authenticate, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = (req as any).user.id;
    const {
      walletId,
      sourceChain,
      destinationChain,
      sourceToken,
      destinationToken,
      amount,
      destinationAddress,
      protocol,
      quoteData,
    } = req.body;

    // Validation
    if (
      !walletId ||
      !sourceChain ||
      !destinationChain ||
      !sourceToken ||
      !destinationToken ||
      !amount ||
      !destinationAddress ||
      !protocol
    ) {
      res.status(400).json({
        success: false,
        error:
          'Missing required fields: walletId, sourceChain, destinationChain, sourceToken, destinationToken, amount, destinationAddress, protocol',
      });
    }

    if (amount <= 0) {
      res.status(400).json({
        success: false,
        error: 'Amount must be greater than 0',
      });
    }

    if (!['wormhole', 'mayan', 'debridge'].includes(protocol)) {
      res.status(400).json({
        success: false,
        error: 'Invalid protocol. Must be: wormhole, mayan, or debridge',
      });
    }

    const result = await bridgeService.executeBridge(userId, walletId, {
      sourceChain,
      destinationChain,
      sourceToken,
      destinationToken,
      amount,
      destinationAddress,
      protocol,
      quoteData,
    });

    res.json({
      success: true,
      data: result,
      message: 'Bridge transaction initiated successfully',
    });
  } catch (error: any) {
    logger.error('Bridge execute endpoint error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to execute bridge transaction',
    });
  }
});

/**
 * GET /api/v1/bridge/status/:txId
 * Get bridge transaction status
 */
router.get('/status/:txId', authenticate, async (req: Request, res: Response): Promise<void> => {
  try {
    const { txId } = req.params;
    const { protocol } = req.query;

    if (!protocol) {
      res.status(400).json({
        success: false,
        error: 'Missing required query parameter: protocol',
      });
    }

    if (!['wormhole', 'mayan', 'debridge'].includes(protocol as string)) {
      res.status(400).json({
        success: false,
        error: 'Invalid protocol. Must be: wormhole, mayan, or debridge',
      });
    }

    const status = await bridgeService.getBridgeStatus(txId, protocol as string);

    res.json({
      success: true,
      data: status,
    });
  } catch (error: any) {
    logger.error('Bridge status endpoint error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to get bridge status',
    });
  }
});

/**
 * GET /api/v1/bridge/supported-chains
 * Get supported chains
 */
router.get('/supported-chains', authenticate, async (_req: Request, res: Response) => {
  try {
    const chains = await bridgeService.getSupportedChains();

    res.json({
      success: true,
      data: chains,
    });
  } catch (error: any) {
    logger.error('Get supported chains endpoint error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to get supported chains',
    });
  }
});

/**
 * GET /api/v1/bridge/history
 * Get bridge history
 */
router.get('/history', authenticate, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).user.id;
    const limit = parseInt(req.query.limit as string) || 20;

    const history = await bridgeService.getBridgeHistory(userId, limit);

    res.json({
      success: true,
      data: history,
    });
  } catch (error: any) {
    logger.error('Bridge history endpoint error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to get bridge history',
    });
  }
});

export default router;
