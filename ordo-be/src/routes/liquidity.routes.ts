/**
 * Liquidity Routes
 * Liquidity pool operations
 */

import { Router, Response } from 'express';
import { body, param, validationResult } from 'express-validator';
import { authenticate } from '../middleware/auth.middleware';
import { AuthenticatedRequest } from '../types';
import liquidityService from '../services/liquidity.service';
import logger from '../config/logger';

const router = Router();

// All routes require authentication
router.use(authenticate);

/**
 * POST /api/v1/liquidity/add
 * Add liquidity to a pool
 */
router.post(
  '/add',
  [
    body('walletId').isUUID().withMessage('Valid wallet ID required'),
    body('protocol').isIn(['raydium', 'meteora', 'orca']).withMessage('Invalid protocol'),
    body('tokenA').isString().trim().notEmpty().withMessage('Token A required'),
    body('tokenB').isString().trim().notEmpty().withMessage('Token B required'),
    body('amountA').isFloat({ gt: 0 }).withMessage('Amount A must be greater than 0'),
    body('amountB').isFloat({ gt: 0 }).withMessage('Amount B must be greater than 0'),
    body('slippage').optional().isFloat({ min: 0, max: 100 }).withMessage('Slippage must be 0-100'),
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

      const { walletId, protocol, tokenA, tokenB, amountA, amountB, slippage } = req.body;
      const userId = req.user!.id;

      const result = await liquidityService.addLiquidity(userId, walletId, {
        protocol,
        tokenA,
        tokenB,
        amountA,
        amountB,
        slippage,
      });

      return res.json({
        success: true,
        data: result,
        message: 'Liquidity added successfully',
      });
    } catch (error: any) {
      logger.error('Add liquidity error:', error);
      return res.status(500).json({
        success: false,
        error: error.message || 'Failed to add liquidity',
      });
    }
  }
);

/**
 * POST /api/v1/liquidity/remove
 * Remove liquidity from a pool
 */
router.post(
  '/remove',
  [
    body('walletId').isUUID().withMessage('Valid wallet ID required'),
    body('positionId').isUUID().withMessage('Valid position ID required'),
    body('protocol').isIn(['raydium', 'meteora', 'orca']).withMessage('Invalid protocol'),
    body('percentage').isFloat({ min: 0, max: 100 }).withMessage('Percentage must be 0-100'),
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

      const { walletId, positionId, protocol, percentage } = req.body;
      const userId = req.user!.id;

      const result = await liquidityService.removeLiquidity(userId, walletId, {
        protocol,
        positionId,
        percentage,
      });

      return res.json({
        success: true,
        data: result,
        message: 'Liquidity removed successfully',
      });
    } catch (error: any) {
      logger.error('Remove liquidity error:', error);
      return res.status(500).json({
        success: false,
        error: error.message || 'Failed to remove liquidity',
      });
    }
  }
);

/**
 * GET /api/v1/liquidity/positions
 * Get user's liquidity positions
 */
router.get('/positions', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.id;

    const positions = await liquidityService.getPositions(userId);

    return res.json({
      success: true,
      data: positions,
      count: positions.length,
    });
  } catch (error: any) {
    logger.error('Get positions error:', error);
    return res.status(500).json({
      success: false,
      error: error.message || 'Failed to get positions',
    });
  }
});

/**
 * GET /api/v1/liquidity/position/:id/value
 * Get position value
 */
router.get(
  '/position/:id/value',
  [
    param('id').isUUID().withMessage('Valid position ID required'),
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

      const { id } = req.params;
      const userId = req.user!.id;

      const value = await liquidityService.getPositionValue(id, userId);

      return res.json({
        success: true,
        data: value,
      });
    } catch (error: any) {
      logger.error('Get position value error:', error);
      return res.status(500).json({
        success: false,
        error: error.message || 'Failed to get position value',
      });
    }
  }
);

/**
 * GET /api/v1/liquidity/position/:id/il
 * Get impermanent loss for a position
 */
router.get(
  '/position/:id/il',
  [
    param('id').isUUID().withMessage('Valid position ID required'),
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

      const { id } = req.params;
      const userId = req.user!.id;

      const il = await liquidityService.calculateImpermanentLoss(id, userId);

      return res.json({
        success: true,
        data: il,
      });
    } catch (error: any) {
      logger.error('Calculate impermanent loss error:', error);
      return res.status(500).json({
        success: false,
        error: error.message || 'Failed to calculate impermanent loss',
      });
    }
  }
);

export default router;
