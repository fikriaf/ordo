/**
 * Bridge Plugin
 * Cross-chain bridge operations for AI agent
 */

import { Action } from '../types/plugin';
import bridgeService from './bridge.service';
import logger from '../config/logger';

export const bridgePlugin: Action[] = [
  {
    name: 'get_bridge_quote',
    description: 'Get a quote for bridging assets between chains. Returns estimated output amount, fees, and time.',
    parameters: [
      {
        name: 'sourceChain',
        type: 'string',
        description: 'Source blockchain (e.g., "solana", "ethereum", "polygon")',
        required: true,
      },
      {
        name: 'destinationChain',
        type: 'string',
        description: 'Destination blockchain',
        required: true,
      },
      {
        name: 'sourceToken',
        type: 'string',
        description: 'Source token address or symbol',
        required: true,
      },
      {
        name: 'destinationToken',
        type: 'string',
        description: 'Destination token address or symbol',
        required: true,
      },
      {
        name: 'amount',
        type: 'number',
        description: 'Amount to bridge',
        required: true,
      },
      {
        name: 'protocol',
        type: 'string',
        description: 'Bridge protocol: "wormhole", "mayan", or "debridge"',
        required: true,
      },
    ],
    handler: async (params: any) => {
      try {
        logger.info('AI Agent: Getting bridge quote', params);

        const quote = await bridgeService.getQuote({
          sourceChain: params.sourceChain,
          destinationChain: params.destinationChain,
          sourceToken: params.sourceToken,
          destinationToken: params.destinationToken,
          amount: params.amount,
          protocol: params.protocol,
        });

        return {
          success: true,
          data: quote,
          message: `Bridge quote: You will receive approximately ${quote.outputAmount.toFixed(4)} ${params.destinationToken} on ${params.destinationChain}. Estimated time: ${Math.floor(quote.estimatedTime / 60)} minutes. Total fees: ${quote.fees.total.toFixed(6)}`,
        };
      } catch (error: any) {
        logger.error('AI Agent: Get bridge quote failed:', error);
        return {
          success: false,
          error: error.message || 'Failed to get bridge quote',
        };
      }
    },
  },
  {
    name: 'bridge_assets',
    description: 'Execute a cross-chain bridge transaction. Transfers assets from one blockchain to another.',
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
        description: 'Source wallet ID',
        required: true,
      },
      {
        name: 'sourceChain',
        type: 'string',
        description: 'Source blockchain',
        required: true,
      },
      {
        name: 'destinationChain',
        type: 'string',
        description: 'Destination blockchain',
        required: true,
      },
      {
        name: 'sourceToken',
        type: 'string',
        description: 'Source token address',
        required: true,
      },
      {
        name: 'destinationToken',
        type: 'string',
        description: 'Destination token address',
        required: true,
      },
      {
        name: 'amount',
        type: 'number',
        description: 'Amount to bridge',
        required: true,
      },
      {
        name: 'destinationAddress',
        type: 'string',
        description: 'Destination wallet address',
        required: true,
      },
      {
        name: 'protocol',
        type: 'string',
        description: 'Bridge protocol: "wormhole", "mayan", or "debridge"',
        required: true,
      },
    ],
    handler: async (params: any) => {
      try {
        logger.info('AI Agent: Executing bridge transaction', params);

        const result = await bridgeService.executeBridge(
          params.userId,
          params.walletId,
          {
            sourceChain: params.sourceChain,
            destinationChain: params.destinationChain,
            sourceToken: params.sourceToken,
            destinationToken: params.destinationToken,
            amount: params.amount,
            destinationAddress: params.destinationAddress,
            protocol: params.protocol,
          }
        );

        return {
          success: true,
          data: result,
          message: `Bridge transaction initiated! Transaction ID: ${result.bridgeTxId}. Status: ${result.status}. Estimated completion: ${result.estimatedCompletionTime.toLocaleString()}`,
        };
      } catch (error: any) {
        logger.error('AI Agent: Bridge assets failed:', error);
        return {
          success: false,
          error: error.message || 'Failed to execute bridge transaction',
        };
      }
    },
  },
  {
    name: 'get_bridge_status',
    description: 'Check the status of a cross-chain bridge transaction.',
    parameters: [
      {
        name: 'bridgeTxId',
        type: 'string',
        description: 'Bridge transaction ID',
        required: true,
      },
      {
        name: 'protocol',
        type: 'string',
        description: 'Bridge protocol: "wormhole", "mayan", or "debridge"',
        required: true,
      },
    ],
    handler: async (params: any) => {
      try {
        logger.info('AI Agent: Getting bridge status', params);

        const status = await bridgeService.getBridgeStatus(
          params.bridgeTxId,
          params.protocol
        );

        let message = `Bridge status: ${status.status}. Progress: ${status.progress}%`;
        
        if (status.estimatedTimeRemaining) {
          message += `. Estimated time remaining: ${Math.floor(status.estimatedTimeRemaining / 60)} minutes`;
        }

        if (status.destinationTxHash) {
          message += `. Destination transaction: ${status.destinationTxHash}`;
        }

        return {
          success: true,
          data: status,
          message,
        };
      } catch (error: any) {
        logger.error('AI Agent: Get bridge status failed:', error);
        return {
          success: false,
          error: error.message || 'Failed to get bridge status',
        };
      }
    },
  },
  {
    name: 'get_supported_chains',
    description: 'Get list of supported blockchains for bridging.',
    parameters: [],
    handler: async () => {
      try {
        logger.info('AI Agent: Getting supported chains');

        const chains = await bridgeService.getSupportedChains();

        const chainList = chains.map(c => `${c.name} (${c.chainId})`).join(', ');

        return {
          success: true,
          data: chains,
          message: `Supported chains: ${chainList}`,
        };
      } catch (error: any) {
        logger.error('AI Agent: Get supported chains failed:', error);
        return {
          success: false,
          error: error.message || 'Failed to get supported chains',
        };
      }
    },
  },
];
