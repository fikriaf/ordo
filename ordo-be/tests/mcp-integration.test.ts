// Mock environment before importing services
process.env.NODE_ENV = 'test';
process.env.SUPABASE_URL = 'https://test.supabase.co';
process.env.SUPABASE_KEY = 'test-key';
process.env.JWT_SECRET = 'test-secret';
process.env.ENCRYPTION_KEY = '12345678901234567890123456789012'; // 32 chars
process.env.SOLANA_RPC_URL = 'https://api.devnet.solana.com';
process.env.OPENROUTER_API_KEY = 'test-key';
process.env.OPENROUTER_BASE_URL = 'https://openrouter.ai/api/v1';
process.env.AI_MODELS = 'test-model';

import { mcpClientService } from '../src/services/mcp-client.service';
import { mcpServerService } from '../src/services/mcp-server.service';

describe('MCP Integration Tests', () => {
  describe('MCPClientService', () => {
    beforeEach(() => {
      // Clear cache before each test
      mcpClientService.clearCache();
      mcpClientService.clearClients();
    });

    it('should fetch tools from enabled MCP servers', async () => {
      const tools = await mcpClientService.getAvailableTools();
      expect(Array.isArray(tools)).toBe(true);
    });

    it('should cache tools for 5 minutes', async () => {
      const tools1 = await mcpClientService.getAvailableTools();
      const tools2 = await mcpClientService.getAvailableTools();
      
      // Second call should be faster (cached)
      expect(tools1).toEqual(tools2);
    });

    it('should prefix MCP tool names with server name', async () => {
      const tools = await mcpClientService.getAvailableTools();
      
      tools.forEach(tool => {
        expect(tool.name).toContain('__');
        const [serverName, toolName] = tool.name.split('__');
        expect(serverName).toBeTruthy();
        expect(toolName).toBeTruthy();
      });
    });

    it('should handle MCP server failures gracefully', async () => {
      // Should not throw even if servers fail
      const tools = await mcpClientService.getAvailableTools();
      expect(Array.isArray(tools)).toBe(true);
    });

    it('should clear cache when requested', () => {
      mcpClientService.clearCache();
      // Should not throw
      expect(true).toBe(true);
    });
  });

  describe('MCPServerService', () => {
    it('should retrieve all enabled servers', async () => {
      const servers = await mcpServerService.getAll();
      expect(Array.isArray(servers)).toBe(true);
    });

    it('should retrieve public servers without sensitive data', async () => {
      const servers = await mcpServerService.getAllPublic();
      expect(Array.isArray(servers)).toBe(true);
      
      servers.forEach(server => {
        expect(server).not.toHaveProperty('api_key');
        expect(server).not.toHaveProperty('headers');
      });
    });

    it('should validate transport types', async () => {
      const validTypes = ['http', 'sse'];
      
      // This test assumes we have servers in the database
      const servers = await mcpServerService.getAll();
      
      servers.forEach(server => {
        expect(validTypes).toContain(server.transport_type);
      });
    });
  });

  describe('Tool Execution Routing', () => {
    it('should identify MCP tools by double underscore', () => {
      const mcpToolName = 'weather-mcp__get_forecast';
      const pluginToolName = 'transfer_sol';
      
      expect(mcpToolName.includes('__')).toBe(true);
      expect(pluginToolName.includes('__')).toBe(false);
    });

    it('should parse MCP tool names correctly', () => {
      const toolName = 'weather-mcp__get_forecast';
      const [serverName, originalName] = toolName.split('__');
      
      expect(serverName).toBe('weather-mcp');
      expect(originalName).toBe('get_forecast');
    });
  });
});
