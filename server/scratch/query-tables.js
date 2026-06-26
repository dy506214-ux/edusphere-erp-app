const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  try {
    const resultsCount = await prisma.examResult?.count().catch(e => e.message);
    const marksCount = await prisma.examMark?.count().catch(e => e.message);
    const reportCardCount = await prisma.reportCard?.count().catch(e => e.message);
    const studentCount = await prisma.student?.count().catch(e => e.message);

    console.log({
      resultsCount,
      marksCount,
      reportCardCount,
      studentCount
    });

    if (studentCount > 0) {
      const students = await prisma.student.findMany({
        take: 3,
        include: {
          user: {
            select: { firstName: true, lastName: true, email: true }
          }
        }
      });
      console.log('Sample students:', JSON.stringify(students, null, 2));
    }
  } catch (err) {
    console.error(err);
  } finally {
    await prisma.$disconnect();
  }
}

main();
