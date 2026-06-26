const { Client } = require('pg');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

async function main() {
  const client = new Client({
    connectionString: process.env.DIRECT_URL || process.env.DATABASE_URL,
  });

  try {
    await client.connect();
    console.log('Connected to database.');

    // Disable RLS on public.results so anyone with the anon key can query it
    console.log('Disabling RLS on public.results...');
    await client.query(`ALTER TABLE public.results DISABLE ROW LEVEL SECURITY;`);
    console.log('RLS disabled successfully.');

  } catch (err) {
    console.error('Error:', err);
  } finally {
    await client.end();
  }
}

main();
