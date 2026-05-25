const { Client } = require('pg');

async function main() {
  const dbUri = "postgresql://postgres.xernedkpgdrvjokokdoa:akshitsha84@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres";
  const client = new Client({ connectionString: dbUri });

  try {
    await client.connect();
    console.log("Connected to Supabase PostgreSQL.");

    const res = await client.query(`
      SELECT * FROM public.messages 
      ORDER BY created_at ASC
    `);
    console.log("\n--- EVERY SINGLE MESSAGE IN DB ---");
    console.log(res.rows);

  } catch (err) {
    console.error("Error querying messages:", err);
  } finally {
    await client.end();
  }
}

main();
