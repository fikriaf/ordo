# Design Document: Ordo Backend

## Overview

Ordo Backend adalah REST API berbasis Express TypeScript yang menyediakan backend untuk aplikasi Android AI assistant "Ordo". Sistem ini mengintegrasikan multiple LLM models melalui OpenRouter, Solana blockchain operations melalui Solana Agent Kit, dan menyediakan plugin architecture yang extensible untuk menambahkan protocol integrations baru.

### Key Design Principles

1. **Modularity**: Plugin-based architecture untuk easy extensibility
2. **Security**: Encryption-at-rest untuk private keys, JWT authentication, rate limiting
3. **Scalability**: Stateless API design, horizontal scaling ready
4. **Observability**: Comprehensive logging, monitoring, dan error tracking
5. **Clean Architecture**: Separation of concerns dengan layered architecture

### Technology Stack

- **Runtime**: Node.js 20+ dengan TypeScript 5+
- **Framework**: Express.js 4.x
- **Database**: Supabase (PostgreSQL 15+)
- **LLM**: OpenRouter SDK
- **Blockchain**: Solana Agent Kit, @solana/web3.js
- **Authentication**: JWT (jsonwebtoken)
- **Encryption**: crypto (AES-256-GCM)
- **Validation**: Zod
- **Logging**: Winston
- **Testing**: Jest, fast-check (property-based testing)

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Android App (Ordo)                       │
└────────────────────────┬────────────────────────────────────┘
                         │ HTTPS/REST
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                    Express API Server                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Auth       │  │   Chat       │  │   Admin      │      │
│  │   Routes     │  │   Routes     │  │   Routes     │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │                  │                  │              │
│  ┌──────▼──────────────────▼──────────────────▼───────┐    │
│  │           Middleware Layer                          │    │
│  │  (Auth, Rate Limit, Validation, Error Handler)     │    │
│  └──────┬──────────────────┬──────────────────┬───────┘    │
│         │                  │                  │              │
│  ┌──────▼───────┐  ┌──────▼───────┐  ┌──────▼───────┐     │
│  │   Auth       │  │   AI Agent   │  │   Admin      │     │
│  │   Service    │  │   Service    │  │   Service    │     │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘     │
│         │                  │                  │              │
│  ┌──────▼──────────────────▼──────────────────▼───────┐    │
│  │              Core Services Layer                    │    │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐         │    │
│  │  │ Wallet   │  │ Plugin   │  │ Transaction│        │    │
│  │  │ Service  │  │ Manager  │  │ Service    │        │    │
│  │  └────┬─────┘  └────┬─────┘  └────┬───────┘        │    │
│  └───────┼─────────────┼─────────────┼────────────────┘    │
└──────────┼─────────────┼─────────────┼─────────────────────┘
           │             │             │
    ┌──────▼─────┐ ┌────▼─────┐ ┌────▼──────┐
    │  Supabase  │ │ OpenRouter│ │  Solana   │
    │    DB      │ │    API    │ │    RPC    │
    └────────────┘ └───────────┘ └───────────┘
```

### Layered Architecture

**1. Presentation Layer (Routes)**
- Express route handlers
- Request validation using Zod schemas
- Response formatting

**2. Application Layer (Services)**
- Business logic implementation
- Service orchestration
- Transaction management

**3. Domain Layer (Models & Entities)**
- Domain models and types
- Business rules
- Value objects

**4. Infrastructure Layer**
- Database access (Supabase client)
- External API clients (OpenRouter, Solana RPC)
- Encryption utilities
- Logging and monitoring

### Plugin Architecture

```typescript
interface Plugin {
  id: string;
  name: string;
  version: string;
  enabled: boolean;
  actions: Action[];
  initialize(): Promise<void>;
  cleanup(): Promise<void>;
}

interface Action {
  name: string;
  description: string;
  parameters: ActionParameter[];
  execute(params: Record<string, any>, context: ExecutionContext): Promise<ActionResult>;
}
```

Plugins are dynamically loaded at runtime and registered with the PluginManager. The AI Agent discovers available actions from all enabled plugins.

## Components and Interfaces

### 1. Authentication Service

**Responsibilities:**
- User registration and login
- JWT token generation and validation
- Password hashing and verification

**Interface:**
```typescript
interface AuthService {
  register(email: string, password: string, username: string): Promise<User>;
  login(email: string, password: string): Promise<{ user: User; token: string }>;
  validateToken(token: string): Promise<User>;
  hashPassword(password: string): Promise<string>;
  verifyPassword(password: string, hash: string): Promise<boolean>;
}
```

### 2. Wallet Service

**Responsibilities:**
- Keypair generation and encryption
- Wallet import and export
- Balance queries
- Private key decryption (in-memory only)

**Interface:**
```typescript
interface WalletService {
  createWallet(userId: string): Promise<Wallet>;
  importWallet(userId: string, privateKey: string): Promise<Wallet>;
  getWalletBalance(walletId: string): Promise<Balance>;
  encryptPrivateKey(privateKey: string): Promise<EncryptedData>;
  decryptPrivateKey(encryptedData: EncryptedData): Promise<string>;
  getKeypair(walletId: string): Promise<Keypair>; // Decrypts in memory
}

interface EncryptedData {
  ciphertext: string;
  iv: string;
  authTag: string;
  algorithm: 'aes-256-gcm';
}

interface Balance {
  sol: number;
  tokens: TokenBalance[];
}

interface TokenBalance {
  mint: string;
  amount: number;
  decimals: number;
  symbol?: string;
}
```

### 3. AI Agent Service

**Responsibilities:**
- Natural language processing
- Intent recognition and action mapping
- Parameter extraction
- LLM interaction via OpenRouter with function calling
- Action execution orchestration

**Function Calling Architecture:**

The AI Agent uses OpenRouter's function calling capability (similar to OpenAI's function calling). When a user sends a message:

1. **Tool Registration**: All available actions from enabled plugins are registered as "tools" in the LLM prompt
2. **LLM Decision**: The LLM analyzes the user's message and decides whether to call a tool
3. **Tool Execution**: If the LLM calls a tool, the backend executes the corresponding action
4. **Response Generation**: The LLM generates a natural language response based on the tool execution result

**Example Flow:**
```
User: "Swap 1 SOL for USDC"
  ↓
LLM receives message + available tools (swap_tokens, transfer_tokens, etc.)
  ↓
LLM decides to call: swap_tokens(from="SOL", to="USDC", amount=1)
  ↓
Backend executes swap via Solana Agent Kit
  ↓
LLM receives result: {signature: "abc123...", status: "success"}
  ↓
LLM generates response: "I've swapped 1 SOL for USDC. Transaction signature: abc123..."
```

**Interface:**
```typescript
interface AIAgentService {
  processMessage(
    userId: string,
    conversationId: string,
    message: string
  ): Promise<AgentResponse>;
  
  processMessageStream(
    userId: string,
    conversationId: string,
    message: string,
    onToken: (token: string) => void
  ): Promise<void>;
  
  // Register all available actions as LLM tools
  getAvailableTools(): Tool[];
  
  // Execute tool called by LLM
  executeTool(toolName: string, parameters: Record<string, any>, context: ExecutionContext): Promise<ToolResult>;
}

interface Tool {
  name: string;
  description: string;
  parameters: {
    type: 'object';
    properties: Record<string, {
      type: string;
      description: string;
      enum?: string[];
    }>;
    required: string[];
  };
}

interface ToolResult {
  success: boolean;
  data?: any;
  error?: string;
}

interface AgentResponse {
  message: string;
  toolCalls?: ToolCall[];
  conversationId: string;
}

interface ToolCall {
  toolName: string;
  parameters: Record<string, any>;
  result: ToolResult;
}

interface ExecutionContext {
  userId: string;
  walletId: string;
  conversationId: string;
}
```

### 4. Plugin Manager

**Responsibilities:**
- Plugin registration and lifecycle management
- Action discovery and routing
- Plugin enable/disable
- Dependency resolution

**Interface:**
```typescript
interface PluginManager {
  registerPlugin(plugin: Plugin): Promise<void>;
  unregisterPlugin(pluginId: string): Promise<void>;
  enablePlugin(pluginId: string): Promise<void>;
  disablePlugin(pluginId: string): Promise<void>;
  getPlugin(pluginId: string): Plugin | undefined;
  getAllPlugins(): Plugin[];
  getEnabledPlugins(): Plugin[];
  getAvailableActions(): Action[];
  executeAction(actionName: string, params: Record<string, any>, context: ExecutionContext): Promise<ActionResult>;
}
```

### 5. Transaction Service

**Responsibilities:**
- Transaction recording and tracking
- Status polling and updates
- Transaction history queries

**Interface:**
```typescript
interface TransactionService {
  recordTransaction(tx: TransactionInput): Promise<Transaction>;
  updateTransactionStatus(txId: string, status: TransactionStatus): Promise<void>;
  getTransactionHistory(userId: string, filters: TransactionFilters): Promise<PaginatedResult<Transaction>>;
  pollTransactionStatus(signature: string): Promise<TransactionStatus>;
}

interface TransactionInput {
  userId: string;
  walletId: string;
  type: string;
  signature: string;
  status: TransactionStatus;
  metadata: Record<string, any>;
}

enum TransactionStatus {
  PENDING = 'pending',
  CONFIRMED = 'confirmed',
  FAILED = 'failed'
}

interface TransactionFilters {
  type?: string;
  status?: TransactionStatus;
  startDate?: Date;
  endDate?: Date;
  page: number;
  limit: number;
}
```

### 6. Solana Agent Kit Integration

**Responsibilities:**
- Wrapping Solana Agent Kit operations
- Providing unified interface for blockchain operations
- Error handling and retry logic

**Interface:**
```typescript
interface SolanaAgentService {
  // Token operations
  deployToken(params: DeployTokenParams): Promise<string>; // Returns mint address
  transferToken(params: TransferParams): Promise<string>; // Returns signature
  swapTokens(params: SwapParams): Promise<string>;
  stakeTokens(params: StakeParams): Promise<string>;
  
