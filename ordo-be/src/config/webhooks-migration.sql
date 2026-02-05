-- Webhook System Migration
-- Date: 2026-02-04
-- Description: Tables for webhook management and delivery tracking

-- Webhooks Table
CREATE TABLE IF NOT EXISTS webhooks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Webhook configuration
    url TEXT NOT NULL,
    secret TEXT NOT NULL, -- For signature verification
    description TEXT,
    
    -- Event subscriptions
    events TEXT[] NOT NULL DEFAULT '{}', -- Array of event types to subscribe to
    
    -- Status and settings
    is_active BOOLEAN DEFAULT true,
    retry_count INTEGER DEFAULT 3,
    timeout_seconds INTEGER DEFAULT 30,
    
    -- Metadata
    metadata JSONB DEFAULT '{}',
    
    -- Statistics
    total_deliveries INTEGER DEFAULT 0,
    successful_deliveries INTEGER DEFAULT 0,
    failed_deliveries INTEGER DEFAULT 0,
    last_delivery_at TIMESTAMPTZ,
    last_success_at TIMESTAMPTZ,
    last_failure_at TIMESTAMPTZ,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT valid_url CHECK (url ~* '^https?://'),
    CONSTRAINT valid_retry_count CHECK (retry_count >= 0 AND retry_count <= 10),
    CONSTRAINT valid_timeout CHECK (timeout_seconds > 0 AND timeout_seconds <= 300)
);

-- Webhook Deliveries Table
CREATE TABLE IF NOT EXISTS webhook_deliveries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    webhook_id UUID NOT NULL REFERENCES webhooks(id) ON DELETE CASCADE,
    
    -- Event details
    event_type TEXT NOT NULL,
    event_data JSONB NOT NULL,
    
    -- Delivery details
    status TEXT NOT NULL CHECK (status IN ('pending', 'success', 'failed', 'retrying')),
    attempt_count INTEGER DEFAULT 0,
    max_attempts INTEGER DEFAULT 3,
    
    -- Request/Response
    request_headers JSONB,
    request_body JSONB,
    response_status INTEGER,
    response_body TEXT,
    response_headers JSONB,
    
    -- Timing
    duration_ms INTEGER,
    next_retry_at TIMESTAMPTZ,
    
    -- Error tracking
    error_message TEXT,
    error_details JSONB,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    delivered_at TIMESTAMPTZ,
    failed_at TIMESTAMPTZ,
    
    -- Constraints
    CONSTRAINT valid_status CHECK (status IN ('pending', 'success', 'failed', 'retrying')),
    CONSTRAINT valid_attempt_count CHECK (attempt_count >= 0)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_webhooks_user_id ON webhooks(user_id);
CREATE INDEX IF NOT EXISTS idx_webhooks_is_active ON webhooks(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_webhooks_events ON webhooks USING GIN(events);
CREATE INDEX IF NOT EXISTS idx_webhooks_last_delivery ON webhooks(last_delivery_at DESC);

CREATE INDEX IF NOT EXISTS idx_webhook_deliveries_webhook_id ON webhook_deliveries(webhook_id);
CREATE INDEX IF NOT EXISTS idx_webhook_deliveries_status ON webhook_deliveries(status);
CREATE INDEX IF NOT EXISTS idx_webhook_deliveries_event_type ON webhook_deliveries(event_type);
CREATE INDEX IF NOT EXISTS idx_webhook_deliveries_created_at ON webhook_deliveries(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_webhook_deliveries_next_retry ON webhook_deliveries(next_retry_at) 
    WHERE status = 'retrying' AND next_retry_at IS NOT NULL;

-- Updated_at trigger for webhooks
CREATE OR REPLACE FUNCTION update_webhooks_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_webhooks_updated_at
BEFORE UPDATE ON webhooks
FOR EACH ROW
EXECUTE FUNCTION update_webhooks_updated_at();

-- Function to update webhook statistics
CREATE OR REPLACE FUNCTION update_webhook_stats()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'success' THEN
        UPDATE webhooks
        SET 
            total_deliveries = total_deliveries + 1,
            successful_deliveries = successful_deliveries + 1,
            last_delivery_at = NOW(),
            last_success_at = NOW()
        WHERE id = NEW.webhook_id;
    ELSIF NEW.status = 'failed' THEN
        UPDATE webhooks
        SET 
            total_deliveries = total_deliveries + 1,
            failed_deliveries = failed_deliveries + 1,
            last_delivery_at = NOW(),
            last_failure_at = NOW()
        WHERE id = NEW.webhook_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_webhook_stats
AFTER UPDATE OF status ON webhook_deliveries
FOR EACH ROW
WHEN (OLD.status IS DISTINCT FROM NEW.status AND NEW.status IN ('success', 'failed'))
EXECUTE FUNCTION update_webhook_stats();

-- Function to cleanup old deliveries
CREATE OR REPLACE FUNCTION cleanup_old_webhook_deliveries(days_to_keep INTEGER DEFAULT 30)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM webhook_deliveries
    WHERE created_at < NOW() - (days_to_keep || ' days')::INTERVAL
        AND status IN ('success', 'failed');
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Webhook Statistics View
CREATE OR REPLACE VIEW webhook_stats AS
SELECT 
    w.id,
    w.user_id,
    w.url,
    w.is_active,
    w.total_deliveries,
    w.successful_deliveries,
    w.failed_deliveries,
    CASE 
        WHEN w.total_deliveries > 0 
        THEN ROUND((w.successful_deliveries::DECIMAL / w.total_deliveries) * 100, 2)
        ELSE 0
    END as success_rate,
    w.last_delivery_at,
    w.last_success_at,
    w.last_failure_at,
    COUNT(wd.id) FILTER (WHERE wd.status = 'pending') as pending_deliveries,
    COUNT(wd.id) FILTER (WHERE wd.status = 'retrying') as retrying_deliveries,
    AVG(wd.duration_ms) FILTER (WHERE wd.status = 'success') as avg_delivery_time_ms
FROM webhooks w
LEFT JOIN webhook_deliveries wd ON w.id = wd.webhook_id
GROUP BY w.id;

-- Event Types Reference (for documentation)
-- Available event types:
-- - transaction.created
-- - transaction.confirmed
-- - transaction.failed
-- - approval.created
-- - approval.approved
-- - approval.rejected
-- - balance.changed
-- - nft.received
-- - nft.transferred
-- - price.alert
-- - portfolio.updated

-- Comments
COMMENT ON TABLE webhooks IS 'Stores user webhook configurations for event notifications';
COMMENT ON TABLE webhook_deliveries IS 'Tracks webhook delivery attempts and results';
COMMENT ON COLUMN webhooks.secret IS 'Secret key for HMAC signature verification';
COMMENT ON COLUMN webhooks.events IS 'Array of event types this webhook subscribes to';
COMMENT ON COLUMN webhook_deliveries.status IS 'Delivery status: pending, success, failed, retrying';
COMMENT ON COLUMN webhook_deliveries.next_retry_at IS 'Timestamp for next retry attempt (exponential backoff)';
