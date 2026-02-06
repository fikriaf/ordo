import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';

class RemoveLiquidityPanel extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onDismiss;

  const RemoveLiquidityPanel({
    super.key,
    required this.data,
    required this.onDismiss,
  });

  @override
  State<RemoveLiquidityPanel> createState() => _RemoveLiquidityPanelState();
}

class _RemoveLiquidityPanelState extends State<RemoveLiquidityPanel> {
  double _percentage = 100.0;
  String? _selectedPositionId;
  bool _isLoading = false;
  bool _isLoadingPositions = true;
  String? _errorMessage;
  String? _successMessage;
  List<Map<String, dynamic>> _positions = [];

  @override
  void initState() {
    super.initState();
    _loadPositions();
  }

  Future<void> _loadPositions() async {
    setState(() {
      _isLoadingPositions = true;
      _errorMessage = null;
    });

    try {
      final authService = context.read<AuthService>();
      final apiClient = ApiClient(authService: authService);
      
      final response = await apiClient.getLiquidityPositions();
      
      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];
        List<dynamic> positionsList = [];
        
        if (data is List) {
          positionsList = data;
        } else if (data is Map && data['positions'] != null) {
          positionsList = data['positions'] as List;
        }
        
        setState(() {
          _positions = positionsList.map((p) => Map<String, dynamic>.from(p)).toList();
          // Auto-select first position if available
          if (_positions.isNotEmpty && _selectedPositionId == null) {
            _selectedPositionId = _positions.first['id']?.toString();
          }
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load positions: ${e.toString().replaceAll('Exception: ', '')}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPositions = false;
        });
      }
    }
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
                    Icons.water_drop_outlined,
                    color: Colors.orange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Remove Liquidity',
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
                            'Withdraw your tokens from liquidity pools',
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

                  // Position Selection
                  Text(
                    'Select Position',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  if (_isLoadingPositions)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                        ),
                      ),
                    )
                  else if (_positions.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.water_drop_outlined,
                              color: Colors.white.withOpacity(0.3),
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No liquidity positions found',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _loadPositions,
                              child: const Text('Refresh'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    _buildPositionList(),

                  const SizedBox(height: 20),

                  // Percentage Slider
                  if (_positions.isNotEmpty) ...[
                    Text(
                      'Withdrawal Amount',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildPercentageSelector(),
                    
                    const SizedBox(height: 20),

                    // Position Details
                    if (_selectedPositionId != null)
                      _buildPositionDetails(),
                  ],

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
                    onPressed: (_isLoading || _positions.isEmpty || _selectedPositionId == null) 
                        ? null 
                        : _handleRemoveLiquidity,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.orange.withOpacity(0.3),
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
                        : Text(
                            'Remove ${_percentage.toStringAsFixed(0)}%',
                            style: const TextStyle(
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

  Widget _buildPositionList() {
    return Column(
      children: _positions.map((position) {
        final positionId = position['id']?.toString() ?? '';
        final isSelected = _selectedPositionId == positionId;
        final tokenA = position['tokenA']?.toString() ?? position['token0']?.toString() ?? 'Token A';
        final tokenB = position['tokenB']?.toString() ?? position['token1']?.toString() ?? 'Token B';
        final protocol = position['protocol']?.toString() ?? 'Unknown';
        final valueUsd = position['valueUsd'] ?? position['value'] ?? 0.0;
        final amountA = position['amountA'] ?? position['amount0'] ?? 0.0;
        final amountB = position['amountB'] ?? position['amount1'] ?? 0.0;
        
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedPositionId = positionId;
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
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
                // Token pair icons
                Stack(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _getProtocolColors(protocol),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          tokenA[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _getProtocolColors(protocol).reversed.toList(),
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.surface, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            tokenB[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$tokenA / $tokenB',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white.withOpacity(0.8),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_capitalizeFirst(protocol)} - $amountA $tokenA + $amountB $tokenB',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
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
                      '\$${_formatNumber(valueUsd)}',
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white.withOpacity(0.8),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isSelected)
                      const Icon(
                        Icons.check_circle,
                        color: Colors.orange,
                        size: 16,
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPercentageSelector() {
    return Column(
      children: [
        // Percentage buttons
        Row(
          children: [25.0, 50.0, 75.0, 100.0].map((pct) {
            final isSelected = _percentage == pct;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _percentage = pct;
                  });
                },
                child: Container(
                  margin: EdgeInsets.only(right: pct != 100.0 ? 8 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? Colors.orange.withOpacity(0.2) 
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected 
                          ? Colors.orange 
                          : Colors.white.withOpacity(0.1),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${pct.toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: isSelected ? Colors.orange : Colors.white.withOpacity(0.7),
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        // Slider
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.orange,
            inactiveTrackColor: Colors.white.withOpacity(0.1),
            thumbColor: Colors.orange,
            overlayColor: Colors.orange.withOpacity(0.2),
            trackHeight: 4,
          ),
          child: Slider(
            value: _percentage,
            min: 1,
            max: 100,
            divisions: 99,
            onChanged: (value) {
              setState(() {
                _percentage = value;
              });
            },
          ),
        ),
        // Display current percentage
        Text(
          '${_percentage.toStringAsFixed(1)}% of position',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildPositionDetails() {
    final position = _positions.firstWhere(
      (p) => p['id']?.toString() == _selectedPositionId,
      orElse: () => {},
    );
    
    if (position.isEmpty) return const SizedBox.shrink();
    
    final tokenA = position['tokenA']?.toString() ?? position['token0']?.toString() ?? 'Token A';
    final tokenB = position['tokenB']?.toString() ?? position['token1']?.toString() ?? 'Token B';
    final protocol = position['protocol']?.toString() ?? 'Unknown';
    final amountA = (position['amountA'] ?? position['amount0'] ?? 0.0) as num;
    final amountB = (position['amountB'] ?? position['amount1'] ?? 0.0) as num;
    
    final withdrawAmountA = amountA * (_percentage / 100);
    final withdrawAmountB = amountB * (_percentage / 100);
    
    return Container(
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
          _buildDetailRow('Protocol', _capitalizeFirst(protocol)),
          const SizedBox(height: 12),
          _buildDetailRow('Pool', '$tokenA / $tokenB'),
          const SizedBox(height: 12),
          Divider(color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 12),
          _buildDetailRow(
            'You will receive',
            '',
            Colors.orange,
          ),
          const SizedBox(height: 8),
          _buildDetailRow(
            tokenA,
            '~${withdrawAmountA.toStringAsFixed(4)}',
          ),
          const SizedBox(height: 8),
          _buildDetailRow(
            tokenB,
            '~${withdrawAmountB.toStringAsFixed(4)}',
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

  List<Color> _getProtocolColors(String protocol) {
    switch (protocol.toLowerCase()) {
      case 'raydium':
        return [const Color(0xFF667eea), const Color(0xFF764ba2)];
      case 'orca':
        return [const Color(0xFF10b77f), const Color(0xFF6567f1)];
      case 'meteora':
        return [const Color(0xFFFF6B6B), const Color(0xFFFFE66D)];
      default:
        return [Colors.orange, Colors.deepOrange];
    }
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  String _formatNumber(dynamic value) {
    if (value == null) return '0.00';
    final num = double.tryParse(value.toString()) ?? 0.0;
    if (num >= 1000000) {
      return '${(num / 1000000).toStringAsFixed(2)}M';
    } else if (num >= 1000) {
      return '${(num / 1000).toStringAsFixed(2)}K';
    }
    return num.toStringAsFixed(2);
  }

  void _handleRemoveLiquidity() async {
    if (_selectedPositionId == null) {
      setState(() {
        _errorMessage = 'Please select a position';
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
      
      // Get selected position details
      final position = _positions.firstWhere(
        (p) => p['id']?.toString() == _selectedPositionId,
        orElse: () => {},
      );
      
      if (position.isEmpty) {
        throw Exception('Position not found');
      }
      
      final protocol = position['protocol']?.toString() ?? 'raydium';
      final tokenA = position['tokenA']?.toString() ?? position['token0']?.toString() ?? '';
      final tokenB = position['tokenB']?.toString() ?? position['token1']?.toString() ?? '';
      
      // Call remove liquidity API
      final response = await apiClient.removeLiquidity(
        walletId: walletId,
        positionId: _selectedPositionId!,
        percentage: _percentage,
        protocol: protocol,
      );
      
      if (response['success'] == true) {
        final signature = response['data']?['signature'] ?? response['signature'];
        setState(() {
          _successMessage = 'Successfully removed ${_percentage.toStringAsFixed(0)}% liquidity from $tokenA/$tokenB pool!\nTx: ${_shortenSignature(signature?.toString() ?? '')}';
          _errorMessage = null;
        });
        
        // Refresh positions and dismiss after showing success
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          widget.onDismiss();
        }
      } else {
        throw Exception(response['error'] ?? 'Remove liquidity failed');
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
