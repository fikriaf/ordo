import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/token_logo_service.dart';

class TokenHolding {
  final String symbol;
  final String name;
  final double amount;
  final double valueUsd;
  final double changePercent;
  final String? logoUrl;

  TokenHolding({
    required this.symbol,
    required this.name,
    required this.amount,
    required this.valueUsd,
    required this.changePercent,
    this.logoUrl,
  });
}

class PortfolioPanel extends StatelessWidget {
  final double totalValue;
  final double changePercent;
  final List<TokenHolding> holdings;
  final VoidCallback? onRefresh;

  const PortfolioPanel({
    super.key,
    required this.totalValue,
    required this.changePercent,
    required this.holdings,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Total value header
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                'Total Assets',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '\$${totalValue.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontFamily: 'Tomorrow',
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: (changePercent >= 0 ? AppTheme.success : AppTheme.error)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (changePercent >= 0 ? AppTheme.success : AppTheme.error)
                        .withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      changePercent >= 0
                          ? Icons.trending_up
                          : Icons.trending_down,
                      size: 16,
                      color: changePercent >= 0
                          ? AppTheme.success
                          : AppTheme.error,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${changePercent >= 0 ? "+" : ""}${changePercent.toStringAsFixed(2)}%',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontFamily: 'Tomorrow',
                            fontWeight: FontWeight.w700,
                            color: changePercent >= 0
                                ? AppTheme.success
                                : AppTheme.error,
                          ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '7d',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            color: AppTheme.textTertiary,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Holdings list
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surface.withOpacity(0.6),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.05),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'HOLDINGS',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                              letterSpacing: 1.5,
                              color: AppTheme.textTertiary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      if (onRefresh != null)
                        IconButton(
                          onPressed: onRefresh,
                          icon: const Icon(
                            Icons.refresh,
                            size: 20,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                ),
                
                // Token list
                Expanded(
                  child: holdings.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.account_balance_wallet_outlined,
                                size: 48,
                                color: AppTheme.textTertiary,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No tokens found',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: holdings.length,
                          separatorBuilder: (context, index) => Divider(
                            height: 1,
                            color: Colors.white.withOpacity(0.05),
                          ),
                          itemBuilder: (context, index) {
                            final holding = holdings[index];
                            return _buildTokenItem(context, holding);
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTokenItem(BuildContext context, TokenHolding holding) {
    final isPositive = holding.changePercent >= 0;
    
    return InkWell(
      onTap: () {
        // TODO: Show token details
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            // Token logo
            TokenLogoService.buildTokenLogo(
              symbol: holding.symbol,
              size: 40,
              fallbackColor: AppTheme.primary,
              borderColor: AppTheme.primary.withOpacity(0.2),
            ),
            
            const SizedBox(width: 12),
            
            // Token info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    holding.symbol,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${holding.amount.toStringAsFixed(4)} ${holding.symbol}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'Tomorrow',
                          fontSize: 11,
                          color: AppTheme.textTertiary,
                        ),
                  ),
                ],
              ),
            ),
            
            // Value and change
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${holding.valueUsd.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontFamily: 'Tomorrow',
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive
                          ? Icons.arrow_drop_up
                          : Icons.arrow_drop_down,
                      size: 16,
                      color: isPositive ? AppTheme.success : AppTheme.error,
                    ),
                    Text(
                      '${isPositive ? "+" : ""}${holding.changePercent.toStringAsFixed(2)}%',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontFamily: 'Tomorrow',
                            fontSize: 11,
                            color: isPositive ? AppTheme.success : AppTheme.error,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
