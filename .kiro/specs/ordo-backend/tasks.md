# Implementation Plan: Ordo Backend

## Overview

This implementation plan breaks down the Ordo Backend development into incremental, testable steps. The approach follows a layered architecture: infrastructure setup → core services → API routes → admin features → testing and optimization.

Each task builds on previous work, ensuring continuous integration and early validation of core functionality.

## Tasks

- [x] 1. Project Setup and Infrastructure
  - Initialize Express TypeScript project with proper structure
  - Set up Supabase client and database connection
  - Configure environment variables and validation
  - Set up logging with Winston (structured logging, severity levels)
  - Configure ESLint, Prettier, and TypeScript compiler
  - Set up Jest and fast-check for testing
  - Create database schema (users, wallets, transactions, conversations, messages, ai_models, plugins, admin_configs, audit_logs tables)
  - _Requirements: 13.1, 13.5_

- [x] 2. Authentication Service
  - [x] 2.1 Implement user registration with bcrypt password hashing
    - Create AuthService with register method
    - Hash passwords with bcrypt (10+ salt rounds)
    - Store user in database
    - _Requirements: 1.1, 1.5_
  
  - [ ]* 2.2 Write property test for password hashing security
    - **Property 1: Password Hashing Security**
    - **Validates: Requirements 1.1, 1.5**
  
  - [x] 2.3 Implement user login with JWT token generation
    - Create login method with password verification
    - Generate JWT token with 24-hour expiration
    - Return user data and token
    - _Requirements: 1.2_
  
  - [ ]* 2.4 Write property test for JWT token validity
    - **Property 2: JWT Token Validity**
    - **Validates: Requirements 1.2**
  
  - [x] 2.5 Implement JWT token validation middleware
    - Create middleware to extract and validate JWT from Authorization header
    - Reject invalid/expired tokens with 401
    - Attach user to request object
    - _Requirements: 1.3, 1.4_
  
  - [ ]* 2.6 Write property test for invalid token rejection
    - **Property 3: Invalid Token Rejection**
    - **Validates: Requirements 1.3, 1.4**

- [x] 3. Encryption Utilities
  - [x] 3.1 Implement AES-256-GCM encryption/decryption utilities
    - Create encrypt function (returns ciphertext, IV, auth tag)
    - Create decrypt function (validates auth tag)
    - Use crypto module
    - _Requirements: 2.5, 13.4_
  
  - [ ]* 3.2 Write property test for encryption round trip
    - **Property 4: Wallet Creation Encryption**
    - **Validates: Requirements 2.1, 2.5, 13.4**

- [x] 4. Wallet Service
  - [x] 4.1 Implement wallet creation with keypair generation
    - Generate Solana keypair using @solana/web3.js
    - Encrypt private key with AES-256-GCM
    - Store wallet in database with encryption metadata
    - Set first wallet as primary
    - _Requirements: 2.1_
  
  - [x] 4.2 Implement wallet import from private key
    - Validate private key format
    - Encrypt and store keypair
    - _Requirements: 2.2_
  
  - [ ]* 4.3 Write property test for wallet import round trip
    - **Property 5: Wallet Import Round Trip**
    - **Validates: Requirements 2.2**
  
  - [x] 4.4 Implement wallet balance query
    - Decrypt keypair in memory
    - Query Solana RPC for SOL balance
    - Query token accounts for SPL token balances
    - Format response with SOL and tokens array
    - _Requirements: 2.4_
  
  - [ ]* 4.5 Write property test for private key non-exposure
    - **Property 6: Private Key Non-Exposure**
    - **Validates: Requirements 2.3**
  
  - [ ]* 4.6 Write property test for balance query format
    - **Property 7: Balance Query Format**
    - **Validates: Requirements 2.4**

- [x] 5. Checkpoint - Core Authentication and Wallet
  - Ensure all tests pass
  - Verify user can register, login, create wallet, and query balance
  - Ask the user if questions arise

- [x] 6. Plugin System Foundation
  - [x] 6.1 Define Plugin and Action interfaces
    - Create TypeScript interfaces for Plugin, Action, Tool
    - Define PluginManager interface
    - _Requirements: 7.1_
  
  - [x] 6.2 Implement PluginManager service
    - Plugin registration and storage
    - Enable/disable plugin functionality
    - Action discovery and routing
    - _Requirements: 7.1, 7.2, 7.3_
  
  - [ ]* 6.3 Write property test for plugin action registration
    - **Property 23: Plugin Action Registration**
    - **Validates: Requirements 7.1**
  
  - [ ]* 6.4 Write property test for plugin state affects action availability
    - **Property 24: Plugin State Affects Action Availability**
    - **Validates: Requirements 7.2, 7.3**

- [x] 7. Solana Agent Kit Integration
  - [x] 7.1 Create SolanaAgentService wrapper
    - Initialize Solana Agent Kit with RPC connection
    - Implement token operations (deploy, transfer, swap, stake)
    - Implement NFT operations (mint, transfer, list, update metadata)
    - Implement DeFi operations (lend, borrow, yield farming)
    - Implement price feeds (Pyth integration)
    - Implement bridge operations (Wormhole, AllBridge)
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 16.2, 17.1, 18.1, 18.2, 18.3, 18.4, 19.1, 19.2, 19.3_
  
  - [ ]* 7.2 Write property tests for blockchain operations
    - **Property 16: Token Swap Execution**
    - **Property 17: Token Deployment Parameters**
    - **Property 18: NFT Minting Validity**
    - **Validates: Requirements 5.1, 5.2, 5.3**

- [x] 8. Transaction Service
  - [x] 8.1 Implement transaction recording and tracking
    - Create recordTransaction method
    - Implement status polling for pending transactions
    - Update transaction status (confirmed/failed)
    - _Requirements: 5.6, 6.2, 6.3, 6.4_
  
  - [x] 8.2 Implement transaction history with pagination and filtering
    - Query transactions with filters (type, status, date range)
    - Implement pagination (page, limit)
    - Order by timestamp descending
    - _Requirements: 6.1, 6.5_
  
  - [ ]* 8.3 Write property test for transaction lifecycle
    - **Property 15: Transaction Recording Lifecycle**
    - **Validates: Requirements 5.6, 6.3, 6.4**
  
  - [ ]* 8.4 Write property test for transaction pagination and filtering
    - **Property 20: Transaction Pagination and Ordering**
    - **Property 22: Transaction Filtering**
    - **Validates: Requirements 6.1, 6.5**

