const { Client } = require('pg');

async function main() {
  const dbUri = "postgresql://postgres.xernedkpgdrvjokokdoa:akshitsha84@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres";
  const client = new Client({ connectionString: dbUri });

  try {
    await client.connect();
    
    const res = await client.query("SELECT id, email, raw_user_meta_data FROM auth.users WHERE email IN ('alex.rivera@edusmart.edu', 'prof.harrison@edusmart.edu')");
    console.log("--- AUTH USERS ---");
    console.log(res.rows);

  } catch (err) {
    console.error("Error:", err);
  } finally {
    await client.end();
  }
}

main();
