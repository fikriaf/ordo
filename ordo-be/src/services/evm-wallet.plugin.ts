/**
 * EVM Wallet Plugin
 * Provides AI access to multi-chain EVM wallet operations
 */

import { Plugin, Action } from '../types/plugin';
import evmWalletService, { EVMChainId } from './evm-wallet.service';
import logger from '../config/logger';

// =============================================
// EVM WALLET ACTIONS
// =============================================

const createEvmWalletAction: Action = {
  name: 'create_evm_wallet',
  description: 'Create a new EVM wallet for Ethereum, Polygon, BSC, Arbitrum, Optimism, or Avalanche',
  parameters: [
    {
      name: 'chainId',
      type: 'string',
      description: 'Chain ID: ethereum, polygon, bsc, arbitrum, optimism, or avalanche',
      required: true,
    },
  ],
  examples: [
    {
      description: 'Create Ethereum wallet',
      input: { chainId: 'ethereum' },
      output: {
        success: true,
        wallet: {
          id: 'uuid',
          address: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb',
          chainId: 'ethereum',
          isPrimary: true,
        },
      },
    },
    {
      description: 'Create Polygon wallet',
      input: { chainId: 'polygon' },
      output: {
        success: true,
        wallet: {
          id: 'uuid',
          address: '0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063',
          chainId: 'polygon',
          isPrimary: true,
        },
      },
    },
  ],
  handler: async (params, context) => {
    try {
      const { chainId } = params;

      // Validate chain ID
      if (!Object.values(EVMChainId).includes(chainId as EVMChainId)) {
        throw new Error(
          'Invalid chain ID. Must be one of: ethereum, polygon, bsc, arbitrum, optimism, avalanche'
        );
      }

      const wallet = await evmWalletService.createWallet(
        context.userId,
        chainId as EVMChainId
      );

      // Don't expose encrypted keys
      const { encryptedPrivateKey, encryptionIv, encryptionAuthTag, ...safeWallet } = wallet;

      return {
        success: true,
        wallet: safeWallet,
        message: `${chainId.charAt(0).toUpperCase() + chainId.slice(1)} wallet created successfully`,
      };
    } catch (error: any) {
      logger.error('Create EVM wallet action error:', error);
      throw new Error(`Failed to create EVM wallet: ${error.message}`);
    }
  },
};

const getEvmBalanceAction: Action = {
  name: 'get_evm_balance',
  description: 'Get native and ERC-20 token balances for an EVM wallet',
  parameters: [
    {
      name: 'walletId',
      type: 'string',
      description: 'EVM wallet ID',
      required: true,
    },
  ],
  examples: [
    {
      description: 'Get Ethereum wallet balance',
      input: { walletId: 'wallet-uuid' },
      output: {
        success: true,
        balance: {
          native: '1.5',
          nativeSymbol: 'ETH',
          tokens: [
            {
              address: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
              symbol: 'USDC',
              name: 'USD Coin',
              amount: '1000.0',
              decimals: 6,
            },
          ],
        },
      },
    },
  ],
  handler: async (params, context) => {
    try {
      const { walletId } = params;

      // Verify wallet belongs to user
      const wallet = await evmWalletService.getWallet(walletId);
      if (!wallet) {
        throw new Error('Wallet not found');
      }

      if (wallet.userId !== context.userId) {
        throw new Error('Unauthorized access to wallet');
      }

      const balance = await evmWalletService.getWalletBalance(walletId);

      return {
        success: true,
        balance,
        wallet: {
          address: wallet.address,
          chainId: wallet.chainId,
        },
      };
    } catch (error: any) {
      logger.error('Get EVM balance action error:', error);
      throw new Error(`Failed to get EVM balance: ${error.message}`);
    }
  },
};

