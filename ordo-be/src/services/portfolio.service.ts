/**
 * Portfolio Service
 * Multi-chain portfolio aggregation and analytics
 */

import supabase from '../config/database';
import logger from '../config/logger';
import walletService from './wallet.service';
import evmWalletService from './evm-wallet.service';
import birdeyeService from './birdeye.service';
import nftService from './nft.service';

interface PortfolioSummary {
  totalValueUsd: number;
  solana: {
    sol: number;
    tokens: Array<{
      mint: string;
      symbol: string;
      amount: number;
      valueUsd: number;
    }>;
    nfts: {
      count: number;
      estimatedValueSol: number;
    };
  };
  evm: {
    chains: Array<{
      chainId: number;
      chainName: string;
      native: {
        symbol: string;
        amount: number;
        valueUsd: number;
      };
      tokens: Array<{
        address: string;
        symbol: string;
        amount: number;
        valueUsd: number;
      }>;
    }>;
  };
  lastUpdated: string;
}

interface PerformanceMetrics {
  totalValueUsd: number;
  change24h: {
    absolute: number;
    percentage: number;
  };
  change7d: {
    absolute: number;
    percentage: number;
  };
  topGainers: Array<{
    symbol: string;
    changePercentage: number;
  }>;
  topLosers: Array<{
    symbol: string;
    changePercentage: number;
  }>;
}

class PortfolioService {
  /**
   * Get portfolio summary
   */
  async getPortfolioSummary(userId: string): Promise<PortfolioSummary> {
    try {
      logger.info('Getting portfolio summary', { userId });

      // Get Solana wallets
      const { data: solanaWallets } = await supabase
        .from('wallets')
        .select('*')
        .eq('user_id', userId)
        .eq('is_primary', true);

      // Get EVM wallets
      const { data: evmWallets } = await supabase
        .from('evm_wallets')
        .select('*')
        .eq('user_id', userId);

      let totalValueUsd = 0;

      // Aggregate Solana portfolio
      const solanaPortfolio = {
        sol: 0,
        tokens: [] as any[],
        nfts: {
          count: 0,
          estimatedValueSol: 0,
        },
      };

      if (solanaWallets && solanaWallets.length > 0) {
        const wallet = solanaWallets[0];
        const balance = await walletService.getWalletBalance(wallet.id);

        solanaPortfolio.sol = balance.sol;

        // Get SOL price
        const solPrice = await birdeyeService.getTokenPrice(
          'So11111111111111111111111111111111111111112'
        );
        const solPriceUsd = solPrice?.value || 0;

        totalValueUsd += balance.sol * solPriceUsd;

        // Get token prices
        if (balance.tokens && balance.tokens.length > 0) {
          const tokenAddresses = balance.tokens.map((t: any) => t.mint);
          const prices = await birdeyeService.getMultipleTokenPrices(tokenAddresses);

          for (const token of balance.tokens) {
            const price = prices[token.mint] || 0;
            const valueUsd = token.amount * price;

            solanaPortfolio.tokens.push({
              mint: token.mint,
              symbol: token.symbol || 'UNKNOWN',
              amount: token.amount,
              valueUsd,
            });

            totalValueUsd += valueUsd;
          }
        }

        // Get NFT portfolio value
        const nftPortfolio = await nftService.getPortfolioValue(userId);
        solanaPortfolio.nfts = {
          count: nftPortfolio.nftCount,
          estimatedValueSol: nftPortfolio.totalValue,
        };

        totalValueUsd += nftPortfolio.totalValue * solPriceUsd;
      }

      // Aggregate EVM portfolio
      const evmPortfolio = {
        chains: [] as any[],
      };

      if (evmWallets && evmWallets.length > 0) {
        for (const wallet of evmWallets) {
          try {
            const balance = await evmWalletService.getWalletBalance(wallet.id);

            const chainData = {
              chainId: wallet.chain_id,
              chainName: this.getChainName(wallet.chain_id),
              native: {
                symbol: this.getNativeSymbol(wallet.chain_id),
                amount: balance.native,
                valueUsd: 0, // TODO: Get native token price
              },
              tokens: balance.tokens.map((t: any) => ({
                address: t.address,
                symbol: t.symbol,
                amount: t.amount,
                valueUsd: 0, // TODO: Get token prices
              })),
            };

            evmPortfolio.chains.push(chainData);
          } catch (error) {
            logger.error('Failed to get EVM wallet balance:', { walletId: wallet.id, error });
          }
        }
      }

      const summary: PortfolioSummary = {
        totalValueUsd,
        solana: solanaPortfolio,
        evm: evmPortfolio,
        lastUpdated: new Date().toISOString(),
      };

      logger.info('Portfolio summary retrieved', { userId, totalValueUsd });

      return summary;
    } catch (error: any) {
      logger.error('Failed to get portfolio summary:', error);
      throw error;
    }
  }

  /**
   * Get performance metrics
   */
  async getPerformanceMetrics(userId: string): Promise<PerformanceMetrics> {
    try {
      logger.info('Getting performance metrics', { userId });

      // Get current portfolio value
      const summary = await this.getPortfolioSummary(userId);
      const currentValue = summary.totalValueUsd;

      // TODO: Implement historical value tracking
      // For now, return mock data
      const metrics: PerformanceMetrics = {
        totalValueUsd: currentValue,
        change24h: {
          absolute: 0,
          percentage: 0,
        },
        change7d: {
          absolute: 0,
          percentage: 0,
        },
        topGainers: [],
        topLosers: [],
      };

      logger.info('Performance metrics retrieved', { userId });

      return metrics;
    } catch (error: any) {
      logger.error('Failed to get performance metrics:', error);
      throw error;
    }
  }

  /**
   * Get chain name by ID
   */
  private getChainName(chainId: number): string {
    const chains: Record<number, string> = {
      1: 'Ethereum',
      137: 'Polygon',
      56: 'BSC',
      42161: 'Arbitrum',
      10: 'Optimism',
      43114: 'Avalanche',
    };

    return chains[chainId] || `Chain ${chainId}`;
  }

  /**
   * Get native token symbol by chain ID
   */
  private getNativeSymbol(chainId: number): string {
    const symbols: Record<number, string> = {
      1: 'ETH',
      137: 'MATIC',
      56: 'BNB',
      42161: 'ETH',
      10: 'ETH',
      43114: 'AVAX',
    };

    return symbols[chainId] || 'NATIVE';
  }
}

export default new PortfolioService();
