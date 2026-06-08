const { Client } = require('pg');

async function main() {
  const client = new Client({ 
    connectionString: 'postgresql://postgres.bstevdkjqjzaglayicdg:akshitsha84@aws-1-ap-south-1.pooler.supabase.com:5432/postgres' 
  });
  
  try {
    await client.connect();
    console.log('Connected!');
    
    // Check the student's section and class
    const res = await client.query(`
      SELECT u.email, u."firstName", u."lastName", st.id as "studentId", 
             st."currentClassId", st."sectionId",
             c.name as "className", sec.name as "sectionName"
      FROM "User" u
      JOIN "Student" st ON st."userId" = u.id
      LEFT JOIN "Class" c ON c.id = st."currentClassId"
      LEFT JOIN "Section" sec ON sec.id = st."sectionId"
      WHERE u.email = 'eduspherestudent@gmail.com';
    `);
    
    console.log('Student details:', JSON.stringify(res.rows, null, 2));
    
    // Check TimetableSlots for that section
    if (res.rows.length > 0) {
      const sectionId = res.rows[0].sectionId;
      console.log('\nChecking TimetableSlots for sectionId:', sectionId);
      
      const res2 = await client.query(`
        SELECT ts.id, ts."dayOfWeek", ts."startTime", ts."endTime", ts.period,
               ts."sectionId", sub.name as "subjectName", sub.code as "subjectCode"
        FROM "TimetableSlot" ts
        LEFT JOIN "Subject" sub ON sub.id = ts."subjectId"
        WHERE ts."sectionId" = $1
        ORDER BY ts."dayOfWeek", ts.period
        LIMIT 10;
      `, [sectionId]);
      
      console.log('TimetableSlots for this student section:', res2.rows.length);
      console.log(JSON.stringify(res2.rows, null, 2));
    }
    
  } catch (err) {
    console.error('Error:', err.message);
  } finally {
    await client.end();
  }
}

main();
