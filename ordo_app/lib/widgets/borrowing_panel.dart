import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';

class BorrowingPanel extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onDismiss;

  const BorrowingPanel({
    super.key,
    required this.data,
    required this.onDismiss,
  });

  @override
  State<BorrowingPanel> createState() => _BorrowingPanelState();
}

class _BorrowingPanelState extends State<BorrowingPanel> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _collateralAmountController = TextEditingController();
  late String _selectedAsset;
  String _collateralAsset = 'SOL';
  String _selectedProtocol = 'kamino';
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  
  // Borrow APY rates for different protocols
  final Map<String, double> _borrowApyRates = {
    'kamino': 8.5,
    'marginfi': 9.2,
    'solend': 8.8,
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
                     'USDC';
    _collateralAsset = widget.data['collateralAsset']?.toString() ?? 'SOL';
    _collateralAmountController.text = widget.data['collateralAmount']?.toString() ?? '';
    _selectedProtocol = widget.data['protocol']?.toString().toLowerCase() ?? 'kamino';
    
    // Ensure valid protocol
    if (!_borrowApyRates.containsKey(_selectedProtocol)) {
      _selectedProtocol = 'kamino';
    }
    
    // Load rates from backend
    _loadBorrowRates();
  }
  
  Future<void> _loadBorrowRates() async {
    try {
      final authService = context.read<AuthService>();
      final apiClient = ApiClient(authService: authService);
      final response = await apiClient.get('/lend/rates');
      
      if (response['success'] == true && response['data'] != null) {
        final data = response['data'] as Map<String, dynamic>;
        setState(() {
          if (data['kamino_borrow'] != null) _borrowApyRates['kamino'] = (data['kamino_borrow'] as num).toDouble();
          if (data['marginfi_borrow'] != null) _borrowApyRates['marginfi'] = (data['marginfi_borrow'] as num).toDouble();
          if (data['solend_borrow'] != null) _borrowApyRates['solend'] = (data['solend_borrow'] as num).toDouble();
        });
      }
    } catch (e) {
      // Use default rates if API fails
      print('Failed to load borrow rates: $e');
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _collateralAmountController.dispose();
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
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.monetization_on,
                    color: Colors.orange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Borrow Assets',
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
            constraints: const BoxConstraints(maxHeight: 550),
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

                  // Warning Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.orange.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Ensure you have sufficient collateral',
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

                  // Collateral Info
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
                        _buildDetailRow('Available Collateral', widget.data['availableCollateral']?.toString() ?? '--'),
                        const SizedBox(height: 8),
                        _buildDetailRow('Borrow Limit', widget.data['borrowLimit']?.toString() ?? '--', AppTheme.primary),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Asset Selection
                  Text(
                    'Asset to Borrow',
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
                        color: Colors.orange,
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
                          color: Colors.orange,
                          width: 2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Collateral Amount Input
                  Text(
                    'Collateral Amount ($_collateralAsset)',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _collateralAmountController,
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
                      suffixText: _collateralAsset,
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
                    'Protocol',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildProtocolSelector(),

                  const SizedBox(height: 20),

                  // Borrowing Details
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
                        _buildDetailRow('Borrow APY', '${(_borrowApyRates[_selectedProtocol] ?? 8.0).toStringAsFixed(1)}%', Colors.orange),
                        const SizedBox(height: 12),
                        _buildDetailRow('Protocol', _protocolNames[_selectedProtocol] ?? _selectedProtocol),
                        const SizedBox(height: 12),
                        _buildDetailRow('Liquidation Threshold', widget.data['liquidationThreshold']?.toString() ?? '80%'),
                        const SizedBox(height: 12),
                        _buildDetailRow('Health Factor', widget.data['healthFactor']?.toString() ?? '--', Colors.green),
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
                    onPressed: _isLoading ? null : _handleBorrow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
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
                            'Borrow',
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
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                _selectedAsset.isNotEmpty ? _selectedAsset[0] : 'T',
                style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _selectedAsset,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
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

  Widget _buildProtocolSelector() {
    return Column(
      children: _borrowApyRates.keys.map((protocol) {
        final isSelected = _selectedProtocol == protocol;
        final apy = _borrowApyRates[protocol] ?? 0.0;
        
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
                  ? Colors.orange.withOpacity(0.1) 
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected 
                    ? Colors.orange 
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
                        'Borrow APY: ${apy.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: Colors.orange.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle,
                    color: Colors.orange,
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
        return [Colors.orange, Colors.orange];
    }
  }

  void _handleBorrow() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      setState(() {
        _errorMessage = 'Please enter a valid borrow amount';
        _successMessage = null;
      });
      return;
    }
    
    final collateralAmount = double.tryParse(_collateralAmountController.text);
    if (collateralAmount == null || collateralAmount <= 0) {
      setState(() {
        _errorMessage = 'Please enter a valid collateral amount';
        _successMessage = null;
      });
      return;
    }
    
    // Minimum borrow amount
    if (amount < 0.001) {
      setState(() {
        _errorMessage = 'Minimum borrow amount is 0.001 $_selectedAsset';
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
      
      // Call borrow API
      final response = await apiClient.borrow(
        walletId: walletId,
        amount: amount,
        asset: _selectedAsset,
        collateralAsset: _collateralAsset,
        collateralAmount: collateralAmount,
        protocol: _selectedProtocol,
      );
      
      if (response['success'] == true) {
        final signature = response['data']?['signature'] ?? response['signature'];
        setState(() {
          _successMessage = 'Successfully borrowed $amount $_selectedAsset from ${_protocolNames[_selectedProtocol]}!\nTx: ${_shortenSignature(signature?.toString() ?? '')}';
          _errorMessage = null;
        });
        
        // Dismiss after showing success
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          widget.onDismiss();
        }
      } else {
        throw Exception(response['error'] ?? 'Borrow failed');
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
