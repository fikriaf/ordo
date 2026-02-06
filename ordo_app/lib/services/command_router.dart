import '../models/command_action.dart';

/// Smart command router - decides if command needs AI or can be handled locally
class CommandRouter {
  /// Route command to appropriate handler
  static CommandRoute route(String command) {
    final lowerCommand = command.toLowerCase().trim();
    
    // Deposit - show panel immediately
    if (_isDepositCommand(lowerCommand)) {
      return CommandRoute(
        type: RouteType.localPanel,
        action: ActionType.deposit,
        params: {},
        reason: 'Deposit interface - instant UI',
      );
    }
    
    // Portfolio/Balance commands - direct API call
    if (_isBalanceCommand(lowerCommand)) {
      return CommandRoute(
        type: RouteType.directApi,
        action: ActionType.checkBalance,
        apiEndpoint: '/wallet/portfolio',
        reason: 'Simple balance check - no AI needed',
      );
    }
    
    // Portfolio view - show panel immediately
    if (_isPortfolioCommand(lowerCommand)) {
      return CommandRoute(
        type: RouteType.localPanel,
        action: ActionType.showPortfolio,
        params: {},
        reason: 'Portfolio - instant UI',
      );
    }
    
    // Transaction history - show panel immediately
    if (_isHistoryCommand(lowerCommand)) {
      return CommandRoute(
        type: RouteType.localPanel,
        action: ActionType.showTransactions,
        params: {},
        reason: 'Transaction history - instant UI',
      );
    }
    
    // Wallet management - show panel immediately
    if (_isWalletManagementCommand(lowerCommand)) {
      return CommandRoute(
        type: RouteType.localPanel,
        action: ActionType.manageWallets,
        params: {},
        reason: 'Wallet management - instant UI',
      );
    }
    
    // EVM wallet management
    if (_isEvmWalletCommand(lowerCommand)) {
      return CommandRoute(
        type: RouteType.localPanel,
        action: ActionType.manageEvmWallets,
        params: {'tab': 'evm'},
        reason: 'EVM wallet management - instant UI',
      );
    }
    
    // Approval history - show panel immediately
    if (_isApprovalHistoryCommand(lowerCommand)) {
      return CommandRoute(
        type: RouteType.localPanel,
        action: ActionType.showApprovalHistory,
        params: {},
        reason: 'Approval history - instant UI',
      );
    }
    
    // Command history - show panel immediately
    if (_isCommandHistoryCommand(lowerCommand)) {
      return CommandRoute(
        type: RouteType.localPanel,
        action: ActionType.showCommandHistory,
        params: {},
        reason: 'Command history - instant UI',
      );
    }
    
    // Analytics/Activity - show panel immediately
    if (_isAnalyticsCommand(lowerCommand)) {
      return CommandRoute(
        type: RouteType.localPanel,
        action: ActionType.showAnalytics,
        params: {},
        reason: 'Analytics - instant UI',
      );
    }
    
    // Security settings - show panel immediately
    if (_isSecurityCommand(lowerCommand)) {
      return CommandRoute(
        type: RouteType.localPanel,
        action: ActionType.showSecuritySettings,
        params: {},
        reason: 'Security settings - instant UI',
      );
    }
    
    // About - show panel immediately
    if (_isAboutCommand(lowerCommand)) {
      return CommandRoute(
        type: RouteType.localPanel,
        action: ActionType.showAbout,
        params: {},
        reason: 'About - instant UI',
      );
    }
    
    // NFT view - show panel immediately (will fetch data in panel)
    if (_isNftCommand(lowerCommand)) {
      return CommandRoute(
        type: RouteType.localPanel,
        action: ActionType.showNfts,
        params: {},
        reason: 'NFT gallery - instant UI',
      );
    }
    
    // Settings/Preferences - show panel immediately
    if (_isSettingsCommand(lowerCommand)) {
      return CommandRoute(
        type: RouteType.localPanel,
        action: ActionType.showPreferences,
        params: {},
        reason: 'Settings - instant UI',
      );
    }
    
    // Staking interface - show panel immediately
    if (_isStakingCommand(lowerCommand)) {
      return CommandRoute(
        type: RouteType.localPanel,
        action: ActionType.stake,
        params: {},
        reason: 'Staking interface - instant UI',
      );
    }
    
    // Lending interface - show panel immediately
    if (_isLendingCommand(lowerCommand)) {
      return CommandRoute(
        type: RouteType.localPanel,
        action: ActionType.lend,
        params: {},
        reason: 'Lending interface - instant UI',
      );
    }
    
    // Borrowing interface - show panel immediately
    if (_isBorrowingCommand(lowerCommand)) {
      return CommandRoute(
        type: RouteType.localPanel,
        action: ActionType.borrow,
        params: {},
        reason: 'Borrowing interface - instant UI',
      );
    }
    
    // Liquidity interface - show panel immediately
    if (_isLiquidityCommand(lowerCommand)) {
      return CommandRoute(
        type: RouteType.localPanel,
        action: ActionType.addLiquidity,
        params: {},
        reason: 'Liquidity interface - instant UI',
      );
    }
    
    // Bridge interface - show panel immediately
    if (_isBridgeCommand(lowerCommand)) {
      return CommandRoute(
        type: RouteType.localPanel,
        action: ActionType.bridge,
        params: {},
        reason: 'Bridge interface - instant UI',
      );
    }
    
    // Token risk analysis
    if (_isTokenRiskCommand(lowerCommand)) {
      final token = _extractToken(lowerCommand);
      return CommandRoute(
        type: RouteType.aiAgent, // Need token mint and analysis
        action: ActionType.tokenRisk,
        params: {'symbol': token},
        reason: 'Token risk analysis needs AI',
      );
    }
    
    // Simple price check
    if (_isPriceCommand(lowerCommand)) {
      final token = _extractToken(lowerCommand);
      return CommandRoute(
        type: RouteType.aiAgent, // Need token mint address, use AI
        action: ActionType.tokenPrice,
        params: {'symbol': token},
        reason: 'Price check needs token mint address',
      );
    }
    
    // Swap with clear parameters - show panel directly
    final swapParams = _parseSwapCommand(lowerCommand);
    if (swapParams != null) {
      return CommandRoute(
        type: RouteType.localPanel,
        action: ActionType.swapTokens,
        params: swapParams,
        reason: 'Clear swap parameters - show panel directly',
      );
    }
    
    // Generic swap command - show swap panel
    if (_isSwapCommand(lowerCommand)) {
      return CommandRoute(
        type: RouteType.localPanel,
        action: ActionType.swapTokens,
        params: {},
        reason: 'Swap interface - instant UI',
      );
    }
    
    // Send/Transfer with clear parameters
    final sendParams = _parseSendCommand(lowerCommand);
    if (sendParams != null) {
      return CommandRoute(
        type: RouteType.localPanel,
        action: ActionType.sendSol,
        params: sendParams,
        reason: 'Clear send parameters - show panel directly',
      );
    }
    
    // Generic send command - show send panel
    if (_isSendCommand(lowerCommand)) {
      return CommandRoute(
        type: RouteType.localPanel,
        action: ActionType.sendSol,
        params: {},
        reason: 'Send interface - instant UI',
      );
    }
    
    // Complex commands - need AI reasoning
    if (_needsAiReasoning(lowerCommand)) {
      return CommandRoute(
        type: RouteType.aiAgent,
        action: ActionType.unknown,
        reason: 'Complex query - needs AI reasoning',
      );
    }
    
    // Default: use AI for ambiguous commands
    return CommandRoute(
      type: RouteType.aiAgent,
      action: ActionType.unknown,
      reason: 'Ambiguous command - using AI',
    );
  }
  
