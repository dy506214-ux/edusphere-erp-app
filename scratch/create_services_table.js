const { Client } = require('pg');

async function main() {
  const dbUri = "postgresql://postgres.xernedkpgdrvjokokdoa:akshitsha84@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres";
  console.log("Connecting to Supabase PostgreSQL...");
  const client = new Client({
    connectionString: dbUri,
  });

  const sql = `
    -- Create ServiceRequest table
    CREATE TABLE IF NOT EXISTS public."ServiceRequest" (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        "requestNumber" TEXT NOT NULL,
        "requesterId" UUID NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        type TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'PENDING',
        "createdAt" TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
    );

    -- Enable RLS
    ALTER TABLE public."ServiceRequest" ENABLE ROW LEVEL SECURITY;

    -- Drop policy if exists and create new one
    DROP POLICY IF EXISTS "Allow all actions for ServiceRequest" ON public."ServiceRequest";
    CREATE POLICY "Allow all actions for ServiceRequest" ON public."ServiceRequest" FOR ALL USING (true) WITH CHECK (true);

    -- Add to Realtime publication if not already added
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'ServiceRequest'
      ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public."ServiceRequest";
      END IF;
    END $$;
  `;

  try {
    await client.connect();
    console.log("Connected successfully!");
    console.log("Creating ServiceRequest table and enabling Realtime...");
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