  // NFT operations
  mintNFT(params: MintNFTParams): Promise<string>; // Returns mint address
  transferNFT(params: TransferNFTParams): Promise<string>;
  listNFT(params: ListNFTParams): Promise<string>;
  
  // DeFi operations
  lendAssets(params: LendParams): Promise<string>;
  borrowAssets(params: BorrowParams): Promise<string>;
  
  // Price feeds
  getTokenPrice(mint: string): Promise<number>;
  
  // Bridge operations
  bridgeAssets(params: BridgeParams): Promise<string>;
}
```

### 7. Admin Service

**Responsibilities:**
- Dashboard metrics aggregation
- User management
- Configuration management
- Audit logging

**Interface:**
```typescript
interface AdminService {
  getDashboardMetrics(): Promise<DashboardMetrics>;
  getUsers(filters: UserFilters): Promise<PaginatedResult<User>>;
  getTransactions(filters: AdminTransactionFilters): Promise<PaginatedResult<Transaction>>;
  updateConfiguration(config: Partial<SystemConfig>): Promise<void>;
  getConfiguration(): Promise<SystemConfig>;
  manageModels(): Promise<AIModel[]>;
  managePlugins(): Promise<Plugin[]>;
  logAuditEvent(event: AuditEvent): Promise<void>;
}

interface DashboardMetrics {
  activeUsers: number;
  totalTransactions: number;
  successRate: number;
  averageResponseTime: number;
  errorRate: number;
}
```

## Data Models

### Database Schema (Supabase/PostgreSQL)

**users table:**
```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) UNIQUE NOT NULL,
  username VARCHAR(100) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  last_login TIMESTAMP
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
```

**wallets table:**
```sql
CREATE TABLE wallets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  public_key VARCHAR(44) UNIQUE NOT NULL,
  encrypted_private_key TEXT NOT NULL,
  encryption_iv VARCHAR(32) NOT NULL,
  encryption_auth_tag VARCHAR(32) NOT NULL,
  encryption_algorithm VARCHAR(20) DEFAULT 'aes-256-gcm',
  is_primary BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_wallets_user_id ON wallets(user_id);
CREATE INDEX idx_wallets_public_key ON wallets(public_key);
```

**transactions table:**
```sql
CREATE TABLE transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  wallet_id UUID NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
  signature VARCHAR(88) UNIQUE NOT NULL,
  type VARCHAR(50) NOT NULL,
  status VARCHAR(20) NOT NULL,
  block_number BIGINT,
  error_message TEXT,
  metadata JSONB,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_transactions_user_id ON transactions(user_id);
CREATE INDEX idx_transactions_wallet_id ON transactions(wallet_id);
CREATE INDEX idx_transactions_status ON transactions(status);
CREATE INDEX idx_transactions_type ON transactions(type);
CREATE INDEX idx_transactions_created_at ON transactions(created_at DESC);
```

**conversations table:**
```sql
CREATE TABLE conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title VARCHAR(255),
  is_archived BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  last_message_at TIMESTAMP
);

CREATE INDEX idx_conversations_user_id ON conversations(user_id);
CREATE INDEX idx_conversations_last_message_at ON conversations(last_message_at DESC);
```

**messages table:**
```sql
CREATE TABLE messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  role VARCHAR(20) NOT NULL, -- 'user' or 'assistant'
  content TEXT NOT NULL,
  metadata JSONB,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_messages_conversation_id ON messages(conversation_id);
CREATE INDEX idx_messages_created_at ON messages(created_at);
```

**ai_models table:**
```sql
CREATE TABLE ai_models (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) UNIQUE NOT NULL,
  provider VARCHAR(50) NOT NULL,
  model_id VARCHAR(100) NOT NULL,
  is_enabled BOOLEAN DEFAULT true,
  is_default BOOLEAN DEFAULT false,
  config JSONB,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_ai_models_is_enabled ON ai_models(is_enabled);
```

**plugins table:**
```sql
CREATE TABLE plugins (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) UNIQUE NOT NULL,
  version VARCHAR(20) NOT NULL,
  is_enabled BOOLEAN DEFAULT true,
  config JSONB,
  installed_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_plugins_is_enabled ON plugins(is_enabled);
```

**admin_configs table:**
```sql
CREATE TABLE admin_configs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key VARCHAR(100) UNIQUE NOT NULL,
  value JSONB NOT NULL,
  description TEXT,
  updated_at TIMESTAMP DEFAULT NOW(),
  updated_by UUID REFERENCES users(id)
);

CREATE INDEX idx_admin_configs_key ON admin_configs(key);
```

**audit_logs table:**
```sql
CREATE TABLE audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID NOT NULL REFERENCES users(id),
  action VARCHAR(100) NOT NULL,
  resource_type VARCHAR(50),
  resource_id UUID,
  details JSONB,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_audit_logs_admin_id ON audit_logs(admin_id);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at DESC);
```

### TypeScript Domain Models

```typescript
interface User {
  id: string;
  email: string;
  username: string;
  passwordHash: string;
  createdAt: Date;
  updatedAt: Date;
  lastLogin?: Date;
}

interface Wallet {
  id: string;
  userId: string;
  publicKey: string;
  encryptedPrivateKey: string;
  encryptionIv: string;
  encryptionAuthTag: string;
  encryptionAlgorithm: string;
  isPrimary: boolean;
  createdAt: Date;
}

interface Transaction {
  id: string;
  userId: string;
  walletId: string;
  signature: string;
  type: string;
  status: TransactionStatus;
  blockNumber?: number;
  errorMessage?: string;
  metadata: Record<string, any>;
  createdAt: Date;
  updatedAt: Date;
}

interface Conversation {
  id: string;
  userId: string;
  title?: string;
  isArchived: boolean;
  createdAt: Date;
  updatedAt: Date;
  lastMessageAt?: Date;
}

interface Message {
  id: string;
  conversationId: string;
  role: 'user' | 'assistant';
  content: string;
  metadata?: Record<string, any>;
  createdAt: Date;
}

interface AIModel {
  id: string;
  name: string;
  provider: string;
  modelId: string;
  isEnabled: boolean;
  isDefault: boolean;
  config?: Record<string, any>;
  createdAt: Date;
}

interface Plugin {
  id: string;
  name: string;
  version: string;
  isEnabled: boolean;
  config?: Record<string, any>;
  installedAt: Date;
  updatedAt: Date;
}

interface AdminConfig {
  id: string;
  key: string;
  value: any;
  description?: string;
  updatedAt: Date;
  updatedBy?: string;
}

