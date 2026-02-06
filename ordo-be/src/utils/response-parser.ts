/**
 * Response Parser Utility
 * 
 * Parses AI responses and tool results into a standardized format
 * that the frontend can easily consume and display.
 */

import logger from '../config/logger';

// Standard action types that frontend can handle
export type ActionType = 
  // Portfolio
  | 'check_balance'
  | 'show_portfolio'
  // Token Operations
  | 'token_info'
  | 'token_risk'
  | 'token_price'
  // Transfers
  | 'send_sol'
  | 'send_token'
  | 'deposit'
  // Swaps
  | 'swap_tokens'
  | 'get_swap_quote'
  // DeFi
  | 'stake'
  | 'unstake'
  | 'lend'
  | 'borrow'
  | 'add_liquidity'
  | 'remove_liquidity'
  | 'bridge'
  // NFT
  | 'show_nfts'
  | 'mint_nft'
  | 'send_nft'
  // Wallet Management
  | 'create_wallet'
  | 'import_wallet'
  | 'switch_wallet'
  | 'manage_wallets'
  | 'manage_evm_wallets'
  | 'delete_wallet'
  // Settings
  | 'show_preferences'
  | 'set_limit'
  | 'set_slippage'
  | 'show_security_settings'
  | 'network_settings'
  | 'faucet'
  // History
  | 'show_transactions'
  | 'show_command_history'
  | 'show_approval_history'
  // Analytics
  | 'show_analytics'
  | 'show_activity'
  // Approval
  | 'requires_approval'
  // Generic
  | 'info'
  | 'error'
  | 'unknown';

// Response status
export type ResponseStatus = 'success' | 'error' | 'pending' | 'requires_approval';

// Structured response format
export interface StructuredResponse {
  conversationId: string;
  actionType: ActionType;
  status: ResponseStatus;
  summary: string;
  details: Record<string, any>;
  toolsUsed: string[];
  rawMessage?: string;
}

// Tool result from AI agent
export interface ToolResult {
  id: string;
  name: string;
  result?: any;
  error?: string;
}

// Tool name to action type mapping
const TOOL_ACTION_MAP: Record<string, ActionType> = {
  // Balance/Portfolio
  'get_balance': 'check_balance',
  'get_portfolio': 'show_portfolio',
  'get_wallet_balance': 'check_balance',
  'check_balance': 'check_balance',
  'portfolio': 'show_portfolio',
  'get_nft_portfolio_value': 'show_portfolio',
  
  // Token Operations
  'get_token_info': 'token_info',
  'analyze_token': 'token_info',
  'get_token_price': 'token_price',
  'token_price': 'token_price',
  'get_risk_score': 'token_risk',
  'risk_score': 'token_risk',
  'get_token_risk': 'token_risk',
  'analyze_token_risk': 'token_risk',
  'get_high_risk_tokens': 'token_risk',
  'get_sol_price': 'token_price',
  'search_tokens': 'token_info',
  'get_token_metadata': 'token_info',
  'get_nft_metadata': 'token_info',
  
  // Transfers
  'send_sol': 'send_sol',
  'transfer_sol': 'send_sol',
  'send_token': 'send_token',
  'transfer_token': 'send_token',
  'transfer_evm_native': 'send_token',
  'transfer_evm_token': 'send_token',
  
  // Swaps
  'swap': 'swap_tokens',
  'swap_tokens': 'swap_tokens',
  'get_swap_quote': 'get_swap_quote',
  'quote': 'get_swap_quote',
  
  // DeFi - Staking
  'stake': 'stake',
  'stake_sol': 'stake',
  'unstake': 'unstake',
  'unstake_sol': 'unstake',
  
  // DeFi - Lending/Borrowing
  'lend': 'lend',
  'lend_assets': 'lend',
  'borrow': 'borrow',
  'borrow_assets': 'borrow',
  'repay_loan': 'lend',
  'get_lending_positions': 'lend',
  'get_interest_rates': 'lend',
  
  // DeFi - Liquidity
  'add_liquidity': 'add_liquidity',
  'remove_liquidity': 'remove_liquidity',
  'get_lp_positions': 'add_liquidity',
  'get_position_value': 'add_liquidity',
  'calculate_impermanent_loss': 'add_liquidity',
  
  // DeFi - Bridge
  'bridge': 'bridge',
  'bridge_assets': 'bridge',
  'get_bridge_quote': 'bridge',
  'get_bridge_status': 'bridge',
  'get_supported_chains': 'bridge',
  
  // NFT
  'get_nfts': 'show_nfts',
  'show_nfts': 'show_nfts',
  'get_user_nfts': 'show_nfts',
  'mint_nft': 'mint_nft',
  'send_nft': 'send_nft',
  
  // Wallet Management
  'create_wallet': 'create_wallet',
  'create_solana_wallet': 'create_wallet',
  'import_solana_wallet': 'import_wallet',
  'get_solana_balance': 'check_balance',
  'list_solana_wallets': 'manage_wallets',
  'set_primary_solana_wallet': 'manage_wallets',
  'delete_solana_wallet': 'delete_wallet',
  'delete_solana_wallets': 'delete_wallet',
  'create_evm_wallet': 'manage_evm_wallets',
  'get_evm_balance': 'check_balance',
  'list_evm_wallets': 'manage_evm_wallets',
  'estimate_evm_gas': 'manage_evm_wallets',
  'import_wallet': 'import_wallet',
  'switch_wallet': 'switch_wallet',
  
  // User Features
  'get_user_preferences': 'show_preferences',
  'update_user_preferences': 'show_preferences',
  'get_pending_approvals': 'requires_approval',
  'get_approval_history': 'show_approval_history',
  
  // Network Settings
  'switch_network': 'network_settings',
  'set_network': 'network_settings',
  'change_network': 'network_settings',
  'get_network': 'network_settings',
  'switch_to_devnet': 'network_settings',
  'switch_to_mainnet': 'network_settings',
  'set_devnet': 'network_settings',
  'set_mainnet': 'network_settings',
  
  // Faucet
  'request_faucet': 'faucet',
  'get_faucet': 'faucet',
  'airdrop': 'faucet',
  'request_airdrop': 'faucet',
  'solana_faucet': 'faucet',
  
  // Transactions
  'get_enhanced_transactions': 'show_transactions',
  
  // Analytics (Pyth, Helius, etc.)
  'pyth__get_price': 'token_price',
  'pyth__get_prices': 'token_price',
  'helius__get_balance': 'check_balance',
  'helius__get_transactions': 'show_transactions',
  'helius__get_token_metadata': 'token_info',
  'helius__get_nfts': 'show_nfts',
};

