const { Client } = require('pg');

async function main() {
  const uri = 'postgresql://postgres:akshitsha84@db.uodmjwjnhinbbvexbyvd.supabase.co:5432/postgres';
  console.log('Connecting directly to production database:', uri);
  const client = new Client({ 
    connectionString: uri, 
    ssl: { rejectUnauthorized: false } 
  });
  try {
    await client.connect();
    console.log('Connected directly to production database successfully!');
    const res = await client.query('SELECT COUNT(*) FROM "User"');
    console.log('User count:', res.rows[0].count);
    
    const res2 = await client.query('SELECT * FROM "AttendanceSlot" WHERE id = $1', ['8c0df2d0-1da3-47d1-8c14-f00dbe2c09f4']);
    console.log('Slot 8c0df2d0-1da3-47d1-8c14-f00dbe2c09f4:', JSON.stringify(res2.rows[0], null, 2));
  } catch (err) {
    console.error('Error:', err);
  } finally {
    await client.end();
  }
}
main();
