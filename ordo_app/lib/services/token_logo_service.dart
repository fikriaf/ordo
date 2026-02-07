import 'package:flutter/material.dart';

/// Service untuk mendapatkan logo token dari berbagai sumber
class TokenLogoService {
  // Token logo URLs dari berbagai CDN
  static const String _solanaLogosCDN = 'https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet';
  static const String _cryptoIconsCDN = 'https://cryptologos.cc/logos';
  static const String _coinGeckoCDN = 'https://assets.coingecko.com/coins/images';
  
  /// Mapping token symbols ke logo URLs
  static final Map<String, String> _tokenLogos = {
    // Solana Native
    'SOL': 'https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/So11111111111111111111111111111111111111112/logo.png',
    'WSOL': 'https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/So11111111111111111111111111111111111111112/logo.png',
    
    // Stablecoins
    'USDC': 'https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v/logo.png',
    'USDT': 'https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB/logo.svg',
    'PYUSD': 'https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/2b1kV6DkPAnxd5ixfnxCpjxmKwqjjaYmCZfHsFu24GXo/logo.png',
    'DAI': 'https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/EjmyN6qEC1Tf1JxiG1ae7UTJhUxSwk1TCWNWqxWV4J6o/logo.png',
    
    // Major Solana Tokens
    'BONK': 'https://arweave.net/hQiPZOsRZXGXBJd_82PhVdlM_hACsT_q6wqwf5cSY7I',
    'JTO': 'https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/jtojtomepa8beP8AuQc6eXt5FriJwfFMwQx2v2f9mCL/logo.png',
    'PYTH': 'https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/HZ1JovNiVvGrGNiiYvEozEVgZ58xaU3RKwX8eACQBCt3/logo.png',
    'WIF': 'https://bafkreibk3covs5ltyqxa272uodhculbr6kea6betidfwy3ajsav2vjzyum.ipfs.nftstorage.link',
    'JUP': 'https://static.jup.ag/jup/icon.png',
    'RAY': 'https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/4k3Dyjzvzp8eMZWUXbBCjEvwSkkk59S5iCNLY3QrkX6R/logo.png',
    'ORCA': 'https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/orcaEKTdK7LKz57vaAYr9QeNsVEPfiu6QeMU1kektZE/logo.png',
    'MNGO': 'https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/MangoCzJ36AjZyKwVj3VnYU4GTonjfVEnJmvvWaxLac/logo.png',
    'SRM': 'https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/SRMuApVNdxXokk5GT7XD5cUUgXMBCoAz2LHeuAoKWRt/logo.png',
    'STEP': 'https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/StepAscQoEioFxxWGnh2sLBDFp9d8rvKz2Yp39iDpyT/logo.png',
    'COPE': 'https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/8HGyAAB1yoM1ttS7pXjHMa3dukTFGQggnFFH3hJZgzQh/logo.png',
    'FIDA': 'https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/EchesyfXePKdLtoiZSL8pBe8Myagyy8ZRqsACNCFGnvp/logo.svg',
    'SAMO': 'https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU/logo.png',
    'SHDW': 'https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/SHDWyBxihqiCj6YekG2GUr7wqKLeLAMK1gHZck9pL6y/logo.png',
    'RENDER': 'https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/rndrizKT3MK1iimdxRdWabcF7Zg7AR5T4nud4EkHBof/logo.png',
    
    // Wrapped Tokens
    'WBTC': 'https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/3NZ9JMVBmGAqocybic2c7LQCJScmgsAZ6vQqTDzcqmJh/logo.png',
    'WETH': 'https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/7vfCXTUXx5WJV5JADk17DUJ4ksgau7utNKj4b963voxs/logo.png',
    
    // EVM Chains
    'ETH': 'https://cryptologos.cc/logos/ethereum-eth-logo.png',
    'MATIC': 'https://cryptologos.cc/logos/polygon-matic-logo.png',
    'BNB': 'https://cryptologos.cc/logos/bnb-bnb-logo.png',
    'AVAX': 'https://cryptologos.cc/logos/avalanche-avax-logo.png',
    'FTM': 'https://cryptologos.cc/logos/fantom-ftm-logo.png',
    'ARB': 'https://cryptologos.cc/logos/arbitrum-arb-logo.png',
    'OP': 'https://cryptologos.cc/logos/optimism-ethereum-op-logo.png',
    
    // Bitcoin
    'BTC': 'https://cryptologos.cc/logos/bitcoin-btc-logo.png',
  };
  
  /// Mapping chain IDs ke logo URLs
  static final Map<String, String> _chainLogos = {
    'ethereum': 'https://cryptologos.cc/logos/ethereum-eth-logo.png',
    'polygon': 'https://cryptologos.cc/logos/polygon-matic-logo.png',
    'bsc': 'https://cryptologos.cc/logos/bnb-bnb-logo.png',
    'binance': 'https://cryptologos.cc/logos/bnb-bnb-logo.png',
    'avalanche': 'https://cryptologos.cc/logos/avalanche-avax-logo.png',
    'fantom': 'https://cryptologos.cc/logos/fantom-ftm-logo.png',
    'arbitrum': 'https://cryptologos.cc/logos/arbitrum-arb-logo.png',
    'optimism': 'https://cryptologos.cc/logos/optimism-ethereum-op-logo.png',
    'solana': 'https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/So11111111111111111111111111111111111111112/logo.png',
  };
  
  /// Get token logo URL by symbol
  static String? getTokenLogoUrl(String symbol) {
    final upperSymbol = symbol.toUpperCase();
    return _tokenLogos[upperSymbol];
  }
  
  /// Get chain logo URL by chain ID
  static String? getChainLogoUrl(String chainId) {
    return _chainLogos[chainId.toLowerCase()];
  }
  
  /// Build token logo widget with fallback
  static Widget buildTokenLogo({
    required String symbol,
    double size = 40,
    Color? fallbackColor,
    Color? borderColor,
  }) {
    final logoUrl = getTokenLogoUrl(symbol);
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: borderColor != null
            ? Border.all(color: borderColor, width: 1)
            : null,
      ),
      child: ClipOval(
        child: logoUrl != null
            ? Image.network(
                logoUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback to first letter if image fails
                  return _buildFallbackLogo(symbol, size, fallbackColor);
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return _buildFallbackLogo(symbol, size, fallbackColor);
                },
              )
            : _buildFallbackLogo(symbol, size, fallbackColor),
      ),
    );
  }
  
  /// Build chain logo widget with fallback
  static Widget buildChainLogo({
    required String chainId,
    double size = 24,
    Color? fallbackColor,
  }) {
    final logoUrl = getChainLogoUrl(chainId);
    
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: logoUrl != null
            ? Image.network(
                logoUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildFallbackLogo(chainId, size, fallbackColor);
                },
              )
            : _buildFallbackLogo(chainId, size, fallbackColor),
      ),
    );
  }
  
  /// Build fallback logo with first letter
  static Widget _buildFallbackLogo(String text, double size, Color? color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: (color ?? const Color(0xFF6366F1)).withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          text.isNotEmpty ? text[0].toUpperCase() : '?',
          style: TextStyle(
            color: color ?? const Color(0xFF6366F1),
            fontWeight: FontWeight.w700,
            fontSize: size * 0.4,
          ),
        ),
      ),
    );
  }
  
  /// Check if token logo exists
  static bool hasTokenLogo(String symbol) {
    return _tokenLogos.containsKey(symbol.toUpperCase());
  }
  
  /// Check if chain logo exists
  static bool hasChainLogo(String chainId) {
    return _chainLogos.containsKey(chainId.toLowerCase());
  }
}
