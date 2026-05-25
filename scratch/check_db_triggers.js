const { Client } = require('pg');

async function main() {
  const dbUri = "postgresql://postgres.xernedkpgdrvjokokdoa:akshitsha84@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres";
  const client = new Client({ connectionString: dbUri });

  try {
    await client.connect();
    console.log("Connected to Supabase PostgreSQL.");

    // Query 1: List all triggers in the database
    const triggersRes = await client.query(`
      SELECT 
        trigger_name, 
        event_manipulation, 
        event_object_table, 
        action_statement, 
        action_orientation, 
        action_timing
      FROM information_schema.triggers;
    `);
    console.log("\n--- TRIGGERS ---");
    console.log(triggersRes.rows);

    // Query 2: List all custom functions in the public schema
    const functionsRes = await client.query(`
      SELECT 
        routine_name, 
        routine_type, 
        data_type
      FROM information_schema.routines
      WHERE routine_schema = 'public';
    `);
    console.log("\n--- PUBLIC ROUTINES/FUNCTIONS ---");
    console.log(functionsRes.rows);

    // Query 3: Check if there's any trigger or function related to 'messages' table specifically
    const msgTriggersRes = await client.query(`
      SELECT tgname, relname, tgtype
      FROM pg_trigger t
      JOIN pg_class c ON t.tgrelid = c.oid
      WHERE c.relname = 'messages';
    `);
    console.log("\n--- MESSAGES TABLE TRIGGERS (pg_trigger) ---");
    console.log(msgTriggersRes.rows);

  } catch (err) {
    console.error("Error inspecting database:", err);
  } finally {
    await client.end();
  }
}

main();
