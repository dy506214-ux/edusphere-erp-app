const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  try {
    const classCounts = await prisma.studentProfile.groupBy({
      by: ['currentClassId'],
      _count: {
        id: true
      }
    });

    console.log('Class student counts:');
    for (let c of classCounts) {
      const cls = await prisma.class.findUnique({ where: { id: c.currentClassId } });
      console.log(`Class name: ${cls ? cls.name : 'N/A'} (ID: ${c.currentClassId}) -> ${c._count.id} students`);
    }

    const totalStudents = await prisma.studentProfile.count();
    console.log('Total students:', totalStudents);
  } catch (error) {
    console.error('Error:', error);
  } finally {
    await prisma.$disconnect();
  }
}

main();