const transferEvmNativeAction: Action = {
  name: 'transfer_evm_native',
  description: 'Transfer native tokens (ETH, MATIC, BNB, etc.) from an EVM wallet',
  parameters: [
    {
      name: 'walletId',
      type: 'string',
      description: 'EVM wallet ID to transfer from',
      required: true,
    },
    {
      name: 'toAddress',
      type: 'string',
      description: 'Recipient EVM address (0x...)',
      required: true,
    },
    {
      name: 'amount',
      type: 'string',
      description: 'Amount to transfer in native token (e.g., "0.1" for 0.1 ETH)',
      required: true,
    },
  ],
  examples: [
    {
      description: 'Transfer 0.1 ETH',
      input: {
        walletId: 'wallet-uuid',
        toAddress: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb',
        amount: '0.1',
      },
      output: {
        success: true,
        txHash: '0xabc123...',
        amount: '0.1',
        message: 'Native token transferred successfully',
      },
    },
  ],
  handler: async (params, context) => {
    try {
      const { walletId, toAddress, amount } = params;

      // Verify wallet belongs to user
      const wallet = await evmWalletService.getWallet(walletId);
      if (!wallet) {
        throw new Error('Wallet not found');
      }

      if (wallet.userId !== context.userId) {
        throw new Error('Unauthorized access to wallet');
      }

      // TODO: Check approval threshold from user preferences
      // For now, execute directly

      const txHash = await evmWalletService.transferNative(walletId, toAddress, amount);

      return {
        success: true,
        txHash,
        amount,
        chainId: wallet.chainId,
        message: `${amount} native tokens transferred successfully`,
      };
    } catch (error: any) {
      logger.error('Transfer EVM native action error:', error);
      throw new Error(`Failed to transfer native tokens: ${error.message}`);
    }
  },
};

const transferEvmTokenAction: Action = {
  name: 'transfer_evm_token',
  description: 'Transfer ERC-20 tokens from an EVM wallet',
  parameters: [
    {
      name: 'walletId',
      type: 'string',
      description: 'EVM wallet ID to transfer from',
      required: true,
    },
    {
      name: 'toAddress',
      type: 'string',
      description: 'Recipient EVM address (0x...)',
      required: true,
    },
    {
      name: 'tokenAddress',
      type: 'string',
      description: 'ERC-20 token contract address (0x...)',
      required: true,
    },
    {
      name: 'amount',
      type: 'string',
      description: 'Amount to transfer in token units',
      required: true,
    },
  ],
  examples: [
    {
      description: 'Transfer 100 USDC',
      input: {
        walletId: 'wallet-uuid',
        toAddress: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb',
        tokenAddress: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
        amount: '100',
      },
      output: {
        success: true,
        txHash: '0xdef456...',
        amount: '100',
        message: 'Token transferred successfully',
      },
    },
  ],
  handler: async (params, context) => {
    try {
      const { walletId, toAddress, tokenAddress, amount } = params;

      // Verify wallet belongs to user
      const wallet = await evmWalletService.getWallet(walletId);
      if (!wallet) {
        throw new Error('Wallet not found');
      }

      if (wallet.userId !== context.userId) {
        throw new Error('Unauthorized access to wallet');
      }

      // TODO: Check approval threshold from user preferences

      const txHash = await evmWalletService.transferToken(
        walletId,
        toAddress,
        tokenAddress,
        amount
      );

      return {
        success: true,
        txHash,
        amount,
        tokenAddress,
        chainId: wallet.chainId,
        message: `${amount} tokens transferred successfully`,
      };
    } catch (error: any) {
      logger.error('Transfer EVM token action error:', error);
      throw new Error(`Failed to transfer tokens: ${error.message}`);
    }
  },
};