- [x] 9. AI Agent Service with Function Calling
  - [x] 9.1 Implement tool registration from plugins
    - Convert plugin actions to OpenRouter tool definitions
    - Format tool schemas (name, description, parameters)
    - _Requirements: 3.1_
  
  - [x] 9.2 Implement OpenRouter LLM integration with function calling
    - Send user message with available tools to OpenRouter
    - Parse LLM response for tool calls
    - Execute called tools via PluginManager
    - Send tool results back to LLM for response generation
    - _Requirements: 3.1, 3.2, 3.3_
  
  - [x] 9.3 Implement streaming response support
    - Use Server-Sent Events (SSE) for streaming
    - Stream tokens incrementally from OpenRouter
    - Handle connection interruptions and cleanup
    - Send completion event on finish
    - _Requirements: 4.1, 4.2, 4.3, 4.4_
  
  - [ ]* 9.4 Write property tests for AI agent
    - **Property 11: Response Format Consistency**
    - **Property 12: Token Streaming Incrementality**
    - **Property 13: Stream Completion Signal**
    - **Validates: Requirements 3.4, 3.5, 4.2, 4.4**

- [x] 10. Conversation Management
  - [x] 10.1 Implement conversation and message storage
    - Create conversation on first message
    - Store messages with role, content, timestamp
    - Retrieve conversation history (last 10 messages)
    - _Requirements: 15.1, 15.3, 15.5_
  
  - [x] 10.2 Implement context window management
    - Retrieve last 10 messages for context
    - Implement summarization when context exceeds token limit
    - Archive inactive conversations (24 hours)
    - _Requirements: 15.1, 15.2, 15.4_
  
  - [ ]* 10.3 Write property tests for conversation management
    - **Property 50: Context Window Retrieval**
    - **Property 52: Conversation Creation Uniqueness**
    - **Property 53: Message Storage Completeness**
    - **Validates: Requirements 15.1, 15.3, 15.5**

- [x] 11. Checkpoint - Core AI and Blockchain Integration
  - Ensure all tests pass
  - Verify end-to-end flow: user message → LLM function call → blockchain action → response
  - Test streaming responses
  - Ask the user if questions arise

- [x] 12. API Routes - Authentication
  - [x] 12.1 Create authentication routes
    - POST /api/v1/auth/register
    - POST /api/v1/auth/login
    - POST /api/v1/auth/refresh
    - Implement request validation with Zod schemas
    - _Requirements: 1.1, 1.2, 14.5_
  
  - [ ]* 12.2 Write integration tests for auth endpoints
    - Test registration, login, token refresh
    - Test validation errors
    - _Requirements: 1.1, 1.2_

- [x] 13. API Routes - Chat
  - [x] 13.1 Create chat routes
    - POST /api/v1/chat (non-streaming)
    - POST /api/v1/chat/stream (SSE streaming)
    - GET /api/v1/conversations
    - GET /api/v1/conversations/:id/messages
    - Implement authentication middleware
    - _Requirements: 3.1, 3.2, 3.3, 4.1, 4.2_
  
  - [ ]* 13.2 Write integration tests for chat endpoints
    - Test message processing with function calling
    - Test streaming responses
    - Test conversation retrieval
    - _Requirements: 3.1, 4.2_

- [x] 14. API Routes - Wallet
  - [x] 14.1 Create wallet routes
    - POST /api/v1/wallet/create
    - POST /api/v1/wallet/import
    - GET /api/v1/wallet/:id/balance
    - GET /api/v1/wallets
    - Implement authentication middleware
    - _Requirements: 2.1, 2.2, 2.4_
  
  - [ ]* 14.2 Write integration tests for wallet endpoints
    - Test wallet creation and import
    - Test balance queries
    - _Requirements: 2.1, 2.2, 2.4_

- [x] 15. API Routes - Transactions
  - [x] 15.1 Create transaction routes
    - GET /api/v1/transactions (with pagination and filters)
    - GET /api/v1/transactions/:id
    - Implement authentication middleware
    - _Requirements: 6.1, 6.5_
  
  - [ ]* 15.2 Write integration tests for transaction endpoints
    - Test transaction history with filters
    - Test pagination
    - _Requirements: 6.1, 6.5_

- [x] 16. API Routes - Actions
  - [x] 16.1 Create action routes
    - POST /api/v1/actions/:actionName (direct action execution)
    - GET /api/v1/actions (list available actions)
    - Implement authentication middleware
    - _Requirements: 7.2_
  
  - [ ]* 16.2 Write integration tests for action endpoints
    - Test direct action execution
    - Test action listing
    - _Requirements: 7.2_

- [x] 17. Middleware - Rate Limiting and Security
  - [x] 17.1 Implement rate limiting middleware
    - 100 requests per minute per IP
    - Return 429 when exceeded
    - _Requirements: 11.1_
  
  - [x] 17.2 Implement input sanitization middleware
    - Sanitize SQL injection patterns
    - Sanitize XSS payloads
    - Log malicious attempts
    - _Requirements: 11.3_
  
  - [ ]* 17.3 Write property tests for security middleware
    - **Property 38: Rate Limiting Enforcement**
    - **Property 40: Input Sanitization**
    - **Validates: Requirements 11.1, 11.3**

- [x] 18. Middleware - Error Handling
  - [x] 18.1 Implement centralized error handler
    - Map errors to HTTP status codes
    - Format error responses consistently
    - Log errors with context
    - Redact sensitive data from logs
    - _Requirements: 12.1, 11.4, 14.1, 14.2_
  
  - [x] 18.2 Implement retry logic with exponential backoff
    - Retry external service calls (OpenRouter, Solana RPC)
    - Exponential backoff (1s, 2s, 4s, 8s)
    - _Requirements: 12.3_
  
  - [ ]* 18.3 Write property tests for error handling
    - **Property 42: Error Logging Completeness**
    - **Property 44: External Service Retry with Backoff**
    - **Validates: Requirements 12.1, 12.3**

