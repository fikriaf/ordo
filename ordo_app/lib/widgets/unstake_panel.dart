import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';

class UnstakePanel extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onDismiss;

  const UnstakePanel({
    super.key,
    required this.data,
    required this.onDismiss,
  });

  @override
  State<UnstakePanel> createState() => _UnstakePanelState();
}

class _UnstakePanelState extends State<UnstakePanel> {
  final TextEditingController _amountController = TextEditingController();
  String _selectedProtocol = 'marinade';
  bool _isLoading = false;
  bool _isLoadingPositions = false;
  String? _errorMessage;
  String? _successMessage;
  
  // User's staking positions
  List<Map<String, dynamic>> _stakingPositions = [];
  Map<String, dynamic>? _selectedPosition;
  
  // Protocol display names
  final Map<String, String> _protocolNames = {
    'marinade': 'Marinade Finance',
    'jito': 'Jito',
    'sanctum': 'Sanctum',
  };
  
  // Staked token names
  final Map<String, String> _stakedTokenNames = {
    'marinade': 'mSOL',
    'jito': 'JitoSOL',
    'sanctum': 'scnSOL',
  };

  @override
  void initState() {
    super.initState();
    final amount = widget.data['amount'] ?? '';
    _amountController.text = amount.toString();
    _selectedProtocol = widget.data['protocol']?.toString().toLowerCase() ?? 
                        widget.data['validator']?.toString().toLowerCase() ?? 
                        'marinade';
    
    // Ensure valid protocol
    if (!_protocolNames.containsKey(_selectedProtocol)) {
      _selectedProtocol = 'marinade';
    }
    
    // Load user's staking positions
    _loadStakingPositions();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }
  
  Future<void> _loadStakingPositions() async {
    setState(() {
      _isLoadingPositions = true;
    });
    
    try {
      final authService = context.read<AuthService>();
      final apiClient = ApiClient(authService: authService);
      
      // Get primary wallet ID
      final walletsResponse = await apiClient.getWallets();
      if (walletsResponse['success'] == true && walletsResponse['data'] != null) {
        final wallets = walletsResponse['data'] as List;
        if (wallets.isNotEmpty) {
          final primaryWallet = wallets.firstWhere(
            (w) => w['isPrimary'] == true,
            orElse: () => wallets.first,
          );
          final walletId = primaryWallet['id'] as String;
          
          final response = await apiClient.getStakingPositions(walletId);
          if (response['success'] == true && response['data'] != null) {
            setState(() {
              _stakingPositions = List<Map<String, dynamic>>.from(response['data']);
              
              // Auto-select first position matching protocol
              _selectedPosition = _stakingPositions.firstWhere(
                (p) => p['protocol']?.toString().toLowerCase() == _selectedProtocol,
                orElse: () => _stakingPositions.isNotEmpty ? _stakingPositions.first : {},
              );
              
              if (_selectedPosition != null && _selectedPosition!.isNotEmpty) {
                _selectedProtocol = _selectedPosition!['protocol']?.toString().toLowerCase() ?? _selectedProtocol;
              }
            });
          }
        }
      }
    } catch (e) {
      print('Failed to load staking positions: $e');
    } finally {
      setState(() {
        _isLoadingPositions = false;
      });
    }
  }
  
