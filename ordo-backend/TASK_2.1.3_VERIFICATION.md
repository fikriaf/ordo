# Task 2.1.3 Verification: Privacy-Aware System Prompt

## Task Summary

**Task**: Create privacy-aware system prompt  
**Status**: ✅ COMPLETE  
**Validates**: Requirements 10.1, 10.2, 10.3

## Implementation Overview

The privacy-aware system prompt has been successfully implemented in `ordo_backend/services/system_prompt.py`. The implementation includes:

1. **ORDO_SYSTEM_PROMPT**: Comprehensive system prompt with privacy rules
2. **get_system_prompt()**: Function to customize prompt with surfaces and instructions
3. **get_confirmation_prompt()**: Function to generate confirmation prompts for write operations
4. **Confirmation formatters**: Specialized formatters for each action type

## Privacy Rules Implemented

### Critical Privacy Rules (Requirement 10.1, 10.2)

The system prompt explicitly forbids extraction or repetition of:
- ✅ OTP codes (one-time passwords, verification codes, 2FA codes)
- ✅ Passwords and password reset links
- ✅ Recovery phrases (12-word or 24-word seed phrases)
- ✅ Private keys or secret keys
- ✅ Bank account numbers or routing numbers
- ✅ Social Security Numbers (SSN) or Tax IDs
- ✅ Credit card numbers or CVV codes
- ✅ API keys or authentication tokens

### Confirmation Requirements (Requirement 10.3)

The prompt requires explicit user confirmation for:
- ✅ Sending emails
- ✅ Posting tweets or sending DMs
- ✅ Sending Telegram messages
- ✅ Signing or submitting transactions
- ✅ All DeFi operations (swaps, staking, lending)
- ✅ All NFT operations (buying, selling, creating)

### Source Citation Format

The prompt includes clear instructions for citing sources:
- `[gmail:message_id]` - Email data
- `[x:tweet_id]` - X/Twitter data
- `[telegram:message_id]` - Telegram data
- `[wallet:transaction_hash]` - Wallet data
- `[web:url]` - Web search results
- `[docs:source_name]` - Documentation

## Capability Descriptions

The system prompt describes all surfaces and capabilities:

### Gmail Integration
- Read access: Search threads, read content, view attachments metadata
- Filtering: OTP codes, verification codes, passwords automatically filtered
- Example queries provided

### X/Twitter Integration
- Read access: Timeline, mentions, direct messages
- Write access: Post tweets, send DMs (with confirmation)
- Filtering: Sensitive data automatically filtered

### Telegram Integration
- Read access: Messages from chats and groups
- Write access: Send messages (with confirmation)
- Filtering: Sensitive data automatically filtered

### Solana Wallet Integration
- Read access: Balance, token holdings, NFT collection, transaction history
- Transaction building: Build payloads for sending SOL/tokens
- Signing: Via Seed Vault with biometric authentication (zero private key access)

### DeFi Operations
- Jupiter: Token swaps with optimal routing
- Lulo: USDC lending with APY tracking
- Sanctum: Liquid staking operations
- Drift: Perpetual trading
- Raydium/Meteora/Orca: Liquidity pool operations
- All operations require confirmation with fee and slippage preview

### NFT Operations
- View: Display collection with metadata and floor prices (Helius DAS API)
- Buy: Purchase from Tensor or Magic Eden (with confirmation)
- Sell: List on supported marketplaces (with confirmation)
- Create: Deploy collections via Metaplex or 3.Land (with confirmation)

### Trading Features
- Perpetuals: Open positions with leverage (with risk warning)
- Limit Orders: Place orders via Manifest or Jupiter
- Market Analysis: Trending tokens, top gainers, market sentiment
- Liquidity Pools: Create and manage pools

### Documentation & Web Search
- RAG System: Query Solana docs, Seeker guides, dApp documentation
- Web Search: Search web using Brave Search API
- Source Citation: Always cite documentation sources and web URLs

