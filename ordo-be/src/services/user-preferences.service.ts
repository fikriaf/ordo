import supabase from '../config/database';
import logger from '../config/logger';
import { UserPreferences } from '../types';

export class UserPreferencesService {
  async getUserPreferences(userId: string): Promise<UserPreferences | null> {
    try {
      const { data, error } = await supabase
        .from('user_preferences')
        .select('*')
        .eq('user_id', userId)
        .single();

      if (error) {
        if (error.code === 'PGRST116') {
          // No preferences found, create default
          return await this.createDefaultPreferences(userId);
        }
        logger.error('Failed to get user preferences:', error);
        throw new Error('Failed to get user preferences');
      }

      return data;
    } catch (error) {
      logger.error('Get user preferences error:', error);
      throw error;
    }
  }

  async createDefaultPreferences(userId: string): Promise<UserPreferences> {
    try {
      const { data, error } = await supabase
        .from('user_preferences')
        .insert({ user_id: userId })
        .select()
        .single();

      if (error) {
        logger.error('Failed to create default preferences:', error);
        throw new Error('Failed to create default preferences');
      }

      logger.info(`Default preferences created for user ${userId}`);
      return data;
    } catch (error) {
      logger.error('Create default preferences error:', error);
      throw error;
    }
  }

  async updatePreferences(
    userId: string,
    updates: Partial<Omit<UserPreferences, 'id' | 'user_id' | 'created_at' | 'updated_at'>>
  ): Promise<UserPreferences> {
    try {
      const { data, error } = await supabase
        .from('user_preferences')
        .update(updates)
        .eq('user_id', userId)
        .select()
        .single();

      if (error) {
        logger.error('Failed to update preferences:', error);
        throw new Error('Failed to update preferences');
      }

      logger.info(`Preferences updated for user ${userId}`);
      return data;
    } catch (error) {
      logger.error('Update preferences error:', error);
      throw error;
    }
  }

  async resetToDefaults(userId: string): Promise<UserPreferences> {
    try {
      // Delete existing preferences
      await supabase
        .from('user_preferences')
        .delete()
        .eq('user_id', userId);

      // Create new default preferences
      return await this.createDefaultPreferences(userId);
    } catch (error) {
      logger.error('Reset preferences error:', error);
      throw error;
    }
  }

  async checkTransactionApprovalRequired(
    userId: string,
    amountUsdc: number,
    riskScore?: number
  ): Promise<{ required: boolean; reason?: string }> {
    try {
      const preferences = await this.getUserPreferences(userId);
      if (!preferences) {
        return { required: true, reason: 'No preferences found' };
      }

      // Check autonomy level
      if (preferences.agent_autonomy_level === 'low') {
        return { required: true, reason: 'Low autonomy level - all transactions require approval' };
      }

      // Check amount threshold
      if (amountUsdc > preferences.require_approval_above_usdc) {
        return { 
          required: true, 
          reason: `Amount ($${amountUsdc}) exceeds approval threshold ($${preferences.require_approval_above_usdc})` 
        };
      }

      // Check risk score if provided
      if (riskScore !== undefined) {
        if (preferences.block_high_risk_tokens && riskScore > 70) {
          return { required: true, reason: `High risk token (score: ${riskScore})` };
        }
        if (riskScore < preferences.min_token_risk_score) {
          return { 
            required: true, 
            reason: `Token risk score (${riskScore}) below minimum (${preferences.min_token_risk_score})` 
          };
        }
      }

      return { required: false };
    } catch (error) {
      logger.error('Check approval required error:', error);
      return { required: true, reason: 'Error checking approval requirements' };
    }
  }

  async checkDailyVolumeLimit(userId: string, additionalAmountUsdc: number): Promise<{ allowed: boolean; reason?: string }> {
    try {
      const preferences = await this.getUserPreferences(userId);
      if (!preferences) {
        return { allowed: false, reason: 'No preferences found' };
      }

      // Get today's transaction volume
      const today = new Date();
      today.setHours(0, 0, 0, 0);

      const { data: transactions, error } = await supabase
        .from('transactions')
        .select('metadata')
        .eq('user_id', userId)
        .gte('created_at', today.toISOString());

      if (error) {
        logger.error('Failed to get daily transactions:', error);
        return { allowed: false, reason: 'Error checking daily volume' };
      }

      // Calculate total volume (simplified - would need proper USD conversion)
      let dailyVolumeUsdc = 0;
      if (transactions) {
        transactions.forEach(tx => {
          const metadata = tx.metadata as any;
          if (metadata?.amountUsdc) {
            dailyVolumeUsdc += parseFloat(metadata.amountUsdc);
          }
        });
      }

      const newTotal = dailyVolumeUsdc + additionalAmountUsdc;
      if (newTotal > preferences.max_daily_volume_usdc) {
        return {
          allowed: false,
          reason: `Daily volume limit exceeded: $${newTotal.toFixed(2)} > $${preferences.max_daily_volume_usdc}`
        };
      }

      return { allowed: true };
    } catch (error) {
      logger.error('Check daily volume error:', error);
      return { allowed: false, reason: 'Error checking daily volume' };
    }
  }
}

export default new UserPreferencesService();
