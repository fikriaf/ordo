import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/token_logo_service.dart';

class LendingPanel extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onDismiss;

  const LendingPanel({
    super.key,
    required this.data,
    required this.onDismiss,
  });

  @override
  State<LendingPanel> createState() => _LendingPanelState();
}

class _LendingPanelState extends State<LendingPanel> {
  final TextEditingController _amountController = TextEditingController();
  late String _selectedAsset;
  String _selectedProtocol = 'kamino';
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  
  // APY rates for different protocols
  final Map<String, double> _apyRates = {
    'kamino': 6.5,
    'marginfi': 5.8,
    'solend': 6.2,
  };
  
  // Protocol display names
  final Map<String, String> _protocolNames = {
    'kamino': 'Kamino Finance',
    'marginfi': 'MarginFi',
    'solend': 'Solend',
  };

  @override
  void initState() {
    super.initState();
    final amount = widget.data['amount'] ?? '';
    _amountController.text = amount.toString();
    _selectedAsset = widget.data['asset']?.toString() ?? 
                     widget.data['token']?.toString() ?? 
                     'SOL';
    _selectedProtocol = widget.data['protocol']?.toString().toLowerCase() ?? 'kamino';
    
    // Ensure valid protocol
    if (!_apyRates.containsKey(_selectedProtocol)) {
      _selectedProtocol = 'kamino';
    }
    
    // Load APY rates from backend
    _loadApyRates();
  }
  
  Future<void> _loadApyRates() async {
    try {
      final authService = context.read<AuthService>();
      final apiClient = ApiClient(authService: authService);
      final response = await apiClient.get('/lend/rates');
      
      if (response['success'] == true && response['data'] != null) {
        final data = response['data'] as Map<String, dynamic>;
        setState(() {
          if (data['kamino'] != null) _apyRates['kamino'] = (data['kamino'] as num).toDouble();
          if (data['marginfi'] != null) _apyRates['marginfi'] = (data['marginfi'] as num).toDouble();
          if (data['solend'] != null) _apyRates['solend'] = (data['solend'] as num).toDouble();
        });
      }
    } catch (e) {
      // Use default APY rates if API fails
      print('Failed to load lending rates: $e');
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
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
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.monetization_on,
                    color: AppTheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Lend Assets',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: widget.onDismiss,
                ),
              ],
            ),
          ),

          // Content
          Container(
            constraints: const BoxConstraints(maxHeight: 500),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Error/Success Message
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                  if (_successMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _successMessage!,
                              style: const TextStyle(color: Colors.green, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Info Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primary.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: AppTheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Earn interest by lending your assets',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Asset Selection
                  Text(
                    'Asset',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildAssetSelector(),

                  const SizedBox(height: 20),

                  // Amount Input
                  Text(
                    'Amount',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                      ),
                      suffixText: _selectedAsset,
                      suffixStyle: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppTheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Protocol Selection
                  Text(
                    'Lending Protocol',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildProtocolSelector(),

                  const SizedBox(height: 20),

                  // Lending Details
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow('Supply APY', '${(_apyRates[_selectedProtocol] ?? 6.0).toStringAsFixed(1)}%', Colors.green),
                        const SizedBox(height: 12),
                        _buildDetailRow('Protocol', _protocolNames[_selectedProtocol] ?? _selectedProtocol),
                        const SizedBox(height: 12),
                        _buildDetailRow('Collateral Factor', widget.data['collateralFactor']?.toString() ?? '75%'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onDismiss,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(
                        color: Colors.white.withOpacity(0.2),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLend,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Supply',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
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

  Widget _buildAssetSelector() {
    final availableBalance = widget.data['availableBalance']?.toString() ?? '--';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          TokenLogoService.buildTokenLogo(
            symbol: _selectedAsset,
            size: 32,
            fallbackColor: AppTheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedAsset,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Balance: $availableBalance',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: Colors.white.withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildProtocolSelector() {
    return Column(
      children: _apyRates.keys.map((protocol) {
        final isSelected = _selectedProtocol == protocol;
        final apy = _apyRates[protocol] ?? 0.0;
        
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedProtocol = protocol;
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected 
                  ? AppTheme.primary.withOpacity(0.1) 
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected 
                    ? AppTheme.primary 
                    : Colors.white.withOpacity(0.1),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _getProtocolColors(protocol),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      protocol[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _protocolNames[protocol] ?? protocol,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white.withOpacity(0.8),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Supply APY: ${apy.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: Colors.green.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle,
                    color: AppTheme.primary,
                    size: 20,
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
  
  List<Color> _getProtocolColors(String protocol) {
    switch (protocol) {
      case 'kamino':
        return [const Color(0xFF667eea), const Color(0xFF764ba2)];
      case 'marginfi':
        return [const Color(0xFFFF6B6B), const Color(0xFFFFE66D)];
      case 'solend':
        return [const Color(0xFF10b77f), const Color(0xFF6567f1)];
      default:
        return [AppTheme.primary, AppTheme.primary];
    }
  }

  Widget _buildDetailRow(String label, String value, [Color? valueColor]) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  void _handleLend() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      setState(() {
        _errorMessage = 'Please enter a valid amount';
        _successMessage = null;
      });
      return;
    }
    
    // Minimum lend amount
    if (amount < 0.001) {
      setState(() {
        _errorMessage = 'Minimum lend amount is 0.001 $_selectedAsset';
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final authService = context.read<AuthService>();
      final apiClient = ApiClient(authService: authService);
      
      // Get primary wallet ID
      final walletsResponse = await apiClient.getWallets();
      if (walletsResponse['success'] != true || walletsResponse['data'] == null) {
        throw Exception('Failed to get wallets');
      }
      
      final wallets = walletsResponse['data'] as List;
      if (wallets.isEmpty) {
        throw Exception('No wallet found. Please create a wallet first.');
      }
      
      // Find primary wallet or use first one
      final primaryWallet = wallets.firstWhere(
        (w) => w['isPrimary'] == true,
        orElse: () => wallets.first,
      );
      final walletId = primaryWallet['id'] as String;
      
      // Call lending API
      final response = await apiClient.lend(
        walletId: walletId,
        amount: amount,
        asset: _selectedAsset,
        protocol: _selectedProtocol,
      );
      
      if (response['success'] == true) {
        final signature = response['data']?['signature'] ?? response['signature'];
        setState(() {
          _successMessage = 'Successfully supplied $amount $_selectedAsset to ${_protocolNames[_selectedProtocol]}!\nTx: ${_shortenSignature(signature?.toString() ?? '')}';
          _errorMessage = null;
        });
        
        // Don't auto-dismiss - let user see the result and close manually
      } else {
        throw Exception(response['error'] ?? 'Lending failed');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _successMessage = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  String _shortenSignature(String sig) {
    if (sig.length > 20) {
      return '${sig.substring(0, 8)}...${sig.substring(sig.length - 8)}';
    }
    return sig;
  }
}
