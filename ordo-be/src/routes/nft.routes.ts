/**
 * NFT Routes
 * NFT operations: mint, transfer, burn, collections
 */

import { Router, Response } from 'express';
import { body, param, query, validationResult } from 'express-validator';
import { authenticate } from '../middleware/auth.middleware';
import { AuthenticatedRequest } from '../types';
import nftService from '../services/nft.service';
import logger from '../config/logger';

const router = Router();

// All routes require authentication
router.use(authenticate);

// POST /api/v1/nft/mint - Mint NFT
router.post(
  '/mint',
  [
    body('walletId').isUUID().withMessage('Valid wallet ID required'),
    body('name').isString().trim().notEmpty().withMessage('NFT name required'),
    body('symbol').isString().trim().notEmpty().withMessage('NFT symbol required'),
    body('uri').isURL().withMessage('Valid metadata URI required'),
    body('sellerFeeBasisPoints').optional().isInt({ min: 0, max: 10000 }).withMessage('Seller fee must be 0-10000 basis points'),
    body('creators').optional().isArray().withMessage('Creators must be an array'),
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

      const { walletId, name, symbol, uri, sellerFeeBasisPoints, creators } = req.body;
      const userId = req.user!.id;

      const result = await nftService.mintNFT(userId, walletId, {
        name,
        symbol,
        uri,
        sellerFeeBasisPoints,
        creators,
      });

      return res.json({
        success: true,
        data: result,
        message: 'NFT minted successfully',
      });
    } catch (error: any) {
      logger.error('Mint NFT error:', error);
      return res.status(500).json({
        success: false,
        error: error.message || 'Failed to mint NFT',
      });
    }
  }
);

// POST /api/v1/nft/transfer - Transfer NFT
router.post(
  '/transfer',
  [
    body('walletId').isUUID().withMessage('Valid wallet ID required'),
    body('mintAddress').isString().trim().notEmpty().withMessage('Mint address required'),
    body('toAddress').isString().trim().notEmpty().withMessage('Recipient address required'),
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

      const { walletId, mintAddress, toAddress } = req.body;
      const userId = req.user!.id;

      const result = await nftService.transferNFT(userId, walletId, {
        mintAddress,
        toAddress,
      });

      return res.json({
        success: true,
        data: result,
        message: 'NFT transferred successfully',
      });
    } catch (error: any) {
      logger.error('Transfer NFT error:', error);
      return res.status(500).json({
        success: false,
        error: error.message || 'Failed to transfer NFT',
      });
    }
  }
);

// POST /api/v1/nft/burn - Burn NFT
router.post(
  '/burn',
  [
    body('walletId').isUUID().withMessage('Valid wallet ID required'),
    body('mintAddress').isString().trim().notEmpty().withMessage('Mint address required'),
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

      const { walletId, mintAddress } = req.body;
      const userId = req.user!.id;

      const result = await nftService.burnNFT(userId, walletId, mintAddress);

      return res.json({
        success: true,
        data: result,
        message: 'NFT burned successfully',
      });
    } catch (error: any) {
      logger.error('Burn NFT error:', error);
      return res.status(500).json({
        success: false,
        error: error.message || 'Failed to burn NFT',
      });
    }
  }
);

// GET /api/v1/nft/user - Get user's NFTs
router.get(
  '/user',
  [
    query('limit').optional().isInt({ min: 1, max: 1000 }).withMessage('Limit must be between 1-1000'),
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
      const limit = req.query.limit ? parseInt(req.query.limit as string) : 100;

      const nfts = await nftService.getUserNFTs(userId, limit);

      return res.json({
        success: true,
        data: nfts,
        count: nfts.length,
      });
    } catch (error: any) {
      logger.error('Get user NFTs error:', error);
      return res.status(500).json({
        success: false,
        error: error.message || 'Failed to get user NFTs',
      });
    }
  }
);

// GET /api/v1/nft/wallet/:address - Get NFTs by wallet address
router.get(
  '/wallet/:address',
  [
    param('address').isString().trim().notEmpty().withMessage('Valid wallet address required'),
    query('limit').optional().isInt({ min: 1, max: 1000 }).withMessage('Limit must be between 1-1000'),
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
      const limit = req.query.limit ? parseInt(req.query.limit as string) : 100;

      const nfts = await nftService.getNFTsByWallet(address, limit);

      return res.json({
        success: true,
        data: nfts,
        count: nfts.length,
      });
    } catch (error: any) {
      logger.error('Get NFTs by wallet error:', error);
      return res.status(500).json({
        success: false,
        error: error.message || 'Failed to get NFTs by wallet',
      });
    }
  }
);

// GET /api/v1/nft/metadata/:mintAddress - Get NFT metadata
router.get(
  '/metadata/:mintAddress',
  [
    param('mintAddress').isString().trim().notEmpty().withMessage('Valid mint address required'),
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

      const { mintAddress } = req.params;

      const metadata = await nftService.getNFTMetadata(mintAddress);

      return res.json({
        success: true,
        data: metadata,
      });
    } catch (error: any) {
      logger.error('Get NFT metadata error:', error);
      return res.status(500).json({
        success: false,
        error: error.message || 'Failed to get NFT metadata',
      });
    }
  }
);

// GET /api/v1/nft/collection/:address - Get collection info
router.get(
  '/collection/:address',
  [
    param('address').isString().trim().notEmpty().withMessage('Valid collection address required'),
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

      const collection = await nftService.getCollectionInfo(address);

      if (!collection) {
        return res.status(404).json({
          success: false,
          error: 'Collection not found',
        });
      }

      return res.json({
        success: true,
        data: collection,
      });
    } catch (error: any) {
      logger.error('Get collection info error:', error);
      return res.status(500).json({
        success: false,
        error: error.message || 'Failed to get collection info',
      });
    }
  }
);

// GET /api/v1/nft/portfolio/value - Get NFT portfolio value
router.get(
  '/portfolio/value',
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const userId = req.user!.id;

      const portfolio = await nftService.getPortfolioValue(userId);

      return res.json({
        success: true,
        data: portfolio,
      });
    } catch (error: any) {
      logger.error('Get portfolio value error:', error);
      return res.status(500).json({
        success: false,
        error: error.message || 'Failed to get portfolio value',
      });
    }
  }
);

export default router;
