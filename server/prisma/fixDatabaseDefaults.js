const { Client } = require('pg');
require('dotenv').config();

const pgClient = new Client({
  connectionString: process.env.DIRECT_URL || process.env.DATABASE_URL
});

async function main() {
  console.log('🔌 Connecting to database to apply defaults...');
  await pgClient.connect();
  console.log('✅ Connected');

  // 1. Get all tables in public schema
  const tablesRes = await pgClient.query(`
    SELECT table_name 
    FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
  `);
  
  const tables = tablesRes.rows.map(r => r.table_name);
  console.log(`Found ${tables.length} tables to inspect...`);
  
  for (const table of tables) {
    // Check if table has an 'id' column
    const colRes = await pgClient.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_schema = 'public' AND table_name = $1 AND column_name = 'id'
    `, [table]);
    
    if (colRes.rows.length > 0) {
      try {
        const dataType = colRes.rows[0].data_type;
        console.log(`Setting DEFAULT gen_random_uuid() on table "${table}" (ID column type: ${dataType})...`);
        
        if (dataType === 'text' || dataType === 'character varying') {
          await pgClient.query(`ALTER TABLE public."${table}" ALTER COLUMN "id" SET DEFAULT gen_random_uuid()::text`);
        } else {
          await pgClient.query(`ALTER TABLE public."${table}" ALTER COLUMN "id" SET DEFAULT gen_random_uuid()`);
        }
        console.log(`   - Success for "${table}"`);
      } catch (err) {
        console.error(`   - Failed for "${table}":`, err.message);
      }
    }
  }

  // 2. Re-create messages table (since we dropped all tables)
  console.log('\n💬 Creating messages table for the chat feature...');
  const createMessagesSql = `
    CREATE TABLE IF NOT EXISTS public.messages (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        sender_id UUID NOT NULL,
        recipient_id UUID NOT NULL,
        text TEXT NOT NULL,
        is_seen BOOLEAN DEFAULT FALSE NOT NULL,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
    );
    ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Allow all actions for messages" ON public.messages;
    CREATE POLICY "Allow all actions for messages" ON public.messages FOR ALL USING (true) WITH CHECK (true);
  `;
  await pgClient.query(createMessagesSql);
  console.log('✅ messages table created and RLS policy configured');

  // 3. Enable Realtime on messages table
  try {
    console.log('📡 Enabling Supabase Realtime for messages table...');
    const realtimeSql = `
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_publication_tables 
          WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'messages'
        ) THEN
          ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
        END IF;
      END $$;
    `;
    await pgClient.query(realtimeSql);
    console.log('✅ Supabase Realtime enabled for messages');
  } catch (err) {
    console.warn('⚠️ Could not add messages to realtime publication:', err.message);
  }

  await pgClient.end();
  console.log('\n🎉 All database primary key defaults and chat configurations applied successfully!');
}

main().catch(async (err) => {
  console.error('❌ Error applying database defaults:', err.message);
  await pgClient.end();
});
