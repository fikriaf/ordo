import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

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
  String? _selectedChain;

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _loadWallets();
  }

  void _loadWallets() {
    // Debug: print incoming data
    print('🔵 WalletManagementPanel data: ${widget.data}');
    
    // Load from data
    final wallets = widget.data['wallets'] as List?;
    if (wallets != null) {
      _solanaWallets = wallets
          .where((w) => w['type'] == 'solana' || w['type'] == null)
          .map((w) => Map<String, dynamic>.from(w))
          .toList();
      print('🔵 Loaded ${_solanaWallets.length} Solana wallets');
    }

    final evmWallets = widget.data['evmWallets'] as List?;
    if (evmWallets != null) {
      _evmWallets = evmWallets.map((w) => Map<String, dynamic>.from(w)).toList();
      print('🔵 Loaded ${_evmWallets.length} EVM wallets');
    }

    // Handle case where a single wallet was just created (from API response)
    // Check if we have a direct address but no wallet list
    final directAddress = widget.data['address'] as String?;
    final chainId = widget.data['chainId'] ?? widget.data['chain'];
    
    print('🔵 Direct address: $directAddress, chainId: $chainId');
    
    if (directAddress != null && directAddress.isNotEmpty) {
      // Determine if it's EVM or Solana based on address format or chainId
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
        print('🔵 Created EVM wallet from direct address');
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
        print('🔵 Created Solana wallet from direct address');
      }
    }
    
    print('🔵 Final: ${_solanaWallets.length} Solana, ${_evmWallets.length} EVM wallets');
  }

  String _shortenAddress(String address) {
    if (address.length <= 12) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
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
          // Header
          _buildHeader(),

          // Tab Bar
          _buildTabBar(),

          // Content
          Flexible(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSolanaWallets(),
                _buildEvmWallets(),
              ],
            ),
          ),

          // Bottom Actions
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
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Mainnet',
                  style: TextStyle(
                    color: Colors.green.shade300,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
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
    if (_solanaWallets.isEmpty) {
      return _buildEmptySolanaState();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      shrinkWrap: true,
      itemCount: _solanaWallets.length,
      itemBuilder: (context, index) {
        final wallet = _solanaWallets[index];
        final isPrimary = wallet['isPrimary'] == true;

        return _buildWalletCard(
          wallet: wallet,
          isPrimary: isPrimary,
          chainSymbol: 'SOL',
          onCopy: () => _copyAddress(wallet['fullAddress'] ?? wallet['publicKey']),
          onSetPrimary: isPrimary ? null : () => _setAsPrimary(wallet['id'], 'solana'),
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

        return _buildWalletCard(
          wallet: wallet,
          isPrimary: wallet['isPrimary'] == true,
          chainSymbol: chainInfo['symbol'],
          chainIcon: chainInfo['icon'],
          chainName: chainInfo['name'],
          onCopy: () => _copyAddress(wallet['address']),
          onSetPrimary: wallet['isPrimary'] == true
              ? null
              : () => _setAsPrimary(wallet['id'], wallet['chainId']),
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
                Text(
                  chain['icon'],
                  style: const TextStyle(fontSize: 14),
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

  Widget _buildWalletCard({
    required Map<String, dynamic> wallet,
    required bool isPrimary,
    required String chainSymbol,
    String? chainIcon,
    String? chainName,
    required VoidCallback onCopy,
    VoidCallback? onSetPrimary,
  }) {
    final balance = wallet['balance'] ?? wallet['native'] ?? 0.0;
    final usdValue = wallet['usdValue'] ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPrimary
              ? AppTheme.primary.withOpacity(0.5)
              : Colors.white.withOpacity(0.05),
          width: isPrimary ? 2 : 1,
        ),
        boxShadow: isPrimary
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
                if (isPrimary)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
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
                Text(
                  wallet['publicKey'] ?? wallet['address']?.toString().substring(0, 10) ?? '',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const Spacer(),
                if (chainIcon != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      chainIcon,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                if (isPrimary)
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

            // Wallet Name
            Text(
              wallet['name'] ?? 'Wallet',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),

            if (chainName != null) ...[
              const SizedBox(height: 2),
              Text(
                chainName,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Balance Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${balance.toStringAsFixed(2)} $chainSymbol',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '\$${usdValue.toStringAsFixed(2)} USD',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (onSetPrimary != null)
                      IconButton(
                        onPressed: onSetPrimary,
                        icon: Icon(
                          Icons.star_border,
                          color: AppTheme.textSecondary,
                          size: 20,
                        ),
                        tooltip: 'Set as Primary',
                      ),
                    IconButton(
                      onPressed: onCopy,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.05),
                      ),
                      icon: Icon(
                        Icons.copy,
                        color: AppTheme.textSecondary,
                        size: 18,
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
          // Create Wallet Button
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

          // Import Wallet Button
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
    if (address == null) return;
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

  void _setAsPrimary(String walletId, String type) {
    widget.onAction?.call('setWalletPrimary', {
      'walletId': walletId,
      'type': type,
    });
  }

  void _createWallet() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_tabController.index == 0) {
        // Create Solana wallet
        widget.onAction?.call('createWallet', {'type': 'solana'});
      } else {
        // Create EVM wallet
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
