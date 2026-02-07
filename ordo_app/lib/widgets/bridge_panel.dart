import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/token_logo_service.dart';

class BridgePanel extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onDismiss;

  const BridgePanel({
    super.key,
    required this.data,
    required this.onDismiss,
  });

  @override
  State<BridgePanel> createState() => _BridgePanelState();
}

class _BridgePanelState extends State<BridgePanel> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _toAddressController = TextEditingController();
  late String _fromChain;
  late String _toChain;
  late String _token;
  bool _isLoading = false;
  bool _isLoadingQuote = false;
  String? _errorMessage;
  String? _successMessage;
  
  // Quote details
  double? _estimatedReceive;
  double? _bridgeFee;
  String? _estimatedTime;
  
  // Supported chains
  final List<String> _supportedChains = ['Solana', 'Ethereum', 'Polygon', 'Arbitrum', 'BSC'];
  
  // Chain colors
  final Map<String, Color> _chainColors = {
    'Solana': const Color(0xFF9945FF),
    'Ethereum': const Color(0xFF627EEA),
    'Polygon': const Color(0xFF8247E5),
    'Arbitrum': const Color(0xFF28A0F0),
    'BSC': const Color(0xFFF0B90B),
  };

  @override
  void initState() {
    super.initState();
    _fromChain = widget.data['fromChain']?.toString() ?? 
                 widget.data['sourceChain']?.toString() ?? 
                 'Solana';
    _toChain = widget.data['toChain']?.toString() ?? 
               widget.data['destinationChain']?.toString() ?? 
               'Ethereum';
    _token = widget.data['token']?.toString() ?? 
             widget.data['asset']?.toString() ?? 
             'SOL';
    _amountController.text = widget.data['amount']?.toString() ?? '';
    _toAddressController.text = widget.data['toAddress']?.toString() ?? '';
    
    // Fetch quote if amount is provided
    if (_amountController.text.isNotEmpty) {
      _fetchQuote();
    }
  }
  
  Future<void> _fetchQuote() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) return;
    
    setState(() {
      _isLoadingQuote = true;
    });
    
    try {
      final authService = context.read<AuthService>();
      final apiClient = ApiClient(authService: authService);
      
      final response = await apiClient.getBridgeQuote(
        fromChain: _fromChain,
        toChain: _toChain,
        token: _token,
        amount: amount,
      );
      
      if (response['success'] == true && response['data'] != null) {
        final data = response['data'] as Map<String, dynamic>;
        setState(() {
          _estimatedReceive = (data['estimatedReceive'] as num?)?.toDouble();
          _bridgeFee = (data['fee'] as num?)?.toDouble();
          _estimatedTime = data['estimatedTime']?.toString();
        });
      }
    } catch (e) {
      // Silently fail quote, use defaults
      print('Failed to fetch bridge quote: $e');
    } finally {
      setState(() {
        _isLoadingQuote = false;
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _toAddressController.dispose();
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
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.swap_horiz,
                    color: Colors.purple,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Bridge Assets',
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

                  // Info Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.purple.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.purple,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Transfer assets across different blockchains',
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

                  // From Chain
                  Text(
                    'From',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildChainSelector(_fromChain, Colors.green),

                  const SizedBox(height: 16),

                  // Swap Icon
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.swap_vert,
                        color: Colors.white.withOpacity(0.5),
                        size: 20,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // To Chain
                  Text(
                    'To',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildChainSelector(_toChain, Colors.blue),

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
                      suffixText: _token,
                      suffixStyle: const TextStyle(
                        color: Colors.purple,
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
                          color: Colors.purple,
                          width: 2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  
                  // Destination Address Input
                  Text(
                    'Destination Address',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _toAddressController,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter destination wallet address',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 14,
                      ),
                      suffixIcon: IconButton(
                        onPressed: () async {
                          final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
                          if (clipboardData?.text != null) {
                            _toAddressController.text = clipboardData!.text!;
                          }
                        },
                        icon: Icon(
                          Icons.content_paste,
                          color: Colors.white.withOpacity(0.5),
                          size: 20,
                        ),
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
                          color: Colors.purple,
                          width: 2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Bridge Details
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
                        _buildDetailRow('Route', '$_fromChain → $_toChain'),
                        const SizedBox(height: 12),
                        _buildDetailRow('Est. Time', _estimatedTime ?? '5-10 min'),
                        const SizedBox(height: 12),
                        _buildDetailRow('Bridge Fee', _bridgeFee != null ? '${_bridgeFee!.toStringAsFixed(4)} $_token' : '~0.1%'),
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          'You will receive', 
                          _isLoadingQuote 
                              ? 'Fetching...' 
                              : _estimatedReceive != null 
                                  ? '${_estimatedReceive!.toStringAsFixed(4)} $_token'
                                  : '--',
                          Colors.green,
                        ),
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
                    onPressed: _isLoading ? null : _handleBridge,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
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
                            'Bridge',
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

  Widget _buildChainSelector(String chain, Color color) {
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
          TokenLogoService.buildChainLogo(
            chainId: chain.toLowerCase(),
            size: 32,
            fallbackColor: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              chain,
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

  void _handleBridge() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      setState(() {
        _errorMessage = 'Please enter a valid amount';
        _successMessage = null;
      });
      return;
    }
    
    if (_toAddressController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a destination address';
        _successMessage = null;
      });
      return;
    }
    
    if (_fromChain == _toChain) {
      setState(() {
        _errorMessage = 'Source and destination chains must be different';
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
      
      // Call bridge API
      final response = await apiClient.executeBridge(
        walletId: walletId,
        fromChain: _fromChain,
        toChain: _toChain,
        token: _token,
        amount: amount,
        toAddress: _toAddressController.text,
      );
      
      if (response['success'] == true) {
        final txId = response['data']?['txId'] ?? response['txId'];
        setState(() {
          _successMessage = 'Bridge initiated! Transferring $amount $_token from $_fromChain to $_toChain.\nTx: ${_shortenSignature(txId?.toString() ?? '')}';
          _errorMessage = null;
        });
        
        // Don't auto-dismiss - let user see the result and close manually
      } else {
        throw Exception(response['error'] ?? 'Bridge failed');
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
