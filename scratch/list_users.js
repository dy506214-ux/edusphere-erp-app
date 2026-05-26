const { Client } = require('pg');

async function main() {
  const dbUri = "postgresql://postgres.xernedkpgdrvjokokdoa:akshitsha84@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres";
  const client = new Client({ connectionString: dbUri });

  try {
    await client.connect();
    
    const students = await client.query("SELECT id, name, email FROM public.students WHERE email LIKE '%alex%' OR email LIKE '%rivera%'");
    const teachers = await client.query("SELECT id, name, email FROM public.teachers WHERE email LIKE '%harrison%'");

    console.log("--- STUDENTS resolved ---");
    console.log(students.rows);

    console.log("--- TEACHERS resolved ---");
    console.log(teachers.rows);

  } catch (err) {
    console.error("Error:", err);
  } finally {
    await client.end();
  }
}

main();
