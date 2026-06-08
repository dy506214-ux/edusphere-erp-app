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
    
    // Subjects for Class 1
    const subjects = [
      { id: 'd7acd731-aeab-4b14-8154-277d54066f60', name: 'Mathematics', code: 'MAT1' },
      { id: '71e2ca07-fd3b-429c-9874-cc1d79d98c86', name: 'English', code: 'ENG1' },
      { id: '25e34e45-534e-470a-a9f4-0a552cb89de7', name: 'Science', code: 'SCI1' },
      { id: '75286ad4-b904-4b5d-a507-f2925b7cc721', name: 'Hindi', code: 'HIN1' },
      { id: '053890cd-2082-42d1-98ae-a756237ab603', name: 'Social Science', code: 'SOC1' },
    ];
    
    // Teachers (Teacher table IDs, not User IDs)
    const teachers = [
      'f53ca3cf-ff5b-40c5-837e-88d1ef45fa74', // Test Teacher
      '74c8220a-d062-454f-890b-373a449fa82b', // Priya Joshi
      'c29f1673-fde8-4bd8-ace7-9bf66389e775', // Aanya Verma
      'c6c46c7e-a091-4257-b74f-c1a9679bc30f', // Vijay Wilson
      'a950435f-2b6d-438e-bb60-cbaa83a74a37'  // Dev Thomas
    ];
    
    // 1. Delete existing slots for this section (if any)
    await client.query('DELETE FROM "TimetableSlot" WHERE "sectionId" = $1;', [sectionId]);
    
    // 2. Delete existing timetable for this class (if any)
    await client.query('DELETE FROM "Timetable" WHERE "classId" = $1;', [classId]);
    
    // 3. Create Timetable
    const timetableId = 'class1-section-a-timetable-uuid';
    await client.query(`
      INSERT INTO "Timetable" (id, name, type, "classId", "effectiveFrom", "isActive", "createdAt", "updatedAt")
      VALUES ($1, $2, $3, $4, NOW(), true, NOW(), NOW());
    `, [timetableId, 'Class 1 Section A Timetable', 'DAILY', classId]);
    console.log('Created Timetable record for Class 1.');
    
    // Time slots per period
    const timeSlots = [
      { period: 1, start: '08:30 AM', end: '09:30 AM' },
      { period: 2, start: '09:45 AM', end: '10:45 AM' },
      { period: 3, start: '11:00 AM', end: '12:00 PM' },
      { period: 4, start: '01:00 PM', end: '02:00 PM' }
    ];
    
    // Monday to Friday: 4 periods. Saturday: 2 periods.
    let count = 0;
    for (let day = 1; day <= 6; day++) {
      const periodsForDay = day === 6 ? 2 : 4;
      for (let pIdx = 0; pIdx < periodsForDay; pIdx++) {
        const slot = timeSlots[pIdx];
        
        // Pick subject and teacher based on day and period
        const subIdx = (day + pIdx) % subjects.length;
        const teachIdx = (day + pIdx) % teachers.length;
        
        const subject = subjects[subIdx];
        const teacherId = teachers[teachIdx];
        
        await client.query(`
          INSERT INTO "TimetableSlot" (
            id, "timetableId", "dayOfWeek", "startTime", "endTime", period, 
            "sectionId", "subjectId", "teacherId", "durationMinutes", "isSpecialSlot"
          ) VALUES (
            gen_random_uuid(), $1, $2, $3, $4, $5, $6, $7, $8, 60, false
          );
        `, [
          timetableId,
          day,
          slot.start,
          slot.end,
          slot.period,
          sectionId,
          subject.id,
          teacherId
        ]);
        count++;
      }
    }
    
    console.log(`Successfully seeded ${count} TimetableSlot records for Class 1 Section A!`);
    
    // Verify
    const verRes = await client.query(`
      SELECT ts."dayOfWeek", ts."startTime", ts."endTime", sub.name as subject
      FROM "TimetableSlot" ts
      JOIN "Subject" sub ON sub.id = ts."subjectId"
      WHERE ts."sectionId" = $1
      ORDER BY ts."dayOfWeek", ts.period;
    `, [sectionId]);
    
    console.log('\nVerification - Seeded slots:');
    verRes.rows.forEach(row => {
      const days = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
      console.log(`  ${days[row.dayOfWeek]} ${row.startTime} - ${row.subject}`);
    });
    
  } catch (err) {
    console.error('Error:', err.message);
    console.error(err.stack);
  } finally {
    await client.end();
  }
}

main();
