const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  try {
    const students = await prisma.studentProfile.findMany({
      where: {
        user: {
          firstName: { contains: 'Harish', mode: 'insensitive' }
        }
      },
      include: {
        user: true,
        academicYear: true,
        currentClass: true,
      }
    });
    console.log('=== Harish Students in DB ===');
    console.log(JSON.stringify(students, null, 2));
  } catch (error) {
    console.error('Error:', error);
  } finally {
    await prisma.$disconnect();
  }
}

main();
