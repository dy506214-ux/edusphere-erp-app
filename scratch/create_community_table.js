const { Client } = require('pg');

async function main() {
  const dbUri = "postgresql://postgres.xernedkpgdrvjokokdoa:akshitsha84@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres";
  console.log("Connecting to Supabase PostgreSQL...");
  const client = new Client({
    connectionString: dbUri,
  });

  const sql = `
    -- Create CommunityPost table
    CREATE TABLE IF NOT EXISTS public."CommunityPost" (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        author_name TEXT NOT NULL,
        author_role TEXT NOT NULL,
        category TEXT NOT NULL,
        content TEXT NOT NULL,
        likes INTEGER DEFAULT 0,
        insightfuls INTEGER DEFAULT 0,
        comments JSONB DEFAULT '[]'::jsonb,
        poll_options JSONB DEFAULT '[]'::jsonb,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
    );

    -- Enable RLS
    ALTER TABLE public."CommunityPost" ENABLE ROW LEVEL SECURITY;

    -- Drop policy if exists and create new one
    DROP POLICY IF EXISTS "Allow all actions for CommunityPost" ON public."CommunityPost";
    CREATE POLICY "Allow all actions for CommunityPost" ON public."CommunityPost" FOR ALL USING (true) WITH CHECK (true);

    -- Add to Realtime publication if not already added
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'CommunityPost'
      ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public."CommunityPost";
      END IF;
    END $$;
  `;

  try {
    await client.connect();
    console.log("Connected successfully!");
    console.log("Creating CommunityPost table and enabling Realtime...");
    await client.query(sql);
    console.log("ðŸŽ‰ Table created and Supabase Realtime enabled successfully!");
  } catch (err) {
    console.error("Error executing migration:", err);
    process.exit(1);
  } finally {
    await client.end();
  }
}

main();
