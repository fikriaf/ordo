-- Additional Features Migration for Ordo Backend
-- This adds missing tables for: User Preferences, Approval Queue, Token Scores, NFT Management, Agent Memory

-- =============================================
-- USER PREFERENCES & SETTINGS
-- =============================================

CREATE TABLE IF NOT EXISTS user_preferences (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  -- Risk Management
  max_single_transfer_sol DECIMAL(18, 9) DEFAULT 1.0,
  max_daily_volume_usdc DECIMAL(18, 2) DEFAULT 10000,
  require_approval_above_sol DECIMAL(18, 9) DEFAULT 0.5,
  auto_approve_whitelisted BOOLEAN DEFAULT FALSE,
  
  -- Trading Preferences
  default_slippage_bps INTEGER DEFAULT 50, -- 0.5%
  max_slippage_bps INTEGER DEFAULT 300, -- 3%
  priority_fee_lamports BIGINT DEFAULT 10000,
  
  -- Agent Behavior
  agent_autonomy_level VARCHAR(20) DEFAULT 'medium' CHECK (agent_autonomy_level IN ('low', 'medium', 'high')),
  enable_auto_staking BOOLEAN DEFAULT FALSE,
  enable_auto_compounding BOOLEAN DEFAULT FALSE,
  
  -- Notifications
  notification_channels JSONB DEFAULT '["mobile", "email"]'::JSONB,
  alert_on_large_movements BOOLEAN DEFAULT TRUE,
  alert_threshold_usdc DECIMAL(18, 2) DEFAULT 1000,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_user_preferences_user_id ON user_preferences(user_id);

-- =============================================
-- APPROVAL QUEUE (Human-in-the-Loop)
-- =============================================

CREATE TABLE IF NOT EXISTS approval_queue (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  -- Request Details
  request_type VARCHAR(50) NOT NULL CHECK (request_type IN ('transaction', 'setting_change', 'large_transfer', 'high_risk_token')),
  
  -- Transaction Reference
  pending_transaction JSONB NOT NULL,
  estimated_risk_score DECIMAL(5, 2),
  estimated_usd_value DECIMAL(18, 2),
  
  -- Context
  agent_reasoning TEXT,
  limiting_factors JSONB,
  alternative_options JSONB,
  
  -- Status
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'expired')),
  
  -- Response
  approved_at TIMESTAMP WITH TIME ZONE,
  rejected_at TIMESTAMP WITH TIME ZONE,
  rejection_reason TEXT,
  
  -- Expiration
  expires_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '15 minutes'),
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_approval_queue_user_id ON approval_queue(user_id);
CREATE INDEX idx_approval_queue_status ON approval_queue(status);
CREATE INDEX idx_approval_queue_created_at ON approval_queue(created_at DESC);
CREATE INDEX idx_approval_queue_expires_at ON approval_queue(expires_at);

-- =============================================
-- TOKEN ANALYTICS & RISK SCORES
-- =============================================

