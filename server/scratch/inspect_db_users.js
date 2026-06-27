const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  try {
    const users = await prisma.user.findMany({
      where: {
        role: {
          in: ['TEACHER', 'ADMIN']
        }
      },
      select: {
        email: true,
        role: true,
        firstName: true,
        lastName: true
      },
      take: 20
    });
    console.log('Teachers and Admins:');
    console.log(JSON.stringify(users, null, 2));

    const totalStudents = await prisma.studentProfile.count();
    console.log('Total students in DB:', totalStudents);
  } catch (error) {
    console.error('Error:', error);
  } finally {
    await prisma.$disconnect();
  }
}

main();
