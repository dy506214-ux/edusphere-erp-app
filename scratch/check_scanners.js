const { Client } = require('pg');

async function main() {
  const dbUri = "postgresql://postgres.xernedkpgdrvjokokdoa:akshitsha84@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres";
  const client = new Client({ connectionString: dbUri });

  try {
    await client.connect();
    console.log("Connected to Supabase PostgreSQL.");

    const tablesRes = await client.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public' AND (table_name ILIKE '%scanner%' OR table_name ILIKE '%attendance%')
    `);
    console.log("Matching tables:", tablesRes.rows);

    for (const row of tablesRes.rows) {
      const table = row.table_name;
      console.log(`\n--- SCHEMA & DATA FOR TABLE: ${table} ---`);
      
      const columnsRes = await client.query(`
        SELECT column_name, data_type, is_nullable 
        FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = $1
      `, [table]);
      
      console.log("Columns:");
      columnsRes.rows.forEach(col => {
        console.log(`  - ${col.column_name} (${col.data_type}, nullable: ${col.is_nullable})`);
      });

      // Get count
      const countRes = await client.query(`SELECT COUNT(*) FROM public."${table}"`);
      console.log(`Total rows: ${countRes.rows[0].count}`);

      // Sample rows
      const rowsRes = await client.query(`SELECT * FROM public."${table}" LIMIT 2`);
      console.log("Sample Rows:");
      console.log(JSON.stringify(rowsRes.rows, null, 2));
    }

  } catch (err) {
    console.error("Error inspecting database:", err);
  } finally {
    await client.end();
  }
}

main();
