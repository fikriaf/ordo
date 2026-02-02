# Ordo Backend

REST API backend untuk Ordo - AI assistant yang dapat melakukan 60+ operasi blockchain Solana melalui natural language.

## 🚀 Features

- **Authentication & Authorization**: JWT-based auth dengan role-based access control
- **Wallet Management**: Create, import, dan query balance wallet Solana
- **AI Agent**: OpenRouter integration dengan function calling dan streaming
- **MCP Integration**: Connect to remote Model Context Protocol servers for extended capabilities
- **Plugin System**: Dynamic plugin registration untuk extensibility
- **Transaction Management**: Recording, tracking, dan history dengan pagination
- **Admin Panel**: Dashboard, user management, model management, plugin management, MCP server management
- **Security**: Rate limiting, input sanitization, encryption, error handling
- **Monitoring**: Health checks untuk semua dependencies

## 📋 Prerequisites

- Node.js >= 18.x
- npm atau yarn
- Supabase account (untuk database)
- OpenRouter API key
- Helius RPC API key (untuk Solana)

## 🛠️ Installation

1. Clone repository:
```bash
git clone <repository-url>
cd ordo-be
```

2. Install dependencies:
```bash
npm install
```

3. Setup environment variables:
```bash
cp .env.example .env
```

Edit `.env` dan isi dengan credentials Anda:
```env
# Server
NODE_ENV=development
PORT=3000
API_VERSION=v1

# Database (Supabase)
SUPABASE_URL=your_supabase_url
SUPABASE_KEY=your_supabase_anon_key

# JWT
JWT_SECRET=your_jwt_secret_key
JWT_EXPIRES_IN=24h

# Encryption
ENCRYPTION_KEY=your_32_character_encryption_key

# Solana
SOLANA_RPC_URL=https://devnet.helius-rpc.com/?api-key=your_helius_key

# OpenRouter
OPENROUTER_API_KEY=your_openrouter_api_key
OPENROUTER_BASE_URL=https://openrouter.ai/api/v1

# AI Models (comma-separated, first is primary)
AI_MODELS=deepseek/deepseek-chat,google/gemini-3-flash-preview,anthropic/claude-sonnet-4,xiaomi/mimo-v2-flash:free,mistralai/devstral-2-2512:free
```

4. Run database migrations:
```bash
# Execute migrations.sql di Supabase SQL Editor
# File: src/config/migrations.sql
```

5. Build project:
```bash
npm run build
```

## 🚀 Running the Application

### Development Mode
```bash
npm run dev
```

### Production Mode
```bash
npm run build
npm start
```

Server akan berjalan di `http://localhost:3000`

## 📚 API Documentation

Lihat [API.md](./API.md) untuk dokumentasi lengkap semua endpoints.

### Quick Start

1. **Register User**:
```bash
curl -X POST http://localhost:3000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"Pass123!","name":"John Doe"}'
```

2. **Login**:
```bash
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"Pass123!"}'
```

3. **Create Wallet**:
```bash
curl -X POST http://localhost:3000/api/v1/wallet/create \
  -H "Authorization: Bearer <your_token>"
```

4. **Chat with AI**:

```
ordo-be/
├── src/
│   ├── config/          # Configuration files
│   │   ├── database.ts  # Supabase client
│   │   ├── env.ts       # Environment validation
│   │   ├── logger.ts    # Winston logger
│   │   └── migrations.sql
│   ├── middleware/      # Express middlewares
│   │   ├── auth.middleware.ts
│   │   ├── rate-limit.middleware.ts
│   │   ├── sanitization.middleware.ts
│   │   └── error-handler.middleware.ts
│   ├── routes/          # API routes
│   │   ├── auth.routes.ts
│   │   ├── wallet.routes.ts
│   │   ├── chat.routes.ts
│   │   ├── action.routes.ts
│   │   ├── transaction.routes.ts
│   │   ├── admin.routes.ts
│   │   └── health.routes.ts
│   ├── services/        # Business logic
│   │   ├── auth.service.ts
│   │   ├── wallet.service.ts
│   │   ├── ai-agent.service.ts
│   │   ├── mcp-client.service.ts
│   │   ├── mcp-server.service.ts
│   │   ├── plugin-manager.service.ts
│   │   ├── solana-agent.service.ts
│   │   ├── transaction.service.ts
│   │   ├── conversation.service.ts
│   │   ├── admin.service.ts
│   │   ├── ai-model.service.ts
│   │   ├── plugin-admin.service.ts
│   │   ├── config.service.ts
│   │   └── health.service.ts
│   ├── types/           # TypeScript types
│   │   ├── index.ts
│   │   └── plugin.ts
│   ├── utils/           # Utility functions
│   │   ├── encryption.ts
│   │   └── retry.ts
│   ├── app.ts           # Express app setup
│   ├── server.ts        # Server entry point
│   └── index.ts         # Main entry point
├── scripts/             # Utility scripts
│   ├── create-admin.ts
│   └── update-user-role.ts
├── tests/               # Test files
├── logs/                # Log files
├── .env.example         # Environment template
├── API.md               # API documentation
├── package.json
├── tsconfig.json
└── README.md
```

