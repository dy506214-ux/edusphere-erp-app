const { Client } = require('pg');

async function main() {
  const dbUri = "postgresql://postgres.xernedkpgdrvjokokdoa:akshitsha84@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres";
  const client = new Client({ connectionString: dbUri });

  const sql = `
    SELECT column_name, data_type, is_nullable, column_default 
    FROM information_schema.columns 
    WHERE table_name = 'ServiceRequest' AND table_schema = 'public';
  `;

  try {
    await client.connect();
    const res = await client.query(sql);
    console.log("Columns:", res.rows);
  } catch (err) {
    console.error("Error:", err);
  } finally {
    await client.end();
  }
}

main();