  // Balance check patterns
  static bool _isBalanceCommand(String cmd) {
    return cmd.contains('balance') ||
           cmd.contains('check balance') ||
           cmd == 'balance' ||
           cmd == 'bal';
  }
  
  // Portfolio patterns
  static bool _isPortfolioCommand(String cmd) {
    return cmd.contains('portfolio') ||
           cmd.contains('holdings') ||
           cmd.contains('my assets');
  }
  
  // History patterns
  static bool _isHistoryCommand(String cmd) {
    return (cmd.contains('history') && !cmd.contains('approval') && !cmd.contains('command')) ||
           cmd.contains('transactions') ||
           cmd.contains('tx history');
  }
  
  // Wallet management patterns
  static bool _isWalletManagementCommand(String cmd) {
    return cmd.contains('manage wallet') ||
           cmd.contains('my wallets') ||
           cmd.contains('wallet management') ||
           cmd.contains('show wallets') ||
           cmd.contains('list wallets') ||
           cmd.contains('view wallets');
  }
  
  // EVM wallet patterns
  static bool _isEvmWalletCommand(String cmd) {
    return cmd.contains('evm wallet') ||
           cmd.contains('ethereum wallet') ||
           cmd.contains('polygon wallet') ||
           cmd.contains('eth wallet') ||
           cmd.contains('manage evm');
  }
  