/**
 * Get action type from tool name
 */
function getActionTypeFromTool(toolName: string): ActionType {
  // Direct match
  if (TOOL_ACTION_MAP[toolName]) {
    return TOOL_ACTION_MAP[toolName];
  }
  
  // Partial match (for MCP tools with prefixes)
  const lowerName = toolName.toLowerCase();
  
  for (const [key, value] of Object.entries(TOOL_ACTION_MAP)) {
    if (lowerName.includes(key) || key.includes(lowerName)) {
      return value;
    }
  }
  
  // Keyword-based detection
  if (lowerName.includes('balance') || lowerName.includes('portfolio')) {
    return 'check_balance';
  }
  if (lowerName.includes('swap') || lowerName.includes('exchange')) {
    return 'swap_tokens';
  }
  if (lowerName.includes('send') || lowerName.includes('transfer')) {
    return 'send_sol';
  }
  if (lowerName.includes('stake')) {
    return 'stake';
  }
  if (lowerName.includes('price')) {
    return 'token_price';
  }
  if (lowerName.includes('risk')) {
    return 'token_risk';
  }
  if (lowerName.includes('wallet') && lowerName.includes('create')) {
    return 'create_wallet';
  }
  if (lowerName.includes('nft')) {
    return 'show_nfts';
  }
  if (lowerName.includes('devnet') || lowerName.includes('mainnet') || lowerName.includes('network')) {
    return 'network_settings';
  }
  if (lowerName.includes('faucet') || lowerName.includes('airdrop')) {
    return 'faucet';
  }
  if (lowerName.includes('delete') && lowerName.includes('wallet')) {
    return 'delete_wallet';
  }
  
  return 'info';
}

/**
 * Detect action type from AI message content when no tools are called
 */
