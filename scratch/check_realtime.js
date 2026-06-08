const { Client } = require('pg');

async function main() {
  const dbUri = "postgresql://postgres.xernedkpgdrvjokokdoa:akshitsha84@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres";
  console.log("Connecting...");
  const client = new Client({
    connectionString: dbUri,
  });

  const sql = `
    SELECT * FROM pg_publication_tables WHERE pubname = 'supabase_realtime';
  `;

  try {
    await client.connect();
    const res = await client.query(sql);
    console.log("Realtime Tables:", res.rows.map(r => r.tablename));
  } catch (err) {
    console.error("Error:", err);
  } finally {
    await client.end();
  }
}

main();