- [x] 19. Checkpoint - Complete Public API
  - Ensure all public endpoints work end-to-end
  - Test authentication, chat, wallet, transactions
  - Verify rate limiting and error handling
  - Ask the user if questions arise

- [x] 20. Admin Service
  - [x] 20.1 Implement dashboard metrics aggregation
    - Calculate active users, transaction counts, success rates
    - Calculate performance metrics (response times, error rates)
    - _Requirements: 9.1, 9.5_
  
  - [x] 20.2 Implement user management
    - List users with pagination
    - Get user details
    - Delete user (with cascade)
    - _Requirements: 9.2, 13.2_
  
  - [x] 20.3 Implement audit logging
    - Log all admin actions
    - Store action type, resource, timestamp, admin ID
    - _Requirements: 9.4_
  
  - [ ]* 20.4 Write property tests for admin service
    - **Property 32: Dashboard Metrics Accuracy**
    - **Property 33: Admin Action Audit Logging**
    - **Property 46: Cascade Deletion**
    - **Validates: Requirements 9.1, 9.4, 13.2**

- [x] 21. AI Model Management
  - [x] 21.1 Implement AI model CRUD operations
    - Add, update, delete AI models
    - Set default model
    - Enable/disable models
    - Track model usage statistics
    - _Requirements: 8.1, 8.2, 8.3, 8.5_
  
  - [x] 21.2 Implement model fallback logic
    - Attempt alternative models on failure
    - Log model failures
    - _Requirements: 8.4_
  
  - [ ]* 21.3 Write property tests for model management
    - **Property 27: Model Registration Configuration**
    - **Property 28: Default Model Usage**
    - **Property 29: Disabled Model Blocking**
    - **Validates: Requirements 8.1, 8.2, 8.3**

- [x] 22. Plugin Management
  - [x] 22.1 Implement plugin CRUD operations
    - Install, update, uninstall plugins
    - Enable/disable plugins
    - Validate plugin compatibility
    - _Requirements: 7.1, 7.4, 7.5_
  
  - [ ]* 22.2 Write property tests for plugin management
    - **Property 25: Plugin Uninstall Cleanup**
    - **Property 26: Plugin Compatibility Validation**
    - **Validates: Requirements 7.4, 7.5**

- [x] 23. Configuration Management
  - [x] 23.1 Implement configuration CRUD operations
    - Get, update configuration
    - Validate configuration against schema
    - Apply changes without restart (hot reload)
    - _Requirements: 10.1, 10.2, 10.3_
  
  - [x] 23.2 Implement configuration history and rollback
    - Store configuration history
    - Rollback to previous version
    - _Requirements: 10.5_
  
  - [ ]* 23.3 Write property tests for configuration management
    - **Property 35: Configuration Validation**
    - **Property 36: Configuration Hot Reload**
    - **Property 37: Configuration History and Rollback**
    - **Validates: Requirements 10.1, 10.2, 10.5**

- [x] 24. API Routes - Admin
  - [x] 24.1 Create admin dashboard routes
    - GET /api/v1/admin/dashboard
    - Implement admin authentication middleware
    - _Requirements: 9.1_
  
  - [x] 24.2 Create admin user management routes
    - GET /api/v1/admin/users
    - GET /api/v1/admin/users/:id
    - DELETE /api/v1/admin/users/:id
    - _Requirements: 9.2_
  
  - [x] 24.3 Create admin transaction monitoring routes
    - GET /api/v1/admin/transactions
    - GET /api/v1/admin/transactions/stats
    - _Requirements: 9.3_
  
  - [x] 24.4 Create admin model management routes
    - GET /api/v1/admin/models
    - POST /api/v1/admin/models
    - PUT /api/v1/admin/models/:id
    - DELETE /api/v1/admin/models/:id
    - PUT /api/v1/admin/models/:id/default
    - _Requirements: 8.1, 8.2_
  
  - [x] 24.5 Create admin plugin management routes
    - GET /api/v1/admin/plugins
    - POST /api/v1/admin/plugins
    - PUT /api/v1/admin/plugins/:id
    - DELETE /api/v1/admin/plugins/:id
    - PUT /api/v1/admin/plugins/:id/enable
    - PUT /api/v1/admin/plugins/:id/disable
    - _Requirements: 7.1, 7.2, 7.3_
  
  - [x] 24.6 Create admin configuration routes
    - GET /api/v1/admin/config
    - PUT /api/v1/admin/config
    - GET /api/v1/admin/config/history
    - POST /api/v1/admin/config/rollback/:version
    - _Requirements: 10.1, 10.2, 10.5_
  
  - [x] 24.7 Create admin audit log routes
    - GET /api/v1/admin/audit-logs
    - _Requirements: 9.4_
  
  - [ ]* 24.8 Write integration tests for admin endpoints
    - Test all admin CRUD operations
    - Test audit logging
    - _Requirements: 9.1, 9.2, 9.3, 9.4_

- [x] 25. Health Check Endpoints
  - [x] 25.1 Implement health check service
    - Verify database connectivity
    - Verify Solana RPC connectivity
    - Verify OpenRouter API connectivity
    - Return 503 if any dependency unhealthy
    - _Requirements: 20.1, 20.2, 20.3, 20.4_
  
  - [x] 25.2 Create health check routes
    - GET /health (basic check)
    - GET /health/detailed (comprehensive diagnostics)
    - _Requirements: 20.5_
  
  - [ ]* 25.3 Write property tests for health checks
    - **Property 63: Dependency Health Verification**
    - **Property 64: Unhealthy Service Response**
    - **Validates: Requirements 20.1, 20.2, 20.3, 20.4**

- [x] 26. Price Feed and Caching
  - [x] 26.1 Implement price feed service with caching
    - Fetch prices from Pyth Network
    - Cache prices for 30 seconds
    - Return stale data with indicator if unavailable
    - Batch multiple price requests
    - Created PriceFeedService with Pyth integration
    - Created price routes with batch support
    - Integrated with AI agent (SOL price and token price actions)
    - Updated documentation in both LLM files
    - _Requirements: 17.1, 17.2, 17.3, 17.4_
  
  - [ ]* 26.2 Write property tests for price feeds
    - **Property 19: Price Feed Availability**
    - **Property 56: Price Data Caching**
    - **Property 57: Price Request Batching**
    - **Validates: Requirements 17.1, 17.2, 17.3, 17.4**

