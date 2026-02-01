import { Router, Response } from 'express';
import { authenticate } from '../middleware/auth.middleware';
import { AuthenticatedRequest } from '../types';
import pluginManager from '../services/plugin-manager.service';
import transactionService from '../services/transaction.service';
import logger from '../config/logger';

const router = Router();

// All action routes require authentication
router.use(authenticate);

// GET /api/v1/actions - List available actions
router.get('/', async (_req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const actions = pluginManager.getAvailableActions();

    const actionList = actions.map(action => ({
      name: action.name,
      description: action.description,
      parameters: action.parameters.map(p => ({
        name: p.name,
        type: p.type,
        description: p.description,
        required: p.required,
        default: p.default,
      })),
      examples: action.examples,
    }));

    res.status(200).json({
      success: true,
      data: {
        actions: actionList,
        total: actionList.length,
      },
    });
  } catch (error: any) {
    logger.error('List actions error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to list actions',
    });
  }
});

// POST /api/v1/actions/:actionName - Execute action directly
router.post('/:actionName', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    if (!req.user) {
      res.status(401).json({
        success: false,
        error: 'Authentication required',
      });
      return;
    }

    const { actionName } = req.params;
    const params = req.body;
    const { walletId } = params;

    // Remove walletId from params as it's part of context
    delete params.walletId;

    const context = {
      userId: req.user.id,
      walletId,
    };

    logger.info(`Executing action: ${actionName}`, { userId: req.user.id, params });

    const result = await pluginManager.executeAction(actionName, params, context);

    // Record transaction if signature is returned
    if (result.signature && walletId) {
      await transactionService.recordTransaction(
        req.user.id,
        walletId,
        actionName,
        result.signature,
        { params, result }
      );
    }

    res.status(200).json({
      success: true,
      data: result,
    });
  } catch (error: any) {
    logger.error('Execute action error:', error);
    res.status(400).json({
      success: false,
      error: error.message || 'Action execution failed',
    });
  }
});

export default router;
