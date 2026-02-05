-- NFT Management Tables Migration
-- Date: 2026-02-03
-- Description: Tables for NFT collections and user NFT tracking

-- NFT Collections Table
CREATE TABLE IF NOT EXISTS nft_collections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    collection_address TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    symbol TEXT NOT NULL,
    description TEXT,
    image TEXT,
    floor_price_sol DECIMAL(18, 9),
    volume_24h_sol DECIMAL(18, 9),
    holder_count INTEGER DEFAULT 0,
    total_supply INTEGER DEFAULT 0,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- User NFTs Table
CREATE TABLE IF NOT EXISTS user_nfts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    mint_address TEXT NOT NULL,
    collection_id UUID REFERENCES nft_collections(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    symbol TEXT NOT NULL,
    image TEXT,
    metadata_uri TEXT,
    last_price_sol DECIMAL(18, 9),
    acquired_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, mint_address)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_nft_collections_address ON nft_collections(collection_address);
CREATE INDEX IF NOT EXISTS idx_nft_collections_floor_price ON nft_collections(floor_price_sol DESC);
CREATE INDEX IF NOT EXISTS idx_user_nfts_user_id ON user_nfts(user_id);
CREATE INDEX IF NOT EXISTS idx_user_nfts_mint_address ON user_nfts(mint_address);
CREATE INDEX IF NOT EXISTS idx_user_nfts_collection_id ON user_nfts(collection_id);
CREATE INDEX IF NOT EXISTS idx_user_nfts_acquired_at ON user_nfts(acquired_at DESC);

-- Updated_at trigger for nft_collections
CREATE OR REPLACE FUNCTION update_nft_collections_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER nft_collections_updated_at
    BEFORE UPDATE ON nft_collections
    FOR EACH ROW
    EXECUTE FUNCTION update_nft_collections_updated_at();

-- Comments
COMMENT ON TABLE nft_collections IS 'NFT collection information and statistics';
COMMENT ON TABLE user_nfts IS 'User-owned NFTs tracking';
COMMENT ON COLUMN nft_collections.floor_price_sol IS 'Current floor price in SOL';
COMMENT ON COLUMN nft_collections.volume_24h_sol IS '24-hour trading volume in SOL';
COMMENT ON COLUMN user_nfts.last_price_sol IS 'Last known price when acquired/traded';
