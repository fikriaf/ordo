import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';

class NftGalleryPanel extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onDismiss;

  const NftGalleryPanel({
    super.key,
    required this.data,
    required this.onDismiss,
  });

  @override
  State<NftGalleryPanel> createState() => _NftGalleryPanelState();
}

class _NftGalleryPanelState extends State<NftGalleryPanel> {
  List<Map<String, dynamic>> _nfts = [];
  double _totalValue = 0.0;
  bool _isLoading = true;
  String? _errorMessage;
  String? _successMessage;
  Map<String, dynamic>? _selectedNft;
  bool _isActionLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize from widget data if available
    final nftsFromData = (widget.data['nfts'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (nftsFromData.isNotEmpty) {
      _nfts = nftsFromData;
      _totalValue = (widget.data['totalValue'] as num?)?.toDouble() ?? 0.0;
      _isLoading = false;
    } else {
      _loadNfts();
    }
  }

  Future<void> _loadNfts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = context.read<AuthService>();
      final apiClient = ApiClient(authService: authService);
      
      final response = await apiClient.getUserNfts();
      
      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];
        List<dynamic> nftsList = [];
        
        if (data is List) {
          nftsList = data;
        } else if (data is Map) {
          nftsList = data['nfts'] as List? ?? [];
          _totalValue = (data['totalValue'] as num?)?.toDouble() ?? 0.0;
        }
        
        setState(() {
          _nfts = nftsList.map((n) => Map<String, dynamic>.from(n)).toList();
        });
        
