// Add Risk Scoring MCP to database
const http = require('http');

const API_HOST = 'localhost';
const API_PORT = 3000;
const EMAIL = 'admin@daemonprotocol.com';
const PASSWORD = 'Rade-OrdoApp-Mobile-Bekasi';

function makeRequest(path, method, body, token) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: API_HOST,
      port: API_PORT,
      path: `/api/v1${path}`,
      method: method,
      headers: {
        'Content-Type': 'application/json',
      },
    };

    if (token) {
      options.headers['Authorization'] = `Bearer ${token}`;
    }

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => {
        data += chunk;
      });
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          resolve(data);
        }
      });
    });

    req.on('error', reject);

    if (body) {
      req.write(JSON.stringify(body));
    }
    req.end();
  });
}

async function main() {
  console.log('Adding Risk Scoring MCP Server...\n');

  // Login
  const loginRes = await makeRequest('/auth/login', 'POST', {
    email: EMAIL,
    password: PASSWORD,
  });
  
  const token = loginRes.data.token;
  console.log('✓ Logged in');

  // Add MCP server
  const mcpData = {
    name: 'Risk Scoring MCP',
    server_url: 'https://mcp-riskscoring-production.up.railway.app',
    transport_type: 'sse',
    description: 'risk assessment and compliance screening tools',
    is_enabled: true,
    config: {
      tools_path: '/tools',
      execute_path: '/tools/{name}',
    },
  };

  console.log('\nAdding MCP server:', mcpData.name);
  const addRes = await makeRequest('/admin/mcp-servers', 'POST', mcpData, token);
  
  if (addRes.success) {
    console.log('✓ MCP server added successfully!');
    console.log('  ID:', addRes.data.id);
    console.log('  Name:', addRes.data.name);
    console.log('  URL:', addRes.data.server_url);
    console.log('  Transport:', addRes.data.transport_type);
    
    // Test the server
    console.log('\nTesting MCP server...');
    const testRes = await makeRequest(`/admin/mcp-test/test/${addRes.data.id}`, 'POST', {}, token);
    
    if (testRes.success) {
      console.log('✓ Test successful!');
      console.log('  Tools found:', testRes.data.test.tools_found);
      console.log('  Duration:', testRes.data.test.duration_ms + 'ms');
      
      if (testRes.data.test.tools_found > 0) {
        console.log('\n  Available tools:');
        testRes.data.test.tools.forEach((tool, i) => {
          console.log(`    ${i + 1}. ${tool.originalName}`);
        });
      }
    } else {
      console.log('✗ Test failed:', testRes.data?.test?.error || testRes.error);
    }
  } else {
    console.log('✗ Failed to add MCP server:', addRes.error);
  }
}

main().catch(console.error);
