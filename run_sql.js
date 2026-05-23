const { Client } = require('pg');
const fs = require('fs');

async function main() {
  const dbUri = "postgresql://postgres:akshitsha84@db.xernedkpgdrvjokokdoa.supabase.co:5432/postgres";
  console.log("Connecting to Supabase PostgreSQL over Node.js...");
  const client = new Client({
    connectionString: dbUri,
  });

  try {
    await client.connect();
    console.log("Connected successfully!");

    console.log("Reading full_schema_setup.sql...");
    const sqlContent = fs.readFileSync('full_schema_setup.sql', 'utf8');

    console.log("Executing SQL migrations (this will take 5-10 seconds)...");
    await client.query(sqlContent);
    console.log("🎉 SQL executed successfully and database fully seeded!");
  } catch (err) {
    console.error("Error executing SQL:", err);
    process.exit(1);
  } finally {
    await client.end();
  }
}

main();
