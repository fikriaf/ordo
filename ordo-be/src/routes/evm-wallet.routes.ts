import { Router, Response } from 'express';
import evmWalletService, { EVMChainId } from '../services/evm-wallet.service';
import { authenticate } from '../middleware/auth.middleware';
import { AuthenticatedRequest } from '../types';
import logger from '../config/logger';

const router = Router();

// All routes require authentication
router.use(authenticate);

/**
 * Create new EVM wallet
 * POST /api/v1/wallet/evm/create
 */
router.post('/create', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    if (!req.user) {
      res.status(401).json({
        success: false,
        error: 'Authentication required'
      });
      return;
    }

    const { chainId } = req.body;
    const userId = req.user.id;

    // Validate chain ID
    if (!Object.values(EVMChainId).includes(chainId)) {
      res.status(400).json({
        success: false,
        error: 'Invalid chain ID. Must be one of: ethereum, polygon, bsc, arbitrum, optimism, avalanche'
      });
      return;
    }

    const wallet = await evmWalletService.createWallet(userId, chainId as EVMChainId);

    // Don't expose encrypted private key in response
    const { encryptedPrivateKey, encryptionIv, encryptionAuthTag, ...safeWallet } = wallet;

    res.status(201).json({
      success: true,
      data: safeWallet
    });
  } catch (error: any) {
    logger.error('Error in create EVM wallet route', { error });
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to create EVM wallet'
    });
  }
});

/**
 * Import existing EVM wallet
 * POST /api/v1/wallet/evm/import
 */
router.post('/import', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    if (!req.user) {
      res.status(401).json({
        success: false,
        error: 'Authentication required'
      });
      return;
    }

    const { chainId, privateKey } = req.body;
    const userId = req.user.id;

    // Validate inputs
    if (!chainId || !privateKey) {
      res.status(400).json({
        success: false,
        error: 'Chain ID and private key are required'
      });
      return;
    }

    if (!Object.values(EVMChainId).includes(chainId)) {
      res.status(400).json({
        success: false,
        error: 'Invalid chain ID'
      });
      return;
    }

    const wallet = await evmWalletService.importWallet(userId, chainId as EVMChainId, privateKey);

    // Don't expose encrypted private key in response
    const { encryptedPrivateKey, encryptionIv, encryptionAuthTag, ...safeWallet } = wallet;

    res.status(201).json({
      success: true,
      data: safeWallet
    });
  } catch (error: any) {
    logger.error('Error in import EVM wallet route', { error });
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to import EVM wallet'
    });
  }
});

/**
 * Get EVM wallet balance
 * GET /api/v1/wallet/evm/:id/balance
 */
router.get('/:id/balance', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    if (!req.user) {
      res.status(401).json({
        success: false,
        error: 'Authentication required'
      });
      return;
    }

    const { id } = req.params;
    const userId = req.user.id;

    // Verify wallet belongs to user
    const wallet = await evmWalletService.getWallet(id);
    if (!wallet) {
      res.status(404).json({
        success: false,
        error: 'Wallet not found'
      });
      return;
    }

    if (wallet.userId !== userId) {
      res.status(403).json({
        success: false,
        error: 'Unauthorized access to wallet'
      });
      return;
    }

    const balance = await evmWalletService.getWalletBalance(id);

    res.json({
      success: true,
      data: balance
    });
  } catch (error: any) {
    logger.error('Error in get EVM wallet balance route', { error });
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to get wallet balance'
    });
  }
});

/**
 * List user's EVM wallets
 * GET /api/v1/wallets/evm
 */
router.get('/', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    if (!req.user) {
      res.status(401).json({
        success: false,
        error: 'Authentication required'
      });
      return;
    }

    const userId = req.user.id;
    const { chainId } = req.query;

    // Validate chain ID if provided
    if (chainId && !Object.values(EVMChainId).includes(chainId as EVMChainId)) {
      res.status(400).json({
        success: false,
        error: 'Invalid chain ID'
      });
      return;
    }

    const wallets = await evmWalletService.getUserWallets(
      userId, 
      chainId as EVMChainId | undefined
    );

    // Don't expose encrypted private keys in response
    const safeWallets = wallets.map(w => {
      const { encryptedPrivateKey, encryptionIv, encryptionAuthTag, ...safe } = w;
      return safe;
    });

    res.json({
      success: true,
      data: safeWallets
    });
  } catch (error: any) {
    logger.error('Error in list EVM wallets route', { error });
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to list EVM wallets'
    });
  }
});