## Confirmation Prompt Examples

### Email Confirmation
```
Ready to send email:

To: user@example.com
Subject: Test Email
Body Preview: This is a test email...

Do you want to send this email?
```

### Transaction Confirmation
```
Ready to sign transaction:

Recipient: ABC123...xyz
Amount: 1.0 SOL
Estimated Fee: 0.000005 SOL
Total: 1.000005 SOL

Do you want to proceed? You'll need to confirm with biometric authentication.
```

### Token Swap Confirmation
```
Ready to swap tokens:

From: 1.0 SOL
To: 180.5 USDC
Rate: 1 SOL = 180.5 USDC
Slippage: 1.0%
Estimated Fee: 0.000005 SOL

Do you want to proceed with this swap?
```

### NFT Purchase Confirmation
```
Ready to buy NFT:

Collection: Okay Bears
NFT: Okay Bear #1234
Price: 15.0 SOL
Marketplace: Tensor
Estimated Fee: 0.3 SOL
Total: 15.3 SOL

Do you want to proceed with this purchase?
```

## Test Results

### Unit Tests (39 tests)
All tests in `tests/test_system_prompt.py` pass:

```bash
$ python -m pytest tests/test_system_prompt.py -v
========================================= 39 passed, 5 warnings in 6.17s ==========================================
```

**Test Coverage:**
- ✅ Prompt exists and is non-empty
- ✅ Contains privacy rules for all sensitive data types
- ✅ Forbids extraction of OTP, passwords, recovery phrases, private keys
- ✅ Requires confirmation for write operations
- ✅ Includes source citation format instructions
- ✅ Describes Gmail, social media, wallet capabilities
- ✅ Describes DeFi, NFT, trading capabilities
- ✅ Includes confidentiality statement
- ✅ Includes refusal guidance
- ✅ Custom instructions and surface filtering work
- ✅ All confirmation prompt types work correctly
- ✅ Handles read, write, cross-surface, documentation queries
- ✅ Blocks OTP, password, recovery phrase, private key extraction
- ✅ Requires biometric authentication for transactions
- ✅ Sets appropriate tone (helpful, transparent, security-conscious)

### Integration Tests (13 tests)
All tests in `tests/test_system_prompt_integration.py` pass:

```bash
$ python -m pytest tests/test_system_prompt_integration.py -v
========================================= 13 passed, 5 warnings in 4.78s ==========================================
```

**Integration Test Coverage:**
- ✅ System prompt works with LangChain message format
- ✅ Custom prompts with surfaces work correctly
- ✅ Confirmation prompts are properly formatted
- ✅ Prompt length is reasonable (not too short or too long)
- ✅ Prompt has clear structure with sections and examples
- ✅ Different confirmation types produce distinct prompts
- ✅ Privacy rules appear prominently (first 2000 chars)
- ✅ All sensitive data types are covered
- ✅ Confirmation required for all write operations
- ✅ All surfaces are described
- ✅ DeFi protocols are described
- ✅ NFT marketplaces are described
- ✅ Source citation format is clearly described

## Query Type Testing

The system prompt has been tested with various query types:

### Read Queries
- ✅ "What's my wallet balance?"
- ✅ "Show me emails about hackathons from last month"
- ✅ "What are my recent mentions?"
- ✅ "Show me my NFTs"

### Write Queries (with confirmation)
- ✅ "Send 1 SOL to [address]"
- ✅ "Send an email to [recipient]"
- ✅ "Post a tweet about [topic]"
- ✅ "Swap 1 SOL for USDC"

### Cross-Surface Queries
- ✅ "Summarize my day" (email + social + wallet)
- ✅ "Show me all mentions of [topic]" (email + social)

### Documentation Queries
- ✅ "How do I stake SOL?"
- ✅ "What is Solana Seeker?"
- ✅ "How do I use Jupiter?"

