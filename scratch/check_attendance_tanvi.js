const { Client } = require('pg');

async function main() {
  const client = new Client({ 
    connectionString: 'postgresql://postgres.bstevdkjqjzaglayicdg:akshitsha84@aws-1-ap-south-1.pooler.supabase.com:5432/postgres' 
  });
  
  try {
    await client.connect();
    console.log('Connected!');
    
    // Check attendance records for Tanvi/eduspherestudent
    const res = await client.query(`
      SELECT ar.id, ar.date, ar.status, ar."checkInTime", u."firstName", u."lastName"
      FROM "AttendanceRecord" ar
      JOIN "Student" s ON s.id = ar."studentId"
      JOIN "User" u ON u.id = s."userId"
      WHERE u.email = 'eduspherestudent@gmail.com'
      ORDER BY ar.date DESC
      LIMIT 10;
    `);
    
    console.log('Attendance records for eduspherestudent@gmail.com:', res.rows.length);
    console.log(JSON.stringify(res.rows, null, 2));
    
    // Also check subjects for their class
    const res2 = await client.query(`
      SELECT s.id, s.name, s.code, s.type
      FROM "Subject" s
      JOIN "Student" st ON st."currentClassId" = s."classId"
      JOIN "User" u ON u.id = st."userId"
      WHERE u.email = 'eduspherestudent@gmail.com'
      LIMIT 10;
    `);
    
    console.log('\nSubjects for student class:', res2.rows.length);
    console.log(JSON.stringify(res2.rows, null, 2));

    // TimetableSlot count
    const res3 = await client.query(`SELECT COUNT(*) FROM "TimetableSlot";`);
    console.log('\nTotal TimetableSlot rows:', res3.rows[0].count);
    
  } catch (err) {
    console.error('Error:', err.message);
  } finally {
    await client.end();
  }
}

main();
