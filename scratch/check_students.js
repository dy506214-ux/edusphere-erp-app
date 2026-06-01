const { Client } = require('pg');

async function main() {
  const dbUri = "postgresql://postgres.xernedkpgdrvjokokdoa:akshitsha84@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres";
  const client = new Client({ connectionString: dbUri });

  try {
    await client.connect();
    console.log("Connected to Supabase PostgreSQL.");

    const tables = ['Student', 'Teacher', 'Staff', 'User', 'AttendanceRecord'];

    for (const table of tables) {
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
    }

  } catch (err) {
    console.error("Error inspecting database:", err);
  } finally {
    await client.end();
  }
}

main();
