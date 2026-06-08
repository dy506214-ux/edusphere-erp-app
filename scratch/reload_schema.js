const { Client } = require('pg');

async function main() {
  const dbUri = "postgresql://postgres.xernedkpgdrvjokokdoa:akshitsha84@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres";
  console.log("Connecting to Supabase PostgreSQL to reload schema...");
  const client = new Client({
    connectionString: dbUri,
  });

  const sql = `NOTIFY pgrst, 'reload schema';`;

  try {
    await client.connect();
    console.log("Connected successfully!");
    await client.query(sql);
    console.log("Schema cache reloaded successfully!");
  } catch (err) {
    console.error("Error executing reload:", err);
    process.exit(1);
  } finally {
    await client.end();
  }
}

main();
