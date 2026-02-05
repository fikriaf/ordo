const http = require('http');

function makeRequest(path, method, body, token) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'localhost',
      port: 3000,
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
  // Login
  const loginRes = await makeRequest('/auth/login', 'POST', {
    email: 'admin@daemonprotocol.com',
    password: 'Rade-OrdoApp-Mobile-Bekasi',
  });
  
  const token = loginRes.data.token;

  // Get servers
  const serversRes = await makeRequest('/admin/mcp-servers', 'GET', null, token);
  
  console.log('MCP Servers in Database:\n');
  serversRes.data.forEach((s, i) => {
    console.log(`${i + 1}. ${s.name}`);
    console.log(`   ID: ${s.id}`);
    console.log(`   Transport: ${s.transport_type}`);
    console.log(`   URL: ${s.server_url}`);
    console.log(`   Enabled: ${s.is_enabled}`);
    console.log('');
  });
}

main().catch(console.error);
