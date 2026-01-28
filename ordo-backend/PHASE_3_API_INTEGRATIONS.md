# Phase 3: API Integrations - Implementation Guide

## Overview

This document provides implementation details for Phase 3 API integrations. The infrastructure is complete, and this guide shows how to implement the actual API calls for each service.

## Completed Integrations

### ✅ Wallet MCP Server (Helius Integration)

**File**: `ordo-backend/ordo_backend/mcp_servers/wallet.py`

**Implemented Tools**:
1. ✅ `get_wallet_portfolio` - Helius DAS API (getAssetsByOwner)
   - Fetches all assets (tokens + NFTs) for a wallet
   - Parses fungible tokens with balance and value
   - Parses NFTs with metadata
   - Calculates total portfolio value in USD
   - Includes native SOL balance

2. ✅ `get_transaction_history` - Helius Enhanced Transactions API
   - Fetches transaction history for an address
   - Returns parsed transactions with type, fee, transfers
   - Includes human-readable descriptions

3. ✅ `get_priority_fee_estimate` - Helius Priority Fee API
   - Gets priority fee estimates at different levels
   - Returns min, low, medium, high, veryHigh, unsafeMax
   - Useful for transaction optimization

**API Endpoints Used**:
- `https://mainnet.helius-rpc.com/?api-key={key}` (DAS API, Priority Fee API)
- `https://api.helius.xyz/v0/addresses/{address}/transactions` (Enhanced Transactions)

**Authentication**: API key in URL parameter

### ✅ Email MCP Server (Gmail Integration)

**File**: `ordo-backend/ordo_backend/mcp_servers/email.py`

**Implemented Tools**:
1. ✅ `search_email_threads` - Gmail API (threads.list)
   - Searches Gmail threads using Gmail search syntax
   - Returns thread metadata (subject, participants, date, snippet)
   - Supports max_results parameter

2. ✅ `get_email_content` - Gmail API (messages.get)
   - Fetches specific email by ID
   - Extracts headers (From, To, Subject, Date)
   - Decodes email body (handles multipart messages)
   - Returns full email content

3. ✅ `send_email` - Gmail API (messages.send)
   - Sends email via Gmail
   - Creates MIME message
   - Base64 encodes for API
   - Returns message ID on success

**API Library**: `google-api-python-client`

**Authentication**: OAuth 2.0 token (passed as parameter)

**Required Scopes**:
- `https://www.googleapis.com/auth/gmail.readonly` (read)
- `https://www.googleapis.com/auth/gmail.send` (send)

## Pending Integrations

### 🔄 Social MCP Server

**File**: `ordo-backend/ordo_backend/mcp_servers/social.py`

**Tools to Implement**:

#### X/Twitter Integration (using Tweepy)
```python
import tweepy

# Initialize client
client = tweepy.Client(bearer_token=token)

# Get DMs
def get_x_dms(token, user_id, limit=20):
    client = tweepy.Client(bearer_token=token)
    # Use Twitter API v2 Direct Messages endpoint
    # Note: Requires elevated access
    pass

# Get mentions
def get_x_mentions(token, user_id, limit=20):
    client = tweepy.Client(bearer_token=token)
    user = client.get_me()
    mentions = client.get_users_mentions(
        id=user.data.id,
        max_results=limit
    )
    return mentions.data

# Send DM
def send_x_dm(recipient_id, text, token, user_id):
    client = tweepy.Client(bearer_token=token)
    # Use Twitter API v2 Direct Messages endpoint
    pass
```

**Authentication**: OAuth 2.0 Bearer Token

**Required Permissions**: 
- Read DMs
- Write DMs
- Read tweets

#### Telegram Integration (using python-telegram-bot)
```python
from telegram import Bot
from telegram.ext import Application

# Initialize bot
async def get_telegram_messages(bot_token, user_id, limit=20):
    bot = Bot(token=bot_token)
    # Get updates
    updates = await bot.get_updates(limit=limit)
    
    messages = []
    for update in updates:
        if update.message:
            messages.append({
                "id": str(update.message.message_id),
                "chatId": str(update.message.chat.id),
                "fromId": str(update.message.from_user.id),
                "fromUsername": update.message.from_user.username,
                "text": update.message.text,
                "timestamp": update.message.date.isoformat()
            })
    
    return messages

# Send message
async def send_telegram_message(chat_id, text, bot_token, user_id):
    bot = Bot(token=bot_token)
    message = await bot.send_message(
        chat_id=chat_id,
        text=text
    )
    return {
        "success": True,
        "messageId": str(message.message_id),
        "status": "sent"
    }
```

**Authentication**: Bot Token

### 🔄 DeFi MCP Server

**File**: `ordo-backend/ordo_backend/mcp_servers/defi.py`

**Tools to Implement**:

