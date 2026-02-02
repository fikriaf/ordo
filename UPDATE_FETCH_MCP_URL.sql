-- Update Fetch MCP Server URL to new Railway deployment
-- Run this in Supabase SQL Editor

UPDATE mcp_servers
SET 
  server_url = 'https://fetch-mcp-server-production-666.up.railway.app',
  config = jsonb_set(
    jsonb_set(
      COALESCE(config, '{}'::jsonb),
      '{tools_path}',
      '"/sse"'
    ),
    '{execute_path}',
    '"/sse"'
  ),
  updated_at = NOW()
WHERE name = 'Fetch MCP Server';

-- Verify the update
SELECT 
  id,
  name,
  transport_type,
  server_url,
  is_enabled,
  config->>'tools_path' as tools_path,
  config->>'execute_path' as execute_path,
  config
FROM mcp_servers
WHERE name = 'Fetch MCP Server';
