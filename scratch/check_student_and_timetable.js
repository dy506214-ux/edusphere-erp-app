const { Client } = require('pg');

async function main() {
  const dbUri = "postgresql://postgres.bstevdkjqjzaglayicdg:akshitsha84@aws-1-ap-south-1.pooler.supabase.com:5432/postgres";
  const client = new Client({
    connectionString: dbUri,
  });

  try {
    await client.connect();

    // Find a student who has an ABSENT record on 2026-05-01 (or 2026-04-30T18:30:00.000Z in UTC/ISO)
    // and a PRESENT record on 2026-05-08 (or 2026-05-07T18:30:00.000Z in UTC/ISO)
    const res = await client.query(`
      SELECT ar."studentId", u.email, u."firstName", u."lastName"
      FROM "AttendanceRecord" ar
      JOIN "Student" s ON s.id = ar."studentId"
      JOIN "User" u ON u.id = s."userId"
      WHERE ar.date IN ('2026-05-01', '2026-04-30T18:30:00.000Z') AND ar.status = 'ABSENT'
      INTERSECT
      SELECT ar."studentId", u.email, u."firstName", u."lastName"
      FROM "AttendanceRecord" ar
      JOIN "Student" s ON s.id = ar."studentId"
      JOIN "User" u ON u.id = s."userId"
      WHERE ar.date IN ('2026-05-08', '2026-05-07T18:30:00.000Z') AND ar.status = 'PRESENT';
    `);
    console.log("Matching students:", res.rows);

  } catch (err) {
    console.error("Error:", err);
  } finally {
    await client.end();
  }
}

main();
