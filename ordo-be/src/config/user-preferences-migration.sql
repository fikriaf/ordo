-- User Preferences Migration
-- Updates user_preferences table to new schema

-- First, check if table exists and what columns it has
DO $$
BEGIN
  -- Drop old columns if they exist
  IF EXISTS (SELECT 1 FROM information_schema.columns 
             WHERE table_name = 'user_preferences' AND column_name = 'require_approval_above_sol') THEN
    ALTER TABLE user_preferences DROP COLUMN IF EXISTS require_approval_above_sol;
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.columns 
             WHERE table_name = 'user_preferences' AND column_name = 'auto_approve_whitelisted') THEN
    ALTER TABLE user_preferences DROP COLUMN IF EXISTS auto_approve_whitelisted;
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.columns 
             WHERE table_name = 'user_preferences' AND column_name = 'max_slippage_bps') THEN
    ALTER TABLE user_preferences DROP COLUMN IF EXISTS max_slippage_bps;
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.columns 
             WHERE table_name = 'user_preferences' AND column_name = 'priority_fee_lamports') THEN
    ALTER TABLE user_preferences DROP COLUMN IF EXISTS priority_fee_lamports;
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.columns 
             WHERE table_name = 'user_preferences' AND column_name = 'notification_channels') THEN
    ALTER TABLE user_preferences DROP COLUMN IF EXISTS notification_channels;
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.columns 
             WHERE table_name = 'user_preferences' AND column_name = 'alert_on_large_movements') THEN
    ALTER TABLE user_preferences DROP COLUMN IF EXISTS alert_on_large_movements;
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.columns 
             WHERE table_name = 'user_preferences' AND column_name = 'alert_threshold_usdc') THEN
    ALTER TABLE user_preferences DROP COLUMN IF EXISTS alert_threshold_usdc;
  END IF;
END $$;

-- Add new columns if they don't exist
ALTER TABLE user_preferences 
  ADD COLUMN IF NOT EXISTS require_approval_above_usdc DECIMAL(20, 2) NOT NULL DEFAULT 50.0 CHECK (require_approval_above_usdc >= 0),
  ADD COLUMN IF NOT EXISTS min_token_risk_score INTEGER NOT NULL DEFAULT 50 CHECK (min_token_risk_score >= 0 AND min_token_risk_score <= 100),
  ADD COLUMN IF NOT EXISTS block_high_risk_tokens BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS notify_on_approval_needed BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS notify_on_transaction_complete BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS notify_on_price_alerts BOOLEAN NOT NULL DEFAULT false;

-- Update existing constraints if needed
DO $$
BEGIN
  -- Update max_single_transfer_sol constraint
  ALTER TABLE user_preferences DROP CONSTRAINT IF EXISTS user_preferences_max_single_transfer_sol_check;
  ALTER TABLE user_preferences ADD CONSTRAINT user_preferences_max_single_transfer_sol_check 
    CHECK (max_single_transfer_sol >= 0 AND max_single_transfer_sol <= 1000);
  
  -- Update max_daily_volume_usdc constraint
  ALTER TABLE user_preferences DROP CONSTRAINT IF EXISTS user_preferences_max_daily_volume_usdc_check;
  ALTER TABLE user_preferences ADD CONSTRAINT user_preferences_max_daily_volume_usdc_check 
    CHECK (max_daily_volume_usdc >= 0 AND max_daily_volume_usdc <= 1000000);
  
  -- Update default_slippage_bps constraint
  ALTER TABLE user_preferences DROP CONSTRAINT IF EXISTS user_preferences_default_slippage_bps_check;
  ALTER TABLE user_preferences ADD CONSTRAINT user_preferences_default_slippage_bps_check 
    CHECK (default_slippage_bps >= 1 AND default_slippage_bps <= 10000);
  
  -- Update agent_autonomy_level constraint
  ALTER TABLE user_preferences DROP CONSTRAINT IF EXISTS user_preferences_agent_autonomy_level_check;
  ALTER TABLE user_preferences ADD CONSTRAINT user_preferences_agent_autonomy_level_check 
    CHECK (agent_autonomy_level IN ('low', 'medium', 'high'));
