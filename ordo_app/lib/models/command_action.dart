enum ActionType {
  // Portfolio
  checkBalance,
  showPortfolio,
  
  // Token Operations
  tokenInfo,
  tokenRisk,
  tokenPrice,
  
  // Transfers
  sendSol,
  sendToken,
  deposit,        // NEW: Show deposit panel
  
  // Swaps
  swapTokens,
  getSwapQuote,
  
  // DeFi
  stake,
  unstake,
  lend,
  borrow,
  addLiquidity,
  removeLiquidity,
  bridge,
  
  // NFT
  showNfts,
  mintNft,
  sendNft,
  
  // Wallet Management
  createWallet,
  importWallet,
  switchWallet,
  manageWallets,      // NEW: Show wallet management panel
  manageEvmWallets,   // NEW: EVM wallet operations
  deleteWallet,       // NEW: Delete wallet operation
  
  // Settings
  showPreferences,
  setLimit,
  setSlippage,
  showSecuritySettings, // NEW: Security & limits panel
  networkSettings,      // NEW: Network switching (devnet/mainnet)
  faucet,               // NEW: Faucet/airdrop panel
  
  // History
  showTransactions,
  showCommandHistory,   // Command history panel
  showApprovalHistory,  // NEW: Approval history panel
  
  // Analytics
  showAnalytics,        // NEW: Helius analytics panel
  showActivity,         // NEW: Address activity
  
  // Approval
  requiresApproval,
  
  // About
  showAbout,            // NEW: About panel
  
  // Generic
  info,
  error,
  unknown,
}

// Map backend action type strings to frontend ActionType enum
ActionType _mapBackendActionType(String? actionType) {
  if (actionType == null) return ActionType.info;
  
  switch (actionType) {
    // Portfolio
    case 'check_balance':
      return ActionType.checkBalance;
    case 'show_portfolio':
      return ActionType.showPortfolio;
    
    // Token Operations
    case 'token_info':
      return ActionType.tokenInfo;
    case 'token_risk':
      return ActionType.tokenRisk;
    case 'token_price':
      return ActionType.tokenPrice;
    
    // Transfers
    case 'send_sol':
      return ActionType.sendSol;
    case 'send_token':
      return ActionType.sendToken;
    case 'deposit':
      return ActionType.deposit;
    
    // Swaps
    case 'swap_tokens':
      return ActionType.swapTokens;
    case 'get_swap_quote':
      return ActionType.getSwapQuote;
    
    // DeFi
    case 'stake':
      return ActionType.stake;
    case 'unstake':
      return ActionType.unstake;
    case 'lend':
      return ActionType.lend;
    case 'borrow':
      return ActionType.borrow;
    case 'add_liquidity':
      return ActionType.addLiquidity;
    case 'remove_liquidity':
      return ActionType.removeLiquidity;
    case 'bridge':
      return ActionType.bridge;
    
    // NFT
    case 'show_nfts':
      return ActionType.showNfts;
    case 'mint_nft':
      return ActionType.mintNft;
    case 'send_nft':
      return ActionType.sendNft;
    
    // Wallet Management
    case 'create_wallet':
      return ActionType.createWallet;
    case 'import_wallet':
      return ActionType.importWallet;
    case 'switch_wallet':
      return ActionType.switchWallet;
    case 'manage_wallets':
      return ActionType.manageWallets;
    case 'manage_evm_wallets':
      return ActionType.manageEvmWallets;
    case 'delete_wallet':
      return ActionType.deleteWallet;
    
    // Settings
    case 'show_preferences':
      return ActionType.showPreferences;
    case 'set_limit':
      return ActionType.setLimit;
    case 'set_slippage':
      return ActionType.setSlippage;
    case 'show_security_settings':
      return ActionType.showSecuritySettings;
    case 'network_settings':
      return ActionType.networkSettings;
    case 'faucet':
      return ActionType.faucet;
    
    // History
    case 'show_transactions':
      return ActionType.showTransactions;
    case 'show_command_history':
      return ActionType.showCommandHistory;
    case 'show_approval_history':
      return ActionType.showApprovalHistory;
    
    // Analytics
    case 'show_analytics':
      return ActionType.showAnalytics;
    case 'show_activity':
      return ActionType.showActivity;
    
    // Approval
    case 'requires_approval':
      return ActionType.requiresApproval;
    
    // About
    case 'show_about':
      return ActionType.showAbout;
    
    // Generic
    case 'info':
      return ActionType.info;
    case 'error':
      return ActionType.error;
    
    default:
      return ActionType.unknown;
  }
}

class CommandAction {
  final ActionType type;
  final Map<String, dynamic> data;
  final String? summary;
  final String? rawMessage;
  final List<String>? toolsUsed;
  final String? status; // success, error, pending, requires_approval
  
  CommandAction({
    required this.type,
    required this.data,
    this.summary,
    this.rawMessage,
    this.toolsUsed,
    this.status,
  });
  