        // Try to get portfolio value if not already set
        if (_totalValue == 0.0) {
          try {
            final valueResponse = await apiClient.getNftPortfolioValue();
            if (valueResponse['success'] == true) {
              setState(() {
                _totalValue = (valueResponse['data']?['totalValue'] as num?)?.toDouble() ?? 0.0;
              });
            }
          } catch (_) {
            // Ignore portfolio value error
          }
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load NFTs: ${e.toString().replaceAll('Exception: ', '')}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
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
          _buildHeader(),

          // Error/Success Messages
          if (_errorMessage != null)
            _buildMessageBanner(_errorMessage!, isError: true),
          if (_successMessage != null)
            _buildMessageBanner(_successMessage!, isError: false),

          // Summary
          _buildSummary(),

          const SizedBox(height: 16),

          // NFT Grid or Loading/Empty State
          _buildContent(),

          const SizedBox(height: 16),

          // Action Buttons
          _buildActionButtons(),

          const SizedBox(height: 20),
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
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.photo_library,
              color: AppTheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'NFT Gallery',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Mint NFT button
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add, color: Colors.green, size: 20),
            ),
            onPressed: _showMintDialog,
            tooltip: 'Mint NFT',
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: widget.onDismiss,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBanner(String message, {required bool isError}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isError ? Colors.red : Colors.green).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isError ? Colors.red : Colors.green).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError ? Colors.red : Colors.green,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isError ? Colors.red : Colors.green,
                fontSize: 13,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            color: isError ? Colors.red : Colors.green,
            onPressed: () {
              setState(() {
                if (isError) {
                  _errorMessage = null;
                } else {
                  _successMessage = null;
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${_nfts.length} NFTs',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '•',
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '\$${_totalValue.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'est',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
            ),
          ),
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
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
          ),
        ),
      );
    }

    if (_nfts.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 400),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.75,
          ),
          itemCount: _nfts.length,
          itemBuilder: (context, index) {
            final nft = _nfts[index];
            return _buildNftCard(nft);
          },
        ),
      ),
    );
  }

  Widget _buildNftCard(Map<String, dynamic> nft) {
    final name = nft['name']?.toString() ?? 'Unknown NFT';
    final floorPrice = (nft['floorPrice'] as num?)?.toDouble() ?? 0.0;
    final imageUrl = nft['image']?.toString() ?? '';
    final mintAddress = nft['mintAddress']?.toString() ?? nft['mint']?.toString() ?? '';
    final isSelected = _selectedNft?['mintAddress'] == mintAddress || _selectedNft?['mint'] == mintAddress;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedNft = null;
          } else {
            _selectedNft = nft;
          }
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primary : Colors.white.withOpacity(0.05),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: imageUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                            child: Image.network(
                              imageUrl,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildPlaceholderImage();
                              },
                            ),
                          )
                        : _buildPlaceholderImage(),
                  ),
                  
                  // Selection indicator
                  if (isSelected)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  
                  // Gradient overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            AppTheme.surface.withOpacity(0.9),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Info
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Floor',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${floorPrice.toStringAsFixed(2)} SOL',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  
                  // Action buttons for selected NFT
                  if (isSelected) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildNftActionButton(
                            icon: Icons.send,
                            label: 'Send',
                            color: Colors.blue,
                            onPressed: () => _showSendDialog(nft),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildNftActionButton(
                            icon: Icons.local_fire_department,
                            label: 'Burn',
                            color: Colors.red,
                            onPressed: () => _showBurnDialog(nft),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNftActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: _isActionLoading ? null : onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 12),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Center(
      child: Icon(
        Icons.image,
        size: 48,
        color: Colors.white.withOpacity(0.2),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
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
              Icons.photo_library_outlined,
              color: AppTheme.primary,
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No NFTs Found',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your NFT collection will appear here\nwhen you own some NFTs.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _showMintDialog,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Mint Your First NFT'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
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
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _loadNfts,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.background),
                      ),
                    )
                  : const Icon(Icons.refresh, size: 18),
              label: Text(_isLoading ? 'Loading...' : 'Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.background,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // NFT Action Dialogs
  // ============================================

  void _showMintDialog() {
    final nameController = TextEditingController();
    final symbolController = TextEditingController();
    final uriController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add_photo_alternate, color: Colors.green, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Mint NFT', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogTextField(nameController, 'NFT Name', Icons.title),
              const SizedBox(height: 12),
              _buildDialogTextField(symbolController, 'Symbol', Icons.label),
              const SizedBox(height: 12),
              _buildDialogTextField(uriController, 'Metadata URI', Icons.link),
              const SizedBox(height: 8),
              Text(
                'Enter the URI to your NFT metadata (JSON file with image, description, etc.)',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.7))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _mintNft(
                name: nameController.text.trim(),
                symbol: symbolController.text.trim(),
                uri: uriController.text.trim(),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Mint'),
          ),
        ],
      ),
    );
  }

  void _showSendDialog(Map<String, dynamic> nft) {
    final addressController = TextEditingController();
    final nftName = nft['name']?.toString() ?? 'NFT';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.send, color: Colors.blue, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Send $nftName',
                style: const TextStyle(color: Colors.white, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogTextField(addressController, 'Recipient Address', Icons.account_balance_wallet),
            const SizedBox(height: 8),
            Text(
              'Enter the Solana wallet address to send this NFT to.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.7))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _sendNft(nft, addressController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showBurnDialog(Map<String, dynamic> nft) {
    final nftName = nft['name']?.toString() ?? 'NFT';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.local_fire_department, color: Colors.red, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Burn $nftName',
                style: const TextStyle(color: Colors.white, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action is irreversible!',
                      style: TextStyle(
                        color: Colors.red.withOpacity(0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Are you sure you want to permanently destroy this NFT? This cannot be undone.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 13,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.7))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _burnNft(nft);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Burn NFT'),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogTextField(TextEditingController controller, String hint, IconData icon) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
        prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.5), size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  // ============================================
  // NFT API Operations
  // ============================================

  Future<void> _mintNft({
    required String name,
    required String symbol,
    required String uri,
  }) async {
    if (name.isEmpty || symbol.isEmpty || uri.isEmpty) {
      setState(() {
        _errorMessage = 'Please fill in all fields';
      });
      return;
    }

    setState(() {
      _isActionLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final authService = context.read<AuthService>();
      final apiClient = ApiClient(authService: authService);
      
      // Get wallet ID
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
      final walletId = primaryWallet['id'] as String;
      
      final response = await apiClient.mintNft(
        walletId: walletId,
        name: name,
        symbol: symbol,
        uri: uri,
      );
      
      if (response['success'] == true) {
        final mintAddress = response['data']?['mintAddress'] ?? response['mintAddress'];
        setState(() {
          _successMessage = 'Successfully minted NFT "$name"!\nMint: ${_shortenAddress(mintAddress?.toString() ?? '')}';
        });
        _loadNfts(); // Refresh the list
      } else {
        throw Exception(response['error'] ?? 'Mint failed');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isActionLoading = false;
        });
      }
    }
  }

  Future<void> _sendNft(Map<String, dynamic> nft, String toAddress) async {
    if (toAddress.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a recipient address';
      });
      return;
    }

    final mintAddress = nft['mintAddress']?.toString() ?? nft['mint']?.toString();
    if (mintAddress == null || mintAddress.isEmpty) {
      setState(() {
        _errorMessage = 'Invalid NFT mint address';
      });
      return;
    }

    setState(() {
      _isActionLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final authService = context.read<AuthService>();
      final apiClient = ApiClient(authService: authService);
      
      // Get wallet ID
      final walletsResponse = await apiClient.getWallets();
      if (walletsResponse['success'] != true || walletsResponse['data'] == null) {
        throw Exception('Failed to get wallets');
      }
      
      final wallets = walletsResponse['data'] as List;
      if (wallets.isEmpty) {
        throw Exception('No wallet found');
      }
      
      final primaryWallet = wallets.firstWhere(
        (w) => w['isPrimary'] == true,
        orElse: () => wallets.first,
      );
      final walletId = primaryWallet['id'] as String;
      
      final response = await apiClient.transferNft(
        walletId: walletId,
        mintAddress: mintAddress,
        toAddress: toAddress,
      );
      
      if (response['success'] == true) {
        setState(() {
          _successMessage = 'Successfully sent "${nft['name'] ?? 'NFT'}" to ${_shortenAddress(toAddress)}';
          _selectedNft = null;
        });
        _loadNfts(); // Refresh the list
      } else {
        throw Exception(response['error'] ?? 'Transfer failed');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isActionLoading = false;
        });
      }
    }
  }

  Future<void> _burnNft(Map<String, dynamic> nft) async {
    final mintAddress = nft['mintAddress']?.toString() ?? nft['mint']?.toString();
    if (mintAddress == null || mintAddress.isEmpty) {
      setState(() {
        _errorMessage = 'Invalid NFT mint address';
      });
      return;
    }

    setState(() {
      _isActionLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final authService = context.read<AuthService>();
      final apiClient = ApiClient(authService: authService);
      
      // Get wallet ID
      final walletsResponse = await apiClient.getWallets();
      if (walletsResponse['success'] != true || walletsResponse['data'] == null) {
        throw Exception('Failed to get wallets');
      }
      
      final wallets = walletsResponse['data'] as List;
      if (wallets.isEmpty) {
        throw Exception('No wallet found');
      }
      
      final primaryWallet = wallets.firstWhere(
        (w) => w['isPrimary'] == true,
        orElse: () => wallets.first,
      );
      final walletId = primaryWallet['id'] as String;
      
      final response = await apiClient.burnNft(
        walletId: walletId,
        mintAddress: mintAddress,
      );
      
      if (response['success'] == true) {
        setState(() {
          _successMessage = 'Successfully burned "${nft['name'] ?? 'NFT'}"';
          _selectedNft = null;
        });
        _loadNfts(); // Refresh the list
      } else {
        throw Exception(response['error'] ?? 'Burn failed');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isActionLoading = false;
        });
      }
    }
  }

  String _shortenAddress(String address) {
    if (address.length > 12) {
      return '${address.substring(0, 6)}...${address.substring(address.length - 6)}';
    }
    return address;
  }
}
