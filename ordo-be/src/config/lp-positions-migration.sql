-- Liquidity Pool Positions Migration
-- Date: 2026-02-04
-- Description: Table for tracking user liquidity pool positions

-- LP Positions Table
CREATE TABLE IF NOT EXISTS lp_positions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    protocol TEXT NOT NULL CHECK (protocol IN ('raydium', 'meteora', 'orca')),
    pool_address TEXT NOT NULL,
    token_a TEXT NOT NULL,
    token_b TEXT NOT NULL,
    amount_a DECIMAL(18, 9) NOT NULL,
    amount_b DECIMAL(18, 9) NOT NULL,
    lp_tokens DECIMAL(18, 9) NOT NULL,
    initial_value_usd DECIMAL(18, 2) DEFAULT 0,
    current_value_usd DECIMAL(18, 2),
    fees_earned_usd DECIMAL(18, 2),
    impermanent_loss DECIMAL(18, 2),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'closed')),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_lp_positions_user_id ON lp_positions(user_id);
CREATE INDEX IF NOT EXISTS idx_lp_positions_protocol ON lp_positions(protocol);
CREATE INDEX IF NOT EXISTS idx_lp_positions_status ON lp_positions(status);
CREATE INDEX IF NOT EXISTS idx_lp_positions_pool_address ON lp_positions(pool_address);
CREATE INDEX IF NOT EXISTS idx_lp_positions_created_at ON lp_positions(created_at DESC);

-- Updated_at trigger
CREATE OR REPLACE FUNCTION update_lp_positions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER lp_positions_updated_at
    BEFORE UPDATE ON lp_positions
    FOR EACH ROW
    EXECUTE FUNCTION update_lp_positions_updated_at();

-- Comments
COMMENT ON TABLE lp_positions IS 'User liquidity pool positions across DeFi protocols';
COMMENT ON COLUMN lp_positions.protocol IS 'DEX protocol: raydium, meteora, or orca';
COMMENT ON COLUMN lp_positions.lp_tokens IS 'Amount of LP tokens received';
COMMENT ON COLUMN lp_positions.initial_value_usd IS 'Initial USD value when position was opened';
COMMENT ON COLUMN lp_positions.impermanent_loss IS 'Calculated impermanent loss in USD';
COMMENT ON COLUMN lp_positions.status IS 'Position status: active or closed';
