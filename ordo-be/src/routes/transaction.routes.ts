import { Router, Response } from 'express';
import { z } from 'zod';
import { authenticate } from '../middleware/auth.middleware';
import { AuthenticatedRequest } from '../types';
import transactionService from '../services/transaction.service';
import logger from '../config/logger';

const router = Router();

// All transaction routes require authentication
router.use(authenticate);

// Validation schemas
const transactionFiltersSchema = z.object({
  type: z.string().optional(),
  status: z.enum(['pending', 'confirmed', 'failed']).optional(),
  startDate: z.string().optional(),
  endDate: z.string().optional(),
  page: z.string().transform(Number).optional(),
  limit: z.string().transform(Number).optional(),
});

// GET /api/v1/transactions - Get transaction history with filters and pagination
router.get('/', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    if (!req.user) {
      res.status(401).json({
        success: false,
        error: 'Authentication required',
      });
      return;
    }

    const validatedQuery = transactionFiltersSchema.parse(req.query);

    const filters = {
      type: validatedQuery.type,
      status: validatedQuery.status,
      startDate: validatedQuery.startDate,
      endDate: validatedQuery.endDate,
    };

    const pagination = {
      page: validatedQuery.page || 1,
      limit: validatedQuery.limit || 20,
    };

    const result = await transactionService.getUserTransactions(
      req.user.id,
      filters,
      pagination
    );

    res.status(200).json({
      success: true,
      data: {
        transactions: result.transactions,
        pagination: {
          page: pagination.page,
          limit: pagination.limit,
          total: result.total,
          totalPages: Math.ceil(result.total / pagination.limit),
        },
      },
    });
  } catch (error: any) {
    if (error instanceof z.ZodError) {
      res.status(400).json({
        success: false,
        error: 'Validation error',
        details: error.errors,
      });
      return;
    }

    logger.error('Get transactions error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to get transactions',
    });
  }
});

// GET /api/v1/transactions/:id - Get transaction details
router.get('/:id', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    if (!req.user) {
      res.status(401).json({
        success: false,
        error: 'Authentication required',
      });
      return;
    }

    const { id } = req.params;
    const transaction = await transactionService.getTransaction(id);

    if (!transaction) {
      res.status(404).json({
        success: false,
        error: 'Transaction not found',
      });
      return;
    }

    // Verify transaction belongs to user
    if (transaction.user_id !== req.user.id) {
      res.status(403).json({
        success: false,
        error: 'Access denied',
      });
      return;
    }

    res.status(200).json({
      success: true,
      data: transaction,
    });
  } catch (error: any) {
    logger.error('Get transaction error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to get transaction',
    });
  }
});

export default router;
