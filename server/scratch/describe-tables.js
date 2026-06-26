const { Client } = require('pg');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

async function main() {
  const client = new Client({
    connectionString: process.env.DIRECT_URL || process.env.DATABASE_URL,
  });

  try {
    await client.connect();
    console.log('Connected to DB.');

    // Print columns of lowercase students table
    let res = await client.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'students'
      ORDER BY ordinal_position;
    `);
    console.log('\nColumns of students table:');
    console.log(res.rows);

    // Fetch one row from students
    res = await client.query(`SELECT * FROM students LIMIT 1;`);
    console.log('\nSample student row:');
    console.log(res.rows[0]);

  } catch (err) {
    console.error(err);
  } finally {
    await client.end();
  }
}

main();
