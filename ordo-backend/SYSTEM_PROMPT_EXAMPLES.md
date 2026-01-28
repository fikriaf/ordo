# System Prompt Examples and Usage

This document provides examples of how the privacy-aware system prompt works in practice.

## Basic Usage

```python
from ordo_backend.services.system_prompt import (
    ORDO_SYSTEM_PROMPT,
    get_system_prompt,
    get_confirmation_prompt,
)
from langchain_core.messages import SystemMessage, HumanMessage

# Use the default system prompt
messages = [
    SystemMessage(content=ORDO_SYSTEM_PROMPT),
    HumanMessage(content="What's my wallet balance?")
]
```

## Example Interactions

### Example 1: Safe Query (Wallet Balance)

**User Query**: "What's my wallet balance?"

**Expected Response**:
```
Your wallet currently holds 45.3 SOL ($8,154.00 USD) and 1,250 USDC. [wallet:balance]

You also have 3 NFTs in your collection:
- Okay Bear #1234 (Floor: 15 SOL) [wallet:nft_collection]
- SMB #5678 (Floor: 85 SOL)
- Mad Lads #9012 (Floor: 120 SOL)

Would you like to see your recent transactions or check token prices?
```

**Privacy Compliance**: ✅ No sensitive data exposed, sources cited

---

### Example 2: Refused Query (OTP Code)

**User Query**: "What's the verification code in my latest email?"

**Expected Response**:
```
I can't access verification codes or OTP codes from your emails - this is a security 
feature to protect your accounts. Please check your email app directly for verification codes.
```

**Privacy Compliance**: ✅ Politely refuses, explains why

---

### Example 3: Write Operation (Send Transaction)

**User Query**: "Send 1 SOL to ABC123...xyz"

**Expected Response**:
```
I've prepared a transaction to send 1 SOL to ABC123...xyz. 

Transaction Details:
- Recipient: ABC123...xyz
- Amount: 1 SOL (~$180.00 USD)
- Estimated Fee: 0.000005 SOL
- Total: 1.000005 SOL

Do you want to proceed with this transaction? If yes, you'll need to confirm with 
biometric authentication.
```

**Privacy Compliance**: ✅ Requires explicit confirmation, shows all details

---

### Example 4: Multi-Surface Query

**User Query**: "Summarize my day"

**Expected Response**:
```
Here's your summary for today:

**Emails** (3 new): Meeting invite from Sarah, newsletter from Solana Foundation, 
project update from team [gmail:thread_abc123, gmail:thread_def456, gmail:thread_ghi789]

**X/Twitter** (5 mentions): Mostly about your recent tweet on Solana DeFi 
[x:mention_123, x:mention_456]

**Wallet Activity**: Received 10 USDC from ABC...xyz, swapped 0.5 SOL for BONK 
[wallet:tx_abc123, wallet:tx_def456]

Would you like details on any of these?
```

**Privacy Compliance**: ✅ Sources cited for each surface, no sensitive data

---

### Example 5: DeFi Operation (Token Swap)

**User Query**: "Swap 1 SOL for USDC"

**Expected Response**:
```
I can help you swap 1 SOL for USDC using Jupiter Exchange.

Current Rate: 1 SOL = ~180.5 USDC
You'll receive: ~180.5 USDC (after 1% slippage)
Estimated Fee: 0.000005 SOL

Do you want to proceed with this swap? I'll need your confirmation to build the transaction.
```

**Confirmation Prompt** (after user says yes):
```
Ready to swap tokens:

From: 1.0 SOL
To: 180.5 USDC
Rate: 1 SOL = 180.5 USDC
Slippage: 1.0%
Estimated Fee: 0.000005 SOL

Do you want to proceed with this swap?
```

**Privacy Compliance**: ✅ Two-step confirmation, all details shown

---

### Example 6: Refused Query (Recovery Phrase)

**User Query**: "Show me my recovery phrase"

**Expected Response**:
```
I cannot access or display recovery phrases - this is a critical security feature. 
Recovery phrases should never be shared with any application or service, including AI assistants.

Your recovery phrase is stored securely in Seed Vault and is never accessible to Ordo. 
If you need to view your recovery phrase, please use your wallet app's secure backup feature.
```

**Privacy Compliance**: ✅ Refuses, explains security concern, suggests alternative

---

### Example 7: Email Search (with filtering)

**User Query**: "Show me emails from john@example.com"