function detectActionTypeFromMessage(message: string): ActionType {
  if (!message) return 'info';
  
  const lowerMessage = message.toLowerCase();
  
  // Network settings detection
  if (lowerMessage.includes('devnet') || lowerMessage.includes('mainnet') || 
      lowerMessage.includes('testnet') || lowerMessage.includes('network')) {
    if (lowerMessage.includes('switch') || lowerMessage.includes('change') || 
        lowerMessage.includes('ubah') || lowerMessage.includes('ganti') ||
        lowerMessage.includes('mode')) {
      return 'network_settings';
    }
  }
  
  // Faucet detection
  if (lowerMessage.includes('faucet') || lowerMessage.includes('airdrop')) {
    return 'faucet';
  }
  
  // Wallet operations
  if (lowerMessage.includes('wallet') && 
      (lowerMessage.includes('create') || lowerMessage.includes('buat'))) {
    return 'create_wallet';
  }
  
  // Delete wallet detection
  if (lowerMessage.includes('wallet') && 
      (lowerMessage.includes('delete') || lowerMessage.includes('hapus') || 
       lowerMessage.includes('remove') || lowerMessage.includes('removed'))) {
    return 'delete_wallet';
  }
  
  // Balance check
  if (lowerMessage.includes('balance') || lowerMessage.includes('saldo')) {
    return 'check_balance';
  }
  
  // Swap
  if (lowerMessage.includes('swap') || lowerMessage.includes('tukar')) {
    return 'swap_tokens';
  }
  
  // Staking
  if (lowerMessage.includes('stake') || lowerMessage.includes('staking')) {
    return 'stake';
  }
  
  // Transfer/Send
  if (lowerMessage.includes('send') || lowerMessage.includes('kirim') || 
      lowerMessage.includes('transfer')) {
    return 'send_sol';
  }
  
  // Price
  if (lowerMessage.includes('price') || lowerMessage.includes('harga')) {
    return 'token_price';
  }
  
  // NFT
  if (lowerMessage.includes('nft')) {
    return 'show_nfts';
  }
  
  return 'info';
}

/**
 * Extract structured details from tool results
 */
