# Ordo Backend - Gap Analysis & Missing Features

**Date**: February 3, 2026  
**Status**: Based on "Ordo Implementation Guide.md" review  
**Current Backend**: ordo-be (Express + TypeScript + Supabase)

---

## ✅ ALREADY IMPLEMENTED

### Core Infrastructure
- ✅ Express.js server with TypeScript
- ✅ Supabase database integration
- ✅ JWT authentication & authorization
- ✅ RBAC (Role-Based Access Control)
- ✅ Rate limiting middleware
- ✅ Error handling middleware
- ✅ Request sanitization
- ✅ Logging (Winston)
- ✅ Environment configuration
- ✅ Database migrations

### Authentication & User Management
- ✅ User registration & login
- ✅ JWT token generation & validation
- ✅ Admin user management
- ✅ Password hashing (bcrypt)
- ✅ User roles (user, admin)

### Wallet Management
- ✅ Wallet creation (Keypair generation)
- ✅ Wallet import (private key)
- ✅ Encrypted private key storage
- ✅ SOL balance queries
- ✅ SPL token balance queries
- ✅ Multi-wallet support per user
- ✅ Primary wallet designation

### Transaction Management
- ✅ Transaction recording
- ✅ Transaction status tracking (pending/confirmed/failed)
- ✅ Transaction history queries
- ✅ Transaction filtering & pagination
- ✅ Background transaction confirmation polling

### AI Agent Integration
- ✅ OpenRouter LLM integration
- ✅ Chat endpoint (streaming & non-streaming)
- ✅ Conversation history
- ✅ Tool/function calling support
- ✅ Plugin system architecture
- ✅ Basic Solana Agent Kit integration

### MCP (Model Context Protocol) Integration
- ✅ MCP server management (CRUD)
- ✅ MCP client service (HTTP & SSE)
- ✅ Dynamic tool discovery
- ✅ Tool execution routing
- ✅ MCP server enable/disable
- ✅ Cache management
- ✅ Admin & public endpoints

### API Endpoints
- ✅ `/api/v1/auth/*` - Authentication
- ✅ `/api/v1/wallet/*` - Wallet operations
- ✅ `/api/v1/transaction/*` - Transaction queries
- ✅ `/api/v1/chat/*` - AI chat (streaming & non-streaming)
- ✅ `/api/v1/health` - Health check
- ✅ `/api/v1/admin/mcp-servers/*` - MCP management
- ✅ `/api/v1/mcp-servers` - Public MCP list

---

## ❌ MISSING FEATURES (Critical for Frontend)

### 1. **Solana Agent Kit v2 Integration** ⚠️ HIGH PRIORITY

**Status**: Partially implemented (basic structure only)  
**Missing**:
- ❌ Full Solana Agent Kit v2 SDK integration
- ❌ Token swap operations (Jupiter, Raydium, Orca)
- ❌ Token transfer operations
- ❌ Staking operations (Marinade, Jito, Sanctum)
- ❌ NFT operations (mint, trade, transfer)
- ❌ DeFi protocol integrations (15+ protocols)
- ❌ Cross-chain bridge operations (Wormhole, Mayan, deBridge)
- ❌ Lending/borrowing (Kamino, MarginFi, Solend)
- ❌ Liquidity pool operations (Meteora, Raydium)

**Required Files**:
```
ordo-be/src/services/
├── solana-agent-kit.service.ts      # Main SAK wrapper
├── jupiter.service.ts                # Jupiter swap integration
├── raydium.service.ts                # Raydium integration
├── meteora.service.ts                # Meteora integration
├── nft.service.ts                    # NFT operations
├── staking.service.ts                # Staking operations
└── defi.service.ts                   # DeFi protocols
```

