/**
 * Solana Wallet Plugin
 * Provides AI access to Solana wallet operations
 */

import { Plugin, Action } from '../types/plugin';
import walletService from './wallet.service';
import logger from '../config/logger';

// =============================================
// SOLANA WALLET ACTIONS
// =============================================

const createSolanaWalletAction: Action = {
  name: 'create_solana_wallet',
  description: 'Create a new Solana wallet for the user',
  parameters: [],
  examples: [
    {
      description: 'Create a new Solana wallet',
      input: {},
      output: {
        success: true,
        wallet: {
          id: 'uuid',
          publicKey: 'ABC123...xyz',
          isPrimary: true,
        },
        message: 'Solana wallet created successfully',
      },
    },
  ],
  handler: async (_params, context) => {
    try {
      const wallet = await walletService.createWallet(context.userId);

      return {
        success: true,
        wallet: {
          id: wallet.id,
          publicKey: wallet.public_key,
          isPrimary: wallet.is_primary,
          createdAt: wallet.created_at,
        },
        chain: 'solana',
        message: 'Solana wallet created successfully',
      };
    } catch (error: any) {
      logger.error('Create Solana wallet action error:', error);
      throw new Error(`Failed to create Solana wallet: ${error.message}`);
    }
  },
};

const importSolanaWalletAction: Action = {
  name: 'import_solana_wallet',
  description: 'Import an existing Solana wallet using a private key',
  parameters: [
    {
      name: 'privateKey',
      type: 'string',
      description: 'Base58 encoded private key',
      required: true,
    },
  ],
  examples: [
    {
      description: 'Import Solana wallet',
      input: { privateKey: '5abc123...' },
      output: {
        success: true,
        wallet: {
          id: 'uuid',
          publicKey: 'ABC123...xyz',
          isPrimary: false,
        },
        message: 'Solana wallet imported successfully',
      },
    },
  ],
  handler: async (params, context) => {
    try {
      const { privateKey } = params;

      if (!privateKey) {
        throw new Error('Private key is required');
      }

      const wallet = await walletService.importWallet(context.userId, privateKey);

      return {
        success: true,
        wallet: {
          id: wallet.id,
          publicKey: wallet.public_key,
          isPrimary: wallet.is_primary,
          createdAt: wallet.created_at,
        },
        chain: 'solana',
        message: 'Solana wallet imported successfully',
      };
    } catch (error: any) {
      logger.error('Import Solana wallet action error:', error);
      throw new Error(`Failed to import Solana wallet: ${error.message}`);
    }
  },
};

const getSolanaBalanceAction: Action = {
  name: 'get_solana_balance',
  description: 'Get SOL balance for a Solana wallet',
  parameters: [
    {
      name: 'walletId',
      type: 'string',
      description: 'Wallet ID (optional - uses primary wallet if not specified)',
      required: false,
    },
  ],
  examples: [
    {
      description: 'Get SOL balance',
      input: {},
      output: {
        success: true,
        balance: 10.5,
        publicKey: 'ABC123...xyz',
      },
    },
  ],
  handler: async (params, context) => {
    try {
      let walletId = params.walletId;

      // If no wallet ID, get primary wallet
      if (!walletId) {
        const wallets = await walletService.getUserWallets(context.userId);
        const primaryWallet = wallets.find((w: any) => w.is_primary);
        if (!primaryWallet) {
          throw new Error('No primary wallet found');
        }
        walletId = primaryWallet.id;
      }

      const balance = await walletService.getWalletBalance(walletId);
      const wallets = await walletService.getUserWallets(context.userId);
      const wallet = wallets.find((w: any) => w.id === walletId);

      return {
        success: true,
        balance: balance.sol,
        tokens: balance.tokens,
        publicKey: wallet?.public_key,
        chain: 'solana',
      };
    } catch (error: any) {
      logger.error('Get Solana balance action error:', error);
      throw new Error(`Failed to get Solana balance: ${error.message}`);
    }
  },
};

const listSolanaWalletsAction: Action = {
  name: 'list_solana_wallets',
  description: 'List all Solana wallets for the user',
  parameters: [],
  examples: [
    {
      description: 'List all Solana wallets',
      input: {},
      output: {
        success: true,
        wallets: [
          {
            id: 'uuid1',
            publicKey: 'ABC123...xyz',
            isPrimary: true,
          },
          {
            id: 'uuid2',
            publicKey: 'DEF456...abc',
            isPrimary: false,
          },
        ],
        count: 2,
      },
    },
  ],
  handler: async (_params, context) => {
    try {
      const wallets = await walletService.getUserWallets(context.userId);

      const safeWallets = wallets.map((w: any) => ({
        id: w.id,
        publicKey: w.public_key,
        isPrimary: w.is_primary,
        createdAt: w.created_at,
      }));

      return {
        success: true,
        wallets: safeWallets,
        count: safeWallets.length,
        chain: 'solana',
      };
    } catch (error: any) {
      logger.error('List Solana wallets action error:', error);
      throw new Error(`Failed to list Solana wallets: ${error.message}`);
    }
  },
};

