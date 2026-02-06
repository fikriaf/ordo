import '../widgets/suggestions_panel.dart';

class IndexedCommand {
  final List<String> keywords;
  final String icon;
  final String label;
  final String template;
  final String tag;
  final bool requiresAuth;
  final int priority;

  const IndexedCommand({
    required this.keywords,
    required this.icon,
    required this.label,
    required this.template,
    required this.tag,
    this.requiresAuth = false,
    this.priority = 0,
  });
}

class CommandIndexService {
  static final List<IndexedCommand> _commands = [
    // Wallet Commands
    IndexedCommand(
      keywords: ['check', 'balance', 'wallet', 'my balance', 'show balance'],
      icon: 'wallet',
      label: 'Check balance',
      template: 'check balance',
      tag: '[wallet]',
      requiresAuth: true,
      priority: 5,
    ),
    IndexedCommand(
      keywords: ['create', 'wallet', 'new wallet'],
      icon: 'wallet',
      label: 'Create wallet',
      template: 'create wallet',
      tag: '[wallet]',
      priority: 5,
    ),
    IndexedCommand(
      keywords: ['deposit', 'receive', 'fund', 'top up', 'add funds', 'buy crypto'],
      icon: 'download',
      label: 'Deposit',
      template: 'deposit funds',
      tag: '[deposit]',
      requiresAuth: true,
      priority: 5,
    ),
    
    // Swap Commands - instant UI
    IndexedCommand(
      keywords: ['swap', 'exchange', 'convert', 'trade'],
      icon: 'repeat',
      label: 'Swap tokens',
      template: 'swap tokens',
      tag: '[swap]',
      requiresAuth: true,
      priority: 5,
    ),
    IndexedCommand(
      keywords: ['swap sol', 'swap 1 sol'],
      icon: 'repeat',
      label: 'Swap SOL to USDC',
      template: 'swap 1 sol to usdc',
      tag: '[swap]',
      requiresAuth: true,
      priority: 5,
    ),
    
    // Transfer Commands - instant UI
    IndexedCommand(
      keywords: ['send', 'transfer', 'pay'],
      icon: 'send',
      label: 'Send tokens',
      template: 'send tokens',
      tag: '[send]',
      requiresAuth: true,
      priority: 5,
    ),
    IndexedCommand(
      keywords: ['send sol', 'transfer sol'],
      icon: 'send',
      label: 'Send SOL',
      template: 'send sol',
      tag: '[send]',
      requiresAuth: true,
      priority: 5,
    ),
    
    // Price Commands
    IndexedCommand(
      keywords: ['price', 'sol price', 'what is', 'how much'],
      icon: 'chart',
      label: 'SOL price',
      template: 'what\'s the price of SOL?',
      tag: '[chart]',
      priority: 5,
    ),
    IndexedCommand(
      keywords: ['chart', 'show chart', 'price chart'],
      icon: 'chart',
      label: 'Show price chart',
      template: 'show SOL chart',
      tag: '[chart]',
      priority: 5,
    ),
    
    // DeFi Commands - instant UI
    IndexedCommand(
      keywords: ['stake', 'staking'],
      icon: 'coins',
      label: 'Stake SOL',
      template: 'stake sol',
      tag: '[stake]',
      requiresAuth: true,
      priority: 5,
    ),
    IndexedCommand(
      keywords: ['lend', 'lending'],
      icon: 'hand_coins',
      label: 'Lend assets',
      template: 'lend assets',
      tag: '[lend]',
      requiresAuth: true,
      priority: 5,
    ),
    IndexedCommand(
      keywords: ['borrow', 'borrowing'],
      icon: 'hand_coins',
      label: 'Borrow assets',
      template: 'borrow assets',
      tag: '[borrow]',
      requiresAuth: true,
      priority: 5,
    ),
    IndexedCommand(
      keywords: ['liquidity', 'add liquidity', 'pool'],
      icon: 'droplet',
      label: 'Add liquidity',
      template: 'add liquidity',
      tag: '[liquidity]',
      requiresAuth: true,
      priority: 5,
    ),
    IndexedCommand(
      keywords: ['bridge', 'cross-chain'],
      icon: 'bridge',
      label: 'Bridge assets',
      template: 'bridge assets',
      tag: '[bridge]',
      requiresAuth: true,
      priority: 5,
    ),
    
    // NFT Commands
    IndexedCommand(
      keywords: ['nft', 'nfts', 'my nfts', 'show nfts'],
      icon: 'image',
      label: 'View NFTs',
      template: 'show my nfts',
      tag: '[nft]',
      requiresAuth: true,
      priority: 5,
    ),
    IndexedCommand(
      keywords: ['mint', 'mint nft', 'create nft'],
      icon: 'image',
      label: 'Mint NFT',
      template: 'mint nft',
      tag: '[nft]',
      requiresAuth: true,
      priority: 5,
    ),
    
    // Portfolio Commands
    IndexedCommand(
      keywords: ['portfolio', 'my portfolio', 'holdings'],
      icon: 'bar_chart',
      label: 'View portfolio',
      template: 'show my portfolio',
      tag: '[portfolio]',
      requiresAuth: true,
      priority: 5,
    ),
    IndexedCommand(
      keywords: ['history', 'transactions', 'tx history'],
      icon: 'history',
      label: 'Transaction history',
      template: 'show transaction history',
      tag: '[history]',
      requiresAuth: true,
      priority: 5,
    ),
    
    // Token Risk Commands
    IndexedCommand(
      keywords: ['risk', 'token risk', 'analyze token', 'safe'],
      icon: 'shield',
      label: 'Analyze token risk',
      template: 'analyze token risk',
      tag: '[risk]',
      priority: 5,
    ),
    IndexedCommand(
      keywords: ['risk bonk', 'bonk safe', 'analyze bonk'],
      icon: 'shield',
      label: 'Analyze BONK risk',
      template: 'analyze risk of BONK',
      tag: '[risk]',
      priority: 5,
    ),
    
    // Settings Commands - instant UI
    IndexedCommand(
      keywords: ['settings', 'preferences', 'config'],
      icon: 'settings',
      label: 'Settings',
      template: 'open settings',
      tag: '[settings]',
      priority: 5,
    ),
    IndexedCommand(
      keywords: ['limit', 'set limit', 'transfer limit'],
      icon: 'settings',
      label: 'Set transfer limit',
      template: 'security settings',
      tag: '[security]',
      requiresAuth: true,
      priority: 5,
    ),
    
    // Wallet Management Commands
    IndexedCommand(
      keywords: ['wallet', 'wallets', 'manage wallet', 'my wallets'],
      icon: 'wallet',
      label: 'Manage wallets',
      template: 'manage wallets',
      tag: '[wallet]',
      requiresAuth: true,
      priority: 5,
    ),
    IndexedCommand(
      keywords: ['evm', 'ethereum', 'polygon', 'evm wallet'],
      icon: 'wallet',
      label: 'EVM wallets',
      template: 'manage evm wallets',
      tag: '[wallet]',
      requiresAuth: true,
      priority: 5,
    ),
    
    // Approval History Commands
    IndexedCommand(
      keywords: ['approval', 'approvals', 'approval history', 'past approvals'],
      icon: 'shield',
      label: 'Approval history',
      template: 'show approval history',
      tag: '[approval]',
      requiresAuth: true,
      priority: 5,
    ),
    
    // Command History Commands
    IndexedCommand(
      keywords: ['command history', 'past commands', 'recent commands'],
      icon: 'history',
      label: 'Command history',
      template: 'show command history',
      tag: '[history]',
      requiresAuth: true,
      priority: 5,
    ),
    
    // Analytics Commands
    IndexedCommand(
      keywords: ['analytics', 'activity', 'wallet activity'],
      icon: 'bar_chart',
      label: 'View analytics',
      template: 'show analytics',
      tag: '[analytics]',
      requiresAuth: true,
      priority: 5,
    ),
    
    // Security Commands
    IndexedCommand(
      keywords: ['security', 'limits', 'security settings', 'safety'],
      icon: 'shield',
      label: 'Security settings',
      template: 'open security settings',
      tag: '[security]',
      requiresAuth: true,
      priority: 5,
    ),
    
    // About Commands
    IndexedCommand(
      keywords: ['about', 'help', 'what is ordo', 'info'],
      icon: 'info',
      label: 'About Ordo',
      template: 'about',
      tag: '[about]',
      priority: 5,
    ),
  ];

