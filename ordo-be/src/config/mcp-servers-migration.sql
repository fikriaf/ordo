-- MCP Servers table migration
-- Run this in Supabase SQL Editor

CREATE TABLE IF NOT EXISTS mcp_servers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR(100) UNIQUE NOT NULL,
  description TEXT,
  transport_type VARCHAR(20) NOT NULL CHECK (transport_type IN ('http', 'sse')),
  server_url VARCHAR(500) NOT NULL,
  api_key VARCHAR(255),
  headers JSONB DEFAULT '{}',
  is_enabled BOOLEAN DEFAULT TRUE,
  config JSONB DEFAULT '{}',
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_mcp_servers_is_enabled ON mcp_servers(is_enabled);
CREATE INDEX idx_mcp_servers_name ON mcp_servers(name);
CREATE INDEX idx_mcp_servers_transport_type ON mcp_servers(transport_type);

-- Trigger for updated_at
CREATE TRIGGER update_mcp_servers_updated_at BEFORE UPDATE ON mcp_servers
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert default MCP servers
INSERT INTO mcp_servers (name, description, transport_type, server_url, is_enabled, config, metadata)
VALUES 
  (
    'Solana Agent Kit MCP',
    'MCP server for Solana blockchain operations via Agent Kit',
    'http',
    'https://mcp.solana-agent-kit.com',
    TRUE,
    '{"timeout": 30000, "retries": 3}'::JSONB,
    '{"version": "2.0.0", "capabilities": ["token", "nft", "defi", "bridge"]}'::JSONB
  ),
  (
    'Helius RPC MCP',
    'MCP server for Helius RPC endpoints with SSE support',
    'sse',
    'https://mcp.helius.xyz/stream',
    TRUE,
    '{"timeout": 10000, "retries": 2, "reconnect": true}'::JSONB,
    '{"version": "1.0.0", "capabilities": ["rpc", "webhooks", "das"]}'::JSONB
  ),
  (
    'Pyth Price Feed MCP',
    'MCP server for Pyth Network price feeds',
    'http',
    'https://mcp.pyth.network',
    TRUE,
    '{"timeout": 5000, "cache_ttl": 30}'::JSONB,
    '{"version": "1.0.0", "capabilities": ["price_feed", "historical_data"]}'::JSONB
  )
ON CONFLICT (name) DO NOTHING;