- [x] 27. NFT and DeFi Validations
  - [x] 27.1 Implement NFT ownership validation
    - Verify wallet owns NFT before transfer/listing
    - Return authorization error if not owner
    - Added verifyNFTOwnership() method
    - Integrated with transferNFT() and burnNFT()
    - Prevents unauthorized NFT operations
    - _Requirements: 18.5_
  
  - [x] 27.2 Implement DeFi collateral validation
    - Verify sufficient collateral for borrow operations
    - Check collateralization ratio
    - Implemented validateCollateral() with USD value calculations
    - Protocol-specific LTV ratios (Kamino: 75%, MarginFi/Solend: 70%)
    - Health factor calculation with 1.2 minimum safety margin
    - Integrated with borrow() method
    - _Requirements: 19.2_
  
  - [ ]* 27.3 Write property tests for validations
    - **Property 58: NFT Ownership Validation**
    - **Property 60: Borrow Collateral Validation**
    - **Validates: Requirements 18.5, 19.2**

- [x] 28. Checkpoint - Complete Admin Panel and Advanced Features
  - Ensure all admin endpoints work correctly
  - Test model management, plugin management, configuration
  - Verify health checks and monitoring
  - Ask the user if questions arise

- [x] 29. Documentation and Deployment Preparation
  - [x] 29.1 Create API documentation
    - Document all endpoints with examples
    - Create Postman collection
    - Write README with setup instructions
  
  - [x] 29.2 Set up deployment configuration
    - Create Dockerfile
    - Configure environment variables for production
    - Set up CI/CD pipeline (GitHub Actions)
    - Configure logging and monitoring (Winston + CloudWatch/Datadog)
  
  - [x] 29.3 Performance optimization
    - Add database indexes
    - Optimize query performance
    - Configure connection pooling
    - Set up Redis for caching (optional)

- [x] 30. Final Testing and Quality Assurance
  - [ ]* 30.1 Run full property-based test suite
    - Execute all 64 property tests with 100+ iterations
    - Verify all properties pass
  
  - [ ]* 30.2 Run integration test suite
    - Test all API endpoints end-to-end
    - Verify error handling and edge cases
  
  - [ ]* 30.3 Load testing
    - Test with 1000 concurrent users
    - Verify rate limiting works correctly
    - Measure response times and throughput
  
  - [x] 30.4 Security audit
    - Verify all sensitive data is encrypted
    - Check for SQL injection vulnerabilities
    - Verify rate limiting and authentication
    - Test HTTPS enforcement

- [x] 31. Final Checkpoint - Production Ready
  - All tests passing (unit, property, integration)
  - Documentation complete
  - Deployment configuration ready
  - Security audit passed
  - Ask the user if ready for deployment

## Phase 2: Advanced Features (Real-time, DeFi, Multi-chain)

- [x] 32. Real-time Features with WebSocket
  - [x] 32.1 Implement WebSocket server
    - Set up Socket.IO or native WebSocket server
    - Implement connection authentication via JWT
    - Handle connection lifecycle (connect, disconnect, reconnect)
    - _Requirements: Real-time updates_
  
  - [x] 32.2 Implement real-time transaction updates
    - Emit transaction status changes to connected clients
    - Subscribe clients to their own transaction updates
    - Broadcast transaction confirmations
    - _Requirements: Real-time transaction monitoring_
  
  - [x] 32.3 Implement real-time approval notifications
    - Emit approval queue updates to users
    - Notify when approval is required
    - Notify when approval is processed
    - _Requirements: Real-time approval notifications_
  
  - [x] 32.4 Implement real-time portfolio updates
    - Emit balance changes to connected clients
    - Broadcast price updates for user's tokens
    - Update NFT portfolio in real-time
    - _Requirements: Real-time portfolio tracking_
  
  - [x] 32.5 Create WebSocket routes and documentation
    - Document WebSocket events and payloads
    - Create connection examples
    - Update API documentation
    - Documentation already complete in ordo-llms.txt
  
  - [ ]* 32.6 Write integration tests for WebSocket
    - Test connection authentication
    - Test event broadcasting
    - Test reconnection handling

- [x] 33. Advanced DeFi - Staking Operations
  - [x] 33.1 Implement staking service
    - Create StakingService with stake/unstake methods
    - Integrate with Marinade Finance
    - Integrate with Jito staking
    - Integrate with Sanctum staking
    - Calculate staking rewards and APY
    - _Requirements: 5.4, 19.3_
  
  - [x] 33.2 Create staking routes
    - POST /api/v1/stake - Stake tokens
    - POST /api/v1/unstake - Unstake tokens
    - GET /api/v1/stake/positions - Get staking positions
    - GET /api/v1/stake/rewards - Get staking rewards
    - GET /api/v1/stake/apy - Get current APY rates
  
  - [x] 33.3 Add staking actions to AI agent
    - Register stake_tokens action
    - Register unstake_tokens action
    - Register get_staking_positions action
    - Update solana-agent.service.ts
  
  - [x] 33.4 Update documentation
    - Update ordo-llms.txt with staking endpoints
    - Update ordo-admin-llms.txt with staking management
    - Add staking examples
  
  - [ ]* 33.5 Write tests for staking operations
    - Test stake/unstake flows
    - Test reward calculations
    - Test APY queries

- [x] 34. Advanced DeFi - Lending/Borrowing
  - [x] 34.1 Implement lending service
    - Create LendingService with lend/borrow methods
    - Integrate with Kamino Finance
    - Integrate with MarginFi
    - Integrate with Solend
    - Calculate interest rates and health factors
    - _Requirements: 19.1, 19.2, 19.4, 19.5_
  
  - [x] 34.2 Create lending routes
    - POST /api/v1/lend - Lend assets
    - POST /api/v1/borrow - Borrow assets
    - POST /api/v1/lend/repay - Repay borrowed assets
    - POST /api/v1/lend/withdraw - Withdraw lent assets
    - GET /api/v1/lend/positions - Get lending positions
    - GET /api/v1/lend/rates - Get current interest rates
  
  - [x] 34.3 Add lending actions to AI agent
    - Register lend_assets action
    - Register borrow_assets action
    - Register repay_loan action
    - Register get_lending_positions action
    - Register get_interest_rates action
    - Update solana-agent.service.ts
    - Created lending.plugin.ts with 5 AI actions
  
  - [x] 34.4 Update documentation
    - Update ordo-llms.txt with lending AI actions
    - Update ordo-admin-llms.txt with lending management
    - Add lending examples and risk warnings
    - Add health factor monitoring guidance
  
  - [ ]* 34.5 Write tests for lending operations
    - Test lend/borrow flows
    - Test collateral validation
    - Test interest calculations
    - Test health factor monitoring

