import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../theme/app_theme.dart';
import '../models/command_action.dart';

/// Unified AI Response Panel that displays results from AI commands
/// Adapts its display based on the action type and structured data
class AIResponsePanel extends StatelessWidget {
  final CommandAction action;
  final VoidCallback onDismiss;

  const AIResponsePanel({
    super.key,
    required this.action,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    // Use conversational layout for info/unknown types
    if (action.type == ActionType.info || action.type == ActionType.unknown) {
      return _buildConversationalLayout(context);
    }
    
    // Use structured layout for specific action types
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          _buildHeader(),
          
          // Content based on action type
          _buildContent(context),
          
          // Footer with tools used
          if (action.toolsUsed != null && action.toolsUsed!.isNotEmpty)
            _buildToolsFooter(),
        ],
      ),
    );
  }

  /// Conversational chat-like layout for info/Q&A responses
  Widget _buildConversationalLayout(BuildContext context) {
    final isError = action.status == 'error';
    final displayText = action.rawMessage ?? action.summary ?? 'No response';
    
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isError 
              ? AppTheme.error.withOpacity(0.3)
              : Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Minimal header with AI indicator and close button
          _buildConversationalHeader(isError),
          
          // Main content with markdown rendering
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Markdown content
                  MarkdownBody(
                    data: displayText,
                    selectable: true,
                    styleSheet: _buildMarkdownStyleSheet(context, isError),
                    onTapLink: (text, href, title) {
                      if (href != null) {
                        _copyToClipboard(href);
                      }
                    },
                  ),
                  
                  // Tools used indicator (subtle)
                  if (action.toolsUsed != null && action.toolsUsed!.isNotEmpty)
                    _buildToolsIndicator(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Minimal header for conversational responses
  Widget _buildConversationalHeader(bool isError) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.05),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // AI avatar/indicator
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isError 
                    ? [AppTheme.error.withOpacity(0.8), AppTheme.error]
                    : [AppTheme.primary.withOpacity(0.8), AppTheme.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          
          // "Ordo" label
          Text(
            'Ordo',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          
          const Spacer(),
          
          // Close button
          IconButton(
            onPressed: onDismiss,
            icon: Icon(
              Icons.close,
              color: AppTheme.textSecondary,
              size: 20,
            ),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  /// Subtle tools indicator for conversational layout
  Widget _buildToolsIndicator() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          Icon(
            Icons.memory,
            color: AppTheme.textTertiary,
            size: 12,
          ),
          const SizedBox(width: 6),
          Text(
            'Used: ${action.toolsUsed!.map((t) => _formatToolName(t)).take(2).join(', ')}${action.toolsUsed!.length > 2 ? ' +${action.toolsUsed!.length - 2}' : ''}',
            style: TextStyle(
              color: AppTheme.textTertiary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  /// Build markdown stylesheet for conversational responses
  MarkdownStyleSheet _buildMarkdownStyleSheet(BuildContext context, bool isError) {
    final textColor = isError ? AppTheme.error : Colors.white;
    
    return MarkdownStyleSheet(
      // Paragraphs
      p: TextStyle(
        color: textColor.withOpacity(0.95),
        fontSize: 15,
        height: 1.5,
      ),
      
      // Bold
      strong: TextStyle(
        color: textColor,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
      
      // Italic
      em: TextStyle(
        color: textColor.withOpacity(0.9),
        fontSize: 15,
        fontStyle: FontStyle.italic,
      ),
      
      // Headers
      h1: TextStyle(
        color: textColor,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.4,
      ),
      h2: TextStyle(
        color: textColor,
        fontSize: 19,
        fontWeight: FontWeight.w700,
        height: 1.4,
      ),
      h3: TextStyle(
        color: textColor,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      
      // Lists
      listBullet: TextStyle(
        color: AppTheme.primary,
        fontSize: 15,
      ),
      listIndent: 20.0,
      
      // Code
      code: TextStyle(
        color: AppTheme.primary,
        fontSize: 13,
        fontFamily: 'monospace',
        backgroundColor: Colors.black.withOpacity(0.3),
      ),
      codeblockDecoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      codeblockPadding: const EdgeInsets.all(12),
      
      // Links
      a: TextStyle(
        color: AppTheme.primary,
        decoration: TextDecoration.underline,
      ),
      
      // Blockquote
      blockquote: TextStyle(
        color: textColor.withOpacity(0.8),
        fontSize: 15,
        fontStyle: FontStyle.italic,
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: AppTheme.primary.withOpacity(0.5),
            width: 3,
          ),
        ),
      ),
      blockquotePadding: const EdgeInsets.only(left: 12),
      
      // Horizontal rule
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      
      // Table
      tableHead: TextStyle(
        color: textColor,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      tableBody: TextStyle(
        color: textColor.withOpacity(0.9),
        fontSize: 14,
      ),
      tableBorder: TableBorder.all(
        color: Colors.white.withOpacity(0.1),
        width: 1,
      ),
      tableColumnWidth: const FlexColumnWidth(),
      tableCellsPadding: const EdgeInsets.all(8),
    );
  }

  Widget _buildHeader() {
    final isError = action.status == 'error';
    final color = isError ? AppTheme.error : AppTheme.primary;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.05),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Icon(
              _getIcon(),
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          
          // Title and status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (action.status != null && action.status != 'success')
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      _getStatusText(),
                      style: TextStyle(
                        color: _getStatusColor(),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Close button
          IconButton(
            onPressed: onDismiss,
            icon: Icon(
              Icons.close,
              color: AppTheme.textSecondary,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary
          if (action.summary != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: action.status == 'error' 
                    ? AppTheme.error.withOpacity(0.1)
                    : AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: action.status == 'error'
                      ? AppTheme.error.withOpacity(0.2)
                      : AppTheme.primary.withOpacity(0.2),
                ),
              ),
              child: Text(
                action.summary!,
                style: TextStyle(
                  color: action.status == 'error' ? AppTheme.error : Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          
          // Structured details OR raw message if no structured data
          _buildDetails(),
          
          // If no structured data but has rawMessage, show it with markdown
          if (action.data.isEmpty && action.rawMessage != null && action.rawMessage!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
              child: MarkdownBody(
                data: action.rawMessage!,
                selectable: true,
                styleSheet: _buildMarkdownStyleSheet(context, action.status == 'error'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetails() {
    final data = action.data;
    
    if (data.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // Build different layouts based on action type
    switch (action.type) {
      case ActionType.checkBalance:
      case ActionType.showPortfolio:
        return _buildBalanceDetails();
      
      case ActionType.createWallet:
      case ActionType.manageEvmWallets:
        return _buildWalletDetails();
      
      case ActionType.tokenPrice:
        return _buildPriceDetails();
      
      case ActionType.tokenRisk:
        return _buildRiskDetails();
      
      case ActionType.swapTokens:
      case ActionType.getSwapQuote:
        return _buildSwapDetails();
      
      case ActionType.sendSol:
      case ActionType.sendToken:
        return _buildTransferDetails();
        
      default:
        return _buildGenericDetails();
    }
  }

  Widget _buildBalanceDetails() {
    final data = action.data;
    final sol = _extractDouble(data['sol'] ?? data['balance']);
    final usdValue = _extractDouble(data['usdValue']);
    final tokens = data['tokens'] as List? ?? [];
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
      ),
      child: Column(
        children: [
          if (sol > 0) ...[
            _buildDetailRow('SOL Balance', '${sol.toStringAsFixed(4)} SOL'),
            const SizedBox(height: 8),
          ],
          if (usdValue > 0) ...[
            _buildDetailRow('USD Value', '\$${usdValue.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
          ],
          if (tokens.isNotEmpty)
            ...tokens.map((t) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _buildDetailRow(
                t['symbol'] ?? 'Token',
                '${t['amount'] ?? 0}',
              ),
            )),
        ],
      ),
    );
  }

  Widget _buildWalletDetails() {
    final data = action.data;
    final address = data['address'] ?? data['wallet']?['address'];
    final chain = data['chain'];
    final wallets = data['wallets'] as List?;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (address != null) ...[
            Text(
              'Address',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => _copyToClipboard(address.toString()),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _shortenAddress(address.toString()),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  Icon(
                    Icons.copy,
                    color: AppTheme.textTertiary,
                    size: 16,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (chain != null)
            _buildDetailRow('Chain', chain.toString().toUpperCase()),
          
          // Multiple wallets
          if (wallets != null && wallets.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'WALLETS CREATED',
              style: TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            ...wallets.map((w) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _buildWalletItem(w),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildWalletItem(Map<String, dynamic> wallet) {
    final chain = wallet['chain'] ?? 'unknown';
    final address = wallet['address'] ?? '';
    
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.account_balance_wallet,
            color: AppTheme.primary,
            size: 16,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                chain.toString().toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _shortenAddress(address.toString()),
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => _copyToClipboard(address.toString()),
          icon: Icon(
            Icons.copy,
            color: AppTheme.textTertiary,
            size: 16,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  Widget _buildPriceDetails() {
    final data = action.data;
    final price = _extractDouble(data['price']);
    final change24h = _extractDouble(data['change24h']);
    final prices = data['prices'] as Map?;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
      ),
      child: Column(
        children: [
          if (price > 0) ...[
            Text(
              '\$${price.toStringAsFixed(price < 1 ? 6 : 2)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w700,
                fontFamily: 'Tomorrow',
              ),
            ),
            if (change24h != 0)
              Text(
                '${change24h >= 0 ? '+' : ''}${change24h.toStringAsFixed(2)}%',
                style: TextStyle(
                  color: change24h >= 0 ? AppTheme.success : AppTheme.error,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
          if (prices != null && prices.isNotEmpty)
            ...prices.entries.map((e) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _buildDetailRow(e.key, '\$${e.value}'),
            )),
        ],
      ),
    );
  }

  Widget _buildRiskDetails() {
    final data = action.data;
    final riskScore = data['riskScore'] ?? data['score'];
    final riskLevel = data['riskLevel'] ?? data['level'];
    final warnings = data['warnings'] as List? ?? [];
    
    final level = riskLevel?.toString().toLowerCase() ?? 'unknown';
    final color = level == 'low' ? AppTheme.success 
                : level == 'medium' ? Colors.orange 
                : level == 'high' ? AppTheme.error 
                : AppTheme.textSecondary;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                level == 'low' ? Icons.check_circle
                    : level == 'medium' ? Icons.warning
                    : level == 'high' ? Icons.dangerous
                    : Icons.help,
                color: color,
                size: 32,
              ),
              const SizedBox(width: 12),
              Text(
                level.toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (riskScore != null) ...[
            const SizedBox(height: 8),
            Text(
              'Score: $riskScore',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
          if (warnings.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...warnings.map((w) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      w.toString(),
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildSwapDetails() {
    final data = action.data;
    final fromToken = data['fromToken'];
    final toToken = data['toToken'];
    final amount = data['amount'];
    final quote = data['quote'];
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
      ),
      child: Column(
        children: [
          if (fromToken != null && toToken != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  fromToken.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Icon(
                    Icons.arrow_forward,
                    color: AppTheme.primary,
                    size: 24,
                  ),
                ),
                Text(
                  toToken.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          if (amount != null) ...[
            const SizedBox(height: 12),
            _buildDetailRow('Amount', amount.toString()),
          ],
          if (quote != null) ...[
            const SizedBox(height: 8),
            _buildDetailRow('Quote', quote.toString()),
          ],
        ],
      ),
    );
  }

  Widget _buildTransferDetails() {
    final data = action.data;
    final signature = data['signature'] ?? data['txHash'];
    final amount = data['amount'];
    final recipient = data['recipient'] ?? data['to'];
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
      ),
      child: Column(
        children: [
          if (action.status == 'success')
            Icon(
              Icons.check_circle,
              color: AppTheme.success,
              size: 48,
            ),
          if (amount != null) ...[
            const SizedBox(height: 12),
            _buildDetailRow('Amount', amount.toString()),
          ],
          if (recipient != null) ...[
            const SizedBox(height: 8),
            _buildDetailRow('To', _shortenAddress(recipient.toString())),
          ],
          if (signature != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _copyToClipboard(signature.toString()),
              child: _buildDetailRow(
                'Tx',
                '${_shortenAddress(signature.toString())} ',
                trailing: Icon(Icons.copy, size: 14, color: AppTheme.textTertiary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGenericDetails() {
    final data = action.data;
    
    if (data.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // Filter out internal fields
    final displayData = Map<String, dynamic>.from(data)
      ..removeWhere((key, value) => 
        key.startsWith('_') || 
        key == 'success' ||
        value == null
      );
    
    if (displayData.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
      ),
      child: Column(
        children: displayData.entries.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildDetailRow(
            _formatKey(e.key),
            _formatValue(e.value),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Widget? trailing}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 4),
              trailing,
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildToolsFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.05),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.build_outlined,
            color: AppTheme.textTertiary,
            size: 14,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              action.toolsUsed!.map((t) => _formatToolName(t)).join(', '),
              style: TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  IconData _getIcon() {
    switch (action.type) {
      case ActionType.checkBalance:
      case ActionType.showPortfolio:
        return Icons.account_balance_wallet_outlined;
      case ActionType.tokenInfo:
        return Icons.info_outlined;
      case ActionType.tokenRisk:
        return Icons.security_outlined;
      case ActionType.tokenPrice:
        return Icons.trending_up;
      case ActionType.sendSol:
      case ActionType.sendToken:
        return Icons.send_outlined;
      case ActionType.swapTokens:
      case ActionType.getSwapQuote:
        return Icons.swap_horiz;
      case ActionType.stake:
        return Icons.savings_outlined;
      case ActionType.createWallet:
      case ActionType.manageEvmWallets:
        return Icons.add_card_outlined;
      case ActionType.showNfts:
        return Icons.collections_outlined;
      case ActionType.showTransactions:
        return Icons.history;
      case ActionType.error:
        return Icons.error_outline;
      default:
        return Icons.chat_outlined;
    }
  }

  String _getStatusText() {
    switch (action.status) {
      case 'error':
        return 'Failed';
      case 'pending':
        return 'Pending...';
      case 'requires_approval':
        return 'Requires approval';
      default:
        return action.status ?? '';
    }
  }

  Color _getStatusColor() {
    switch (action.status) {
      case 'error':
        return AppTheme.error;
      case 'pending':
        return Colors.orange;
      case 'requires_approval':
        return Colors.amber;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _shortenAddress(String address) {
    if (address.length <= 12) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  String _formatKey(String key) {
    // Convert camelCase to Title Case
    return key
        .replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(1)}')
        .replaceAll('_', ' ')
        .trim()
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  String _formatValue(dynamic value) {
    if (value == null) return '-';
    if (value is Map || value is List) return '...';
    return value.toString();
  }

  String _formatToolName(String toolName) {
    // Remove prefixes like 'mcp__' and format
    return toolName
        .replaceAll(RegExp(r'^[a-z]+__'), '')
        .replaceAll('_', ' ')
        .trim();
  }

  double _extractDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
  }
}
