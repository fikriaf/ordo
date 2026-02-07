import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/token_logo_service.dart';

class WalletManagementPanel extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onDismiss;
  final Function(String action, Map<String, dynamic> params)? onAction;
  final int initialTab;

  const WalletManagementPanel({
    super.key,
    required this.data,
    required this.onDismiss,
    this.onAction,
    this.initialTab = 0,
  });

  @override
  State<WalletManagementPanel> createState() => _WalletManagementPanelState();
}

class _WalletManagementPanelState extends State<WalletManagementPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  bool _isFetchingWallets = true;
  String? _selectedChain;
  String? _errorMessage;

  // Supported EVM chains
  final List<Map<String, dynamic>> _evmChains = [
    {'id': 'ethereum', 'name': 'Ethereum', 'symbol': 'ETH', 'icon': '⟠'},
    {'id': 'polygon', 'name': 'Polygon', 'symbol': 'MATIC', 'icon': '⬡'},
    {'id': 'bsc', 'name': 'BNB Chain', 'symbol': 'BNB', 'icon': '◈'},
    {'id': 'arbitrum', 'name': 'Arbitrum', 'symbol': 'ETH', 'icon': '⬢'},
    {'id': 'optimism', 'name': 'Optimism', 'symbol': 'ETH', 'icon': '⬡'},
    {'id': 'avalanche', 'name': 'Avalanche', 'symbol': 'AVAX', 'icon': '△'},
  ];

  List<Map<String, dynamic>> _solanaWallets = [];
  List<Map<String, dynamic>> _evmWallets = [];

  // Track which wallet is currently showing private key (only one at a time)
  String? _revealedWalletId;
  String? _revealedPrivateKey;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _loadWalletsFromData();
    _fetchWalletsFromApi();
  }

  void _loadWalletsFromData() {
    print('WalletManagementPanel data: ${widget.data}');
    
    final wallets = widget.data['wallets'] as List?;
    if (wallets != null) {
      _solanaWallets = wallets
          .where((w) => w['type'] == 'solana' || w['type'] == null)
          .map((w) => Map<String, dynamic>.from(w))
          .toList();
    }

    final evmWallets = widget.data['evmWallets'] as List?;
    if (evmWallets != null) {
      _evmWallets = evmWallets.map((w) => Map<String, dynamic>.from(w)).toList();
    }

    final directAddress = widget.data['address'] as String?;
    final chainId = widget.data['chainId'] ?? widget.data['chain'];
    
    if (directAddress != null && directAddress.isNotEmpty) {
      final isEvm = chainId != null || directAddress.startsWith('0x');
      
      if (isEvm && _evmWallets.isEmpty) {
        _evmWallets = [{
          'address': directAddress,
          'chainId': chainId ?? 'ethereum',
          'name': 'New Wallet',
          'balance': 0.0,
          'usdValue': 0.0,
          'isPrimary': true,
          'isNew': true,
        }];
      } else if (!isEvm && _solanaWallets.isEmpty) {
        _solanaWallets = [{
          'publicKey': _shortenAddress(directAddress),
          'fullAddress': directAddress,
          'name': 'New Wallet',
          'balance': 0.0,
          'usdValue': 0.0,
          'isPrimary': true,
          'isNew': true,
        }];
      }
    }
  }

  Future<void> _fetchWalletsFromApi() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiClient = ApiClient(authService: authService);
      
      final response = await apiClient.getWallets();
      
      if (response['success'] == true && mounted) {
        final wallets = response['data'] as List? ?? [];
        
        setState(() {
          _solanaWallets = wallets
              .map((w) => Map<String, dynamic>.from(w))
              .toList();
          
          if (_solanaWallets.isNotEmpty) {
            final hasPrimary = _solanaWallets.any((w) => w['isPrimary'] == true);
            if (!hasPrimary) {
              _solanaWallets[0]['isPrimary'] = true;
            }
          }
          
          _isFetchingWallets = false;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _isFetchingWallets = false;
          _errorMessage = response['error']?.toString();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFetchingWallets = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _refreshWallets() async {
    setState(() {
      _isFetchingWallets = true;
    });
    await _fetchWalletsFromApi();
  }

  String _shortenAddress(String address) {
    if (address.length <= 12) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  String _getNetworkName() {
    final network = widget.data['network']?.toString() ?? 
                    widget.data['mode']?.toString() ?? 
                    'devnet';
    switch (network.toLowerCase()) {
      case 'mainnet':
        return 'Mainnet';
      case 'testnet':
        return 'Testnet';
      case 'devnet':
      default:
        return 'Devnet';
    }
  }

  Color _getNetworkColor() {
    final network = widget.data['network']?.toString() ?? 
                    widget.data['mode']?.toString() ?? 
                    'devnet';
    switch (network.toLowerCase()) {
      case 'mainnet':
        return Colors.green;
      case 'testnet':
        return Colors.purple;
      case 'devnet':
      default:
        return Colors.orange;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
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
          _buildHeader(),
          _buildTabBar(),
          Flexible(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSolanaWallets(),
                _buildEvmWallets(),
              ],
            ),
          ),
          _buildBottomActions(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
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
          GestureDetector(
            onTap: widget.onDismiss,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.chevron_left,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '[WALLET]',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'My Wallets',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getNetworkColor().withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _getNetworkColor(),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _getNetworkColor().withOpacity(0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _getNetworkName(),
                  style: TextStyle(
                    color: _getNetworkColor(),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _isFetchingWallets ? null : _refreshWallets,
            icon: _isFetchingWallets
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                    ),
                  )
                : Icon(
                    Icons.refresh,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
            tooltip: 'Refresh wallets',
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: AppTheme.textSecondary,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.network(
                  'https://cryptologos.cc/logos/solana-sol-logo.png',
                  width: 16,
                  height: 16,
                  errorBuilder: (_, __, ___) => const Text('◎'),
                ),
                const SizedBox(width: 6),
                const Text('Solana'),
              ],
            ),
          ),
          const Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('⟠', style: TextStyle(fontSize: 16)),
                SizedBox(width: 6),
                Text('EVM Chains'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSolanaWallets() {
    if (_isFetchingWallets) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading wallets...',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null && _solanaWallets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red.shade300,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'Failed to load wallets',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _refreshWallets,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_solanaWallets.isEmpty) {
      return _buildEmptySolanaState();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      shrinkWrap: true,
      itemCount: _solanaWallets.length,
      itemBuilder: (context, index) {
        final wallet = _solanaWallets[index];
        final isPrimary = wallet['isPrimary'] == true || wallet['is_primary'] == true;
        final walletId = wallet['id']?.toString() ?? wallet['_id']?.toString() ?? '';
        final address = wallet['publicKey']?.toString() ?? 
                       wallet['fullAddress']?.toString() ?? 
                       wallet['public_key']?.toString() ?? 
                       wallet['address']?.toString() ?? '';
        final uniqueKey = walletId.isNotEmpty ? walletId : 'sol_$index';

        return _FlipWalletCard(
          key: ValueKey(uniqueKey),
          wallet: wallet,
          isPrimary: isPrimary,
          chainSymbol: 'SOL',
          address: address,
          onCopy: () => _copyAddress(address),
          onSetPrimary: isPrimary ? null : () => _setAsPrimary(walletId, index),
          onViewPrivateKey: () => _showPasswordDialog(walletId, address),
          shortenAddress: _shortenAddress,
          isRevealed: _revealedWalletId == walletId || _revealedWalletId == address,
          privateKey: (_revealedWalletId == walletId || _revealedWalletId == address) ? _revealedPrivateKey : null,
          onHidePrivateKey: _hidePrivateKey,
        );
      },
    );
  }

  Widget _buildEmptySolanaState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                color: AppTheme.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Solana Wallets',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create or import a Solana wallet to\nstart using DeFi features.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEvmWallets() {
    if (_evmWallets.isEmpty) {
      return _buildEmptyEvmState();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      shrinkWrap: true,
      itemCount: _evmWallets.length,
      itemBuilder: (context, index) {
        final wallet = _evmWallets[index];
        final chainInfo = _evmChains.firstWhere(
          (c) => c['id'] == wallet['chainId'],
          orElse: () => {'name': 'Unknown', 'symbol': '?', 'icon': '?'},
        );
        final walletId = wallet['id']?.toString() ?? wallet['_id']?.toString() ?? '';
        final address = wallet['address']?.toString() ?? '';
        final uniqueKey = walletId.isNotEmpty ? walletId : 'evm_$index';

        return _FlipWalletCard(
          key: ValueKey(uniqueKey),
          wallet: wallet,
          isPrimary: wallet['isPrimary'] == true,
          chainSymbol: chainInfo['symbol'],
          chainIcon: chainInfo['icon'],
          chainId: chainInfo['id'],
          chainName: chainInfo['name'],
          address: address,
          onCopy: () => _copyAddress(address),
          onSetPrimary: wallet['isPrimary'] == true
              ? null
              : () => _setAsPrimary(walletId, index),
          onViewPrivateKey: () => _showPasswordDialog(walletId, address),
          shortenAddress: _shortenAddress,
          isRevealed: _revealedWalletId == walletId || _revealedWalletId == address,
          privateKey: (_revealedWalletId == walletId || _revealedWalletId == address) ? _revealedPrivateKey : null,
          onHidePrivateKey: _hidePrivateKey,
        );
      },
    );
  }

  Widget _buildEmptyEvmState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                color: AppTheme.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No EVM Wallets',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create or import an EVM wallet to manage\nEthereum, Polygon, BSC and more.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            _buildChainSelector(),
          ],
        ),
      ),
    );
  }

  Widget _buildChainSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: _evmChains.map((chain) {
        final isSelected = _selectedChain == chain['id'];
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedChain = isSelected ? null : chain['id'];
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primary.withOpacity(0.2)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? AppTheme.primary.withOpacity(0.5)
                    : Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TokenLogoService.buildChainLogo(
                  chainId: chain['id'],
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  chain['name'],
                  style: TextStyle(
                    color: isSelected ? AppTheme.primary : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.8),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _createWallet,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                shadowColor: AppTheme.primary.withOpacity(0.3),
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
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_circle_outline, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _tabController.index == 0
                              ? 'Create New Wallet'
                              : 'Create ${_selectedChain != null ? _evmChains.firstWhere((c) => c['id'] == _selectedChain)['name'] : 'EVM'} Wallet',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _showImportDialog,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.vpn_key_outlined, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Import Private Key',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _copyAddress(String? address) {
    if (address == null || address.isEmpty) return;
    Clipboard.setData(ClipboardData(text: address));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Address copied to clipboard'),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _setAsPrimary(String? walletId, int index) async {
    // If no walletId, try to set primary by index in local state
    if (walletId == null || walletId.isEmpty) {
      setState(() {
        for (int i = 0; i < _solanaWallets.length; i++) {
          _solanaWallets[i]['isPrimary'] = (i == index);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Primary wallet updated (local)'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiClient = ApiClient(authService: authService);
      
      final response = await apiClient.setPrimaryWallet(walletId);
      
      if (response['success'] == true && mounted) {
        setState(() {
          for (var wallet in _solanaWallets) {
            wallet['isPrimary'] = (wallet['id']?.toString() == walletId || 
                                   wallet['_id']?.toString() == walletId);
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Primary wallet updated'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        _refreshWallets();
      } else {
        throw Exception(response['error'] ?? 'Failed to set primary wallet');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showPasswordDialog(String? walletId, String address) {
    final passwordController = TextEditingController();
    bool isLoading = false;
    String? errorText;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.security, color: AppTheme.warning, size: 24),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Security Verification',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter your password to view the private key for this wallet.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(color: AppTheme.textSecondary),
                  errorText: errorText,
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: Icon(Icons.lock_outline, color: AppTheme.textSecondary),
                ),
                onSubmitted: (_) async {
                  if (passwordController.text.isEmpty) {
                    setDialogState(() => errorText = 'Password is required');
                    return;
                  }
                  await _verifyAndShowPrivateKey(
                    dialogContext,
                    walletId,
                    address,
                    passwordController.text,
                    setDialogState,
                    (loading) => setDialogState(() => isLoading = loading),
                    (error) => setDialogState(() => errorText = error),
                  );
                },
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: AppTheme.warning, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Never share your private key with anyone!',
                        style: TextStyle(
                          color: AppTheme.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (passwordController.text.isEmpty) {
                        setDialogState(() => errorText = 'Password is required');
                        return;
                      }
                      await _verifyAndShowPrivateKey(
                        dialogContext,
                        walletId,
                        address,
                        passwordController.text,
                        setDialogState,
                        (loading) => setDialogState(() => isLoading = loading),
                        (error) => setDialogState(() => errorText = error),
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Verify'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _verifyAndShowPrivateKey(
    BuildContext dialogContext,
    String? walletId,
    String address,
    String password,
    StateSetter setDialogState,
    Function(bool) setLoading,
    Function(String?) setError,
  ) async {
    setLoading(true);
    setError(null);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiClient = ApiClient(authService: authService);
      
      final response = await apiClient.getWalletPrivateKey(walletId ?? '', password);
      
      if (response['success'] == true && mounted) {
        Navigator.pop(dialogContext);
        
        // Find the wallet card and trigger flip
        final privateKey = response['data']?['privateKey']?.toString() ?? 
                          response['privateKey']?.toString() ?? '';
        
        // Show the private key using wallet ID
        _showPrivateKeyResult(walletId ?? address, privateKey);
      } else {
        setError(response['error']?.toString() ?? 'Invalid password');
      }
    } catch (e) {
      setError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      setLoading(false);
    }
  }

  void _showPrivateKeyResult(String walletId, String privateKey) {
    // Set the revealed wallet ID and private key - only one wallet at a time
    setState(() {
      _revealedWalletId = walletId;
      _revealedPrivateKey = privateKey;
    });
  }

  void _hidePrivateKey() {
    setState(() {
      _revealedWalletId = null;
      _revealedPrivateKey = null;
    });
  }

  void _createWallet() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_tabController.index == 0) {
        widget.onAction?.call('createWallet', {'type': 'solana'});
      } else {
        final chainId = _selectedChain ?? 'ethereum';
        widget.onAction?.call('createEvmWallet', {'chainId': chainId});
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showImportDialog() {
    final controller = TextEditingController();
    final isSolana = _tabController.index == 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Import ${isSolana ? 'Solana' : 'EVM'} Wallet',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isSolana) ...[
              Text(
                'Select Chain',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              _buildChainSelector(),
              const SizedBox(height: 16),
            ],
            Text(
              'Private Key',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: isSolana ? 'Base58 encoded key' : '0x...',
                hintStyle: TextStyle(color: AppTheme.textTertiary),
                filled: true,
                fillColor: Colors.black.withOpacity(0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your private key is encrypted and stored securely.',
              style: TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _importWallet(controller.text, isSolana);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
            ),
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  void _importWallet(String privateKey, bool isSolana) {
    if (privateKey.isEmpty) return;

    if (isSolana) {
      widget.onAction?.call('importWallet', {'privateKey': privateKey});
    } else {
      widget.onAction?.call('importEvmWallet', {
        'chainId': _selectedChain ?? 'ethereum',
        'privateKey': privateKey,
      });
    }
  }
}

// Flip card widget for wallet with animation
class _FlipWalletCard extends StatefulWidget {
  final Map<String, dynamic> wallet;
  final bool isPrimary;
  final String chainSymbol;
  final String? chainIcon;
  final String? chainId;
  final String? chainName;
  final String address;
  final VoidCallback onCopy;
  final VoidCallback? onSetPrimary;
  final VoidCallback onViewPrivateKey;
  final String Function(String) shortenAddress;
  final bool isRevealed;
  final String? privateKey;
  final VoidCallback? onHidePrivateKey;

  const _FlipWalletCard({
    super.key,
    required this.wallet,
    required this.isPrimary,
    required this.chainSymbol,
    this.chainIcon,
    this.chainId,
    this.chainName,
    required this.address,
    required this.onCopy,
    this.onSetPrimary,
    required this.onViewPrivateKey,
    required this.shortenAddress,
    this.isRevealed = false,
    this.privateKey,
    this.onHidePrivateKey,
  });

  @override
  State<_FlipWalletCard> createState() => _FlipWalletCardState();
}

class _FlipWalletCardState extends State<_FlipWalletCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _showBack = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    
    // If already revealed on init, show back
    if (widget.isRevealed) {
      _showBack = true;
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_FlipWalletCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Handle flip based on isRevealed parameter change
    if (widget.isRevealed && !oldWidget.isRevealed && !_showBack) {
      // Should reveal - flip to back
      _flipCard();
    } else if (!widget.isRevealed && oldWidget.isRevealed && _showBack) {
      // Should hide - flip to front
      _flipCard();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flipCard() {
    if (_showBack) {
      _controller.reverse();
      // Notify parent to clear revealed state when hiding
      widget.onHidePrivateKey?.call();
    } else {
      _controller.forward();
    }
    setState(() {
      _showBack = !_showBack;
    });
  }

  @override
  Widget build(BuildContext context) {
    final balance = widget.wallet['balance'] ?? widget.wallet['native'] ?? 0.0;
    final usdValue = widget.wallet['usdValue'] ?? 0.0;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final angle = _animation.value * pi;
        final isFront = angle < pi / 2;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          child: isFront
              ? _buildFrontCard(balance, usdValue)
              : Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(pi),
                  child: _buildBackCard(),
                ),
        );
      },
    );
  }

  Widget _buildFrontCard(dynamic balance, dynamic usdValue) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isPrimary
              ? AppTheme.primary.withOpacity(0.5)
              : Colors.white.withOpacity(0.05),
          width: widget.isPrimary ? 2 : 1,
        ),
        boxShadow: widget.isPrimary
            ? [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                if (widget.isPrimary)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppTheme.primary.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      'PRIMARY',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'SECONDARY',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.shortenAddress(widget.address),
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.chainId != null)
                  TokenLogoService.buildChainLogo(
                    chainId: widget.chainId!,
                    size: 16,
                  ),
                if (widget.isPrimary)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.check_circle,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.wallet['name'] ?? 'Wallet',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (widget.chainName != null) ...[
              const SizedBox(height: 2),
              Text(
                widget.chainName!,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${(balance is num ? balance : 0.0).toStringAsFixed(4)} ${widget.chainSymbol}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '\$${(usdValue is num ? usdValue : 0.0).toStringAsFixed(2)} USD',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    if (widget.onSetPrimary != null)
                      IconButton(
                        onPressed: widget.onSetPrimary,
                        icon: Icon(
                          Icons.star_border,
                          color: AppTheme.textSecondary,
                          size: 20,
                        ),
                        tooltip: 'Set as Primary',
                      ),
                    IconButton(
                      onPressed: widget.onViewPrivateKey,
                      icon: Icon(
                        Icons.key,
                        color: AppTheme.warning,
                        size: 20,
                      ),
                      tooltip: 'View Private Key',
                    ),
                    IconButton(
                      onPressed: widget.onCopy,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.05),
                      ),
                      icon: Icon(
                        Icons.copy,
                        color: AppTheme.textSecondary,
                        size: 18,
                      ),
                      tooltip: 'Copy Address',
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

  Widget _buildBackCard() {
    final privateKey = widget.privateKey ?? '';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.warning.withOpacity(0.2),
            AppTheme.error.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.warning.withOpacity(0.5),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.key, color: AppTheme.warning, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'PRIVATE KEY',
                  style: TextStyle(
                    color: AppTheme.warning,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _flipCard,
                  icon: Icon(
                    Icons.close,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                  tooltip: 'Hide',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                privateKey.isNotEmpty ? privateKey : 'Unable to retrieve private key',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (privateKey.isNotEmpty) {
                        Clipboard.setData(ClipboardData(text: privateKey));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Private key copied to clipboard'),
                            backgroundColor: AppTheme.warning,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.warning,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _flipCard,
                    icon: const Icon(Icons.visibility_off, size: 16),
                    label: const Text('Hide'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(0.3)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: AppTheme.error, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Keep this key secret. Anyone with access can control your funds.',
                      style: TextStyle(
                        color: AppTheme.error,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
