import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/assistant_controller.dart';
import '../services/auth_service.dart';
import '../widgets/status_strip.dart';
import '../widgets/command_input.dart';
import '../widgets/suggestions_panel.dart';
import '../widgets/context_panels/thinking_panel.dart';
import '../widgets/context_panels/executing_panel.dart';
import '../widgets/context_panels/result_panel.dart';
import '../widgets/context_panels/error_panel.dart';
import '../widgets/portfolio_panel.dart';
import '../widgets/approval_panel.dart';
import '../widgets/swap_panel.dart';
import '../widgets/token_risk_panel.dart';
import '../widgets/transaction_history_panel.dart';
import '../widgets/settings_panel.dart';
import '../widgets/nft_gallery_panel.dart';
import '../widgets/staking_panel.dart';
import '../widgets/unstake_panel.dart';
import '../widgets/lending_panel.dart';
import '../widgets/deposit_panel.dart';
import '../widgets/borrowing_panel.dart';
import '../widgets/liquidity_panel.dart';
import '../widgets/bridge_panel.dart';
import '../widgets/remove_liquidity_panel.dart';
import '../widgets/send_panel.dart';
import '../widgets/wallet_management_panel.dart';
import '../widgets/approval_history_panel.dart';
import '../widgets/ai_response_panel.dart';
import '../widgets/network_settings_panel.dart';
import '../widgets/faucet_panel.dart';
import '../widgets/command_history_panel.dart';
import '../widgets/analytics_panel.dart';
import '../widgets/security_settings_panel.dart';
import '../widgets/price_chart_panel.dart';
import '../services/command_index.dart';
import '../models/command_action.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class CommandScreen extends StatefulWidget {
  const CommandScreen({super.key});

  @override
  State<CommandScreen> createState() => _CommandScreenState();
}

