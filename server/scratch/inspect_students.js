const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  try {
    const students = await prisma.studentProfile.findMany({
      include: {
        user: true,
        currentClass: true,
        section: true
      },
      orderBy: {
        admissionNumber: 'asc'
      },
      take: 70
    });

    console.log(`Fetched ${students.length} students:`);
    const formatted = students.map(s => ({
      id: s.id,
      admissionNumber: s.admissionNumber,
      name: `${s.user.firstName} ${s.user.lastName}`,
      email: s.user.email,
      class: s.currentClass ? s.currentClass.name : 'N/A',
      section: s.section ? s.section.name : 'N/A',
      status: s.status
    }));
    console.log(JSON.stringify(formatted, null, 2));
  } catch (error) {
    console.error('Error fetching students:', error);
  } finally {
    await prisma.$disconnect();
  }
}

main();
