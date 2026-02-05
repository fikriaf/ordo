/**
 * Run NFT Migration
 * Automatically creates NFT tables in Supabase
 */

const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error('❌ Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function runMigration() {
  try {
    console.log('🚀 Running NFT Migration...\n');

    // Read SQL file
    const sqlPath = path.join(__dirname, 'src', 'config', 'nft-migration.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');

    console.log('📝 Executing SQL migration...\n');

    // Execute full SQL
    const { data, error } = await supabase.rpc('exec', { sql });

    if (error) {
      console.error('❌ Migration failed:', error.message);
      console.log('\n⚠️  Please run the SQL manually in Supabase SQL Editor:');
      console.log('   1. Open Supabase Dashboard');
      console.log('   2. Go to SQL Editor');
      console.log('   3. Copy-paste from: src/config/nft-migration.sql');
      console.log('   4. Click Run\n');
      process.exit(1);
    }

    console.log('✅ Migration completed successfully!\n');
    console.log('Created tables:');
    console.log('  - nft_collections');
    console.log('  - user_nfts');
    console.log('\nCreated indexes and triggers');

  } catch (error) {
    console.error('❌ Migration failed:', error.message);
    console.log('\n⚠️  Please run the SQL manually in Supabase SQL Editor:');
    console.log('   1. Open Supabase Dashboard');
    console.log('   2. Go to SQL Editor');
    console.log('   3. Copy-paste from: src/config/nft-migration.sql');
    console.log('   4. Click Run\n');
    process.exit(1);
  }
}

runMigration();
