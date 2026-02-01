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

- [ ] 2. Authentication Service
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

- [ ] 3. Encryption Utilities
  - [x] 3.1 Implement AES-256-GCM encryption/decryption utilities
    - Create encrypt function (returns ciphertext, IV, auth tag)
    - Create decrypt function (validates auth tag)
    - Use crypto module
    - _Requirements: 2.5, 13.4_
  
  - [ ]* 3.2 Write property test for encryption round trip
    - **Property 4: Wallet Creation Encryption**
    - **Validates: Requirements 2.1, 2.5, 13.4**

- [ ] 4. Wallet Service
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

- [ ] 5. Checkpoint - Core Authentication and Wallet
  - Ensure all tests pass
  - Verify user can register, login, create wallet, and query balance
  - Ask the user if questions arise

- [ ] 6. Plugin System Foundation
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

- [ ] 7. Solana Agent Kit Integration
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

- [ ] 8. Transaction Service
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

- [ ] 9. AI Agent Service with Function Calling
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

- [ ] 10. Conversation Management
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

- [ ] 11. Checkpoint - Core AI and Blockchain Integration
  - Ensure all tests pass
  - Verify end-to-end flow: user message → LLM function call → blockchain action → response
  - Test streaming responses
  - Ask the user if questions arise

- [ ] 12. API Routes - Authentication
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

- [ ] 13. API Routes - Chat
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

- [ ] 14. API Routes - Wallet
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

- [ ] 15. API Routes - Transactions
  - [x] 15.1 Create transaction routes
    - GET /api/v1/transactions (with pagination and filters)
    - GET /api/v1/transactions/:id
    - Implement authentication middleware
    - _Requirements: 6.1, 6.5_
  
  - [ ]* 15.2 Write integration tests for transaction endpoints
    - Test transaction history with filters
    - Test pagination
    - _Requirements: 6.1, 6.5_

- [ ] 16. API Routes - Actions
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

- [ ] 19. Checkpoint - Complete Public API
  - Ensure all public endpoints work end-to-end
  - Test authentication, chat, wallet, transactions
  - Verify rate limiting and error handling
  - Ask the user if questions arise

- [ ] 20. Admin Service
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

- [ ] 26. Price Feed and Caching
  - [ ] 26.1 Implement price feed service with caching
    - Fetch prices from Pyth Network
    - Cache prices for 30 seconds
    - Return stale data with indicator if unavailable
    - Batch multiple price requests
    - _Requirements: 17.1, 17.2, 17.3, 17.4_
  
  - [ ]* 26.2 Write property tests for price feeds
    - **Property 19: Price Feed Availability**
    - **Property 56: Price Data Caching**
    - **Property 57: Price Request Batching**
    - **Validates: Requirements 17.1, 17.2, 17.3, 17.4**

- [ ] 27. NFT and DeFi Validations
  - [ ] 27.1 Implement NFT ownership validation
    - Verify wallet owns NFT before transfer/listing
    - Return authorization error if not owner
    - _Requirements: 18.5_
  
  - [ ] 27.2 Implement DeFi collateral validation
    - Verify sufficient collateral for borrow operations
    - Check collateralization ratio
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

- [ ] 30. Final Testing and Quality Assurance
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
  
  - [ ] 30.4 Security audit
    - Verify all sensitive data is encrypted
    - Check for SQL injection vulnerabilities
    - Verify rate limiting and authentication
    - Test HTTPS enforcement

- [ ] 31. Final Checkpoint - Production Ready
  - All tests passing (unit, property, integration)
  - Documentation complete
  - Deployment configuration ready
  - Security audit passed
  - Ask the user if ready for deployment

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation and allow for user feedback
- Property tests validate universal correctness properties (100+ iterations each)
- Unit tests validate specific examples and edge cases
- Integration tests validate end-to-end API flows
- The implementation follows a bottom-up approach: infrastructure → services → routes → admin
