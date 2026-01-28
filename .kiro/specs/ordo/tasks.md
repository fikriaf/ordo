# Ordo Implementation Tasks

## Phase 1: Multi-Agent System Foundation ✓ (Completed)

### 1.1 Core Infrastructure Setup ✓
- [x] 1.1.1 Set up React Native project with Expo
- [x] 1.1.2 Set up FastAPI backend with basic structure
- [x] 1.1.3 Configure PostgreSQL + pgvector database
- [x] 1.1.4 Set up Docker Compose for local development
- [x] 1.1.5 Configure environment variables and secrets management

### 1.2 Permission System Implementation ✓
- [x] 1.2.1 Implement PermissionManager frontend service
- [x] 1.2.2 Add secure storage for permission states and OAuth tokens
- [x] 1.2.3 Write unit tests for PermissionManager
- [x] 1.2.4 Write property-based tests for permission state management

### 1.3 Wallet Integration ✓
- [x] 1.3.1 Implement SeedVaultAdapter with MWA integration
- [x] 1.3.2 Add transaction signing via Seed Vault
- [x] 1.3.3 Write unit tests for SeedVaultAdapter
- [x] 1.3.4 Write property-based tests for wallet operations

## Phase 2: Multi-Agent Orchestration System

### 2.1 LangGraph Agent Architecture
- [ ] 2.1.1 Set up LangGraph StateGraph workflow
- [x] 2.1.2 Implement Mistral AI integration with OpenRouter fallback
- [ ] 2.1.3 Create privacy-aware system prompt

### 2.2 Model Context Protocol (MCP) Integration
- [ ] 2.2.1 Set up MCP server infrastructure
- [ ] 2.2.2 Implement MCP interceptors
- [ ] 2.2.3 Initialize MultiServerMCPClient

### 2.3 Policy Engine Enhancement
- [ ] 2.3.1 Expand sensitive data patterns
- [ ] 2.3.2 Implement content filtering methods
- [ ] 2.3.3 Add audit logging for policy violations

### 2.4 Context Aggregation System
- [ ] 2.4.1 Implement ContextAggregator frontend service
- [ ] 2.4.2 Add source attribution tracking
- [ ] 2.4.3 Implement cross-surface data merging

## Phase 3: Tool Implementation (MCP Servers)

### 3.1 Email MCP Server
- [ ] 3.1.1 Create email MCP server with FastMCP
- [ ] 3.1.2 Implement Gmail API integration
- [ ] 3.1.3 Add policy filtering to email tools
- [ ] 3.1.4 Create email MCP resources

### 3.2 Wallet MCP Server
- [ ] 3.2.1 Create wallet MCP server with FastMCP
- [ ] 3.2.2 Implement Helius RPC integration
- [ ] 3.2.3 Add transaction building tools
- [ ] 3.2.4 Create wallet MCP resources

### 3.3 Social Media MCP Server
- [ ] 3.3.1 Create social MCP server with FastMCP
- [ ] 3.3.2 Implement X/Twitter API integration
- [ ] 3.3.3 Implement Telegram Bot API integration
- [ ] 3.3.4 Add policy filtering to social tools

### 3.4 DeFi MCP Server (Solana Agent Kit Integration)
- [ ] 3.4.1 Create DeFi MCP server with FastMCP
- [ ] 3.4.2 Implement Jupiter swap integration
- [ ] 3.4.3 Implement Lulo lending integration
- [ ] 3.4.4 Implement additional DeFi tools
- [ ] 3.4.5 Add Jito Bundles support

### 3.5 NFT MCP Server (Solana Agent Kit Integration)
- [ ] 3.5.1 Create NFT MCP server with FastMCP
- [ ] 3.5.2 Implement Tensor marketplace integration
- [ ] 3.5.3 Implement Metaplex integration

### 3.6 Trading MCP Server (Plugin God Mode Integration)
- [ ] 3.6.1 Create trading MCP server with FastMCP
- [ ] 3.6.2 Implement advanced trading features
- [ ] 3.6.3 Add Messari AI integration
- [ ] 3.6.4 Add risk warnings for leveraged positions
- [ ] 3.6.5 Add onramp integration

### 3.7 Agent EOA Wallet Integration (Solana Agent Kit)
- [ ] 3.7.1 Create agent wallet with KeypairWallet
- [ ] 3.7.2 Implement wallet funding mechanism
- [ ] 3.7.3 Integrate SolanaAgentKit with all plugins
- [ ] 3.7.4 Create LangChain tools from SolanaAgentKit
- [ ] 3.7.5 Implement spending limit enforcement
- [ ] 3.7.6 Add service whitelist management
- [ ] 3.7.7 Implement autonomous payment execution
- [ ] 3.7.8 Add payment history and dashboard
- [ ] 3.7.9 Add agent wallet security measures

## Phase 4: RAG System and Web Search

### 4.1 RAG System Implementation
- [ ] 4.1.1 Set up Supabase pgvector integration
- [ ] 4.1.2 Implement Mistral embeddings
- [ ] 4.1.3 Add documentation corpus
- [ ] 4.1.4 Implement semantic search
- [ ] 4.1.5 Add documentation update pipeline

