import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/api_client.dart';

class DepositPanel extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onDismiss;

  const DepositPanel({
    super.key,
    required this.data,
    required this.onDismiss,
  });

  @override
  State<DepositPanel> createState() => _DepositPanelState();
}

class _DepositPanelState extends State<DepositPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _copied = false;
  bool _isLoading = true;
  String _walletAddress = '';
  String? _error;
  bool _didFetch = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _walletAddress = widget.data['address']?.toString() ?? '';
    
    // If address already provided, no need to load
    if (_walletAddress.isNotEmpty) {
      _isLoading = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Fetch wallet address if not provided and not already fetching
    if (_walletAddress.isEmpty && !_didFetch) {
      _didFetch = true;
      _fetchWalletAddress();
    }
  }

  Future<void> _fetchWalletAddress() async {
    try {
      final apiClient = context.read<ApiClient>();
      final response = await apiClient.getWallets();
      
      if (response['success'] == true && response['data'] != null) {
        final wallets = response['data'] as List;
        if (wallets.isNotEmpty) {
          // Get primary wallet or first one
          final primaryWallet = wallets.firstWhere(
            (w) => w['is_primary'] == true,
            orElse: () => wallets.first,
          );
          if (mounted) {
            setState(() {
              _walletAddress = primaryWallet['public_key']?.toString() ?? '';
              _isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _error = 'No wallet found. Please create a wallet first.';
              _isLoading = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Failed to load wallets';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load wallet address: $e';
          _isLoading = false;
        });
      }
    }
  }

  String get walletAddress => _walletAddress;

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: AppTheme.surface.withOpacity(0.95),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surface.withOpacity(0.95),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: AppTheme.error, size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: widget.onDismiss,
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }

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
          _buildHeader(),

          // Tab Bar
          _buildTabBar(),

          // Tab Content
          SizedBox(
            height: 400,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCryptoDeposit(),
                _buildFiatOnRamp(),
              ],
            ),
          ),
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
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.success.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.download,
              color: AppTheme.success,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Deposit',
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
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppTheme.textSecondary,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        tabs: const [
          Tab(text: 'Crypto'),
          Tab(text: 'Buy with Card'),
        ],
      ),
    );
  }

  Widget _buildCryptoDeposit() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // QR Code
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: QrImageView(
              data: walletAddress,
              version: QrVersions.auto,
              size: 180,
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
            ),
          ),

          const SizedBox(height: 20),

          // Network badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.primary.withOpacity(0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppTheme.success,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.success.withOpacity(0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Solana Network',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Address
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.05),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Deposit Address',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        walletAddress,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _copyAddress,
                      icon: Icon(
                        _copied ? Icons.check : Icons.copy,
                        color: _copied ? AppTheme.success : AppTheme.primary,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Copy button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _copyAddress,
              icon: Icon(
                _copied ? Icons.check : Icons.copy,
                size: 18,
              ),
              label: Text(_copied ? 'Copied!' : 'Copy Address'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _copied ? AppTheme.success : AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Warning
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.warning.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: AppTheme.warning,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Only send SOL or SPL tokens to this address. Sending other assets may result in permanent loss.',
                    style: TextStyle(
                      color: AppTheme.warning,
                      fontSize: 11,
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

  Widget _buildFiatOnRamp() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.credit_card,
                  color: AppTheme.primary,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Buy Crypto with Card',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Purchase SOL or USDC directly with your credit/debit card through our trusted partners.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Provider buttons
          _buildProviderButton(
            name: 'Moonpay',
            description: 'Buy with card or bank transfer',
            icon: Icons.account_balance,
            color: const Color(0xFF7D00FF),
            onTap: () => _openOnRamp('moonpay'),
          ),

          const SizedBox(height: 12),

          _buildProviderButton(
            name: 'Transak',
            description: 'Global fiat-to-crypto gateway',
            icon: Icons.language,
            color: const Color(0xFF0064FF),
            onTap: () => _openOnRamp('transak'),
          ),

          const SizedBox(height: 12),

          _buildProviderButton(
            name: 'Coinbase Pay',
            description: 'Use your Coinbase account',
            icon: Icons.currency_bitcoin,
            color: const Color(0xFF0052FF),
            onTap: () => _openOnRamp('coinbase'),
          ),

          const SizedBox(height: 20),

          // Disclaimer
          Text(
            'Powered by third-party providers. Fees and availability may vary by region.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textTertiary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderButton({
    required String name,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
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
                      description,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: AppTheme.textTertiary,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _copyAddress() async {
    await Clipboard.setData(ClipboardData(text: walletAddress));
    setState(() => _copied = true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Address copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
  }

  void _openOnRamp(String provider) async {
    // TODO: Replace with actual on-ramp URLs with wallet address
    final urls = {
      'moonpay':
          'https://www.moonpay.com/buy?defaultCurrencyCode=sol&walletAddress=$walletAddress',
      'transak':
          'https://global.transak.com/?defaultCryptoCurrency=SOL&walletAddress=$walletAddress',
      'coinbase':
          'https://pay.coinbase.com/buy/select-asset?appId=ordo&addresses={"$walletAddress":["solana"]}',
    };

    final url = urls[provider];
    if (url != null) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }
}
