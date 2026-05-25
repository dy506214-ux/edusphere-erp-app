const { Client } = require('pg');

async function main() {
  const dbUri = "postgresql://postgres.xernedkpgdrvjokokdoa:akshitsha84@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres";
  console.log("Connecting to Supabase PostgreSQL...");
  const client = new Client({
    connectionString: dbUri,
  });

  const sql = `
    -- Create messages table
    CREATE TABLE IF NOT EXISTS public.messages (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        sender_id UUID NOT NULL,
        recipient_id UUID NOT NULL,
        text TEXT NOT NULL,
        is_seen BOOLEAN DEFAULT FALSE NOT NULL,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
    );

    -- Enable RLS
    ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

    -- Drop policy if exists and create new one
    DROP POLICY IF EXISTS "Allow all actions for messages" ON public.messages;
    CREATE POLICY "Allow all actions for messages" ON public.messages FOR ALL USING (true) WITH CHECK (true);

    -- Add to Realtime publication if not already added
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

  try {
    await client.connect();
    console.log("Connected successfully!");
    console.log("Creating messages table and enabling Realtime...");
    await client.query(sql);
    console.log("🎉 Table created and Supabase Realtime enabled successfully!");
  } catch (err) {
    console.error("Error executing migration:", err);
    process.exit(1);
  } finally {
    await client.end();
  }
}

main();
