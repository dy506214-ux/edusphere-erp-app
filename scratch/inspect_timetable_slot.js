const { Client } = require('pg');

async function main() {
  const dbUri = "postgresql://postgres.bstevdkjqjzaglayicdg:akshitsha84@aws-1-ap-south-1.pooler.supabase.com:5432/postgres";
  console.log("Connecting to Supabase PostgreSQL over Node.js...");
  const client = new Client({
    connectionString: dbUri,
  });

  try {
    await client.connect();
    console.log("Connected successfully!");

    // Inspect columns of TimetableSlot
    const res = await client.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'TimetableSlot';
    `);
    
    console.log("Columns in TimetableSlot:");
    res.rows.forEach(row => {
      console.log(`  ${row.column_name}: ${row.data_type}`);
    });

    // Inspect columns of Subject
    const res2 = await client.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'Subject';
    `);
    
    console.log("\nColumns in Subject:");
    res2.rows.forEach(row => {
      console.log(`  ${row.column_name}: ${row.data_type}`);
    });

    // Let's also query some rows from TimetableSlot if there are any
    const res3 = await client.query(`
      SELECT * FROM "TimetableSlot" LIMIT 5;
    `);
    console.log(`\nTimetableSlot rows: ${res3.rows.length}`);
    if (res3.rows.length > 0) {
      console.log("Sample rows:", res3.rows);
    }
  } catch (err) {
    console.error("Error executing SQL:", err);
  } finally {
    await client.end();
  }
}

main();
