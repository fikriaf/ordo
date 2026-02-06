import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'auth_service.dart';

class ApiClient {
  // Production API - Railway backup
  static const String baseUrl = 'https://ordo-production.up.railway.app/api/v1';
  
  final AuthService authService;
  late final http.Client _client;
  
  ApiClient({required this.authService}) {
    // Create custom HTTP client that accepts all certificates
    final httpClient = HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    
    _client = IOClient(httpClient);
  }
  
  // Get headers with auth token
  Map<String, String> _getHeaders() {
    final headers = {
      'Content-Type': 'application/json',
    };
    
    // Add auth token if available
    if (authService.token != null) {
      headers['Authorization'] = 'Bearer ${authService.token}';
    }
    
    return headers;
  }
  
  // POST request
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final url = Uri.parse('$baseUrl$endpoint');
    
    try {
      print('🔵 POST to: $url');
      print('🔵 Body: ${jsonEncode(body)}');
      
      final response = await _client.post(
        url,
        headers: _getHeaders(),
        body: jsonEncode(body),
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          print('🔴 TIMEOUT after 60 seconds');
          throw Exception('Connection timeout after 60 seconds');
        },
      );
      
      print('🔵 Response status: ${response.statusCode}');
      print('🔵 Response body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('API Error: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      print('🔴 SocketException: $e');
      print('🔴 Address: ${e.address}');
      print('🔴 Port: ${e.port}');
      throw Exception('Network Error: Cannot connect to server. Check your internet connection.');
    } on HandshakeException catch (e) {
      print('🔴 HandshakeException (SSL): $e');
      throw Exception('SSL Error: Cannot establish secure connection.');
    } on TimeoutException catch (e) {
      print('🔴 TimeoutException: $e');
      throw Exception('Timeout: Server took too long to respond.');
    } catch (e) {
      print('🔴 POST error: $e');
      print('🔴 Error type: ${e.runtimeType}');
      throw Exception('Network Error: $e');
    }
  }
  
  // GET request
  Future<Map<String, dynamic>> get(String endpoint) async {
    final url = Uri.parse('$baseUrl$endpoint');
    
    try {
      final response = await _client.get(
        url,
        headers: _getHeaders(),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('API Error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network Error: $e');
    }
  }
  
  // Chat endpoint - NON-STREAMING (fallback)
  Future<Map<String, dynamic>> sendMessage(String message) async {
    return await post('/chat', {
      'message': message,
    });
  }
  
  // Chat endpoint - STREAMING with SSE
  Stream<String> sendMessageStream(String message) async* {
    final url = Uri.parse('$baseUrl/chat/stream');
    
    try {
      print('🔵 SSE POST to: $url');
      print('🔵 Message: $message');
      
      final request = http.Request('POST', url);
      request.headers.addAll(_getHeaders());
      request.headers['Accept'] = 'text/event-stream';
      request.body = jsonEncode({'message': message});
      
      final streamedResponse = await _client.send(request).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw Exception('Connection timeout after 60 seconds');
        },
      );
      
      print('🔵 SSE Response status: ${streamedResponse.statusCode}');
      
      if (streamedResponse.statusCode != 200) {
        throw Exception('API Error: ${streamedResponse.statusCode}');
      }
      
      // Buffer for incomplete SSE lines
      String buffer = '';
      
      // Parse SSE stream with proper buffering
      await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
        // Add chunk to buffer
        buffer += chunk;
        
        // Process complete lines (SSE format: "data: {...}\n\n")
        while (buffer.contains('\n\n')) {
          final endIndex = buffer.indexOf('\n\n');
          final completeEvent = buffer.substring(0, endIndex);
          buffer = buffer.substring(endIndex + 2);
          
          // Process each line in the event
          final lines = completeEvent.split('\n');
          for (final line in lines) {
            if (line.startsWith('data: ')) {
              final data = line.substring(6).trim();
              
              // Skip empty data
              if (data.isEmpty) continue;
              
              try {
                final json = jsonDecode(data);
                final type = json['type']?.toString();
                
                // Handle different event types from backend
                if (type == 'token') {
                  // Token streaming - yield content
                  final content = json['content']?.toString();
                  if (content != null && content.isNotEmpty) {
                    yield content;
                  }
                } else if (type == 'tool_call') {
                  // Tool call event - yield as marker
                  final toolName = json['toolName']?.toString() ?? 'tool';
                  yield '\n[Using $toolName...]\n';
                } else if (type == 'tool_result') {
                  // Tool result - yield result
                  final toolName = json['toolName']?.toString() ?? 'tool';
                  final hasError = json['error'] == true;
                  if (!hasError) {
                    yield '\n[✓ $toolName completed]\n';
                  }
                } else if (type == 'done') {
                  // Stream complete - yield the full structured response as JSON
                  print('🔵 SSE Stream completed');
                  print('🔵 Received structured done event');
                  // Yield the full done event as a special marker
                  yield '___DONE___${jsonEncode(json)}';
                  return; // Exit the stream
                } else if (type == 'error') {
                  // Error event - throw to be caught by controller
                  final error = json['error']?.toString() ?? 'Unknown error';
                  print('🔴 SSE Error event: $error');
                  throw Exception(error);
                } else if (type == 'start') {
                  // Start event - ignore
                  continue;
                }
              } catch (e) {
                if (e is FormatException) {
                  print('🔴 JSON parse error (will retry with more data): $e');
                  // Put incomplete data back in buffer to try again
                  // This shouldn't happen now with proper buffering
                } else {
                  print('🔴 Failed to parse SSE data: $e');
                  rethrow;
                }
              }
            }
          }
        }
      }
      
      print('🔵 SSE Stream finished');
      
    } on SocketException catch (e) {
      print('🔴 SocketException: $e');
      throw Exception('Network Error: Cannot connect to server');
    } on TimeoutException catch (e) {
      print('🔴 TimeoutException: $e');
      throw Exception('Timeout: Server took too long to respond');
    } catch (e) {
      print('🔴 SSE error: $e');
      throw Exception('Streaming Error: $e');
    }
  }
  
  // Auth endpoints
  Future<Map<String, dynamic>> login(String email, String password) async {
    return await post('/auth/login', {
      'email': email,
      'password': password,
    });
  }
  
  Future<Map<String, dynamic>> register(
    String email,
    String password,
    String name,
  ) async {
    return await post('/auth/register', {
      'email': email,
      'password': password,
      'name': name,
    });
  }
  
  // Refresh token
  Future<Map<String, dynamic>> refreshToken() async {
    return await post('/auth/refresh', {});
  }
  
  // ============================================
  // EVM WALLET MANAGEMENT
  // ============================================
  
  // Create EVM wallet
  Future<Map<String, dynamic>> createEvmWallet(String chainId) async {
    return await post('/wallet/evm/create', {
      'chainId': chainId,
    });
  }
  
  // Import EVM wallet
  Future<Map<String, dynamic>> importEvmWallet(String chainId, String privateKey) async {
    return await post('/wallet/evm/import', {
      'chainId': chainId,
      'privateKey': privateKey,
    });
  }
  
  // Get EVM wallet balance
  Future<Map<String, dynamic>> getEvmWalletBalance(String walletId) async {
    return await get('/wallet/evm/$walletId/balance');
  }
  
  // List EVM wallets
  Future<Map<String, dynamic>> getEvmWallets({String? chainId}) async {
    String endpoint = '/wallets/evm';
    if (chainId != null) {
      endpoint += '?chainId=$chainId';
    }
    return await get(endpoint);
  }
  
  // Transfer native EVM token (ETH, MATIC, BNB)
  Future<Map<String, dynamic>> transferEvmNative({
    required String walletId,
    required String toAddress,
    required double amount,
  }) async {
    return await post('/wallet/evm/transfer/native', {
      'walletId': walletId,
      'toAddress': toAddress,
      'amount': amount,
    });
  }
  
  // Transfer ERC-20 token
  Future<Map<String, dynamic>> transferEvmToken({
    required String walletId,
    required String toAddress,
    required String tokenAddress,
    required double amount,
  }) async {
    return await post('/wallet/evm/transfer/token', {
      'walletId': walletId,
      'toAddress': toAddress,
      'tokenAddress': tokenAddress,
      'amount': amount,
    });
  }
  
  // ============================================
  // SOLANA WALLET MANAGEMENT
  // ============================================
  
  // Create Solana wallet
  Future<Map<String, dynamic>> createWallet() async {
    return await post('/wallet/create', {});
  }
  
  // Import Solana wallet
  Future<Map<String, dynamic>> importWallet(String privateKey) async {
    return await post('/wallet/import', {
      'privateKey': privateKey,
    });
  }
  
  // Get wallet balance
  Future<Map<String, dynamic>> getWalletBalance(String walletId) async {
    return await get('/wallet/$walletId/balance');
  }
  
  // List wallets
  Future<Map<String, dynamic>> getWallets() async {
    return await get('/wallets');
  }
  
  // ============================================
  // TOKEN TRANSFERS
  // ============================================
  
  // Transfer SOL
  Future<Map<String, dynamic>> transferSol({
    required String walletId,
    required String toAddress,
    required double amount,
  }) async {
    return await post('/transfer/sol', {
      'walletId': walletId,
      'toAddress': toAddress,
      'amount': amount,
    });
  }
  
  // Transfer SPL Token
  Future<Map<String, dynamic>> transferToken({
    required String walletId,
    required String toAddress,
    required String tokenMint,
    required double amount,
    required int decimals,
  }) async {
    return await post('/transfer/token', {
      'walletId': walletId,
      'toAddress': toAddress,
      'tokenMint': tokenMint,
      'amount': amount,
      'decimals': decimals,
    });
  }
  
  // Validate transfer
  Future<Map<String, dynamic>> validateTransfer({
    required String walletId,
    required double amount,
    String? tokenMint,
  }) async {
    return await post('/transfer/validate', {
      'walletId': walletId,
      'amount': amount,
      if (tokenMint != null) 'tokenMint': tokenMint,
    });
  }
  
  // Get transfer fee
  Future<Map<String, dynamic>> getTransferFee({String? tokenMint}) async {
    String endpoint = '/transfer/fee';
    if (tokenMint != null) {
      endpoint += '?tokenMint=$tokenMint';
    }
    return await get(endpoint);
  }
  
  // ============================================
  // SWAP OPERATIONS (Jupiter)
  // ============================================
  
  // Get swap quote
  Future<Map<String, dynamic>> getSwapQuote({
    required String inputMint,
    required String outputMint,
    required double amount,
    int slippageBps = 50,
  }) async {
    return await get(
      '/swap/quote?inputMint=$inputMint&outputMint=$outputMint&amount=$amount&slippageBps=$slippageBps'
    );
  }
  
  // Execute swap
  Future<Map<String, dynamic>> executeSwap({
    required String walletId,
    required Map<String, dynamic> quoteResponse,
  }) async {
    return await post('/swap/execute', {
      'walletId': walletId,
      'quoteResponse': quoteResponse,
    });
  }
  
  // Get token price
  Future<Map<String, dynamic>> getTokenPrice(String tokenMint) async {
    return await get('/swap/price/$tokenMint');
  }
  
  // Get supported tokens
  Future<Map<String, dynamic>> getSwapTokens() async {
    return await get('/swap/tokens');
  }
  
  // Validate swap
  Future<Map<String, dynamic>> validateSwap({
    required String walletId,
    required String inputMint,
    required double amount,
  }) async {
    return await post('/swap/validate', {
      'walletId': walletId,
      'inputMint': inputMint,
      'amount': amount,
    });
  }
  
  // ============================================
  // STAKING OPERATIONS
  // ============================================
  
  // Stake tokens
  Future<Map<String, dynamic>> stake({
    required String walletId,
    required double amount,
    required String protocol, // marinade, jito, sanctum
  }) async {
    return await post('/stake', {
      'walletId': walletId,
      'amount': amount,
      'protocol': protocol,
    });
  }
  
  // Unstake tokens
  Future<Map<String, dynamic>> unstake({
    required String walletId,
    required double amount,
    required String protocol,
    String? stakeAccountAddress,
  }) async {
    return await post('/stake/unstake', {
      'walletId': walletId,
      'amount': amount,
      'protocol': protocol,
      if (stakeAccountAddress != null) 'stakeAccountAddress': stakeAccountAddress,
    });
  }
  
  // Get staking positions
  Future<Map<String, dynamic>> getStakingPositions(String walletId) async {
    return await get('/stake/positions?walletId=$walletId');
  }
  
  // Get staking rewards
  Future<Map<String, dynamic>> getStakingRewards(String walletId) async {
    return await get('/stake/rewards?walletId=$walletId');
  }
  
  // Get APY rates
  Future<Map<String, dynamic>> getStakingApy() async {
    return await get('/stake/apy');
  }
  
  // ============================================
  // LENDING & BORROWING
  // ============================================
  
  // Lend assets
  Future<Map<String, dynamic>> lend({
    required String walletId,
    required double amount,
    required String asset,
    required String protocol, // kamino, marginfi, solend
  }) async {
    return await post('/lend', {
      'walletId': walletId,
      'amount': amount,
      'asset': asset,
      'protocol': protocol,
    });
  }
  
  // Borrow assets
  Future<Map<String, dynamic>> borrow({
    required String walletId,
    required double amount,
    required String asset,
    required String collateralAsset,
    required double collateralAmount,
    required String protocol,
  }) async {
    return await post('/lend/borrow', {
      'walletId': walletId,
      'amount': amount,
      'asset': asset,
      'collateralAsset': collateralAsset,
      'collateralAmount': collateralAmount,
      'protocol': protocol,
    });
  }
  
  // Repay loan
  Future<Map<String, dynamic>> repayLoan({
    required String walletId,
    required double amount,
    required String asset,
    required String protocol,
    String? loanId,
  }) async {
    return await post('/lend/repay', {
      'walletId': walletId,
      'amount': amount,
      'asset': asset,
      'protocol': protocol,
      if (loanId != null) 'loanId': loanId,
    });
  }
  
  // Withdraw lent assets
  Future<Map<String, dynamic>> withdrawLent({
    required String walletId,
    required double amount,
    required String asset,
    required String protocol,
    String? positionId,
  }) async {
    return await post('/lend/withdraw', {
      'walletId': walletId,
      'amount': amount,
      'asset': asset,
      'protocol': protocol,
      if (positionId != null) 'positionId': positionId,
    });
  }
  
  // Get lending positions
  Future<Map<String, dynamic>> getLendingPositions(String walletId) async {
    return await get('/lend/positions?walletId=$walletId');
  }
  
  // Get interest rates
  Future<Map<String, dynamic>> getLendingRates() async {
    return await get('/lend/rates');
  }
  
  // ============================================
  // NFT OPERATIONS
  // ============================================
  
  // Mint NFT
  Future<Map<String, dynamic>> mintNft({
    required String walletId,
    required String name,
    required String symbol,
    required String uri,
    int sellerFeeBasisPoints = 500,
    List<Map<String, dynamic>>? creators,
  }) async {
    return await post('/nft/mint', {
      'walletId': walletId,
      'name': name,
      'symbol': symbol,
      'uri': uri,
      'sellerFeeBasisPoints': sellerFeeBasisPoints,
      if (creators != null) 'creators': creators,
    });
  }
  
  // Transfer NFT
  Future<Map<String, dynamic>> transferNft({
    required String walletId,
    required String mintAddress,
    required String toAddress,
  }) async {
    return await post('/nft/transfer', {
      'walletId': walletId,
      'mintAddress': mintAddress,
      'toAddress': toAddress,
    });
  }
  
  // Burn NFT
  Future<Map<String, dynamic>> burnNft({
    required String walletId,
    required String mintAddress,
  }) async {
    return await post('/nft/burn', {
      'walletId': walletId,
      'mintAddress': mintAddress,
    });
  }
  
  // Get user NFTs
  Future<Map<String, dynamic>> getUserNfts({int limit = 100}) async {
    return await get('/nft/user?limit=$limit');
  }
  
  // Get NFTs by wallet
  Future<Map<String, dynamic>> getNftsByWallet(String address, {int limit = 100}) async {
    return await get('/nft/wallet/$address?limit=$limit');
  }
  
  // Get NFT metadata
  Future<Map<String, dynamic>> getNftMetadata(String mintAddress) async {
    return await get('/nft/metadata/$mintAddress');
  }
  
  // Get collection info
  Future<Map<String, dynamic>> getNftCollection(String collectionAddress) async {
    return await get('/nft/collection/$collectionAddress');
  }
  
  // Get NFT portfolio value
  Future<Map<String, dynamic>> getNftPortfolioValue() async {
    return await get('/nft/portfolio/value');
  }
  
  // ============================================
  // TOKEN RISK SCORING
  // ============================================
  
  // Get token risk score
  Future<Map<String, dynamic>> getTokenRisk(String tokenAddress) async {
    return await get('/tokens/$tokenAddress/risk');
  }
  
  // Analyze token
  Future<Map<String, dynamic>> analyzeToken(String tokenAddress) async {
    return await post('/tokens/$tokenAddress/analyze', {});
  }
  
  // Search tokens
  Future<Map<String, dynamic>> searchTokens(String query, {int limit = 10}) async {
    return await get('/tokens/search?q=$query&limit=$limit');
  }
  
  // Get risky tokens
  Future<Map<String, dynamic>> getRiskyTokens({int limit = 20}) async {
    return await get('/tokens/risky?limit=$limit');
  }
  
  // ============================================
  // USER PREFERENCES
  // ============================================
  
  // Get preferences
  Future<Map<String, dynamic>> getPreferences() async {
    return await get('/preferences');
  }
  
  // Update preferences
  Future<Map<String, dynamic>> updatePreferences(Map<String, dynamic> preferences) async {
    return await put('/preferences', preferences);
  }
  
  // Reset preferences
  Future<Map<String, dynamic>> resetPreferences() async {
    return await post('/preferences/reset', {});
  }
  
  // PUT request
  Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final url = Uri.parse('$baseUrl$endpoint');
    
    try {
      print('🔵 PUT to: $url');
      print('🔵 Body: ${jsonEncode(body)}');
      
      final response = await _client.put(
        url,
        headers: _getHeaders(),
        body: jsonEncode(body),
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          print('🔴 TIMEOUT after 60 seconds');
          throw Exception('Connection timeout after 60 seconds');
        },
      );
      
      print('🔵 Response status: ${response.statusCode}');
      print('🔵 Response body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('API Error: ${response.statusCode}');
      }
    } catch (e) {
      print('🔴 PUT error: $e');
      throw Exception('Network Error: $e');
    }
  }
  
  // ============================================
  // APPROVAL QUEUE
  // ============================================
  
  // Get pending approvals
  Future<Map<String, dynamic>> getPendingApprovals() async {
    return await get('/approvals/pending');
  }
  
  // Get approval details
  Future<Map<String, dynamic>> getApprovalDetails(String approvalId) async {
    return await get('/approvals/$approvalId');
  }
  
  // Approve request
  Future<Map<String, dynamic>> approveRequest(String approvalId) async {
    return await post('/approvals/$approvalId/approve', {});
  }
  
  // Reject request
  Future<Map<String, dynamic>> rejectRequest(String approvalId, {String? reason}) async {
    return await post('/approvals/$approvalId/reject', {
      if (reason != null) 'reason': reason,
    });
  }
  
  // Get approval history
  Future<Map<String, dynamic>> getApprovalHistory({
    String? status,
    String? requestType,
    String? startDate,
    String? endDate,
    int page = 1,
    int limit = 20,
  }) async {
    String endpoint = '/approvals/history?page=$page&limit=$limit';
    if (status != null) endpoint += '&status=$status';
    if (requestType != null) endpoint += '&request_type=$requestType';
    if (startDate != null) endpoint += '&start_date=$startDate';
    if (endDate != null) endpoint += '&end_date=$endDate';
    return await get(endpoint);
  }
  
  // ============================================
  // ANALYTICS (Helius)
  // ============================================
  
  // Get enhanced transactions
  Future<Map<String, dynamic>> getEnhancedTransactions(String address, {int limit = 10}) async {
    return await get('/analytics/transactions/$address?limit=$limit');
  }
  
  // Get parsed transaction
  Future<Map<String, dynamic>> getParsedTransaction(String signature) async {
    return await get('/analytics/transaction/$signature');
  }
  
  // Get token metadata
  Future<Map<String, dynamic>> getTokenMetadata(String mintAddress) async {
    return await get('/analytics/token/$mintAddress');
  }
  
  // Get NFTs by owner (Helius)
  Future<Map<String, dynamic>> getAnalyticsNfts(String address, {int limit = 100}) async {
    return await get('/analytics/nfts/$address?limit=$limit');
  }
  
  // Get token balances with metadata
  Future<Map<String, dynamic>> getAnalyticsBalances(String address) async {
    return await get('/analytics/balances/$address');
  }
  
  // Search assets
  Future<Map<String, dynamic>> searchAssets(String query, {int limit = 20}) async {
    return await get('/analytics/search?q=$query&limit=$limit');
  }
  
  // Get address activity
  Future<Map<String, dynamic>> getAddressActivity(String address) async {
    return await get('/analytics/activity/$address');
  }
  
  // ============================================
  // TRANSACTION HISTORY
  // ============================================
  
  // Get transaction history
  Future<Map<String, dynamic>> getTransactionHistory({
    int page = 1,
    int limit = 10,
    String? type,
    String? status,
    String? startDate,
    String? endDate,
  }) async {
    String endpoint = '/transactions?page=$page&limit=$limit';
    if (type != null) endpoint += '&type=$type';
    if (status != null) endpoint += '&status=$status';
    if (startDate != null) endpoint += '&startDate=$startDate';
    if (endDate != null) endpoint += '&endDate=$endDate';
    return await get(endpoint);
  }
  
  // Get transaction details
  Future<Map<String, dynamic>> getTransactionDetails(String transactionId) async {
    return await get('/transactions/$transactionId');
  }
  
  // ============================================
  // HEALTH CHECK
  // ============================================
  
  // Basic health check
  Future<Map<String, dynamic>> healthCheck() async {
    return await get('/health');
  }
  
  // Detailed health check
  Future<Map<String, dynamic>> healthCheckDetailed() async {
    return await get('/health/detailed');
  }
  
  // ============================================
  // CONVERSATIONS
  // ============================================
  
  // Get conversations
  Future<Map<String, dynamic>> getConversations() async {
    return await get('/conversations');
  }
  
  // Get conversation messages
  Future<Map<String, dynamic>> getConversationMessages(String conversationId) async {
    return await get('/conversations/$conversationId/messages');
  }
}