  // Approval history patterns
  static bool _isApprovalHistoryCommand(String cmd) {
    return cmd.contains('approval history') ||
           cmd.contains('past approvals') ||
           cmd.contains('approved transactions') ||
           cmd.contains('rejected transactions') ||
           cmd.contains('show approvals');
  }
  
  // Command history patterns
  static bool _isCommandHistoryCommand(String cmd) {
    return cmd.contains('command history') ||
           cmd.contains('past commands') ||
           cmd.contains('recent commands') ||
           cmd.contains('my commands');
  }
  
  // Analytics patterns
  static bool _isAnalyticsCommand(String cmd) {
    return cmd.contains('analytics') ||
           cmd.contains('activity') ||
           cmd.contains('address activity') ||
           cmd.contains('wallet activity') ||
           cmd.contains('my activity');
  }
  
  // Security settings patterns
  static bool _isSecurityCommand(String cmd) {
    return cmd.contains('security') ||
           cmd.contains('limits') ||
           cmd.contains('security settings') ||
           cmd.contains('transaction limits') ||
           cmd.contains('safety settings');
  }
  
  // About patterns
  static bool _isAboutCommand(String cmd) {
    return cmd.contains('about') ||
           cmd.contains('about ordo') ||
           cmd.contains('what is ordo') ||
           cmd.contains('help');
  }
  
  // NFT patterns
  static bool _isNftCommand(String cmd) {
    return (cmd.contains('nft') || cmd.contains('nfts')) &&
           (cmd.contains('show') || cmd.contains('my') || cmd.contains('view'));
  }
  
  // Settings patterns
  static bool _isSettingsCommand(String cmd) {
    return cmd.contains('settings') ||
           cmd.contains('preferences') ||
           cmd.contains('config');
  }
  
  // Staking patterns
  static bool _isStakingCommand(String cmd) {
    return (cmd.contains('stake') || cmd.contains('staking')) &&
           !cmd.contains('unstake');
  }
  
  // Lending patterns
  static bool _isLendingCommand(String cmd) {
    return cmd.contains('lend') || cmd.contains('lending');
  }
  
  // Borrowing patterns
  static bool _isBorrowingCommand(String cmd) {
    return cmd.contains('borrow') || cmd.contains('borrowing');
  }
  
  // Liquidity patterns
  static bool _isLiquidityCommand(String cmd) {
    return cmd.contains('liquidity') || 
           cmd.contains('add liquidity') ||
           cmd.contains('pool');
  }
  
  // Bridge patterns
  static bool _isBridgeCommand(String cmd) {
    return cmd.contains('bridge') || cmd.contains('cross-chain');
  }
  
  // Generic swap patterns (for instant UI)
  static bool _isSwapCommand(String cmd) {
    return cmd.contains('swap') || 
           cmd.contains('exchange') || 
           cmd.contains('convert') ||
           cmd.contains('trade');
  }
  
