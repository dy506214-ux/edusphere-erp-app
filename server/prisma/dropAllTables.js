const { Client } = require('pg');
require('dotenv').config();

const pgClient = new Client({
  connectionString: process.env.DIRECT_URL || process.env.DATABASE_URL
});

async function main() {
  console.log('🔌 Connecting to the database to drop all tables and types...');
  await pgClient.connect();
  console.log('✅ Connected');

  // 1. Drop all tables CASCADE
  console.log('🗑️ Dropping all tables...');
  const dropTablesQuery = `
    DO $$ DECLARE
        r RECORD;
    BEGIN
        FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public') LOOP
            EXECUTE 'DROP TABLE IF EXISTS public.' || quote_ident(r.tablename) || ' CASCADE';
        END LOOP;
    END $$;
  `;
  await pgClient.query(dropTablesQuery);
  console.log('✅ All tables dropped successfully.');

  // 2. Drop all custom types/enums CASCADE
  console.log('🗑️ Dropping all custom types/enums...');
  const dropTypesQuery = `
    DO $$ DECLARE
        r RECORD;
    BEGIN
        FOR r IN (
            SELECT typname FROM pg_type t 
            JOIN pg_namespace n ON n.oid = t.typnamespace 
            WHERE n.nspname = 'public' AND t.typtype = 'e'
        ) LOOP
            EXECUTE 'DROP TYPE IF EXISTS public.' || quote_ident(r.typname) || ' CASCADE';
        END LOOP;
    END $$;
  `;
  await pgClient.query(dropTypesQuery);
  console.log('✅ All custom types/enums dropped successfully.');

  // 3. Optional: Clear auth.users
  try {
    console.log('🧹 Clearing Supabase auth.users...');
    await pgClient.query('DELETE FROM auth.users CASCADE;');
    console.log('✅ Cleared auth.users');
  } catch (error) {
    console.warn('⚠️ Could not clear auth.users (likely no permission or already empty):', error.message);
  }

  await pgClient.end();
  console.log('\n🎉 Database is now 100% clean and completely empty!');
}

main().catch(async (err) => {
  console.error('❌ Error dropping database schema:', err.message);
  await pgClient.end();
});
