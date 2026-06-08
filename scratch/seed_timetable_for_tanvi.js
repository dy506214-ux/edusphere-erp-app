const { Client } = require('pg');

async function main() {
  const dbUri = "postgresql://postgres.bstevdkjqjzaglayicdg:akshitsha84@aws-1-ap-south-1.pooler.supabase.com:5432/postgres";
  const client = new Client({
    connectionString: dbUri,
  });

  try {
    await client.connect();
    console.log("Connected!");

    const classId = '4a09a0ce-8de5-4a0a-85cb-e2602cbf1d1f';
    const sectionId = 'e17f3db1-ba3e-4bdd-9f5a-04bc8fbfaf7d';

    // 1. Delete existing Timetable and TimetableSlot entries for this class/section if any
    await client.query('DELETE FROM "TimetableSlot" WHERE "sectionId" = $1;', [sectionId]);
    await client.query('DELETE FROM "Timetable" WHERE "classId" = $1;', [classId]);

    // 2. Insert Timetable
    const timetableId = 'tanvi-timetable-uuid';
    await client.query(`
      INSERT INTO "Timetable" (id, name, type, "classId", "effectiveFrom", "isActive", "createdAt", "updatedAt")
      VALUES ($1, $2, $3, $4, NOW(), true, NOW(), NOW());
    `, [timetableId, 'Tanvi Class 3 Timetable', 'DAILY', classId]);
    console.log("Created Timetable record.");

    // Subjects and Teachers maps
    const subjects = [
      { id: '8d86d078-f12c-4729-9aef-f3def7bb8aea', name: 'Mathematics', code: 'MAT3' },
      { id: '8f702d15-9ae2-407f-aded-291cb7248f93', name: 'English', code: 'ENG3' },
      { id: '4c25e389-9266-4d58-b5da-a4e97500abfd', name: 'Science', code: 'SCI3' },
      { id: '482d4981-5516-461a-ad91-d3eb6319bed1', name: 'Hindi', code: 'HIN3' },
      { id: '12a199b9-1903-4682-91f2-a6d6360f3bba', name: 'Social Science', code: 'SOC3' }
    ];

    const teachers = [
      'f53ca3cf-ff5b-40c5-837e-88d1ef45fa74', // Test Teacher
      '74c8220a-d062-454f-890b-373a449fa82b', // Priya Joshi
      'c29f1673-fde8-4bd8-ace7-9bf66389e775', // Aanya Verma
      'c6c46c7e-a091-4257-b74f-c1a9679bc30f', // Vijay Wilson
      'a950435f-2b6d-438e-bb60-cbaa83a74a37'  // Dev Thomas
    ];

    // Seed Slots for Days 1 to 6 (Monday to Saturday)
    const timeSlots = [
      { period: 1, start: '08:30 AM', end: '09:30 AM' },
      { period: 2, start: '09:45 AM', end: '10:45 AM' },
      { period: 3, start: '11:00 AM', end: '12:00 PM' },
      { period: 4, start: '01:00 PM', end: '02:00 PM' }
    ];

    // Monday to Friday: 4 periods each. Saturday: 2 periods.
    let count = 0;
    for (let day = 1; day <= 6; day++) {
      const periodsForDay = day === 6 ? 2 : 4;
      for (let pIdx = 0; pIdx < periodsForDay; pIdx++) {
        const slot = timeSlots[pIdx];
        
        // Pick subject and teacher deterministically based on day and period index
        const subIdx = (day + pIdx) % subjects.length;
        const teachIdx = (day + pIdx) % teachers.length;
        
        const subject = subjects[subIdx];
        const teacherId = teachers[teachIdx];

        await client.query(`
          INSERT INTO "TimetableSlot" (
            id, "timetableId", "dayOfWeek", "startTime", "endTime", period, "sectionId", "subjectId", "teacherId", "durationMinutes", "isSpecialSlot", "roomId"
          ) VALUES (
            gen_random_uuid(), $1, $2, $3, $4, $5, $6, $7, $8, 60, false, null
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

    console.log(`Successfully seeded ${count} TimetableSlot records!`);

  } catch (err) {
    console.error("Error:", err);
  } finally {
    await client.end();
  }
}

main();