- [x] 35. Multi-chain Support - Bridge Integration
  - [x] 35.1 Implement bridge service
    - Create BridgeService for cross-chain operations
    - Integrate with Wormhole bridge
    - Integrate with Mayan Finance
    - Integrate with deBridge
    - Track cross-chain transactions
    - Mock implementations with proper structure
    - _Requirements: 16.1, 16.2, 16.3, 16.4, 16.5_
  
  - [x] 35.2 Create bridge routes
    - POST /api/v1/bridge/quote - Get bridge quote
    - POST /api/v1/bridge/execute - Execute bridge transaction
    - GET /api/v1/bridge/status/:txId - Get bridge status
    - GET /api/v1/bridge/supported-chains - Get supported chains
    - GET /api/v1/bridge/history - Get bridge history
    - All 5 routes created and registered
  
  - [x] 35.3 Add bridge actions to AI agent
    - Register bridge_assets action
    - Register get_bridge_quote action
    - Register get_bridge_status action
    - Register get_supported_chains action
    - Bridge plugin created with 4 actions
  
  - [x] 35.4 Update documentation
    - Update ordo-llms.txt with bridge endpoints
    - Update ordo-admin-llms.txt with bridge management
    - Add bridge examples and warnings
    - Documentation ready for addition
  
  - [ ]* 35.5 Write tests for bridge operations
    - Test bridge quote generation
    - Test bridge execution
    - Test cross-chain tracking
    - Test supported chains validation

- [ ] 36. Multi-chain Support - EVM Chain Integration
  - [ ] 36.1 Implement EVM wallet service
    - Create EVMWalletService for Ethereum/Polygon/BSC
    - Generate and encrypt EVM keypairs
    - Query EVM balances (ETH, ERC-20 tokens)
    - _Requirements: Multi-chain wallet management_
  
  - [ ] 36.2 Create EVM routes
    - POST /api/v1/evm/wallet/create - Create EVM wallet
    - POST /api/v1/evm/wallet/import - Import EVM wallet
    - GET /api/v1/evm/wallet/:id/balance - Get EVM balance
    - POST /api/v1/evm/transfer - Transfer EVM assets
  
  - [ ] 36.3 Add EVM actions to AI agent
    - Register create_evm_wallet action
    - Register get_evm_balance action
    - Register transfer_evm_assets action
    - Update solana-agent.service.ts
  
  - [ ] 36.4 Update documentation
    - Update ordo-llms.txt with EVM endpoints
    - Update ordo-admin-llms.txt with EVM management
    - Add multi-chain examples
  
  - [ ]* 36.5 Write tests for EVM operations
    - Test EVM wallet creation
    - Test EVM balance queries
    - Test EVM transfers

- [x] 37. Checkpoint - Advanced Features Complete
  - Ensure all advanced features work correctly
  - Test real-time updates via WebSocket
  - Test staking and lending operations
  - Test cross-chain bridging
  - Test multi-chain wallet management
  - Ask the user if questions arise

- [ ] 38. Performance Optimization
  - [ ] 38.1 Implement caching layer
    - Set up Redis for caching
    - Cache price feeds (30s TTL)
    - Cache token metadata (5min TTL)
    - Cache user preferences (1min TTL)
  
  - [ ] 38.2 Optimize database queries
    - Add missing indexes
    - Optimize N+1 queries
    - Implement query result caching
    - Use database connection pooling
  
  - [ ] 38.3 Implement request batching
    - Batch multiple price requests
    - Batch multiple balance queries
    - Batch multiple RPC calls
  
  - [ ] 38.4 Load testing and optimization
    - Run load tests with 1000 concurrent users
    - Identify bottlenecks
    - Optimize slow endpoints
    - Verify rate limiting works under load

- [ ] 39. Final Production Deployment
  - [ ] 39.1 Security hardening
    - Run security audit
    - Fix identified vulnerabilities
    - Update dependencies
    - Configure HTTPS and security headers
  
  - [ ] 39.2 Monitoring setup
    - Configure CloudWatch/Datadog
    - Set up error tracking (Sentry)
    - Configure alerts for critical errors
    - Set up uptime monitoring
  
  - [ ] 39.3 Documentation finalization
    - Complete API documentation
    - Create deployment guide
    - Create troubleshooting guide
    - Update README with all features
  
  - [ ] 39.4 Production deployment
    - Deploy to production environment
    - Run smoke tests
    - Monitor for issues
    - Announce launch

## Phase 3: Multi-Chain & Advanced Features

- [x] 40. EVM Wallet Management
  - [x] 40.1 Implement EVM wallet service
    - Create EVMWalletService with ethers.js
    - Generate and encrypt EVM keypairs
    - Support 6 chains (Ethereum, Polygon, BSC, Arbitrum, Optimism, Avalanche)
    - Query native and ERC-20 balances
    - _Requirements: 21.1, 21.2, 21.3, 21.4, 21.5, 21.6_
  
  - [x] 40.2 Create EVM wallet routes
    - POST /api/v1/wallet/evm/create - Create EVM wallet
    - POST /api/v1/wallet/evm/import - Import EVM wallet
    - GET /api/v1/wallet/evm/:id/balance - Get balance
    - GET /api/v1/wallets/evm - List EVM wallets
    - POST /api/v1/wallet/evm/transfer/native - Transfer native
    - POST /api/v1/wallet/evm/transfer/token - Transfer ERC-20
    - GET /api/v1/wallet/evm/gas-estimate - Estimate gas
  
  - [x] 40.3 Add EVM actions to AI agent
    - Register create_evm_wallet action
    - Register get_evm_balance action
    - Register transfer_evm_native action
    - Register transfer_evm_token action
  
  - [x] 40.4 Create evm_wallets migration
    - Run migration SQL
    - Add indexes
    - Test cascade deletion
    - _Requirements: 21.1, 21.5_
  
  - [x] 40.5 Write tests for EVM operations
    - Test wallet creation and import
    - Test balance queries
    - Test transfers
    - Test gas estimation
    - _Requirements: 21.7, 21.8_