  /// Parse from new structured backend response format
  factory CommandAction.fromApiResponse(Map<String, dynamic> response) {
    final data = response['data'] ?? {};
    
    print('🔵 Parsing API response:');
    print('🔵 Response data keys: ${data.keys.toList()}');
    
    // Check if this is the new structured format
    if (data.containsKey('actionType')) {
      // New structured format from backend
      final actionType = _mapBackendActionType(data['actionType'] as String?);
      final details = data['details'] as Map<String, dynamic>? ?? {};
      final summary = data['summary'] as String?;
      final rawMessage = data['rawMessage'] as String?;
      final toolsUsed = (data['toolsUsed'] as List?)?.map((e) => e.toString()).toList();
      final status = data['status'] as String?;
      
      print('🔵 New format - Action type: $actionType');
      print('🔵 Summary: $summary');
      print('🔵 Status: $status');
      print('🔵 Tools used: $toolsUsed');
      print('🔵 Details keys: ${details.keys.toList()}');
      
      return CommandAction(
        type: actionType,
        data: details,
        summary: summary,
        rawMessage: rawMessage,
        toolsUsed: toolsUsed,
        status: status,
      );
    }
    
    // Legacy format fallback (old response structure)
    print('🔵 Legacy format detected, using fallback parsing');
    return _parseLegacyResponse(response);
  }
  
  /// Parse from streaming 'done' event (has structured data directly)
  factory CommandAction.fromStreamDoneEvent(Map<String, dynamic> event) {
    print('🔵 Parsing stream done event:');
    print('🔵 Event keys: ${event.keys.toList()}');
    
    // Stream done event has structured data at root level
    if (event.containsKey('actionType')) {
      final actionType = _mapBackendActionType(event['actionType'] as String?);
      final details = event['details'] as Map<String, dynamic>? ?? {};
      final summary = event['summary'] as String?;
      final rawMessage = event['rawMessage'] as String?;
      final toolsUsed = (event['toolsUsed'] as List?)?.map((e) => e.toString()).toList();
      final status = event['status'] as String?;
      
      print('🔵 Stream done - Action type: $actionType');
      print('🔵 Summary: $summary');
      
      return CommandAction(
        type: actionType,
        data: details,
        summary: summary,
        rawMessage: rawMessage,
        toolsUsed: toolsUsed,
        status: status,
      );
    }
    
    // Fallback
    return CommandAction(
      type: ActionType.info,
      data: {},
      summary: 'Command processed',
      status: 'success',
    );
  }
  
  /// Legacy response parser (for backwards compatibility)
  static CommandAction _parseLegacyResponse(Map<String, dynamic> response) {
    final data = response['data'] ?? {};
    final message = data['message'] as String?;
    final toolCallsList = data['toolCalls'] as List?;
    final toolCalls = toolCallsList?.map((t) => t['name']?.toString() ?? 'Tool').toList();
    
    // Parse action type from tool calls or message
    ActionType type = ActionType.unknown;
    Map<String, dynamic> actionData = {};
    
    if (toolCallsList != null && toolCallsList.isNotEmpty) {
      // Extract data from tool calls
      for (var tool in toolCallsList) {
        final toolName = (tool['name'] as String?)?.toLowerCase() ?? '';
        final toolResult = tool['result'];
        
        // Map tool names to action types and extract data
        if (toolName.contains('balance') || toolName.contains('portfolio') || toolName.contains('wallet')) {
          type = ActionType.checkBalance;
          
          // Extract balance data from tool result
          if (toolResult is Map) {
            actionData = Map<String, dynamic>.from(toolResult);
          } else if (toolResult is String) {
            actionData = _parseBalanceFromString(toolResult);
          }
        } else if (toolName.contains('swap')) {
          type = ActionType.swapTokens;
          if (toolResult is Map) {
            actionData = Map<String, dynamic>.from(toolResult);
          }
        } else if (toolName.contains('transfer') || toolName.contains('send')) {
          type = ActionType.sendSol;
          if (toolResult is Map) {
            actionData = Map<String, dynamic>.from(toolResult);
          }
        } else if (toolName.contains('stake')) {
          type = ActionType.stake;
          if (toolResult is Map) {
            actionData = Map<String, dynamic>.from(toolResult);
          }
        } else if (toolName.contains('risk')) {
          type = ActionType.tokenRisk;
          if (toolResult is Map) {
            actionData = Map<String, dynamic>.from(toolResult);
          }
        } else if (toolName.contains('price')) {
          type = ActionType.tokenPrice;
          if (toolResult is Map) {
            actionData = Map<String, dynamic>.from(toolResult);
          }
        } else if (toolName.contains('nft')) {
          type = ActionType.showNfts;
          if (toolResult is Map) {
            actionData = Map<String, dynamic>.from(toolResult);
          }
        } else if (toolName.contains('wallet')) {
          type = ActionType.createWallet;
          if (toolResult is Map) {
            actionData = Map<String, dynamic>.from(toolResult);
          }
        }
        
        // If we found a type, break
        if (type != ActionType.unknown) break;
      }
      
      // If still unknown, default to info
      if (type == ActionType.unknown) {
        type = ActionType.info;
        actionData = {'summary': _extractSummary(message ?? 'Command processed')};
      }
    } else if (message != null) {
      // No tool calls - just info response
      type = ActionType.info;
      actionData = {'summary': _extractSummary(message)};
    }
    
    return CommandAction(
      type: type,
      data: actionData,
      summary: _extractSummary(message ?? 'Command processed'),
      rawMessage: message,
      toolsUsed: toolCalls,
      status: 'success',
    );
  }
  
