import supabase from '../config/database';
import logger from '../config/logger';
import { Plugin } from '../types';
import pluginManager from './plugin-manager.service';

interface CreatePluginInput {
  name: string;
  version: string;
  description: string;
  config?: Record<string, any>;
}

interface UpdatePluginInput {
  name?: string;
  version?: string;
  description?: string;
  config?: Record<string, any>;
}

class PluginAdminService {
  async getAllPlugins(): Promise<Plugin[]> {
    try {
      const { data, error } = await supabase
        .from('plugins')
        .select('*')
        .order('created_at', { ascending: false });

      if (error) {
        logger.error('Error getting plugins:', error);
        throw new Error('Failed to get plugins');
      }

      return data || [];
    } catch (error) {
      logger.error('Error getting plugins:', error);
      throw new Error('Failed to get plugins');
    }
  }

  async getPluginById(id: string): Promise<Plugin | null> {
    try {
      const { data, error } = await supabase
        .from('plugins')
        .select('*')
        .eq('id', id)
        .single();

      if (error) {
        if (error.code === 'PGRST116') {
          return null;
        }
        logger.error('Error getting plugin:', error);
        throw new Error('Failed to get plugin');
      }

      return data;
    } catch (error) {
      logger.error('Error getting plugin:', error);
      throw new Error('Failed to get plugin');
    }
  }

  async createPlugin(input: CreatePluginInput, adminId: string): Promise<Plugin> {
    try {
      // Check if plugin with same name already exists
      const { data: existing } = await supabase
        .from('plugins')
        .select('id')
        .eq('name', input.name)
        .single();

      if (existing) {
        throw new Error('Plugin with this name already exists');
      }

      // Validate plugin compatibility (basic validation)
      this.validatePluginConfig(input);

      const { data, error } = await supabase
        .from('plugins')
        .insert({
          name: input.name,
          version: input.version,
          description: input.description,
          is_enabled: false, // Disabled by default for safety
          config: input.config || {},
        })
        .select()
        .single();

      if (error) {
        logger.error('Error creating plugin:', error);
        throw new Error('Failed to create plugin');
      }

      // Log audit event
      await this.logPluginAction(adminId, 'CREATE_PLUGIN', data.id, {
        name: data.name,
        version: data.version,
      });

      logger.info(`Plugin created: ${data.name}`, { pluginId: data.id, adminId });
      return data;
    } catch (error) {
      logger.error('Error creating plugin:', error);
      throw error;
    }
  }

  async updatePlugin(id: string, input: UpdatePluginInput, adminId: string): Promise<Plugin> {
    try {
      // Validate if updating config
      if (input.config) {
        const plugin = await this.getPluginById(id);
        if (plugin) {
          this.validatePluginConfig({ ...plugin, ...input } as CreatePluginInput);
        }
      }

      const { data, error } = await supabase
        .from('plugins')
        .update(input)
        .eq('id', id)
        .select()
        .single();

      if (error) {
        logger.error('Error updating plugin:', error);
        throw new Error('Failed to update plugin');
      }

      // Log audit event
      await this.logPluginAction(adminId, 'UPDATE_PLUGIN', id, input);

      logger.info(`Plugin updated: ${data.name}`, { pluginId: id, adminId });
      return data;
    } catch (error) {
      logger.error('Error updating plugin:', error);
      throw error;
    }
  }

  async deletePlugin(id: string, adminId: string): Promise<void> {
    try {
      const plugin = await this.getPluginById(id);
      if (!plugin) {
        throw new Error('Plugin not found');
      }

      // Unregister from plugin manager if enabled
      if (plugin.is_enabled) {
        try {
          await pluginManager.unregisterPlugin(plugin.name);
        } catch (error) {
          logger.warn('Error unregistering plugin from manager:', error);
        }
      }

      const { error } = await supabase.from('plugins').delete().eq('id', id);

      if (error) {
        logger.error('Error deleting plugin:', error);
        throw new Error('Failed to delete plugin');
      }

      // Log audit event
      await this.logPluginAction(adminId, 'DELETE_PLUGIN', id, {
        name: plugin.name,
      });

      logger.info(`Plugin deleted: ${plugin.name}`, { pluginId: id, adminId });
    } catch (error) {
      logger.error('Error deleting plugin:', error);
      throw error;
    }
  }

  async enablePlugin(id: string, adminId: string): Promise<Plugin> {
    try {
      const plugin = await this.getPluginById(id);
      if (!plugin) {
        throw new Error('Plugin not found');
      }

      // Update database
      const { data, error } = await supabase
        .from('plugins')
        .update({ is_enabled: true })
        .eq('id', id)
        .select()
        .single();

      if (error) {
        logger.error('Error enabling plugin:', error);
        throw new Error('Failed to enable plugin');
      }

      // Register with plugin manager
      // Note: In a real implementation, you would load the plugin code here
      // For now, we just update the database state
      logger.info(`Plugin enabled: ${data.name}`, { pluginId: id, adminId });

      // Log audit event
      await this.logPluginAction(adminId, 'ENABLE_PLUGIN', id, {});

      return data;
    } catch (error) {
      logger.error('Error enabling plugin:', error);
      throw error;
    }
  }

  async disablePlugin(id: string, adminId: string): Promise<Plugin> {
    try {
      const plugin = await this.getPluginById(id);
      if (!plugin) {
        throw new Error('Plugin not found');
      }

      // Unregister from plugin manager
      try {
        await pluginManager.unregisterPlugin(plugin.name);
      } catch (error) {
        logger.warn('Error unregistering plugin from manager:', error);
      }

      // Update database
      const { data, error } = await supabase
        .from('plugins')
        .update({ is_enabled: false })
        .eq('id', id)
        .select()
        .single();

      if (error) {
        logger.error('Error disabling plugin:', error);
        throw new Error('Failed to disable plugin');
      }

      // Log audit event
      await this.logPluginAction(adminId, 'DISABLE_PLUGIN', id, {});

      logger.info(`Plugin disabled: ${data.name}`, { pluginId: id, adminId });
      return data;
    } catch (error) {
      logger.error('Error disabling plugin:', error);
      throw error;
    }
  }

  private validatePluginConfig(input: CreatePluginInput): void {
    // Basic validation
    if (!input.name || input.name.length < 3) {
      throw new Error('Plugin name must be at least 3 characters');
    }

    if (!input.version || !this.isValidVersion(input.version)) {
      throw new Error('Invalid plugin version format. Use semantic versioning (e.g., 1.0.0)');
    }

    // Additional validation can be added here
    // - Check for required config fields
    // - Validate dependencies
    // - Check compatibility with current system version
  }

  private isValidVersion(version: string): boolean {
    // Simple semantic versioning check
    const semverRegex = /^\d+\.\d+\.\d+$/;
    return semverRegex.test(version);
  }

  private async logPluginAction(
    adminId: string,
    action: string,
    pluginId: string,
    details: Record<string, any>
  ): Promise<void> {
    try {
      await supabase.from('audit_logs').insert({
        admin_id: adminId,
        action,
        resource_type: 'plugin',
        resource_id: pluginId,
        metadata: details,
      });
    } catch (error) {
      logger.error('Error logging plugin action:', error);
      // Don't throw - audit logging failure shouldn't break operations
    }
  }
}

export default new PluginAdminService();
