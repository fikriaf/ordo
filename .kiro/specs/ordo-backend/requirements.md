# Requirements Document: Ordo Backend

## Introduction

Ordo Backend adalah REST API backend berbasis Express TypeScript untuk aplikasi Android AI assistant "Ordo". Ordo adalah versi Android dari konsep Sendai.fun (https://docs.sendai.fun) - sebuah AI agent yang dapat melakukan 60+ operasi Solana blockchain melalui natural language commands.

Sistem ini menggunakan LLM dengan function calling capability (via OpenRouter) untuk mengeksekusi blockchain operations. Ketika user mengirim pesan natural language, LLM menganalisis intent dan memanggil tools/actions yang sesuai (swap tokens, mint NFT, lend assets, dll). Backend kemudian mengeksekusi action tersebut via Solana Agent Kit dan mengembalikan hasil ke LLM untuk di-format menjadi response natural language.

Key features:
- Function calling architecture (LLM calls tools/actions)
- 60+ Solana blockchain operations via Solana Agent Kit
- Multiple LLM models via OpenRouter
- Plugin architecture untuk extensibility
- Admin panel untuk dynamic management

## Glossary

- **Ordo_Backend**: Sistem backend Express TypeScript yang menyediakan REST API untuk aplikasi Ordo
- **AI_Agent**: Komponen yang memproses natural language commands menggunakan LLM dengan function calling untuk mengeksekusi blockchain operations
- **Function_Calling**: Capability LLM untuk memanggil tools/actions berdasarkan user input (mirip OpenAI function calling)
- **Tool**: Function yang dapat dipanggil oleh LLM, merepresentasikan blockchain action (swap, mint, lend, dll)
- **Solana_Agent_Kit**: Library yang menyediakan 60+ Solana blockchain operations
- **OpenRouter**: Service untuk mengakses multiple LLM models
- **Plugin**: Modul yang dapat di-install untuk menambahkan protocol integrations baru
- **Action**: Unit operasi blockchain yang dapat dieksekusi (contoh: swap token, mint NFT)
- **Wallet**: Solana wallet dengan keypair yang di-encrypt
- **Admin_Panel**: Interface untuk mengelola models, plugins, dan konfigurasi sistem
- **Supabase**: PostgreSQL database service dengan real-time capabilities
- **Streaming_Response**: Response yang dikirim secara incremental untuk real-time feedback

## Requirements

### Requirement 1: User Authentication and Authorization

**User Story:** As a user, I want to register and login securely, so that I can access my wallet and transaction history.

#### Acceptance Criteria

1. WHEN a user submits valid registration data (email, password, username), THE Ordo_Backend SHALL create a new user account with encrypted credentials
2. WHEN a user submits valid login credentials, THE Ordo_Backend SHALL return a JWT token valid for 24 hours
3. WHEN a user submits an invalid JWT token, THE Ordo_Backend SHALL reject the request with 401 Unauthorized
4. WHEN a user's JWT token expires, THE Ordo_Backend SHALL require re-authentication
5. THE Ordo_Backend SHALL hash passwords using bcrypt with minimum 10 salt rounds

### Requirement 2: Wallet Management

**User Story:** As a user, I want to create and manage Solana wallets, so that I can perform blockchain operations.

#### Acceptance Criteria

1. WHEN a user requests wallet creation, THE Ordo_Backend SHALL generate a new Solana keypair and store it encrypted in the database
2. WHEN a user requests wallet import with a valid private key, THE Ordo_Backend SHALL encrypt and store the keypair
3. WHEN retrieving wallet data, THE Ordo_Backend SHALL decrypt the keypair only in memory and never expose private keys in API responses
4. WHEN a user requests wallet balance, THE Ordo_Backend SHALL query Solana RPC and return current SOL and token balances
5. THE Ordo_Backend SHALL use AES-256-GCM encryption for all stored private keys

### Requirement 3: AI Chat Interface with Function Calling

**User Story:** As a user, I want to interact with the AI using natural language, so that I can execute blockchain operations without technical knowledge.

#### Acceptance Criteria

1. WHEN a user sends a chat message, THE AI_Agent SHALL send the message to LLM with available tools/actions registered as function definitions
2. WHEN the LLM decides to call a tool, THE Ordo_Backend SHALL execute the corresponding action via Solana_Agent_Kit
3. WHEN a tool execution completes, THE Ordo_Backend SHALL send the result back to LLM for natural language response generation
4. WHEN an Action is executed successfully, THE AI_Agent SHALL return a human-readable confirmation with transaction details
5. WHEN an Action fails, THE AI_Agent SHALL return a clear error message with suggested remediation steps

### Requirement 4: Streaming Chat Responses

**User Story:** As a user, I want to see AI responses in real-time, so that I get immediate feedback during processing.

#### Acceptance Criteria

1. WHEN a user requests streaming chat, THE Ordo_Backend SHALL establish a Server-Sent Events (SSE) connection
2. WHEN the AI_Agent generates response tokens, THE Ordo_Backend SHALL stream each token immediately to the client
3. WHEN a streaming connection is interrupted, THE Ordo_Backend SHALL clean up resources and log the disconnection
4. WHEN streaming is complete, THE Ordo_Backend SHALL send a completion event and close the connection gracefully
5. THE Ordo_Backend SHALL support concurrent streaming connections for multiple users

### Requirement 5: Solana Blockchain Operations

**User Story:** As a user, I want to perform various Solana operations through the AI, so that I can manage my crypto assets.

#### Acceptance Criteria

1. WHEN a user requests a token swap, THE Solana_Agent_Kit SHALL execute the swap via Jupiter aggregator and return the transaction signature
2. WHEN a user requests token deployment, THE Solana_Agent_Kit SHALL create a new SPL token with specified parameters
3. WHEN a user requests NFT minting, THE Solana_Agent_Kit SHALL mint the NFT with metadata and return the mint address
4. WHEN a user requests lending operations, THE Solana_Agent_Kit SHALL interact with lending protocols (Lulo, Marginfi) and execute the operation
5. WHEN a user requests price data, THE Solana_Agent_Kit SHALL fetch current prices from Pyth Network
6. THE Ordo_Backend SHALL record all blockchain transactions in the transactions table with status tracking

### Requirement 6: Transaction History and Monitoring

**User Story:** As a user, I want to view my transaction history, so that I can track my blockchain activities.

#### Acceptance Criteria

1. WHEN a user requests transaction history, THE Ordo_Backend SHALL return paginated transactions ordered by timestamp descending
2. WHEN a transaction is pending, THE Ordo_Backend SHALL poll Solana RPC for confirmation status
3. WHEN a transaction is confirmed, THE Ordo_Backend SHALL update the transaction status to "confirmed" with block number
4. WHEN a transaction fails, THE Ordo_Backend SHALL update the status to "failed" with error details
5. THE Ordo_Backend SHALL support filtering transactions by type, status, and date range

### Requirement 7: Plugin System

**User Story:** As a system administrator, I want to dynamically add new protocol integrations, so that the system can support new blockchain operations without code changes.

#### Acceptance Criteria

1. WHEN an admin installs a new Plugin, THE Ordo_Backend SHALL register the Plugin's Actions in the system
2. WHEN a Plugin is enabled, THE AI_Agent SHALL include the Plugin's Actions in available operations
3. WHEN a Plugin is disabled, THE Ordo_Backend SHALL prevent execution of the Plugin's Actions
4. WHEN a Plugin is uninstalled, THE Ordo_Backend SHALL remove all Plugin data and Actions from the system
5. THE Ordo_Backend SHALL validate Plugin compatibility before installation

### Requirement 8: AI Model Management

**User Story:** As a system administrator, I want to manage available AI models, so that I can optimize cost and performance.

#### Acceptance Criteria

1. WHEN an admin adds a new AI model, THE Ordo_Backend SHALL register the model with OpenRouter configuration
2. WHEN an admin sets a default model, THE AI_Agent SHALL use that model for all new conversations
3. WHEN an admin disables a model, THE Ordo_Backend SHALL prevent new conversations from using that model
4. WHEN a model API call fails, THE Ordo_Backend SHALL log the error and attempt fallback to alternative models
5. THE Ordo_Backend SHALL track model usage statistics (requests, tokens, costs)

### Requirement 9: Admin Dashboard and Monitoring

**User Story:** As a system administrator, I want to monitor system health and user activity, so that I can ensure reliable operations.

#### Acceptance Criteria

1. WHEN an admin requests dashboard data, THE Ordo_Backend SHALL return aggregated metrics (active users, transactions, success rates)
2. WHEN an admin views user list, THE Ordo_Backend SHALL return paginated users with wallet counts and last activity
3. WHEN an admin views transaction monitoring, THE Ordo_Backend SHALL return real-time transaction status with filtering capabilities
4. WHEN an admin performs any action, THE Ordo_Backend SHALL log the action in audit_logs with timestamp and admin identifier
5. THE Ordo_Backend SHALL calculate and display system performance metrics (response times, error rates)

### Requirement 10: Configuration Management

**User Story:** As a system administrator, I want to update system configuration dynamically, so that I can adjust settings without redeployment.

#### Acceptance Criteria

1. WHEN an admin updates configuration, THE Ordo_Backend SHALL validate the new values against schema constraints
2. WHEN configuration is updated, THE Ordo_Backend SHALL apply changes immediately without requiring restart
3. WHEN invalid configuration is submitted, THE Ordo_Backend SHALL reject the update and return validation errors
4. WHEN configuration changes affect active operations, THE Ordo_Backend SHALL complete in-flight operations before applying changes
5. THE Ordo_Backend SHALL maintain configuration history with rollback capability

### Requirement 11: Security and Rate Limiting

**User Story:** As a system administrator, I want to protect the API from abuse, so that the system remains available for legitimate users.

#### Acceptance Criteria

1. WHEN a client exceeds rate limits (100 requests per minute per IP), THE Ordo_Backend SHALL return 429 Too Many Requests
2. WHEN a user attempts unauthorized access to protected endpoints, THE Ordo_Backend SHALL return 403 Forbidden
3. WHEN SQL injection or XSS attempts are detected, THE Ordo_Backend SHALL sanitize inputs and log the attempt
4. WHEN sensitive data is logged, THE Ordo_Backend SHALL redact private keys, passwords, and tokens
5. THE Ordo_Backend SHALL enforce HTTPS for all API endpoints in production

### Requirement 12: Error Handling and Logging

**User Story:** As a developer, I want comprehensive error logging, so that I can debug issues quickly.

#### Acceptance Criteria

1. WHEN an error occurs, THE Ordo_Backend SHALL log the error with stack trace, request context, and timestamp
2. WHEN a blockchain transaction fails, THE Ordo_Backend SHALL log the transaction details and error reason
3. WHEN an external service (OpenRouter, Solana RPC) fails, THE Ordo_Backend SHALL log the failure and implement retry logic with exponential backoff
4. WHEN critical errors occur, THE Ordo_Backend SHALL send alerts to configured monitoring channels
5. THE Ordo_Backend SHALL categorize logs by severity (debug, info, warn, error, critical)

### Requirement 13: Database Schema and Data Integrity

**User Story:** As a developer, I want a well-structured database schema, so that data is organized and queryable efficiently.

#### Acceptance Criteria

1. THE Ordo_Backend SHALL define foreign key constraints between users, wallets, and transactions tables
2. WHEN a user is deleted, THE Ordo_Backend SHALL cascade delete associated wallets and transactions
3. WHEN concurrent updates occur, THE Ordo_Backend SHALL use database transactions to maintain consistency
4. WHEN storing encrypted data, THE Ordo_Backend SHALL store encryption metadata (algorithm, IV) alongside ciphertext
5. THE Ordo_Backend SHALL create indexes on frequently queried columns (user_id, transaction_status, created_at)

### Requirement 14: API Response Format and Validation

**User Story:** As a frontend developer, I want consistent API responses, so that I can handle responses predictably.

#### Acceptance Criteria

1. WHEN an API request succeeds, THE Ordo_Backend SHALL return responses in format: `{success: true, data: {...}}`
2. WHEN an API request fails, THE Ordo_Backend SHALL return responses in format: `{success: false, error: {code: string, message: string}}`
3. WHEN request validation fails, THE Ordo_Backend SHALL return 400 Bad Request with detailed validation errors
4. WHEN a resource is not found, THE Ordo_Backend SHALL return 404 Not Found with resource identifier
5. THE Ordo_Backend SHALL validate all request bodies against JSON schemas before processing

### Requirement 15: Conversation Context Management

**User Story:** As a user, I want the AI to remember our conversation context, so that I can have natural multi-turn interactions.

#### Acceptance Criteria

1. WHEN a user sends a message, THE AI_Agent SHALL retrieve the last 10 messages from the conversation history
2. WHEN context exceeds token limits, THE AI_Agent SHALL summarize older messages to maintain context
3. WHEN a user starts a new conversation, THE AI_Agent SHALL create a new conversation record with unique identifier
4. WHEN a conversation is inactive for 24 hours, THE Ordo_Backend SHALL archive the conversation
5. THE Ordo_Backend SHALL store conversation messages with role (user/assistant), content, and timestamp

### Requirement 16: Cross-Chain Bridge Operations

**User Story:** As a user, I want to bridge assets between chains, so that I can move my assets across different blockchains.

#### Acceptance Criteria

1. WHEN a user requests bridging assets, THE Solana_Agent_Kit SHALL validate source and destination chains are supported
2. WHEN bridge parameters are valid, THE Solana_Agent_Kit SHALL initiate the bridge transaction via supported bridge protocols
3. WHEN a bridge transaction is initiated, THE Ordo_Backend SHALL track the transaction across both chains
4. WHEN a bridge transaction completes, THE Ordo_Backend SHALL update transaction status with destination transaction hash
5. THE Ordo_Backend SHALL support bridging via Wormhole and AllBridge protocols

### Requirement 17: Price Feeds and Market Data

**User Story:** As a user, I want to get current token prices, so that I can make informed trading decisions.

#### Acceptance Criteria

1. WHEN a user requests token price, THE Solana_Agent_Kit SHALL fetch the price from Pyth Network
2. WHEN price data is unavailable, THE Ordo_Backend SHALL return the last known price with staleness indicator
3. WHEN multiple tokens are requested, THE Ordo_Backend SHALL batch the requests for efficiency
4. WHEN price data is fetched, THE Ordo_Backend SHALL cache the data for 30 seconds to reduce API calls
5. THE Ordo_Backend SHALL support price queries for all tokens with Pyth price feeds

### Requirement 18: NFT Operations

**User Story:** As a user, I want to manage NFTs, so that I can mint, transfer, and list NFTs for sale.

#### Acceptance Criteria

1. WHEN a user requests NFT minting, THE Solana_Agent_Kit SHALL create the NFT with metadata URI and return mint address
2. WHEN a user requests NFT transfer, THE Solana_Agent_Kit SHALL transfer the NFT to the specified recipient address
3. WHEN a user requests NFT listing, THE Solana_Agent_Kit SHALL list the NFT on supported marketplaces (Tensor, Magic Eden)
4. WHEN a user requests NFT metadata update, THE Solana_Agent_Kit SHALL update the metadata URI
5. THE Ordo_Backend SHALL validate NFT ownership before allowing transfer or listing operations

### Requirement 19: DeFi Protocol Integrations

**User Story:** As a user, I want to interact with DeFi protocols, so that I can lend, borrow, and earn yield on my assets.

#### Acceptance Criteria

1. WHEN a user requests lending, THE Solana_Agent_Kit SHALL deposit assets to lending protocols (Lulo, Marginfi)
2. WHEN a user requests borrowing, THE Solana_Agent_Kit SHALL validate collateral and execute borrow operation
3. WHEN a user requests yield farming, THE Solana_Agent_Kit SHALL stake assets in supported liquidity pools
4. WHEN a user requests position closure, THE Solana_Agent_Kit SHALL withdraw assets and return them to user wallet
5. THE Ordo_Backend SHALL track DeFi positions and calculate current value including accrued interest

### Requirement 20: Health Check and Service Status

**User Story:** As a DevOps engineer, I want health check endpoints, so that I can monitor service availability.

#### Acceptance Criteria

1. WHEN a health check is requested, THE Ordo_Backend SHALL verify database connectivity and return status
2. WHEN a health check is requested, THE Ordo_Backend SHALL verify Solana RPC connectivity and return status
3. WHEN a health check is requested, THE Ordo_Backend SHALL verify OpenRouter API connectivity and return status
4. WHEN any dependency is unhealthy, THE Ordo_Backend SHALL return 503 Service Unavailable with details
5. THE Ordo_Backend SHALL provide a `/health` endpoint for basic checks and `/health/detailed` for comprehensive diagnostics
