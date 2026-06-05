const { PrismaClient } = require('@prisma/client');
const { randomUUID } = require('crypto');

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Seeding historical attendance data for May 2026...');

  // 1. Fetch all students
  const students = await prisma.student.findMany({
    select: { id: true }
  });

  if (students.length === 0) {
    console.error('❌ No students found in the database. Please seed students first.');
    return;
  }

  console.log(`Found ${students.length} students. Generating attendance records...`);

  // 2. Identify school days in May 2026 (excluding Saturdays and Sundays)
  const schoolDays = [];
  const year = 2026;
  const month = 4; // May (0-indexed)

  for (let day = 1; day <= 31; day++) {
    const date = new Date(year, month, day);
    const dayOfWeek = date.getDay();
    // 0 = Sunday, 6 = Saturday
    if (dayOfWeek !== 0 && dayOfWeek !== 6) {
      schoolDays.push(new Date(year, month, day));
    }
  }

  console.log(`Generated ${schoolDays.length} school days in May 2026.`);

  // 3. Generate attendance records
  const attendanceRecords = [];

  for (const student of students) {
    for (const date of schoolDays) {
      const rand = Math.random();
      let status = 'PRESENT';
      if (rand > 0.90) {
        status = 'ABSENT';
      } else if (rand > 0.85) {
        status = 'LATE';
      }

      // Format date correctly for Postgres date type
      const dateStr = date.toISOString().split('T')[0];

      attendanceRecords.push({
        id: randomUUID(),
        attendeeType: 'STUDENT',
        studentId: student.id,
        date: new Date(dateStr),
        status: status,
        createdAt: new Date(),
        updatedAt: new Date()
      });
    }
  }

  // 4. Bulk insert in chunks of 2000 to prevent database memory issues
  console.log(`Inserting ${attendanceRecords.length} attendance records in chunks...`);
  const chunkSize = 2000;
  for (let i = 0; i < attendanceRecords.length; i += chunkSize) {
    const chunk = attendanceRecords.slice(i, i + chunkSize);
    await prisma.attendanceRecord.createMany({
      data: chunk
    });
    console.log(`   - Seeded chunk ${Math.floor(i / chunkSize) + 1}/${Math.ceil(attendanceRecords.length / chunkSize)}`);
  }

  console.log('🎉 Historical attendance seeding completed successfully!');
}

main().catch(console.error).finally(() => prisma.$disconnect());
