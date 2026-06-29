require('../server/node_modules/dotenv').config({ path: '../server/.env' });
const prisma = require('../server/src/config/database');

async function main() {
  const users = await prisma.user.findMany({
    where: {
      email: { contains: 'student', mode: 'insensitive' }
    },
    select: {
      email: true,
      firstName: true,
      lastName: true,
      role: true,
      student: {
        select: {
          admissionNumber: true,
          academicYearId: true,
          academicYear: true,
          currentClass: true,
        }
      }
    }
  });
  console.log('STUDENT USERS:', JSON.stringify(users, null, 2));
}

main().catch(console.error).finally(() => prisma.$disconnect());
