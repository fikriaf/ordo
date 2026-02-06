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
  // Settings
  | 'show_preferences'
  | 'set_limit'
  | 'set_slippage'
  | 'show_security_settings'
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
  
  // Token Operations
  'get_token_info': 'token_info',
  'analyze_token': 'token_info',
  'get_token_price': 'token_price',
  'token_price': 'token_price',
  'get_risk_score': 'token_risk',
  'risk_score': 'token_risk',
  
  // Transfers
  'send_sol': 'send_sol',
  'transfer_sol': 'send_sol',
  'send_token': 'send_token',
  'transfer_token': 'send_token',
  
  // Swaps
  'swap': 'swap_tokens',
  'swap_tokens': 'swap_tokens',
  'get_swap_quote': 'get_swap_quote',
  'quote': 'get_swap_quote',
  
  // DeFi
  'stake': 'stake',
  'stake_sol': 'stake',
  'unstake': 'unstake',
  'unstake_sol': 'unstake',
  'lend': 'lend',
  'borrow': 'borrow',
  'add_liquidity': 'add_liquidity',
  'remove_liquidity': 'remove_liquidity',
  'bridge': 'bridge',
  
  // NFT
  'get_nfts': 'show_nfts',
  'show_nfts': 'show_nfts',
  'mint_nft': 'mint_nft',
  'send_nft': 'send_nft',
  
  // Wallet Management
  'create_wallet': 'create_wallet',
  'create_solana_wallet': 'create_wallet',
  'create_evm_wallet': 'manage_evm_wallets',
  'import_wallet': 'import_wallet',
  'switch_wallet': 'switch_wallet',
  
  // Analytics (Pyth, Helius, etc.)
  'pyth__get_price': 'token_price',
  'pyth__get_prices': 'token_price',
  'helius__get_balance': 'check_balance',
  'helius__get_transactions': 'show_transactions',
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
      if (result.address) {
        details.address = result.address;
      }
      if (result.wallet) {
        details.wallet = result.wallet;
      }
      if (result.wallets) {
        details.wallets = result.wallets;
      }
      if (result.chain) {
        details.chain = result.chain;
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
      if (result.level) {
        details.riskLevel = result.level;
      }
      if (result.warnings) {
        details.warnings = result.warnings;
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
      const riskResult = toolResults.find(t => t.result?.score !== undefined || t.result?.level);
      if (riskResult?.result) {
        const r = riskResult.result;
        return `Risk: ${r.level || r.score}`;
      }
      return 'Risk analysis complete';
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
  
  const hasError = toolResults.some(t => t.error);
  if (hasError) {
    return 'error';
  }
  
  const requiresApproval = toolResults.some(t => 
    t.result?.requiresApproval || 
    t.result?.needsConfirmation
  );
  if (requiresApproval) {
    return 'requires_approval';
  }
  
  const isPending = toolResults.some(t => 
    t.result?.status === 'pending' ||
    t.result?.pending
  );
  if (isPending) {
    return 'pending';
  }
  
  return 'success';
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
  
  // Determine action type from tools or default to info
  let actionType: ActionType = 'info';
  if (toolResults.length > 0) {
    // Use the first tool's action type (primary action)
    actionType = getActionTypeFromTool(toolResults[0].name);
  }
  
  // Extract structured details
  const details = extractDetails(toolResults);
  
  // Generate summary
  const summary = generateSummary(actionType, toolResults, aiMessage);
  
  // Get status
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
