const { Client } = require('pg');
require('dotenv').config();

async function main() {
  const client = new Client({
    connectionString: process.env.DIRECT_URL || process.env.DATABASE_URL,
  });

  try {
    await client.connect();
    console.log('Connected successfully to database.');

    // Query constraints using pg_constraint
    const res = await client.query(`
      SELECT 
        conname AS constraint_name,
        conrelid::regclass AS table_name,
        confrelid::regclass AS foreign_table_name,
        pg_get_constraintdef(oid) AS constraint_def
      FROM 
        pg_constraint
      WHERE 
        conrelid::regclass::text IN ('assignments', 'attendance', 'profiles', 'students', 'submissions', 'teachers')
        OR confrelid::regclass::text IN ('assignments', 'attendance', 'profiles', 'students', 'submissions', 'teachers');
    `);

    console.log('\n--- Constraints ---');
    res.rows.forEach(row => {
      console.log(`Table: ${row.table_name}`);
      console.log(`Constraint Name: ${row.constraint_name}`);
      console.log(`Foreign Table: ${row.foreign_table_name}`);
      console.log(`Definition: ${row.constraint_def}`);
      console.log('-----------------------------------');
    });

  } catch (err) {
    console.error('Error querying database:', err);
  } finally {
    await client.end();
  }
}

main();