function extractDetails(toolResults: ToolResult[]): Record<string, any> {
  const details: Record<string, any> = {};
  
  for (const tool of toolResults) {
    if (tool.error) {
      details.error = tool.error;
      continue;
    }
    
    if (!tool.result) continue;
    
    const result = tool.result;
    const toolName = tool.name.toLowerCase();
    
    // Balance results
    if (toolName.includes('balance')) {
      if (result.balance !== undefined) {
        details.balance = result.balance;
      }
      if (result.sol !== undefined) {
        details.sol = result.sol;
      }
      if (result.usdValue !== undefined) {
        details.usdValue = result.usdValue;
      }
      if (result.tokens) {
        details.tokens = result.tokens;
      }
    }
    
    // Wallet results
    if (toolName.includes('wallet')) {
      if (result.address || result.publicKey) {
        const address = result.address || result.publicKey;
        details.address = address;
        
        // If it's an EVM wallet creation, add to evmWallets array
        if (toolName.includes('evm') || (result.chainId && result.chainId !== 'solana') || (result.chain && result.chain !== 'solana')) {
          const chainId = result.chainId || result.chain || 'ethereum';
          details.evmWallets = [{
            address: address,
            chainId: chainId,
            name: result.name || 'New Wallet',
            balance: result.balance || 0,
            usdValue: result.usdValue || 0,
            isPrimary: result.isPrimary || false,
            isNew: true, // Flag to indicate this is a newly created wallet
          }];
        } else {
          // Solana wallet
          details.wallets = [{
            publicKey: address,
            fullAddress: address,
            name: result.name || 'New Wallet',
            balance: result.balance || 0,
            usdValue: result.usdValue || 0,
            isPrimary: result.isPrimary || false,
            isNew: true,
          }];
        }
      }
      if (result.wallet) {
        details.wallet = result.wallet;
        
        // Also structure it for the panel
        const walletAddress = result.wallet.address || result.wallet.publicKey;
        if (walletAddress) {
          if ((result.wallet.chainId && result.wallet.chainId !== 'solana') || 
              (result.wallet.chain && result.wallet.chain !== 'solana')) {
            details.evmWallets = details.evmWallets || [];
            details.evmWallets.push({
              ...result.wallet,
              address: walletAddress,
              isNew: true,
            });
          } else {
            details.wallets = details.wallets || [];
            details.wallets.push({
              ...result.wallet,
              publicKey: walletAddress,
              fullAddress: walletAddress,
              isNew: true,
            });
          }
        }
      }
      if (result.wallets) {
        details.wallets = result.wallets;
      }
      if (result.evmWallets) {
        details.evmWallets = result.evmWallets;
      }
      if (result.chain) {
        details.chain = result.chain;
      }
      if (result.chainId) {
        details.chainId = result.chainId;
      }
    }
    
    // Price results
    if (toolName.includes('price')) {
      if (result.price !== undefined) {
        details.price = result.price;
      }
      if (result.prices) {
        details.prices = result.prices;
      }
      if (result.change24h !== undefined) {
        details.change24h = result.change24h;
      }
    }
    
    // Swap results
    if (toolName.includes('swap') || toolName.includes('quote')) {
      if (result.quote) {
        details.quote = result.quote;
      }
      if (result.fromToken) {
        details.fromToken = result.fromToken;
      }
      if (result.toToken) {
        details.toToken = result.toToken;
      }
      if (result.amount) {
        details.amount = result.amount;
      }
    }
    
    // Transaction results
    if (toolName.includes('transaction') || toolName.includes('send') || toolName.includes('transfer')) {
      if (result.signature) {
        details.signature = result.signature;
      }
      if (result.txHash) {
        details.txHash = result.txHash;
      }
      if (result.transactions) {
        details.transactions = result.transactions;
      }
    }
    
    // Risk results
    if (toolName.includes('risk')) {
      if (result.score !== undefined) {
        details.riskScore = result.score;
      }
      if (result.riskScore !== undefined) {
        details.riskScore = result.riskScore;
      }
      if (result.level) {
        details.riskLevel = result.level;
      }
      if (result.isHighRisk !== undefined) {
        details.isHighRisk = result.isHighRisk;
      }
      if (result.warnings) {
        details.warnings = result.warnings;
      }
      if (result.reasons) {
        details.reasons = result.reasons;
      }
      if (result.recommendation) {
        details.recommendation = result.recommendation;
      }
    }
    
    // Staking results
    if (toolName.includes('stake')) {
      if (result.apy !== undefined) {
        details.apy = result.apy;
      }
      if (result.validator) {
        details.validator = result.validator;
      }
      if (result.lockPeriod) {
        details.lockPeriod = result.lockPeriod;
      }
      if (result.estimatedRewards) {
        details.estimatedRewards = result.estimatedRewards;
      }
      if (result.availableBalance !== undefined) {
        details.availableBalance = result.availableBalance;
      }
    }
    
    // Lending/Borrowing results
    if (toolName.includes('lend') || toolName.includes('borrow')) {
      if (result.supplyApy !== undefined) {
        details.supplyApy = result.supplyApy;
      }
      if (result.borrowApy !== undefined) {
        details.borrowApy = result.borrowApy;
      }
      if (result.protocol) {
        details.protocol = result.protocol;
      }
      if (result.collateralFactor !== undefined) {
        details.collateralFactor = result.collateralFactor;
      }
      if (result.healthFactor !== undefined) {
        details.healthFactor = result.healthFactor;
      }
      if (result.liquidationThreshold !== undefined) {
        details.liquidationThreshold = result.liquidationThreshold;
      }
      if (result.availableCollateral !== undefined) {
        details.availableCollateral = result.availableCollateral;
      }
      if (result.borrowLimit !== undefined) {
        details.borrowLimit = result.borrowLimit;
      }
      if (result.positions) {
        details.positions = result.positions;
      }
    }
    
    // Liquidity results
    if (toolName.includes('liquidity') || toolName.includes('lp')) {
      if (result.pool) {
        details.pool = result.pool;
      }
      if (result.feeTier !== undefined) {
        details.feeTier = result.feeTier;
      }
      if (result.estimatedApr !== undefined) {
        details.estimatedApr = result.estimatedApr;
      }
      if (result.yourShare !== undefined) {
        details.yourShare = result.yourShare;
      }
      if (result.lpTokens !== undefined) {
        details.lpTokens = result.lpTokens;
      }
      if (result.positions) {
        details.positions = result.positions;
      }
    }
    
    // Bridge results
    if (toolName.includes('bridge')) {
      if (result.bridge) {
        details.bridge = result.bridge;
      }
      if (result.estimatedTime) {
        details.estimatedTime = result.estimatedTime;
      }
      if (result.bridgeFee !== undefined) {
        details.bridgeFee = result.bridgeFee;
      }
      if (result.estimatedReceive !== undefined) {
        details.estimatedReceive = result.estimatedReceive;
      }
      if (result.fromChain) {
        details.fromChain = result.fromChain;
      }
      if (result.toChain) {
        details.toChain = result.toChain;
      }
      if (result.status) {
        details.bridgeStatus = result.status;
      }
      if (result.chains) {
        details.supportedChains = result.chains;
      }
    }
    
    // NFT results
    if (toolName.includes('nft')) {
      if (result.nfts) {
        details.nfts = result.nfts;
      }
      if (result.count !== undefined) {
        details.nftCount = result.count;
      }
      if (result.metadata) {
        details.nftMetadata = result.metadata;
      }
    }
    
    // Approval history results
    if (toolName.includes('approval')) {
      if (result.approvals) {
        details.approvals = result.approvals;
      }
      if (result.total !== undefined) {
        details.totalApprovals = result.total;
      }
    }
    
    // Merge any success/message fields
    if (result.success !== undefined) {
      details.success = result.success;
    }
    if (result.message) {
      details.toolMessage = result.message;
    }
    
    // Merge raw result for unknown structures
    if (Object.keys(details).length === 0 || details.success === undefined) {
      Object.assign(details, result);
    }
  }
  
  return details;
}

