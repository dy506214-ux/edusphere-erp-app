const { Client } = require('pg');

async function main() {
  const uri = 'postgresql://postgres.xernedkpgdrvjokokdoa:akshitsha84@aws-0-ap-southeast-1.pooler.supabase.com:6543/postgres';
  console.log('Connecting to other db:', uri);
  const client = new Client({ 
    connectionString: uri,
    ssl: { rejectUnauthorized: false }
  });
  try {
    await client.connect();
    console.log('Connected successfully!');
    const res = await client.query('SELECT * FROM "AttendanceSlot" WHERE id = $1', ['8c0df2d0-1da3-47d1-8c14-f00dbe2c09f4']);
    console.log('Slot:', JSON.stringify(res.rows[0], null, 2));
    
    if (res.rows[0]) {
      const res2 = await client.query('SELECT count(*) FROM "AttendanceRecord" WHERE "slotId" = $1', ['8c0df2d0-1da3-47d1-8c14-f00dbe2c09f4']);
      console.log('Records count:', res2.rows[0]);
    }
  } catch (err) {
    console.error('Connection failed:', err);
  } finally {
    await client.end();
  }
}

main();
