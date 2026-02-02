-- Update MCP Server Endpoint Configurations
-- Run this in Supabase SQL Editor

-- Update Fetch MCP Server (SSE transport)
UPDATE mcp_servers
SET 
  config = jsonb_set(
    jsonb_set(
      COALESCE(config, '{}'::jsonb),
      '{tools_path}',
      '"/tools"'
    ),
    '{execute_path}',
    '"/tools/{name}"'
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
