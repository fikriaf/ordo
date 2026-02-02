import supabase from '../config/database';
import logger from '../config/logger';

export type MCPTransportType = 'http' | 'sse';

export interface MCPServer {
  id: string;
  name: string;
  description?: string;
  transport_type: MCPTransportType;
  server_url: string;
  api_key?: string;
  headers?: Record<string, string>;
  is_enabled: boolean;
  config: Record<string, any>;
  metadata: Record<string, any>;
  created_at: string;
  updated_at: string;
}

export interface CreateMCPServerInput {
  name: string;
  description?: string;
  transport_type: MCPTransportType;
  server_url: string;
  api_key?: string;
  headers?: Record<string, string>;
  is_enabled?: boolean;
  config?: Record<string, any>;
  metadata?: Record<string, any>;
}

export interface UpdateMCPServerInput {
  name?: string;
  description?: string;
  transport_type?: MCPTransportType;
  server_url?: string;
  api_key?: string;
  headers?: Record<string, string>;
  is_enabled?: boolean;
  config?: Record<string, any>;
  metadata?: Record<string, any>;
}

export class MCPServerService {
  // Get all MCP servers (public - without sensitive data)
  async getAllPublic(): Promise<Omit<MCPServer, 'api_key' | 'headers'>[]> {
    try {
      const { data, error } = await supabase
        .from('mcp_servers')
        .select('id, name, description, transport_type, server_url, is_enabled, config, metadata, created_at, updated_at')
        .eq('is_enabled', true)
        .order('name', { ascending: true });

      if (error) throw error;

      logger.info('Retrieved all public MCP servers', { count: data?.length || 0 });
      return data || [];
    } catch (error) {
      logger.error('Error getting public MCP servers', { error });
      throw new Error('Failed to retrieve MCP servers');
    }
  }

  // Get all MCP servers (admin - with sensitive data)
  async getAll(): Promise<MCPServer[]> {
    try {
      const { data, error } = await supabase
        .from('mcp_servers')
        .select('*')
        .order('name', { ascending: true });

      if (error) throw error;

      logger.info('Retrieved all MCP servers (admin)', { count: data?.length || 0 });
      return data || [];
    } catch (error) {
      logger.error('Error getting MCP servers', { error });
      throw new Error('Failed to retrieve MCP servers');
    }
  }

  // Get MCP server by ID
  async getById(id: string): Promise<MCPServer | null> {
    try {
      const { data, error } = await supabase
        .from('mcp_servers')
        .select('*')
        .eq('id', id)
        .single();

      if (error) {
        if (error.code === 'PGRST116') return null;
        throw error;
      }

      logger.info('Retrieved MCP server by ID', { id });
      return data;
    } catch (error) {
      logger.error('Error getting MCP server by ID', { id, error });
      throw new Error('Failed to retrieve MCP server');
    }
  }

  // Create new MCP server
  async create(input: CreateMCPServerInput, adminId: string): Promise<MCPServer> {
    try {
      const { data, error } = await supabase
        .from('mcp_servers')
        .insert({
          name: input.name,
          description: input.description,
          transport_type: input.transport_type,
          server_url: input.server_url,
          api_key: input.api_key,
          headers: input.headers || {},
          is_enabled: input.is_enabled ?? true,
          config: input.config || {},
          metadata: input.metadata || {},
        })
        .select()
        .single();

      if (error) throw error;

      // Log audit
      await this.logAudit(adminId, 'create', 'mcp_server', data.id, {
        name: input.name,
        transport_type: input.transport_type,
        server_url: input.server_url,
      });

      logger.info('Created MCP server', { id: data.id, name: input.name, adminId });
      return data;
    } catch (error: any) {
      logger.error('Error creating MCP server', { input, error });
      if (error.code === '23505') {
        throw new Error('MCP server with this name already exists');
      }
      throw new Error('Failed to create MCP server');
    }
  }

  // Update MCP server
  async update(id: string, input: UpdateMCPServerInput, adminId: string): Promise<MCPServer> {
    try {
      const { data, error } = await supabase
        .from('mcp_servers')
        .update({
          ...(input.name && { name: input.name }),
          ...(input.description !== undefined && { description: input.description }),
          ...(input.transport_type && { transport_type: input.transport_type }),
          ...(input.server_url && { server_url: input.server_url }),
          ...(input.api_key !== undefined && { api_key: input.api_key }),
          ...(input.headers && { headers: input.headers }),
          ...(input.is_enabled !== undefined && { is_enabled: input.is_enabled }),
          ...(input.config && { config: input.config }),
          ...(input.metadata && { metadata: input.metadata }),
        })
        .eq('id', id)
        .select()
        .single();

      if (error) {
        if (error.code === 'PGRST116') {
          throw new Error('MCP server not found');
        }
        throw error;
      }

      // Log audit
      await this.logAudit(adminId, 'update', 'mcp_server', id, input);

      logger.info('Updated MCP server', { id, adminId });
      return data;
    } catch (error: any) {
      logger.error('Error updating MCP server', { id, input, error });
      if (error.message === 'MCP server not found') throw error;
      if (error.code === '23505') {
        throw new Error('MCP server with this name already exists');
      }
      throw new Error('Failed to update MCP server');
    }
  }

  // Delete MCP server
  async delete(id: string, adminId: string): Promise<void> {
    try {
      const { error } = await supabase
        .from('mcp_servers')
        .delete()
        .eq('id', id);

      if (error) throw error;

      // Log audit
      await this.logAudit(adminId, 'delete', 'mcp_server', id, {});

      logger.info('Deleted MCP server', { id, adminId });
    } catch (error) {
      logger.error('Error deleting MCP server', { id, error });
      throw new Error('Failed to delete MCP server');
    }
  }

  // Enable/Disable MCP server
  async toggleEnabled(id: string, enabled: boolean, adminId: string): Promise<MCPServer> {
    try {
      const { data, error } = await supabase
        .from('mcp_servers')
        .update({ is_enabled: enabled })
        .eq('id', id)
        .select()
        .single();

      if (error) {
        if (error.code === 'PGRST116') {
          throw new Error('MCP server not found');
        }
        throw error;
      }

      // Log audit
      await this.logAudit(adminId, enabled ? 'enable' : 'disable', 'mcp_server', id, { enabled });

      logger.info(`${enabled ? 'Enabled' : 'Disabled'} MCP server`, { id, adminId });
      return data;
    } catch (error: any) {
      logger.error('Error toggling MCP server', { id, enabled, error });
      if (error.message === 'MCP server not found') throw error;
      throw new Error('Failed to toggle MCP server');
    }
  }

  // Log audit action
  private async logAudit(
    adminId: string,
    action: string,
    resourceType: string,
    resourceId: string,
    metadata: Record<string, any>
  ): Promise<void> {
    try {
      await supabase.from('audit_logs').insert({
        admin_id: adminId,
        action,
        resource_type: resourceType,
        resource_id: resourceId,
        metadata,
      });
    } catch (error) {
      logger.error('Error logging audit', { adminId, action, resourceType, resourceId, error });
    }
  }
}

export const mcpServerService = new MCPServerService();
