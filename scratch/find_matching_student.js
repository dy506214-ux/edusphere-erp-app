const { Client } = require('pg');

async function main() {
  const dbUri = "postgresql://postgres.bstevdkjqjzaglayicdg:akshitsha84@aws-1-ap-south-1.pooler.supabase.com:5432/postgres";
  const client = new Client({
    connectionString: dbUri,
  });

  try {
    await client.connect();
    console.log("Connected!");

    // Search for a student with these exact records:
    // 2026-04-30: PRESENT
    // 2026-05-01: ABSENT
    // 2026-05-04: PRESENT
    // 2026-05-05: PRESENT
    // 2026-05-06: PRESENT
    // 2026-05-07: PRESENT
    // 2026-05-08: PRESENT
    // (Note: dates might be shifted by timezone, so we match both raw date and date-1day / date+1day)
    
    const studentsRes = await client.query(`
      SELECT s.id, u.email, u."firstName", u."lastName"
      FROM "Student" s
      JOIN "User" u ON u.id = s."userId"
      LIMIT 1000;
    `);

    console.log(`Total students to check: ${studentsRes.rows.length}`);

    const matches = [];
    for (const student of studentsRes.rows) {
      const recordsRes = await client.query(`
        SELECT date, status FROM "AttendanceRecord" WHERE "studentId" = $1;
      `, [student.id]);
      
      const records = recordsRes.rows.map(r => {
        // Format date to local YYYY-MM-DD or simple ISO date
        const d = new Date(r.date);
        // Correct timezone offset to get local date string
        const offset = d.getTimezoneOffset();
        const localDateStr = new Date(d.getTime() - (offset * 60 * 1000)).toISOString().split('T')[0];
        return { date: localDateStr, status: r.status };
      });

      // Check if this student matches:
      // - 2026-04-30 PRESENT
      // - 2026-05-01 ABSENT
      // - 2026-05-04 PRESENT
      // - 2026-05-05 PRESENT
      // - 2026-05-06 PRESENT
      // - 2026-05-07 PRESENT
      // - 2026-05-08 PRESENT
      const has = (dateStr, statusStr) => {
        return records.some(r => r.date === dateStr && r.status === statusStr);
      };

      if (
        has('2026-04-30', 'PRESENT') &&
        has('2026-05-01', 'ABSENT') &&
        has('2026-05-04', 'PRESENT') &&
        has('2026-05-05', 'PRESENT') &&
        has('2026-05-06', 'PRESENT') &&
        has('2026-05-07', 'PRESENT') &&
        has('2026-05-08', 'PRESENT')
      ) {
        matches.push({ student, recordsCount: records.length });
      }
    }

    console.log("Matching students:", matches);

  } catch (err) {
    console.error("Error:", err);
  } finally {
    await client.end();
  }
}

main();
