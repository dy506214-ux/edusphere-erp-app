const { Client } = require('pg');
const dns = require('dns');
dns.setDefaultResultOrder('ipv4first');

async function main() {
  console.log("Testing connection via Node.js with pooler...");
  const client = new Client({
    user: 'postgres.xernedkpgdrvjokokdoa',
    password: 'akshitsha84',
    host: 'aws-0-ap-northeast-2.pooler.supabase.com',
    port: 6543,
    database: 'postgres',
    ssl: { rejectUnauthorized: false }
  });

  try {
    await client.connect();
    console.log("🎉 SUCCESS! Connected successfully via Node.js pooler!");
    const res = await client.query("SELECT COUNT(*) FROM public.students;");
    console.log("Student count:", res.rows[0].count);
  } catch (err) {
    console.error("Connection failed:", err.message);
  } finally {
    await client.end();
  }
}

main();