const listEvmWalletsAction: Action = {
  name: 'list_evm_wallets',
  description: 'List all EVM wallets for the user, optionally filtered by chain',
  parameters: [
    {
      name: 'chainId',
      type: 'string',
      description: 'Optional chain ID to filter: ethereum, polygon, bsc, arbitrum, optimism, avalanche',
      required: false,
    },
  ],
  examples: [
    {
      description: 'List all EVM wallets',
      input: {},
      output: {
        success: true,
        wallets: [
          {
            id: 'uuid1',
            address: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb',
            chainId: 'ethereum',
            isPrimary: true,
          },
          {
            id: 'uuid2',
            address: '0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063',
            chainId: 'polygon',
            isPrimary: true,
          },
        ],
      },
    },
    {
      description: 'List Ethereum wallets only',
      input: { chainId: 'ethereum' },
      output: {
        success: true,
        wallets: [
          {
            id: 'uuid1',
            address: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb',
            chainId: 'ethereum',
            isPrimary: true,
          },
        ],
      },
    },
  ],
  handler: async (params, context) => {
    try {
      const { chainId } = params;

      // Validate chain ID if provided
      if (chainId && !Object.values(EVMChainId).includes(chainId as EVMChainId)) {
        throw new Error('Invalid chain ID');
      }

      const wallets = await evmWalletService.getUserWallets(
        context.userId,
        chainId as EVMChainId | undefined
      );

      // Don't expose encrypted keys
      const safeWallets = wallets.map((w) => {
        const { encryptedPrivateKey, encryptionIv, encryptionAuthTag, ...safe } = w;
        return safe;
      });

      return {
        success: true,
        wallets: safeWallets,
        count: safeWallets.length,
      };
    } catch (error: any) {
      logger.error('List EVM wallets action error:', error);
      throw new Error(`Failed to list EVM wallets: ${error.message}`);
    }
  },
};

const estimateEvmGasAction: Action = {
  name: 'estimate_evm_gas',
  description: 'Estimate gas fees for EVM transactions',
  parameters: [
    {
      name: 'chainId',
      type: 'string',
      description: 'Chain ID: ethereum, polygon, bsc, arbitrum, optimism, avalanche',
      required: true,
    },
    {
      name: 'type',
      type: 'string',
      description: 'Transaction type: native or token',
      required: true,
    },
    {
      name: 'tokenAddress',
      type: 'string',
      description: 'Token contract address (required for token transfers)',
      required: false,
    },
  ],
  examples: [
    {
      description: 'Estimate gas for ETH transfer',
      input: { chainId: 'ethereum', type: 'native' },
      output: {
        success: true,
        estimate: {
          gasLimit: '21000',
          gasPrice: '50000000000',
          estimatedFee: '0.00105',
          estimatedFeeUsd: 2.1,
        },
      },
    },
    {
      description: 'Estimate gas for USDC transfer',
      input: {
        chainId: 'ethereum',
        type: 'token',
        tokenAddress: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
      },
      output: {
        success: true,
        estimate: {
          gasLimit: '65000',
          gasPrice: '50000000000',
          estimatedFee: '0.00325',
          estimatedFeeUsd: 6.5,
        },
      },
    },
  ],
  handler: async (params, _context) => {
    try {
      const { chainId, type, tokenAddress } = params;

      // Validate inputs
      if (!Object.values(EVMChainId).includes(chainId as EVMChainId)) {
        throw new Error('Invalid chain ID');
      }

      if (type !== 'native' && type !== 'token') {
        throw new Error('Transaction type must be "native" or "token"');
      }

      const estimate = await evmWalletService.estimateGas(
        chainId as EVMChainId,
        type as 'native' | 'token',
        tokenAddress
      );

      return {
        success: true,
        estimate,
        chainId,
      };
    } catch (error: any) {
      logger.error('Estimate EVM gas action error:', error);
      throw new Error(`Failed to estimate gas: ${error.message}`);
    }
  },
};

// =============================================
// PLUGIN DEFINITION
// =============================================

const evmWalletPlugin: Plugin = {
  id: 'evm-wallet',
  name: 'EVM Wallet Operations',
  description:
    'Multi-chain EVM wallet management supporting Ethereum, Polygon, BSC, Arbitrum, Optimism, and Avalanche',
  version: '1.0.0',
  isEnabled: true,
  actions: [
    createEvmWalletAction,
    getEvmBalanceAction,
    transferEvmNativeAction,
    transferEvmTokenAction,
    listEvmWalletsAction,
    estimateEvmGasAction,
  ],
};

export default evmWalletPlugin;