CREATE TABLE IF NOT EXISTS token_scores (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  -- Token Identity
  token_address VARCHAR(44) UNIQUE NOT NULL,
  token_symbol VARCHAR(20),
  token_name VARCHAR(100),
  
  -- Risk Metrics
  risk_score DECIMAL(5, 2), -- 0-100
  market_score DECIMAL(5, 2), -- Range Protocol score
  liquidity_score DECIMAL(5, 2),
  holder_score DECIMAL(5, 2),
  rugcheck_score DECIMAL(5, 2),
  
  -- Market Data
  price_usd DECIMAL(18, 9),
  market_cap_usd DECIMAL(18, 2),
  volume_24h_usd DECIMAL(18, 2),
  liquidity_usd DECIMAL(18, 2),
  holder_count INTEGER,
  
  -- Limiting Factors (Range Protocol 1.8)
  limiting_factors JSONB,
  
  -- Data Sources
  data_sources JSONB DEFAULT '[]'::JSONB,
  
  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_fetched_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_token_scores_address ON token_scores(token_address);
CREATE INDEX idx_token_scores_symbol ON token_scores(token_symbol);
CREATE INDEX idx_token_scores_risk ON token_scores(risk_score);
CREATE INDEX idx_token_scores_updated ON token_scores(updated_at DESC);

-- =============================================
-- NFT COLLECTIONS & ASSETS
-- =============================================

CREATE TABLE IF NOT EXISTS nft_collections (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  collection_address VARCHAR(44) UNIQUE NOT NULL,
  collection_name VARCHAR(100),
  collection_symbol VARCHAR(20),
  
  -- Analytics
  floor_price_sol DECIMAL(18, 9),
  volume_24h_sol DECIMAL(18, 9),
  listed_count INTEGER,
  holder_count INTEGER,
  
  -- Risk Assessment
  verified BOOLEAN DEFAULT FALSE,
  risk_flags JSONB DEFAULT '[]'::JSONB,
  
  -- Metadata
  metadata_uri TEXT,
  creator_address VARCHAR(44),
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_nft_collections_address ON nft_collections(collection_address);
CREATE INDEX idx_nft_collections_verified ON nft_collections(verified);

CREATE TABLE IF NOT EXISTS user_nfts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  mint_address VARCHAR(44) UNIQUE NOT NULL,
  collection_id UUID REFERENCES nft_collections(id),
  
  name VARCHAR(100),
  image_uri TEXT,
  attributes JSONB,
  
  acquired_at TIMESTAMP WITH TIME ZONE,
  acquired_price_sol DECIMAL(18, 9),
  current_value_sol DECIMAL(18, 9),
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_user_nfts_user_id ON user_nfts(user_id);
CREATE INDEX idx_user_nfts_collection_id ON user_nfts(collection_id);
CREATE INDEX idx_user_nfts_mint_address ON user_nfts(mint_address);

-- =============================================
-- AGENT MEMORY & CONTEXT
-- =============================================

CREATE TABLE IF NOT EXISTS agent_memories (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  -- Memory Content
  memory_type VARCHAR(50) NOT NULL CHECK (memory_type IN ('conversation', 'decision', 'learned_preference', 'market_insight', 'error_log')),
  content TEXT NOT NULL,
  
  -- Context
  agent_id VARCHAR(100) NOT NULL,
  session_id UUID,
  related_transaction_id UUID REFERENCES transactions(id),
  
  -- Metadata
  metadata JSONB DEFAULT '{}'::JSONB,
  importance_score DECIMAL(3, 2) DEFAULT 0.5, -- 0-1
  
  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  accessed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  access_count INTEGER DEFAULT 0
);

CREATE INDEX idx_agent_memories_user_id ON agent_memories(user_id);
CREATE INDEX idx_agent_memories_type ON agent_memories(memory_type);
CREATE INDEX idx_agent_memories_agent_id ON agent_memories(agent_id);
CREATE INDEX idx_agent_memories_session_id ON agent_memories(session_id);
CREATE INDEX idx_agent_memories_created_at ON agent_memories(created_at DESC);

-- =============================================
-- AGENT ACTIVITY LOGS
-- =============================================

CREATE TABLE IF NOT EXISTS agent_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  -- Agent Identity
  agent_id VARCHAR(100) NOT NULL,
  agent_type VARCHAR(50) NOT NULL CHECK (agent_type IN ('orchestrator', 'supervisor', 'worker', 'tool')),
  
  -- Log Details
  level VARCHAR(20) DEFAULT 'info' CHECK (level IN ('debug', 'info', 'warn', 'error', 'critical')),
  message TEXT NOT NULL,
  
  -- Context
  user_id UUID REFERENCES users(id),
  transaction_id UUID REFERENCES transactions(id),
  session_id UUID,
  
  -- Structured Data
  metadata JSONB DEFAULT '{}'::JSONB,
  error_stack TEXT,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_agent_logs_agent_id ON agent_logs(agent_id);
CREATE INDEX idx_agent_logs_agent_type ON agent_logs(agent_type);
CREATE INDEX idx_agent_logs_level ON agent_logs(level);
CREATE INDEX idx_agent_logs_created_at ON agent_logs(created_at DESC);
CREATE INDEX idx_agent_logs_user_id ON agent_logs(user_id);

-- =============================================
-- WEBHOOKS & EVENT LOGS
-- =============================================

CREATE TABLE IF NOT EXISTS webhook_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  -- Event Source
  source VARCHAR(50) NOT NULL, -- 'helius', 'birdeye', 'custom'
  event_type VARCHAR(100) NOT NULL,
  
  -- Payload
  payload JSONB NOT NULL,
  
  -- Processing
  processed BOOLEAN DEFAULT FALSE,
  processed_at TIMESTAMP WITH TIME ZONE,
  processing_error TEXT,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_webhook_events_source ON webhook_events(source);
CREATE INDEX idx_webhook_events_processed ON webhook_events(processed);
CREATE INDEX idx_webhook_events_created_at ON webhook_events(created_at DESC);

-- =============================================
-- TRIGGERS FOR UPDATED_AT
-- =============================================

CREATE TRIGGER update_user_preferences_updated_at BEFORE UPDATE ON user_preferences
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_approval_queue_updated_at BEFORE UPDATE ON approval_queue
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_token_scores_updated_at BEFORE UPDATE ON token_scores
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_nft_collections_updated_at BEFORE UPDATE ON nft_collections
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_nfts_updated_at BEFORE UPDATE ON user_nfts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================
-- FUNCTIONS
-- =============================================

-- Increment access count on memory retrieval
CREATE OR REPLACE FUNCTION increment_memory_access()
RETURNS TRIGGER AS $$
BEGIN
  NEW.access_count = OLD.access_count + 1;
  NEW.accessed_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER agent_memories_access_counter BEFORE UPDATE ON agent_memories
  FOR EACH ROW WHEN (NEW.accessed_at > OLD.accessed_at)
  EXECUTE FUNCTION increment_memory_access();

-- Auto-expire approval requests
CREATE OR REPLACE FUNCTION expire_old_approvals()
RETURNS void AS $$
BEGIN
  UPDATE approval_queue
  SET status = 'expired'
  WHERE status = 'pending'
    AND expires_at < NOW();
END;
$$ LANGUAGE plpgsql;

-- Insert default user preferences for new users
CREATE OR REPLACE FUNCTION create_default_user_preferences()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO user_preferences (user_id)
  VALUES (NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER create_user_preferences_on_user_creation
  AFTER INSERT ON users
  FOR EACH ROW
  EXECUTE FUNCTION create_default_user_preferences();