interface AuditLog {
  id: string;
  adminId: string;
  action: string;
  resourceType?: string;
  resourceId?: string;
  details?: Record<string, any>;
  createdAt: Date;
}
```


## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property Reflection

After analyzing all 100 acceptance criteria, I identified several areas where properties can be consolidated:

**Consolidations Made:**
1. **Encryption properties (2.5, 13.4)**: Combined into single property about encryption implementation
2. **Response format properties (14.1, 14.2)**: Combined into single property about consistent API responses
3. **Health check properties (20.1, 20.2, 20.3)**: Combined into single property about dependency verification
4. **Transaction recording (5.6, 6.3, 6.4)**: Consolidated into transaction lifecycle property
5. **Plugin action availability (7.2, 7.3)**: Combined into single property about plugin state affecting action availability

This reduces redundancy while maintaining comprehensive coverage of all testable requirements.

### Authentication and Authorization Properties

**Property 1: Password Hashing Security**
*For any* user registration with a password, the stored password hash must use bcrypt with at least 10 salt rounds, and verifying the original password against the hash must succeed.
**Validates: Requirements 1.1, 1.5**

**Property 2: JWT Token Validity**
*For any* successful login, the returned JWT token must be valid, decodable, contain the correct user ID, and have an expiration time of 24 hours from issuance.
**Validates: Requirements 1.2**

**Property 3: Invalid Token Rejection**
*For any* malformed, expired, or tampered JWT token, authentication must fail and return 401 Unauthorized status.
**Validates: Requirements 1.3, 1.4**

### Wallet Management Properties

**Property 4: Wallet Creation Encryption**
*For any* wallet creation request, the generated keypair must be stored with AES-256-GCM encryption, and the encrypted data must include IV and auth tag metadata.
**Validates: Requirements 2.1, 2.5, 13.4**

**Property 5: Wallet Import Round Trip**
*For any* valid Solana private key, importing the wallet then retrieving the keypair (decrypted in memory) must produce a keypair that matches the original private key.
**Validates: Requirements 2.2**

**Property 6: Private Key Non-Exposure**
*For any* wallet API response (balance queries, wallet info), the response JSON must never contain the private key or any substring of the private key.
**Validates: Requirements 2.3**

**Property 7: Balance Query Format**
*For any* wallet balance request, the response must include SOL balance as a number and tokens as an array where each token has mint, amount, and decimals fields.
**Validates: Requirements 2.4**

### AI Chat Interface Properties

**Property 8: Intent Recognition Completeness**
*For any* chat message that contains a recognizable action keyword, the AI Agent must identify at least one valid action with confidence score, or return a clarification request.
**Validates: Requirements 3.1**

**Property 9: Pre-Execution Validation**
*For any* identified action, execution must only proceed if the user has a valid wallet and appropriate permissions; otherwise, a clear error must be returned.
**Validates: Requirements 3.2**

**Property 10: Parameter Extraction Completeness**
*For any* action requiring parameters, the AI Agent must either extract all required parameters from the message or explicitly request the missing parameters.
**Validates: Requirements 3.3**

**Property 11: Response Format Consistency**
*For any* API request, the response must follow the format `{success: true, data: {...}}` for successes or `{success: false, error: {code, message}}` for failures.
**Validates: Requirements 3.4, 3.5, 14.1, 14.2**

### Streaming Properties

**Property 12: Token Streaming Incrementality**
*For any* streaming chat request, response tokens must be sent incrementally (not all at once), and the total concatenated tokens must equal the complete response.
**Validates: Requirements 4.2**

**Property 13: Stream Completion Signal**
*For any* completed streaming response, a completion event must be sent before closing the connection, and the connection must close gracefully without errors.
**Validates: Requirements 4.4**

**Property 14: Concurrent Streaming Support**
*For any* set of concurrent streaming requests from different users, each stream must receive its own independent responses without cross-contamination.
**Validates: Requirements 4.5**

### Blockchain Operations Properties

**Property 15: Transaction Recording Lifecycle**
*For any* blockchain operation (swap, deploy, mint, lend, etc.), a transaction record must be created with "pending" status, and the status must eventually update to either "confirmed" (with block number) or "failed" (with error details).
**Validates: Requirements 5.6, 6.3, 6.4**

**Property 16: Token Swap Execution**
*For any* valid token swap request with sufficient balance, the operation must return a valid Solana transaction signature (88 characters, base58 encoded).
**Validates: Requirements 5.1**

**Property 17: Token Deployment Parameters**
*For any* token deployment request with specified parameters (name, symbol, decimals), the created SPL token must have metadata matching those parameters.
**Validates: Requirements 5.2**

**Property 18: NFT Minting Validity**
*For any* NFT mint request with metadata URI, the operation must return a valid mint address (base58 encoded public key), and the NFT must be owned by the user's wallet.
**Validates: Requirements 5.3**

**Property 19: Price Feed Availability**
*For any* token with a Pyth price feed, requesting the price must return a numeric value greater than zero or a staleness indicator if data is unavailable.
**Validates: Requirements 5.5, 17.1, 17.2**

### Transaction History Properties

**Property 20: Transaction Pagination and Ordering**
*For any* transaction history request with page and limit parameters, the response must contain at most `limit` transactions, ordered by timestamp descending, and include pagination metadata (total, page, hasNext).
**Validates: Requirements 6.1**

**Property 21: Transaction Status Polling**
*For any* transaction in "pending" status, the system must poll Solana RPC for confirmation, and the status must eventually transition to "confirmed" or "failed".
**Validates: Requirements 6.2**

**Property 22: Transaction Filtering**
*For any* transaction history request with filters (type, status, date range), all returned transactions must match the specified filter criteria.
**Validates: Requirements 6.5**

### Plugin System Properties

**Property 23: Plugin Action Registration**
*For any* installed plugin, all actions defined by the plugin must be registered and discoverable via the action registry.
**Validates: Requirements 7.1**

**Property 24: Plugin State Affects Action Availability**
*For any* plugin, its actions must be executable when the plugin is enabled, and must be blocked (returning an error) when the plugin is disabled.
**Validates: Requirements 7.2, 7.3**

**Property 25: Plugin Uninstall Cleanup**
*For any* uninstalled plugin, no plugin data, actions, or configuration must remain in the system (database or memory).
**Validates: Requirements 7.4**

**Property 26: Plugin Compatibility Validation**
*For any* plugin installation attempt, the system must validate compatibility (version, dependencies) and reject incompatible plugins before installation.
**Validates: Requirements 7.5**

### AI Model Management Properties

**Property 27: Model Registration Configuration**
*For any* added AI model, the model must be registered with OpenRouter configuration (API key, model ID, parameters) and be queryable from the models list.
**Validates: Requirements 8.1**

**Property 28: Default Model Usage**
*For any* new conversation created after setting a default model, the conversation must use that default model unless explicitly overridden.
**Validates: Requirements 8.2**

**Property 29: Disabled Model Blocking**
*For any* disabled AI model, attempts to create new conversations using that model must be rejected with a clear error message.
**Validates: Requirements 8.3**

**Property 30: Model Fallback on Failure**
*For any* model API call that fails, the system must log the error and attempt to use an alternative enabled model if available.
**Validates: Requirements 8.4**

**Property 31: Model Usage Tracking**
*For any* model API call, usage statistics (request count, token count, estimated cost) must be recorded and aggregatable.
**Validates: Requirements 8.5**

### Admin and Monitoring Properties

**Property 32: Dashboard Metrics Accuracy**
*For any* dashboard metrics request, the returned data must accurately reflect current system state (active users count matches users with recent activity, transaction counts match database records).
**Validates: Requirements 9.1**

**Property 33: Admin Action Audit Logging**
*For any* admin action (add model, disable plugin, update config), an audit log entry must be created with timestamp, admin ID, action type, and affected resource.
**Validates: Requirements 9.4**

**Property 34: Performance Metrics Calculation**
*For any* performance metrics request, calculated values (average response time, error rate) must be mathematically correct based on recorded data.
**Validates: Requirements 9.5**

### Configuration Management Properties

**Property 35: Configuration Validation**
*For any* configuration update, the new values must be validated against the schema, and invalid updates must be rejected with detailed validation errors.
**Validates: Requirements 10.1, 10.3**

**Property 36: Configuration Hot Reload**
*For any* valid configuration update, the changes must take effect immediately without requiring server restart, and subsequent requests must use the new configuration.
**Validates: Requirements 10.2**

**Property 37: Configuration History and Rollback**
*For any* configuration change, the previous configuration must be stored in history, and rolling back must restore the exact previous state.
**Validates: Requirements 10.5**

### Security Properties

**Property 38: Rate Limiting Enforcement**
*For any* client IP, if more than 100 requests are made within 60 seconds, subsequent requests must return 429 Too Many Requests until the rate limit window resets.
**Validates: Requirements 11.1**

**Property 39: Authorization Enforcement**
*For any* protected endpoint, requests without valid authentication or with insufficient permissions must return 403 Forbidden and not execute the requested operation.
**Validates: Requirements 11.2**

**Property 40: Input Sanitization**
*For any* request containing SQL injection patterns or XSS payloads, the input must be sanitized before processing, and the attempt must be logged.
**Validates: Requirements 11.3**

**Property 41: Sensitive Data Redaction**
*For any* log entry, sensitive data (private keys, passwords, JWT tokens, API keys) must be redacted or masked, never appearing in plain text.
**Validates: Requirements 11.4**

### Error Handling Properties

**Property 42: Error Logging Completeness**
*For any* error that occurs, a log entry must be created containing stack trace, request context (method, path, user ID), and timestamp.
**Validates: Requirements 12.1**

**Property 43: Transaction Error Logging**
*For any* failed blockchain transaction, a log entry must include transaction signature, error reason, and transaction parameters.
**Validates: Requirements 12.2**

**Property 44: External Service Retry with Backoff**
*For any* external service failure (OpenRouter, Solana RPC), the system must retry with exponential backoff (delays: 1s, 2s, 4s, 8s) up to a maximum number of attempts.
**Validates: Requirements 12.3**

**Property 45: Log Severity Categorization**
*For any* log entry, it must be assigned a severity level (debug, info, warn, error, critical) appropriate to the event type.
**Validates: Requirements 12.5**

### Database Integrity Properties

**Property 46: Cascade Deletion**
*For any* user deletion, all associated wallets and transactions must be automatically deleted (cascade), leaving no orphaned records.
**Validates: Requirements 13.2**

**Property 47: Concurrent Update Consistency**
*For any* set of concurrent updates to the same resource, using database transactions must ensure that the final state is consistent and no updates are lost.
**Validates: Requirements 13.3**

### API Validation Properties

**Property 48: Request Schema Validation**
*For any* API request with a body, the body must be validated against the endpoint's JSON schema before processing, and invalid requests must return 400 Bad Request with validation errors.
**Validates: Requirements 14.3, 14.5**

**Property 49: Resource Not Found Handling**
*For any* request for a non-existent resource (user, wallet, transaction), the response must be 404 Not Found with the resource type and identifier.
**Validates: Requirements 14.4**

### Conversation Context Properties

**Property 50: Context Window Retrieval**
*For any* chat message in an existing conversation, the AI Agent must retrieve the last 10 messages (or fewer if conversation is shorter) to provide context.
**Validates: Requirements 15.1**

**Property 51: Context Summarization on Overflow**
*For any* conversation where the last 10 messages exceed the model's token limit, older messages must be summarized to fit within the limit while preserving key information.
**Validates: Requirements 15.2**

**Property 52: Conversation Creation Uniqueness**
*For any* new conversation creation, the conversation must receive a unique identifier (UUID), and no two conversations can have the same ID.
**Validates: Requirements 15.3**

**Property 53: Message Storage Completeness**
*For any* message in a conversation, the stored record must include role (user or assistant), content, timestamp, and conversation ID.
**Validates: Requirements 15.5**

### Cross-Chain Bridge Properties

**Property 54: Bridge Chain Validation**
*For any* bridge request, if either the source or destination chain is not supported, the request must be rejected with a clear error listing supported chains.
**Validates: Requirements 16.1**

**Property 55: Bridge Transaction Tracking**
*For any* initiated bridge transaction, the system must track the transaction on both source and destination chains, storing both transaction signatures.
**Validates: Requirements 16.3, 16.4**

### Price Feed Properties

**Property 56: Price Data Caching**
*For any* token price request, if the same token is requested again within 30 seconds, the cached price must be returned without making a new API call.
**Validates: Requirements 17.4**

**Property 57: Price Request Batching**
*For any* set of multiple token price requests made concurrently, the requests must be batched into a single API call to Pyth Network for efficiency.
**Validates: Requirements 17.3**

### NFT Operations Properties

**Property 58: NFT Ownership Validation**
*For any* NFT transfer or listing request, the operation must only proceed if the user's wallet is the current owner of the NFT; otherwise, return an authorization error.
**Validates: Requirements 18.5**

**Property 59: NFT Metadata Update**
*For any* NFT metadata update request, the NFT's metadata URI must be changed to the new URI, and subsequent queries must return the updated URI.
**Validates: Requirements 18.4**

### DeFi Protocol Properties

**Property 60: Borrow Collateral Validation**
*For any* borrow request, the operation must only proceed if the user has sufficient collateral (meeting the protocol's collateralization ratio); otherwise, return an error.
**Validates: Requirements 19.2**

**Property 61: Position Closure Asset Return**
*For any* DeFi position closure request, the withdrawn assets (principal plus accrued interest) must be transferred back to the user's wallet.
**Validates: Requirements 19.4**

**Property 62: DeFi Position Value Tracking**
*For any* active DeFi position, the system must track the current value including accrued interest, and the calculated value must be within 1% of the protocol's reported value.
**Validates: Requirements 19.5**

### Health Check Properties

**Property 63: Dependency Health Verification**
*For any* health check request, the system must verify connectivity to all critical dependencies (database, Solana RPC, OpenRouter), and return their individual statuses.
**Validates: Requirements 20.1, 20.2, 20.3**

**Property 64: Unhealthy Service Response**
*For any* health check where at least one dependency is unhealthy, the response must be 503 Service Unavailable with details about which dependencies failed.
**Validates: Requirements 20.4**


## Error Handling

### Error Categories

**1. Validation Errors (400 Bad Request)**
- Invalid request body schema
- Missing required parameters
- Invalid parameter types or formats
- Business rule violations (e.g., insufficient balance)

**2. Authentication Errors (401 Unauthorized)**
- Missing JWT token
- Invalid or expired JWT token
- Malformed authentication header

**3. Authorization Errors (403 Forbidden)**
- Valid authentication but insufficient permissions
- Attempting to access another user's resources
- Disabled features or plugins

**4. Not Found Errors (404 Not Found)**
- Resource does not exist (user, wallet, transaction)
- Invalid endpoint path

**5. Rate Limiting Errors (429 Too Many Requests)**
- Exceeded rate limit (100 requests/minute per IP)
- Includes Retry-After header

**6. Server Errors (500 Internal Server Error)**
- Unexpected exceptions
- Database connection failures
- Unhandled edge cases

**7. Service Unavailable (503 Service Unavailable)**
- External service failures (Solana RPC, OpenRouter)
- Database unavailable
- System maintenance mode

### Error Response Format

All errors follow a consistent format:

```typescript
interface ErrorResponse {
  success: false;
  error: {
    code: string;           // Machine-readable error code (e.g., "INVALID_TOKEN")
    message: string;        // Human-readable error message
    details?: any;          // Additional context (validation errors, stack trace in dev)
    timestamp: string;      // ISO 8601 timestamp
    requestId: string;      // Unique request identifier for tracing
  };
}
```

### Error Handling Strategy

**1. Centralized Error Handler Middleware**
```typescript
app.use((err: Error, req: Request, res: Response, next: NextFunction) => {
  // Log error with context
  logger.error('Request error', {
    error: err.message,
    stack: err.stack,
    method: req.method,
    path: req.path,
    userId: req.user?.id,
    requestId: req.id
  });
  
  // Map error to appropriate HTTP response
  const errorResponse = mapErrorToResponse(err);
  res.status(errorResponse.status).json(errorResponse.body);
});
```

**2. Custom Error Classes**
```typescript
class ValidationError extends Error {
  constructor(message: string, public details: any) {
    super(message);
    this.name = 'ValidationError';
  }
}

class AuthenticationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'AuthenticationError';
  }
}

class BlockchainError extends Error {
  constructor(message: string, public signature?: string) {
    super(message);
    this.name = 'BlockchainError';
  }
}
```

**3. Retry Logic for External Services**
```typescript
async function retryWithBackoff<T>(
  operation: () => Promise<T>,
  maxRetries: number = 4,
  baseDelay: number = 1000
): Promise<T> {
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      return await operation();
    } catch (error) {
      if (attempt === maxRetries - 1) throw error;
      
      const delay = baseDelay * Math.pow(2, attempt);
      logger.warn(`Retry attempt ${attempt + 1} after ${delay}ms`, { error });
      await sleep(delay);
    }
  }
  throw new Error('Max retries exceeded');
}
```

**4. Circuit Breaker for External Services**
- Track failure rates for external services
- Open circuit after 5 consecutive failures
- Half-open after 30 seconds to test recovery
- Close circuit after 3 successful requests

**5. Graceful Degradation**
- Return cached data when external services fail
- Provide fallback AI models when primary model fails
- Queue transactions for retry when RPC is unavailable

### Logging Strategy

**Log Levels:**
- **DEBUG**: Detailed diagnostic information (development only)
- **INFO**: General informational messages (requests, responses)
- **WARN**: Warning messages (deprecated features, fallbacks used)
- **ERROR**: Error messages (handled exceptions)
- **CRITICAL**: Critical errors requiring immediate attention (service down, data corruption)

**Structured Logging Format:**
```typescript
{
  timestamp: "2024-01-15T10:30:00.000Z",
  level: "error",
  message: "Transaction failed",
  context: {
    userId: "uuid",
    walletId: "uuid",
    signature: "...",
    error: "Insufficient funds"
  },
  requestId: "uuid",
  service: "ordo-backend"
}
```

**Sensitive Data Redaction:**
- Private keys: Always redacted
- Passwords: Always redacted
- JWT tokens: Redacted (show only first 10 chars)
- API keys: Redacted (show only first 8 chars)

## Testing Strategy

### Dual Testing Approach

The testing strategy employs both **unit tests** and **property-based tests** as complementary approaches:

- **Unit tests**: Verify specific examples, edge cases, and error conditions
- **Property-based tests**: Verify universal properties across all inputs
- Together, they provide comprehensive coverage: unit tests catch concrete bugs, property tests verify general correctness

### Property-Based Testing

**Library**: fast-check (TypeScript property-based testing library)

**Configuration**:
- Minimum 100 iterations per property test (due to randomization)
- Each property test must reference its design document property
- Tag format: `Feature: ordo-backend, Property {number}: {property_text}`

**Example Property Test:**
```typescript
import fc from 'fast-check';

describe('Authentication Properties', () => {
  // Feature: ordo-backend, Property 1: Password Hashing Security
  it('should hash all passwords with bcrypt and verify correctly', async () => {
    await fc.assert(
      fc.asyncProperty(
        fc.string({ minLength: 8, maxLength: 100 }), // Generate random passwords
        async (password) => {
          // Register user with random password
          const user = await authService.register(
            `test-${Date.now()}@example.com`,
            password,
            `user-${Date.now()}`
          );
          
          // Verify password hash uses bcrypt
          expect(user.passwordHash).toMatch(/^\$2[aby]\$/);
          
          // Verify password verification works
          const isValid = await authService.verifyPassword(password, user.passwordHash);
          expect(isValid).toBe(true);
          
          // Verify wrong password fails
          const isInvalid = await authService.verifyPassword(password + 'wrong', user.passwordHash);
          expect(isInvalid).toBe(false);
        }
      ),
      { numRuns: 100 }
    );
  });
});
```

**Property Test Patterns:**

1. **Round-Trip Properties** (Encryption, Serialization)
```typescript
// Property 5: Wallet Import Round Trip
fc.assert(
  fc.asyncProperty(
    fc.base58String({ length: 44 }), // Generate random private keys
    async (privateKey) => {
      const wallet = await walletService.importWallet(userId, privateKey);
      const keypair = await walletService.getKeypair(wallet.id);
      expect(keypair.secretKey.toString()).toBe(privateKey);
    }
  )
);
```

2. **Invariant Properties** (Data Integrity)
```typescript
// Property 46: Cascade Deletion
fc.assert(
  fc.asyncProperty(
    fc.record({
      email: fc.emailAddress(),
      username: fc.string({ minLength: 3 }),
      password: fc.string({ minLength: 8 })
    }),
    async (userData) => {
      const user = await authService.register(userData.email, userData.password, userData.username);
      const wallet = await walletService.createWallet(user.id);
      const tx = await transactionService.recordTransaction({
        userId: user.id,
        walletId: wallet.id,
        type: 'test',
        signature: 'test-sig',
        status: 'pending',
        metadata: {}
      });
      
      // Delete user
      await userService.deleteUser(user.id);
      
      // Verify cascade deletion
      const walletExists = await walletService.getWallet(wallet.id);
      const txExists = await transactionService.getTransaction(tx.id);
      expect(walletExists).toBeNull();
      expect(txExists).toBeNull();
    }
  )
);
```

3. **Error Condition Properties** (Input Validation)
```typescript
// Property 39: Authorization Enforcement
fc.assert(
  fc.asyncProperty(
    fc.string(), // Generate random invalid tokens
    async (invalidToken) => {
      fc.pre(!isValidJWT(invalidToken)); // Precondition: token is invalid
      
      const response = await request(app)
        .get('/api/v1/wallet/balance')
        .set('Authorization', `Bearer ${invalidToken}`);
      
      expect(response.status).toBe(403);
      expect(response.body.success).toBe(false);
    }
  )
);
```

4. **Metamorphic Properties** (Relationships)
```typescript
// Property 22: Transaction Filtering
fc.assert(
  fc.asyncProperty(
    fc.array(fc.record({
      type: fc.constantFrom('swap', 'transfer', 'mint'),
      status: fc.constantFrom('pending', 'confirmed', 'failed')
    })),
    fc.constantFrom('swap', 'transfer', 'mint'),
    async (transactions, filterType) => {
      // Create transactions
      for (const tx of transactions) {
        await transactionService.recordTransaction({...tx, userId, walletId, signature: generateSig()});
      }
      
      // Query with filter
      const filtered = await transactionService.getTransactionHistory(userId, { type: filterType });
      
      // All returned transactions must match filter
      expect(filtered.items.every(tx => tx.type === filterType)).toBe(true);
      
      // Count must be <= total transactions
      expect(filtered.items.length).toBeLessThanOrEqual(transactions.length);
    }
  )
);
```

### Unit Testing

**Library**: Jest

**Coverage Requirements**:
- Minimum 80% code coverage
- 100% coverage for critical paths (authentication, encryption, transaction handling)

**Unit Test Focus Areas**:
1. **Specific Examples**: Test concrete scenarios with known inputs/outputs
2. **Edge Cases**: Empty inputs, boundary values, special characters
3. **Error Conditions**: Invalid inputs, missing dependencies, timeout scenarios
4. **Integration Points**: Service interactions, database operations, external API calls

**Example Unit Tests:**
```typescript
describe('WalletService', () => {
  describe('createWallet', () => {
    it('should create a wallet with valid keypair', async () => {
      const wallet = await walletService.createWallet(userId);
      
      expect(wallet.id).toBeDefined();
      expect(wallet.publicKey).toMatch(/^[1-9A-HJ-NP-Za-km-z]{32,44}$/);
      expect(wallet.encryptedPrivateKey).toBeDefined();
      expect(wallet.encryptionIv).toBeDefined();
    });
    
    it('should reject wallet creation for non-existent user', async () => {
      await expect(
        walletService.createWallet('non-existent-user-id')
      ).rejects.toThrow('User not found');
    });
    
    it('should set first wallet as primary', async () => {
      const wallet = await walletService.createWallet(userId);
      expect(wallet.isPrimary).toBe(true);
    });
  });
});
```

### Integration Testing

**Focus**: Test complete request-response cycles through the API

```typescript
describe('POST /api/v1/chat', () => {
  it('should process a token swap request', async () => {
    const response = await request(app)
      .post('/api/v1/chat')
      .set('Authorization', `Bearer ${validToken}`)
      .send({
        conversationId: conversationId,
        message: 'Swap 1 SOL for USDC'
      });
    
    expect(response.status).toBe(200);
    expect(response.body.success).toBe(true);
    expect(response.body.data.action).toBeDefined();
    expect(response.body.data.action.type).toBe('swap');
  });
});
```

### Test Data Management

**Generators for Property Tests:**
```typescript
// Custom arbitraries for domain-specific data
const solanaAddressArbitrary = fc.base58String({ minLength: 32, maxLength: 44 });
const emailArbitrary = fc.emailAddress();
const passwordArbitrary = fc.string({ minLength: 8, maxLength: 100 });
const tokenAmountArbitrary = fc.double({ min: 0.000001, max: 1000000 });