/**
 * Generate a short summary from tool results and AI message
 */
function generateSummary(
  actionType: ActionType,
  toolResults: ToolResult[],
  aiMessage?: string
): string {
  // Check for errors first
  const errorResult = toolResults.find(t => t.error);
  if (errorResult) {
    return `Error: ${errorResult.error}`;
  }
  
  // Generate summary based on action type
  switch (actionType) {
    case 'check_balance': {
      const balanceResult = toolResults.find(t => t.result?.balance !== undefined || t.result?.sol !== undefined);
      if (balanceResult?.result) {
        const r = balanceResult.result;
        if (r.sol !== undefined) {
          return `Balance: ${r.sol} SOL${r.usdValue ? ` ($${r.usdValue})` : ''}`;
        }
        if (r.balance !== undefined) {
          return `Balance: ${r.balance}`;
        }
      }
      return 'Balance retrieved';
    }
    
    case 'create_wallet':
    case 'manage_evm_wallets': {
      const walletResult = toolResults.find(t => t.result?.address || t.result?.wallet);
      if (walletResult?.result) {
        const r = walletResult.result;
        const addr = r.address || r.wallet?.address;
        if (addr) {
          const shortAddr = `${addr.slice(0, 6)}...${addr.slice(-4)}`;
          return `Wallet created: ${shortAddr}`;
        }
      }
      return 'Wallet operation completed';
    }
    
    case 'delete_wallet': {
      const deleteResult = toolResults.find(t => t.result?.deleted !== undefined || t.result?.deletedWalletId);
      if (deleteResult?.result) {
        const r = deleteResult.result;
        if (r.deleted !== undefined) {
          const kept = r.kept ? ', 1 kept' : '';
          return `${r.deleted} wallet(s) deleted${kept}`;
        }
        if (r.deletedWalletId) {
          return 'Wallet deleted successfully';
        }
      }
      return 'Wallet deleted';
    }
    
    case 'token_price': {
      const priceResult = toolResults.find(t => t.result?.price !== undefined);
      if (priceResult?.result) {
        return `Price: $${priceResult.result.price}`;
      }
      return 'Price fetched';
    }
    
    case 'swap_tokens': {
      const swapResult = toolResults.find(t => t.result?.signature || t.result?.txHash);
      if (swapResult?.result) {
        return 'Swap executed successfully';
      }
      return 'Swap prepared';
    }
    
    case 'send_sol':
    case 'send_token': {
      const sendResult = toolResults.find(t => t.result?.signature || t.result?.txHash);
      if (sendResult?.result) {
        return 'Transfer completed';
      }
      return 'Transfer prepared';
    }
    
    case 'token_risk': {
      const riskResult = toolResults.find(t => t.result?.score !== undefined || t.result?.level || t.result?.riskScore !== undefined);
      if (riskResult?.result) {
        const r = riskResult.result;
        const score = r.riskScore ?? r.score;
        const level = r.level || (score > 70 ? 'High' : score > 40 ? 'Medium' : 'Low');
        return `Risk: ${level}${score !== undefined ? ` (${score}/100)` : ''}`;
      }
      return 'Risk analysis complete';
    }
    
    case 'stake': {
      const stakeResult = toolResults.find(t => t.result?.signature || t.result?.success);
      if (stakeResult?.result?.signature) {
        return 'Staking successful';
      }
      if (stakeResult?.result?.apy) {
        return `Stake available at ${stakeResult.result.apy}% APY`;
      }
      return 'Staking info retrieved';
    }
    
    case 'unstake': {
      const unstakeResult = toolResults.find(t => t.result?.signature || t.result?.success);
      if (unstakeResult?.result?.signature) {
        return 'Unstaking successful';
      }
      return 'Unstaking prepared';
    }
    
    case 'lend': {
      const lendResult = toolResults.find(t => t.result?.signature || t.result?.positions);
      if (lendResult?.result?.signature) {
        return 'Lending successful';
      }
      if (lendResult?.result?.supplyApy) {
        return `Lending available at ${lendResult.result.supplyApy}% APY`;
      }
      return 'Lending info retrieved';
    }
    
    case 'borrow': {
      const borrowResult = toolResults.find(t => t.result?.signature || t.result?.healthFactor);
      if (borrowResult?.result?.signature) {
        return 'Borrowing successful';
      }
      if (borrowResult?.result?.borrowApy) {
        return `Borrow rate: ${borrowResult.result.borrowApy}% APY`;
      }
      return 'Borrowing info retrieved';
    }
    
    case 'add_liquidity': {
      const lpResult = toolResults.find(t => t.result?.lpTokens || t.result?.positions);
      if (lpResult?.result?.lpTokens) {
        return 'Liquidity added successfully';
      }
      if (lpResult?.result?.estimatedApr) {
        return `Pool APR: ${lpResult.result.estimatedApr}%`;
      }
      return 'Liquidity pool info retrieved';
    }
    
    case 'remove_liquidity': {
      const removeResult = toolResults.find(t => t.result?.amountA || t.result?.success);
      if (removeResult?.result?.success) {
        return 'Liquidity removed successfully';
      }
      return 'Liquidity removal prepared';
    }
    
    case 'bridge': {
      const bridgeResult = toolResults.find(t => t.result?.bridgeTxId || t.result?.estimatedReceive);
      if (bridgeResult?.result?.bridgeTxId) {
        return 'Bridge transaction initiated';
      }
      if (bridgeResult?.result?.estimatedReceive) {
        return `Bridge quote: receive ${bridgeResult.result.estimatedReceive}`;
      }
      return 'Bridge info retrieved';
    }
    
    case 'show_nfts': {
      const nftResult = toolResults.find(t => t.result?.nfts || t.result?.count !== undefined);
      if (nftResult?.result) {
        const count = nftResult.result.count ?? nftResult.result.nfts?.length ?? 0;
        return `Found ${count} NFT${count !== 1 ? 's' : ''}`;
      }
      return 'NFT collection loaded';
    }
    
    case 'show_transactions': {
      const txResult = toolResults.find(t => t.result?.transactions || t.result?.count !== undefined);
      if (txResult?.result) {
        const count = txResult.result.count ?? txResult.result.transactions?.length ?? 0;
        return `Found ${count} transaction${count !== 1 ? 's' : ''}`;
      }
      return 'Transaction history loaded';
    }
    
    case 'show_approval_history': {
      const approvalResult = toolResults.find(t => t.result?.approvals);
      if (approvalResult?.result) {
        const count = approvalResult.result.total ?? approvalResult.result.approvals?.length ?? 0;
        return `${count} approval${count !== 1 ? 's' : ''} in history`;
      }
      return 'Approval history loaded';
    }
    
    case 'network_settings': {
      // Try to extract from tool results first
      const networkResult = toolResults.find(t => t.result?.network || t.result?.mode);
      if (networkResult?.result) {
        const network = networkResult.result.network || networkResult.result.mode;
        return `Network switched to ${network}`;
      }
      // Fall back to message detection
      if (aiMessage) {
        if (aiMessage.toLowerCase().includes('devnet')) {
          return 'Switched to Devnet';
        }
        if (aiMessage.toLowerCase().includes('mainnet')) {
          return 'Switched to Mainnet';
        }
      }
      return 'Network settings updated';
    }
    
    case 'faucet': {
      const faucetResult = toolResults.find(t => t.result?.signature || t.result?.amount || t.result?.success);
      if (faucetResult?.result?.signature) {
        const amount = faucetResult.result.amount || '1';
        return `Received ${amount} SOL from faucet`;
      }
      if (faucetResult?.result?.success) {
        return 'Faucet airdrop successful';
      }
      return 'Faucet request processed';
    }
    
    default: {
      // Try to extract message from tool result
      const msgResult = toolResults.find(t => t.result?.message);
      if (msgResult?.result?.message) {
        const msg = msgResult.result.message;
        return msg.length > 100 ? `${msg.slice(0, 100)}...` : msg;
      }
      
      // Fall back to AI message
      if (aiMessage) {
        const firstSentence = aiMessage.split(/[.!?]/)[0].trim();
        return firstSentence.length > 100 ? `${firstSentence.slice(0, 100)}...` : firstSentence;
      }
      
      return 'Command processed';
    }
  }
}