  /// Search commands based on query
  static List<SuggestionItem> search(String query, {int limit = 5}) {
    if (query.trim().isEmpty) {
      return _getDefaultSuggestions(limit);
    }

    final lowerQuery = query.toLowerCase().trim();
    final results = <_ScoredCommand>[];

    for (final command in _commands) {
      final score = _calculateScore(lowerQuery, command);
      if (score > 0) {
        results.add(_ScoredCommand(command, score));
      }
    }

    // Sort by score (descending)
    results.sort((a, b) => b.score.compareTo(a.score));

    // Convert to SuggestionItems
    return results
        .take(limit)
        .map((scored) => SuggestionItem(
              icon: scored.command.icon,
              label: scored.command.label,
              template: scored.command.template,
              tag: scored.command.tag,
            ))
        .toList();
  }

  /// Get default suggestions when no query (context-aware)
  static List<SuggestionItem> _getDefaultSuggestions(int limit) {
    // TODO: Integrate with ContextService for smart suggestions
    // For now, show diverse commands from different categories
    final categories = <String, List<IndexedCommand>>{};
    
    // Group by category (based on icon/tag)
    for (final cmd in _commands) {
      final category = cmd.tag;
      categories.putIfAbsent(category, () => []);
      categories[category]!.add(cmd);
    }
    
    // Pick one command from each category (round-robin)
    final suggestions = <IndexedCommand>[];
    final categoryKeys = categories.keys.toList()..shuffle();
    
    for (final category in categoryKeys) {
      if (suggestions.length >= limit) break;
      final cmds = categories[category]!;
      if (cmds.isNotEmpty) {
        suggestions.add(cmds.first);
      }
    }
    
    // If still need more, add remaining commands
    if (suggestions.length < limit) {
      final remaining = _commands
          .where((cmd) => !suggestions.contains(cmd))
          .take(limit - suggestions.length);
      suggestions.addAll(remaining);
    }

    return suggestions
        .take(limit)
        .map((cmd) => SuggestionItem(
              icon: cmd.icon,
              label: cmd.label,
              template: cmd.template,
              tag: cmd.tag,
            ))
        .toList();
  }
  