/**
 * Transfer native token (ETH, MATIC, BNB, etc.)
 * POST /api/v1/wallet/evm/transfer/native
 */
router.post('/transfer/native', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    if (!req.user) {
      res.status(401).json({
        success: false,
        error: 'Authentication required'
      });
      return;
    }

    const { walletId, toAddress, amount } = req.body;
    const userId = req.user.id;

    // Validate inputs
    if (!walletId || !toAddress || !amount) {
      res.status(400).json({
        success: false,
        error: 'Wallet ID, recipient address, and amount are required'
      });
      return;
    }

    // Verify wallet belongs to user
    const wallet = await evmWalletService.getWallet(walletId);
    if (!wallet) {
      res.status(404).json({
        success: false,
        error: 'Wallet not found'
      });
      return;
    }

    if (wallet.userId !== userId) {
      res.status(403).json({
        success: false,
        error: 'Unauthorized access to wallet'
      });
      return;
    }

    // TODO: Check approval threshold from user preferences
    // For now, execute directly

    const txHash = await evmWalletService.transferNative(walletId, toAddress, amount);

    res.json({
      success: true,
      data: {
        txHash,
        amount
      },
      message: 'Native token transferred successfully'
    });
  } catch (error: any) {
    logger.error('Error in transfer native token route', { error });
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to transfer native token'
    });
  }
});

/**
 * Transfer ERC-20 token
 * POST /api/v1/wallet/evm/transfer/token
 */
router.post('/transfer/token', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    if (!req.user) {
      res.status(401).json({
        success: false,
        error: 'Authentication required'
      });
      return;
    }

    const { walletId, toAddress, tokenAddress, amount } = req.body;
    const userId = req.user.id;

    // Validate inputs
    if (!walletId || !toAddress || !tokenAddress || !amount) {
      res.status(400).json({
        success: false,
        error: 'Wallet ID, recipient address, token address, and amount are required'
      });
      return;
    }

    // Verify wallet belongs to user
    const wallet = await evmWalletService.getWallet(walletId);
    if (!wallet) {
      res.status(404).json({
        success: false,
        error: 'Wallet not found'
      });
      return;
    }

    if (wallet.userId !== userId) {
      res.status(403).json({
        success: false,
        error: 'Unauthorized access to wallet'
      });
      return;
    }

    // TODO: Check approval threshold from user preferences

    const txHash = await evmWalletService.transferToken(walletId, toAddress, tokenAddress, amount);

    res.json({
      success: true,
      data: {
        txHash,
        amount
      },
      message: 'Token transferred successfully'
    });
  } catch (error: any) {
    logger.error('Error in transfer token route', { error });
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to transfer token'
    });
  }
});

/**
 * Estimate gas fee
 * GET /api/v1/wallet/evm/gas-estimate
 */
router.get('/gas-estimate', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { chainId, type, tokenAddress } = req.query;

    // Validate inputs
    if (!chainId || !type) {
      res.status(400).json({
        success: false,
        error: 'Chain ID and transaction type are required'
      });
      return;
    }

    if (!Object.values(EVMChainId).includes(chainId as EVMChainId)) {
      res.status(400).json({
        success: false,
        error: 'Invalid chain ID'
      });
      return;
    }

    if (type !== 'native' && type !== 'token') {
      res.status(400).json({
        success: false,
        error: 'Transaction type must be "native" or "token"'
      });
      return;
    }

    const estimate = await evmWalletService.estimateGas(
      chainId as EVMChainId,
      type as 'native' | 'token',
      tokenAddress as string | undefined
    );

    res.json({
      success: true,
      data: estimate
    });
  } catch (error: any) {
    logger.error('Error in estimate gas route', { error });
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to estimate gas'
    });
  }
});

export default router;