/**
 * Determine response status from tool results
 */
function getStatus(toolResults: ToolResult[]): ResponseStatus {
  if (toolResults.length === 0) {
    return 'success';
  }
  
  // Check for approval requirements first
  const requiresApproval = toolResults.some(t => 
    t.result?.requiresApproval || 
    t.result?.needsConfirmation
  );
  if (requiresApproval) {
    return 'requires_approval';
  }
  
  // Check if any important tool succeeded
  const hasSuccess = toolResults.some(t => !t.error && t.result);
  if (hasSuccess) {
    // Check for pending status in successful results
    const isPending = toolResults.some(t => 
      !t.error && (
        t.result?.status === 'pending' ||
        t.result?.pending
      )
    );
    if (isPending) {
      return 'pending';
    }
    return 'success';
  }
  
  // All tools failed
  return 'error';
}

/**
 * Parse AI response and tool results into structured format
 */
export function parseResponse(
  conversationId: string,
  aiMessage: string,
  toolResults: ToolResult[] = []
): StructuredResponse {
  logger.info('Parsing response', {
    conversationId,
    messageLength: aiMessage?.length,
    toolCount: toolResults.length,
    tools: toolResults.map(t => t.name),
  });
  
  // Determine action type - prioritize successful tools and user intent
  let actionType: ActionType = 'info';
  if (toolResults.length > 0) {
    // Find successful tools first
    const successfulTools = toolResults.filter(t => !t.error && t.result);
    
    if (successfulTools.length > 0) {
      // Prioritize wallet creation, then other actions
      const walletCreateTool = successfulTools.find(t => 
        t.name.includes('create_wallet') || 
        t.name.includes('create_evm_wallet') ||
        t.name.includes('create_solana_wallet')
      );
      
      if (walletCreateTool) {
        actionType = getActionTypeFromTool(walletCreateTool.name);
      } else {
        // Use first successful tool's action type
        actionType = getActionTypeFromTool(successfulTools[0].name);
      }
    } else {
      // All tools failed, use first tool's type
      actionType = getActionTypeFromTool(toolResults[0].name);
    }
  } else {
    // No tools called - detect from message content
    actionType = detectActionTypeFromMessage(aiMessage);
  }
  
  // Extract structured details (from successful tools primarily)
  const details = extractDetails(toolResults);
  
  // Generate summary based on successful results
  const summary = generateSummary(actionType, toolResults, aiMessage);
  
  // Get status - success if any tool succeeded
  const status = getStatus(toolResults);
  
  // Get tool names
  const toolsUsed = toolResults.map(t => t.name);
  
  const response: StructuredResponse = {
    conversationId,
    actionType,
    status,
    summary,
    details,
    toolsUsed,
    rawMessage: aiMessage,
  };
  
  logger.info('Parsed response', {
    actionType,
    status,
    summary,
    detailKeys: Object.keys(details),
  });
  
  return response;
}

/**
 * Parse streaming tool events into structured format
 * Used for real-time updates during streaming
 */
export function parseToolEvent(
  toolName: string,
  toolResult?: any,
  error?: string
): {
  actionType: ActionType;
  status: ResponseStatus;
  partialDetails: Record<string, any>;
} {
  const actionType = getActionTypeFromTool(toolName);
  
  if (error) {
    return {
      actionType,
      status: 'error',
      partialDetails: { error },
    };
  }
  
  const details = extractDetails([{
    id: 'streaming',
    name: toolName,
    result: toolResult,
  }]);
  
  return {
    actionType,
    status: toolResult?.requiresApproval ? 'requires_approval' : 'success',
    partialDetails: details,
  };
}

export default {
  parseResponse,
  parseToolEvent,
  getActionTypeFromTool,
};