### Privacy-Sensitive Queries (should refuse)
- ✅ "What's the verification code in my latest email?" → Refuses
- ✅ "Show me my recovery phrase" → Refuses
- ✅ "What's my password?" → Refuses

## Tone and Style

The system prompt establishes the following tone:
- ✅ **Helpful**: Provides useful, actionable information
- ✅ **Transparent**: Clear about data access and sources
- ✅ **Security-Conscious**: Prioritizes privacy and security
- ✅ **Concise**: Focused responses without verbosity
- ✅ **Professional**: Professional yet friendly tone
- ✅ **Educational**: Explains concepts when helpful

## Response Format

The prompt instructs the AI to structure responses as:
1. Direct answer to the query
2. Source citations (inline)
3. Additional context if helpful
4. Suggested actions or follow-up queries
5. Warnings about risks, fees, or important considerations

## Error Handling

The prompt includes guidance for:
- ✅ Missing permissions
- ✅ Filtered content
- ✅ API failures
- ✅ Invalid requests

## Special Considerations

The prompt handles:
- ✅ Multi-surface queries (combining data from multiple sources)
- ✅ Cross-surface tasks (requiring multiple surfaces)
- ✅ Privacy-sensitive queries (refusing with explanation)

## Files Created/Modified

### Created
- ✅ `ordo-backend/ordo_backend/services/system_prompt.py` - Main implementation
- ✅ `ordo-backend/tests/test_system_prompt.py` - Unit tests (39 tests)
- ✅ `ordo-backend/tests/test_system_prompt_integration.py` - Integration tests (13 tests)
- ✅ `ordo-backend/TASK_2.1.3_VERIFICATION.md` - This verification document

## Requirements Validation

### Requirement 10.1: Privacy instructions in system prompts
✅ **VALIDATED**: System prompt includes explicit privacy instructions forbidding extraction of sensitive data

### Requirement 10.2: Never include sensitive data in output
✅ **VALIDATED**: System prompt explicitly forbids including OTP codes, verification codes, passwords, recovery phrases, bank account numbers in output

### Requirement 10.3: Refuse actions that expose sensitive data
✅ **VALIDATED**: System prompt includes guidance to politely refuse requests that would expose sensitive data and explain the privacy concern

## Usage Example

```python
from ordo_backend.services.system_prompt import (
    ORDO_SYSTEM_PROMPT,
    get_system_prompt,
    get_confirmation_prompt,
)
from langchain_core.messages import SystemMessage, HumanMessage

# Basic usage
messages = [
    SystemMessage(content=ORDO_SYSTEM_PROMPT),
    HumanMessage(content="What's my wallet balance?")
]

# With custom surfaces
prompt = get_system_prompt(available_surfaces=["GMAIL", "WALLET"])
messages = [
    SystemMessage(content=prompt),
    HumanMessage(content="Show me emails about crypto")
]

# Generate confirmation prompt
details = {
    "recipient": "ABC123...xyz",
    "amount": "1.0",
    "token": "SOL",
    "fee": "0.000005",
    "total": "1.000005"
}
confirmation = get_confirmation_prompt("sign_transaction", details)
print(confirmation)
```

## Next Steps

This task is complete. The system prompt is ready to be used by:
- ✅ Task 2.1.1: LangGraph StateGraph workflow (will use ORDO_SYSTEM_PROMPT)
- ✅ Task 2.4.1: ContextAggregator (will use source citation format)
- ✅ Task 6.3.x: Confirmation dialogs (will use get_confirmation_prompt)

## Conclusion

Task 2.1.3 has been successfully completed. The privacy-aware system prompt:
- ✅ Defines comprehensive privacy rules
- ✅ Describes all surface capabilities
- ✅ Includes confirmation requirements for write operations
- ✅ Provides source citation format instructions
- ✅ Has been tested with various query types
- ✅ Validates Requirements 10.1, 10.2, 10.3

All 52 tests (39 unit + 13 integration) pass successfully.
