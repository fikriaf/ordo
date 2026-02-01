export interface ActionParameter {
  name: string;
  type: 'string' | 'number' | 'boolean' | 'object' | 'array';
  description: string;
  required: boolean;
  default?: any;
}

export interface Action {
  name: string;
  description: string;
  parameters: ActionParameter[];
  handler: (params: any, context: ActionContext) => Promise<any>;
  examples?: ActionExample[];
}

export interface ActionExample {
  description: string;
  input: Record<string, any>;
  output: any;
}

export interface ActionContext {
  userId: string;
  walletId?: string;
  metadata?: Record<string, any>;
}

export interface Plugin {
  id: string;
  name: string;
  version: string;
  description: string;
  isEnabled: boolean;
  actions: Action[];
  config?: Record<string, any>;
}

export interface PluginManager {
  registerPlugin(plugin: Plugin): void;
  unregisterPlugin(pluginId: string): void;
  getPlugin(pluginId: string): Plugin | undefined;
  getAllPlugins(): Plugin[];
  getEnabledPlugins(): Plugin[];
  enablePlugin(pluginId: string): void;
  disablePlugin(pluginId: string): void;
  getAction(actionName: string): Action | undefined;
  executeAction(actionName: string, params: any, context: ActionContext): Promise<any>;
  getAvailableActions(): Action[];
}

export interface Tool {
  name: string;
  description: string;
  parameters: {
    type: 'object';
    properties: Record<string, any>;
    required?: string[];
  };
}
