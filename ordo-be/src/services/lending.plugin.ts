/**
 * Lending Operations Plugin
 * Provides AI agent actions for DeFi lending and borrowing
 */

import { Plugin, Action, ActionContext } from '../types/plugin';
import lendingService from './lending.service';
import logger from '../config/logger';

/**
 * Lend assets action
 */
const lendAssetsAction: Action = {
  name: 'lend_assets',
  description: 'Lend assets to earn interest on Kamino, MarginFi, or Solend. Returns position ID and transaction signature.',
  parameters: [
    {
      name: 'amount',
      type: 'number',
      description: 'Amount of assets to lend',
      required: true,
    },
    {
      name: 'asset',
      type: 'string',
      description: 'Token mint address to lend',
      required: true,
    },
    {
      name: 'protocol',
      type: 'string',
      description: 'Lending protocol: kamino, marginfi, or solend',
      required: true,
    },
    {
      name: 'assetPriceUsd',
      type: 'number',
      description: 'Current USD price of the asset (for approval checks)',
      required: false,
      default: 1,
    },
  ],
  examples: [
    {
      description: 'Lend 100 USDC on Kamino',
      input: {
        amount: 100,
        asset: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
        protocol: 'kamino',
        assetPriceUsd: 1.0,
      },
      output: {
        success: true,
        signature: 'tx_signature',
        positionId: 'position_id',
      },
    },
  ],
  handler: async (params, context: ActionContext) => {
    try {
      const { amount, asset, protocol, assetPriceUsd = 1 } = params;

      if (!context.userId || !context.walletId) {
        throw new Error('User ID and Wallet ID are required');
      }

      if (!amount || amount <= 0) {
        throw new Error('Amount must be greater than 0');
      }

      if (!asset) {
        throw new Error('Asset mint address is required');
      }

      if (!['kamino', 'marginfi', 'solend'].includes(protocol)) {
        throw new Error('Protocol must be kamino, marginfi, or solend');
      }

      const result = await lendingService.lendWithApproval(
        context.userId,
        context.walletId,
        { amount, asset, protocol },
        assetPriceUsd
      );

      if (result.approval_required) {
        return {
          success: false,
          approval_required: true,
          approval_id: result.approval_id,
          message: result.message,
        };
      }

      return {
        success: true,
        signature: result.signature,
        positionId: result.positionId,
        message: `Successfully lent ${amount} tokens on ${protocol}`,
      };
    } catch (error: any) {
      logger.error('Lend assets action failed:', error);
      return {
        success: false,
        error: error.message || 'Failed to lend assets',
      };
    }
  },
};

/**
 * Borrow assets action
 */
const borrowAssetsAction: Action = {
  name: 'borrow_assets',
  description: 'Borrow assets with collateral on Kamino, MarginFi, or Solend. Returns loan ID, health factor, and transaction signature.',
  parameters: [
    {
      name: 'amount',
      type: 'number',
      description: 'Amount of assets to borrow',
      required: true,
    },
    {
      name: 'asset',
      type: 'string',
      description: 'Token mint address to borrow',
      required: true,
    },
    {
      name: 'collateralAsset',
      type: 'string',
      description: 'Collateral token mint address',
      required: true,
    },
    {
      name: 'collateralAmount',
      type: 'number',
      description: 'Amount of collateral to deposit',
      required: true,
    },
    {
      name: 'protocol',
      type: 'string',
      description: 'Lending protocol: kamino, marginfi, or solend',
      required: true,
    },
    {
      name: 'assetPriceUsd',
      type: 'number',
      description: 'Current USD price of the borrow asset',
      required: false,
      default: 1,
    },
    {
      name: 'collateralPriceUsd',
      type: 'number',
      description: 'Current USD price of the collateral asset',
      required: false,
      default: 1,
    },
  ],
  examples: [
    {
      description: 'Borrow 50 USDC with 0.5 SOL collateral on MarginFi',
      input: {
        amount: 50,
        asset: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
        collateralAsset: 'So11111111111111111111111111111111111111112',
        collateralAmount: 0.5,
        protocol: 'marginfi',
        assetPriceUsd: 1.0,
        collateralPriceUsd: 150.0,
      },
      output: {
        success: true,
        signature: 'tx_signature',
        loanId: 'loan_id',
        healthFactor: 1.8,
      },
    },
  ],
  handler: async (params, context: ActionContext) => {
    try {
      const {
        amount,
        asset,
        collateralAsset,
        collateralAmount,
        protocol,
        assetPriceUsd = 1,
        collateralPriceUsd = 1,
      } = params;

      if (!context.userId || !context.walletId) {
        throw new Error('User ID and Wallet ID are required');
      }

      if (!amount || amount <= 0) {
        throw new Error('Borrow amount must be greater than 0');
      }

      if (!collateralAmount || collateralAmount <= 0) {
        throw new Error('Collateral amount must be greater than 0');
      }

      if (!asset || !collateralAsset) {
        throw new Error('Asset and collateral mint addresses are required');
      }

      if (!['kamino', 'marginfi', 'solend'].includes(protocol)) {
        throw new Error('Protocol must be kamino, marginfi, or solend');
      }

      const result = await lendingService.borrowWithApproval(
        context.userId,
        context.walletId,
        { amount, asset, collateralAsset, collateralAmount, protocol },
        assetPriceUsd,
        collateralPriceUsd
      );

      if (result.approval_required) {
        return {
          success: false,
          approval_required: true,
          approval_id: result.approval_id,
          message: result.message,
        };
      }

      return {
        success: true,
        signature: result.signature,
        loanId: result.loanId,
        healthFactor: result.healthFactor,
        message: `Successfully borrowed ${amount} tokens on ${protocol}. Health factor: ${result.healthFactor?.toFixed(2)}`,
      };
    } catch (error: any) {
      logger.error('Borrow assets action failed:', error);
      return {
        success: false,
        error: error.message || 'Failed to borrow assets',
      };
    }
  },
};

