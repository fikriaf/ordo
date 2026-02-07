import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/token_logo_service.dart';

class AnalyticsPanel extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onDismiss;

  const AnalyticsPanel({
    super.key,
    required this.data,
    required this.onDismiss,
  });

  @override
  State<AnalyticsPanel> createState() => _AnalyticsPanelState();
}

class _AnalyticsPanelState extends State<AnalyticsPanel> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Data states
  Map<String, dynamic>? _activity;
  List<Map<String, dynamic>> _transactions = [];
  Map<String, dynamic>? _balances;
  
  bool _isLoading = true;
  String? _errorMessage;
  String? _walletAddress;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadWalletAndData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadWalletAndData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = context.read<AuthService>();
      final apiClient = ApiClient(authService: authService);
      
      // Get primary wallet
      final walletsResponse = await apiClient.getWallets();
      if (walletsResponse['success'] != true || walletsResponse['data'] == null) {
        throw Exception('Failed to get wallets');
      }
      
      final wallets = walletsResponse['data'] as List;
      if (wallets.isEmpty) {
        throw Exception('No wallet found. Please create a wallet first.');
      }
      
      final primaryWallet = wallets.firstWhere(
        (w) => w['isPrimary'] == true,
        orElse: () => wallets.first,
      );
      _walletAddress = primaryWallet['publicKey']?.toString() ?? primaryWallet['address']?.toString();
      
      if (_walletAddress == null || _walletAddress!.isEmpty) {
        throw Exception('Wallet address not found');
      }

      // Load all data in parallel
      await Future.wait([
        _loadActivity(),
        _loadTransactions(),
        _loadBalances(),
      ]);
      
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadActivity() async {
    if (_walletAddress == null) return;
    
    try {
      final authService = context.read<AuthService>();
      final apiClient = ApiClient(authService: authService);
      
      final response = await apiClient.getAddressActivity(_walletAddress!);
      
      if (response['success'] == true && response['data'] != null) {
        setState(() {
          _activity = Map<String, dynamic>.from(response['data']);
        });
      }
    } catch (e) {
      // Silently fail for activity
    }
  }

  Future<void> _loadTransactions() async {
    if (_walletAddress == null) return;
    
    try {
      final authService = context.read<AuthService>();
      final apiClient = ApiClient(authService: authService);
      
      final response = await apiClient.getEnhancedTransactions(_walletAddress!, limit: 20);
      
      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];
        List<dynamic> txList = data is List ? data : (data['transactions'] ?? []);
        
        setState(() {
          _transactions = txList.map((t) => Map<String, dynamic>.from(t)).toList();
        });
      }
    } catch (e) {
      // Silently fail for transactions
    }
  }

  Future<void> _loadBalances() async {
    if (_walletAddress == null) return;
    
    try {
      final authService = context.read<AuthService>();
      final apiClient = ApiClient(authService: authService);
      
      final response = await apiClient.getAnalyticsBalances(_walletAddress!);
      
      if (response['success'] == true && response['data'] != null) {
        setState(() {
          _balances = Map<String, dynamic>.from(response['data']);
        });
      }
    } catch (e) {
      // Silently fail for balances
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
          _buildHeader(),

          // Error Message
          if (_errorMessage != null)
            _buildErrorBanner(),

          // Tab Bar
          _buildTabBar(),

          // Content
          _buildContent(),

          // Footer
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.analytics,
              color: Colors.teal,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Analytics',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_walletAddress != null)
                  Text(
                    '${_walletAddress!.substring(0, 6)}...${_walletAddress!.substring(_walletAddress!.length - 4)}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _loadWalletAndData,
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: widget.onDismiss,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(12),
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
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.teal.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.teal,
        unselectedLabelColor: Colors.white.withOpacity(0.5),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'Transactions'),
          Tab(text: 'Holdings'),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(40),
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
          ),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 380),
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildTransactionsTab(),
          _buildHoldingsTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    if (_activity == null) {
      return _buildEmptyState('No activity data available');
    }

    final totalTx = _activity!['totalTransactions'] ?? _activity!['transactionCount'] ?? 0;
    final firstTx = _activity!['firstTransaction'] ?? _activity!['firstActivity'];
    final lastTx = _activity!['lastTransaction'] ?? _activity!['lastActivity'];
    final solTransferred = _activity!['solTransferred'] ?? _activity!['totalSolTransferred'] ?? 0.0;
    final programsUsed = _activity!['programsUsed'] ?? _activity!['uniquePrograms'] ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Grid
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Txns',
                  totalTx.toString(),
                  Icons.receipt_long,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'SOL Moved',
                  '${_formatNumber(solTransferred)}',
                  Icons.swap_horiz,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Programs',
                  programsUsed is List ? programsUsed.length.toString() : '0',
                  Icons.apps,
                  Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Tokens',
                  _balances != null ? (_balances!['tokens'] as List?)?.length.toString() ?? '0' : '0',
                  Icons.token,
                  Colors.orange,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Timeline
          Text(
            'Activity Timeline',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          _buildTimelineItem('First Transaction', _formatDateTime(firstTx), Icons.play_arrow, Colors.green),
          _buildTimelineItem('Last Transaction', _formatDateTime(lastTx), Icons.stop, Colors.teal),
        ],
      ),
    );
  }

  Widget _buildTransactionsTab() {
    if (_transactions.isEmpty) {
      return _buildEmptyState('No transactions found');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _transactions.length,
      itemBuilder: (context, index) {
        final tx = _transactions[index];
        return _buildTransactionItem(tx);
      },
    );
  }

  Widget _buildHoldingsTab() {
    if (_balances == null) {
      return _buildEmptyState('No holdings data available');
    }

    final nativeBalance = _balances!['nativeBalance'] ?? _balances!['sol'] ?? 0.0;
    final tokens = (_balances!['tokens'] as List?)?.map((t) => Map<String, dynamic>.from(t)).toList() ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SOL Balance
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.purple.withOpacity(0.2),
                  Colors.blue.withOpacity(0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purple.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF9945FF), Color(0xFF14F195)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text(
                      'S',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Solana',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Native Balance',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${_formatNumber(nativeBalance)} SOL',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          if (tokens.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Token Holdings',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            ...tokens.take(10).map((token) => _buildTokenItem(token)),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(String label, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 11,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> tx) {
    final type = tx['type']?.toString() ?? tx['description']?.toString() ?? 'Transaction';
    final signature = tx['signature']?.toString() ?? '';
    final timestamp = tx['timestamp'] ?? tx['blockTime'];
    final fee = tx['fee'] ?? 0;
    final status = tx['status']?.toString() ?? 'confirmed';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _getTransactionColor(type).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getTransactionIcon(type),
              color: _getTransactionColor(type),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatTransactionType(type),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  signature.isNotEmpty 
                      ? '${signature.substring(0, 8)}...${signature.substring(signature.length - 6)}'
                      : 'Unknown',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: status == 'confirmed' || status == 'success'
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: status == 'confirmed' || status == 'success'
                        ? Colors.green
                        : Colors.red,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatTimestamp(timestamp),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTokenItem(Map<String, dynamic> token) {
    final name = token['tokenName'] ?? token['name'] ?? token['symbol'] ?? 'Unknown';
    final symbol = token['symbol'] ?? '';
    final balance = token['balance'] ?? token['amount'] ?? 0.0;
    final decimals = token['decimals'] ?? 9;
    final displayBalance = balance is num ? balance / (decimals > 0 ? (10 * decimals) : 1) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          TokenLogoService.buildTokenLogo(
            symbol: symbol,
            size: 32,
            fallbackColor: Colors.teal,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (symbol.isNotEmpty)
                  Text(
                    symbol,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            _formatNumber(displayBalance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 48,
              color: Colors.white.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: widget.onDismiss,
          icon: const Icon(Icons.close, size: 18),
          label: const Text('Close'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: BorderSide(
              color: Colors.white.withOpacity(0.2),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  // Helper methods
  String _formatNumber(dynamic value) {
    if (value == null) return '0';
    final num = double.tryParse(value.toString()) ?? 0.0;
    if (num >= 1000000) {
      return '${(num / 1000000).toStringAsFixed(2)}M';
    } else if (num >= 1000) {
      return '${(num / 1000).toStringAsFixed(2)}K';
    }
    return num.toStringAsFixed(4);
  }

  String _formatDateTime(dynamic value) {
    if (value == null) return 'Unknown';
    
    DateTime? date;
    if (value is int) {
      date = DateTime.fromMillisecondsSinceEpoch(value * 1000);
    } else if (value is String) {
      date = DateTime.tryParse(value);
    }
    
    if (date == null) return value.toString();
    
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatTimestamp(dynamic value) {
    if (value == null) return '';
    
    DateTime? date;
    if (value is int) {
      date = DateTime.fromMillisecondsSinceEpoch(value * 1000);
    } else if (value is String) {
      date = DateTime.tryParse(value);
    }
    
    if (date == null) return '';
    
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    
    return '${date.day}/${date.month}';
  }

  Color _getTransactionColor(String type) {
    final lowerType = type.toLowerCase();
    if (lowerType.contains('swap')) return Colors.blue;
    if (lowerType.contains('transfer') || lowerType.contains('send')) return Colors.orange;
    if (lowerType.contains('stake')) return Colors.purple;
    if (lowerType.contains('nft')) return Colors.pink;
    return Colors.teal;
  }

  IconData _getTransactionIcon(String type) {
    final lowerType = type.toLowerCase();
    if (lowerType.contains('swap')) return Icons.swap_horiz;
    if (lowerType.contains('transfer') || lowerType.contains('send')) return Icons.send;
    if (lowerType.contains('stake')) return Icons.savings;
    if (lowerType.contains('nft')) return Icons.image;
    return Icons.receipt_long;
  }

  String _formatTransactionType(String type) {
    return type
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }
}
