import { Request } from 'express';

export interface AuthenticatedRequest extends Request {
  user?: {
    id: string;
    email: string;
    role: 'user' | 'admin';
  };
}

export interface User {
  id: string;
  email: string;
  password_hash: string;
  role: 'user' | 'admin';
  created_at: string;
  updated_at: string;
}

export interface Wallet {
  id: string;
  user_id: string;
  public_key: string;
  encrypted_private_key: string;
  encryption_iv: string;
  encryption_tag: string;
  is_primary: boolean;
  created_at: string;
}

export interface Transaction {
  id: string;
  user_id: string;
  wallet_id: string;
  type: string;
  signature: string;
  status: 'pending' | 'confirmed' | 'failed';
  amount?: number;
  token_address?: string;
  metadata: Record<string, any>;
  created_at: string;
  updated_at: string;
}

export interface Conversation {
  id: string;
  user_id: string;
  title?: string;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface Message {
  id: string;
  conversation_id: string;
  role: 'user' | 'assistant' | 'system';
  content: string;
  metadata?: Record<string, any>;
  created_at: string;
}

export interface AIModel {
  id: string;
  name: string;
  provider: string;
  model_id: string;
  is_default: boolean;
  is_enabled: boolean;
  config: Record<string, any>;
  created_at: string;
  updated_at: string;
}

export interface Plugin {
  id: string;
  name: string;
  version: string;
  description: string;
  is_enabled: boolean;
  config: Record<string, any>;
  created_at: string;
  updated_at: string;
}

export interface AdminConfig {
  id: string;
  key: string;
  value: any;
  version: number;
  created_at: string;
  updated_at: string;
}

export interface AuditLog {
  id: string;
  admin_id: string;
  action: string;
  resource_type: string;
  resource_id?: string;
  metadata?: Record<string, any>;
  created_at: string;
}

export interface ToolDefinition {
  name: string;
  description: string;
  parameters: {
    type: 'object';
    properties: Record<string, any>;
    required?: string[];
  };
}

export interface ToolCall {
  name: string;
  arguments: Record<string, any>;
}

export interface ToolResult {
  success: boolean;
  data?: any;
  error?: string;
}

// =============================================
// NEW TYPES FOR ADDITIONAL FEATURES
// =============================================

export interface UserPreferences {
  id: string;
  user_id: string;
  // Transaction Limits
  max_single_transfer_sol: number;
  max_daily_volume_usdc: number;
  // Agent Autonomy
  agent_autonomy_level: 'low' | 'medium' | 'high';
  require_approval_above_usdc: number;
  // Trading Preferences
  default_slippage_bps: number;
  enable_auto_staking: boolean;
  enable_auto_compounding: boolean;
  // Risk Management
  min_token_risk_score: number;
  block_high_risk_tokens: boolean;
  // Notifications
  notify_on_approval_needed: boolean;
  notify_on_transaction_complete: boolean;
  notify_on_price_alerts: boolean;
  // Timestamps
  created_at: string;
  updated_at: string;
}

export interface ApprovalRequest {
  id: string;
  user_id: string;
  request_type: 'transaction' | 'setting_change' | 'large_transfer' | 'high_risk_token';
  pending_transaction: Record<string, any>;
  estimated_risk_score?: number;
  estimated_usd_value?: number;
  agent_reasoning?: string;
  limiting_factors?: Record<string, any>;
  alternative_options?: Record<string, any>;
  status: 'pending' | 'approved' | 'rejected' | 'expired';
  approved_at?: string;
  rejected_at?: string;
  rejection_reason?: string;
  expires_at: string;
  created_at: string;
  updated_at: string;
}

export interface TokenScore {
  id: string;
  token_address: string;
  token_symbol?: string;
  token_name?: string;
  risk_score?: number;
  market_score?: number;
  liquidity_score?: number;
  holder_score?: number;
  rugcheck_score?: number;
  price_usd?: number;
  market_cap_usd?: number;
  volume_24h_usd?: number;
  liquidity_usd?: number;
  holder_count?: number;
  limiting_factors?: Record<string, any>;
  data_sources?: string[];
  created_at: string;
  updated_at: string;
  last_fetched_at: string;
}

export interface NFTCollection {
  id: string;
  collection_address: string;
  collection_name?: string;
  collection_symbol?: string;
  floor_price_sol?: number;
  volume_24h_sol?: number;
  listed_count?: number;
  holder_count?: number;
  verified: boolean;
  risk_flags?: string[];
  metadata_uri?: string;
  creator_address?: string;
  created_at: string;
  updated_at: string;
}

export interface UserNFT {
  id: string;
  user_id: string;
  mint_address: string;
  collection_id?: string;
  name?: string;
  image_uri?: string;
  attributes?: Record<string, any>;
  acquired_at?: string;
  acquired_price_sol?: number;
  current_value_sol?: number;
  created_at: string;
  updated_at: string;
}

export interface AgentMemory {
  id: string;
  user_id: string;
  memory_type: 'conversation' | 'decision' | 'learned_preference' | 'market_insight' | 'error_log';
  content: string;
  agent_id: string;
  session_id?: string;
  related_transaction_id?: string;
  metadata?: Record<string, any>;
  importance_score: number;
  created_at: string;
  accessed_at: string;
  access_count: number;
}

export interface AgentLog {
  id: string;
  agent_id: string;
  agent_type: 'orchestrator' | 'supervisor' | 'worker' | 'tool';
  level: 'debug' | 'info' | 'warn' | 'error' | 'critical';
  message: string;
  user_id?: string;
  transaction_id?: string;
  session_id?: string;
  metadata?: Record<string, any>;
  error_stack?: string;
  created_at: string;
}

export interface WebhookEvent {
  id: string;
  source: string;
  event_type: string;
  payload: Record<string, any>;
  processed: boolean;
  processed_at?: string;
  processing_error?: string;
  created_at: string;
}

// Swap/Trade Types
export interface SwapQuote {
  inputMint: string;
  outputMint: string;
  inputAmount: number;
  outputAmount: number;
  priceImpact: number;
  slippage: number;
  route: any[];
  fees: {
    total: number;
    breakdown: Record<string, number>;
  };
}

export interface SwapRequest {
  walletId: string;
  inputMint: string;
  outputMint: string;
  amount: number;
  slippage?: number;
  priorityFee?: number;
}

export interface StakeRequest {
  walletId: string;
  amount: number;
  validator?: string;
  protocol?: 'native' | 'marinade' | 'jito' | 'sanctum';
}

export interface NFTMintRequest {
  walletId: string;
  name: string;
  symbol: string;
  uri: string;
  sellerFeeBasisPoints?: number;
  creators?: Array<{
    address: string;
    share: number;
  }>;
}
