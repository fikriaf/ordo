-- Update Fetch MCP Server configuration
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
SELECT id, name, transport_type, server_url, config
FROM mcp_servers
WHERE name = 'Fetch MCP Server';
