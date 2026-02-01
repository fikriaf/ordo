import supabase from '../config/database';
import logger from '../config/logger';
import { AdminConfig } from '../types';

interface ConfigUpdate {
  value: any;
}

interface ConfigHistory {
  id: string;
  key: string;
  value: any;
  version: number;
  updated_at: string;
  updated_by: string;
}

class ConfigService {
  private configCache: Map<string, any> = new Map();

  async getAllConfigs(): Promise<AdminConfig[]> {
    try {
      const { data, error } = await supabase
        .from('admin_configs')
        .select('*')
        .order('key', { ascending: true });

      if (error) {
        logger.error('Error getting configs:', error);
        throw new Error('Failed to get configs');
      }

      // Update cache
      data?.forEach((config) => {
        this.configCache.set(config.key, config.value);
      });

      return data || [];
    } catch (error) {
      logger.error('Error getting configs:', error);
      throw new Error('Failed to get configs');
    }
  }

  async getConfigByKey(key: string): Promise<AdminConfig | null> {
    try {
      // Check cache first
      if (this.configCache.has(key)) {
        const { data } = await supabase
          .from('admin_configs')
          .select('*')
          .eq('key', key)
          .single();
        return data;
      }

      const { data, error } = await supabase
        .from('admin_configs')
        .select('*')
        .eq('key', key)
        .single();

      if (error) {
        if (error.code === 'PGRST116') {
          return null;
        }
        logger.error('Error getting config:', error);
        throw new Error('Failed to get config');
      }

      // Update cache
      if (data) {
        this.configCache.set(key, data.value);
      }

      return data;
    } catch (error) {
      logger.error('Error getting config:', error);
      throw new Error('Failed to get config');
    }
  }

  async updateConfig(key: string, update: ConfigUpdate, adminId: string): Promise<AdminConfig> {
    try {
      // Validate config value
      this.validateConfigValue(key, update.value);

      // Get current config for history
      const current = await this.getConfigByKey(key);
      const newVersion = current ? current.version + 1 : 1;

      // Save to history if exists
      if (current) {
        await this.saveConfigHistory(current, adminId);
      }

      // Update or insert config
      const { data, error } = await supabase
        .from('admin_configs')
        .upsert({
          key,
          value: update.value,
          version: newVersion,
          updated_by: adminId,
          updated_at: new Date().toISOString(),
        })
        .select()
        .single();

      if (error) {
        logger.error('Error updating config:', error);
        throw new Error('Failed to update config');
      }

      // Update cache (hot reload)
      this.configCache.set(key, update.value);

      // Log audit event
      await this.logConfigAction(adminId, 'UPDATE_CONFIG', key, {
        old_value: current?.value,
        new_value: update.value,
        version: newVersion,
      });

      logger.info(`Config updated: ${key}`, { version: newVersion, adminId });
      return data;
    } catch (error) {
      logger.error('Error updating config:', error);
      throw error;
    }
  }

  async getConfigHistory(key: string): Promise<ConfigHistory[]> {
    try {
      // Query from audit logs for config history
      const { data, error } = await supabase
        .from('audit_logs')
        .select('*')
        .eq('resource_type', 'config')
        .eq('resource_id', key)
        .eq('action', 'UPDATE_CONFIG')
        .order('created_at', { ascending: false })
        .limit(50);

      if (error) {
        logger.error('Error getting config history:', error);
        throw new Error('Failed to get config history');
      }

      // Transform audit logs to history format
      return (
        data?.map((log) => ({
          id: log.id,
          key,
          value: log.metadata?.new_value,
          version: log.metadata?.version || 0,
          updated_at: log.created_at,
          updated_by: log.admin_id,
        })) || []
      );
    } catch (error) {
      logger.error('Error getting config history:', error);
      throw new Error('Failed to get config history');
    }
  }

  async rollbackConfig(key: string, version: number, adminId: string): Promise<AdminConfig> {
    try {
      // Get history entry for the version
      const history = await this.getConfigHistory(key);
      const targetVersion = history.find((h) => h.version === version);

      if (!targetVersion) {
        throw new Error(`Version ${version} not found in history`);
      }

      // Rollback to that version
      return await this.updateConfig(key, { value: targetVersion.value }, adminId);
    } catch (error) {
      logger.error('Error rolling back config:', error);
      throw error;
    }
  }

  getCachedConfig(key: string): any {
    return this.configCache.get(key);
  }

  clearCache(): void {
    this.configCache.clear();
    logger.info('Config cache cleared');
  }

  private validateConfigValue(key: string, value: any): void {
    // Basic validation - can be extended based on config key
    if (value === undefined || value === null) {
      throw new Error('Config value cannot be null or undefined');
    }

    // Add specific validations based on key
    switch (key) {
      case 'rate_limit_max':
        if (typeof value !== 'number' || value < 1 || value > 10000) {
          throw new Error('rate_limit_max must be a number between 1 and 10000');
        }
        break;
      case 'rate_limit_window_ms':
        if (typeof value !== 'number' || value < 1000 || value > 3600000) {
          throw new Error('rate_limit_window_ms must be between 1000 and 3600000');
        }
        break;
      case 'max_context_messages':
        if (typeof value !== 'number' || value < 1 || value > 100) {
          throw new Error('max_context_messages must be between 1 and 100');
        }
        break;
      // Add more validations as needed
    }
  }

  private async saveConfigHistory(config: AdminConfig, _adminId: string): Promise<void> {
    try {
      // History is saved via audit logs
      // This is just a placeholder for additional history tracking if needed
      logger.debug('Config history saved via audit logs', { key: config.key, version: config.version });
    } catch (error) {
      logger.error('Error saving config history:', error);
    }
  }

  private async logConfigAction(
    adminId: string,
    action: string,
    key: string,
    details: Record<string, any>
  ): Promise<void> {
    try {
      await supabase.from('audit_logs').insert({
        admin_id: adminId,
        action,
        resource_type: 'config',
        resource_id: key,
        metadata: details,
      });
    } catch (error) {
      logger.error('Error logging config action:', error);
    }
  }
}

export default new ConfigService();
