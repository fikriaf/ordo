import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PortfolioPanel extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onDismiss;

  const PortfolioPanel({
    super.key,
    required this.data,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    // Extract data safely
    final sol = _extractDouble(data['sol'] ?? data['balance'] ?? data['solBalance']);
    final usdValue = _extractDouble(data['usdValue'] ?? data['totalValue']);
    final tokens = data['tokens'] as List? ?? [];
    
    // Calculate total if not provided
    final totalValue = usdValue > 0 ? usdValue : _calculateTotalValue(sol, tokens);

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
                  child: Icon(
                    Icons.account_balance_wallet_outlined,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Portfolio',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
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

          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Total Value
                Column(
                  children: [
                    Text(
                      'Total Assets',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '\$${totalValue.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Tomorrow',
                        letterSpacing: -1,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Holdings
                Container(
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'HOLDINGS',
                        style: TextStyle(
                          color: AppTheme.textTertiary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // SOL
                      if (sol > 0)
                        _buildAssetRow(
                          icon: Icons.currency_bitcoin,
                          name: 'SOL',
                          amount: sol.toStringAsFixed(4),
                          value: _extractDouble(data['solUsdValue']).toStringAsFixed(2),
                          change: data['solChange']?.toString() ?? '--',
                          isPositive: _extractDouble(data['solChange']) >= 0,
                        ),

                      // Tokens
                      ...tokens.map((token) => Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: _buildAssetRow(
                              icon: Icons.toll,
                              name: token['symbol'] ?? 'TOKEN',
                              amount: (token['amount'] ?? 0).toString(),
                              value: '0.00',
                              change: '0.0%',
                              isPositive: true,
                            ),
                          )),

                      // Empty state
                      if (sol == 0 && tokens.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.account_balance_wallet_outlined,
                                  color: AppTheme.textTertiary,
                                  size: 48,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No assets yet',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // TODO: Implement receive
                        },
                        icon: const Icon(Icons.arrow_downward, size: 18),
                        label: const Text('Receive'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(
                            color: AppTheme.primary.withOpacity(0.3),
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // TODO: Implement send
                        },
                        icon: const Icon(Icons.arrow_upward, size: 18),
                        label: const Text('Send'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetRow({
    required IconData icon,
    required String name,
    required String amount,
    required String value,
    required String change,
    required bool isPositive,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
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
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$amount $name',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$$value',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                fontFamily: 'Tomorrow',
              ),
            ),
            const SizedBox(height: 2),
            Text(
              change,
              style: TextStyle(
                color: isPositive ? AppTheme.success : AppTheme.error,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  double _calculateTotalValue(double sol, List tokens) {
    // Use provided USD value from API, or return 0 if not available
    double total = _extractDouble(data['solUsdValue']);
    // Add token values if available
    for (var token in tokens) {
      total += _extractDouble(token['usdValue']);
    }
    return total;
  }

  double _extractDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
