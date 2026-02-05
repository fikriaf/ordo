/**
 * Token Swap Routes
 * Handles token swaps via Jupiter aggregator
 */

import { Router, Response } from 'express';
import { body, query, validationResult } from 'express-validator';
import { authenticate } from '../middleware/auth.middleware';
import { AuthenticatedRequest } from '../types';
import jupiterService from '../services/jupiter.service';
import tokenRiskService from '../services/token-risk.service';
import logger from '../config/logger';

const router = Router();

// All routes require authentication
router.use(authenticate);

// GET /api/v1/swap/quote - Get swap quote
router.get(
  '/quote',
  [
    query('inputMint').isString().trim().notEmpty().withMessage('Input token mint required'),
    query('outputMint').isString().trim().notEmpty().withMessage('Output token mint required'),
    query('amount').isFloat({ min: 0.000000001 }).withMessage('Valid amount required'),
    query('slippageBps').optional().isInt({ min: 1, max: 10000 }).withMessage('Valid slippage required'),
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

      const { inputMint, outputMint, amount, slippageBps } = req.query;

      const quote = await jupiterService.getSwapQuote({
        inputMint: inputMint as string,
        outputMint: outputMint as string,
        amount: parseFloat(amount as string),
        slippageBps: slippageBps ? parseInt(slippageBps as string) : undefined,
      });

      // Fetch risk score for output token
      let riskScore = undefined;
      let riskWarnings = [];
      try {
        const riskData = await tokenRiskService.getTokenRiskScore(outputMint as string);
        riskScore = riskData.risk_score;
        
        // Add warnings if high risk
        if (tokenRiskService.isHighRisk(riskScore)) {
          riskWarnings.push('⚠️ High-risk token detected');
          riskWarnings.push('Approval will be required for this swap');
          if (riskData.limiting_factors && riskData.limiting_factors.length > 0) {
            riskWarnings.push(...riskData.limiting_factors.map(f => `Risk factor: ${f}`));
          }
        }
      } catch (error: any) {
        logger.warn('Failed to fetch risk score for quote', {
          outputMint,
          error: error.message,
        });
      }

      return res.json({
        success: true,
        data: {
          ...quote,
          riskScore,
          riskWarnings: riskWarnings.length > 0 ? riskWarnings : undefined,
        },
      });
    } catch (error: any) {
      logger.error('Get swap quote error:', error);
      return res.status(500).json({
        success: false,
        error: error.message || 'Failed to get swap quote',
      });
    }
  }
);

// POST /api/v1/swap/execute - Execute swap
router.post(
  '/execute',
  [
    body('walletId').isUUID().withMessage('Valid wallet ID required'),
    body('quoteResponse').isObject().withMessage('Quote response required'),
    body('inputTokenPriceUsd').optional().isFloat({ min: 0 }).withMessage('Valid input token price required'),
    body('outputTokenPriceUsd').optional().isFloat({ min: 0 }).withMessage('Valid output token price required'),
    body('tokenRiskScore').optional().isInt({ min: 0, max: 100 }).withMessage('Valid risk score required'),
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

      const userId = req.user!.id;
      const { 
        walletId, 
        quoteResponse, 
        inputTokenPriceUsd = 1, 
        outputTokenPriceUsd = 1,
        tokenRiskScore 
      } = req.body;

      // Validate swap
      const inputAmount = parseInt(quoteResponse.inAmount) / Math.pow(10, 9);
      const validation = await jupiterService.validateSwap(
        walletId,
        quoteResponse.inputMint,
        inputAmount
      );

      if (!validation.valid) {
        return res.status(400).json({
          success: false,
          error: validation.error,
        });
      }

      // Auto-fetch risk score for output token if not provided
      let finalRiskScore = tokenRiskScore;
      if (finalRiskScore === undefined) {
        try {
          const outputMint = quoteResponse.outputMint;
          const riskData = await tokenRiskService.getTokenRiskScore(outputMint);
          finalRiskScore = riskData.risk_score;
          
          logger.info('Auto-fetched risk score for output token', {
            outputMint,
            riskScore: finalRiskScore,
          });
        } catch (error: any) {
          logger.warn('Failed to fetch risk score, proceeding without it', {
            error: error.message,
          });
          // Continue without risk score if fetch fails
        }
      }

      // Execute swap with approval check
      const result = await jupiterService.executeSwapWithApproval(
        userId,
        walletId,
        quoteResponse,
        inputTokenPriceUsd,
        outputTokenPriceUsd,
        finalRiskScore
      );

      // If approval required, return 202 Accepted
      if (result.approval_required) {
        return res.status(202).json({
          success: true,
          approval_required: true,
          approval_id: result.approval_id,
          message: result.message,
        });
      }

      // Otherwise return success
      return res.json({
        success: true,
        data: {
          signature: result.signature,
        },
        message: result.message,
      });
    } catch (error: any) {
      logger.error('Execute swap error:', error);
      return res.status(500).json({
        success: false,
        error: error.message || 'Failed to execute swap',
      });
    }
  }
);

// GET /api/v1/swap/tokens - Get supported tokens
router.get('/tokens', async (_req: AuthenticatedRequest, res: Response) => {
  try {
    const tokens = await jupiterService.getSupportedTokens();

    return res.json({
      success: true,
      data: tokens,
      count: tokens.length,
    });
  } catch (error: any) {
    logger.error('Get supported tokens error:', error);
    return res.status(500).json({
      success: false,
      error: error.message || 'Failed to get supported tokens',
    });
  }
});

// GET /api/v1/swap/price/:tokenMint - Get token price
router.get('/price/:tokenMint', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { tokenMint } = req.params;

    const price = await jupiterService.getTokenPrice(tokenMint);

    return res.json({
      success: true,
      data: {
        tokenMint,
        price,
        currency: 'USD',
      },
    });
  } catch (error: any) {
    logger.error('Get token price error:', error);
    return res.status(500).json({
      success: false,
      error: error.message || 'Failed to get token price',
    });
  }
});

// POST /api/v1/swap/validate - Validate swap before execution
router.post(
  '/validate',
  [
    body('walletId').isUUID().withMessage('Valid wallet ID required'),
    body('inputMint').isString().trim().notEmpty().withMessage('Input token mint required'),
    body('amount').isFloat({ min: 0.000000001 }).withMessage('Valid amount required'),
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

      const { walletId, inputMint, amount } = req.body;

      const validation = await jupiterService.validateSwap(
        walletId,
        inputMint,
        amount
      );

      return res.json({
        success: true,
        data: validation,
      });
    } catch (error: any) {
      logger.error('Validate swap error:', error);
      return res.status(500).json({
        success: false,
        error: error.message || 'Failed to validate swap',
      });
    }
  }
);

export default router;
