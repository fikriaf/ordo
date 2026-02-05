import logger from '../config/logger';
import walletService from './wallet.service';
import { Plugin, Action, ActionContext } from '../types/plugin';
import pluginManager from './plugin-manager.service';
import userFeaturesPlugin from './user-features.plugin';
import evmWalletPlugin from './evm-wallet.plugin';
import tokenRiskPlugin from './token-risk.plugin';
import lendingPlugin from './lending.plugin';
import { bridgePlugin } from './bridge.plugin';
import { liquidityPlugin } from './liquidity.plugin';
import priceFeedService from './price-feed.service';
import tokenTransferService from './token-transfer.service';
import jupiterService from './jupiter.service';
import heliusService from './helius.service';
import nftService from './nft.service';

class SolanaAgentService {
  constructor() {
    this.registerPlugins();
  }

  private registerPlugins() {
    // Register Token Operations Plugin
    const tokenPlugin: Plugin = {
      id: 'solana-token',
      name: 'Solana Token Operations',
      version: '1.0.0',
      description: 'Token operations: transfer, balance, swap',
      isEnabled: true,
      actions: this.getTokenActions(),
    };

    // Register Swap Operations Plugin
    const swapPlugin: Plugin = {
      id: 'jupiter-swap',
      name: 'Jupiter Swap Operations',
      version: '1.0.0',
      description: 'Token swaps via Jupiter aggregator',
      isEnabled: true,
      actions: this.getSwapActions(),
    };

    // Register Price Feed Plugin
    const pricePlugin: Plugin = {
      id: 'price-feed',
      name: 'Price Feed',
      version: '1.0.0',
      description: 'Real-time price feeds',
      isEnabled: true,
      actions: this.getPriceActions(),
    };

    // Register Analytics Plugin
    const analyticsPlugin: Plugin = {
      id: 'helius-analytics',
      name: 'Helius Analytics',
      version: '1.0.0',
      description: 'Enhanced Solana data and analytics via Helius',
      isEnabled: true,
      actions: this.getAnalyticsActions(),
    };

    // Register NFT Plugin
    const nftPlugin: Plugin = {
      id: 'nft-operations',
      name: 'NFT Operations',
      version: '1.0.0',
      description: 'NFT minting, transfer, and management',
      isEnabled: true,
      actions: this.getNFTActions(),
    };

    pluginManager.registerPlugin(tokenPlugin);
    pluginManager.registerPlugin(swapPlugin);
    pluginManager.registerPlugin(pricePlugin);
    pluginManager.registerPlugin(analyticsPlugin);
    pluginManager.registerPlugin(nftPlugin);
    pluginManager.registerPlugin(userFeaturesPlugin);
    pluginManager.registerPlugin(evmWalletPlugin);
    pluginManager.registerPlugin(tokenRiskPlugin);
    pluginManager.registerPlugin(lendingPlugin);

    // Register Bridge Plugin
    const bridgePluginObj: Plugin = {
      id: 'bridge',
      name: 'Cross-Chain Bridge',
      version: '1.0.0',
      description: 'Cross-chain asset bridging via Wormhole, Mayan, and deBridge',
      actions: bridgePlugin,
      isEnabled: true,
    };
    pluginManager.registerPlugin(bridgePluginObj);

    // Register Liquidity Plugin
    const liquidityPluginObj: Plugin = {
      id: 'liquidity',
      name: 'Liquidity Pool Operations',
      version: '1.0.0',
      description: 'Add and remove liquidity from DEX pools (Raydium, Meteora, Orca)',
      actions: liquidityPlugin,
      isEnabled: true,
    };
    pluginManager.registerPlugin(liquidityPluginObj);

    logger.info('Solana Agent plugins registered');
  }

  private getTokenActions(): Action[] {
    return [
      {
        name: 'get_balance',
        description: 'Get wallet balance (SOL and tokens)',
        parameters: [],
        handler: async (_params, context) => this.getBalance(context),
      },
      {
        name: 'transfer_sol',
        description: 'Transfer SOL to another address',
        parameters: [
          {
            name: 'toAddress',
            type: 'string',
            description: 'Recipient Solana address',
            required: true,
          },
          {
            name: 'amount',
            type: 'number',
            description: 'Amount of SOL to transfer',
            required: true,
          },
        ],
        examples: [
          {
            description: 'Transfer 1 SOL',
            input: { toAddress: 'ABC...XYZ', amount: 1.0 },
            output: { success: true, signature: 'tx_sig' },
          },
        ],
        handler: async (params, context) => this.transferSOL(params, context),
      },
      {
        name: 'transfer_token',
        description: 'Transfer SPL token to another address',
        parameters: [
          {
            name: 'toAddress',
            type: 'string',
            description: 'Recipient Solana address',
            required: true,
          },
          {
            name: 'tokenMint',
            type: 'string',
            description: 'Token mint address',
            required: true,
          },
          {
            name: 'amount',
            type: 'number',
            description: 'Amount of tokens to transfer',
            required: true,
          },
          {
            name: 'decimals',
            type: 'number',
            description: 'Token decimals (default: 9)',
            required: false,
            default: 9,
          },
        ],
        examples: [
          {
            description: 'Transfer 100 USDC',
            input: {
              toAddress: 'ABC...XYZ',
              tokenMint: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
              amount: 100,
              decimals: 6,
            },
            output: { success: true, signature: 'tx_sig' },
          },
        ],
        handler: async (params, context) => this.transferToken(params, context),
      },
    ];
  }