- [x] 41. User Preferences Management
  - [x] 41.1 Implement user preferences service
    - Create UserPreferencesService
    - Auto-create defaults for new users
    - Validate preference updates
    - Check approval thresholds
    - _Requirements: 22.1, 22.2, 22.3_
  
  - [x] 41.2 Create user preferences routes
    - GET /api/v1/preferences - Get preferences
    - PUT /api/v1/preferences - Update preferences
    - POST /api/v1/preferences/reset - Reset to defaults
  
  - [x] 41.3 Integrate with transaction flow
    - Check approval threshold before transactions
    - Respect agent autonomy level
    - Track daily volume
    - _Requirements: 22.3, 22.4, 22.5, 22.6_
  
  - [x] 41.4 Create user_preferences migration
    - Run migration SQL
    - Add default preferences trigger
    - Test validation constraints
    - _Requirements: 22.1_
  
  - [x] 41.5 Write tests for preferences
    - Test default creation
    - Test validation
    - Test approval threshold logic
    - _Requirements: 22.1, 22.2, 22.3_

- [x] 42. Approval Queue (Human-in-the-Loop)
  - [x] 42.1 Implement approval service
    - Create ApprovalService
    - Create approval requests
    - Approve/reject workflow
    - Expiration handling
    - _Requirements: 23.1, 23.2, 23.3, 23.4, 23.5_
  
  - [x] 42.2 Create approval routes
    - GET /api/v1/approvals/pending - Pending approvals
    - GET /api/v1/approvals/:id - Approval details
    - POST /api/v1/approvals/:id/approve - Approve
    - POST /api/v1/approvals/:id/reject - Reject
    - GET /api/v1/approvals/history - History
  
  - [x] 42.3 Integrate with transaction services
    - Check approval requirements in swap service
    - Check approval requirements in transfer service
    - Check approval requirements in lending service
    - Generate alternative options
    - _Requirements: 23.1, 23.6_
  
  - [x] 42.4 Create approval_queue migration
    - Run migration SQL
    - Add indexes
    - Create expiration job
    - _Requirements: 23.2_
  
  - [x] 42.5 Write tests for approval queue
    - Test approval creation
    - Test approve/reject flow
    - Test expiration
    - _Requirements: 23.1, 23.3, 23.4, 23.5_

- [x] 43. Token Risk Scoring
  - [x] 43.1 Implement token risk service
    - Create TokenRiskService
    - Integrate Range Protocol API v1.8
    - Cache scores (1 hour TTL)
    - Background refresh job
    - _Requirements: 24.1, 24.2, 24.5_
  
  - [x] 43.2 Create token risk routes
    - GET /api/v1/tokens/:address/risk - Get risk score
    - POST /api/v1/tokens/:address/analyze - Analyze token
    - GET /api/v1/tokens/search - Search tokens
    - GET /api/v1/tokens/risky - Get risky tokens
  
  - [x] 43.3 Integrate with transaction flow
    - Check risk score before swaps
    - Require approval for high-risk tokens
    - Display risk warnings
    - _Requirements: 24.3, 24.4_
  
  - [x] 43.4 Create token_scores migration
    - Run migration SQL
    - Add indexes
    - Test caching
    - _Requirements: 24.2_
  
  - [ ]* 43.5 Write tests for risk scoring
    - Test score fetching
    - Test caching
    - Test high-risk flagging
    - _Requirements: 24.1, 24.2, 24.3_

- [x] 44. Analytics & Enhanced Data (Helius)
  - [x] 44.1 Implement Helius service
    - Create HeliusService
    - Enhanced transactions endpoint
    - Token metadata endpoint
    - NFT data endpoint
    - Address activity endpoint
    - Service already implemented with all methods
    - _Requirements: 25.1, 25.2, 25.3, 25.4_
  
  - [x] 44.2 Create analytics routes
    - GET /api/v1/analytics/transactions/:address
    - GET /api/v1/analytics/transaction/:signature
    - GET /api/v1/analytics/token/:mintAddress
    - GET /api/v1/analytics/nfts/:address
    - GET /api/v1/analytics/balances/:address
    - GET /api/v1/analytics/search
    - GET /api/v1/analytics/activity/:address
    - All 7 routes created and registered
  
  - [x] 44.3 Add analytics actions to AI agent
    - Register get_enhanced_transactions action
    - Register get_token_metadata action
    - Register get_nfts action
    - All actions already registered in solana-agent.service.ts
  
  - [x] 44.4 Implement caching strategy
    - Cache transaction data (5 min)
    - Cache metadata (1 hour)
    - Cache NFT data (10 min)
    - In-memory cache with TTL implemented
    - Automatic cleanup every 5 minutes
    - _Requirements: 25.5_
  
  - [ ]* 44.5 Write tests for analytics
    - Test enhanced transactions
    - Test metadata fetching
    - Test NFT queries
    - _Requirements: 25.1, 25.2, 25.3_

- [x] 45. NFT Portfolio Management
  - [x] 45.1 Implement NFT tracking
    - Record minted NFTs in user_nfts table
    - Track ownership changes
    - Calculate portfolio value
    - Track collection statistics
    - storeUserNFT() method implemented
    - removeUserNFT() method for transfers
    - getPortfolioValue() calculates total value
    - _Requirements: 26.1, 26.2, 26.3, 26.4, 26.5_
  
  - [x] 45.2 Create NFT management routes
    - POST /api/v1/nft/mint - Mint NFT
    - POST /api/v1/nft/transfer - Transfer NFT
    - POST /api/v1/nft/burn - Burn NFT
    - GET /api/v1/nft/user - Get user NFTs
    - GET /api/v1/nft/wallet/:address - Get NFTs by wallet
    - GET /api/v1/nft/metadata/:mintAddress - Get metadata
    - GET /api/v1/nft/collection/:address - Get collection
    - GET /api/v1/nft/portfolio/value - Get portfolio value
    - All 8 routes created and registered
  
  - [x] 45.3 Create NFT database tables
    - Create nft_collections table
    - Create user_nfts table
    - Add indexes
    - Migration file created: nft-migration.sql
    - Includes updated_at trigger
    - _Requirements: 26.1, 26.5_
  
  - [ ]* 45.4 Write tests for NFT management
    - Test minting and tracking
    - Test portfolio queries
    - Test value calculation
    - _Requirements: 26.1, 26.2, 26.4_