#### Birdeye API Integration
```python
import httpx

async def get_token_price_birdeye(token_address, birdeye_api_key, user_id):
    async with httpx.AsyncClient() as client:
        response = await client.get(
            f"https://public-api.birdeye.so/defi/price",
            params={"address": token_address},
            headers={"X-API-KEY": birdeye_api_key}
        )
        data = response.json()
        
        return {
            "address": token_address,
            "symbol": data.get("symbol", ""),
            "priceUsd": data.get("value", 0.0),
            "priceChange24h": data.get("priceChange24h", 0.0),
            "volume24h": data.get("volume24h", 0.0),
            "liquidity": data.get("liquidity", 0.0)
        }
```

#### Jupiter API Integration
```python
async def jupiter_swap_quote(input_mint, output_mint, amount, user_id, slippage_bps=50):
    async with httpx.AsyncClient() as client:
        response = await client.get(
            "https://quote-api.jup.ag/v6/quote",
            params={
                "inputMint": input_mint,
                "outputMint": output_mint,
                "amount": amount,
                "slippageBps": slippage_bps
            }
        )
        return response.json()

async def jupiter_execute_swap(quote, user_address, user_id):
    async with httpx.AsyncClient() as client:
        response = await client.post(
            "https://quote-api.jup.ag/v6/swap",
            json={
                "quoteResponse": quote,
                "userPublicKey": user_address,
                "wrapAndUnwrapSol": True
            }
        )
        swap_transaction = response.json()
        return {
            "transaction": swap_transaction.get("swapTransaction"),
            "type": "JUPITER_SWAP",
            "inputMint": quote["inputMint"],
            "outputMint": quote["outputMint"],
            "inAmount": quote["inAmount"],
            "outAmount": quote["outAmount"]
        }
```

**APIs**:
- Birdeye: `https://public-api.birdeye.so`
- Jupiter: `https://quote-api.jup.ag/v6`
- Lulo: Custom integration (check Lulo docs)
- Sanctum: Custom integration (check Sanctum docs)
- Drift: Custom integration (check Drift docs)

### 🔄 NFT MCP Server

**File**: `ordo-backend/ordo_backend/mcp_servers/nft.py`

**Tools to Implement**:

#### Helius DAS API for NFTs
```python
async def get_nft_collection(collection_address, helius_api_key, user_id):
    async with httpx.AsyncClient() as client:
        # Get collection info using Helius DAS
        response = await client.post(
            f"https://mainnet.helius-rpc.com/?api-key={helius_api_key}",
            json={
                "jsonrpc": "2.0",
                "id": "ordo-nft-collection",
                "method": "getAssetsByGroup",
                "params": {
                    "groupKey": "collection",
                    "groupValue": collection_address,
                    "page": 1,
                    "limit": 1000
                }
            }
        )
        data = response.json()
        
        # Parse collection data
        items = data.get("result", {}).get("items", [])
        
        return {
            "address": collection_address,
            "name": items[0].get("content", {}).get("metadata", {}).get("name", "") if items else "",
            "totalSupply": len(items),
            # Additional fields would come from marketplace APIs
        }
```

#### Tensor API Integration
```python
async def tensor_get_floor_price(collection_address, user_id):
    # Tensor API integration
    # Check Tensor documentation for API endpoints
    pass
```

### 🔄 Trading MCP Server

**File**: `ordo-backend/ordo_backend/mcp_servers/trading.py`

**Tools to Implement**:

#### Market Analysis
```python
async def get_market_analysis(token_address, user_id):
    # Aggregate data from multiple sources
    # - Birdeye for price and volume
    # - Jupiter for liquidity
    # - Social sentiment APIs
    # - Technical indicators calculation
    pass
```

#### Messari API Integration
```python
async def messari_get_insights(token_symbol, user_id):
    async with httpx.AsyncClient() as client:
        response = await client.get(
            f"https://data.messari.io/api/v1/assets/{token_symbol}/metrics",
            headers={"x-messari-api-key": messari_api_key}
        )
        data = response.json()
        
        # Parse Messari data
        return {
            "symbol": token_symbol,
            "analysis": data.get("data", {}).get("market_data", {}),
            # Additional parsing
        }
```

## Installation Instructions

### 1. Install Python Dependencies

```bash
cd ordo-backend
pip install -r requirements.txt
```

### 2. Configure Environment Variables

Create or update `.env` file:

