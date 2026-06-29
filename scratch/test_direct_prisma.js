const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const userId = 'c9541df0-573d-470d-932d-0c8d86c5676e';
  const student = await prisma.studentProfile.findFirst({
    where: { userId },
    include: {
      user: true,
      currentClass: true,
      section: true,
      academicYear: true,
    }
  });
  console.log("=== PRISMA DIRECT STUDENT ===");
  console.log(JSON.stringify(student, null, 2));
}

main().catch(console.error).finally(() => prisma.$disconnect());
