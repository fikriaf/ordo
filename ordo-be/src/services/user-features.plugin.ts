/**
 * User Features Plugin
 * Provides AI access to User Preferences, Approval Queue, and Token Risk features
 */

import { Plugin, Action } from '../types/plugin';
import userPreferencesService from './user-preferences.service';
import approvalService from './approval.service';
import tokenRiskService from './token-risk.service';
import logger from '../config/logger';

// =============================================
// USER PREFERENCES ACTIONS
// =============================================

const getUserPreferencesAction: Action = {
  name: 'get_user_preferences',
  description: 'Get user trading preferences and risk settings',
  parameters: [],
  examples: [
    {
      description: 'Get current preferences',
      input: {},
      output: { success: true, preferences: { max_single_transfer_sol: 1.0 } },
    },
  ],
  handler: async (_params, context) => {
    try {
      const preferences = await userPreferencesService.getUserPreferences(context.userId);
      return {
        success: true,
        preferences,
      };
    } catch (error: any) {
      logger.error('Get user preferences action error:', error);
      throw new Error(`Failed to get preferences: ${error.message}`);
    }
  },
};

const updateUserPreferencesAction: Action = {
  name: 'update_user_preferences',
  description: 'Update user trading preferences and risk settings',
  parameters: [
    {
      name: 'max_single_transfer_sol',
      type: 'number',
      description: 'Maximum SOL per single transfer',
      required: false,
    },
    {
      name: 'agent_autonomy_level',
      type: 'string',
      description: 'Agent autonomy level: low, medium, or high',
      required: false,
    },
    {
      name: 'default_slippage_bps',
      type: 'number',
      description: 'Default slippage in basis points',
      required: false,
    },
    {
      name: 'enable_auto_staking',
      type: 'boolean',
      description: 'Enable automatic staking',
      required: false,
    },
  ],
  examples: [
    {
      description: 'Update max transfer and autonomy',
      input: { max_single_transfer_sol: 5, agent_autonomy_level: 'high' },
      output: { success: true, message: 'Preferences updated' },
    },
  ],
  handler: async (params, context) => {
    try {
      const preferences = await userPreferencesService.updatePreferences(
        context.userId,
        params
      );
      return {
        success: true,
        preferences,
        message: 'Preferences updated successfully',
      };
    } catch (error: any) {
      logger.error('Update user preferences action error:', error);
      throw new Error(`Failed to update preferences: ${error.message}`);
    }
  },
};

// =============================================
// APPROVAL QUEUE ACTIONS
// =============================================

const getPendingApprovalsAction: Action = {
  name: 'get_pending_approvals',
  description: 'Get list of pending transaction approvals',
  parameters: [],
  examples: [
    {
      description: 'Get pending approvals',
      input: {},
      output: { success: true, approvals: [], count: 0 },
    },
  ],
  handler: async (_params, context) => {
    try {
      const approvals = await approvalService.getPendingApprovals(context.userId);
      return {
        success: true,
        approvals,
        count: approvals.length,
      };
    } catch (error: any) {
      logger.error('Get pending approvals action error:', error);
      throw new Error(`Failed to get pending approvals: ${error.message}`);
    }
  },
};

const getApprovalHistoryAction: Action = {
  name: 'get_approval_history',
  description: 'Get approval history with optional filters',
  parameters: [
    {
      name: 'status',
      type: 'string',
      description: 'Filter by status: pending, approved, rejected, expired',
      required: false,
    },
    {
      name: 'limit',
      type: 'number',
      description: 'Number of results to return (default 20)',
      required: false,
      default: 20,
    },
  ],
  examples: [
    {
      description: 'Get approval history',
      input: { limit: 10 },
      output: { success: true, approvals: [], total: 0 },
    },
  ],
  handler: async (params, context) => {
    try {
      const result = await approvalService.getApprovalHistory(
        context.userId,
        { status: params.status },
        { limit: params.limit || 20 }
      );
      return {
        success: true,
        approvals: result.approvals,
        total: result.total,
      };
    } catch (error: any) {
      logger.error('Get approval history action error:', error);
      throw new Error(`Failed to get approval history: ${error.message}`);
    }
  },
};

// =============================================
// TOKEN RISK ACTIONS
// =============================================

const getTokenRiskAction: Action = {
  name: 'get_token_risk',
  description: 'Get risk score and analysis for a token',
  parameters: [
    {
      name: 'token_address',
      type: 'string',
      description: 'Token address to check',
      required: true,
    },
  ],
  examples: [
    {
      description: 'Check SOL token risk',
      input: { token_address: 'So11111111111111111111111111111111111111112' },
      output: { success: true, recommendation: 'safe', reasons: [] },
    },
  ],
  handler: async (params, _context) => {
    try {
      const analysis = await tokenRiskService.analyzeToken(params.token_address);
      return {
        success: true,
        ...analysis,
      };
    } catch (error: any) {
      logger.error('Get token risk action error:', error);
      throw new Error(`Failed to get token risk: ${error.message}`);
    }
  },
};

const searchTokensAction: Action = {
  name: 'search_tokens',
  description: 'Search for tokens by symbol, name, or address',
  parameters: [
    {
      name: 'query',
      type: 'string',
      description: 'Search query (symbol, name, or address)',
      required: true,
    },
    {
      name: 'limit',
      type: 'number',
      description: 'Number of results (default 10)',
      required: false,
      default: 10,
    },
  ],
  examples: [
    {
      description: 'Search for SOL token',
      input: { query: 'SOL', limit: 5 },
      output: { success: true, tokens: [], count: 0 },
    },
  ],
  handler: async (params, _context) => {
    try {
      const tokens = await tokenRiskService.searchTokens(
        params.query,
        params.limit || 10
      );
      return {
        success: true,
        tokens,
        count: tokens.length,
      };
    } catch (error: any) {
      logger.error('Search tokens action error:', error);
      throw new Error(`Failed to search tokens: ${error.message}`);
    }
  },
};

const getRiskyTokensAction: Action = {
  name: 'get_risky_tokens',
  description: 'Get list of high-risk tokens to avoid',
  parameters: [
    {
      name: 'limit',
      type: 'number',
      description: 'Number of results (default 20)',
      required: false,
      default: 20,
    },
  ],
  examples: [
    {
      description: 'Get risky tokens',
      input: { limit: 10 },
      output: { success: true, tokens: [], count: 0 },
    },
  ],
  handler: async (params, _context) => {
    try {
      const tokens = await tokenRiskService.getHighRiskTokens(params.limit || 20);
      return {
        success: true,
        tokens,
        count: tokens.length,
      };
    } catch (error: any) {
      logger.error('Get risky tokens action error:', error);
      throw new Error(`Failed to get risky tokens: ${error.message}`);
    }
  },
};

// =============================================
// PLUGIN DEFINITION
// =============================================

const userFeaturesPlugin: Plugin = {
  id: 'user-features',
  name: 'User Features',
  version: '1.0.0',
  description: 'User preferences, approval queue, and token risk scoring',
  isEnabled: true,
  actions: [
    getUserPreferencesAction,
    updateUserPreferencesAction,
    getPendingApprovalsAction,
    getApprovalHistoryAction,
    getTokenRiskAction,
    searchTokensAction,
    getRiskyTokensAction,
  ],
};

export default userFeaturesPlugin;