  private getSwapActions(): Action[] {
    return [
      {
        name: 'get_swap_quote',
        description: 'Get token swap quote from Jupiter',
        parameters: [
          {
            name: 'inputMint',
            type: 'string',
            description: 'Input token mint address',
            required: true,
          },
          {
            name: 'outputMint',
            type: 'string',
            description: 'Output token mint address',
            required: true,
          },
          {
            name: 'amount',
            type: 'number',
            description: 'Amount to swap',
            required: true,
          },
          {
            name: 'slippageBps',
            type: 'number',
            description: 'Slippage tolerance in basis points (default: 50)',
            required: false,
            default: 50,
          },
        ],
        examples: [
          {
            description: 'Get quote to swap 1 SOL to USDC',
            input: {
              inputMint: 'So11111111111111111111111111111111111111112',
              outputMint: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
              amount: 1.0,
              slippageBps: 50,
            },
            output: {
              success: true,
              inputAmount: 1.0,
              outputAmount: 150.5,
              priceImpact: 0.01,
            },
          },
        ],
        handler: async (params, _context) => this.getSwapQuote(params),
      },
      {
        name: 'get_token_price',
        description: 'Get current price of a token in USD',
        parameters: [
          {
            name: 'tokenMint',
            type: 'string',
            description: 'Token mint address',
            required: true,
          },
        ],
        examples: [
          {
            description: 'Get USDC price',
            input: { tokenMint: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v' },
            output: { success: true, price: 1.0, currency: 'USD' },
          },
        ],
        handler: async (params, _context) => this.getTokenPrice(params),
      },
    ];
  }

  private getPriceActions(): Action[] {
    return [
      {
        name: 'get_sol_price',
        description: 'Get current SOL price in USD',
        parameters: [],
        handler: async () => this.getSolPrice(),
      },
    ];
  }

  // Action Handlers
  private async getBalance(context: ActionContext): Promise<any> {
    if (!context.walletId) {
      throw new Error('Wallet ID required');
    }

    const balance = await walletService.getWalletBalance(context.walletId);
    
    return {
      success: true,
      sol: balance.sol,
      tokens: balance.tokens,
    };
  }

  private async transferSOL(params: any, context: ActionContext): Promise<any> {
    if (!context.walletId) {
      throw new Error('Wallet ID required');
    }

    const { toAddress, amount } = params;

    const result = await tokenTransferService.transferSOL(
      context.userId,
      context.walletId,
      toAddress,
      amount
    );

    return {
      success: true,
      ...result,
      message: `Successfully transferred ${amount} SOL`,
    };
  }

  private async transferToken(params: any, context: ActionContext): Promise<any> {
    if (!context.walletId) {
      throw new Error('Wallet ID required');
    }

    const { toAddress, tokenMint, amount, decimals = 9 } = params;

    const result = await tokenTransferService.transferToken(
      context.userId,
      context.walletId,
      toAddress,
      tokenMint,
      amount,
      decimals
    );

    return {
      success: true,
      ...result,
      message: `Successfully transferred ${amount} tokens`,
    };
  }

  private async getSolPrice(): Promise<any> {
    try {
      const price = await priceFeedService.getSolPrice();
      return {
        success: true,
        symbol: 'SOL',
        price,
        currency: 'USD',
        timestamp: new Date().toISOString(),
      };
    } catch (error: any) {
      logger.error('Failed to get SOL price:', error);
      // Return fallback mock price if service fails
      return {
        success: true,
        symbol: 'SOL',
        price: 150.25,
        currency: 'USD',
        timestamp: new Date().toISOString(),
        note: 'Fallback price - service unavailable',
      };
    }
  }

  // Swap Action Handlers
  private async getSwapQuote(params: any): Promise<any> {
    const { inputMint, outputMint, amount, slippageBps } = params;

    const quote = await jupiterService.getSwapQuote({
      inputMint,
      outputMint,
      amount,
      slippageBps,
    });

    return {
      success: true,
      ...quote,
    };
  }

  private async getTokenPrice(params: any): Promise<any> {
    const { tokenMint } = params;

    try {
      const priceData = await priceFeedService.getPrice(tokenMint);

      return {
        success: true,
        tokenMint,
        price: priceData.price,
        currency: 'USD',
        confidence: priceData.confidence,
        isStale: priceData.isStale,
        timestamp: new Date(priceData.timestamp).toISOString(),
      };
    } catch (error: any) {
      logger.error('Failed to get token price:', error);
      
      // Try Jupiter as fallback
      try {
        const price = await jupiterService.getTokenPrice(tokenMint);
        return {
          success: true,
          tokenMint,
          price,
          currency: 'USD',
          source: 'jupiter',
        };
      } catch (jupiterError: any) {
        return {
          success: false,
          error: 'Price not available for this token',
        };
      }
    }
  }

  // Analytics Action Handlers
  private getAnalyticsActions(): Action[] {
    return [
      {
        name: 'get_enhanced_transactions',
        description: 'Get enhanced transaction history with parsed data',
        parameters: [
          {
            name: 'address',
            type: 'string',
            description: 'Solana address',
            required: true,
          },
          {
            name: 'limit',
            type: 'number',
            description: 'Number of transactions (default: 10)',
            required: false,
            default: 10,
          },
        ],
        examples: [
          {
            description: 'Get last 10 transactions',
            input: { address: 'ABC...XYZ', limit: 10 },
            output: { success: true, transactions: [] },
          },
        ],
        handler: async (params, _context) => this.getEnhancedTransactions(params),
      },
      {
        name: 'get_token_metadata',
        description: 'Get detailed token metadata including name, symbol, image',
        parameters: [
          {
            name: 'mintAddress',
            type: 'string',
            description: 'Token mint address',
            required: true,
          },
        ],
        examples: [
          {
            description: 'Get USDC metadata',
            input: { mintAddress: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v' },
            output: { success: true, name: 'USD Coin', symbol: 'USDC' },
          },
        ],
        handler: async (params, _context) => this.getTokenMetadata(params),
      },
      {
        name: 'get_nfts',
        description: 'Get NFTs owned by an address',
        parameters: [
          {
            name: 'address',
            type: 'string',
            description: 'Owner address',
            required: true,
          },
          {
            name: 'limit',
            type: 'number',
            description: 'Number of NFTs (default: 100)',
            required: false,
            default: 100,
          },
        ],
        examples: [
          {
            description: 'Get NFTs owned by address',
            input: { address: 'ABC...XYZ', limit: 100 },
            output: { success: true, nfts: [] },
          },
        ],
        handler: async (params, _context) => this.getNFTs(params),
      },
    ];
  }

  private async getEnhancedTransactions(params: any): Promise<any> {
    const { address, limit = 10 } = params;

    const transactions = await heliusService.getEnhancedTransactions(address, limit);

    return {
      success: true,
      transactions,
      count: transactions.length,
    };
  }

  private async getTokenMetadata(params: any): Promise<any> {
    const { mintAddress } = params;

    const metadata = await heliusService.getTokenMetadata(mintAddress);

    if (!metadata) {
      return {
        success: false,
        error: 'Token metadata not found',
      };
    }

    return {
      success: true,
      metadata,
    };
  }

  private async getNFTs(params: any): Promise<any> {
    const { address, limit = 100 } = params;

    const nfts = await heliusService.getNFTsByOwner(address, limit);

    return {
      success: true,
      nfts,
      count: nfts.length,
    };
  }

  // NFT Action Handlers
  private getNFTActions(): Action[] {
    return [
      {
        name: 'get_user_nfts',
        description: 'Get NFTs owned by the user',
        parameters: [
          {
            name: 'limit',
            type: 'number',
            description: 'Number of NFTs to retrieve (default: 100)',
            required: false,
            default: 100,
          },
        ],
        examples: [
          {
            description: 'Get user NFTs',
            input: { limit: 50 },
            output: { success: true, nfts: [], count: 0 },
          },
        ],
        handler: async (_params, context) => this.getUserNFTsAction(context),
      },
      {
        name: 'get_nft_metadata',
        description: 'Get detailed metadata for a specific NFT',
        parameters: [
          {
            name: 'mintAddress',
            type: 'string',
            description: 'NFT mint address',
            required: true,
          },
        ],
        examples: [
          {
            description: 'Get NFT metadata',
            input: { mintAddress: 'ABC...XYZ' },
            output: { success: true, metadata: {} },
          },
        ],
        handler: async (params, _context) => this.getNFTMetadataAction(params),
      },
      {
        name: 'get_nft_portfolio_value',
        description: 'Get total value of user NFT portfolio',
        parameters: [],
        examples: [
          {
            description: 'Get portfolio value',
            input: {},
            output: { success: true, totalValue: 10.5, nftCount: 25 },
          },
        ],
        handler: async (_params, context) => this.getNFTPortfolioValue(context),
      },
    ];
  }

  private async getUserNFTsAction(context: ActionContext): Promise<any> {
    if (!context.userId) {
      throw new Error('User ID required');
    }

    const nfts = await nftService.getUserNFTs(context.userId);

    return {
      success: true,
      nfts,
      count: nfts.length,
    };
  }

  private async getNFTMetadataAction(params: any): Promise<any> {
    const { mintAddress } = params;

    const metadata = await nftService.getNFTMetadata(mintAddress);

    return {
      success: true,
      metadata,
    };
  }

  private async getNFTPortfolioValue(context: ActionContext): Promise<any> {
    if (!context.userId) {
      throw new Error('User ID required');
    }

    const portfolio = await nftService.getPortfolioValue(context.userId);

    return {
      success: true,
      ...portfolio,
    };
  }
}

export default new SolanaAgentService();
