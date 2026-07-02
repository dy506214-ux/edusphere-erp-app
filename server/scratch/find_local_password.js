const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  try {
    const student = await prisma.studentProfile.findFirst();
    if (!student) {
      console.log('No student found');
      return;
    }
    console.log('Student Profile:', JSON.stringify(student, null, 2));
  } catch (err) {
    console.error(err);
  } finally {
    await prisma.$disconnect();
  }
}

main();