// Composite generators
const userArbitrary = fc.record({
  email: emailArbitrary,
  username: fc.string({ minLength: 3, maxLength: 20 }),
  password: passwordArbitrary
});

const walletArbitrary = fc.record({
  publicKey: solanaAddressArbitrary,
  balance: tokenAmountArbitrary
});
```

**Test Database:**
- Use separate test database (Supabase test project)
- Reset database between test suites
- Use transactions for test isolation

### Continuous Integration

**CI Pipeline:**
1. Lint code (ESLint, Prettier)
2. Type check (TypeScript compiler)
3. Run unit tests
4. Run property-based tests (100 iterations)
5. Run integration tests
6. Generate coverage report
7. Fail if coverage < 80%

**Performance Testing:**
- Load testing with k6 (1000 concurrent users)
- Stress testing for rate limiting
- Latency testing for streaming responses

### Mocking Strategy

**External Services:**
- Mock Solana RPC calls (use @solana/web3.js test utilities)
- Mock OpenRouter API (use nock for HTTP mocking)
- Mock Supabase client (use jest.mock)

**Example Mock:**
```typescript
jest.mock('@solana/web3.js', () => ({
  Connection: jest.fn().mockImplementation(() => ({
    getBalance: jest.fn().mockResolvedValue(1000000000), // 1 SOL
    getTokenAccountsByOwner: jest.fn().mockResolvedValue({ value: [] })
  }))
}));
```

### Test Organization

```
tests/
├── unit/
│   ├── services/
│   │   ├── auth.service.test.ts
│   │   ├── wallet.service.test.ts
│   │   ├── ai-agent.service.test.ts
│   │   └── ...
│   └── utils/
│       ├── encryption.test.ts
│       └── validation.test.ts
├── property/
│   ├── auth.properties.test.ts
│   ├── wallet.properties.test.ts
│   ├── transaction.properties.test.ts
│   └── ...
├── integration/
│   ├── auth.integration.test.ts
│   ├── chat.integration.test.ts
│   └── admin.integration.test.ts
└── helpers/
    ├── generators.ts
    ├── fixtures.ts
    └── test-db.ts
```

## API Endpoints Reference

### Public Endpoints

**Authentication:**
- `POST /api/v1/auth/register` - Register new user
- `POST /api/v1/auth/login` - Login user
- `POST /api/v1/auth/refresh` - Refresh JWT token

**Chat:**
- `POST /api/v1/chat` - Send chat message (LLM with function calling for actions)
- `POST /api/v1/chat/stream` - Send chat message with streaming response (LLM with function calling)
- `GET /api/v1/conversations` - Get user's conversations
- `GET /api/v1/conversations/:id/messages` - Get conversation messages

**Note:** Chat endpoints use OpenRouter LLM with function calling capability. The LLM can call registered tools/actions (swap tokens, mint NFT, etc.) based on user's natural language input.

**Wallet:**
- `POST /api/v1/wallet/create` - Create new wallet
- `POST /api/v1/wallet/import` - Import wallet from private key
- `GET /api/v1/wallet/:id/balance` - Get wallet balance
- `GET /api/v1/wallets` - Get user's wallets

**Transactions:**
- `GET /api/v1/transactions` - Get transaction history (paginated, filterable)
- `GET /api/v1/transactions/:id` - Get transaction details

**Actions:**
- `POST /api/v1/actions/:actionName` - Execute specific action directly
- `GET /api/v1/actions` - Get available actions

**Health:**
- `GET /health` - Basic health check
- `GET /health/detailed` - Detailed health check with dependency status

### Admin Endpoints

**Dashboard:**
- `GET /api/v1/admin/dashboard` - Get dashboard metrics

**User Management:**
- `GET /api/v1/admin/users` - Get users (paginated, filterable)
- `GET /api/v1/admin/users/:id` - Get user details
- `DELETE /api/v1/admin/users/:id` - Delete user

**Transaction Monitoring:**
- `GET /api/v1/admin/transactions` - Get all transactions (paginated, filterable)
- `GET /api/v1/admin/transactions/stats` - Get transaction statistics

**AI Model Management:**
- `GET /api/v1/admin/models` - Get AI models
- `POST /api/v1/admin/models` - Add new AI model
- `PUT /api/v1/admin/models/:id` - Update AI model
- `DELETE /api/v1/admin/models/:id` - Delete AI model
- `PUT /api/v1/admin/models/:id/default` - Set default model

**Plugin Management:**
- `GET /api/v1/admin/plugins` - Get plugins
- `POST /api/v1/admin/plugins` - Install plugin
- `PUT /api/v1/admin/plugins/:id` - Update plugin
- `DELETE /api/v1/admin/plugins/:id` - Uninstall plugin
- `PUT /api/v1/admin/plugins/:id/enable` - Enable plugin
- `PUT /api/v1/admin/plugins/:id/disable` - Disable plugin

**Configuration:**
- `GET /api/v1/admin/config` - Get configuration
- `PUT /api/v1/admin/config` - Update configuration
- `GET /api/v1/admin/config/history` - Get configuration history
- `POST /api/v1/admin/config/rollback/:version` - Rollback configuration

**Audit Logs:**
- `GET /api/v1/admin/audit-logs` - Get audit logs (paginated, filterable)

## Security Considerations

### Authentication & Authorization

1. **JWT Token Security:**
   - Use RS256 algorithm (asymmetric)
   - Short expiration (24 hours)
   - Refresh token rotation
   - Token blacklist for logout

2. **Password Security:**
   - Bcrypt with 10+ salt rounds
   - Minimum password requirements (8 chars, complexity)
   - Password reset with time-limited tokens

3. **API Key Management:**
   - Store API keys in environment variables
   - Rotate keys regularly
   - Use different keys for dev/staging/prod

### Data Protection

1. **Encryption at Rest:**
   - AES-256-GCM for private keys
   - Unique IV per encryption
   - Store auth tags for integrity verification

2. **Encryption in Transit:**
   - HTTPS only in production
   - TLS 1.3 minimum
   - HSTS headers

3. **Database Security:**
   - Row-level security (RLS) in Supabase
   - Prepared statements (prevent SQL injection)
   - Principle of least privilege for DB users

### Input Validation

1. **Request Validation:**
   - Zod schemas for all endpoints
   - Sanitize HTML/SQL in user inputs
   - Validate Solana addresses format

2. **Rate Limiting:**
   - 100 requests/minute per IP
   - Stricter limits for expensive operations
   - Exponential backoff for repeated violations

### Monitoring & Alerting

1. **Security Monitoring:**
   - Log all authentication failures
   - Alert on repeated failed login attempts
   - Monitor for SQL injection/XSS attempts

2. **Anomaly Detection:**
   - Unusual transaction patterns
   - Spike in error rates
   - Unexpected API usage patterns

## Deployment Architecture

### Infrastructure

**Hosting:** Railway / Render / AWS ECS

**Database:** Supabase (managed PostgreSQL)

**Environment Variables:**
```
NODE_ENV=production
PORT=3000
DATABASE_URL=postgresql://...
SUPABASE_URL=https://...
SUPABASE_KEY=...
OPENROUTER_API_KEY=...
SOLANA_RPC_URL=https://...
JWT_SECRET=...
ENCRYPTION_KEY=...
RATE_LIMIT_MAX=100
RATE_LIMIT_WINDOW_MS=60000
LOG_LEVEL=info
```

### Scaling Strategy

1. **Horizontal Scaling:**
   - Stateless API design
   - Load balancer (Nginx/AWS ALB)
   - Multiple API instances

2. **Database Scaling:**
   - Read replicas for queries
   - Connection pooling (PgBouncer)
   - Query optimization with indexes

3. **Caching:**
   - Redis for session data
   - Cache price feeds (30s TTL)
   - Cache AI model responses (optional)

### Monitoring

**Metrics:**
- Request rate, latency, error rate
- Database query performance
- External API response times
- Memory and CPU usage

**Tools:**
- Logging: Winston + CloudWatch/Datadog
- Metrics: Prometheus + Grafana
- Error tracking: Sentry
- APM: New Relic / Datadog

## Future Enhancements

1. **WebSocket Support:** Real-time notifications for transaction confirmations
2. **Multi-Chain Support:** Extend beyond Solana to Ethereum, Polygon, etc.
3. **Advanced AI Features:** Multi-agent conversations, context sharing
4. **Analytics Dashboard:** User behavior analytics, transaction trends
5. **Mobile SDK:** Native SDK for direct integration with Android app
6. **Webhook System:** Allow users to configure webhooks for events
7. **GraphQL API:** Alternative to REST for flexible queries
8. **Batch Operations:** Execute multiple actions in a single transaction

## Additional Components (Phase 2)

### 8. EVM Wallet Service

**Responsibilities:**
- EVM keypair generation and encryption
- Multi-chain wallet management (Ethereum, Polygon, BSC, Arbitrum, Optimism, Avalanche)
- EVM balance queries (native and ERC-20 tokens)
- EVM transaction execution

**Interface:**
```typescript
interface EVMWalletService {
  createWallet(userId: string, chainId: EVMChainId): Promise<EVMWallet>;
  importWallet(userId: string, chainId: EVMChainId, privateKey: string): Promise<EVMWallet>;
  getWalletBalance(walletId: string): Promise<EVMBalance>;
  transferNative(walletId: string, toAddress: string, amount: number): Promise<string>; // Returns tx hash
  transferToken(walletId: string, toAddress: string, tokenAddress: string, amount: number): Promise<string>;
  estimateGas(chainId: EVMChainId, type: 'native' | 'token', tokenAddress?: string): Promise<GasEstimate>;
}

