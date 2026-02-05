import { Router, Response } from 'express';
import { body, param, query, validationResult } from 'express-validator';
import { authenticate } from '../middleware/auth.middleware';
import { AuthenticatedRequest } from '../types';
import approvalService from '../services/approval.service';
import logger from '../config/logger';

const router = Router();

// All routes require authentication
router.use(authenticate);

// GET /api/v1/approvals/pending - Get pending approvals
router.get('/pending', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.id;
    const approvals = await approvalService.getPendingApprovals(userId);

    res.json({
      success: true,
      data: approvals,
      count: approvals.length,
    });
  } catch (error: any) {
    logger.error('Get pending approvals error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to get pending approvals',
    });
  }
});

// GET /api/v1/approvals/history - Get approval history (MUST BE BEFORE /:id)
router.get(
  '/history',
  [
    query('status').optional().isIn(['pending', 'approved', 'rejected', 'expired']),
    query('request_type').optional().isIn(['transaction', 'setting_change', 'large_transfer', 'high_risk_token']),
    query('start_date').optional().isISO8601(),
    query('end_date').optional().isISO8601(),
    query('page').optional().isInt({ min: 1 }),
    query('limit').optional().isInt({ min: 1, max: 100 }),
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
      const { status, request_type, start_date, end_date, page, limit } = req.query;

      const result = await approvalService.getApprovalHistory(
        userId,
        {
          status: status as any,
          requestType: request_type as any,
          startDate: start_date as string,
          endDate: end_date as string,
        },
        {
          page: page ? parseInt(page as string) : undefined,
          limit: limit ? parseInt(limit as string) : undefined,
        }
      );

      return res.json({
        success: true,
        data: result.approvals,
        pagination: {
          total: result.total,
          page: page ? parseInt(page as string) : 1,
          limit: limit ? parseInt(limit as string) : 20,
        },
      });
    } catch (error: any) {
      logger.error('Get approval history error:', error);
      return res.status(500).json({
        success: false,
        error: error.message || 'Failed to get approval history',
      });
    }
  }
);

// GET /api/v1/approvals/:id - Get specific approval request
router.get(
  '/:id',
  [param('id').isUUID()],
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

      const approval = await approvalService.getApprovalRequest(id);
      if (!approval) {
        return res.status(404).json({
          success: false,
          error: 'Approval request not found',
        });
      }

      // Verify ownership
      if (approval.user_id !== userId) {
        return res.status(403).json({
          success: false,
          error: 'Unauthorized',
        });
      }

      return res.json({
        success: true,
        data: approval,
      });
    } catch (error: any) {
      logger.error('Get approval request error:', error);
      return res.status(500).json({
        success: false,
        error: error.message || 'Failed to get approval request',
      });
    }
  }
);

// POST /api/v1/approvals/:id/approve - Approve request
router.post(
  '/:id/approve',
  [param('id').isUUID()],
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

      const approval = await approvalService.approveRequest(id, userId);

      return res.json({
        success: true,
        data: approval,
        message: 'Request approved successfully',
      });
    } catch (error: any) {
      logger.error('Approve request error:', error);
      const statusCode = error.message === 'Unauthorized' ? 403 : 
                         error.message === 'Approval request not found' ? 404 : 500;
      return res.status(statusCode).json({
        success: false,
        error: error.message || 'Failed to approve request',
      });
    }
  }
);

// POST /api/v1/approvals/:id/reject - Reject request
router.post(
  '/:id/reject',
  [
    param('id').isUUID(),
    body('reason').optional().isString().trim(),
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
      const { reason } = req.body;
      const userId = req.user!.id;

      const approval = await approvalService.rejectRequest(id, userId, reason);

      return res.json({
        success: true,
        data: approval,
        message: 'Request rejected successfully',
      });
    } catch (error: any) {
      logger.error('Reject request error:', error);
      const statusCode = error.message === 'Unauthorized' ? 403 : 
                         error.message === 'Approval request not found' ? 404 : 500;
      return res.status(statusCode).json({
        success: false,
        error: error.message || 'Failed to reject request',
      });
    }
  }
);

export default router;
