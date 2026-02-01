import supabase from '../config/database';
import logger from '../config/logger';
import { AIModel } from '../types';

interface CreateModelInput {
  name: string;
  provider: string;
  model_id: string;
  config?: Record<string, any>;
}

interface UpdateModelInput {
  name?: string;
  provider?: string;
  model_id?: string;
  is_enabled?: boolean;
  config?: Record<string, any>;
}

interface ModelUsageStats {
  model_id: string;
  total_requests: number;
  total_tokens: number;
  estimated_cost: number;
}

class AIModelService {
  async getAllModels(): Promise<AIModel[]> {
    try {
      const { data, error } = await supabase
        .from('ai_models')
        .select('*')
        .order('created_at', { ascending: false });

      if (error) {
        logger.error('Error getting AI models:', error);
        throw new Error('Failed to get AI models');
      }

      return data || [];
    } catch (error) {
      logger.error('Error getting AI models:', error);
      throw new Error('Failed to get AI models');
    }
  }

  async getModelById(id: string): Promise<AIModel | null> {
    try {
      const { data, error } = await supabase
        .from('ai_models')
        .select('*')
        .eq('id', id)
        .single();

      if (error) {
        if (error.code === 'PGRST116') {
          return null;
        }
        logger.error('Error getting AI model:', error);
        throw new Error('Failed to get AI model');
      }

      return data;
    } catch (error) {
      logger.error('Error getting AI model:', error);
      throw new Error('Failed to get AI model');
    }
  }

  async createModel(input: CreateModelInput, adminId: string): Promise<AIModel> {
    try {
      // Check if model with same name already exists
      const { data: existing } = await supabase
        .from('ai_models')
        .select('id')
        .eq('name', input.name)
        .single();

      if (existing) {
        throw new Error('Model with this name already exists');
      }

      const { data, error } = await supabase
        .from('ai_models')
        .insert({
          name: input.name,
          provider: input.provider,
          model_id: input.model_id,
          is_enabled: true,
          is_default: false,
          config: input.config || {},
        })
        .select()
        .single();

      if (error) {
        logger.error('Error creating AI model:', error);
        throw new Error('Failed to create AI model');
      }

      // Log audit event
      await this.logModelAction(adminId, 'CREATE_MODEL', data.id, {
        name: data.name,
        provider: data.provider,
      });

      logger.info(`AI model created: ${data.name}`, { modelId: data.id, adminId });
      return data;
    } catch (error) {
      logger.error('Error creating AI model:', error);
      throw error;
    }
  }

  async updateModel(id: string, input: UpdateModelInput, adminId: string): Promise<AIModel> {
    try {
      const { data, error } = await supabase
        .from('ai_models')
        .update(input)
        .eq('id', id)
        .select()
        .single();

      if (error) {
        logger.error('Error updating AI model:', error);
        throw new Error('Failed to update AI model');
      }

      // Log audit event
      await this.logModelAction(adminId, 'UPDATE_MODEL', id, input);

      logger.info(`AI model updated: ${data.name}`, { modelId: id, adminId });
      return data;
    } catch (error) {
      logger.error('Error updating AI model:', error);
      throw error;
    }
  }

  async deleteModel(id: string, adminId: string): Promise<void> {
    try {
      // Check if it's the default model
      const model = await this.getModelById(id);
      if (model?.is_default) {
        throw new Error('Cannot delete default model. Set another model as default first.');
      }

      const { error } = await supabase.from('ai_models').delete().eq('id', id);

      if (error) {
        logger.error('Error deleting AI model:', error);
        throw new Error('Failed to delete AI model');
      }

      // Log audit event
      await this.logModelAction(adminId, 'DELETE_MODEL', id, {});

      logger.info(`AI model deleted`, { modelId: id, adminId });
    } catch (error) {
      logger.error('Error deleting AI model:', error);
      throw error;
    }
  }

  async setDefaultModel(id: string, adminId: string): Promise<AIModel> {
    try {
      // First, unset current default
      await supabase
        .from('ai_models')
        .update({ is_default: false })
        .eq('is_default', true);

      // Set new default
      const { data, error } = await supabase
        .from('ai_models')
        .update({ is_default: true, is_enabled: true })
        .eq('id', id)
        .select()
        .single();

      if (error) {
        logger.error('Error setting default model:', error);
        throw new Error('Failed to set default model');
      }

      // Log audit event
      await this.logModelAction(adminId, 'SET_DEFAULT_MODEL', id, {});

      logger.info(`Default model set: ${data.name}`, { modelId: id, adminId });
      return data;
    } catch (error) {
      logger.error('Error setting default model:', error);
      throw error;
    }
  }

  async enableModel(id: string, adminId: string): Promise<AIModel> {
    try {
      const { data, error } = await supabase
        .from('ai_models')
        .update({ is_enabled: true })
        .eq('id', id)
        .select()
        .single();

      if (error) {
        logger.error('Error enabling model:', error);
        throw new Error('Failed to enable model');
      }

      // Log audit event
      await this.logModelAction(adminId, 'ENABLE_MODEL', id, {});

      logger.info(`Model enabled: ${data.name}`, { modelId: id, adminId });
      return data;
    } catch (error) {
      logger.error('Error enabling model:', error);
      throw error;
    }
  }

  async disableModel(id: string, adminId: string): Promise<AIModel> {
    try {
      // Check if it's the default model
      const model = await this.getModelById(id);
      if (model?.is_default) {
        throw new Error('Cannot disable default model. Set another model as default first.');
      }

      const { data, error } = await supabase
        .from('ai_models')
        .update({ is_enabled: false })
        .eq('id', id)
        .select()
        .single();

      if (error) {
        logger.error('Error disabling model:', error);
        throw new Error('Failed to disable model');
      }

      // Log audit event
      await this.logModelAction(adminId, 'DISABLE_MODEL', id, {});

      logger.info(`Model disabled: ${data.name}`, { modelId: id, adminId });
      return data;
    } catch (error) {
      logger.error('Error disabling model:', error);
      throw error;
    }
  }

  async getModelUsageStats(_modelId?: string): Promise<ModelUsageStats[]> {
    try {
      // This would require tracking model usage in a separate table
      // For now, return mock data
      // TODO: Implement actual usage tracking
      return [];
    } catch (error) {
      logger.error('Error getting model usage stats:', error);
      throw new Error('Failed to get model usage stats');
    }
  }

  private async logModelAction(
    adminId: string,
    action: string,
    modelId: string,
    details: Record<string, any>
  ): Promise<void> {
    try {
      await supabase.from('audit_logs').insert({
        admin_id: adminId,
        action,
        resource_type: 'ai_model',
        resource_id: modelId,
        metadata: details,
      });
    } catch (error) {
      logger.error('Error logging model action:', error);
      // Don't throw - audit logging failure shouldn't break operations
    }
  }
}

export default new AIModelService();
