const { Client } = require('pg');

async function main() {
  const client = new Client({ 
    connectionString: 'postgresql://postgres.bstevdkjqjzaglayicdg:akshitsha84@aws-1-ap-south-1.pooler.supabase.com:5432/postgres' 
  });
  
  try {
    await client.connect();
    
    // Get Teacher IDs (from Teacher table, not User)
    const res = await client.query(`
      SELECT t.id as "teacherId", u."firstName", u."lastName"
      FROM "Teacher" t
      JOIN "User" u ON u.id = t."userId"
      LIMIT 5;
    `);
    console.log('Teachers:', JSON.stringify(res.rows, null, 2));
    
    // Also check what the existing TimetableSlot teacherId references
    const res2 = await client.query(`
      SELECT ts."teacherId", ts."subjectId", ts."sectionId"
      FROM "TimetableSlot" ts
      LIMIT 3;
    `);
    console.log('\nExisting TimetableSlot teacher refs:', JSON.stringify(res2.rows, null, 2));
    
  } catch (err) {
    console.error('Error:', err.message);
  } finally {
    await client.end();
  }
}

main();
