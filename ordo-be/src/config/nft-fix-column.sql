-- Fix missing column in user_nfts table
-- Add last_price_sol column if it doesn't exist

ALTER TABLE user_nfts 
ADD COLUMN IF NOT EXISTS last_price_sol DECIMAL(18, 9);

-- Verify the column was added
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'user_nfts' 
AND column_name = 'last_price_sol';
