/**
 * Helius Service
 * Enhanced Solana data via Helius API
 */

import axios from 'axios';
import { Connection, PublicKey } from '@solana/web3.js';
import env from '../config/env';
import logger from '../config/logger';

const HELIUS_API_KEY = env.HELIUS_API_KEY || '';
const HELIUS_RPC_URL = `https://mainnet.helius-rpc.com/?api-key=${HELIUS_API_KEY}`;
const HELIUS_API_URL = 'https://api.helius.xyz/v0';

interface EnhancedTransaction {
  signature: string;
  timestamp: number;
  type: string;
  source: string;
  fee: number;
  feePayer: string;
  nativeTransfers?: any[];
  tokenTransfers?: any[];
  accountData?: any[];
  events?: any;
}

interface TokenMetadata {
  account: string;
  onChainAccountInfo: any;
  onChainMetadata: any;
  offChainMetadata: any;
  legacyMetadata: any;
}

interface CacheEntry<T> {
  data: T;
  timestamp: number;
  ttl: number;
}

export class HeliusService {
  private connection: Connection;
  private cache: Map<string, CacheEntry<any>>;

  // Cache TTLs (in milliseconds)
  private readonly TRANSACTION_CACHE_TTL = 5 * 60 * 1000; // 5 minutes
  private readonly METADATA_CACHE_TTL = 60 * 60 * 1000; // 1 hour
  private readonly NFT_CACHE_TTL = 10 * 60 * 1000; // 10 minutes

  constructor() {
    this.connection = new Connection(HELIUS_RPC_URL, 'confirmed');
    this.cache = new Map();

    // Clean up expired cache entries every 5 minutes
    setInterval(() => this.cleanupCache(), 5 * 60 * 1000);
  }

  /**
   * Get cached data or fetch if expired
   */
  private async getCached<T>(
    key: string,
    ttl: number,
    fetchFn: () => Promise<T>
  ): Promise<T> {
    const cached = this.cache.get(key);
    const now = Date.now();

    if (cached && now - cached.timestamp < cached.ttl) {
      logger.debug('Cache hit', { key });
      return cached.data as T;
    }

    logger.debug('Cache miss', { key });
    const data = await fetchFn();

    this.cache.set(key, {
      data,
      timestamp: now,
      ttl,
    });

    return data;
  }

  /**
   * Clean up expired cache entries
   */
  private cleanupCache(): void {
    const now = Date.now();
    let cleaned = 0;

    for (const [key, entry] of this.cache.entries()) {
      if (now - entry.timestamp >= entry.ttl) {
        this.cache.delete(key);
        cleaned++;
      }
    }

    if (cleaned > 0) {
      logger.debug('Cache cleanup completed', { cleaned, remaining: this.cache.size });
    }
  }

  /**
   * Clear all cache
   */
  clearCache(): void {
    this.cache.clear();
    logger.info('Cache cleared');
  }

  /**
   * Get enhanced transaction history
   */
  async getEnhancedTransactions(
    address: string,
    limit: number = 10
  ): Promise<EnhancedTransaction[]> {
    const cacheKey = `transactions:${address}:${limit}`;

    return this.getCached(cacheKey, this.TRANSACTION_CACHE_TTL, async () => {
      try {
        if (!HELIUS_API_KEY) {
          throw new Error('Helius API key not configured');
        }

        logger.info('Getting enhanced transactions from Helius', { address, limit });

        const response = await axios.get(
          `${HELIUS_API_URL}/addresses/${address}/transactions`,
          {
            params: {
              'api-key': HELIUS_API_KEY,
              limit,
            },
          }
        );

        const transactions = response.data;

        logger.info('Enhanced transactions retrieved', { count: transactions.length });

        return transactions;
      } catch (error: any) {
        logger.error('Failed to get enhanced transactions:', {
          message: error.message,
          status: error.response?.status,
        });
        throw new Error(`Failed to get enhanced transactions: ${error.message}`);
      }
    });
  }

  /**
   * Get parsed transaction by signature
   */
  async getParsedTransaction(signature: string): Promise<any> {
    try {
      if (!HELIUS_API_KEY) {
        throw new Error('Helius API key not configured');
      }

      logger.info('Getting parsed transaction', { signature });

      const response = await axios.post(
        HELIUS_RPC_URL,
        {
          jsonrpc: '2.0',
          id: 'helius-tx',
          method: 'getTransaction',
          params: [
            signature,
            {
              encoding: 'jsonParsed',
              maxSupportedTransactionVersion: 0,
            },
          ],
        }
      );

      return response.data.result;
    } catch (error: any) {
      logger.error('Failed to get parsed transaction:', {
        message: error.message,
        status: error.response?.status,
      });
      throw new Error(`Failed to get parsed transaction: ${error.message}`);
    }
  }

