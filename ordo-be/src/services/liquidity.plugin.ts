/**
 * Liquidity Plugin
 * Liquidity pool operations for AI agent
 */

import { Action } from '../types/plugin';
import liquidityService from './liquidity.service';
import logger from '../config/logger';

export const liquidityPlugin: Action[] = [
  {
    name: 'add_liquidity',
    description: 'Add liquidity to a DEX pool. Provides LP tokens in return.',
    parameters: [
      {
        name: 'userId',
        type: 'string',
        description: 'User ID',
        required: true,
      },
      {
        name: 'walletId',
        type: 'string',
        description: 'Wallet ID',
        required: true,
      },
      {
        name: 'protocol',
        type: 'string',
        description: 'DEX protocol: "raydium", "meteora", or "orca"',
        required: true,
      },
      {
        name: 'tokenA',
        type: 'string',
        description: 'First token address',
        required: true,
      },
      {
        name: 'tokenB',
        type: 'string',
        description: 'Second token address',
        required: true,
      },
      {
        name: 'amountA',
        type: 'number',
        description: 'Amount of token A',
        required: true,
      },
      {
        name: 'amountB',
        type: 'number',
        description: 'Amount of token B',
        required: true,
      },
      {
        name: 'slippage',
        type: 'number',
        description: 'Slippage tolerance (0-100)',
        required: false,
      },
    ],
    handler: async (params: any) => {
      try {
        logger.info('AI Agent: Adding liquidity', params);

        const result = await liquidityService.addLiquidity(
          params.userId,
          params.walletId,
          {
            protocol: params.protocol,
            tokenA: params.tokenA,
            tokenB: params.tokenB,
            amountA: params.amountA,
            amountB: params.amountB,
            slippage: params.slippage,
          }
        );

        return {
          success: true,
          data: result,
          message: `Liquidity added successfully! You received ${result.lpTokens.toFixed(4)} LP tokens. Position ID: ${result.positionId}`,
        };
      } catch (error: any) {
        logger.error('AI Agent: Add liquidity failed:', error);
        return {
          success: false,
          error: error.message || 'Failed to add liquidity',
        };
      }
    },
  },
  {
    name: 'remove_liquidity',
    description: 'Remove liquidity from a DEX pool. Burns LP tokens and returns underlying assets.',
    parameters: [
      {
        name: 'userId',
        type: 'string',
        description: 'User ID',
        required: true,
      },
      {
        name: 'walletId',
        type: 'string',
        description: 'Wallet ID',
        required: true,
      },
      {
        name: 'positionId',
        type: 'string',
        description: 'Liquidity position ID',
        required: true,
      },
      {
        name: 'protocol',
        type: 'string',
        description: 'DEX protocol: "raydium", "meteora", or "orca"',
        required: true,
      },
      {
        name: 'percentage',
        type: 'number',
        description: 'Percentage to remove (0-100)',
        required: true,
      },
    ],
    handler: async (params: any) => {
      try {
        logger.info('AI Agent: Removing liquidity', params);

        const result = await liquidityService.removeLiquidity(
          params.userId,
          params.walletId,
          {
            protocol: params.protocol,
            positionId: params.positionId,
            percentage: params.percentage,
          }
        );

        return {
          success: true,
          data: result,
          message: `Liquidity removed successfully! You received ${result.amountA.toFixed(4)} of token A and ${result.amountB.toFixed(4)} of token B`,
        };
      } catch (error: any) {
        logger.error('AI Agent: Remove liquidity failed:', error);
        return {
          success: false,
          error: error.message || 'Failed to remove liquidity',
        };
      }
    },
  },
  {
    name: 'get_lp_positions',
    description: 'Get all liquidity pool positions for a user.',
    parameters: [
      {
        name: 'userId',
        type: 'string',
        description: 'User ID',
        required: true,
      },
    ],
    handler: async (params: any) => {
      try {
        logger.info('AI Agent: Getting LP positions', params);

        const positions = await liquidityService.getPositions(params.userId);

        const summary = positions.map(p => 
          `${p.protocol} pool (${p.token_a}/${p.token_b}): ${p.lp_tokens.toFixed(4)} LP tokens, Status: ${p.status}`
        ).join('\n');

        return {
          success: true,
          data: positions,
          message: positions.length > 0 
            ? `You have ${positions.length} liquidity positions:\n${summary}`
            : 'You have no active liquidity positions',
        };
      } catch (error: any) {
        logger.error('AI Agent: Get LP positions failed:', error);
        return {
          success: false,
          error: error.message || 'Failed to get LP positions',
        };
      }
    },
  },
  {
    name: 'get_position_value',
    description: 'Get current value and performance of a liquidity position.',
    parameters: [
      {
        name: 'userId',
        type: 'string',
        description: 'User ID',
        required: true,
      },
      {
        name: 'positionId',
        type: 'string',
        description: 'Position ID',
        required: true,
      },
    ],
    handler: async (params: any) => {
      try {
        logger.info('AI Agent: Getting position value', params);

        const value = await liquidityService.getPositionValue(
          params.positionId,
          params.userId
        );

        return {
          success: true,
          data: value,
          message: `Position value: $${value.currentValueUsd.toFixed(2)}. Fees earned: $${value.feesEarnedUsd.toFixed(2)}. Impermanent loss: ${value.impermanentLossPercentage.toFixed(2)}%`,
        };
      } catch (error: any) {
        logger.error('AI Agent: Get position value failed:', error);
        return {
          success: false,
          error: error.message || 'Failed to get position value',
        };
      }
    },
  },
  {
    name: 'calculate_impermanent_loss',
    description: 'Calculate impermanent loss for a liquidity position.',
    parameters: [
      {
        name: 'userId',
        type: 'string',
        description: 'User ID',
        required: true,
      },
      {
        name: 'positionId',
        type: 'string',
        description: 'Position ID',
        required: true,
      },
    ],
    handler: async (params: any) => {
      try {
        logger.info('AI Agent: Calculating impermanent loss', params);

        const il = await liquidityService.calculateImpermanentLoss(
          params.positionId,
          params.userId
        );

        return {
          success: true,
          data: il,
          message: `Impermanent loss: $${il.impermanentLoss.toFixed(2)} (${il.impermanentLossPercentage.toFixed(2)}%)`,
        };
      } catch (error: any) {
        logger.error('AI Agent: Calculate impermanent loss failed:', error);
        return {
          success: false,
          error: error.message || 'Failed to calculate impermanent loss',
        };
      }
    },
  },
];