### 4.2 Web Search Integration
- [ ] 4.2.1 Implement Brave Search API integration
- [ ] 4.2.2 Add web content fetching
- [ ] 4.2.3 Implement RAG fallback to web search
- [ ] 4.2.4 Add source citation for web results

## Phase 5: Digital Assistant Capabilities

### 5.1 Mobile Permissions and Setup
- [ ] 5.1.1 Configure Android permissions
- [ ] 5.1.2 Configure Seeker permissions

### 5.2 Voice Assistant Integration
- [ ] 5.2.1 Implement speech-to-text (STT)
- [ ] 5.2.2 Implement text-to-speech (TTS)
- [ ] 5.2.3 Add voice command flow

### 5.3 Push Notifications
- [ ] 5.3.1 Set up notification system
- [ ] 5.3.2 Implement notification types
- [ ] 5.3.3 Add notification scheduling

### 5.4 Home Screen Widget
- [ ] 5.4.1 Create Android widget
- [ ] 5.4.2 Create Seeker widget

### 5.5 Device Assistant Integration
- [ ] 5.5.1 Implement Siri Shortcuts (Seeker)
- [ ] 5.5.2 Implement Google Assistant Actions (Android)

### 5.6 Background Services
- [ ] 5.6.1 Implement background fetch
- [ ] 5.6.2 Add background task management

### 5.7 Share Extension and Deep Linking
- [ ] 5.7.1 Implement share functionality
- [ ] 5.7.2 Handle incoming shares
- [ ] 5.7.3 Add deep linking support

### 5.8 Biometric Authentication
- [ ] 5.8.1 Implement biometric auth service
- [ ] 5.8.2 Add biometric protection for sensitive actions

### 5.9 Offline Mode
- [ ] 5.9.1 Implement offline cache manager
- [ ] 5.9.2 Add offline data access

### 5.10 Accessibility Features
- [ ] 5.10.1 Implement accessibility support
- [ ] 5.10.2 Add high contrast and large text modes

## Phase 6: User Interface and Experience

### 6.1 Chat Interface
- [ ] 6.1.1 Create chat UI components
- [ ] 6.1.2 Implement conversation management
- [ ] 6.1.3 Add source citations display
- [ ] 6.1.4 Add suggested actions

### 6.2 Permission Management UI
- [ ] 6.2.1 Create permission settings screen
- [ ] 6.2.2 Implement OAuth flows
- [ ] 6.2.3 Add permission request dialogs

### 6.3 Confirmation Dialogs
- [ ] 6.3.1 Create transaction confirmation dialog
- [ ] 6.3.2 Create email send confirmation dialog
- [ ] 6.3.3 Create DeFi operation confirmation dialog

### 6.4 Portfolio Display
- [ ] 6.4.1 Create portfolio overview screen
- [ ] 6.4.2 Add NFT collection view
- [ ] 6.4.3 Add transaction history view

### 6.5 Agent Wallet Dashboard
- [ ] 6.5.1 Create agent wallet overview
- [ ] 6.5.2 Create payment history view
- [ ] 6.5.3 Add spending limit configuration
- [ ] 6.5.4 Add approved services management

### 6.6 Settings and Preferences
- [ ] 6.6.1 Create settings screen
- [ ] 6.6.2 Add audit log viewer

## Phase 7: Testing and Quality Assurance

### 7.1 Unit Testing
- [ ] 7.1.1 Write frontend unit tests
- [ ] 7.1.2 Write backend unit tests

### 7.2 Property-Based Testing
- [ ] 7.2.1 Write permission system PBT
- [ ] 7.2.2 Write policy engine PBT
- [ ] 7.2.3 Write wallet integration PBT
- [ ] 7.2.4 Write orchestration PBT
- [ ] 7.2.5 Write agent wallet PBT

### 7.3 Integration Testing
- [ ] 7.3.1 Test end-to-end query flow
- [ ] 7.3.2 Test OAuth token refresh flow
- [ ] 7.3.3 Test MWA transaction signing flow
- [ ] 7.3.4 Test agent wallet operations

### 7.4 Security Testing
- [ ] 7.4.1 Test sensitive data filtering
- [ ] 7.4.2 Test permission enforcement
- [ ] 7.4.3 Test private key isolation
- [ ] 7.4.4 Test confirmation requirements
- [ ] 7.4.5 Test audit logging

### 7.5 Performance Testing
- [ ] 7.5.1 Test query response times
- [ ] 7.5.2 Test concurrent user load
- [ ] 7.5.3 Test database performance

### 7.6 User Acceptance Testing
- [ ] 7.6.1 Test on Solana Seeker device
- [ ] 7.6.2 Test on Android devices
- [ ] 7.6.3 Test on Seeker devices

## Phase 8: Deployment and Launch

### 8.1 Backend Deployment
- [ ] 8.1.1 Set up production infrastructure
- [ ] 8.1.2 Configure monitoring and alerting
- [ ] 8.1.3 Set up MCP servers
- [ ] 8.1.4 Configure rate limiting and security

