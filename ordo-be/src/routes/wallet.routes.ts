import { Router, Response } from 'express';
import { z } from 'zod';
import walletService from '../services/wallet.service';
import authService from '../services/auth.service';
import { authenticate } from '../middleware/auth.middleware';
import { AuthenticatedRequest } from '../types';
import logger from '../config/logger';

const router = Router();

// All wallet routes require authentication
router.use(authenticate);

// Validation schemas
const importWalletSchema = z.object({
  privateKey: z.string().min(1, 'Private key is required'),
});

const getPrivateKeySchema = z.object({
  password: z.string().min(1, 'Password is required'),
});

// POST /api/v1/wallet/create
router.post('/create', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    if (!req.user) {
      res.status(401).json({
        success: false,
        error: 'Authentication required',
      });
      return;
    }

    const wallet = await walletService.createWallet(req.user.id);

    res.status(201).json({
      success: true,
      data: {
        id: wallet.id,
        publicKey: wallet.public_key,
        isPrimary: wallet.is_primary,
        createdAt: wallet.created_at,
      },
    });
  } catch (error: any) {
    logger.error('Create wallet route error:', error);
    res.status(400).json({
      success: false,
      error: error.message || 'Wallet creation failed',
    });
  }
});

// POST /api/v1/wallet/import
router.post('/import', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    if (!req.user) {
      res.status(401).json({
        success: false,
        error: 'Authentication required',
      });
      return;
    }

    const validatedData = importWalletSchema.parse(req.body);
    const wallet = await walletService.importWallet(req.user.id, validatedData.privateKey);

    res.status(201).json({
      success: true,
      data: {
        id: wallet.id,
        publicKey: wallet.public_key,
        isPrimary: wallet.is_primary,
        createdAt: wallet.created_at,
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

    logger.error('Import wallet route error:', error);
    res.status(400).json({
      success: false,
      error: error.message || 'Wallet import failed',
    });
  }
});

// GET /api/v1/wallet/:id/balance
router.get('/:id/balance', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    if (!req.user) {
      res.status(401).json({
        success: false,
        error: 'Authentication required',
      });
      return;
    }

    const walletId = req.params.id;
    const balance = await walletService.getWalletBalance(walletId);

    res.status(200).json({
      success: true,
      data: balance,
    });
  } catch (error: any) {
    logger.error('Get balance route error:', error);
    res.status(400).json({
      success: false,
      error: error.message || 'Failed to get balance',
    });
  }
});

// GET /api/v1/wallets
router.get('/', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    if (!req.user) {
      res.status(401).json({
        success: false,
        error: 'Authentication required',
      });
      return;
    }

    const wallets = await walletService.getUserWallets(req.user.id);

    res.status(200).json({
      success: true,
      data: wallets.map((wallet) => ({
        id: wallet.id,
        publicKey: wallet.public_key,
        isPrimary: wallet.is_primary,
        createdAt: wallet.created_at,
      })),
    });
  } catch (error: any) {
    logger.error('Get wallets route error:', error);
    res.status(400).json({
      success: false,
      error: error.message || 'Failed to get wallets',
    });
  }
});

// GET /api/v1/wallet/portfolio - Get portfolio summary with real-time update
router.get('/portfolio', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    if (!req.user) {
      res.status(401).json({
        success: false,
        error: 'Authentication required',
      });
      return;
    }

    const portfolio = await walletService.getPortfolioSummary(req.user.id);

    res.status(200).json({
      success: true,
      data: portfolio,
      message: 'Portfolio summary retrieved and real-time update sent',
    });
  } catch (error: any) {
    logger.error('Get portfolio route error:', error);
    res.status(400).json({
      success: false,
      error: error.message || 'Failed to get portfolio',
    });
  }
});

// DELETE /api/v1/wallet/:id - Delete a wallet
router.delete('/:id', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    if (!req.user) {
      res.status(401).json({
        success: false,
        error: 'Authentication required',
      });
      return;
    }

    const walletId = req.params.id;
    await walletService.deleteWallet(req.user.id, walletId);

    // Get remaining wallets to return
    const remainingWallets = await walletService.getUserWallets(req.user.id);

    res.status(200).json({
      success: true,
      message: 'Wallet deleted successfully',
      data: {
        deletedWalletId: walletId,
        remainingWallets: remainingWallets.map((wallet) => ({
          id: wallet.id,
          publicKey: wallet.public_key,
          isPrimary: wallet.is_primary,
          createdAt: wallet.created_at,
        })),
      },
    });
  } catch (error: any) {
    logger.error('Delete wallet route error:', error);
    res.status(400).json({
      success: false,
      error: error.message || 'Failed to delete wallet',
    });
  }
});

// PUT /api/v1/wallets/:id/primary - Set wallet as primary
router.put('/:id/primary', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    if (!req.user) {
      res.status(401).json({
        success: false,
        error: 'Authentication required',
      });
      return;
    }

    const walletId = req.params.id;
    await walletService.setPrimaryWallet(req.user.id, walletId);

    // Get updated wallets to return
    const wallets = await walletService.getUserWallets(req.user.id);

    res.status(200).json({
      success: true,
      message: 'Primary wallet updated successfully',
      data: wallets.map((wallet) => ({
        id: wallet.id,
        publicKey: wallet.public_key,
        isPrimary: wallet.is_primary,
        createdAt: wallet.created_at,
      })),
    });
  } catch (error: any) {
    logger.error('Set primary wallet route error:', error);
    res.status(400).json({
      success: false,
      error: error.message || 'Failed to set primary wallet',
    });
  }
});

// POST /api/v1/wallets/:id/private-key - Get private key with password verification
router.post('/:id/private-key', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    if (!req.user) {
      res.status(401).json({
        success: false,
        error: 'Authentication required',
      });
      return;
    }

    // Validate password input
    const validatedData = getPrivateKeySchema.parse(req.body);
    
    // Verify user password
    const isValidPassword = await authService.verifyPassword(req.user.id, validatedData.password);
    if (!isValidPassword) {
      res.status(401).json({
        success: false,
        error: 'Invalid password',
      });
      return;
    }

    const walletId = req.params.id;
    const privateKey = await walletService.getPrivateKey(req.user.id, walletId);

    res.status(200).json({
      success: true,
      data: {
        privateKey,
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

    logger.error('Get private key route error:', error);
    res.status(400).json({
      success: false,
      error: error.message || 'Failed to get private key',
    });
  }
});

export default router;
