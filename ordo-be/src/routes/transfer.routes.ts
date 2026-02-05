/**
 * Token Transfer Routes
 * Handles SOL and SPL token transfers
 */

import { Router, Response } from 'express';
import { body, validationResult } from 'express-validator';
import { authenticate } from '../middleware/auth.middleware';
import { AuthenticatedRequest } from '../types';
import tokenTransferService from '../services/token-transfer.service';
import logger from '../config/logger';

const router = Router();

// All routes require authentication
router.use(authenticate);

// POST /api/v1/transfer/sol - Transfer SOL
router.post(
  '/sol',
  [
    body('walletId').isUUID().withMessage('Valid wallet ID required'),
    body('toAddress').isString().trim().notEmpty().withMessage('Recipient address required'),
    body('amount').isFloat({ min: 0.000000001 }).withMessage('Valid amount required'),
    body('solPriceUsd').optional().isFloat({ min: 0 }).withMessage('Valid SOL price required'),
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
      const { walletId, toAddress, amount, solPriceUsd } = req.body;

      // Validate transfer
      const validation = await tokenTransferService.validateTransfer(
        walletId,
        userId,
        amount
      );

      if (!validation.valid) {
        return res.status(400).json({
          success: false,
          error: validation.error,
        });
      }

      // Execute transfer with approval check
      const result = await tokenTransferService.transferSOLWithApproval(
        userId,
        walletId,
        toAddress,
        amount,
        solPriceUsd
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

      // Transfer executed successfully
      return res.json({
        success: true,
        data: {
          signature: result.signature,
          amount: result.amount,
        },
        message: result.message,
      });
    } catch (error: any) {
      logger.error('Transfer SOL error:', error);
      return res.status(500).json({
        success: false,
        error: error.message || 'Failed to transfer SOL',
      });
    }
  }
);

// POST /api/v1/transfer/token - Transfer SPL token
router.post(
  '/token',
  [
    body('walletId').isUUID().withMessage('Valid wallet ID required'),
    body('toAddress').isString().trim().notEmpty().withMessage('Recipient address required'),
    body('tokenMint').isString().trim().notEmpty().withMessage('Token mint address required'),
    body('amount').isFloat({ min: 0.000000001 }).withMessage('Valid amount required'),
    body('decimals').optional().isInt({ min: 0, max: 18 }).withMessage('Valid decimals required'),
    body('tokenPriceUsd').optional().isFloat({ min: 0 }).withMessage('Valid token price required'),
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
      const { walletId, toAddress, tokenMint, amount, decimals = 9, tokenPriceUsd, tokenRiskScore } = req.body;

      // Validate transfer
      const validation = await tokenTransferService.validateTransfer(
        walletId,
        userId,
        amount,
        tokenMint
      );

      if (!validation.valid) {
        return res.status(400).json({
          success: false,
          error: validation.error,
        });
      }

      // Execute transfer with approval check
      const result = await tokenTransferService.transferTokenWithApproval(
        userId,
        walletId,
        toAddress,
        tokenMint,
        amount,
        decimals,
        tokenPriceUsd,
        tokenRiskScore
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

      // Transfer executed successfully
      return res.json({
        success: true,
        data: {
          signature: result.signature,
          amount: result.amount,
        },
        message: result.message,
      });
    } catch (error: any) {
      logger.error('Transfer token error:', error);
      return res.status(500).json({
        success: false,
        error: error.message || 'Failed to transfer token',
      });
    }
  }
);

// GET /api/v1/transfer/fee - Estimate transfer fee
router.get('/fee', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { tokenMint } = req.query;

    const fee = await tokenTransferService.estimateTransferFee(
      tokenMint as string | undefined
    );

    return res.json({
      success: true,
      data: fee,
    });
  } catch (error: any) {
    logger.error('Estimate fee error:', error);
    return res.status(500).json({
      success: false,
      error: error.message || 'Failed to estimate fee',
    });
  }
});

// POST /api/v1/transfer/validate - Validate transfer before execution
router.post(
  '/validate',
  [
    body('walletId').isUUID().withMessage('Valid wallet ID required'),
    body('amount').isFloat({ min: 0.000000001 }).withMessage('Valid amount required'),
    body('tokenMint').optional().isString().trim(),
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
      const { walletId, amount, tokenMint } = req.body;

      const validation = await tokenTransferService.validateTransfer(
        walletId,
        userId,
        amount,
        tokenMint
      );

      return res.json({
        success: true,
        data: validation,
      });
    } catch (error: any) {
      logger.error('Validate transfer error:', error);
      return res.status(500).json({
        success: false,
        error: error.message || 'Failed to validate transfer',
      });
    }
  }
);

export default router;
