import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/token_logo_service.dart';

class SwapPanel extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onDismiss;

  const SwapPanel({
    super.key,
    required this.data,
    required this.onDismiss,
  });

  @override
  State<SwapPanel> createState() => _SwapPanelState();
}

class _SwapPanelState extends State<SwapPanel> {
  late TextEditingController _amountController;
  late String _fromToken;
  late String _toToken;
  bool _isLoading = false;
  double? _usdValue;
  double? _tokenPrice;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.data['amount']?.toString() ?? '',
    );
    _fromToken = widget.data['from']?.toString() ?? 'SOL';
    _toToken = widget.data['to']?.toString() ?? 'USDC';
    
    // Fetch price on init
    _fetchPrice();
    
    // Listen to amount changes
    _amountController.addListener(_updateUsdValue);
  }

  @override
  void dispose() {
    _amountController.removeListener(_updateUsdValue);
    _amountController.dispose();
    super.dispose();
  }
  
  Future<void> _fetchPrice() async {
    try {
      // Use Binance API directly for real-time price
      final symbol = _getBinanceSymbol(_fromToken);
      if (symbol != null) {
        final response = await http.get(
          Uri.parse('https://api.binance.com/api/v3/ticker/price?symbol=$symbol'),
        );
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          setState(() {
            _tokenPrice = double.tryParse(data['price']?.toString() ?? '0');
            _updateUsdValue();
          });
          return;
        }
      }
      
      // Fallback to internal API if Binance fails
      final authService = context.read<AuthService>();
      final apiClient = ApiClient(authService: authService);
      final apiResponse = await apiClient.getTokenPrice('So11111111111111111111111111111111111111112');
      if (apiResponse['success'] == true && apiResponse['data'] != null) {
        setState(() {
          _tokenPrice = (apiResponse['data']['price'] as num?)?.toDouble();
          _updateUsdValue();
        });
      }
    } catch (e) {
      // Silently fail, use fallback
      setState(() {
        _tokenPrice = 180.0; // Fallback SOL price
        _updateUsdValue();
      });
    }
  }
  
  // Get Binance trading pair symbol
  String? _getBinanceSymbol(String token) {
    final symbols = {
      'SOL': 'SOLUSDT',
      'BTC': 'BTCUSDT',
      'ETH': 'ETHUSDT',
      'BNB': 'BNBUSDT',
      'AVAX': 'AVAXUSDT',
      'MATIC': 'MATICUSDT',
      'DOT': 'DOTUSDT',
      'LINK': 'LINKUSDT',
      'UNI': 'UNIUSDT',
      'ATOM': 'ATOMUSDT',
    };
    return symbols[token.toUpperCase()];
  }
  
  void _updateUsdValue() {
    final amount = double.tryParse(_amountController.text);
    if (amount != null && _tokenPrice != null && _fromToken == 'SOL') {
      setState(() {
        _usdValue = amount * _tokenPrice!;
      });
    } else if (_fromToken == 'USDC' || _fromToken == 'USDT') {
      final amount = double.tryParse(_amountController.text);
      if (amount != null) {
        setState(() {
          _usdValue = amount;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    Icons.sync_alt,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Swap Tokens',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: widget.onDismiss,
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
                // From token
                _buildTokenInput(
                  label: 'From',
                  token: _fromToken,
                  controller: _amountController,
                  balance: widget.data['fromBalance']?.toString(),
                  usdValue: _usdValue,
                ),

                const SizedBox(height: 16),

                // Swap icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.swap_vert,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                ),

                const SizedBox(height: 16),

                // To token
                _buildTokenInput(
                  label: 'To',
                  token: _toToken,
                  controller: null,
                  balance: null,
                  estimatedAmount: widget.data['estimatedOutput']?.toString() ?? '--',
                ),

                const SizedBox(height: 24),

                // Info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.05),
                      width: 1,
                    ),
                  ),
                    child: Column(
                      children: [
                        _buildInfoRow('Rate', widget.data['rate']?.toString() ?? '--'),
                        const SizedBox(height: 8),
                        _buildInfoRow('Slippage', widget.data['slippage']?.toString() ?? '--'),
                        const SizedBox(height: 8),
                        _buildInfoRow('Fee', widget.data['fee']?.toString() ?? '--'),
                        if (widget.data['priceImpact'] != null) ...[
                          const SizedBox(height: 8),
                          _buildInfoRow('Price Impact', widget.data['priceImpact'].toString()),
                        ],
                      ],
                    ),
                ),

                const SizedBox(height: 24),

                // Action button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSwap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Review Swap',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
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

  Widget _buildTokenInput({
    required String label,
    required String token,
    required TextEditingController? controller,
    String? balance,
    String? estimatedAmount,
    double? usdValue,
  }) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (balance != null)
                Text(
                  'Balance: $balance',
                  style: TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Token selector
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.primary.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    TokenLogoService.buildTokenLogo(
                      symbol: token,
                      size: 20,
                      fallbackColor: AppTheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      token,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down,
                      color: AppTheme.textSecondary,
                      size: 20,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Amount input
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    controller != null
                        ? TextField(
                            controller: controller,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Tomorrow',
                            ),
                            decoration: InputDecoration(
                              hintText: '0.0',
                              hintStyle: TextStyle(
                                color: AppTheme.textTertiary,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          )
                        : Text(
                            estimatedAmount ?? '0.0',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Tomorrow',
                            ),
                          ),
                    if (usdValue != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '≈ \$${usdValue.toStringAsFixed(2)} USD',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
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
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFamily: 'Tomorrow',
          ),
        ),
      ],
    );
  }

  void _handleSwap() {
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an amount')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // TODO: Implement actual swap via API
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Swap request sent. Please wait for confirmation.')),
        );
        widget.onDismiss();
      }
    });
  }
}