**Expected Response**:
```
I found 5 emails from john@example.com:

1. "Project Update" - Yesterday at 2:30 PM [gmail:msg_123]
   Preview: "Here's the latest on the Solana integration..."

2. "Meeting Notes" - 2 days ago [gmail:msg_456]
   Preview: "Thanks for joining the call. Key takeaways..."

3. "Question about DeFi" - 3 days ago [gmail:msg_789]
   Preview: "I have a question about Jupiter swaps..."

Note: Some emails were filtered out to protect sensitive information (OTP codes, passwords, etc.)

Would you like to read any of these emails in full?
```

**Privacy Compliance**: ✅ Filtered sensitive emails, informed user, sources cited

---

### Example 8: NFT Purchase

**User Query**: "Buy Okay Bear #1234"

**Expected Response**:
```
I found Okay Bear #1234 listed on Tensor for 15 SOL.

NFT Details:
- Collection: Okay Bears
- Token: Okay Bear #1234
- Current Price: 15 SOL (~$2,700 USD)
- Floor Price: 14.8 SOL
- Marketplace: Tensor
- Marketplace Fee: 2%

Total Cost: 15.3 SOL (including fees)

Do you want to proceed with this purchase? I'll need your confirmation to build the transaction.
```

**Confirmation Prompt** (after user says yes):
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

**Privacy Compliance**: ✅ Two-step confirmation, all costs shown

---

### Example 9: Documentation Query

**User Query**: "How do I stake SOL?"

**Expected Response**:
```
To stake SOL on Solana, you have several options:

**Native Staking** [docs:solana_staking]:
- Delegate SOL to a validator
- Earn ~7% APY
- Requires 0.00228288 SOL minimum
- Unstaking takes 2-3 days

**Liquid Staking** [docs:sanctum]:
- Stake via Sanctum or Jupiter
- Receive liquid staking tokens (LSTs)
- Can use LSTs in DeFi while earning staking rewards
- Instant unstaking available

Would you like me to help you stake SOL using one of these methods?
```

**Privacy Compliance**: ✅ Sources cited, educational, no user data exposed

---

### Example 10: Cross-Surface Task (Email + Wallet)

**User Query**: "Did I receive any payments mentioned in my emails?"

**Expected Response**:
```
I found 2 payment-related emails and checked your wallet:

**Email from Sarah** (Yesterday) [gmail:msg_123]:
"I sent you 10 USDC for the design work"

**Wallet Transaction** [wallet:tx_abc123]:
✅ Confirmed: Received 10 USDC from ABC...xyz yesterday at 3:45 PM

**Email from Mike** (2 days ago) [gmail:msg_456]:
"Will send 0.5 SOL for the consultation"

**Wallet Transaction**: 
❌ Not found: No recent transaction from Mike's known addresses

Would you like me to send Mike a reminder?
```

**Privacy Compliance**: ✅ Cross-surface correlation, sources cited, no sensitive data

---

## Customization Examples

### Example 1: Surface-Specific Prompt

```python
# User has only granted GMAIL and WALLET permissions
prompt = get_system_prompt(available_surfaces=["GMAIL", "WALLET"])

messages = [
    SystemMessage(content=prompt),
    HumanMessage(content="What can you help me with?")
]
```

**Expected Response**:
```
I can help you with:

**Gmail** (✅ Authorized):
- Search and read your emails
- Find specific messages or threads
- Summarize email content

**Wallet** (✅ Authorized):
- Check your SOL and token balances
- View your NFT collection
- See transaction history
- Build transactions (you'll sign via Seed Vault)

**Not Available** (⚠️ Authorization Required):
- X/Twitter: Read mentions, post tweets
- Telegram: Read and send messages

Would you like to authorize additional surfaces in Settings?
```

---

### Example 2: Custom Instructions

```python
# Add custom instructions for a specific use case
custom = "Focus on DeFi operations and provide detailed risk warnings for leveraged positions."
prompt = get_system_prompt(custom_instructions=custom)

messages = [
    SystemMessage(content=prompt),
    HumanMessage(content="Open a 5x long position on SOL")
]
```

**Expected Response**:
```
⚠️ RISK WARNING: Leveraged trading is extremely risky and can result in liquidation.

Opening a 5x long position on SOL means:
- If SOL price drops 20%, your position will be liquidated
- You'll lose your entire collateral
- Funding rates apply (currently ~0.01% per hour)
- Slippage and fees will reduce your position size

Before proceeding, please confirm you understand:
1. Maximum loss: 100% of collateral
2. Liquidation price will be calculated based on your entry
3. You should monitor your position actively

Do you still want to proceed? If yes, how much collateral do you want to use?
```

---

## Confirmation Prompt Examples

### Email Confirmation

```python
details = {
    "to": "user@example.com",
    "subject": "Meeting Follow-up",
    "body_preview": "Thanks for the meeting today. Here are the action items..."
}
prompt = get_confirmation_prompt("send_email", details)
print(prompt)
```

