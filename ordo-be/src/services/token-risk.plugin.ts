/**
 * Token Risk Scoring Plugin
 * Provides AI agent actions for token risk assessment
 */

import { Plugin, Action, ActionContext } from '../types/plugin';
import tokenRiskService from './token-risk.service';
import logger from '../config/logger';

/**
 * Get token risk score action
 */
const getTokenRiskAction: Action = {
  name: 'get_token_risk',
  description: 'Get risk score for a Solana token (0-100, higher = riskier). Scores above 70 are high-risk and require approval.',
  parameters: [
    {
      name: 'tokenAddress',
      type: 'string',
      description: 'Solana token mint address',
      required: true,
    },
  ],
  handler: async (params, _context: ActionContext) => {
    try {
      const { tokenAddress } = params;

      if (!tokenAddress) {
        throw new Error('tokenAddress is required');
      }

      const score = await tokenRiskService.getTokenRiskScore(tokenAddress);

      return {
        success: true,
        data: {
          tokenAddress: score.token_address,
          marketScore: score.market_score,
          riskScore: score.risk_score,
          liquidityScore: score.liquidity_score,
          limitingFactors: score.limiting_factors,
          isHighRisk: tokenRiskService.isHighRisk(score.risk_score),
          lastFetched: score.last_fetched,
        },
        message: `Risk score: ${score.risk_score}/100 ${tokenRiskService.isHighRisk(score.risk_score) ? '⚠️ HIGH RISK' : '✓ Low-Medium Risk'}`,
      };
    } catch (error: any) {
      logger.error('Get token risk action failed:', error);
      return {
        success: false,
        error: error.message || 'Failed to get token risk score',
      };
    }
  },
};

/**
 * Analyze token action (detailed assessment)
 */
const analyzeTokenAction: Action = {
  name: 'analyze_token_risk',
  description: 'Get detailed risk analysis for a token including recommendations and warnings',
  parameters: [
    {
      name: 'tokenAddress',
      type: 'string',
      description: 'Solana token mint address',
      required: true,
    },
  ],
  handler: async (params, _context: ActionContext) => {
    try {
      const { tokenAddress } = params;

      if (!tokenAddress) {
        throw new Error('tokenAddress is required');
      }

      const analysis = await tokenRiskService.analyzeToken(tokenAddress);

      return {
        success: true,
        data: {
          tokenAddress: analysis.score.token_address,
          riskScore: analysis.score.risk_score,
          marketScore: analysis.score.market_score,
          liquidityScore: analysis.score.liquidity_score,
          isHighRisk: analysis.isHighRisk,
          recommendation: analysis.recommendation,
          warnings: analysis.warnings,
          limitingFactors: analysis.score.limiting_factors,
        },
        message: `${analysis.recommendation}\n${analysis.warnings.length > 0 ? '\nWarnings:\n' + analysis.warnings.map(w => `- ${w}`).join('\n') : ''}`,
      };
    } catch (error: any) {
      logger.error('Analyze token action failed:', error);
      return {
        success: false,
        error: error.message || 'Failed to analyze token',
      };
    }
  },
};

/**
 * Search high-risk tokens action
 */
const getHighRiskTokensAction: Action = {
  name: 'get_high_risk_tokens',
  description: 'Get list of high-risk tokens (risk score > 70) to warn users about',
  parameters: [
    {
      name: 'limit',
      type: 'number',
      description: 'Maximum number of tokens to return (default: 10)',
      required: false,
    },
  ],
  handler: async (params, _context: ActionContext) => {
    try {
      const limit = params.limit || 10;

      const tokens = await tokenRiskService.getHighRiskTokens(limit);

      return {
        success: true,
        data: {
          tokens: tokens.map(t => ({
            address: t.token_address,
            riskScore: t.risk_score,
            limitingFactors: t.limiting_factors,
          })),
          count: tokens.length,
        },
        message: `Found ${tokens.length} high-risk tokens. These tokens require approval for transactions.`,
      };
    } catch (error: any) {
      logger.error('Get high-risk tokens action failed:', error);
      return {
        success: false,
        error: error.message || 'Failed to get high-risk tokens',
      };
    }
  },
};

/**
 * Token Risk Plugin
 */
const tokenRiskPlugin: Plugin = {
  id: 'token-risk-scoring',
  name: 'Token Risk Scoring',
  version: '1.0.0',
  description: 'Token risk assessment via Range Protocol API. Helps users make informed trading decisions.',
  isEnabled: true,
  actions: [
    getTokenRiskAction,
    analyzeTokenAction,
    getHighRiskTokensAction,
  ],
};

export default tokenRiskPlugin;
