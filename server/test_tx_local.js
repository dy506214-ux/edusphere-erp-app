const { PrismaClient } = require('@prisma/client');

async function main() {
  const prisma = new PrismaClient();
  const dateVal = new Date('2026-07-01T00:00:00.000Z');

  try {
    // 1. Clean up first
    await prisma.attendanceRecord.deleteMany({});
    await prisma.attendanceSlot.deleteMany({});
    
    // Get a valid student and teacher
    const student = await prisma.studentProfile.findFirst();
    const teacher = await prisma.teacher.findFirst();
    const classObj = await prisma.class.findFirst();
    const sectionObj = await prisma.section.findFirst();

    if (!student || !teacher || !classObj || !sectionObj) {
      console.log('Ensure you have seeded the database with students, classes and teachers.');
      return;
    }

    console.log('Creating dummy slot...');
    const slot = await prisma.attendanceSlot.create({
      data: {
        date: dateVal,
        attendeeType: 'STUDENT',
        classId: classObj.id,
        sectionId: sectionObj.id,
        createdBy: teacher.userId,
        status: 'OPEN'
      }
    });

    console.log('Creating dummy existing attendance record...');
    await prisma.attendanceRecord.create({
      data: {
        attendeeType: 'STUDENT',
        studentId: student.id,
        date: dateVal,
        status: 'PRESENT',
        markedBy: teacher.userId
      }
    });

    console.log('Simulating submit transaction...');
    await prisma.$transaction(async (tx) => {
      // Delete existing records
      const delCount = await tx.attendanceRecord.deleteMany({
        where: {
          date: slot.date,
          attendeeType: slot.attendeeType,
          studentId: { in: [student.id] }
        }
      });
      console.log('Deleted records count:', delCount.count);

      // Create new records
      const createCount = await tx.attendanceRecord.createMany({
        data: [
          {
            attendeeType: slot.attendeeType,
            studentId: student.id,
            date: slot.date,
            status: 'ABSENT',
            slotId: slot.id,
            markedBy: teacher.userId
          }
        ]
      });
      console.log('Created records count:', createCount.count);
    });

    console.log('Success! No unique constraint error.');
  } catch (err) {
    console.error('Transaction failed:', err);
  } finally {
    await prisma.$disconnect();
  }
}
main();
