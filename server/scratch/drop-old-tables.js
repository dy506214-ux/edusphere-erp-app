const { Client } = require('pg');
require('dotenv').config();

async function main() {
  const client = new Client({
    connectionString: process.env.DIRECT_URL || process.env.DATABASE_URL,
  });

  try {
    await client.connect();
    console.log('Connected successfully to database.');

    console.log('Dropping old tables in public schema...');
    // Drop all old tables with CASCADE to ensure all constraints and dependencies are removed
    await client.query(`
      DROP TABLE IF EXISTS "submissions" CASCADE;
      DROP TABLE IF EXISTS "attendance" CASCADE;
      DROP TABLE IF EXISTS "profiles" CASCADE;
      DROP TABLE IF EXISTS "students" CASCADE;
      DROP TABLE IF EXISTS "teachers" CASCADE;
      DROP TABLE IF EXISTS "assignments" CASCADE;
    `);

    console.log('Successfully dropped old tables!');

    // Verify public tables now
    const tablesRes = await client.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
      ORDER BY table_name;
    `);

    console.log('\n--- Remaining Tables in public schema ---');
    if (tablesRes.rows.length === 0) {
      console.log('None! Public schema is empty.');
    } else {
      tablesRes.rows.forEach(row => {
        console.log(`- ${row.table_name}`);
      });
    }

  } catch (err) {
    console.error('Error dropping tables:', err);
  } finally {
    await client.end();
  }
}

main();
