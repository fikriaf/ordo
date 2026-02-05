/**
 * Token Risk Scoring Service
 * Integrates with Range Protocol Market Score API v1.8
 * Provides risk assessment for Solana tokens
 */

import logger from '../config/logger';
import supabase from '../config/database';

interface RangeProtocolScore {
  address: string;
  marketScore: number;
  riskScore: number;
  liquidityScore: number;
  limitingFactors: string[];
  lastUpdated: string;
}

interface TokenScore {
  id?: string;
  token_address: string;
  market_score: number;
  risk_score: number;
  liquidity_score: number;
  limiting_factors: string[];
  last_fetched: string;
  created_at?: string;
  updated_at?: string;
}

export class TokenRiskService {
  // private readonly RANGE_API_URL = 'https://api.range.org/v1.8'; // For future use
  private readonly CACHE_TTL_HOURS = 1;
  private readonly HIGH_RISK_THRESHOLD = 70;

  /**
   * Get token risk score (with caching)
   */
  async getTokenRiskScore(tokenAddress: string): Promise<TokenScore> {
    try {
      logger.info('Getting token risk score', { tokenAddress });

      // Check cache first
      const cached = await this.getCachedScore(tokenAddress);
      if (cached && this.isCacheValid(cached.last_fetched)) {
        logger.info('Returning cached risk score', { tokenAddress });
        return cached;
      }

      // Fetch from Range Protocol API
      const score = await this.fetchFromRangeProtocol(tokenAddress);

      // Save to cache
      await this.saveScore(score);

      return score;
    } catch (error: any) {
      logger.error('Failed to get token risk score:', error);
      
      // Return cached score even if expired, if available
      const cached = await this.getCachedScore(tokenAddress);
      if (cached) {
        logger.warn('Returning expired cached score due to API error', { tokenAddress });
        return cached;
      }

      throw new Error(`Failed to get token risk score: ${error.message}`);
    }
  }

  /**
   * Fetch score from Range Protocol API
   */
  private async fetchFromRangeProtocol(tokenAddress: string): Promise<TokenScore> {
    try {
      logger.info('Fetching from Range Protocol API', { tokenAddress });

      // Note: This is a mock implementation
      // In production, replace with actual Range Protocol API call
      const response = await this.mockRangeProtocolAPI(tokenAddress);

      const score: TokenScore = {
        token_address: tokenAddress,
        market_score: response.marketScore,
        risk_score: response.riskScore,
        liquidity_score: response.liquidityScore,
        limiting_factors: response.limitingFactors,
        last_fetched: new Date().toISOString(),
      };

      logger.info('Fetched risk score from Range Protocol', {
        tokenAddress,
        riskScore: score.risk_score,
      });

      return score;
    } catch (error: any) {
      logger.error('Range Protocol API error:', error);
      throw new Error(`Range Protocol API error: ${error.message}`);
    }
  }

  /**
   * Mock Range Protocol API (replace with real API in production)
   */
  private async mockRangeProtocolAPI(tokenAddress: string): Promise<RangeProtocolScore> {
    // Simulate API delay
    await new Promise(resolve => setTimeout(resolve, 100));

    // Generate mock scores based on token address
    const hash = tokenAddress.split('').reduce((acc, char) => acc + char.charCodeAt(0), 0);
    const riskScore = (hash % 100);
    const marketScore = Math.min(100, riskScore + 10);
    const liquidityScore = Math.max(0, 100 - riskScore);

    const limitingFactors: string[] = [];
    if (riskScore > 70) {
      limitingFactors.push('High volatility');
      limitingFactors.push('Low liquidity');
    }
    if (liquidityScore < 30) {
      limitingFactors.push('Limited market depth');
    }
    if (marketScore < 50) {
      limitingFactors.push('Unverified token');
    }

    return {
      address: tokenAddress,
      marketScore,
      riskScore,
      liquidityScore,
      limitingFactors,
      lastUpdated: new Date().toISOString(),
    };
  }

  /**
   * Get cached score from database
   */
  private async getCachedScore(tokenAddress: string): Promise<TokenScore | null> {
    try {
      const { data, error } = await supabase
        .from('token_scores')
        .select('*')
        .eq('token_address', tokenAddress)
        .single();

      if (error) {
        if (error.code === 'PGRST116') {
          // No rows returned
          return null;
        }
        throw error;
      }

      return data;
    } catch (error: any) {
      logger.error('Failed to get cached score:', error);
      return null;
    }
  }

  /**
   * Check if cached score is still valid
   */
  private isCacheValid(lastFetched: string): boolean {
    const fetchedTime = new Date(lastFetched).getTime();
    const now = Date.now();
    const ageHours = (now - fetchedTime) / (1000 * 60 * 60);

    return ageHours < this.CACHE_TTL_HOURS;
  }

