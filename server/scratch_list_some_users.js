const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  try {
    const userCount = await prisma.user.count();
    const studentCount = await prisma.student.count();
    const teacherCount = await prisma.teacher.count();
    const classCount = await prisma.class.count();
    console.log(`Counts - Users: ${userCount}, Students: ${studentCount}, Teachers: ${teacherCount}, Classes: ${classCount}`);

    const sampleUsers = await prisma.user.findMany({
      take: 10,
      select: { email: true, firstName: true, lastName: true, role: true }
    });
    console.log('Sample Users:', JSON.stringify(sampleUsers, null, 2));

  } catch (error) {
    console.error('Error querying database:', error);
  } finally {
    await prisma.$disconnect();
  }
}

main();

