const { Client } = require('pg');

async function main() {
  const dbUri = "postgresql://postgres.xernedkpgdrvjokokdoa:akshitsha84@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres";
  const client = new Client({ connectionString: dbUri });

  try {
    await client.connect();
    console.log("Connected to database!");

    const sql = `
      -- Disable RLS on Transport-related tables
      ALTER TABLE IF EXISTS public."TransportAllocation" DISABLE ROW LEVEL SECURITY;
      ALTER TABLE IF EXISTS public."TransportRoute" DISABLE ROW LEVEL SECURITY;
      ALTER TABLE IF EXISTS public."RouteStop" DISABLE ROW LEVEL SECURITY;
      ALTER TABLE IF EXISTS public."Vehicle" DISABLE ROW LEVEL SECURITY;

      -- Grant permissions to anon and authenticated roles
      GRANT SELECT ON public."TransportAllocation" TO anon, authenticated;
      GRANT SELECT ON public."TransportRoute" TO anon, authenticated;
      GRANT SELECT ON public."RouteStop" TO anon, authenticated;
      GRANT SELECT ON public."Vehicle" TO anon, authenticated;
      
      GRANT ALL ON public."TransportAllocation" TO anon, authenticated;
      GRANT ALL ON public."TransportRoute" TO anon, authenticated;
      GRANT ALL ON public."RouteStop" TO anon, authenticated;
      GRANT ALL ON public."Vehicle" TO anon, authenticated;
    `;

    console.log("Executing SQL RLS fix...");
    await client.query(sql);
    console.log("🎉 RLS disabled and permissions granted for Transport tables!");
  } catch (err) {
    console.error("Error executing SQL:", err);
  } finally {
    await client.end();
  }
}

main();
