# 🧠 Context-Aware Smart Suggestions

## Overview

Sistem suggestion yang cerdas dan adaptif berdasarkan state user dan recent actions.

---

## 🎯 Problem

**Before:**
- Suggestions selalu sama (random/round-robin)
- Tidak relevan dengan user state
- User harus cari command sendiri
- Tidak ada learning dari user behavior

**After:**
- Suggestions berubah based on context
- Relevan dengan user state
- Suggest next logical actions
- Learn from command history

---

## 🔧 How It Works

### ContextService

Tracks user state dan provides smart suggestions:

```dart
enum UserContext {
  idle,              // No recent activity
  hasWallet,         // User has wallet
  hasBalance,        // User has balance > 0
  afterBalance,      // Just checked balance
  afterSwap,         // Just completed swap
  afterSend,         // Just sent tokens
  afterError,        // Last command failed
  afterStake,        // Just staked
  afterNft,          // Just viewed NFTs
}
```

### Context Detection

```dart
// Automatically detects context based on:
- Authentication status
- Wallet balance
- Last command executed
- Error state
- Command history (last 10)
```

---

## 📊 Context-Based Suggestions

### 1. Idle (Not Logged In)
```
Suggestions:
- "create wallet"
- "what's SOL price?"
- "show my portfolio"
```

### 2. Has Wallet (No Balance)
```
Suggestions:
- "check balance"
- "what's SOL price?"
- "show my portfolio"
```

### 3. Has Balance
```
Suggestions:
- "check balance"
- "swap 1 sol to usdc"
- "send 0.5 sol to [address]"
- "stake 1 sol"
- "show my nfts"
```

### 4. After Checking Balance
```
Suggestions:
- "swap 1 sol to usdc"
- "send 0.5 sol to [address]"
- "stake 1 sol"
- "show my nfts"
- "show transaction history"
```

### 5. After Swap
```
Suggestions:
- "check balance"
- "swap again"
- "show transaction history"
- "what's SOL price?"
```

### 6. After Send
```
Suggestions:
- "check balance"
- "send again"
- "show transaction history"
```

### 7. After Error
```
Suggestions:
- [Last command] (retry)
- "check balance"
- "what went wrong?"
```

### 8. After Staking
```
Suggestions:
- "check balance"
- "check staking rewards"
- "unstake sol"
```

### 9. After Viewing NFTs
```
Suggestions:
- "mint nft"
- "send nft"
- "check balance"
```

---

## 🎨 Implementation

### ContextService

```dart
class ContextService extends ChangeNotifier {
  UserContext _currentContext = UserContext.idle;
  String? _lastCommand;
  String? _lastError;
  bool _isAuthenticated = false;
  double _balance = 0.0;
  List<String> _recentCommands = [];
  
  // Update context
  void recordCommand(String command) {
    _lastCommand = command;
    _recentCommands.insert(0, command);
    _updateContext();
  }
  
  void recordError(String error) {
    _lastError = error;
    _currentContext = UserContext.afterError;
  }
  
  // Get contextual suggestions
  List<String> getContextualSuggestions() {
    switch (_currentContext) {
      case UserContext.idle:
        return ['create wallet', 'what\'s SOL price?'];
      case UserContext.hasBalance:
        return ['swap 1 sol to usdc', 'send 0.5 sol'];
      // ... more contexts
    }
  }
}
```

### CommandIndexService

```dart
static List<SuggestionItem> getContextualSuggestions({
  required bool isAuthenticated,
  required double balance,
  String? lastCommand,
  bool hasError = false,
  int limit = 5,
}) {
  // Filter commands based on context
  if (hasError && lastCommand != null) {
    // Suggest retry + safe commands
  } else if (lastCommand?.contains('balance')) {
    // Suggest trading actions
  } else if (!isAuthenticated) {
    // Suggest wallet creation
  } else if (balance <= 0) {
    // Suggest balance check
  } else {
    // Suggest all trading actions
  }
}
```

### AssistantController

```dart
// Record context on every command
Future<void> processCommand(String command) async {
  try {
    // Execute command...
    
    // Record success
    contextService.recordCommand(command);
  } catch (e) {
    // Record error
    contextService.recordError(e.toString());
  }
}
```

---

## 📈 Benefits

### 1. Faster Workflow
- Next logical action always suggested
- No need to remember commands
- Quick access to common actions

### 2. Better UX
- Relevant suggestions only
- Adapts to user behavior
- Learns from history

### 3. Error Recovery
- Retry last command easily
- Safe fallback suggestions
- Clear error context

### 4. Personalization
- Based on user state
- Considers balance
- Remembers recent actions

---

## 🧪 Testing

### Test Scenarios

1. **New User (Not Logged In)**
   ```
   Expected: "create wallet", "what's SOL price?"
   ```

2. **Logged In (No Balance)**
   ```
   Expected: "check balance", "what's SOL price?"
   ```

3. **Has Balance**
   ```
   Expected: "swap", "send", "stake", "nfts"
   ```

4. **After Checking Balance**
   ```
   Expected: Trading actions (swap, send, stake)
   ```

5. **After Swap**
   ```
   Expected: "check balance", "swap again", "history"
   ```

6. **After Error**
   ```
   Expected: Retry last command, safe actions
   ```

---

## 🔄 Future Enhancements

### 1. Machine Learning
- Learn from user patterns
- Predict next action
- Personalized suggestions

### 2. Time-Based Context
- Morning: Check balance, prices
- Evening: Review history, analytics
- Weekend: Explore new features

### 3. Balance-Based Suggestions
- Low balance: Suggest receive/buy
- High balance: Suggest invest/stake
- Medium balance: Suggest trade

### 4. Advanced History
- Frequently used commands
- Command sequences
- User preferences

### 5. Social Context
- Trending tokens
- Popular actions
- Community suggestions

---

## 📊 Statistics

### Code Added
- **ContextService:** ~250 lines
- **CommandIndex updates:** ~100 lines
- **AssistantController updates:** ~20 lines
- **Main.dart updates:** ~10 lines
- **Total:** ~380 lines

### Files Modified
- NEW: `context_service.dart`
- MODIFIED: `command_index.dart`
- MODIFIED: `assistant_controller.dart`
- MODIFIED: `main.dart`

---

## ✅ Status

**Implementation:** ✅ Complete  
**Testing:** ⚠️ Needs manual testing  
**Documentation:** ✅ Complete  
**Committed:** ✅ Yes  
**Pushed:** ✅ Yes

---

## 🚀 Next Steps

1. **Test in app** - Verify context detection works
2. **Refine suggestions** - Based on user feedback
3. **Add more contexts** - Cover edge cases
4. **Implement ML** - Learn from patterns
5. **Add analytics** - Track suggestion usage

---

**Date:** February 6, 2026  
**Feature:** Context-Aware Smart Suggestions  
**Impact:** Better UX, faster workflow, personalized experience