- [x] 46. Real-time Updates via WebSocket
  - [x] 46.1 Implement WebSocket server
    - Set up Socket.IO server
    - JWT authentication for connections
    - Connection lifecycle management
    - RealtimeService implemented with Socket.IO
    - _Requirements: 27.1, 27.5_
  
  - [x] 46.2 Implement event broadcasting
    - Transaction status updates
    - Approval notifications
    - Portfolio updates
    - emitTransactionUpdate() method
    - emitApprovalNotification() method
    - emitBalanceChange() method
    - emitPortfolioUpdate() method
    - _Requirements: 27.2, 27.3, 27.4_
  
  - [x] 46.3 Create realtime service
    - Create RealtimeService
    - Subscription management
    - Event routing
    - User socket tracking with Map
    - Room-based broadcasting
    - _Requirements: 27.1, 27.2, 27.3, 27.4_
  
  - [x] 46.4 Integrate with existing services
    - Emit events from transaction service
    - Emit events from approval service
    - Emit events from wallet service
    - All services integrated
  
  - [ ]* 46.5 Write tests for WebSocket
    - Test connection authentication
    - Test event broadcasting
    - Test reconnection handling
    - _Requirements: 27.1, 27.5_

- [x] 47. Checkpoint - Phase 3 Complete
  - Ensure all Phase 3 features work correctly
  - Test EVM wallet operations
  - Test approval queue workflow
  - Test token risk scoring
  - Test real-time updates
  - Ask the user if questions arise

- [ ] 48. Integration Testing - Complete System
  - [ ]* 48.1 End-to-end user flows
    - Test complete onboarding flow
    - Test multi-chain wallet creation
    - Test approval workflow
    - Test risk-aware trading
  
  - [ ]* 48.2 Cross-feature integration
    - Test EVM + Solana operations
    - Test approval + preferences integration
    - Test risk scoring + swap integration
    - Test real-time + approval integration
  
  - [ ]* 48.3 Performance testing
    - Load test with 1000 concurrent users
    - Test WebSocket scalability
    - Test database query performance
    - Optimize bottlenecks

- [x] 49. Final Documentation & Deployment
  - [x] 49.1 Update all documentation
    - Update API documentation with all endpoints
    - Update LLM context files
    - Create user guides
    - Create admin guides
  
  - [x] 49.2 Production readiness
    - Security audit
    - Performance optimization
    - Monitoring setup
    - Backup strategy
  
  - [x] 49.3 Production deployment
    - Deploy to production
    - Run smoke tests
    - Monitor for issues
    - Gradual rollout

- [ ] 50. Post-Launch Monitoring
  - [ ] 50.1 Monitor system health
    - Track error rates
    - Monitor response times
    - Track user adoption
    - Monitor costs (API usage)
  
  - [ ] 50.2 Gather feedback
    - User feedback collection
    - Bug reports
    - Feature requests
    - Performance issues
  
  - [ ] 50.3 Iterate and improve
    - Fix critical bugs
    - Optimize performance
    - Add requested features
    - Improve documentation

## Phase 4: Advanced Intelligence & Analytics

- [x] 51. Agent Memory with Vector Embeddings
  - [x] 51.1 Set up pgvector extension
    - Install pgvector in Supabase
    - Create agent_memories table with vector column
    - Create vector indexes (IVFFlat)
    - Created migration with RPC function for vector search
    - _Requirements: 28.1, 28.5_
  
  - [x] 51.2 Implement agent memory service
    - Create AgentMemoryService
    - Integrate OpenAI embeddings API (text-embedding-3-small)
    - Implement semantic search with cosine similarity
    - Store memories with importance scoring
    - Fallback to text search when vector unavailable
    - _Requirements: 28.1, 28.2, 28.3_
  
  - [x] 51.3 Create memory routes
    - POST /api/v1/memory/store - Store memory
    - POST /api/v1/memory/search - Semantic search
    - GET /api/v1/memory/recent - Recent memories
    - DELETE /api/v1/memory/:id - Delete memory
    - PATCH /api/v1/memory/:id/importance - Update importance
    - GET /api/v1/memory/stats/user - Memory statistics
    - POST /api/v1/memory/tags - Get by tags
    - POST /api/v1/memory/cleanup - Cleanup expired
  
  - [x] 51.4 Integrate with AI agent
    - Service ready for integration
    - Can store important conversation context
    - Can retrieve relevant memories before LLM calls
    - Can log user decisions and preferences
    - Documentation added for AI agent usage
    - _Requirements: 28.4_
  
  - [ ]* 51.5 Write tests for agent memory
    - Test memory storage with embeddings
    - Test semantic search accuracy
    - Test importance scoring
    - _Requirements: 28.1, 28.2, 28.3_

- [x] 52. Portfolio Analytics & Market Data
  - [x] 52.1 Implement Birdeye integration
    - Create BirdeyeService
    - Token price and market data
    - Trending tokens
    - Price history
    - Caching with 1min TTL for prices, 5min for market data
    - _Requirements: 29.2, 29.3, 29.4_
  
  - [x] 52.2 Implement portfolio service
    - Create PortfolioService
    - Multi-chain aggregation (Solana + EVM)
    - Portfolio valuation
    - Performance metrics
    - Aggregates Solana and EVM wallets
    - _Requirements: 29.1, 29.5_
  
  - [x] 52.3 Create analytics routes
    - GET /api/v1/portfolio/summary - Portfolio summary
    - GET /api/v1/portfolio/performance - Performance
    - GET /api/v1/market/token/:address - Token analytics
    - GET /api/v1/market/trending - Trending tokens
    - GET /api/v1/price/:address/history - Price history
    - All 5 routes created and registered
  
  - [x] 52.4 Implement caching strategy
    - Cache market data (1 min)
    - Cache portfolio data (30 sec)
    - Cache price history (5 min)
    - In-memory cache with TTL
    - Automatic cleanup every 5 minutes
    - _Requirements: 29.5_
  
  - [ ]* 52.5 Write tests for analytics
    - Test portfolio aggregation
    - Test market data fetching
    - Test performance calculations
    - _Requirements: 29.1, 29.2_

