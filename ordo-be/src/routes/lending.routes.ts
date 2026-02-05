import { Router, Request, Response } from 'express';
import lendingService from '../services/lending.service';
import { authenticate } from '../middleware/auth.middleware';
import logger from '../config/logger';

const router = Router();

/**
 * @route POST /api/v1/lend
 * @desc Lend assets to earn interest
 * @access Private
 */
router.post('/', authenticate, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = (req as any).user.id;
    const { walletId, amount, asset, protocol, assetPriceUsd = 1 } = req.body;

    // Validation
    if (!walletId || !amount || !asset || !protocol) {
      res.status(400).json({
        success: false,
        error: 'Missing required fields: walletId, amount, asset, protocol',
      });
    }

    if (amount <= 0) {
      res.status(400).json({
        success: false,
        error: 'Amount must be greater than 0',
      });
    }

    if (!['kamino', 'marginfi', 'solend'].includes(protocol)) {
      res.status(400).json({
        success: false,
        error: 'Invalid protocol. Must be: kamino, marginfi, or solend',
      });
    }

    // Execute with approval check
    const result = await lendingService.lendWithApproval(
      userId,
      walletId,
      { amount, asset, protocol },
      assetPriceUsd
    );

    // If approval required, return 202 Accepted
    if (result.approval_required) {
      res.status(202).json({
        success: true,
        approval_required: true,
        approval_id: result.approval_id,
        message: result.message,
      });
    }

    // Otherwise return success
    res.json({
      success: true,
      data: {
        signature: result.signature,
        positionId: result.positionId,
      },
      message: result.message,
    });
  } catch (error: any) {
    logger.error('Lend endpoint error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to lend assets',
    });
  }
});

/**
 * @route POST /api/v1/lend/borrow
 * @desc Borrow assets with collateral
 * @access Private
 */
router.post('/borrow', authenticate, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = (req as any).user.id;
    const { 
      walletId, 
      amount, 
      asset, 
      collateralAsset, 
      collateralAmount, 
      protocol,
      assetPriceUsd = 1,
      collateralPriceUsd = 1
    } = req.body;

    // Validation
    if (!walletId || !amount || !asset || !collateralAsset || !collateralAmount || !protocol) {
      res.status(400).json({
        success: false,
        error: 'Missing required fields: walletId, amount, asset, collateralAsset, collateralAmount, protocol',
      });
    }

    if (amount <= 0 || collateralAmount <= 0) {
      res.status(400).json({
        success: false,
        error: 'Amount and collateralAmount must be greater than 0',
      });
    }

    if (!['kamino', 'marginfi', 'solend'].includes(protocol)) {
      res.status(400).json({
        success: false,
        error: 'Invalid protocol. Must be: kamino, marginfi, or solend',
      });
    }

    // Execute with approval check
    const result = await lendingService.borrowWithApproval(
      userId,
      walletId,
      { amount, asset, collateralAsset, collateralAmount, protocol },
      assetPriceUsd,
      collateralPriceUsd
    );

    // If approval required, return 202 Accepted
    if (result.approval_required) {
      res.status(202).json({
        success: true,
        approval_required: true,
        approval_id: result.approval_id,
        message: result.message,
      });
    }

    // Otherwise return success
    res.json({
      success: true,
      data: {
        signature: result.signature,
        loanId: result.loanId,
        healthFactor: result.healthFactor,
      },
      message: result.message,
    });
  } catch (error: any) {
    logger.error('Borrow endpoint error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to borrow assets',
    });
  }
});

/**
 * @route POST /api/v1/lend/repay
 * @desc Repay borrowed assets
 * @access Private
 */
router.post('/repay', authenticate, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = (req as any).user.id;
    const { walletId, amount, asset, protocol, loanId } = req.body;

    // Validation
    if (!walletId || !amount || !asset || !protocol) {
      res.status(400).json({
        success: false,
        error: 'Missing required fields: walletId, amount, asset, protocol',
      });
    }

    if (amount <= 0) {
      res.status(400).json({
        success: false,
        error: 'Amount must be greater than 0',
      });
    }

    if (!['kamino', 'marginfi', 'solend'].includes(protocol)) {
      res.status(400).json({
        success: false,
        error: 'Invalid protocol. Must be: kamino, marginfi, or solend',
      });
    }

    const result = await lendingService.repay(userId, walletId, {
      amount,
      asset,
      protocol,
      loanId,
    });

    res.json({
      success: true,
      data: result,
      message: 'Loan repaid successfully',
    });
  } catch (error: any) {
    logger.error('Repay endpoint error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to repay loan',
    });
  }
});

/**
 * @route POST /api/v1/lend/withdraw
 * @desc Withdraw lent assets
 * @access Private
 */
router.post('/withdraw', authenticate, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = (req as any).user.id;
    const { walletId, amount, asset, protocol, positionId } = req.body;

    // Validation
    if (!walletId || !amount || !asset || !protocol) {
      res.status(400).json({
        success: false,
        error: 'Missing required fields: walletId, amount, asset, protocol',
      });
    }

    if (amount <= 0) {
      res.status(400).json({
        success: false,
        error: 'Amount must be greater than 0',
      });
    }

    if (!['kamino', 'marginfi', 'solend'].includes(protocol)) {
      res.status(400).json({
        success: false,
        error: 'Invalid protocol. Must be: kamino, marginfi, or solend',
      });
    }

    const result = await lendingService.withdraw(userId, walletId, {
      amount,
      asset,
      protocol,
      positionId,
    });

    res.json({
      success: true,
      data: result,
      message: 'Assets withdrawn successfully',
    });
  } catch (error: any) {
    logger.error('Withdraw endpoint error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to withdraw assets',
    });
  }
});

/**
 * @route GET /api/v1/lend/positions
 * @desc Get user's lending positions
 * @access Private
 */
router.get('/positions', authenticate, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = (req as any).user.id;
    const { walletId } = req.query;

    if (!walletId) {
      res.status(400).json({
        success: false,
        error: 'Missing required query parameter: walletId',
      });
    }

    const positions = await lendingService.getLendingPositions(userId, walletId as string);

    res.json({
      success: true,
      data: {
        positions,
        count: positions.length,
      },
    });
  } catch (error: any) {
    logger.error('Get lending positions endpoint error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to get lending positions',
    });
  }
});

/**
 * @route GET /api/v1/lend/rates
 * @desc Get current interest rates
 * @access Private
 */
router.get('/rates', authenticate, async (_req: Request, res: Response) => {
  try {
    const rates = await lendingService.getInterestRates();

    res.json({
      success: true,
      data: rates,
    });
  } catch (error: any) {
    logger.error('Get interest rates endpoint error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to get interest rates',
    });
  }
});

export default router;