  /// Get context-aware suggestions based on user state
  static List<SuggestionItem> getContextualSuggestions({
    required bool isAuthenticated,
    required double balance,
    String? lastCommand,
    bool hasError = false,
    int limit = 5,
  }) {
    final contextCommands = <IndexedCommand>[];
    
    // Determine context and get relevant commands
    if (hasError && lastCommand != null) {
      // After error: suggest retry + safe commands
      contextCommands.addAll(_commands.where((cmd) => 
        cmd.template == lastCommand ||
        cmd.keywords.contains('balance') ||
        cmd.keywords.contains('price')
      ));
    } else if (lastCommand != null) {
      // After successful command: suggest related actions
      if (lastCommand.contains('balance') || lastCommand.contains('portfolio')) {
        // After balance check: suggest trading actions
        contextCommands.addAll(_commands.where((cmd) =>
          cmd.keywords.contains('swap') ||
          cmd.keywords.contains('send') ||
          cmd.keywords.contains('stake') ||
          cmd.keywords.contains('nft')
        ));
      } else if (lastCommand.contains('swap')) {
        // After swap: suggest balance check, another swap, or history
        contextCommands.addAll(_commands.where((cmd) =>
          cmd.keywords.contains('balance') ||
          cmd.keywords.contains('swap') ||
          cmd.keywords.contains('history')
        ));
      } else if (lastCommand.contains('send')) {
        // After send: suggest balance check or history
        contextCommands.addAll(_commands.where((cmd) =>
          cmd.keywords.contains('balance') ||
          cmd.keywords.contains('history')
        ));
      }
    } else if (!isAuthenticated) {
      // Not logged in: suggest wallet creation and info commands
      contextCommands.addAll(_commands.where((cmd) =>
        cmd.keywords.contains('create') ||
        cmd.keywords.contains('price') ||
        cmd.keywords.contains('chart') ||
        !cmd.requiresAuth
      ));
    } else if (balance <= 0) {
      // Has wallet but no balance: suggest balance check and info
      contextCommands.addAll(_commands.where((cmd) =>
        cmd.keywords.contains('balance') ||
        cmd.keywords.contains('price') ||
        cmd.keywords.contains('portfolio')
      ));
    } else {
      // Has balance: suggest all trading actions
      contextCommands.addAll(_commands.where((cmd) =>
        cmd.requiresAuth &&
        (cmd.keywords.contains('swap') ||
         cmd.keywords.contains('send') ||
         cmd.keywords.contains('stake') ||
         cmd.keywords.contains('nft') ||
         cmd.keywords.contains('balance'))
      ));
    }
    
    // If no contextual commands found, fall back to default
    if (contextCommands.isEmpty) {
      return _getDefaultSuggestions(limit);
    }
    
    // Remove duplicates and take limit
    final uniqueCommands = contextCommands.toSet().toList();
    uniqueCommands.shuffle();
    
    return uniqueCommands
        .take(limit)
        .map((cmd) => SuggestionItem(
              icon: cmd.icon,
              label: cmd.label,
              template: cmd.template,
              tag: cmd.tag,
            ))
        .toList();
  }

  /// Calculate relevance score for a command
  static int _calculateScore(String query, IndexedCommand command) {
    int score = 0;

    for (final keyword in command.keywords) {
      // Exact match = highest score
      if (keyword == query) {
        score += 100;
        continue;
      }

      // Starts with = high score
      if (keyword.startsWith(query)) {
        score += 50;
        continue;
      }

      // Contains = medium score
      if (keyword.contains(query)) {
        score += 25;
        continue;
      }

      // Word boundary match
      final words = keyword.split(' ');
      for (final word in words) {
        if (word.startsWith(query)) {
          score += 30;
        }
      }
    }

    // Add priority bonus
    score += command.priority;

    return score;
  }

  /// Get all commands (for reference)
  static List<IndexedCommand> getAllCommands() {
    return List.unmodifiable(_commands);
  }
}

class _ScoredCommand {
  final IndexedCommand command;
  final int score;

  _ScoredCommand(this.command, this.score);
}