```bash
# Helius (Solana RPC)
HELIUS_API_KEY=your_helius_api_key

# Gmail API (OAuth 2.0)
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret

# X/Twitter API
X_API_KEY=your_x_api_key
X_API_SECRET=your_x_api_secret
X_BEARER_TOKEN=your_x_bearer_token

# Telegram Bot
TELEGRAM_BOT_TOKEN=your_telegram_bot_token

# Birdeye API
BIRDEYE_API_KEY=your_birdeye_api_key

# Messari API
MESSARI_API_KEY=your_messari_api_key

# Brave Search API
BRAVE_SEARCH_API_KEY=your_brave_search_api_key

# Mistral AI
MISTRAL_API_KEY=your_mistral_api_key

# OpenRouter (fallback)
OPENROUTER_API_KEY=your_openrouter_api_key

# LangSmith (observability)
LANGSMITH_API_KEY=your_langsmith_api_key
LANGSMITH_PROJECT=ordo
LANGSMITH_TRACING=true

# Supabase (RAG)
SUPABASE_URL=your_supabase_url
SUPABASE_KEY=your_supabase_key

# Database
DATABASE_URL=postgresql://user:password@localhost:5432/ordo_db

# Redis
REDIS_URL=redis://localhost:6379
```

### 3. Set Up OAuth 2.0 for Gmail

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing
3. Enable Gmail API
4. Create OAuth 2.0 credentials
5. Add authorized redirect URIs
6. Download credentials JSON
7. Implement OAuth flow in frontend

### 4. Set Up X/Twitter API

1. Go to [Twitter Developer Portal](https://developer.twitter.com/)
2. Create a new app
3. Get API keys and tokens
4. Request elevated access for DM endpoints
5. Configure OAuth 2.0

### 5. Set Up Telegram Bot

1. Talk to [@BotFather](https://t.me/botfather) on Telegram
2. Create a new bot with `/newbot`
3. Get bot token
4. Configure bot permissions

## Testing API Integrations

### Test Wallet Integration

```python
import asyncio
from ordo_backend.mcp_servers.wallet import get_wallet_portfolio

async def test_wallet():
    result = await get_wallet_portfolio(
        address="YOUR_WALLET_ADDRESS",
        helius_api_key="YOUR_HELIUS_KEY",
        user_id="test_user"
    )
    print(result)

asyncio.run(test_wallet())
```

### Test Email Integration

```python
from ordo_backend.mcp_servers.email import search_email_threads

async def test_email():
    result = await search_email_threads(
        query="in:inbox",
        token="YOUR_OAUTH_TOKEN",
        user_id="test_user",
        max_results=5
    )
    print(result)

asyncio.run(test_email())
```

## Error Handling

All API integrations include comprehensive error handling:

1. **HTTP Errors**: Caught and returned as error objects
2. **Missing Dependencies**: Graceful degradation with error messages
3. **Invalid Tokens**: Clear error messages for authentication failures
4. **Rate Limiting**: Handled with appropriate error responses
5. **Timeouts**: 30-second timeout for all HTTP requests

## Security Considerations

1. **OAuth Tokens**: Never log or store tokens in plain text
2. **API Keys**: Store in environment variables, never in code
3. **Rate Limiting**: Implement rate limiting for all endpoints
4. **Input Validation**: Validate all user inputs before API calls
5. **Error Messages**: Don't expose sensitive information in errors

## Next Steps

1. ✅ Complete Wallet integration (Helius) - DONE
2. ✅ Complete Email integration (Gmail) - DONE
3. 🔄 Complete Social integration (X, Telegram)
4. 🔄 Complete DeFi integration (Jupiter, Lulo, Sanctum, Drift)
5. 🔄 Complete NFT integration (Tensor, Metaplex)
6. 🔄 Complete Trading integration (Messari, onramp)
7. 🔄 Implement Agent EOA Wallet (Solana Agent Kit)
8. 🔄 Add comprehensive error handling and retry logic
9. 🔄 Implement rate limiting per API
10. 🔄 Add integration tests for all APIs

## Resources

- [Helius Documentation](https://docs.helius.dev/)
- [Gmail API Documentation](https://developers.google.com/gmail/api)
- [Twitter API Documentation](https://developer.twitter.com/en/docs)
- [Telegram Bot API Documentation](https://core.telegram.org/bots/api)
- [Jupiter API Documentation](https://station.jup.ag/docs/apis/swap-api)
- [Birdeye API Documentation](https://docs.birdeye.so/)
- [Solana Agent Kit](https://github.com/sendaifun/solana-agent-kit)

## Status

**Phase 3 Progress**: 2/7 integrations complete (Wallet, Email)

- ✅ Wallet MCP Server (Helius) - COMPLETE
- ✅ Email MCP Server (Gmail) - COMPLETE
- 🔄 Social MCP Server (X, Telegram) - Infrastructure ready
- 🔄 DeFi MCP Server (Jupiter, Lulo, etc.) - Infrastructure ready
- 🔄 NFT MCP Server (Tensor, Metaplex) - Infrastructure ready
- 🔄 Trading MCP Server (Messari, onramp) - Infrastructure ready
- 🔄 Agent EOA Wallet - Infrastructure ready

All infrastructure is in place. Remaining integrations follow the same patterns as Wallet and Email implementations.
