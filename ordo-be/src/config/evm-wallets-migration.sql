-- EVM Wallets Migration
-- This migration adds support for EVM-compatible chains (Ethereum, Polygon, BSC, etc.)

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create evm_wallets table
CREATE TABLE IF NOT EXISTS evm_wallets (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  chain_id VARCHAR(50) NOT NULL,
  address VARCHAR(42) NOT NULL,
  encrypted_private_key TEXT NOT NULL,
  encryption_iv TEXT NOT NULL,
  encryption_auth_tag TEXT NOT NULL,
  is_primary BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_evm_wallets_user_id ON evm_wallets(user_id);
CREATE INDEX IF NOT EXISTS idx_evm_wallets_address ON evm_wallets(address);
CREATE INDEX IF NOT EXISTS idx_evm_wallets_chain_id ON evm_wallets(chain_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_evm_wallets_user_address ON evm_wallets(user_id, address);

-- Add updated_at trigger
CREATE OR REPLACE FUNCTION update_evm_wallets_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_evm_wallets_updated_at
  BEFORE UPDATE ON evm_wallets
  FOR EACH ROW
  EXECUTE FUNCTION update_evm_wallets_updated_at();

-- Add comments for documentation
COMMENT ON TABLE evm_wallets IS 'EVM-compatible chain wallets (Ethereum, Polygon, BSC, etc.)';
COMMENT ON COLUMN evm_wallets.chain_id IS 'Chain identifier (ethereum, polygon, bsc, arbitrum, optimism, avalanche)';
COMMENT ON COLUMN evm_wallets.address IS 'EVM wallet address (0x...)';
COMMENT ON COLUMN evm_wallets.encrypted_private_key IS 'AES-256-GCM encrypted private key';
COMMENT ON COLUMN evm_wallets.encryption_iv IS 'Initialization vector for encryption';
COMMENT ON COLUMN evm_wallets.encryption_auth_tag IS 'Authentication tag for GCM mode';
COMMENT ON COLUMN evm_wallets.is_primary IS 'Whether this is the user''s primary EVM wallet for this chain';

-- Constraint to ensure valid chain IDs
ALTER TABLE evm_wallets ADD CONSTRAINT check_valid_chain_id 
  CHECK (chain_id IN ('ethereum', 'polygon', 'bsc', 'arbitrum', 'optimism', 'avalanche'));

-- Constraint to ensure valid Ethereum address format
ALTER TABLE evm_wallets ADD CONSTRAINT check_valid_eth_address 
  CHECK (address ~ '^0x[a-fA-F0-9]{40}$');
