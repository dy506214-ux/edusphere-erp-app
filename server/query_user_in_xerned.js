const { Client } = require('pg');

async function main() {
  const uri = 'postgresql://postgres.xernedkpgdrvjokokdoa:akshitsha84@aws-1-ap-northeast-2.pooler.supabase.com:6543/postgres';
  const client = new Client({ 
    connectionString: uri, 
    ssl: { rejectUnauthorized: false } 
  });
  try {
    await client.connect();
    const res = await client.query('SELECT * FROM "User" WHERE id = $1', ['b68e7472-d6f4-4f13-b610-b9c409f59483']);
    console.log('User in xerned:', JSON.stringify(res.rows[0], null, 2));
  } catch (err) {
    console.error(err);
  } finally {
    await client.end();
  }
}
main();
