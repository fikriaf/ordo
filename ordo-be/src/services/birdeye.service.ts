/**
 * Birdeye Service
 * Market data and analytics via Birdeye API
 */

import axios from 'axios';
import env from '../config/env';
import logger from '../config/logger';

const BIRDEYE_API_KEY = env.BIRDEYE_API_KEY || '';
const BIRDEYE_API_URL = 'https://public-api.birdeye.so';

interface TokenPrice {
  address: string;
  value: number;
  updateUnixTime: number;
  updateHumanTime: string;
}

interface TokenMarketData {
  address: string;
  symbol: string;
  name: string;
  price: number;
  priceChange24h: number;
  volume24h: number;
  liquidity: number;
  marketCap: number;
  holder: number;
}

interface TrendingToken {
  address: string;
  symbol: string;
  name: string;
  price: number;
  priceChange24h: number;
  volume24h: number;
  rank: number;
}

interface PriceHistory {
  address: string;
  items: Array<{
    unixTime: number;
    value: number;
  }>;
}

interface CacheEntry<T> {
  data: T;
  timestamp: number;
  ttl: number;
}

class BirdeyeService {
  private cache: Map<string, CacheEntry<any>>;

  // Cache TTLs (in milliseconds)
  private readonly PRICE_CACHE_TTL = 60 * 1000; // 1 minute
  private readonly MARKET_DATA_CACHE_TTL = 5 * 60 * 1000; // 5 minutes
  private readonly HISTORY_CACHE_TTL = 5 * 60 * 1000; // 5 minutes

  constructor() {
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
      logger.debug('Birdeye cache hit', { key });
      return cached.data as T;
    }

    logger.debug('Birdeye cache miss', { key });
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
      logger.debug('Birdeye cache cleanup completed', { cleaned, remaining: this.cache.size });
    }
  }

  /**
   * Clear all cache
   */
  clearCache(): void {
    this.cache.clear();
    logger.info('Birdeye cache cleared');
  }

  /**
   * Get token price
   */
  async getTokenPrice(tokenAddress: string): Promise<TokenPrice | null> {
    const cacheKey = `price:${tokenAddress}`;

    return this.getCached(cacheKey, this.PRICE_CACHE_TTL, async () => {
      try {
        if (!BIRDEYE_API_KEY) {
          throw new Error('Birdeye API key not configured');
        }

        logger.info('Getting token price from Birdeye', { tokenAddress });

        const response = await axios.get(
          `${BIRDEYE_API_URL}/defi/price`,
          {
            params: {
              address: tokenAddress,
            },
            headers: {
              'X-API-KEY': BIRDEYE_API_KEY,
            },
          }
        );

        if (!response.data.success) {
          logger.warn('Birdeye API returned unsuccessful response', { tokenAddress });
          return null;
        }

        return response.data.data;
      } catch (error: any) {
        logger.error('Failed to get token price from Birdeye:', {
          message: error.message,
          status: error.response?.status,
        });
        return null;
      }
    });
  }

  /**
   * Get token market data
   */
  async getTokenMarketData(tokenAddress: string): Promise<TokenMarketData | null> {
    const cacheKey = `market:${tokenAddress}`;

    return this.getCached(cacheKey, this.MARKET_DATA_CACHE_TTL, async () => {
      try {
        if (!BIRDEYE_API_KEY) {
          throw new Error('Birdeye API key not configured');
        }

        logger.info('Getting token market data from Birdeye', { tokenAddress });

        const response = await axios.get(
          `${BIRDEYE_API_URL}/defi/token_overview`,
          {
            params: {
              address: tokenAddress,
            },
            headers: {
              'X-API-KEY': BIRDEYE_API_KEY,
            },
          }
        );

        if (!response.data.success) {
          logger.warn('Birdeye API returned unsuccessful response', { tokenAddress });
          return null;
        }

        return response.data.data;
      } catch (error: any) {
        logger.error('Failed to get token market data from Birdeye:', {
          message: error.message,
          status: error.response?.status,
        });
        return null;
      }
    });
  }

  /**
   * Get trending tokens
   */
  async getTrendingTokens(limit: number = 20): Promise<TrendingToken[]> {
    const cacheKey = `trending:${limit}`;

    return this.getCached(cacheKey, this.MARKET_DATA_CACHE_TTL, async () => {
      try {
        if (!BIRDEYE_API_KEY) {
          throw new Error('Birdeye API key not configured');
        }

        logger.info('Getting trending tokens from Birdeye', { limit });

        const response = await axios.get(
          `${BIRDEYE_API_URL}/defi/trending_tokens`,
          {
            params: {
              sort_by: 'volume24hUSD',
              sort_type: 'desc',
              offset: 0,
              limit,
            },
            headers: {
              'X-API-KEY': BIRDEYE_API_KEY,
            },
          }
        );

        if (!response.data.success) {
          logger.warn('Birdeye API returned unsuccessful response');
          return [];
        }

        return response.data.data.items || [];
      } catch (error: any) {
        logger.error('Failed to get trending tokens from Birdeye:', {
          message: error.message,
          status: error.response?.status,
        });
        return [];
      }
    });
  }

  /**
   * Get price history
   */
  async getPriceHistory(
    tokenAddress: string,
    timeframe: '1H' | '4H' | '1D' | '1W' | '1M' = '1D'
  ): Promise<PriceHistory | null> {
    const cacheKey = `history:${tokenAddress}:${timeframe}`;

    return this.getCached(cacheKey, this.HISTORY_CACHE_TTL, async () => {
      try {
        if (!BIRDEYE_API_KEY) {
          throw new Error('Birdeye API key not configured');
        }

        logger.info('Getting price history from Birdeye', { tokenAddress, timeframe });

        const response = await axios.get(
          `${BIRDEYE_API_URL}/defi/history_price`,
          {
            params: {
              address: tokenAddress,
              address_type: 'token',
              type: timeframe,
            },
            headers: {
              'X-API-KEY': BIRDEYE_API_KEY,
            },
          }
        );

        if (!response.data.success) {
          logger.warn('Birdeye API returned unsuccessful response', { tokenAddress });
          return null;
        }

        return {
          address: tokenAddress,
          items: response.data.data.items || [],
        };
      } catch (error: any) {
        logger.error('Failed to get price history from Birdeye:', {
          message: error.message,
          status: error.response?.status,
        });
        return null;
      }
    });
  }

  /**
   * Get multiple token prices
   */
  async getMultipleTokenPrices(tokenAddresses: string[]): Promise<Record<string, number>> {
    try {
      if (!BIRDEYE_API_KEY) {
        throw new Error('Birdeye API key not configured');
      }

      logger.info('Getting multiple token prices from Birdeye', { count: tokenAddresses.length });

      const response = await axios.get(
        `${BIRDEYE_API_URL}/defi/multi_price`,
        {
          params: {
            list_address: tokenAddresses.join(','),
          },
          headers: {
            'X-API-KEY': BIRDEYE_API_KEY,
          },
        }
      );

      if (!response.data.success) {
        logger.warn('Birdeye API returned unsuccessful response');
        return {};
      }

      const prices: Record<string, number> = {};
      const data = response.data.data;

      for (const address of tokenAddresses) {
        if (data[address]) {
          prices[address] = data[address].value;
        }
      }

      return prices;
    } catch (error: any) {
      logger.error('Failed to get multiple token prices from Birdeye:', {
        message: error.message,
        status: error.response?.status,
      });
      return {};
    }
  }
}

export default new BirdeyeService();