### 8.2 Frontend Deployment
- [ ] 8.2.1 Build production app with EAS
- [ ] 8.2.2 Submit to Solana dApp Store
- [ ] 8.2.3 Submit to Google Play Store (optional)
- [ ] 8.2.4 Submit to Apple App Store (optional)

### 8.3 Documentation
- [ ] 8.3.1 Write user documentation
- [ ] 8.3.2 Write developer documentation
- [ ] 8.3.3 Create video tutorials

### 8.4 Launch Preparation
- [ ] 8.4.1 Conduct final testing
- [ ] 8.4.2 Prepare launch materials
- [ ] 8.4.3 Set up support channels

### 8.5 Post-Launch
- [ ] 8.5.1 Monitor production metrics
- [ ] 8.5.2 Gather user feedback
- [ ] 8.5.3 Plan future iterations

## Task Details

### Phase 2 Task Details

#### 2.1.1 Set up LangGraph StateGraph workflow
- Create agent state TypedDict with all required fields
- Define workflow nodes: parse_query, check_permissions, select_tools, execute_tools, filter_results, aggregate_results, generate_response
- Add conditional edges for permission checking and error handling
- Compile and test basic workflow execution
- **Validates: Requirements 7.1, 7.2, 7.3**

#### 2.1.2 Implement Mistral AI integration with OpenRouter fallback
- Initialize ChatMistralAI with mistral-large-latest model
- Configure temperature, max_tokens, and safety settings
- Add function calling support for tool selection
- Implement OpenRouter fallback using deepseek/deepseek-r1-0528:free
- Configure proper headers (HTTP-Referer, X-Title) for OpenRouter
- Test LLM invocation with system prompts
- Test fallback mechanism when Mistral fails
- **Validates: Requirements 7.1**

#### 2.1.3 Create privacy-aware system prompt
- Define ORDO_SYSTEM_PROMPT with privacy rules
- Add capability descriptions for all surfaces
- Include confirmation requirements for write operations
- Add source citation format instructions
- Test prompt with various query types
- **Validates: Requirements 10.1, 10.2, 10.3**

#### 2.2.1 Set up MCP server infrastructure
- Create MCP server directory structure (email, social, wallet, defi, nft, trading)
- Configure Kiro MCP settings in .kiro/settings/mcp.json
- Set up FastMCP for each domain server
- Test MCP server connectivity via Kiro's MCP panel
- **Validates: Requirements 20.1, 20.6**

#### 2.2.2 Implement MCP interceptors
- Create inject_ordo_context interceptor for permission checking
- Create audit_tool_calls interceptor for logging
- Add runtime context injection (user_id, permissions, tokens)
- Test interceptor execution with sample tool calls
- **Validates: Requirements 20.3, 20.4**

#### 2.2.3 Initialize MultiServerMCPClient
- Configure all MCP server URLs and transports
- Add tool interceptors to client
- Implement callbacks for progress and logging
- Load tools from all MCP servers
- Test tool discovery and execution
- **Validates: Requirements 20.2, 20.5**

#### 2.3.1 Expand sensitive data patterns
- Add comprehensive OTP code patterns (4-8 digits)
- Add verification code patterns with context
- Add recovery phrase patterns (12/24 word sequences)
- Add password reset email patterns
- Add bank statement and tax document keywords
- Test pattern matching with sample data
- **Validates: Requirements 2.4**

#### 2.3.2 Implement content filtering methods
- Implement filter_emails with subject and body scanning
- Implement filter_messages for social media content
- Add filter_content dispatcher for different content types
- Return filtered count and blocked patterns
- **Validates: Requirements 2.2, 2.3, 6.3**

#### 2.3.3 Add audit logging for policy violations
- Create audit_logger module with PostgreSQL backend
- Log all blocked content access attempts
- Include timestamp, user_id, surface, pattern, content_preview
- Implement log retention policy (90 days)
- **Validates: Requirements 2.6, 11.2**

#### 2.4.1 Implement ContextAggregator frontend service
- Create aggregateResults method for multi-surface data
- Implement formatForLLM for context preparation
- Add extractSources for citation tracking
- Handle conflicting or duplicate information
- **Validates: Requirements 7.3, 9.2**

#### 2.4.2 Add source attribution tracking
- Create Source interface with surface, identifier, timestamp, preview
- Track sources for each piece of data
- Format sources for display in UI
- Test source extraction from various content types
- **Validates: Requirements 7.5, 9.4, 10.6**

#### 2.4.3 Implement cross-surface data merging
- Combine results from multiple tools
- Maintain source attribution during merge
- Handle partial failures gracefully
- Test with email + wallet, social + email combinations
- **Validates: Requirements 9.1, 9.2, 9.6**

## Summary

This task list provides a comprehensive roadmap for building Ordo. The implementation follows a phased approach with ~150 tasks across 8 phases. Each task validates specific requirements from the requirements document.

**Note**: Task details for phases 3-8 are documented in the original design document. Refer to `.kiro/specs/ordo/design.md` and `.kiro/specs/ordo/requirements.md` for complete implementation guidance.