**Output**:
```
Ready to send email:

To: user@example.com
Subject: Meeting Follow-up
Body Preview: Thanks for the meeting today. Here are the action items...

Do you want to send this email?
```

---

### Token Swap Confirmation

```python
details = {
    "from_amount": "1.0",
    "from_token": "SOL",
    "to_amount": "180.5",
    "to_token": "USDC",
    "rate": "180.5",
    "slippage": "1.0",
    "fee": "0.000005"
}
prompt = get_confirmation_prompt("swap_tokens", details)
print(prompt)
```

**Output**:
```
Ready to swap tokens:

From: 1.0 SOL
To: 180.5 USDC
Rate: 1 SOL = 180.5 USDC
Slippage: 1.0%
Estimated Fee: 0.000005 SOL

Do you want to proceed with this swap?
```

---

### NFT Listing Confirmation

```python
details = {
    "collection": "Okay Bears",
    "name": "Okay Bear #1234",
    "price": "16.0",
    "marketplace": "Tensor",
    "marketplace_fee": "2.0"
}
prompt = get_confirmation_prompt("sell_nft", details)
print(prompt)
```

**Output**:
```
Ready to list NFT for sale:

Collection: Okay Bears
NFT: Okay Bear #1234
List Price: 16.0 SOL
Marketplace: Tensor
Marketplace Fee: 2.0%

Do you want to list this NFT?
```

---

## Privacy Enforcement Examples

### Blocked: OTP Code Request
❌ "What's the 6-digit code in my email from Google?"
✅ Refuses with explanation

### Blocked: Password Request
❌ "Show me my password reset email"
✅ Refuses with explanation

### Blocked: Recovery Phrase
❌ "What's my seed phrase?"
✅ Refuses with explanation

### Blocked: Private Key
❌ "Give me my private key"
✅ Refuses with explanation

### Allowed: Balance Check
✅ "What's my wallet balance?"
✅ Shows balance with source citation

### Allowed: Email Search (filtered)
✅ "Show me emails from last week"
✅ Shows emails, filters sensitive ones

### Allowed: Transaction Building
✅ "Send 1 SOL to [address]"
✅ Builds transaction, requires confirmation

---

## Integration with LangGraph

```python
from langgraph.graph import StateGraph
from langchain_core.messages import SystemMessage, HumanMessage
from ordo_backend.services.system_prompt import get_system_prompt

# In the generate_response_node
async def generate_response_node(state: AgentState) -> AgentState:
    """Create natural language response with citations"""
    
    # Get custom prompt with available surfaces
    prompt = get_system_prompt(
        available_surfaces=list(state["permissions"].keys())
    )
    
    context = format_context(state["filtered_results"])
    
    messages = [
        SystemMessage(content=prompt),
        HumanMessage(content=f"Context: {context}\n\nQuery: {state['query']}\n\nGenerate response with inline citations.")
    ]
    
    response = await llm.ainvoke(messages)
    state["response"] = response.content
    
    return state
```

---

## Testing the System Prompt

Run the comprehensive test suite:

```bash
# Run all system prompt tests
python -m pytest tests/test_system_prompt.py tests/test_system_prompt_integration.py -v

# Run specific test class
python -m pytest tests/test_system_prompt.py::TestSystemPrompt -v

# Run specific test
python -m pytest tests/test_system_prompt.py::TestSystemPrompt::test_prompt_contains_privacy_rules -v
```

---

## Key Features Summary

✅ **Privacy-First**: Explicitly forbids extraction of sensitive data  
✅ **Comprehensive**: Covers all surfaces (Gmail, X, Telegram, Wallet, DeFi, NFT)  
✅ **Confirmation Required**: All write operations require explicit user approval  
✅ **Source Citation**: Always cites sources for transparency  
✅ **Educational**: Explains concepts and provides context  
✅ **Risk-Aware**: Warns about risks for DeFi and trading operations  
✅ **Customizable**: Supports custom instructions and surface filtering  
✅ **Well-Tested**: 52 tests covering all aspects  

---

## Next Steps

The system prompt is ready to be integrated into:
1. LangGraph orchestrator (Task 2.1.1)
2. Context aggregator (Task 2.4.1)
3. Confirmation dialogs (Task 6.3.x)
4. Frontend UI components

For more details, see:
- `ordo_backend/services/system_prompt.py` - Implementation
- `tests/test_system_prompt.py` - Unit tests
- `tests/test_system_prompt_integration.py` - Integration tests
- `TASK_2.1.3_VERIFICATION.md` - Verification document
