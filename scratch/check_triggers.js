const { Client } = require('pg');

async function main() {
  const dbUri = "postgresql://postgres.xernedkpgdrvjokokdoa:akshitsha84@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres";
  const client = new Client({ connectionString: dbUri });

  const sql = `
    SELECT tgname, proname 
    FROM pg_trigger 
    JOIN pg_proc ON pg_proc.oid = pg_trigger.tgfoid 
    WHERE tgrelid = '"ServiceRequest"'::regclass;
  `;

  try {
    await client.connect();
    const res = await client.query(sql);
    console.log("Triggers:", res.rows);
  } catch (err) {
    console.error("Error:", err);
  } finally {
    await client.end();
  }
}

main();
