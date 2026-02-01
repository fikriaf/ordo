import { Plugin, Action, ActionContext, PluginManager as IPluginManager } from '../types/plugin';
import supabase from '../config/database';
import logger from '../config/logger';

class PluginManagerService implements IPluginManager {
  private plugins: Map<string, Plugin> = new Map();

  constructor() {
    this.loadPluginsFromDatabase();
  }

  private async loadPluginsFromDatabase() {
    try {
      const { data: pluginsData, error } = await supabase
        .from('plugins')
        .select('*')
        .eq('is_enabled', true);

      if (error) {
        logger.error('Failed to load plugins from database:', error);
        return;
      }

      logger.info(`Loaded ${pluginsData?.length || 0} plugins from database`);
    } catch (error) {
      logger.error('Error loading plugins:', error);
    }
  }

  registerPlugin(plugin: Plugin): void {
    if (this.plugins.has(plugin.id)) {
      logger.warn(`Plugin ${plugin.id} already registered, updating...`);
    }
    
    this.plugins.set(plugin.id, plugin);
    logger.info(`Plugin registered: ${plugin.name} (${plugin.id})`);
  }

  unregisterPlugin(pluginId: string): void {
    if (this.plugins.delete(pluginId)) {
      logger.info(`Plugin unregistered: ${pluginId}`);
    } else {
      logger.warn(`Plugin not found: ${pluginId}`);
    }
  }

  getPlugin(pluginId: string): Plugin | undefined {
    return this.plugins.get(pluginId);
  }

  getAllPlugins(): Plugin[] {
    return Array.from(this.plugins.values());
  }

  getEnabledPlugins(): Plugin[] {
    return Array.from(this.plugins.values()).filter(p => p.isEnabled);
  }

  enablePlugin(pluginId: string): void {
    const plugin = this.plugins.get(pluginId);
    if (plugin) {
      plugin.isEnabled = true;
      logger.info(`Plugin enabled: ${pluginId}`);
    } else {
      throw new Error(`Plugin not found: ${pluginId}`);
    }
  }

  disablePlugin(pluginId: string): void {
    const plugin = this.plugins.get(pluginId);
    if (plugin) {
      plugin.isEnabled = false;
      logger.info(`Plugin disabled: ${pluginId}`);
    } else {
      throw new Error(`Plugin not found: ${pluginId}`);
    }
  }

  getAction(actionName: string): Action | undefined {
    for (const plugin of this.getEnabledPlugins()) {
      const action = plugin.actions.find(a => a.name === actionName);
      if (action) {
        return action;
      }
    }
    return undefined;
  }

  async executeAction(actionName: string, params: any, context: ActionContext): Promise<any> {
    const action = this.getAction(actionName);
    
    if (!action) {
      throw new Error(`Action not found: ${actionName}`);
    }

    // Validate required parameters
    const missingParams = action.parameters
      .filter(p => p.required && !(p.name in params))
      .map(p => p.name);

    if (missingParams.length > 0) {
      throw new Error(`Missing required parameters: ${missingParams.join(', ')}`);
    }

    try {
      logger.info(`Executing action: ${actionName}`, { params, context });
      const result = await action.handler(params, context);
      logger.info(`Action executed successfully: ${actionName}`);
      return result;
    } catch (error: any) {
      logger.error(`Action execution failed: ${actionName}`, error);
      throw new Error(`Action execution failed: ${error.message}`);
    }
  }

  getAvailableActions(): Action[] {
    const actions: Action[] = [];
    for (const plugin of this.getEnabledPlugins()) {
      actions.push(...plugin.actions);
    }
    return actions;
  }

  getActionsForTools(): any[] {
    return this.getAvailableActions().map(action => ({
      name: action.name,
      description: action.description,
      parameters: {
        type: 'object',
        properties: action.parameters.reduce((acc, param) => {
          acc[param.name] = {
            type: param.type,
            description: param.description,
          };
          return acc;
        }, {} as Record<string, any>),
        required: action.parameters.filter(p => p.required).map(p => p.name),
      },
    }));
  }
}

export default new PluginManagerService();
