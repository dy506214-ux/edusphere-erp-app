const prisma = require('../server/src/config/database');

async function main() {
  const students = await prisma.studentProfile.findMany({
    include: {
      user: true,
      currentClass: true,
      section: true,
      academicYear: true,
    }
  });
  console.log('ALL STUDENTS:', students.map(s => ({
    id: s.id,
    email: s.user?.email,
    name: `${s.user?.firstName} ${s.user?.lastName}`,
    class: s.currentClass?.name,
    academicYearId: s.academicYearId,
    academicYear: s.academicYear
  })));
}

main().catch(console.error).finally(() => prisma.$disconnect());
