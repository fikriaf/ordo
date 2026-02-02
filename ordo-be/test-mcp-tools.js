// Test MCP Tool Discovery
// Run with: node test-mcp-tools.js

const axios = require('axios');

const API_BASE = 'https://api.ordo-assistant.com/api/v1';
const ADMIN_EMAIL = 'admin@daemonprotocol.com';
const ADMIN_PASSWORD = 'Rade-OrdoApp-Mobile-Bekasi';

async function testMCPTools() {
  try {
    console.log('1. Logging in as admin...');
    const loginResponse = await axios.post(`${API_BASE}/auth/login`, {
      email: ADMIN_EMAIL,
      password: ADMIN_PASSWORD,
    });

    const token = loginResponse.data.data.token;
    console.log('✓ Login successful\n');

    const headers = {
      Authorization: `Bearer ${token}`,
    };

    console.log('2. Clearing MCP cache...');
    await axios.post(`${API_BASE}/admin/mcp-servers/cache/clear`, {}, { headers });
    console.log('✓ Cache cleared\n');

    console.log('3. Listing MCP servers...');
    const serversResponse = await axios.get(`${API_BASE}/admin/mcp-servers`, { headers });
    const servers = serversResponse.data.data;
    console.log(`✓ Found ${servers.length} MCP servers:`);
    servers.forEach(s => {
      console.log(`  - ${s.name} (${s.transport_type}) - ${s.is_enabled ? 'ENABLED' : 'DISABLED'}`);
      console.log(`    URL: ${s.server_url}`);
      console.log(`    Config: ${JSON.stringify(s.config)}`);
    });
    console.log('');

    console.log('4. Testing chat endpoint to trigger tool discovery...');
    const chatResponse = await axios.post(
      `${API_BASE}/chat`,
      {
        message: 'What tools do you have available?',
      },
      { headers }
    );

    console.log('✓ Chat response:', chatResponse.data.data.response);
    console.log('');

    console.log('5. Testing with a fetch request...');
    const fetchResponse = await axios.post(
      `${API_BASE}/chat`,
      {
        message: 'Fetch the content from https://example.com',
      },
      { headers }
    );

    console.log('✓ Fetch response:', fetchResponse.data.data.response);
    
  } catch (error) {
    console.error('✗ Error:', error.response?.data || error.message);
    if (error.response?.data) {
      console.error('Response data:', JSON.stringify(error.response.data, null, 2));
    }
  }
}

testMCPTools();