  // Generic send/transfer patterns (for instant UI)
  static bool _isSendCommand(String cmd) {
    return cmd.contains('send') || cmd.contains('transfer');
  }
  
  // Deposit patterns
  static bool _isDepositCommand(String cmd) {
    return cmd.contains('deposit') || 
           cmd.contains('receive') || 
           cmd.contains('fund') ||
           cmd.contains('top up') ||
           cmd.contains('add funds') ||
           (cmd.contains('buy') && cmd.contains('crypto'));
  }
  
  // Token risk patterns
  static bool _isTokenRiskCommand(String cmd) {
    return (cmd.contains('risk') || cmd.contains('safe') || cmd.contains('analyze')) &&
           (cmd.contains('token') || cmd.contains('sol') || cmd.contains('usdc') || cmd.contains('bonk'));
  }
  
  // Price check patterns
  static bool _isPriceCommand(String cmd) {
    return (cmd.contains('price') || cmd.contains('how much')) &&
           !cmd.contains('swap') &&
           !cmd.contains('buy');
  }
  
  // Extract token from price command
  static String _extractToken(String cmd) {
    // Try to find token symbol
    final tokens = ['sol', 'usdc', 'usdt', 'bonk', 'jup', 'jto'];
    for (final token in tokens) {
      if (cmd.contains(token)) {
        return token.toUpperCase();
      }
    }
    return 'SOL'; // default
  }
  
  // Parse swap command: "swap 1 sol to usdc"
  static Map<String, dynamic>? _parseSwapCommand(String cmd) {
    if (!cmd.contains('swap')) return null;
    
    // Pattern: swap [amount] [from] to [to]
    final regex = RegExp(r'swap\s+(\d+\.?\d*)\s+(\w+)\s+to\s+(\w+)', caseSensitive: false);
    final match = regex.firstMatch(cmd);
    
    if (match != null) {
      return {
        'amount': double.tryParse(match.group(1) ?? '0') ?? 0.0,
        'from': match.group(2)?.toUpperCase() ?? 'SOL',
        'to': match.group(3)?.toUpperCase() ?? 'USDC',
      };
    }
    
    return null;
  }
  
  // Parse send command: "send 0.5 sol to [address]"
  static Map<String, dynamic>? _parseSendCommand(String cmd) {
    if (!cmd.contains('send') && !cmd.contains('transfer')) return null;
    
    // Pattern: send [amount] [token] to [address]
    final regex = RegExp(r'(?:send|transfer)\s+(\d+\.?\d*)\s+(\w+)', caseSensitive: false);
    final match = regex.firstMatch(cmd);
    
    if (match != null) {
      return {
        'amount': double.tryParse(match.group(1) ?? '0') ?? 0.0,
        'token': match.group(2)?.toUpperCase() ?? 'SOL',
      };
    }
    
    return null;
  }
  
  // Check if command needs AI reasoning
  static bool _needsAiReasoning(String cmd) {
    // Questions
    if (cmd.contains('?') || 
        cmd.startsWith('what') ||
        cmd.startsWith('how') ||
        cmd.startsWith('why') ||
        cmd.startsWith('when') ||
        cmd.startsWith('should')) {
      return true;
    }
    
    // Complex analysis
    if (cmd.contains('analyze') ||
        cmd.contains('recommend') ||
        cmd.contains('suggest') ||
        cmd.contains('best') ||
        cmd.contains('strategy') ||
        cmd.contains('optimize')) {
      return true;
    }
    
    return false;
  }
}

enum RouteType {
  directApi,    // Call API directly, no AI
  localPanel,   // Show panel with parsed data, no API
  aiAgent,      // Use AI for reasoning
}

class CommandRoute {
  final RouteType type;
  final ActionType action;
  final String? apiEndpoint;
  final Map<String, dynamic>? params;
  final String reason;
  
  CommandRoute({
    required this.type,
    required this.action,
    this.apiEndpoint,
    this.params,
    required this.reason,
  });
}