**API Endpoints Needed**:
```
POST /api/v1/swap/quote              # Get swap quote
POST /api/v1/swap/execute            # Execute swap
POST /api/v1/stake                   # Stake tokens
POST /api/v1/unstake                 # Unstake tokens
POST /api/v1/nft/mint                # Mint NFT
POST /api/v1/nft/transfer            # Transfer NFT
POST /api/v1/liquidity/add           # Add liquidity
POST /api/v1/liquidity/remove        # Remove liquidity
```

---

### 2. **Data & Analytics Services** ⚠️ HIGH PRIORITY

**Status**: Not implemented  
**Missing**:
- ❌ Helius API integration (transaction history, DAS API, webhooks)
- ❌ Birdeye API integration (market data, token analytics)
- ❌ Jupiter API integration (price feeds, token lists)
- ❌ Range Protocol integration (token risk scoring v1.8)
- ❌ Token risk analysis service
- ❌ Market data aggregation
- ❌ Portfolio analytics
- ❌ Real-time price feeds

**Required Files**:
```
ordo-be/src/services/
├── helius.service.ts                # Helius integration
├── birdeye.service.ts               # Birdeye integration
├── jupiter-api.service.ts           # Jupiter data API
├── range-protocol.service.ts        # Risk scoring
├── token-analytics.service.ts       # Token analysis
└── portfolio.service.ts             # Portfolio tracking
```

**API Endpoints Needed**:
```
GET  /api/v1/analytics/token/:address        # Token analytics
GET  /api/v1/analytics/portfolio/:userId     # Portfolio summary
GET  /api/v1/analytics/risk/:tokenAddress    # Risk score
GET  /api/v1/price/:symbol                   # Token price
GET  /api/v1/market/trending                 # Trending tokens
POST /api/v1/webhooks/helius                 # Helius webhook
```

---

### 3. **User Preferences & Settings** ⚠️ MEDIUM PRIORITY

**Status**: Not implemented  
**Missing**:
- ❌ User preferences table & service
- ❌ Risk management settings (max transfer, daily limits)
- ❌ Trading preferences (slippage, priority fees)
- ❌ Agent autonomy settings
- ❌ Notification preferences
- ❌ Approval thresholds

**Required Files**:
```
ordo-be/src/services/
└── user-preferences.service.ts

ordo-be/src/routes/
└── user-preferences.routes.ts
```

**Database Schema** (from guide):
```sql
CREATE TABLE user_preferences (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    max_single_transfer_sol DECIMAL(18, 9) DEFAULT 1.0,
    max_daily_volume_usdc DECIMAL(18, 2) DEFAULT 10000,
    require_approval_above_sol DECIMAL(18, 9) DEFAULT 0.5,
    default_slippage_bps INTEGER DEFAULT 50,
    agent_autonomy_level TEXT DEFAULT 'medium',
    notification_channels JSONB,
    ...
);
```

**API Endpoints Needed**:
```
GET  /api/v1/preferences              # Get user preferences
PUT  /api/v1/preferences              # Update preferences
POST /api/v1/preferences/reset        # Reset to defaults
```

---

### 4. **Approval Queue (Human-in-the-Loop)** ⚠️ HIGH PRIORITY

**Status**: Not implemented  
**Missing**:
- ❌ Approval queue table & service
- ❌ Approval request creation
- ❌ Approval/rejection workflow
- ❌ Real-time approval notifications
- ❌ Approval expiration handling
- ❌ Risk-based approval triggers

**Required Files**:
```
ordo-be/src/services/
└── approval.service.ts

ordo-be/src/routes/
└── approval.routes.ts
```

**Database Schema** (from guide):
```sql
CREATE TABLE approval_queue (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    request_type TEXT,
    pending_transaction JSONB,
    estimated_risk_score DECIMAL(5, 2),
    agent_reasoning TEXT,
    status TEXT DEFAULT 'pending',
    expires_at TIMESTAMPTZ,
    ...
);
```

**API Endpoints Needed**:
```
GET  /api/v1/approvals/pending        # Get pending approvals
POST /api/v1/approvals/:id/approve    # Approve request
POST /api/v1/approvals/:id/reject     # Reject request
GET  /api/v1/approvals/history        # Approval history
```

