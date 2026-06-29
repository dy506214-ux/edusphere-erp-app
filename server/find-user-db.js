const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  try {
    const user = await prisma.user.findFirst({
      where: {
        firstName: { contains: 'Harish', mode: 'insensitive' }
      },
      include: {
        student: {
          include: {
            academicYear: true
          }
        }
      }
    });
    console.log('=== Harish User by First Name ===');
    console.log(JSON.stringify(user, null, 2));
  } catch (error) {
    console.error('Error:', error);
  } finally {
    await prisma.$disconnect();
  }
}

main();
