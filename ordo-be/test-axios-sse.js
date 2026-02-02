// Test axios SSE handling
const axios = require('axios');

const url = 'https://fetch-mcp-server-production-666.up.railway.app/sse';

console.log('Testing axios SSE connection...');
console.log('URL:', url);

let sessionEndpoint = null;
let buffer = '';

axios.get(url, {
  headers: {
    'Accept': 'text/event-stream',
    'Cache-Control': 'no-cache',
    'Connection': 'keep-alive',
  },
  responseType: 'stream',
  timeout: 0,
  httpAgent: new (require('http').Agent)({ keepAlive: true }),
  httpsAgent: new (require('https').Agent)({ keepAlive: true }),
})
  .then(response => {
    console.log('Connected! Status:', response.status);
    const stream = response.data;

    // Prevent stream from pausing
    stream.setEncoding('utf8');
    stream.resume();

    stream.on('data', (chunk) => {
      buffer += chunk.toString();
      const lines = buffer.split('\n');
      buffer = lines.pop() || '';

      for (const line of lines) {
        console.log('Line:', line);

        if (line.startsWith('data: ')) {
          const data = line.slice(6).trim();
          
          if (data.startsWith('/message')) {
            if (!sessionEndpoint) {
              sessionEndpoint = data;
              console.log('\n✓ SESSION FOUND:', sessionEndpoint);
              console.log('\nNow sending POST request...\n');
              
              // Send POST request
              const postUrl = `https://fetch-mcp-server-production-666.up.railway.app${sessionEndpoint}`;
              const requestId = Date.now();
              
              axios.post(postUrl, {
                jsonrpc: '2.0',
                method: 'tools/list',
                params: {},
                id: requestId,
              }, {
                headers: {
                  'Content-Type': 'application/json',
                },
                timeout: 10000,
              })
                .then(postResponse => {
                  console.log('POST response status:', postResponse.status);
                  console.log('POST response data:', JSON.stringify(postResponse.data));
                  console.log('\nWaiting for SSE response with id:', requestId);
                })
                .catch(error => {
                  console.error('POST error:', error.message);
                  if (error.response) {
                    console.error('Response status:', error.response.status);
                    console.error('Response data:', error.response.data);
                  }
                });
            }
          } else {
            // Try to parse as JSON
            try {
              const parsed = JSON.parse(data);
              console.log('\n✓ JSON RESPONSE:', JSON.stringify(parsed, null, 2));
              
              if (parsed.result && parsed.result.tools) {
                console.log('\n✓✓✓ TOOLS FOUND:', parsed.result.tools.length);
                parsed.result.tools.forEach(tool => {
                  console.log('  -', tool.name, ':', tool.description);
                });
                process.exit(0);
              }
            } catch (e) {
              // Not JSON
            }
          }
        }
      }
    });

    stream.on('error', (error) => {
      console.error('Stream error:', error.message);
      process.exit(1);
    });

    stream.on('end', () => {
      console.log('Stream ended');
      process.exit(1);
    });

    stream.on('close', () => {
      console.log('Stream closed');
    });
  })
  .catch(error => {
    console.error('Connection error:', error.message);
    process.exit(1);
  });

// Timeout after 60 seconds
setTimeout(() => {
  console.log('\nTimeout after 60 seconds');
  process.exit(1);
}, 60000);
