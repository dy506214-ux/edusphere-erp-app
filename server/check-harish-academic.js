const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  try {
    const user = await prisma.user.findUnique({
      where: { email: 'sai.iyer@edusphere.edu' },
      include: {
        student: {
          include: {
            academicYear: true
          }
        }
      }
    });
    console.log('=== Harish Yadav User in DB ===');
    console.log(JSON.stringify(user, null, 2));
  } catch (error) {
    console.error('Error:', error);
  } finally {
    await prisma.$disconnect();
  }
}

main();