class _CommandScreenState extends State<CommandScreen> {
  final TextEditingController _commandController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<SuggestionItem> _suggestions = [];
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _commandController.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
    _updateSuggestions('');
  }

  @override
  void dispose() {
    _removeOverlay();
    _commandController.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _commandController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    _updateSuggestions(_commandController.text);
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus && _suggestions.isNotEmpty) {
      // Small delay to allow user to see the input first
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_focusNode.hasFocus && _suggestions.isNotEmpty) {
          _showOverlay();
        }
      });
    } else {
      _removeOverlay();
    }
  }

  void _updateSuggestions(String query) {
    setState(() {
      _suggestions = CommandIndexService.search(query, limit: 5);
    });
    
    // Only update overlay if already showing OR if there's a query
    if (_overlayEntry != null && _focusNode.hasFocus) {
      if (_suggestions.isNotEmpty) {
        _showOverlay();
      } else {
        _removeOverlay();
      }
    }
  }

  void _showOverlay() {
    _removeOverlay(); // Remove old overlay first
    
    _overlayEntry = OverlayEntry(
      builder: (context) {
        // Get keyboard height
        final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
        // Input area height (CommandInput + bottom padding)
        const inputAreaHeight = 80.0;
        final screenHeight = MediaQuery.of(context).size.height;
        // Max height for suggestions (50% of available space)
        final maxSuggestionsHeight = (screenHeight - keyboardHeight - inputAreaHeight - 100) * 0.6;
        
        return Positioned(
          left: 0,
          right: 0,
          // Don't cover the input area at the bottom
          bottom: keyboardHeight + inputAreaHeight + 16, // Above input area
          top: 0,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: () {
                _removeOverlay();
                _focusNode.unfocus();
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Suggestions panel at the bottom of this area
                    GestureDetector(
                      onTap: () {}, // Prevent tap through
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: maxSuggestionsHeight.clamp(150.0, 400.0),
                        ),
                        child: SuggestionsPanel(
                          suggestions: _suggestions,
                          onSuggestionTap: (template) {
                            _removeOverlay();
                            _onSuggestionTap(template);
                          },
                          onClose: () {
                            _removeOverlay();
                            _focusNode.unfocus();
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _onSuggestionTap(String template) {
    // DIRECTLY execute command - don't just fill input!
    final controller = Provider.of<AssistantController>(context, listen: false);
    controller.processCommand(template);
    _focusNode.unfocus();
  }

  void _handleSubmit(AssistantController controller) {
    final command = _commandController.text.trim();
    if (command.isNotEmpty) {
      controller.processCommand(command);
      _commandController.clear();
      _focusNode.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    
    return Scaffold(
      body: SafeArea(
        child: Consumer<AssistantController>(
          builder: (context, controller, child) {
            // Suggestions are handled by Overlay, not in build tree!
            
            return Column(
              children: [
                // Status strip with menu
                Row(
                  children: [
                    Expanded(
                      child: StatusStrip(
                        state: controller.state,
                        isGuest: !authService.isAuthenticated,
                      ),
                    ),
                    // Menu button
                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () => _showMenu(context, authService),
                    ),
                  ],
                ),
                
                // Main area with background
                Expanded(
                  child: Stack(
                    children: [
                      // Background decoration
                      Positioned.fill(
                        child: _buildBackground(),
                      ),
                      
                      // Main content
                      Positioned.fill(
                        child: _buildStateContent(controller),
                      ),
                    ],
                  ),
                ),
                
                // Command input (always at bottom)
                CommandInput(
                  controller: _commandController,
                  focusNode: _focusNode,
                  isLoading: controller.isLoading,
                  state: controller.state,
                  onSubmit: () => _handleSubmit(controller),
                  onVoiceInput: controller.startVoiceInput,
                ),
                
                const SizedBox(height: 16),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showMenu(BuildContext context, AuthService authService) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            
            // User info
            if (authService.isAuthenticated) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authService.user?['username'] ?? 'User',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          authService.user?['email'] ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 32),
            ],
            
            // Menu items
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About'),
              onTap: () {
                Navigator.pop(context);
                _showAbout(context);
              },
            ),
            
            if (authService.isAuthenticated)
              ListTile(
                leading: const Icon(Icons.logout, color: AppTheme.error),
                title: const Text('Logout', style: TextStyle(color: AppTheme.error)),
                onTap: () async {
                  await authService.logout();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  }
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.login, color: AppTheme.primary),
                title: const Text('Login'),
                onTap: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
              ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('About Ordo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Version 1.0.0'),
            const SizedBox(height: 16),
            Text(
              'Your Solana DeFi Assistant',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            Text(
              'Made by Daemon BlockInt Technologies',
              style: TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Stack(
      children: [
        // Grid pattern
        Positioned.fill(
          child: CustomPaint(
            painter: GridPatternPainter(),
          ),
        ),
        // Gradient glow
        Positioned(
          top: -100,
          left: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppTheme.primary.withOpacity(0.1),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStateContent(AssistantController controller) {
    switch (controller.state) {
      case AssistantState.idle:
        return _buildIdleState();
      
      case AssistantState.listening:
        return _buildListeningState();
      
      case AssistantState.thinking:
        return ThinkingPanel(
          processSteps: controller.processSteps,
          progress: controller.progress,
          currentPhase: controller.currentPhase,
          command: controller.currentCommand,
        );
      
      case AssistantState.executing:
        return ThinkingPanel(
          processSteps: controller.processSteps,
          progress: controller.progress,
          currentPhase: controller.currentPhase,
          command: controller.currentCommand,
        );
      
      case AssistantState.completing:
        return ThinkingPanel(
          processSteps: controller.processSteps,
          progress: controller.progress,
          currentPhase: controller.currentPhase,
          command: controller.currentCommand,
          completionSummary: controller.completionSummary,
          isCompleting: true,
        );
      
      case AssistantState.showingPanel:
        return _buildActionPanel(controller);
      
      case AssistantState.error:
        return ErrorPanel(
          error: controller.error ?? 'Unknown error',
          onRetry: () {
            controller.processCommand(controller.currentCommand);
          },
          onDismiss: () {
            controller.reset();
          },
        );
    }
  }

  Widget _buildActionPanel(AssistantController controller) {
    final action = controller.currentAction;
    if (action == null) return _buildIdleState();

    // Wrap in scrollable container to prevent overflow
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: _buildPanelContent(action, controller),
    );
  }

  Widget _buildPanelContent(CommandAction action, AssistantController controller) {
    switch (action.type) {
      case ActionType.checkBalance:
      case ActionType.showPortfolio:
        return PortfolioPanel(
          data: action.data,
          onDismiss: () => controller.dismissPanel(),
        );
      
      case ActionType.swapTokens:
      case ActionType.getSwapQuote:
        return SwapPanel(
          data: action.data,
          onDismiss: () => controller.dismissPanel(),
        );
      
      case ActionType.tokenRisk:
        return TokenRiskPanel(
          data: action.data,
          onDismiss: () => controller.dismissPanel(),
        );
      
      case ActionType.showTransactions:
        return TransactionHistoryPanel(
          data: action.data,
          onDismiss: () => controller.dismissPanel(),
        );
      
      case ActionType.showPreferences:
      case ActionType.setLimit:
      case ActionType.setSlippage:
        return SettingsPanel(
          data: action.data,
          onDismiss: () => controller.dismissPanel(),
        );
      
      case ActionType.requiresApproval:
        return ApprovalPanel(
          command: controller.currentCommand,
          amount: action.data['amount']?.toString() ?? '0',
          usdValue: action.data['usdValue']?.toString() ?? '0',
          reason: action.data['reason']?.toString() ?? 'Exceeds limit',
          agentReasoning: action.data['reasoning']?.toString() ?? 'Safety check required',
          onApprove: () {
            // TODO: Implement approval
            controller.dismissPanel();
          },
          onReject: () {
            controller.dismissPanel();
          },
        );
      
      // Info responses - show compact summary only
      case ActionType.info:
        return _buildInfoPanel(
          action.data['summary'] ?? 'Command processed',
          controller,
        );
      
      // NFT Gallery - show placeholder for now
      case ActionType.showNfts:
        return NftGalleryPanel(
          data: action.data,
          onDismiss: () => controller.dismissPanel(),
        );
      
      // Mint NFT - show NFT gallery with mint action
      case ActionType.mintNft:
        return NftGalleryPanel(
          data: {...action.data, 'autoAction': 'mint'},
          onDismiss: () => controller.dismissPanel(),
        );
      
      // Send NFT - show NFT gallery with send action
      case ActionType.sendNft:
        return NftGalleryPanel(
          data: {...action.data, 'autoAction': 'send'},
          onDismiss: () => controller.dismissPanel(),
        );
      
      // Staking interface - show placeholder
      case ActionType.stake:
        return StakingPanel(
          data: action.data,
          onDismiss: () => controller.dismissPanel(),
        );
      
      // Unstaking interface
      case ActionType.unstake:
        return UnstakePanel(
          data: action.data,
          onDismiss: () => controller.dismissPanel(),
        );
      
      // Lending interface - show placeholder
      case ActionType.lend:
        return LendingPanel(
          data: action.data,
          onDismiss: () => controller.dismissPanel(),
        );
      
      // Borrowing interface - show placeholder
      case ActionType.borrow:
        return BorrowingPanel(
          data: action.data,
          onDismiss: () => controller.dismissPanel(),
        );
      
      // Liquidity interface - show placeholder
      case ActionType.addLiquidity:
        return LiquidityPanel(
          data: action.data,
          onDismiss: () => controller.dismissPanel(),
        );
      
      // Remove Liquidity interface
      case ActionType.removeLiquidity:
        return RemoveLiquidityPanel(
          data: action.data,
          onDismiss: () => controller.dismissPanel(),
        );
      
      // Bridge interface - show placeholder
      case ActionType.bridge:
        return BridgePanel(
          data: action.data,
          onDismiss: () => controller.dismissPanel(),
        );
      
      // Wallet management interface
      case ActionType.manageWallets:
      case ActionType.manageEvmWallets:
      case ActionType.createWallet:
      case ActionType.importWallet:
      case ActionType.switchWallet:
      case ActionType.deleteWallet:
        return WalletManagementPanel(
          data: action.data,
          initialTab: action.type == ActionType.manageEvmWallets ? 1 : 0,
          onDismiss: () => controller.dismissPanel(),
        );
      
      // Approval history interface
      case ActionType.showApprovalHistory:
        return ApprovalHistoryPanel(
          data: action.data,
          onDismiss: () => controller.dismissPanel(),
        );
      
      // Command history panel
      case ActionType.showCommandHistory:
        return CommandHistoryPanel(
          data: action.data,
          onDismiss: () => controller.dismissPanel(),
        );
      
      // Analytics panel
      case ActionType.showAnalytics:
      case ActionType.showActivity:
        return AnalyticsPanel(
          data: action.data,
          onDismiss: () => controller.dismissPanel(),
        );
      
      // Security settings panel
      case ActionType.showSecuritySettings:
        return SecuritySettingsPanel(
          data: action.data,
          onDismiss: () => controller.dismissPanel(),
        );
      
      // About panel
      case ActionType.showAbout:
        return _buildAboutPanel(controller);
      
      // Price chart panel
      case ActionType.showPriceChart:
        return PriceChartPanel(
          data: action.data,
          onDismiss: () => controller.dismissPanel(),
        );
      
      // Token price/info - show AI response panel
      case ActionType.tokenPrice:
      case ActionType.tokenInfo:
        return AIResponsePanel(
          action: action,
          onDismiss: () => controller.dismissPanel(),
        );
      
      // Send/Transfer - show send panel
      case ActionType.sendSol:
      case ActionType.sendToken:
        return SendPanel(
          data: action.data,
          onDismiss: () => controller.dismissPanel(),
        );
      
      // Deposit - show deposit panel
      case ActionType.deposit:
        return DepositPanel(
          data: action.data,
          onDismiss: () => controller.dismissPanel(),
        );
      
      // Network settings panel
      case ActionType.networkSettings:
        return NetworkSettingsPanel(
          data: action.data,
          onDismiss: () => controller.dismissPanel(),
        );
      
      // Faucet panel
      case ActionType.faucet:
        return FaucetPanel(
          data: action.data,
          onDismiss: () => controller.dismissPanel(),
        );
      
      // Generic info response - use AI response panel for unhandled types
      case ActionType.info:
      case ActionType.unknown:
      case ActionType.error:
      case _:
        return AIResponsePanel(
          action: action,
          onDismiss: () => controller.dismissPanel(),
        );
    }
  }

  Widget _buildInfoPanel(String message, AssistantController controller) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            color: AppTheme.success,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () => controller.dismissPanel(),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderPanel(
    String title,
    String description,
    String iconName,
    AssistantController controller,
  ) {
    // Map icon names to IconData
    final iconMap = {
      'gallery': Icons.photo_library,
      'coins': Icons.account_balance_wallet,
      'hand_coins': Icons.monetization_on,
      'droplet': Icons.water_drop,
      'bridge': Icons.swap_horiz,
    };
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Icon(
                iconMap[iconName] ?? Icons.info_outline,
                color: AppTheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => controller.dismissPanel(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Placeholder content
          Icon(
            iconMap[iconName] ?? Icons.info_outline,
            color: AppTheme.primary.withOpacity(0.3),
            size: 80,
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Coming soon',
            style: TextStyle(
              color: AppTheme.primary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          
          // Action button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => controller.dismissPanel(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Got it',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutPanel(AssistantController controller) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.terminal,
                  color: AppTheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ORDO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    'AI DeFi Assistant',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => controller.dismissPanel(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Version info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.textSecondary, size: 20),
                SizedBox(width: 12),
                Text('Version', style: TextStyle(color: AppTheme.textSecondary)),
                Spacer(),
                Text('1.0.0', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          
          // Features
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Features',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _buildFeatureItem(Icons.swap_horiz, 'Token Swaps', 'Swap any SPL token with best rates'),
                _buildFeatureItem(Icons.account_balance_wallet, 'Multi-Wallet', 'Manage Solana & EVM wallets'),
                _buildFeatureItem(Icons.savings, 'DeFi', 'Stake, lend, borrow, and more'),
                _buildFeatureItem(Icons.photo_library, 'NFTs', 'View and manage your NFT collection'),
                _buildFeatureItem(Icons.shield, 'Security', 'Approval system and transaction limits'),
                _buildFeatureItem(Icons.mic, 'Voice Commands', 'Control with natural language'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Footer
          Text(
            'Made by Daemon BlockInt Technologies',
            style: TextStyle(
              color: AppTheme.textTertiary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          
          // Close button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => controller.dismissPanel(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Close',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdleState() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Don't expand!
          children: [
            const SizedBox(height: 100), // Top spacing
            
            // App identity
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.primary.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.terminal,
                size: 48,
                color: AppTheme.primary,
              ),
            ),
            
            const SizedBox(height: 16),
            
            Text(
              'ORDO',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              'Your Solana DeFi Assistant',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textTertiary,
              ),
            ),
            
            const SizedBox(height: 48),
            
            // Quick suggestions
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildSuggestionChip('Check my balance'),
                _buildSuggestionChip('Swap 1 SOL to USDC'),
                _buildSuggestionChip('Show my NFTs'),
                _buildSuggestionChip('What\'s SOL price?'),
              ],
            ),
            
            const SizedBox(height: 200), // Bottom spacing for suggestions panel
          ],
        ),
      ),
    );
  }

  Widget _buildListeningState() {
    final controller = Provider.of<AssistantController>(context, listen: false);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Pulsing mic icon
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.8, end: 1.2),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeInOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.success.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.mic,
                    size: 48,
                    color: AppTheme.success,
                  ),
                ),
              );
            },
            onEnd: () {
              // Loop animation
              setState(() {});
            },
          ),
          
          const SizedBox(height: 24),
          
          Text(
            'Listening...',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          
          const SizedBox(height: 8),
          
          // Show partial voice input
          if (controller.partialVoiceInput.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                controller.partialVoiceInput,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.primary,
                      fontStyle: FontStyle.italic,
                    ),
                textAlign: TextAlign.center,
              ),
            )
          else
            Text(
              'Speak your command',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          
          const SizedBox(height: 32),
          
          // Cancel button
          TextButton(
            onPressed: () {
              controller.cancelVoiceInput();
            },
            child: Text(
              'Cancel',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String label) {
    return InkWell(
      onTap: () {
        // DIRECTLY execute command - don't just fill input!
        final controller = Provider.of<AssistantController>(context, listen: false);
        controller.processCommand(label);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surface.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.05),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

class GridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primary.withOpacity(0.03)
      ..strokeWidth = 1;

    const spacing = 24.0;

    // Draw vertical lines
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // Draw horizontal lines
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
