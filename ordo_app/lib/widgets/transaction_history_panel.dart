import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';
import '../services/token_logo_service.dart';

class TransactionHistoryPanel extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onDismiss;

  const TransactionHistoryPanel({
    super.key,
    required this.data,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final transactions = (data['transactions'] as List?)?.cast<Map<String, dynamic>>() ?? [];

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
          Container(
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
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.primary.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.history,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '[SCROLL-TEXT] HISTORY',
                        style: TextStyle(
                          color: AppTheme.primary.withOpacity(0.8),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Transaction History',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
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
          ),

          // Content - Scrollable
          Flexible(
            child: transactions.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: transactions.length + 1, // +1 for end indicator
                    itemBuilder: (context, index) {
                      if (index == transactions.length) {
                        return _buildEndIndicator();
                      }

                      final tx = transactions[index];
                      final isFirst = index == 0;
                      final showDateHeader = isFirst || _shouldShowDateHeader(
                        transactions,
                        index,
                      );

                      return Column(
                        children: [
                          if (showDateHeader) ...[
                            if (!isFirst) const SizedBox(height: 16),
                            _buildDateHeader(tx['timestamp']),
                            const SizedBox(height: 12),
                          ],
                          _buildTransactionCard(tx),
                          const SizedBox(height: 12),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history,
              color: AppTheme.textTertiary,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'No transactions yet',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your transaction history will appear here',
              style: TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateHeader(dynamic timestamp) {
    final dateStr = _formatDateHeader(timestamp);
    
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: Colors.white.withOpacity(0.1),
            height: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            dateStr,
            style: TextStyle(
              color: AppTheme.textTertiary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: Colors.white.withOpacity(0.1),
            height: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> tx) {
    final type = tx['type']?.toString() ?? 'unknown';
    final status = tx['status']?.toString() ?? 'confirmed';
    final timestamp = tx['timestamp'];
    
    final icon = _getTransactionIcon(type);
    final title = _getTransactionTitle(tx);
    final subtitle = _getTransactionSubtitle(tx);
    final amount = _getTransactionAmount(tx);
    final isPositive = _isPositiveTransaction(tx);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primary.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    amount,
                    style: TextStyle(
                      color: isPositive ? AppTheme.success : Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Tomorrow',
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildStatusBadge(status),
                ],
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Divider(
              color: Colors.white.withOpacity(0.05),
              height: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatTimestamp(timestamp),
                  style: TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                InkWell(
                  onTap: () {
                    // TODO: Open explorer
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View on Explorer',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.open_in_new,
                          color: AppTheme.textSecondary,
                          size: 12,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final isConfirmed = status.toLowerCase() == 'confirmed';
    final color = isConfirmed ? AppTheme.success : AppTheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEndIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '_',
            style: TextStyle(
              color: AppTheme.primary.withOpacity(0.4),
              fontSize: 12,
              fontFamily: 'Tomorrow',
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'End of transaction log',
            style: TextStyle(
              color: AppTheme.primary.withOpacity(0.4),
              fontSize: 12,
              fontFamily: 'Tomorrow',
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTransactionIcon(String type) {
    switch (type.toLowerCase()) {
      case 'swap':
        return Icons.sync_alt;
      case 'send':
      case 'transfer':
        return Icons.arrow_upward;
      case 'receive':
        return Icons.arrow_downward;
      case 'stake':
        return Icons.account_balance_wallet;
      case 'unstake':
        return Icons.account_balance_wallet_outlined;
      default:
        return Icons.receipt_long;
    }
  }

  String _getTransactionTitle(Map<String, dynamic> tx) {
    final type = tx['type']?.toString() ?? 'Transaction';
    final amount = tx['amount']?.toString() ?? '';
    final token = tx['token']?.toString() ?? tx['symbol']?.toString() ?? '';
    
    switch (type.toLowerCase()) {
      case 'swap':
        final from = tx['from']?.toString() ?? '';
        final to = tx['to']?.toString() ?? '';
        return 'Swap $amount $from to $to';
      case 'send':
      case 'transfer':
        return 'Transfer $amount $token';
      case 'stake':
        return 'Stake $amount $token';
      default:
        return type;
    }
  }

  String _getTransactionSubtitle(Map<String, dynamic> tx) {
    final type = tx['type']?.toString() ?? '';
    
    switch (type.toLowerCase()) {
      case 'swap':
        return 'Via Jupiter Aggregator';
      case 'send':
      case 'transfer':
        final to = tx['to']?.toString() ?? '';
        if (to.isNotEmpty) {
          return 'To: ${to.substring(0, 4)}...${to.substring(to.length - 4)}';
        }
        return 'Transfer';
      case 'stake':
        return tx['validator']?.toString() ?? 'Validator';
      default:
        return 'Confirmed on Mainnet';
    }
  }

  String _getTransactionAmount(Map<String, dynamic> tx) {
    final amount = tx['amount']?.toString() ?? '0';
    final token = tx['token']?.toString() ?? tx['symbol']?.toString() ?? '';
    final type = tx['type']?.toString() ?? '';
    
    final isPositive = _isPositiveTransaction(tx);
    final sign = isPositive ? '+' : '-';
    
    return '$sign$amount $token';
  }

  bool _isPositiveTransaction(Map<String, dynamic> tx) {
    final type = tx['type']?.toString().toLowerCase() ?? '';
    return type == 'receive' || type == 'reward';
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Just now';
    
    try {
      DateTime dateTime;
      if (timestamp is String) {
        dateTime = DateTime.parse(timestamp);
      } else if (timestamp is int) {
        dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else {
        return 'Just now';
      }

      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) return 'Just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24) return '${difference.inHours}h ago';
      if (difference.inDays < 7) return '${difference.inDays}d ago';
      
      return DateFormat('MMM d, yyyy').format(dateTime);
    } catch (e) {
      return 'Just now';
    }
  }

  String _formatDateHeader(dynamic timestamp) {
    if (timestamp == null) return 'TODAY';
    
    try {
      DateTime dateTime;
      if (timestamp is String) {
        dateTime = DateTime.parse(timestamp);
      } else if (timestamp is int) {
        dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else {
        return 'TODAY';
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final txDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

      if (txDate == today) {
        return 'TODAY — ${DateFormat('d MMM yyyy').format(dateTime)}';
      } else if (txDate == yesterday) {
        return 'YESTERDAY';
      } else {
        return DateFormat('d MMM yyyy').format(dateTime).toUpperCase();
      }
    } catch (e) {
      return 'TODAY';
    }
  }

  bool _shouldShowDateHeader(List<Map<String, dynamic>> transactions, int index) {
    if (index == 0) return true;
    
    final current = transactions[index]['timestamp'];
    final previous = transactions[index - 1]['timestamp'];
    
    if (current == null || previous == null) return false;
    
    try {
      DateTime currentDate;
      DateTime previousDate;
      
      if (current is String) {
        currentDate = DateTime.parse(current);
      } else if (current is int) {
        currentDate = DateTime.fromMillisecondsSinceEpoch(current);
      } else {
        return false;
      }
      
      if (previous is String) {
        previousDate = DateTime.parse(previous);
      } else if (previous is int) {
        previousDate = DateTime.fromMillisecondsSinceEpoch(previous);
      } else {
        return false;
      }
      
      return currentDate.day != previousDate.day ||
          currentDate.month != previousDate.month ||
          currentDate.year != previousDate.year;
    } catch (e) {
      return false;
    }
  }
}
