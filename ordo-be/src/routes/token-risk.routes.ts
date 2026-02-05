/**
 * Token Risk Scoring Routes
 * Provides risk assessment for Solana tokens
 */

import { Router, Response } from 'express';
import { param, query, validationResult } from 'express-validator';
import { authenticate } from '../middleware/auth.middleware';
import { AuthenticatedRequest } from '../types';
import tokenRiskService from '../services/token-risk.service';
import logger from '../config/logger';

const router = Router();

// All routes require authentication
router.use(authenticate);

// GET /api/v1/tokens/:address/risk - Get token risk score
router.get(
  '/:address/risk',
  [
    param('address').isString().trim().notEmpty().withMessage('Token address required'),
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

      const score = await tokenRiskService.getTokenRiskScore(address);

      return res.json({
        success: true,
        data: score,
      });
    } catch (error: any) {
      logger.error('Get token risk score error:', error);
      return res.status(500).json({
        success: false,
        error: error.message || 'Failed to get token risk score',
      });
    }
  }
);

// POST /api/v1/tokens/:address/analyze - Analyze token with detailed assessment
router.post(
  '/:address/analyze',
  [
    param('address').isString().trim().notEmpty().withMessage('Token address required'),
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

      const analysis = await tokenRiskService.analyzeToken(address);

      return res.json({
        success: true,
        data: analysis,
      });
    } catch (error: any) {
      logger.error('Analyze token error:', error);
      return res.status(500).json({
        success: false,
        error: error.message || 'Failed to analyze token',
      });
    }
  }
);

// GET /api/v1/tokens/search - Search tokens by address pattern
router.get(
  '/search',
  [
    query('q').isString().trim().notEmpty().withMessage('Search query required'),
    query('limit').optional().isInt({ min: 1, max: 50 }).withMessage('Limit must be between 1 and 50'),
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

      const { q, limit = 10 } = req.query;

      const tokens = await tokenRiskService.searchTokens(
        q as string,
        parseInt(limit as string)
      );

      return res.json({
        success: true,
        data: tokens,
        count: tokens.length,
      });
    } catch (error: any) {
      logger.error('Search tokens error:', error);
      return res.status(500).json({
        success: false,
        error: error.message || 'Failed to search tokens',
      });
    }
  }
);

// GET /api/v1/tokens/risky - Get high-risk tokens
router.get(
  '/risky',
  [
    query('limit').optional().isInt({ min: 1, max: 100 }).withMessage('Limit must be between 1 and 100'),
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

      const { limit = 20 } = req.query;

      const tokens = await tokenRiskService.getHighRiskTokens(
        parseInt(limit as string)
      );

      return res.json({
        success: true,
        data: tokens,
        count: tokens.length,
        message: 'High-risk tokens (score > 70)',
      });
    } catch (error: any) {
      logger.error('Get high-risk tokens error:', error);
      return res.status(500).json({
        success: false,
        error: error.message || 'Failed to get high-risk tokens',
      });
    }
  }
);

// POST /api/v1/tokens/refresh - Refresh scores for tokens (admin/background job)
router.post(
  '/refresh',
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const { tokenAddresses } = req.body;

      if (!tokenAddresses || !Array.isArray(tokenAddresses)) {
        return res.status(400).json({
          success: false,
          error: 'tokenAddresses array required',
        });
      }

      if (tokenAddresses.length > 100) {
        return res.status(400).json({
          success: false,
          error: 'Maximum 100 tokens per refresh',
        });
      }

      // Start refresh in background
      tokenRiskService.refreshScores(tokenAddresses).catch(error => {
        logger.error('Background refresh error:', error);
      });

      return res.json({
        success: true,
        message: `Refreshing scores for ${tokenAddresses.length} tokens`,
      });
    } catch (error: any) {
      logger.error('Refresh tokens error:', error);
      return res.status(500).json({
        success: false,
        error: error.message || 'Failed to refresh tokens',
      });
    }
  }
);

export default router;