END $$;

-- Create indexes if they don't exist
CREATE INDEX IF NOT EXISTS idx_user_preferences_user_id ON user_preferences(user_id);
CREATE INDEX IF NOT EXISTS idx_user_preferences_autonomy ON user_preferences(agent_autonomy_level);

-- Ensure updated_at trigger exists
CREATE OR REPLACE FUNCTION update_user_preferences_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_user_preferences_updated_at ON user_preferences;
CREATE TRIGGER trigger_update_user_preferences_updated_at
  BEFORE UPDATE ON user_preferences
  FOR EACH ROW
  EXECUTE FUNCTION update_user_preferences_updated_at();

-- Ensure auto-create trigger exists for new users
CREATE OR REPLACE FUNCTION create_default_user_preferences()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO user_preferences (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_create_default_user_preferences ON users;
CREATE TRIGGER trigger_create_default_user_preferences
  AFTER INSERT ON users
  FOR EACH ROW
  EXECUTE FUNCTION create_default_user_preferences();

-- Add comments for documentation
COMMENT ON COLUMN user_preferences.require_approval_above_usdc IS 'Require approval for transactions above this USDC value';
COMMENT ON COLUMN user_preferences.min_token_risk_score IS 'Minimum acceptable token risk score (0-100)';
COMMENT ON COLUMN user_preferences.block_high_risk_tokens IS 'Block transactions with high-risk tokens (score > 70)';
COMMENT ON COLUMN user_preferences.notify_on_approval_needed IS 'Send notification when approval is needed';
COMMENT ON COLUMN user_preferences.notify_on_transaction_complete IS 'Send notification when transaction completes';
COMMENT ON COLUMN user_preferences.notify_on_price_alerts IS 'Send notification for price alerts';

-- Backfill new columns for existing records
UPDATE user_preferences 
SET 
  require_approval_above_usdc = COALESCE(require_approval_above_usdc, 50.0),
  min_token_risk_score = COALESCE(min_token_risk_score, 50),
  block_high_risk_tokens = COALESCE(block_high_risk_tokens, true),
  notify_on_approval_needed = COALESCE(notify_on_approval_needed, true),
  notify_on_transaction_complete = COALESCE(notify_on_transaction_complete, true),
  notify_on_price_alerts = COALESCE(notify_on_price_alerts, false)
WHERE require_approval_above_usdc IS NULL 
   OR min_token_risk_score IS NULL 
   OR block_high_risk_tokens IS NULL;

-- Create default preferences for users without preferences
INSERT INTO user_preferences (user_id)
SELECT id FROM users
WHERE id NOT IN (SELECT user_id FROM user_preferences)
ON CONFLICT (user_id) DO NOTHING;

-- Verify migration
DO $$
DECLARE
  user_count INTEGER;
  pref_count INTEGER;
  col_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO user_count FROM users;
  SELECT COUNT(*) INTO pref_count FROM user_preferences;
  SELECT COUNT(*) INTO col_count FROM information_schema.columns 
    WHERE table_name = 'user_preferences' AND column_name = 'require_approval_above_usdc';
  
  RAISE NOTICE 'Migration completed successfully';
  RAISE NOTICE 'Users: %, Preferences: %', user_count, pref_count;
  RAISE NOTICE 'New column exists: %', (col_count > 0);
  
  IF user_count != pref_count THEN
    RAISE WARNING 'User count (%) does not match preferences count (%)', user_count, pref_count;
  END IF;
  
  IF col_count = 0 THEN
    RAISE EXCEPTION 'Column require_approval_above_usdc was not created!';
  END IF;
END $$;
