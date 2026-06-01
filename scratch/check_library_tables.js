const { Client } = require('pg');

async function main() {
  const dbUri = "postgresql://postgres.xernedkpgdrvjokokdoa:akshitsha84@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres";
  const client = new Client({ connectionString: dbUri });

  try {
    await client.connect();
    console.log("Connected to Supabase PostgreSQL.");

    const tables = ['fee_payments', 'students', 'teachers', 'assignments'];

    for (const table of tables) {
      console.log(`\n--- SCHEMA & DATA FOR TABLE: ${table} ---`);
      
      const columnsRes = await client.query(`
        SELECT column_name, data_type, is_nullable 
        FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = $1
      `, [table]);
      
      if (columnsRes.rows.length === 0) {
        console.log(`Table "${table}" does not exist in the public schema!`);
        continue;
      }
      
      console.log("Columns:");
      columnsRes.rows.forEach(col => {
        console.log(`  - ${col.column_name} (${col.data_type}, nullable: ${col.is_nullable})`);
      });

      // Get count and first few rows
      const countRes = await client.query(`SELECT COUNT(*) FROM public."${table}"`);
      console.log(`Total rows: ${countRes.rows[0].count}`);

      const rowsRes = await client.query(`SELECT * FROM public."${table}" LIMIT 1`);
      console.log("Sample Row:");
      console.log(rowsRes.rows);
    }

  } catch (err) {
    console.error("Error inspecting database:", err);
  } finally {
    await client.end();
  }
}

main();
