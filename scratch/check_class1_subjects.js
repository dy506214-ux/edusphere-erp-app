const { Client } = require('pg');

async function main() {
  const client = new Client({ 
    connectionString: 'postgresql://postgres.bstevdkjqjzaglayicdg:akshitsha84@aws-1-ap-south-1.pooler.supabase.com:5432/postgres' 
  });
  
  try {
    await client.connect();
    console.log('Connected!');
    
    // Test Student is in Class 1 (325bf881-dfa6-46c2-9369-0bb726d2c6ca), Section A (ff388d3a-1db4-44c8-8e9c-929a805b03a3)
    const classId = '325bf881-dfa6-46c2-9369-0bb726d2c6ca';
    const sectionId = 'ff388d3a-1db4-44c8-8e9c-929a805b03a3';
    
    // First, check existing subjects for Class 1
    const subRes = await client.query(`SELECT id, name, code FROM "Subject" WHERE "classId" = $1;`, [classId]);
    console.log('Subjects for Class 1:', JSON.stringify(subRes.rows, null, 2));
    
    // Check if timetable exists for Class 1
    const ttRes = await client.query(`SELECT id, name FROM "Timetable" WHERE "classId" = $1;`, [classId]);
    console.log('Timetables for Class 1:', JSON.stringify(ttRes.rows, null, 2));
    
    // Get some teacher IDs
    const teacherRes = await client.query(`SELECT id, "firstName", "lastName" FROM "User" WHERE role = 'TEACHER' LIMIT 5;`);
    console.log('Teachers:', JSON.stringify(teacherRes.rows, null, 2));
    
  } catch (err) {
    console.error('Error:', err.message);
  } finally {
    await client.end();
  }
}

main();