const setPrimaryWalletAction: Action = {
  name: 'set_primary_solana_wallet',
  description: 'Set a Solana wallet as the primary wallet',
  parameters: [
    {
      name: 'walletId',
      type: 'string',
      description: 'Wallet ID to set as primary',
      required: true,
    },
  ],
  examples: [
    {
      description: 'Set primary wallet',
      input: { walletId: 'uuid' },
      output: {
        success: true,
        message: 'Primary wallet updated',
      },
    },
  ],
  handler: async (params, context) => {
    try {
      const { walletId } = params;

      if (!walletId) {
        throw new Error('Wallet ID is required');
      }

      await walletService.setPrimaryWallet(context.userId, walletId);

      return {
        success: true,
        message: 'Primary wallet updated successfully',
        chain: 'solana',
      };
    } catch (error: any) {
      logger.error('Set primary Solana wallet action error:', error);
      throw new Error(`Failed to set primary wallet: ${error.message}`);
    }
  },
};

const deleteSolanaWalletAction: Action = {
  name: 'delete_solana_wallet',
  description: 'Delete a Solana wallet. Use with caution - this removes the wallet from the database.',
  parameters: [
    {
      name: 'walletId',
      type: 'string',
      description: 'Wallet ID to delete',
      required: true,
    },
  ],
  examples: [
    {
      description: 'Delete a wallet by ID',
      input: { walletId: 'uuid' },
      output: {
        success: true,
        message: 'Wallet deleted successfully',
      },
    },
  ],
  handler: async (params, context) => {
    try {
      const { walletId } = params;

      if (!walletId) {
        throw new Error('Wallet ID is required');
      }

      await walletService.deleteWallet(context.userId, walletId);

      return {
        success: true,
        message: 'Wallet deleted successfully',
        chain: 'solana',
        deletedWalletId: walletId,
      };
    } catch (error: any) {
      logger.error('Delete Solana wallet action error:', error);
      throw new Error(`Failed to delete wallet: ${error.message}`);
    }
  },
};

const deleteSolanaWalletsAction: Action = {
  name: 'delete_solana_wallets',
  description: 'Delete multiple Solana wallets at once. Use for batch deletion.',
  parameters: [
    {
      name: 'walletIds',
      type: 'array',
      description: 'Array of wallet IDs to delete',
      required: true,
    },
    {
      name: 'keepWalletId',
      type: 'string',
      description: 'Optional - wallet ID to keep (useful for "delete all except" operations)',
      required: false,
    },
  ],
  examples: [
    {
      description: 'Delete multiple wallets',
      input: { walletIds: ['uuid1', 'uuid2'] },
      output: {
        success: true,
        deleted: 2,
        message: '2 wallets deleted successfully',
      },
    },
    {
      description: 'Delete all wallets except one',
      input: { walletIds: ['uuid1', 'uuid2', 'uuid3'], keepWalletId: 'uuid1' },
      output: {
        success: true,
        deleted: 2,
        kept: 'uuid1',
        message: '2 wallets deleted, 1 wallet kept',
      },
    },
  ],
  handler: async (params, context) => {
    try {
      let { walletIds, keepWalletId } = params;

      if (!walletIds || !Array.isArray(walletIds) || walletIds.length === 0) {
        // If no specific walletIds provided, get all user wallets
        const allWallets = await walletService.getUserWallets(context.userId);
        walletIds = allWallets.map((w: any) => w.id);
      }

      // Filter out the wallet to keep
      if (keepWalletId) {
        walletIds = walletIds.filter((id: string) => id !== keepWalletId);
      }

      if (walletIds.length === 0) {
        return {
          success: true,
          deleted: 0,
          kept: keepWalletId,
          message: 'No wallets to delete',
          chain: 'solana',
        };
      }

      const result = await walletService.deleteWallets(context.userId, walletIds);

      // Get remaining wallets
      const remainingWallets = await walletService.getUserWallets(context.userId);

      return {
        success: true,
        deleted: result.deleted,
        failed: result.failed.length > 0 ? result.failed : undefined,
        kept: keepWalletId,
        remainingWallets: remainingWallets.map((w: any) => ({
          id: w.id,
          publicKey: w.public_key,
          isPrimary: w.is_primary,
        })),
        message: keepWalletId 
          ? `${result.deleted} wallet(s) deleted, 1 wallet kept`
          : `${result.deleted} wallet(s) deleted successfully`,
        chain: 'solana',
      };
    } catch (error: any) {
      logger.error('Delete Solana wallets action error:', error);
      throw new Error(`Failed to delete wallets: ${error.message}`);
    }
  },
};

// =============================================
// PLUGIN DEFINITION
// =============================================

const solanaWalletPlugin: Plugin = {
  id: 'solana-wallet',
  name: 'Solana Wallet Operations',
  description: 'Solana wallet management including create, import, delete, balance, and listing wallets',
  version: '1.0.0',
  isEnabled: true,
  actions: [
    createSolanaWalletAction,
    importSolanaWalletAction,
    getSolanaBalanceAction,
    listSolanaWalletsAction,
    setPrimaryWalletAction,
    deleteSolanaWalletAction,
    deleteSolanaWalletsAction,
  ],
};

export default solanaWalletPlugin;