  double get _availableToUnstake {
    if (_selectedPosition != null && _selectedPosition!.isNotEmpty) {
      return (_selectedPosition!['stakedAmount'] as num?)?.toDouble() ?? 0.0;
    }
    
    // Sum positions for selected protocol
    return _stakingPositions
      .where((p) => p['protocol']?.toString().toLowerCase() == _selectedProtocol)
      .fold(0.0, (sum, p) => sum + ((p['stakedAmount'] as num?)?.toDouble() ?? 0.0));
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
                    Icons.output,
                    color: Colors.orange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Unstake SOL',
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
                          Icons.info_outline,
                          color: Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Unstake your liquid staked tokens to receive SOL',
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

                  // Amount Input
                  Text(
                    'Amount to Unstake',
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
                      suffixText: _stakedTokenNames[_selectedProtocol] ?? 'stSOL',
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

                  const SizedBox(height: 8),

                  // Available Balance
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isLoadingPositions 
                            ? 'Loading...'
                            : 'Available: ${_availableToUnstake.toStringAsFixed(4)} ${_stakedTokenNames[_selectedProtocol]}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                      TextButton(
                        onPressed: _availableToUnstake > 0 ? () {
                          setState(() {
                            _amountController.text = _availableToUnstake.toStringAsFixed(4);
                          });
                        } : null,
                        child: const Text(
                          'MAX',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Summary
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
                    child: Column(
                      children: [
                        _buildSummaryRow('Protocol', _protocolNames[_selectedProtocol] ?? _selectedProtocol),
                        const SizedBox(height: 12),
                        _buildSummaryRow('Token', _stakedTokenNames[_selectedProtocol] ?? 'stSOL'),
                        const SizedBox(height: 12),
                        _buildSummaryRow('Unstake Period', _getUnstakePeriod()),
                        const SizedBox(height: 12),
                        _buildSummaryRow('You will receive', 'SOL', Colors.green),
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
                    onPressed: _isLoading ? null : _handleUnstake,
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
                            'Unstake',
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
  
  Widget _buildProtocolSelector() {
    return Column(
      children: _protocolNames.keys.map((protocol) {
        final isSelected = _selectedProtocol == protocol;
        final positionsForProtocol = _stakingPositions
            .where((p) => p['protocol']?.toString().toLowerCase() == protocol)
            .toList();
        final stakedAmount = positionsForProtocol.fold(
          0.0, 
          (sum, p) => sum + ((p['stakedAmount'] as num?)?.toDouble() ?? 0.0)
        );
        
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedProtocol = protocol;
              _selectedPosition = positionsForProtocol.isNotEmpty 
                  ? positionsForProtocol.first 
                  : null;
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
                        _isLoadingPositions 
                            ? 'Loading...'
                            : 'Staked: ${stakedAmount.toStringAsFixed(4)} ${_stakedTokenNames[protocol]}',
                        style: TextStyle(
                          color: stakedAmount > 0 
                              ? Colors.green.withOpacity(0.8) 
                              : Colors.white.withOpacity(0.5),
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
      case 'marinade':
        return [const Color(0xFF10b77f), const Color(0xFF6567f1)];
      case 'jito':
        return [const Color(0xFFFF6B6B), const Color(0xFFFFE66D)];
      case 'sanctum':
        return [const Color(0xFF667eea), const Color(0xFF764ba2)];
      default:
        return [Colors.orange, Colors.orange];
    }
  }
  
  String _getUnstakePeriod() {
    switch (_selectedProtocol) {
      case 'marinade':
        return 'Instant (Liquid)';
      case 'jito':
        return 'Instant (Liquid)';
      case 'sanctum':
        return 'Instant (Liquid)';
      default:
        return '~2-3 days';
    }
  }

  Widget _buildSummaryRow(String label, String value, [Color? valueColor]) {
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

  void _handleUnstake() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      setState(() {
        _errorMessage = 'Please enter a valid amount';
        _successMessage = null;
      });
      return;
    }
    
    // Check if user has enough staked
    if (amount > _availableToUnstake) {
      setState(() {
        _errorMessage = 'Insufficient staked balance. Available: ${_availableToUnstake.toStringAsFixed(4)} ${_stakedTokenNames[_selectedProtocol]}';
        _successMessage = null;
      });
      return;
    }
    
    // Minimum unstake amount
    if (amount < 0.001) {
      setState(() {
        _errorMessage = 'Minimum unstake amount is 0.001 ${_stakedTokenNames[_selectedProtocol]}';
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
      
      // Call unstake API
      final response = await apiClient.unstake(
        walletId: walletId,
        amount: amount,
        protocol: _selectedProtocol,
        stakeAccountAddress: _selectedPosition?['stakeAccountAddress'] as String?,
      );
      
      if (response['success'] == true) {
        final signature = response['data']?['signature'] ?? response['signature'];
        setState(() {
          _successMessage = 'Successfully unstaked $amount ${_stakedTokenNames[_selectedProtocol]}!\nTx: ${_shortenSignature(signature?.toString() ?? '')}';
          _errorMessage = null;
        });
        
        // Dismiss after showing success
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          widget.onDismiss();
        }
      } else {
        throw Exception(response['error'] ?? 'Unstaking failed');
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