  // Parse balance from string response
  static Map<String, dynamic> _parseBalanceFromString(String text) {
    final data = <String, dynamic>{};
    
    // Try to extract SOL balance
    final solMatch = RegExp(r'(\d+\.?\d*)\s*SOL').firstMatch(text);
    if (solMatch != null) {
      data['sol'] = double.tryParse(solMatch.group(1) ?? '0') ?? 0.0;
    }
    
    // Try to extract USD value
    final usdMatch = RegExp(r'\$(\d+\.?\d*)').firstMatch(text);
    if (usdMatch != null) {
      data['usdValue'] = double.tryParse(usdMatch.group(1) ?? '0') ?? 0.0;
    }
    
    return data;
  }
  
  // Extract short summary from long message
  static String _extractSummary(String message) {
    // Take first sentence or first 100 chars
    final sentences = message.split('. ');
    if (sentences.isNotEmpty) {
      return sentences.first.trim();
    }
    return message.length > 100 
        ? '${message.substring(0, 100)}...' 
        : message;
  }
  
  /// Get display-friendly title for the action
  String get title {
    switch (type) {
      case ActionType.checkBalance:
        return 'Balance';
      case ActionType.showPortfolio:
        return 'Portfolio';
      case ActionType.tokenInfo:
        return 'Token Info';
      case ActionType.tokenRisk:
        return 'Risk Analysis';
      case ActionType.tokenPrice:
        return 'Price';
      case ActionType.sendSol:
      case ActionType.sendToken:
        return 'Transfer';
      case ActionType.swapTokens:
        return 'Swap';
      case ActionType.getSwapQuote:
        return 'Swap Quote';
      case ActionType.stake:
        return 'Stake';
      case ActionType.unstake:
        return 'Unstake';
      case ActionType.createWallet:
        return 'Wallet Created';
      case ActionType.manageEvmWallets:
        return 'EVM Wallet';
      case ActionType.deleteWallet:
        return 'Wallet Deleted';
      case ActionType.showNfts:
        return 'NFTs';
      case ActionType.showTransactions:
        return 'Transactions';
      case ActionType.info:
        // Generate dynamic title from summary if available
        return _generateInfoTitle();
      case ActionType.error:
        return 'Error';
      default:
        return 'Result';
    }
  }
  
  /// Generate a contextual title for info-type responses
  String _generateInfoTitle() {
    if (summary == null || summary!.isEmpty) return 'Response';
    
    final text = summary!.toLowerCase();
    
    // Check for common topics and return appropriate titles
    if (text.contains('wallet')) return 'Wallets';
    if (text.contains('balance') || text.contains('saldo')) return 'Balance';
    if (text.contains('price') || text.contains('harga')) return 'Price';
    if (text.contains('token')) return 'Token Info';
    if (text.contains('transaction') || text.contains('transaksi')) return 'Transactions';
    if (text.contains('swap')) return 'Swap';
    if (text.contains('stake') || text.contains('staking')) return 'Staking';
    if (text.contains('nft')) return 'NFTs';
    if (text.contains('help') || text.contains('bantuan')) return 'Help';
    if (text.contains('error') || text.contains('gagal') || text.contains('failed')) return 'Error';
    
    // Default to "Response" for general Q&A
    return 'Response';
  }
  
  /// Get icon name for the action (material icon names)
  String get iconName {
    switch (type) {
      case ActionType.checkBalance:
      case ActionType.showPortfolio:
        return 'account_balance_wallet';
      case ActionType.tokenInfo:
        return 'info';
      case ActionType.tokenRisk:
        return 'security';
      case ActionType.tokenPrice:
        return 'trending_up';
      case ActionType.sendSol:
      case ActionType.sendToken:
        return 'send';
      case ActionType.swapTokens:
      case ActionType.getSwapQuote:
        return 'swap_horiz';
      case ActionType.stake:
        return 'savings';
      case ActionType.unstake:
        return 'money_off';
      case ActionType.createWallet:
      case ActionType.manageEvmWallets:
        return 'add_card';
      case ActionType.deleteWallet:
        return 'delete';
      case ActionType.showNfts:
        return 'collections';
      case ActionType.showTransactions:
        return 'history';
      case ActionType.error:
        return 'error';
      default:
        return 'chat';
    }
  }
  
  /// Check if action was successful
  bool get isSuccess => status == 'success' || status == null;
  
  /// Check if action requires user approval
  bool get needsApproval => status == 'requires_approval';
}