  /**
   * Get token metadata using DAS API
   */
  async getTokenMetadata(mintAddress: string): Promise<TokenMetadata | null> {
    const cacheKey = `metadata:${mintAddress}`;

    return this.getCached(cacheKey, this.METADATA_CACHE_TTL, async () => {
      try {
        if (!HELIUS_API_KEY) {
          throw new Error('Helius API key not configured');
        }

        logger.info('Getting token metadata', { mintAddress });

        const response = await axios.post(
          HELIUS_RPC_URL,
          {
            jsonrpc: '2.0',
            id: 'helius-metadata',
            method: 'getAsset',
            params: {
              id: mintAddress,
            },
          }
        );

        if (response.data.error) {
          logger.warn('Token metadata not found', { mintAddress });
          return null;
        }

        return response.data.result;
      } catch (error: any) {
        logger.error('Failed to get token metadata:', {
          message: error.message,
          status: error.response?.status,
        });
        return null;
      }
    });
  }

  /**
   * Get NFTs owned by address
   */
  async getNFTsByOwner(ownerAddress: string, limit: number = 100): Promise<any[]> {
    const cacheKey = `nfts:${ownerAddress}:${limit}`;

    return this.getCached(cacheKey, this.NFT_CACHE_TTL, async () => {
      try {
        if (!HELIUS_API_KEY) {
          throw new Error('Helius API key not configured');
        }

        logger.info('Getting NFTs by owner', { ownerAddress, limit });

        const response = await axios.post(
          HELIUS_RPC_URL,
          {
            jsonrpc: '2.0',
            id: 'helius-nfts',
            method: 'getAssetsByOwner',
            params: {
              ownerAddress,
              page: 1,
              limit,
            },
          }
        );

        const nfts = response.data.result?.items || [];

        logger.info('NFTs retrieved', { count: nfts.length });

        return nfts;
      } catch (error: any) {
        logger.error('Failed to get NFTs:', {
          message: error.message,
          status: error.response?.status,
        });
        throw new Error(`Failed to get NFTs: ${error.message}`);
      }
    });
  }

  /**
   * Get token balances with metadata
   */
  async getTokenBalancesWithMetadata(address: string): Promise<any[]> {
    try {
      if (!HELIUS_API_KEY) {
        throw new Error('Helius API key not configured');
      }

      logger.info('Getting token balances with metadata', { address });

      // Get token accounts
      const publicKey = new PublicKey(address);
      const tokenAccounts = await this.connection.getParsedTokenAccountsByOwner(
        publicKey,
        {
          programId: new PublicKey('TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA'),
        }
      );

      // Enrich with metadata
      const enrichedBalances = await Promise.all(
        tokenAccounts.value.map(async (account) => {
          const info = account.account.data.parsed.info;
          const metadata = await this.getTokenMetadata(info.mint);

          return {
            mint: info.mint,
            amount: info.tokenAmount.uiAmount,
            decimals: info.tokenAmount.decimals,
            metadata: metadata ? {
              name: metadata.onChainMetadata?.metadata?.name || 'Unknown',
              symbol: metadata.onChainMetadata?.metadata?.symbol || 'UNKNOWN',
              image: metadata.offChainMetadata?.metadata?.image || null,
            } : null,
          };
        })
      );

      logger.info('Token balances with metadata retrieved', {
        count: enrichedBalances.length,
      });

      return enrichedBalances;
    } catch (error: any) {
      logger.error('Failed to get token balances with metadata:', {
        message: error.message,
      });
      throw new Error(`Failed to get token balances: ${error.message}`);
    }
  }

  /**
   * Search assets by name/symbol
   */
  async searchAssets(query: string, limit: number = 20): Promise<any[]> {
    try {
      if (!HELIUS_API_KEY) {
        throw new Error('Helius API key not configured');
      }

      logger.info('Searching assets', { query, limit });

      const response = await axios.post(
        HELIUS_RPC_URL,
        {
          jsonrpc: '2.0',
          id: 'helius-search',
          method: 'searchAssets',
          params: {
            query,
            limit,
          },
        }
      );

      const assets = response.data.result?.items || [];

      logger.info('Assets found', { count: assets.length });

      return assets;
    } catch (error: any) {
      logger.error('Failed to search assets:', {
        message: error.message,
        status: error.response?.status,
      });
      throw new Error(`Failed to search assets: ${error.message}`);
    }
  }

  /**
   * Get address activity summary
   */
  async getAddressActivity(address: string): Promise<any> {
    try {
      if (!HELIUS_API_KEY) {
        throw new Error('Helius API key not configured');
      }

      logger.info('Getting address activity', { address });

      // Get recent transactions
      const transactions = await this.getEnhancedTransactions(address, 100);

      // Analyze activity
      const activity = {
        totalTransactions: transactions.length,
        types: {} as Record<string, number>,
        recentActivity: transactions.slice(0, 10),
        firstSeen: transactions.length > 0 ? transactions[transactions.length - 1].timestamp : null,
        lastSeen: transactions.length > 0 ? transactions[0].timestamp : null,
      };

      // Count transaction types
      transactions.forEach((tx) => {
        activity.types[tx.type] = (activity.types[tx.type] || 0) + 1;
      });

      logger.info('Address activity analyzed', { address });

      return activity;
    } catch (error: any) {
      logger.error('Failed to get address activity:', {
        message: error.message,
      });
      throw new Error(`Failed to get address activity: ${error.message}`);
    }
  }
}

export default new HeliusService();