---

### 5. **Agent Memory & Context** ⚠️ MEDIUM PRIORITY

**Status**: Partially implemented (conversation history only)  
**Missing**:
- ❌ Vector embeddings for semantic search
- ❌ Long-term memory storage
- ❌ Learned preferences tracking
- ❌ Decision log storage
- ❌ Market insights storage
- ❌ Memory importance scoring
- ❌ Memory retrieval by similarity

**Required Files**:
```
ordo-be/src/services/
└── agent-memory.service.ts
```

**Database Schema** (from guide):
```sql
CREATE TABLE agent_memories (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    memory_type TEXT,
    content TEXT,
    embedding vector(1536),  -- OpenAI embeddings
    agent_id TEXT,
    importance_score DECIMAL(3, 2),
    ...
);
```

**API Endpoints Needed**:
```
POST /api/v1/memory/store             # Store memory
POST /api/v1/memory/search            # Semantic search
GET  /api/v1/memory/recent            # Recent memories
```

---

### 6. **Token Risk Scoring** ⚠️ HIGH PRIORITY

**Status**: Not implemented  
**Missing**:
- ❌ Token scores table & service
- ❌ Range Protocol Market Score v1.8 integration
- ❌ Limiting factors analysis
- ❌ Risk metrics calculation
- ❌ Token metadata caching
- ❌ Automated score updates

**Required Files**:
```
ordo-be/src/services/
├── token-risk.service.ts
└── range-protocol.service.ts
```

**Database Schema** (from guide):
```sql
CREATE TABLE token_scores (
    id UUID PRIMARY KEY,
    token_address TEXT UNIQUE,
    risk_score DECIMAL(5, 2),
    market_score DECIMAL(5, 2),
    limiting_factors JSONB,
    liquidity_score DECIMAL(5, 2),
    holder_score DECIMAL(5, 2),
    ...
);
```

**API Endpoints Needed**:
```
GET  /api/v1/tokens/:address/risk     # Get risk score
POST /api/v1/tokens/:address/analyze  # Analyze token
GET  /api/v1/tokens/risky             # List risky tokens
```

---

### 7. **NFT Management** ⚠️ MEDIUM PRIORITY

**Status**: Not implemented  
**Missing**:
- ❌ NFT collections table & service
- ❌ User NFTs tracking
- ❌ NFT metadata fetching (Helius DAS API)
- ❌ NFT floor price tracking
- ❌ NFT portfolio valuation
- ❌ Magic Eden / Tensor integration

**Required Files**:
```
ordo-be/src/services/
├── nft.service.ts
├── nft-marketplace.service.ts
└── nft-analytics.service.ts
```

**Database Schema** (from guide):
```sql
CREATE TABLE nft_collections (
    id UUID PRIMARY KEY,
    collection_address TEXT UNIQUE,
    floor_price_sol DECIMAL(18, 9),
    volume_24h_sol DECIMAL(18, 9),
    ...
);

CREATE TABLE user_nfts (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    mint_address TEXT UNIQUE,
    collection_id UUID REFERENCES nft_collections(id),
    ...
);
```

**API Endpoints Needed**:
```
GET  /api/v1/nfts/user/:userId        # User's NFTs
GET  /api/v1/nfts/collection/:address # Collection info
POST /api/v1/nfts/mint                # Mint NFT
POST /api/v1/nfts/transfer            # Transfer NFT
GET  /api/v1/nfts/portfolio/value     # Portfolio value
```

---

### 8. **Real-time Features** ⚠️ MEDIUM PRIORITY

**Status**: Not implemented  
**Missing**:
- ❌ Supabase Realtime subscriptions
- ❌ Transaction status updates (real-time)
- ❌ Approval queue notifications (real-time)
- ❌ Portfolio updates (real-time)
- ❌ WebSocket connections for mobile

