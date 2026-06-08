const { Client } = require('pg');

async function main() {
  const client = new Client({ 
    connectionString: 'postgresql://postgres.bstevdkjqjzaglayicdg:akshitsha84@aws-1-ap-south-1.pooler.supabase.com:5432/postgres' 
  });
  
  try {
    await client.connect();
    
    // Check SchoolCalendar table structure and data
    const res = await client.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'SchoolCalendar'
      ORDER BY ordinal_position;
    `);
    console.log('SchoolCalendar columns:', res.rows);
    
    const res2 = await client.query(`SELECT * FROM "SchoolCalendar" ORDER BY date ASC LIMIT 20;`);
    console.log('\nSchoolCalendar rows:', res2.rows.length);
    console.log(JSON.stringify(res2.rows, null, 2));
    
  } catch (err) {
    console.error('Error:', err.message);
  } finally {
    await client.end();
  }
}

main();