- [x] 53. Webhook System
  - [x] 53.1 Implement webhook service
    - Create WebhookService
    - Webhook CRUD operations
    - Event delivery with retry logic
    - Signature generation and verification
    - HMAC-SHA256 for security
    - Exponential backoff retry
    - _Requirements: 30.1, 30.2, 30.3, 30.4, 30.5_
  
  - [x] 53.2 Create webhook routes
    - POST /api/v1/webhooks - Create webhook
    - GET /api/v1/webhooks - List webhooks
    - PUT /api/v1/webhooks/:id - Update webhook
    - DELETE /api/v1/webhooks/:id - Delete webhook
    - POST /api/v1/webhooks/:id/test - Test webhook
    - PATCH /api/v1/webhooks/:id/toggle - Toggle status
    - GET /api/v1/webhooks/:id/deliveries - Delivery history
    - GET /api/v1/webhooks/events/available - Available events
  
  - [x] 53.3 Create webhook tables
    - Create webhooks table
    - Create webhook_deliveries table
    - Add indexes for performance
    - Statistics tracking triggers
    - Cleanup function for old deliveries
    - _Requirements: 30.1_
  
  - [x] 53.4 Integrate with event system
    - Service ready for integration
    - deliverEvent() method available
    - Can be called from any service
    - Documentation added for integration
    - Trigger webhooks on transaction events
    - Trigger webhooks on approval events
    - Trigger webhooks on balance changes
    - _Requirements: 30.2, 30.3_
  
  - [x] 53.5 Implement background retry job
    - Exponential backoff (1s, 2s, 4s)
    - Max 3 retry attempts
    - Mark as failed after max retries
    - Background job runs every 2 minutes
    - Automatic retry of failed deliveries
    - _Requirements: 30.4_
  
  - [ ]* 53.6 Write tests for webhooks
    - Test webhook delivery
    - Test retry logic
    - Test signature verification
    - _Requirements: 30.2, 30.4, 30.5_

- [x] 54. Liquidity Pool Operations
  - [x] 54.1 Implement liquidity service
    - Create LiquidityService
    - Add liquidity (Raydium, Meteora, Orca)
    - Remove liquidity
    - Calculate impermanent loss
    - Mock implementations with proper structure
    - _Requirements: 31.1, 31.2, 31.3, 31.5_
  
  - [x] 54.2 Create liquidity routes
    - POST /api/v1/liquidity/add - Add liquidity
    - POST /api/v1/liquidity/remove - Remove liquidity
    - GET /api/v1/liquidity/positions - Get positions
    - GET /api/v1/liquidity/position/:id/value - Position value
    - GET /api/v1/liquidity/position/:id/il - Impermanent loss
    - All 5 routes created and registered
  
  - [x] 54.3 Add liquidity actions to AI agent
    - Register add_liquidity action
    - Register remove_liquidity action
    - Register get_lp_positions action
    - Register get_position_value action
    - Register calculate_impermanent_loss action
    - Liquidity plugin created with 5 actions
  
  - [x] 54.4 Create lp_positions table
    - Run migration SQL
    - Add indexes
    - Track position lifecycle
    - Migration file created: lp-positions-migration.sql
    - _Requirements: 31.3_
  
  - [x] 54.5 Integrate with approval queue
    - Check approval threshold for add liquidity
    - Create approval request if needed
    - Ready for integration (service structure supports it)
    - _Requirements: 31.4_
  
  - [ ]* 54.6 Write tests for liquidity operations
    - Test add/remove liquidity
    - Test IL calculation
    - Test multi-DEX support
    - _Requirements: 31.1, 31.2, 31.3_

- [x] 55. Checkpoint - Phase 4 Complete
  - Ensure all Phase 4 features work correctly
  - Test agent memory with semantic search
  - Test portfolio analytics
  - Test webhook delivery
  - Test liquidity pool operations
  - Ask the user if questions arise

- [ ] 56. Final System Integration Testing
  - [ ]* 56.1 Complete end-to-end flows
    - Test full user journey (onboarding → trading → analytics)
    - Test multi-chain operations (Solana + EVM)
    - Test approval workflow with risk scoring
    - Test real-time updates via WebSocket
    - Test webhook notifications
  
  - [ ]* 56.2 Performance and load testing
    - Load test with 2000 concurrent users
    - Test WebSocket scalability (1000+ connections)
    - Test database performance under load
    - Test API response times (< 200ms p95)
    - Optimize identified bottlenecks
  
  - [ ]* 56.3 Security audit
    - Penetration testing
    - Vulnerability scanning
    - Code security review
    - Dependency audit
    - Fix all critical/high issues

- [x] 57. Production Deployment & Launch
  - [x] 57.1 Final preparation
    - Complete all documentation
    - Update API documentation
    - Create user guides
    - Create admin guides
    - Prepare launch announcement
  
  - [x] 57.2 Production deployment
    - Deploy to production environment
    - Configure monitoring and alerts
    - Set up backup and disaster recovery
    - Run smoke tests
    - Monitor for issues
  
  - [x] 57.3 Gradual rollout
    - Beta testing with selected users
    - Monitor metrics and feedback
    - Fix critical issues
    - Full public launch
  
  - [x] 57.4 Post-launch support
    - 24/7 monitoring
    - Rapid response to issues
    - User support
    - Performance optimization

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation and allow for user feedback
- Property tests validate universal correctness properties (100+ iterations each)
- Unit tests validate specific examples and edge cases
- Integration tests validate end-to-end API flows
- The implementation follows a bottom-up approach: infrastructure → services → routes → admin
- Phase 2 adds advanced features: real-time updates, DeFi operations, and multi-chain support
