import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SuggestionItem {
  final String icon;
  final String label;
  final String template;
  final String tag;
  final bool needsInput;
  final String? example;

  const SuggestionItem({
    required this.icon,
    required this.label,
    required this.template,
    required this.tag,
    this.needsInput = false,
    this.example,
  });
}

class SuggestionsPanel extends StatelessWidget {
  final List<SuggestionItem> suggestions;
  final Function(SuggestionItem) onSuggestionTap;
  final VoidCallback? onClose;

  const SuggestionsPanel({
    super.key,
    required this.suggestions,
    required this.onSuggestionTap,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.95), // Increased opacity
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1), // More visible border
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4), // Stronger shadow
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with close button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  Icon(
                    Icons.lightbulb_outline,
                    size: 16,
                    color: AppTheme.textTertiary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Suggestions',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  // Close button
                  GestureDetector(
                    onTap: onClose,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Suggestion items - scrollable
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: suggestions.asMap().entries.map((entry) {
                    final index = entry.key;
                    final suggestion = entry.value;
                    final isLast = index == suggestions.length - 1;
                    
                    return _buildSuggestionItem(
                      context,
                      suggestion,
                      isLast,
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionItem(
    BuildContext context,
    SuggestionItem suggestion,
    bool isLast,
  ) {
    return InkWell(
      onTap: () => onSuggestionTap(suggestion),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
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
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getIconData(suggestion.icon),
                size: 20,
                color: AppTheme.primary,
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tag + Label
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: AppTheme.primary.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          suggestion.tag,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          suggestion.label,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Template
                  Text(
                    suggestion.template,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'Tomorrow',
                      color: AppTheme.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 8),
            
            // Arrow icon
            Icon(
              Icons.north_west,
              size: 16,
              color: AppTheme.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'repeat':
      case 'sync_alt':
        return Icons.sync_alt;
      case 'send':
        return Icons.send;
      case 'wallet':
      case 'account_balance_wallet':
        return Icons.account_balance_wallet;
      case 'swap':
        return Icons.swap_horiz;
      case 'stake':
      case 'coins':
        return Icons.savings;
      case 'nft':
      case 'image':
        return Icons.image;
      case 'chart':
      case 'bar_chart':
        return Icons.bar_chart;
      case 'settings':
        return Icons.settings;
      case 'bridge':
        return Icons.compare_arrows;
      case 'lend':
      case 'hand_coins':
        return Icons.handshake;
      case 'liquidity':
      case 'droplet':
        return Icons.water_drop;
      case 'download':
      case 'deposit':
        return Icons.download;
      case 'wallet':
      case 'settings':
      case 'security':
      case 'about':
        return Icons.settings;
      default:
        return Icons.auto_awesome;
    }
  }
}
