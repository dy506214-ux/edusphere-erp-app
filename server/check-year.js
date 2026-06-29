const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  try {
    const yearId = '3b6fa212-5ef4-4db9-a3fa-3f12c4a61573';
    const year = await prisma.academicYear.findUnique({
      where: { id: yearId }
    });
    console.log('=== Academic Year for ID 3b6fa ===');
    console.log(JSON.stringify(year, null, 2));

    const student = await prisma.studentProfile.findFirst({
      where: { id: '2171b290-bccc-4a81-95eb-b857cf81f3ed' },
      include: {
        academicYear: true
      }
    });
    console.log('=== Student relation check ===');
    console.log(JSON.stringify(student, null, 2));

  } catch (error) {
    console.error('Error:', error);
  } finally {
    await prisma.$disconnect();
  }
}

main();
