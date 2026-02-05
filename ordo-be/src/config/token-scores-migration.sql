-- Token Risk Scores Migration
-- Stores token risk scores from Range Protocol API
-- Implements caching with 1-hour TTL

-- Check if table exists and create if not
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'token_scores') THEN
    CREATE TABLE token_scores (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      token_address TEXT NOT NULL UNIQUE,
      market_score INTEGER NOT NULL CHECK (market_score >= 0 AND market_score <= 100),
      risk_score INTEGER NOT NULL CHECK (risk_score >= 0 AND risk_score <= 100),
      liquidity_score INTEGER NOT NULL CHECK (liquidity_score >= 0 AND liquidity_score <= 100),
      limiting_factors TEXT[] DEFAULT '{}',
      last_fetched TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
      created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
      updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    );
  END IF;
END $$;

-- Add columns if they don't exist (for existing tables)
DO $$ 
BEGIN
  -- Add market_score if not exists
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name = 'token_scores' AND column_name = 'market_score') THEN
    ALTER TABLE token_scores ADD COLUMN market_score INTEGER NOT NULL DEFAULT 50 
      CHECK (market_score >= 0 AND market_score <= 100);
  END IF;

  -- Add risk_score if not exists
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name = 'token_scores' AND column_name = 'risk_score') THEN
    ALTER TABLE token_scores ADD COLUMN risk_score INTEGER NOT NULL DEFAULT 50 
      CHECK (risk_score >= 0 AND risk_score <= 100);
  END IF;

  -- Add liquidity_score if not exists
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name = 'token_scores' AND column_name = 'liquidity_score') THEN
    ALTER TABLE token_scores ADD COLUMN liquidity_score INTEGER NOT NULL DEFAULT 50 
      CHECK (liquidity_score >= 0 AND liquidity_score <= 100);
  END IF;

  -- Add limiting_factors if not exists
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name = 'token_scores' AND column_name = 'limiting_factors') THEN
    ALTER TABLE token_scores ADD COLUMN limiting_factors TEXT[] DEFAULT '{}';
  END IF;

  -- Add last_fetched if not exists
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name = 'token_scores' AND column_name = 'last_fetched') THEN
    ALTER TABLE token_scores ADD COLUMN last_fetched TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW();
  END IF;

  -- Add created_at if not exists
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name = 'token_scores' AND column_name = 'created_at') THEN
    ALTER TABLE token_scores ADD COLUMN created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
  END IF;

  -- Add updated_at if not exists
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name = 'token_scores' AND column_name = 'updated_at') THEN
    ALTER TABLE token_scores ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
  END IF;

  -- Add token_address if not exists (unlikely but safe)
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name = 'token_scores' AND column_name = 'token_address') THEN
    ALTER TABLE token_scores ADD COLUMN token_address TEXT NOT NULL UNIQUE;
  END IF;
END $$;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_token_scores_address ON token_scores(token_address);
CREATE INDEX IF NOT EXISTS idx_token_scores_risk ON token_scores(risk_score DESC);
CREATE INDEX IF NOT EXISTS idx_token_scores_last_fetched ON token_scores(last_fetched);

-- Create index for high-risk tokens
CREATE INDEX IF NOT EXISTS idx_token_scores_high_risk ON token_scores(risk_score) WHERE risk_score > 70;

-- Add comments
COMMENT ON TABLE token_scores IS 'Stores token risk scores from Range Protocol API with caching';
COMMENT ON COLUMN token_scores.token_address IS 'Solana token mint address';
COMMENT ON COLUMN token_scores.market_score IS 'Overall market score (0-100)';
COMMENT ON COLUMN token_scores.risk_score IS 'Risk score (0-100, higher = riskier)';
COMMENT ON COLUMN token_scores.liquidity_score IS 'Liquidity score (0-100)';
COMMENT ON COLUMN token_scores.limiting_factors IS 'Array of risk factors';
COMMENT ON COLUMN token_scores.last_fetched IS 'When score was last fetched from API';

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_token_scores_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update updated_at
DROP TRIGGER IF EXISTS trigger_update_token_scores_updated_at ON token_scores;
CREATE TRIGGER trigger_update_token_scores_updated_at
  BEFORE UPDATE ON token_scores
  FOR EACH ROW
  EXECUTE FUNCTION update_token_scores_updated_at();

-- Function to clean up old scores (optional maintenance)
CREATE OR REPLACE FUNCTION cleanup_old_token_scores(days_old INTEGER DEFAULT 30)
RETURNS INTEGER AS $$
DECLARE
  deleted_count INTEGER;
BEGIN
  DELETE FROM token_scores
  WHERE last_fetched < NOW() - (days_old || ' days')::INTERVAL;
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION cleanup_old_token_scores IS 'Removes token scores older than specified days (default 30)';

-- Sample data for testing (optional)
-- INSERT INTO token_scores (token_address, market_score, risk_score, liquidity_score, limiting_factors)
-- VALUES 
--   ('So11111111111111111111111111111111111111112', 95, 15, 98, ARRAY['None']),
--   ('EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v', 92, 18, 95, ARRAY['None']),
--   ('Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB', 90, 20, 93, ARRAY['None']);
