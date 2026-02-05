import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { authenticate } from '../middleware/auth.middleware';
import stakingService from '../services/staking.service';
import logger from '../config/logger';

const router = Router();

// Validation schemas
const stakeSchema = z.object({
  walletId: z.string().uuid(),
  amount: z.number().positive(),
  protocol: z.enum(['marinade', 'jito', 'sanctum']),
});

const unstakeSchema = z.object({
  walletId: z.string().uuid(),
  amount: z.number().positive(),
  protocol: z.enum(['marinade', 'jito', 'sanctum']),
  stakeAccountAddress: z.string().optional(),
});

/**
 * POST /api/v1/stake
 * Stake SOL tokens
 */
router.post('/', authenticate, async (req: Request, res: Response) => {
  try {
    const validation = stakeSchema.safeParse(req.body);
    if (!validation.success) {
      return res.status(400).json({
        success: false,
        error: {
          code: 'VALIDATION_ERROR',
          message: 'Invalid request data',
          details: validation.error.errors,
        },
      });
    }

    const { walletId, amount, protocol } = validation.data;
    const userId = (req as any).user.userId;

    const result = await stakingService.stake(userId, walletId, {
      amount,
      protocol,
    });

    return res.json({
      success: true,
      data: result,
    });
  } catch (error: any) {
    logger.error('Stake endpoint error:', error);
    return res.status(500).json({
      success: false,
      error: {
        code: 'STAKE_ERROR',
        message: error.message || 'Failed to stake tokens',
      },
    });
  }
});

/**
 * POST /api/v1/stake/unstake
 * Unstake SOL tokens
 */
router.post('/unstake', authenticate, async (req: Request, res: Response) => {
  try {
    const validation = unstakeSchema.safeParse(req.body);
    if (!validation.success) {
      return res.status(400).json({
        success: false,
        error: {
          code: 'VALIDATION_ERROR',
          message: 'Invalid request data',
          details: validation.error.errors,
        },
      });
    }

    const { walletId, amount, protocol, stakeAccountAddress } = validation.data;
    const userId = (req as any).user.userId;

    const result = await stakingService.unstake(userId, walletId, {
      amount,
      protocol,
      stakeAccountAddress,
    });

    return res.json({
      success: true,
      data: result,
    });
  } catch (error: any) {
    logger.error('Unstake endpoint error:', error);
    return res.status(500).json({
      success: false,
      error: {
        code: 'UNSTAKE_ERROR',
        message: error.message || 'Failed to unstake tokens',
      },
    });
  }
});

/**
 * GET /api/v1/stake/positions
 * Get user's staking positions
 */
router.get('/positions', authenticate, async (req: Request, res: Response) => {
  try {
    const walletId = req.query.walletId as string;

    if (!walletId) {
      return res.status(400).json({
        success: false,
        error: {
          code: 'VALIDATION_ERROR',
          message: 'walletId is required',
        },
      });
    }

    const userId = (req as any).user.userId;

    const positions = await stakingService.getStakingPositions(userId, walletId);

    return res.json({
      success: true,
      data: {
        positions,
        count: positions.length,
      },
    });
  } catch (error: any) {
    logger.error('Get staking positions endpoint error:', error);
    return res.status(500).json({
      success: false,
      error: {
        code: 'GET_POSITIONS_ERROR',
        message: error.message || 'Failed to get staking positions',
      },
    });
  }
});

/**
 * GET /api/v1/stake/rewards
 * Get user's staking rewards
 */
router.get('/rewards', authenticate, async (req: Request, res: Response) => {
  try {
    const walletId = req.query.walletId as string;

    if (!walletId) {
      return res.status(400).json({
        success: false,
        error: {
          code: 'VALIDATION_ERROR',
          message: 'walletId is required',
        },
      });
    }

    const userId = (req as any).user.userId;

    const rewards = await stakingService.getStakingRewards(userId, walletId);

    return res.json({
      success: true,
      data: rewards,
    });
  } catch (error: any) {
    logger.error('Get staking rewards endpoint error:', error);
    return res.status(500).json({
      success: false,
      error: {
        code: 'GET_REWARDS_ERROR',
        message: error.message || 'Failed to get staking rewards',
      },
    });
  }
});

/**
 * GET /api/v1/stake/apy
 * Get current APY rates for all protocols
 */
router.get('/apy', async (_req: Request, res: Response) => {
  try {
    const apyRates = await stakingService.getAPYRates();

    return res.json({
      success: true,
      data: apyRates,
    });
  } catch (error: any) {
    logger.error('Get APY rates endpoint error:', error);
    return res.status(500).json({
      success: false,
      error: {
        code: 'GET_APY_ERROR',
        message: error.message || 'Failed to get APY rates',
      },
    });
  }
});

export default router;