enum EVMChainId {
  ETHEREUM = 'ethereum',
  POLYGON = 'polygon',
  BSC = 'bsc',
  ARBITRUM = 'arbitrum',
  OPTIMISM = 'optimism',
  AVALANCHE = 'avalanche'
}

interface EVMWallet {
  id: string;
  userId: string;
  chainId: EVMChainId;
  address: string; // 0x...
  encryptedPrivateKey: string;
  encryptionIv: string;
  encryptionAuthTag: string;
  isPrimary: boolean;
  createdAt: Date;
}

interface EVMBalance {
  native: number; // ETH, MATIC, BNB, etc.
  tokens: EVMTokenBalance[];
}

interface EVMTokenBalance {
  address: string; // Token contract address
  symbol: string;
  name: string;
  amount: number;
  decimals: number;
}

interface GasEstimate {
  gasLimit: number;
  gasPrice: string; // in wei
  estimatedFee: string; // in native token
  estimatedFeeUsd: number;
}
```

**Database Schema:**
```sql
CREATE TABLE evm_wallets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  chain_id VARCHAR(50) NOT NULL,
  address VARCHAR(42) NOT NULL,
  encrypted_private_key TEXT NOT NULL,
  encryption_iv VARCHAR(32) NOT NULL,
  encryption_auth_tag VARCHAR(32) NOT NULL,
  is_primary BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_evm_wallets_user_id ON evm_wallets(user_id);
CREATE INDEX idx_evm_wallets_address ON evm_wallets(address);
CREATE INDEX idx_evm_wallets_chain_id ON evm_wallets(chain_id);
CREATE UNIQUE INDEX idx_evm_wallets_user_address ON evm_wallets(user_id, address);
```

### 9. User Preferences Service

**Responsibilities:**
- User preference management
- Risk threshold configuration
- Agent autonomy level control
- Notification preferences

**Interface:**
```typescript
interface UserPreferencesService {
  getPreferences(userId: string): Promise<UserPreferences>;
  updatePreferences(userId: string, updates: Partial<UserPreferences>): Promise<UserPreferences>;
  resetToDefaults(userId: string): Promise<UserPreferences>;
  checkApprovalRequired(userId: string, transactionValue: number): Promise<boolean>;
}

interface UserPreferences {
  id: string;
  userId: string;
  maxSingleTransferSol: number;
  maxDailyVolumeUsdc: number;
  requireApprovalAboveSol: number;
  autoApproveWhitelisted: boolean;
  defaultSlippageBps: number;
  maxSlippageBps: number;
  priorityFeeLamports: number;
  agentAutonomyLevel: 'low' | 'medium' | 'high';
  enableAutoStaking: boolean;
  enableAutoCompounding: boolean;
  notificationChannels: string[];
  alertOnLargeMovements: boolean;
  alertThresholdUsdc: number;
  createdAt: Date;
  updatedAt: Date;
}
```

**Database Schema:**
```sql
CREATE TABLE user_preferences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  max_single_transfer_sol DECIMAL(18, 9) DEFAULT 1.0,
  max_daily_volume_usdc DECIMAL(18, 2) DEFAULT 10000,
  require_approval_above_sol DECIMAL(18, 9) DEFAULT 0.5,
  auto_approve_whitelisted BOOLEAN DEFAULT false,
  default_slippage_bps INTEGER DEFAULT 50,
  max_slippage_bps INTEGER DEFAULT 300,
  priority_fee_lamports INTEGER DEFAULT 10000,
  agent_autonomy_level VARCHAR(20) DEFAULT 'medium',
  enable_auto_staking BOOLEAN DEFAULT false,
  enable_auto_compounding BOOLEAN DEFAULT false,
  notification_channels JSONB DEFAULT '["mobile"]',
  alert_on_large_movements BOOLEAN DEFAULT true,
  alert_threshold_usdc DECIMAL(18, 2) DEFAULT 1000,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_user_preferences_user_id ON user_preferences(user_id);
```

### 10. Approval Service

**Responsibilities:**
- Approval request creation and management
- Approval/rejection workflow
- Expiration handling
- Alternative options generation

**Interface:**
```typescript
interface ApprovalService {
  createApprovalRequest(request: ApprovalRequestInput): Promise<ApprovalRequest>;
  getApprovalRequest(id: string): Promise<ApprovalRequest>;
  getPendingApprovals(userId: string): Promise<ApprovalRequest[]>;
  getApprovalHistory(userId: string, filters: ApprovalFilters): Promise<PaginatedResult<ApprovalRequest>>;
  approveRequest(id: string, userId: string): Promise<ApprovalRequest>;
  rejectRequest(id: string, userId: string, reason?: string): Promise<ApprovalRequest>;
  expireOldRequests(): Promise<void>; // Background job
}

interface ApprovalRequestInput {
  userId: string;
  requestType: 'transaction' | 'setting_change' | 'large_transfer' | 'high_risk_token';
  pendingTransaction: any;
  estimatedRiskScore?: number;
  estimatedUsdValue?: number;
  agentReasoning: string;
  limitingFactors?: any;
  alternativeOptions?: any;
  expiresAt?: Date;
}

interface ApprovalRequest {
  id: string;
  userId: string;
  requestType: string;
  status: 'pending' | 'approved' | 'rejected' | 'expired';
  pendingTransaction: any;
  estimatedRiskScore?: number;
  estimatedUsdValue?: number;
  agentReasoning: string;
  limitingFactors?: any;
  alternativeOptions?: any;
  approvedAt?: Date;
  rejectedAt?: Date;
  rejectionReason?: string;
  expiresAt: Date;
  createdAt: Date;
}

interface ApprovalFilters {
  status?: string;
  requestType?: string;
  startDate?: Date;
  endDate?: Date;
  page: number;
  limit: number;
}
```

**Database Schema:**
```sql
CREATE TABLE approval_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  request_type VARCHAR(50) NOT NULL,
  status VARCHAR(20) DEFAULT 'pending',
  pending_transaction JSONB NOT NULL,
  estimated_risk_score DECIMAL(5, 2),
  estimated_usd_value DECIMAL(18, 2),
  agent_reasoning TEXT NOT NULL,
  limiting_factors JSONB,
  alternative_options JSONB,
  approved_at TIMESTAMP,
  rejected_at TIMESTAMP,
  rejection_reason TEXT,
  expires_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_approval_queue_user_id ON approval_queue(user_id);
CREATE INDEX idx_approval_queue_status ON approval_queue(status);
CREATE INDEX idx_approval_queue_expires_at ON approval_queue(expires_at);
```

### 11. Token Risk Service

**Responsibilities:**
- Token risk score fetching and caching
- Range Protocol integration
- Risk analysis and recommendations

**Interface:**
```typescript
interface TokenRiskService {
  getTokenRiskScore(tokenAddress: string): Promise<TokenScore>;
  analyzeToken(tokenAddress: string): Promise<TokenAnalysis>;
  searchTokens(query: string, limit: number): Promise<TokenScore[]>;
  getRiskyTokens(limit: number): Promise<TokenScore[]>;
  refreshTokenScores(): Promise<void>; // Background job
}