## 🔐 Security Features

### Authentication
- JWT tokens dengan 24-hour expiration
- Bcrypt password hashing (10 salt rounds)
- Role-based access control (user/admin)

### Encryption
- AES-256-GCM untuk private keys
- Secure random encryption keys
- Auth tags untuk integrity verification

### Rate Limiting
- Global: 100 requests/minute per IP
- Auth endpoints: 10 requests/minute per IP
- Admin endpoints: 50 requests/minute per IP

### Input Sanitization
- SQL injection protection
- XSS attack prevention
- Malicious input logging

### Error Handling
- Centralized error handler
- Sensitive data redaction
- Retry logic dengan exponential backoff

## 🎯 Admin Features

### Create Admin User
```bash
npm run build
npx tsx scripts/update-user-role.ts user@example.com admin
```

### Admin Endpoints
- Dashboard metrics
- User management (list, view, delete)
- AI model management (CRUD, enable/disable)
- Plugin management (CRUD, enable/disable)
- MCP server management (CRUD, enable/disable, cache control)
- Configuration management (hot reload, history, rollback)
- Audit logs

## 🔌 MCP Integration

Ordo Backend supports Model Context Protocol (MCP) servers for extending AI capabilities with remote tools.

### Supported Transport Types
- **HTTP**: Standard HTTP requests
- **SSE**: Server-Sent Events for streaming
- **STDIO**: Not supported on Railway deployment

### MCP Features
- Dynamic tool discovery from remote servers
- Tool caching (5-minute TTL) for performance
- Automatic tool merging with local plugins
- Per-server authentication (API keys, custom headers)
- Enable/disable servers without deletion
- Cache management for updated servers

### Adding MCP Servers

Use admin endpoints to add MCP servers:

```bash
curl -X POST http://localhost:3000/api/v1/admin/mcp-servers \
  -H "Authorization: Bearer <admin_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "weather-mcp",
    "description": "Weather data provider",
    "transport_type": "http",
    "server_url": "https://weather-mcp.example.com",
    "api_key": "your_api_key",
    "headers": {
      "X-Custom-Header": "value"
    },
    "is_enabled": true,
    "config": {
      "timeout": 30000
    }
  }'
```

### How It Works

1. **Tool Discovery**: When AI agent starts, it fetches tools from all enabled MCP servers
2. **Tool Merging**: MCP tools are merged with local plugin tools
3. **Tool Naming**: MCP tools are prefixed with server name (e.g., `weather-mcp__get_forecast`)
4. **Tool Execution**: AI decides which tool to use, backend routes to appropriate service
5. **Caching**: Tools are cached for 5 minutes to reduce latency

### MCP Endpoints

**Public**:
- `GET /api/v1/mcp-servers` - List enabled servers (no sensitive data)

**Admin**:
- `GET /api/v1/admin/mcp-servers` - List all servers
- `GET /api/v1/admin/mcp-servers/:id` - Get server details
- `POST /api/v1/admin/mcp-servers` - Create server
- `PUT /api/v1/admin/mcp-servers/:id` - Update server
- `DELETE /api/v1/admin/mcp-servers/:id` - Delete server
- `PUT /api/v1/admin/mcp-servers/:id/enable` - Enable server
- `PUT /api/v1/admin/mcp-servers/:id/disable` - Disable server
- `POST /api/v1/admin/mcp-servers/cache/clear` - Clear tools cache

## 📊 Monitoring

### Health Checks
- **Basic**: `GET /health`
- **Detailed**: `GET /health/detailed`

Detailed health check monitors:
- Database connectivity (Supabase)
- Solana RPC connectivity (Helius)
- OpenRouter API connectivity

## 🧪 Testing

```bash
# Run all tests
npm test

# Run tests in watch mode
npm run test:watch
```

## 🐛 Debugging

Logs tersimpan di folder `logs/`:
- `app.log` - All logs
- `app-error.log` - Error logs only

Log format: JSON dengan timestamp, level, message, dan context.

## 🚢 Deployment

### Environment Variables for Production
```env
NODE_ENV=production
PORT=3000
# ... other variables
```

### Docker (Coming Soon)
```bash
docker build -t ordo-backend .
docker run -p 3000:3000 ordo-backend
```

## 📝 License

MIT

## 🤝 Contributing

1. Fork repository
2. Create feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to branch (`git push origin feature/AmazingFeature`)
5. Open Pull Request

## 📧 Support

Untuk pertanyaan atau issues, silakan buka issue di GitHub repository.

## 🙏 Acknowledgments

- [Solana Agent Kit](https://github.com/sendaifun/solana-agent-kit) - Solana blockchain operations
- [OpenRouter](https://openrouter.ai/) - LLM API aggregator
- [Supabase](https://supabase.com/) - Database dan authentication
- [Helius](https://helius.dev/) - Solana RPC provider