**Required Files**:
```
ordo-be/src/services/
└── realtime.service.ts
```

**Implementation Needed**:
- Supabase Realtime channels
- WebSocket server for mobile clients
- Event broadcasting system

---

### 9. **Webhook Handlers** ⚠️ LOW PRIORITY

**Status**: Not implemented  
**Missing**:
- ❌ Helius webhook handler
- ❌ Birdeye webhook handler
- ❌ Webhook event logging
- ❌ Webhook signature verification
- ❌ Webhook retry logic

**Required Files**:
```
ordo-be/src/services/
└── webhook.service.ts

ordo-be/src/routes/
└── webhooks.routes.ts
```

**API Endpoints Needed**:
```
POST /api/v1/webhooks/helius          # Helius events
POST /api/v1/webhooks/birdeye         # Birdeye events
GET  /api/v1/webhooks/logs            # Webhook logs
```

---

### 10. **Agent Activity Logs** ⚠️ LOW PRIORITY

**Status**: Basic logging only  
**Missing**:
- ❌ Structured agent logs table
- ❌ Agent decision logging
- ❌ Agent performance metrics
- ❌ Agent error tracking
- ❌ Log querying & filtering

**Database Schema** (from guide):
```sql
CREATE TABLE agent_logs (
    id UUID PRIMARY KEY,
    agent_id TEXT,
    agent_type TEXT,
    level TEXT,
    message TEXT,
    user_id UUID,
    transaction_id UUID,
    metadata JSONB,
    ...
);
```

**API Endpoints Needed**:
```
GET  /api/v1/admin/logs/agents        # Agent logs
GET  /api/v1/admin/logs/errors        # Error logs
POST /api/v1/admin/logs/query         # Query logs
```

---

## 📊 PRIORITY MATRIX

### 🔴 CRITICAL (Must have for MVP)
1. **Solana Agent Kit v2 Integration** - Core blockchain operations
2. **Token Risk Scoring** - Safety & compliance
3. **Approval Queue** - User control & safety
4. **Data & Analytics Services** - Market intelligence

### 🟡 HIGH (Important for full functionality)
5. **User Preferences** - Customization
6. **NFT Management** - Complete feature set
7. **Real-time Features** - Better UX

### 🟢 MEDIUM (Nice to have)
8. **Agent Memory** - Enhanced AI capabilities
9. **Webhook Handlers** - Automation
10. **Agent Activity Logs** - Debugging & monitoring

---

## 🎯 RECOMMENDED IMPLEMENTATION ORDER

### Phase 1: Core Blockchain Operations (Week 1-2)
1. Solana Agent Kit v2 full integration
2. Jupiter swap service
3. Token transfer operations
4. Basic staking operations

### Phase 2: Safety & Risk Management (Week 2-3)
5. Token risk scoring service
6. Range Protocol integration
7. Approval queue system
8. User preferences

### Phase 3: Data & Analytics (Week 3-4)
9. Helius integration
10. Birdeye integration
11. Jupiter API integration
12. Portfolio analytics

### Phase 4: Advanced Features (Week 4-5)
13. NFT management
14. Real-time subscriptions
15. Agent memory with embeddings
16. Webhook handlers

### Phase 5: Monitoring & Optimization (Week 5-6)
17. Agent activity logs
18. Performance monitoring
19. Error tracking
20. Admin dashboard backend

---

## 📝 NOTES

- Current backend has solid foundation (auth, wallet, transactions, MCP)
- MCP integration is complete and working well
- Main gaps are in Solana-specific operations and analytics
- Frontend can start with existing endpoints while backend catches up
- Prioritize safety features (risk scoring, approvals) before advanced features

---

## 🔗 RELATED DOCUMENTS

- `Ordo Implementation Guide.md` - Full feature specification
- `ordo-be/README.md` - Current backend documentation
- `ordo-be/src/config/migrations.sql` - Current database schema