interface TokenScore {
  id: string;
  tokenAddress: string;
  tokenSymbol: string;
  tokenName: string;
  riskScore: number; // 0-100, lower is better
  marketScore: number; // 0-100, higher is better
  liquidityScore: number;
  holderScore: number;
  rugcheckScore: number;
  priceUsd: number;
  marketCapUsd: number;
  volume24hUsd: number;
  liquidityUsd: number;
  holderCount: number;
  limitingFactors: any;
  dataSources: string[];
  createdAt: Date;
  updatedAt: Date;
  lastFetchedAt: Date;
}

interface TokenAnalysis {
  score: TokenScore;
  recommendation: 'safe' | 'caution' | 'high_risk';
  reasons: string[];
}
```

**Database Schema:**
```sql
CREATE TABLE token_scores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  token_address VARCHAR(44) UNIQUE NOT NULL,
  token_symbol VARCHAR(20),
  token_name VARCHAR(100),
  risk_score DECIMAL(5, 2),
  market_score DECIMAL(5, 2),
  liquidity_score DECIMAL(5, 2),
  holder_score DECIMAL(5, 2),
  rugcheck_score DECIMAL(5, 2),
  price_usd DECIMAL(18, 8),
  market_cap_usd DECIMAL(20, 2),
  volume_24h_usd DECIMAL(20, 2),
  liquidity_usd DECIMAL(20, 2),
  holder_count INTEGER,
  limiting_factors JSONB,
  data_sources JSONB,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  last_fetched_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_token_scores_address ON token_scores(token_address);
CREATE INDEX idx_token_scores_risk_score ON token_scores(risk_score);
CREATE INDEX idx_token_scores_symbol ON token_scores(token_symbol);
```

### 12. Helius Analytics Service

**Responsibilities:**
- Enhanced transaction data from Helius
- Token and NFT metadata
- Address activity analysis

**Interface:**
```typescript
interface HeliusService {
  getEnhancedTransactions(address: string, limit: number): Promise<EnhancedTransaction[]>;
  getParsedTransaction(signature: string): Promise<ParsedTransaction>;
  getTokenMetadata(mintAddress: string): Promise<TokenMetadata>;
  getNFTsByOwner(address: string, limit: number): Promise<NFTAsset[]>;
  getTokenBalances(address: string): Promise<TokenBalanceWithMetadata[]>;
  searchAssets(query: string, limit: number): Promise<Asset[]>;
  getAddressActivity(address: string): Promise<AddressActivity>;
}

interface EnhancedTransaction {
  signature: string;
  timestamp: number;
  type: string;
  source: string;
  fee: number;
  feePayer: string;
  nativeTransfers: NativeTransfer[];
  tokenTransfers: TokenTransfer[];
  events: any;
}

interface TokenMetadata {
  account: string;
  onChainMetadata: any;
  offChainMetadata: any;
}

interface NFTAsset {
  id: string;
  content: {
    metadata: {
      name: string;
      symbol: string;
      description: string;
      image: string;
    };
  };
  ownership: {
    owner: string;
    delegated: boolean;
  };
  creators: any[];
  royalty: any;
}

interface AddressActivity {
  totalTransactions: number;
  types: Record<string, number>;
  recentActivity: EnhancedTransaction[];
  firstSeen: number;
  lastSeen: number;
}
```

### 13. Realtime Service

**Responsibilities:**
- WebSocket connection management
- Real-time event broadcasting
- Subscription management

**Interface:**
```typescript
interface RealtimeService {
  initialize(server: http.Server): void;
  authenticateConnection(socket: Socket, token: string): Promise<User>;
  subscribeToTransactions(userId: string, socket: Socket): void;
  subscribeToApprovals(userId: string, socket: Socket): void;
  subscribeToPortfolio(userId: string, socket: Socket): void;
  broadcastTransactionUpdate(userId: string, transaction: Transaction): void;
  broadcastApprovalNotification(userId: string, approval: ApprovalRequest): void;
  broadcastPortfolioUpdate(userId: string, portfolio: any): void;
}

// WebSocket Events
interface WebSocketEvents {
  // Client -> Server
  'authenticate': (token: string) => void;
  'subscribe:transactions': () => void;
  'subscribe:approvals': () => void;
  'subscribe:portfolio': () => void;
  
  // Server -> Client
  'authenticated': (user: User) => void;
  'transaction:update': (transaction: Transaction) => void;
  'approval:created': (approval: ApprovalRequest) => void;
  'approval:processed': (approval: ApprovalRequest) => void;
  'portfolio:update': (portfolio: any) => void;
  'error': (error: { code: string; message: string }) => void;
}
```

### API Endpoints (Additional)

**EVM Wallet:**
- `POST /api/v1/wallet/evm/create` - Create EVM wallet
- `POST /api/v1/wallet/evm/import` - Import EVM wallet
- `GET /api/v1/wallet/evm/:id/balance` - Get EVM balance
- `GET /api/v1/wallets/evm` - List user's EVM wallets
- `POST /api/v1/wallet/evm/transfer/native` - Transfer native token
- `POST /api/v1/wallet/evm/transfer/token` - Transfer ERC-20 token
- `GET /api/v1/wallet/evm/gas-estimate` - Estimate gas fee

**User Preferences:**
- `GET /api/v1/preferences` - Get user preferences
- `PUT /api/v1/preferences` - Update preferences
- `POST /api/v1/preferences/reset` - Reset to defaults

**Approval Queue:**
- `GET /api/v1/approvals/pending` - Get pending approvals
- `GET /api/v1/approvals/:id` - Get approval details
- `POST /api/v1/approvals/:id/approve` - Approve request
- `POST /api/v1/approvals/:id/reject` - Reject request
- `GET /api/v1/approvals/history` - Get approval history

**Token Risk:**
- `GET /api/v1/tokens/:address/risk` - Get token risk score
- `POST /api/v1/tokens/:address/analyze` - Analyze token
- `GET /api/v1/tokens/search` - Search tokens
- `GET /api/v1/tokens/risky` - Get risky tokens

**Analytics (Helius):**
- `GET /api/v1/analytics/transactions/:address` - Enhanced transactions
- `GET /api/v1/analytics/transaction/:signature` - Parsed transaction
- `GET /api/v1/analytics/token/:mintAddress` - Token metadata
- `GET /api/v1/analytics/nfts/:address` - NFTs by owner
- `GET /api/v1/analytics/balances/:address` - Token balances with metadata
- `GET /api/v1/analytics/search` - Search assets
- `GET /api/v1/analytics/activity/:address` - Address activity

**NFT Management:**
- `POST /api/v1/nft/mint` - Mint NFT
- `POST /api/v1/nft/transfer` - Transfer NFT
- `POST /api/v1/nft/burn` - Burn NFT
- `GET /api/v1/nft/user` - Get user's NFTs
- `GET /api/v1/nft/wallet/:address` - Get NFTs by wallet
- `GET /api/v1/nft/metadata/:mintAddress` - Get NFT metadata
- `GET /api/v1/nft/collection/:address` - Get collection info
- `GET /api/v1/nft/portfolio/value` - Get portfolio value

**Staking:**
- `POST /api/v1/stake` - Stake tokens
- `POST /api/v1/stake/unstake` - Unstake tokens
- `GET /api/v1/stake/positions` - Get staking positions
- `GET /api/v1/stake/rewards` - Get staking rewards
- `GET /api/v1/stake/apy` - Get APY rates

**Lending:**
- `POST /api/v1/lend` - Lend assets
- `POST /api/v1/lend/borrow` - Borrow assets
- `POST /api/v1/lend/repay` - Repay loan
- `POST /api/v1/lend/withdraw` - Withdraw lent assets
- `GET /api/v1/lend/positions` - Get lending positions
- `GET /api/v1/lend/rates` - Get interest rates

**Token Transfer:**
- `POST /api/v1/transfer/sol` - Transfer SOL
- `POST /api/v1/transfer/token` - Transfer SPL token
- `GET /api/v1/transfer/fee` - Estimate transfer fee
- `POST /api/v1/transfer/validate` - Validate transfer

**Token Swap (Jupiter):**
- `GET /api/v1/swap/quote` - Get swap quote
- `POST /api/v1/swap/execute` - Execute swap
- `GET /api/v1/swap/price/:tokenMint` - Get token price
- `GET /api/v1/swap/tokens` - Get supported tokens
- `POST /api/v1/swap/validate` - Validate swap

**Admin - EVM Wallets:**
- `GET /api/v1/admin/wallets/evm` - List all EVM wallets

### 14. Agent Memory Service

**Responsibilities:**
- Long-term memory storage with vector embeddings
- Semantic memory retrieval
- Learned preferences tracking
- Decision logging

**Interface:**
```typescript
interface AgentMemoryService {
  storeMemory(memory: MemoryInput): Promise<AgentMemory>;
  searchMemories(userId: string, query: string, limit: number): Promise<AgentMemory[]>;
  getRecentMemories(userId: string, limit: number): Promise<AgentMemory[]>;
  updateImportanceScore(memoryId: string, score: number): Promise<void>;
  deleteMemory(memoryId: string): Promise<void>;
}

interface MemoryInput {
  userId: string;
  memoryType: 'preference' | 'decision' | 'insight' | 'context';
  content: string;
  agentId?: string;
  importanceScore?: number;
  metadata?: any;
}

interface AgentMemory {
  id: string;
  userId: string;
  memoryType: string;
  content: string;
  embedding: number[]; // Vector embedding (1536 dimensions for OpenAI)
  agentId?: string;
  importanceScore: number;
  metadata?: any;
  createdAt: Date;
  lastAccessedAt: Date;
}
```

**Database Schema:**
```sql
CREATE TABLE agent_memories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  memory_type VARCHAR(50) NOT NULL,
  content TEXT NOT NULL,
  embedding vector(1536), -- pgvector extension
  agent_id VARCHAR(100),
  importance_score DECIMAL(3, 2) DEFAULT 0.5,
  metadata JSONB,
  created_at TIMESTAMP DEFAULT NOW(),
  last_accessed_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_agent_memories_user_id ON agent_memories(user_id);