/**
 * Repay loan action
 */
const repayLoanAction: Action = {
  name: 'repay_loan',
  description: 'Repay borrowed assets to close or reduce a loan position',
  parameters: [
    {
      name: 'amount',
      type: 'number',
      description: 'Amount to repay',
      required: true,
    },
    {
      name: 'asset',
      type: 'string',
      description: 'Token mint address to repay',
      required: true,
    },
    {
      name: 'protocol',
      type: 'string',
      description: 'Lending protocol: kamino, marginfi, or solend',
      required: true,
    },
    {
      name: 'loanId',
      type: 'string',
      description: 'Loan ID to repay (optional, protocol-specific)',
      required: false,
    },
  ],
  examples: [
    {
      description: 'Repay 50 USDC loan on Kamino',
      input: {
        amount: 50,
        asset: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
        protocol: 'kamino',
        loanId: 'loan_123',
      },
      output: {
        success: true,
        signature: 'tx_signature',
      },
    },
  ],
  handler: async (params, context: ActionContext) => {
    try {
      const { amount, asset, protocol, loanId } = params;

      if (!context.userId || !context.walletId) {
        throw new Error('User ID and Wallet ID are required');
      }

      if (!amount || amount <= 0) {
        throw new Error('Repay amount must be greater than 0');
      }

      if (!asset) {
        throw new Error('Asset mint address is required');
      }

      if (!['kamino', 'marginfi', 'solend'].includes(protocol)) {
        throw new Error('Protocol must be kamino, marginfi, or solend');
      }

      const result = await lendingService.repay(
        context.userId,
        context.walletId,
        { amount, asset, protocol, loanId }
      );

      return {
        success: true,
        signature: result.signature,
        message: `Successfully repaid ${amount} tokens on ${protocol}`,
      };
    } catch (error: any) {
      logger.error('Repay loan action failed:', error);
      return {
        success: false,
        error: error.message || 'Failed to repay loan',
      };
    }
  },
};

/**
 * Get lending positions action
 */
const getLendingPositionsAction: Action = {
  name: 'get_lending_positions',
  description: 'Get all active lending and borrowing positions across protocols',
  parameters: [],
  handler: async (_params, context: ActionContext) => {
    try {
      if (!context.userId || !context.walletId) {
        throw new Error('User ID and Wallet ID are required');
      }

      const positions = await lendingService.getLendingPositions(
        context.userId,
        context.walletId
      );

      const lendPositions = positions.filter(p => p.type === 'lend');
      const borrowPositions = positions.filter(p => p.type === 'borrow');

      return {
        success: true,
        data: {
          positions,
          lendPositions,
          borrowPositions,
          totalLendPositions: lendPositions.length,
          totalBorrowPositions: borrowPositions.length,
        },
        message: `Found ${positions.length} positions (${lendPositions.length} lending, ${borrowPositions.length} borrowing)`,
      };
    } catch (error: any) {
      logger.error('Get lending positions action failed:', error);
      return {
        success: false,
        error: error.message || 'Failed to get lending positions',
      };
    }
  },
};

/**
 * Get interest rates action
 */
const getInterestRatesAction: Action = {
  name: 'get_interest_rates',
  description: 'Get current supply and borrow APY rates across all lending protocols',
  parameters: [],
  handler: async (_params, _context: ActionContext) => {
    try {
      const rates = await lendingService.getInterestRates();

      // Group by protocol
      const byProtocol: Record<string, any[]> = {};
      rates.forEach(rate => {
        if (!byProtocol[rate.protocol]) {
          byProtocol[rate.protocol] = [];
        }
        byProtocol[rate.protocol].push(rate);
      });

      return {
        success: true,
        data: {
          rates,
          byProtocol,
          protocolCount: Object.keys(byProtocol).length,
        },
        message: `Retrieved interest rates for ${rates.length} assets across ${Object.keys(byProtocol).length} protocols`,
      };
    } catch (error: any) {
      logger.error('Get interest rates action failed:', error);
      return {
        success: false,
        error: error.message || 'Failed to get interest rates',
      };
    }
  },
};

/**
 * Lending Operations Plugin
 */
const lendingPlugin: Plugin = {
  id: 'lending-operations',
  name: 'Lending Operations',
  version: '1.0.0',
  description: 'DeFi lending and borrowing on Kamino, MarginFi, and Solend protocols',
  isEnabled: true,
  actions: [
    lendAssetsAction,
    borrowAssetsAction,
    repayLoanAction,
    getLendingPositionsAction,
    getInterestRatesAction,
  ],
};

export default lendingPlugin;
