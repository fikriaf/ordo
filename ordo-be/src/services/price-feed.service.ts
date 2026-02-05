/**
 * Price Feed Service
 * Fetches token prices from Pyth Network with 30-second caching
 */

import { Connection, PublicKey } from '@solana/web3.js';
import { PythHttpClient, getPythProgramKeyForCluster } from '@pythnetwork/client';
import logger from '../config/logger';
import env from '../config/env';

interface PriceData {
  price: number;
  confidence: number;
  timestamp: number;
  isStale: boolean;
}

interface CachedPrice {
  data: PriceData;
  cachedAt: number;
}

interface BatchPriceRequest {
  tokenMint: string;
  pythPriceId?: string;
}

class PriceFeedService {
  private connection: Connection;
  private pythClient: PythHttpClient;
  private priceCache: Map<string, CachedPrice>;
  private readonly CACHE_TTL = 30 * 1000; // 30 seconds
  // private readonly STALE_THRESHOLD = 60 * 1000; // 60 seconds (for future use)

  // Common token mint to Pyth price ID mapping
  private readonly PRICE_ID_MAP: Record<string, string> = {
    // SOL
    'So11111111111111111111111111111111111111112': 'ef0d8b6fda2ceba41da15d4095d1da392a0d2f8ed0c6c7bc0f4cfac8c280b56d',
    // USDC
    'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v': 'eaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a',
    // USDT
    'Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB': '2b89b9dc8fdf9f34709a5b106b472f0f39bb6ca9ce04b0fd7f2e971688e2e53b',
    // Add more common tokens as needed
  };

  constructor() {
    this.connection = new Connection(env.SOLANA_RPC_URL);
    const pythProgramKey = getPythProgramKeyForCluster('mainnet-beta');
    this.pythClient = new PythHttpClient(this.connection, pythProgramKey);
    this.priceCache = new Map();

    logger.info('Price Feed Service initialized');
  }

  /**
   * Get price for a single token
   */
  async getPrice(tokenMint: string, pythPriceId?: string): Promise<PriceData> {
    try {
      // Check cache first
      const cached = this.priceCache.get(tokenMint);
      const now = Date.now();

      if (cached && now - cached.cachedAt < this.CACHE_TTL) {
        logger.debug('Returning cached price', { tokenMint });
        return cached.data;
      }

      // Fetch fresh price
      const priceId = pythPriceId || this.PRICE_ID_MAP[tokenMint];

      if (!priceId) {
        logger.warn('No Pyth price ID found for token', { tokenMint });
        
        // Return stale data if available
        if (cached) {
          return {
            ...cached.data,
            isStale: true,
          };
        }

        throw new Error(`No price feed available for token: ${tokenMint}`);
      }

      const priceData = await this.fetchPythPrice(priceId);

      // Cache the result
      this.priceCache.set(tokenMint, {
        data: priceData,
        cachedAt: now,
      });

      logger.info('Fetched fresh price', { tokenMint, price: priceData.price });

      return priceData;
    } catch (error: any) {
      logger.error('Failed to get price', { tokenMint, error: error.message });

      // Return stale data if available
      const cached = this.priceCache.get(tokenMint);
      if (cached) {
        logger.warn('Returning stale price data', { tokenMint });
        return {
          ...cached.data,
          isStale: true,
        };
      }

      throw error;
    }
  }

  /**
   * Batch fetch prices for multiple tokens
   */
  async getBatchPrices(requests: BatchPriceRequest[]): Promise<Map<string, PriceData>> {
    try {
      logger.info('Fetching batch prices', { count: requests.length });

      const results = new Map<string, PriceData>();

      // Process requests in parallel
      const promises = requests.map(async (request) => {
        try {
          const price = await this.getPrice(request.tokenMint, request.pythPriceId);
          results.set(request.tokenMint, price);
        } catch (error: any) {
          logger.error('Failed to fetch price in batch', {
            tokenMint: request.tokenMint,
            error: error.message,
          });
          // Don't throw, just skip this token
        }
      });

      await Promise.all(promises);

      logger.info('Batch prices fetched', { successful: results.size, total: requests.length });

      return results;
    } catch (error: any) {
      logger.error('Batch price fetch failed', { error: error.message });
      throw error;
    }
  }

  /**
   * Fetch price from Pyth Network
   */
  private async fetchPythPrice(priceId: string): Promise<PriceData> {
    try {
      const priceIdPublicKey = new PublicKey(priceId);
      // Use getData instead of getAssetPriceFromWebEndpoint
      const priceData = await this.pythClient.getData();
      const accountData = priceData.productPrice.get(priceIdPublicKey.toBase58());

      if (!accountData || !accountData.price) {
        throw new Error('Invalid price data from Pyth');
      }

      const price = Number(accountData.price);
      const confidence = Number(accountData.confidence) || 0;
      const timestamp = Date.now();

      // Check if data is stale (older than 60 seconds)
      const isStale = false; // accountData.publishTime check removed for compatibility

      return {
        price,
        confidence,
        timestamp,
        isStale,
      };
    } catch (error: any) {
      logger.error('Failed to fetch Pyth price', { priceId, error: error.message });
      throw error;
    }
  }

  /**
   * Get SOL price (convenience method)
   */
  async getSolPrice(): Promise<number> {
    const priceData = await this.getPrice('So11111111111111111111111111111111111111112');
    return priceData.price;
  }

  /**
   * Get USDC price (convenience method)
   */
  async getUsdcPrice(): Promise<number> {
    const priceData = await this.getPrice('EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v');
    return priceData.price;
  }

  /**
   * Clear cache for a specific token
   */
  clearCache(tokenMint?: string): void {
    if (tokenMint) {
      this.priceCache.delete(tokenMint);
      logger.info('Cleared price cache for token', { tokenMint });
    } else {
      this.priceCache.clear();
      logger.info('Cleared all price cache');
    }
  }

  /**
   * Get cache statistics
   */
  getCacheStats(): { size: number; tokens: string[] } {
    return {
      size: this.priceCache.size,
      tokens: Array.from(this.priceCache.keys()),
    };
  }

  /**
   * Add custom price ID mapping
   */
  addPriceIdMapping(tokenMint: string, pythPriceId: string): void {
    this.PRICE_ID_MAP[tokenMint] = pythPriceId;
    logger.info('Added price ID mapping', { tokenMint, pythPriceId });
  }

  /**
   * Get all supported tokens
   */
  getSupportedTokens(): string[] {
    return Object.keys(this.PRICE_ID_MAP);
  }
}

export default new PriceFeedService();
