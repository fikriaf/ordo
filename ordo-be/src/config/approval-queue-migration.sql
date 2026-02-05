-- Approval Queue Migration
-- Creates approval_queue table for human-in-the-loop transaction approvals

-- Create approval_queue table
CREATE TABLE IF NOT EXISTS approval_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  -- Request Details
  request_type VARCHAR(50) NOT NULL CHECK (request_type IN ('transaction', 'setting_change', 'large_transfer', 'high_risk_token')),
  status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'expired', 'executed')),
  
  -- Transaction Data
  pending_transaction JSONB NOT NULL,
  transaction_signature VARCHAR(255),
  
  -- Risk Assessment
  estimated_risk_score INTEGER CHECK (estimated_risk_score >= 0 AND estimated_risk_score <= 100),
  estimated_usd_value DECIMAL(20, 2),
  
  -- AI Context
  agent_reasoning TEXT,
  limiting_factors JSONB,
  alternative_options JSONB,
  
  -- Approval Details
  approved_by UUID REFERENCES users(id),
  approved_at TIMESTAMPTZ,
  rejected_by UUID REFERENCES users(id),
  rejected_at TIMESTAMPTZ,
  rejection_reason TEXT,
  
  -- Expiration
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '15 minutes'),
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- Constraints
  CHECK (
    (status = 'approved' AND approved_by IS NOT NULL AND approved_at IS NOT NULL) OR
    (status = 'rejected' AND rejected_by IS NOT NULL AND rejected_at IS NOT NULL) OR
    (status IN ('pending', 'expired', 'executed'))
  )
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_approval_queue_user_id ON approval_queue(user_id);
CREATE INDEX IF NOT EXISTS idx_approval_queue_status ON approval_queue(status);
CREATE INDEX IF NOT EXISTS idx_approval_queue_expires_at ON approval_queue(expires_at);
CREATE INDEX IF NOT EXISTS idx_approval_queue_created_at ON approval_queue(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_approval_queue_user_status ON approval_queue(user_id, status);
CREATE INDEX IF NOT EXISTS idx_approval_queue_pending_expired ON approval_queue(status, expires_at) WHERE status = 'pending';

-- Create trigger to update updated_at
CREATE OR REPLACE FUNCTION update_approval_queue_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_approval_queue_updated_at ON approval_queue;
CREATE TRIGGER trigger_update_approval_queue_updated_at
  BEFORE UPDATE ON approval_queue
  FOR EACH ROW
  EXECUTE FUNCTION update_approval_queue_updated_at();

-- Create function to auto-expire pending approvals
CREATE OR REPLACE FUNCTION expire_pending_approvals()
RETURNS INTEGER AS $$
DECLARE
  expired_count INTEGER;
BEGIN
  UPDATE approval_queue
  SET 
    status = 'expired',
    updated_at = NOW()
  WHERE 
    status = 'pending' 
    AND expires_at < NOW();
  
  GET DIAGNOSTICS expired_count = ROW_COUNT;
  
  IF expired_count > 0 THEN
    RAISE NOTICE 'Expired % pending approval(s)', expired_count;
  END IF;
  
  RETURN expired_count;
END;
$$ LANGUAGE plpgsql;

-- Create function to clean up old approvals (older than 30 days)
CREATE OR REPLACE FUNCTION cleanup_old_approvals()
RETURNS INTEGER AS $$
DECLARE
  deleted_count INTEGER;
BEGIN
  DELETE FROM approval_queue
  WHERE 
    status IN ('approved', 'rejected', 'expired', 'executed')
    AND created_at < NOW() - INTERVAL '30 days';
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  
  IF deleted_count > 0 THEN
    RAISE NOTICE 'Cleaned up % old approval(s)', deleted_count;
  END IF;
  
  RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Add comments for documentation
COMMENT ON TABLE approval_queue IS 'Human-in-the-loop approval queue for high-risk or large transactions';
COMMENT ON COLUMN approval_queue.request_type IS 'Type of approval request: transaction, setting_change, large_transfer, high_risk_token';
COMMENT ON COLUMN approval_queue.status IS 'Current status: pending, approved, rejected, expired, executed';
COMMENT ON COLUMN approval_queue.pending_transaction IS 'JSON object containing transaction details to be executed';
COMMENT ON COLUMN approval_queue.estimated_risk_score IS 'AI-estimated risk score (0-100, higher = riskier)';
COMMENT ON COLUMN approval_queue.estimated_usd_value IS 'Estimated USD value of the transaction';
COMMENT ON COLUMN approval_queue.agent_reasoning IS 'AI agent explanation for why approval is needed';
COMMENT ON COLUMN approval_queue.limiting_factors IS 'JSON object with factors limiting the transaction';
COMMENT ON COLUMN approval_queue.alternative_options IS 'JSON array with alternative transaction options';
COMMENT ON COLUMN approval_queue.expires_at IS 'Timestamp when the approval request expires (default 15 minutes)';

-- Create a view for pending approvals with user info
CREATE OR REPLACE VIEW pending_approvals_view AS
SELECT 
  aq.id,
  aq.user_id,
  u.email as user_email,
  aq.request_type,
  aq.status,
  aq.pending_transaction,
  aq.estimated_risk_score,
  aq.estimated_usd_value,
  aq.agent_reasoning,
  aq.limiting_factors,
  aq.alternative_options,
  aq.expires_at,
  aq.created_at,
  EXTRACT(EPOCH FROM (aq.expires_at - NOW())) as seconds_until_expiry
FROM approval_queue aq
JOIN users u ON aq.user_id = u.id
WHERE aq.status = 'pending'
ORDER BY aq.created_at DESC;

COMMENT ON VIEW pending_approvals_view IS 'View of pending approvals with user information and time until expiry';

-- Verify migration
DO $$
DECLARE
  table_exists BOOLEAN;
  index_count INTEGER;
BEGIN
  SELECT EXISTS (
    SELECT FROM information_schema.tables 
    WHERE table_name = 'approval_queue'
  ) INTO table_exists;
  
  SELECT COUNT(*) INTO index_count
  FROM pg_indexes
  WHERE tablename = 'approval_queue';
  
  RAISE NOTICE 'Migration completed successfully';
  RAISE NOTICE 'Table exists: %', table_exists;
  RAISE NOTICE 'Indexes created: %', index_count;
  
  IF NOT table_exists THEN
    RAISE EXCEPTION 'Table approval_queue was not created!';
  END IF;
  
  IF index_count < 6 THEN
    RAISE WARNING 'Expected at least 6 indexes, found %', index_count;
  END IF;
END $$;

-- Run initial expiration check
SELECT expire_pending_approvals();
