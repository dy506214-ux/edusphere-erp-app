const { Client } = require('pg');

async function main() {
  const dbUri = "postgresql://postgres.xernedkpgdrvjokokdoa:akshitsha84@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres";
  const client = new Client({ connectionString: dbUri });

  try {
    await client.connect();
    console.log("Connected to Supabase PostgreSQL.");

    const res = await client.query(`
      SELECT * FROM public.messages 
      WHERE (sender_id = 'a1e3b5c7-1234-5678-abcd-ef1234567890' AND recipient_id = 'b2f4c6d8-2345-6789-bcde-f23456789012')
         OR (sender_id = 'b2f4c6d8-2345-6789-bcde-f23456789012' AND recipient_id = 'a1e3b5c7-1234-5678-abcd-ef1234567890')
      ORDER BY created_at ASC
    `);
    console.log("\n--- ALL MESSAGES BETWEEN ALEX AND HARRISON ---");
    console.log(res.rows);

  } catch (err) {
    console.error("Error querying messages:", err);
  } finally {
    await client.end();
  }
}

main();
