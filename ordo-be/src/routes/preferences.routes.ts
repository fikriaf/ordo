import { Router, Response } from 'express';
import { body, validationResult } from 'express-validator';
import { authenticate } from '../middleware/auth.middleware';
import { AuthenticatedRequest } from '../types';
import userPreferencesService from '../services/user-preferences.service';
import logger from '../config/logger';

const router = Router();

// All routes require authentication
router.use(authenticate);

// GET /api/v1/preferences - Get user preferences
router.get('/', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.id;
    const preferences = await userPreferencesService.getUserPreferences(userId);

    res.json({
      success: true,
      data: preferences,
    });
  } catch (error: any) {
    logger.error('Get preferences error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to get preferences',
    });
  }
});

// PUT /api/v1/preferences - Update user preferences
router.put(
  '/',
  [
    body('max_single_transfer_sol').optional().isFloat({ min: 0, max: 1000 }),
    body('max_daily_volume_usdc').optional().isFloat({ min: 0, max: 1000000 }),
    body('agent_autonomy_level').optional().isIn(['low', 'medium', 'high']),
    body('require_approval_above_usdc').optional().isFloat({ min: 0 }),
    body('default_slippage_bps').optional().isInt({ min: 1, max: 10000 }),
    body('enable_auto_staking').optional().isBoolean(),
    body('enable_auto_compounding').optional().isBoolean(),
    body('min_token_risk_score').optional().isInt({ min: 0, max: 100 }),
    body('block_high_risk_tokens').optional().isBoolean(),
    body('notify_on_approval_needed').optional().isBoolean(),
    body('notify_on_transaction_complete').optional().isBoolean(),
    body('notify_on_price_alerts').optional().isBoolean(),
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
      const updates = req.body;

      const preferences = await userPreferencesService.updatePreferences(userId, updates);

      return res.json({
        success: true,
        data: preferences,
        message: 'Preferences updated successfully',
      });
    } catch (error: any) {
      logger.error('Update preferences error:', error);
      return res.status(500).json({
        success: false,
        error: error.message || 'Failed to update preferences',
      });
    }
  }
);

// POST /api/v1/preferences/reset - Reset to defaults
router.post('/reset', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.id;
    const preferences = await userPreferencesService.resetToDefaults(userId);

    res.json({
      success: true,
      data: preferences,
      message: 'Preferences reset to defaults',
    });
  } catch (error: any) {
    logger.error('Reset preferences error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to reset preferences',
    });
  }
});

export default router;