CREATE INDEX idx_agent_memories_type ON agent_memories(memory_type);
CREATE INDEX idx_agent_memories_embedding ON agent_memories USING ivfflat (embedding vector_cosine_ops);
```

**Vector Search:**
- Use pgvector extension for PostgreSQL
- Cosine similarity for semantic search
- Index with IVFFlat for performance

### 15. Portfolio Analytics Service

**Responsibilities:**
- Multi-chain portfolio aggregation
- Market data integration (Birdeye)
- Portfolio valuation and tracking
- Performance analytics

**Interface:**
```typescript
interface PortfolioService {
  getPortfolioSummary(userId: string): Promise<PortfolioSummary>;
  getTokenAnalytics(tokenAddress: string): Promise<TokenAnalytics>;
  getTrendingTokens(limit: number): Promise<TrendingToken[]>;
  getPriceHistory(tokenAddress: string, timeframe: string): Promise<PricePoint[]>;
  getPortfolioPerformance(userId: string, timeframe: string): Promise<PerformanceMetrics>;
}

interface PortfolioSummary {
  totalValueUsd: number;
  solanaValueUsd: number;
  evmValueUsd: number;
  tokens: PortfolioToken[];
  nfts: PortfolioNFT[];
  defiPositions: DeFiPosition[];
  change24h: number;
  change7d: number;
}

interface TokenAnalytics {
  address: string;
  symbol: string;
  name: string;
  priceUsd: number;
  priceChange24h: number;
  volume24h: number;
  marketCap: number;
  liquidity: number;
  holders: number;
  priceHistory: PricePoint[];
}

interface TrendingToken {
  address: string;
  symbol: string;
  name: string;
  priceUsd: number;
  priceChange24h: number;
  volume24h: number;
  volumeChange24h: number;
}

interface PerformanceMetrics {
  totalReturn: number;
  totalReturnPercentage: number;
  bestPerformer: { symbol: string; return: number };
  worstPerformer: { symbol: string; return: number };
  realizedGains: number;
  unrealizedGains: number;
}
```

### 16. Birdeye Integration Service

**Responsibilities:**
- Market data fetching
- Token analytics
- Price feeds
- Trending tokens

**Interface:**
```typescript
interface BirdeyeService {
  getTokenPrice(address: string): Promise<number>;
  getTokenOverview(address: string): Promise<TokenOverview>;
  getTokenMarketData(address: string): Promise<MarketData>;
  getTrendingTokens(limit: number): Promise<TrendingToken[]>;
  getPriceHistory(address: string, timeframe: string): Promise<PricePoint[]>;
}

interface TokenOverview {
  address: string;
  symbol: string;
  name: string;
  decimals: number;
  price: number;
  priceChange24h: number;
  volume24h: number;
  marketCap: number;
  liquidity: number;
  holders: number;
}

interface MarketData {
  price: number;
  volume24h: number;
  volumeChange24h: number;
  marketCap: number;
  marketCapChange24h: number;
  liquidity: number;
  liquidityChange24h: number;
  priceHigh24h: number;
  priceLow24h: number;
}
```

### 17. Webhook Service

**Responsibilities:**
- Webhook configuration management
- Event notification delivery
- Retry logic with exponential backoff
- Signature verification

**Interface:**
```typescript
interface WebhookService {
  createWebhook(webhook: WebhookInput): Promise<Webhook>;
  updateWebhook(id: string, updates: Partial<WebhookInput>): Promise<Webhook>;
  deleteWebhook(id: string): Promise<void>;
  getUserWebhooks(userId: string): Promise<Webhook[]>;
  sendWebhook(userId: string, event: WebhookEvent): Promise<void>;
  retryFailedWebhooks(): Promise<void>; // Background job
}

interface WebhookInput {
  userId: string;
  url: string;
  events: WebhookEventType[];
  secret?: string;
  isEnabled: boolean;
}

interface Webhook {
  id: string;
  userId: string;
  url: string;
  events: WebhookEventType[];
  secret: string;
  isEnabled: boolean;
  lastTriggeredAt?: Date;
  failureCount: number;
  createdAt: Date;
}

enum WebhookEventType {
  TRANSACTION_CONFIRMED = 'transaction.confirmed',
  TRANSACTION_FAILED = 'transaction.failed',
  APPROVAL_REQUIRED = 'approval.required',
  APPROVAL_PROCESSED = 'approval.processed',
  BALANCE_CHANGED = 'balance.changed',
  PRICE_ALERT = 'price.alert'
}

interface WebhookEvent {
  type: WebhookEventType;
  data: any;
  timestamp: Date;
}
```

**Database Schema:**
```sql
CREATE TABLE webhooks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  url TEXT NOT NULL,
  events JSONB NOT NULL,
  secret VARCHAR(255),
  is_enabled BOOLEAN DEFAULT true,
  last_triggered_at TIMESTAMP,
  failure_count INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_webhooks_user_id ON webhooks(user_id);
CREATE INDEX idx_webhooks_enabled ON webhooks(is_enabled);

CREATE TABLE webhook_deliveries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  webhook_id UUID NOT NULL REFERENCES webhooks(id) ON DELETE CASCADE,
  event_type VARCHAR(50) NOT NULL,
  payload JSONB NOT NULL,
  status VARCHAR(20) NOT NULL, -- pending, success, failed
  response_code INTEGER,
  response_body TEXT,
  attempt_count INTEGER DEFAULT 1,
  created_at TIMESTAMP DEFAULT NOW(),
  delivered_at TIMESTAMP
);

CREATE INDEX idx_webhook_deliveries_webhook_id ON webhook_deliveries(webhook_id);
CREATE INDEX idx_webhook_deliveries_status ON webhook_deliveries(status);
```

### 18. Liquidity Pool Service

**Responsibilities:**
- Add/remove liquidity operations
- LP position tracking
- Impermanent loss calculation
- Multi-DEX support (Raydium, Meteora, Orca)

**Interface:**
```typescript
interface LiquidityService {
  addLiquidity(params: AddLiquidityParams): Promise<string>; // Returns signature
  removeLiquidity(params: RemoveLiquidityParams): Promise<string>;
  getLPPositions(userId: string): Promise<LPPosition[]>;
  getLPPositionValue(positionId: string): Promise<LPPositionValue>;
  calculateImpermanentLoss(positionId: string): Promise<ImpermanentLossData>;
}

interface AddLiquidityParams {
  walletId: string;
  protocol: 'raydium' | 'meteora' | 'orca';
  tokenA: string;
  tokenB: string;
  amountA: number;
  amountB: number;
  slippageBps: number;
}

interface RemoveLiquidityParams {
  walletId: string;
  protocol: 'raydium' | 'meteora' | 'orca';
  lpTokenMint: string;
  amount: number;
  slippageBps: number;
}

interface LPPosition {
  id: string;
  userId: string;
  protocol: string;
  poolAddress: string;
  tokenA: string;
  tokenB: string;
  lpTokenMint: string;
  lpTokenAmount: number;
  initialValueUsd: number;
  createdAt: Date;
}

interface LPPositionValue {
  currentValueUsd: number;
  tokenAAmount: number;
  tokenBAmount: number;
  feesEarnedUsd: number;
  impermanentLoss: number;
  totalReturn: number;
}

interface ImpermanentLossData {
  impermanentLossPercentage: number;
  impermanentLossUsd: number;
  hodlValue: number;
  lpValue: number;
  feesEarned: number;
  netReturn: number;
}
```

**Database Schema:**
```sql
CREATE TABLE lp_positions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  wallet_id UUID NOT NULL REFERENCES wallets(id),
  protocol VARCHAR(50) NOT NULL,
  pool_address VARCHAR(44) NOT NULL,
  token_a VARCHAR(44) NOT NULL,
  token_b VARCHAR(44) NOT NULL,
  lp_token_mint VARCHAR(44) NOT NULL,
  lp_token_amount DECIMAL(18, 9) NOT NULL,
  initial_value_usd DECIMAL(18, 2),
  initial_token_a_amount DECIMAL(18, 9),
  initial_token_b_amount DECIMAL(18, 9),
  status VARCHAR(20) DEFAULT 'active', -- active, closed
  created_at TIMESTAMP DEFAULT NOW(),
  closed_at TIMESTAMP
);

CREATE INDEX idx_lp_positions_user_id ON lp_positions(user_id);
CREATE INDEX idx_lp_positions_status ON lp_positions(status);
```

### API Endpoints (Additional - Phase 3 Continued)

**Agent Memory:**
- `POST /api/v1/memory/store` - Store memory
- `POST /api/v1/memory/search` - Semantic search
- `GET /api/v1/memory/recent` - Recent memories
- `DELETE /api/v1/memory/:id` - Delete memory

**Portfolio Analytics:**
- `GET /api/v1/portfolio/summary` - Portfolio summary
- `GET /api/v1/portfolio/performance` - Performance metrics
- `GET /api/v1/analytics/token/:address` - Token analytics
- `GET /api/v1/market/trending` - Trending tokens
- `GET /api/v1/price/:address/history` - Price history

**Webhooks:**
- `POST /api/v1/webhooks` - Create webhook
- `GET /api/v1/webhooks` - List webhooks
- `PUT /api/v1/webhooks/:id` - Update webhook
- `DELETE /api/v1/webhooks/:id` - Delete webhook
- `POST /api/v1/webhooks/:id/test` - Test webhook

**Liquidity Pools:**
- `POST /api/v1/liquidity/add` - Add liquidity
- `POST /api/v1/liquidity/remove` - Remove liquidity
- `GET /api/v1/liquidity/positions` - Get LP positions
- `GET /api/v1/liquidity/position/:id/value` - Get position value
- `GET /api/v1/liquidity/position/:id/il` - Calculate impermanent loss