  /**
   * Save score to database
   */
  private async saveScore(score: TokenScore): Promise<void> {
    try {
      const { error } = await supabase
        .from('token_scores')
        .upsert({
          token_address: score.token_address,
          market_score: score.market_score,
          risk_score: score.risk_score,
          liquidity_score: score.liquidity_score,
          limiting_factors: score.limiting_factors,
          last_fetched: score.last_fetched,
          updated_at: new Date().toISOString(),
        }, {
          onConflict: 'token_address',
        });

      if (error) {
        throw error;
      }

      logger.info('Saved token score to cache', { tokenAddress: score.token_address });
    } catch (error: any) {
      logger.error('Failed to save token score:', error);
      // Don't throw - caching failure shouldn't break the flow
    }
  }

  /**
   * Check if token is high-risk
   */
  isHighRisk(riskScore: number): boolean {
    return riskScore > this.HIGH_RISK_THRESHOLD;
  }

  /**
   * Analyze token and return detailed assessment
   */
  async analyzeToken(tokenAddress: string): Promise<{
    score: TokenScore;
    isHighRisk: boolean;
    recommendation: string;
    warnings: string[];
  }> {
    try {
      const score = await this.getTokenRiskScore(tokenAddress);
      const isHighRisk = this.isHighRisk(score.risk_score);

      const warnings: string[] = [];
      let recommendation = '';

      if (isHighRisk) {
        recommendation = 'High risk - Exercise extreme caution';
        warnings.push('This token has a high risk score');
        warnings.push('Consider smaller position sizes');
        warnings.push('Approval required for transactions');
      } else if (score.risk_score > 50) {
        recommendation = 'Moderate risk - Proceed with caution';
        warnings.push('This token has moderate risk');
        warnings.push('Review limiting factors before trading');
      } else {
        recommendation = 'Low risk - Generally safe to trade';
      }

      // Add limiting factor warnings
      if (score.limiting_factors && score.limiting_factors.length > 0) {
        warnings.push(...score.limiting_factors.map(f => `Limiting factor: ${f}`));
      }

      return {
        score,
        isHighRisk,
        recommendation,
        warnings,
      };
    } catch (error: any) {
      logger.error('Token analysis failed:', error);
      throw error;
    }
  }

  /**
   * Search tokens by address pattern
   */
  async searchTokens(query: string, limit: number = 10): Promise<TokenScore[]> {
    try {
      const { data, error } = await supabase
        .from('token_scores')
        .select('*')
        .ilike('token_address', `%${query}%`)
        .order('risk_score', { ascending: true })
        .limit(limit);

      if (error) {
        throw error;
      }

      return data || [];
    } catch (error: any) {
      logger.error('Token search failed:', error);
      throw new Error(`Token search failed: ${error.message}`);
    }
  }

  /**
   * Get high-risk tokens
   */
  async getHighRiskTokens(limit: number = 20): Promise<TokenScore[]> {
    try {
      const { data, error } = await supabase
        .from('token_scores')
        .select('*')
        .gt('risk_score', this.HIGH_RISK_THRESHOLD)
        .order('risk_score', { ascending: false })
        .limit(limit);

      if (error) {
        throw error;
      }

      return data || [];
    } catch (error: any) {
      logger.error('Failed to get high-risk tokens:', error);
      throw new Error(`Failed to get high-risk tokens: ${error.message}`);
    }
  }

  /**
   * Refresh scores for multiple tokens (background job)
   */
  async refreshScores(tokenAddresses: string[]): Promise<void> {
    logger.info('Refreshing token scores', { count: tokenAddresses.length });

    for (const address of tokenAddresses) {
      try {
        // Force refresh by fetching from API
        const score = await this.fetchFromRangeProtocol(address);
        await this.saveScore(score);
      } catch (error: any) {
        logger.error('Failed to refresh score', { address, error: error.message });
        // Continue with next token
      }
    }

    logger.info('Token score refresh complete');
  }

  /**
   * Get tokens that need refresh (older than cache TTL)
   */
  async getTokensNeedingRefresh(limit: number = 50): Promise<string[]> {
    try {
      const cutoffTime = new Date(Date.now() - this.CACHE_TTL_HOURS * 60 * 60 * 1000);

      const { data, error } = await supabase
        .from('token_scores')
        .select('token_address')
        .lt('last_fetched', cutoffTime.toISOString())
        .limit(limit);

      if (error) {
        throw error;
      }

      return data?.map(row => row.token_address) || [];
    } catch (error: any) {
      logger.error('Failed to get tokens needing refresh:', error);
      return [];
    }
  }
}

export default new TokenRiskService();
