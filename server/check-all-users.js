const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  try {
    const users = await prisma.user.findMany({
      where: { role: 'STUDENT' },
      take: 20,
      include: {
        student: true
      }
    });
    console.log('=== Student Role Users in DB ===');
    users.forEach(u => {
      console.log(`Email: ${u.email}, Name: ${u.firstName} ${u.lastName}, Has Profile: ${!!u.student}`);
    });
  } catch (error) {
    console.error('Error:', error);
  } finally {
    await prisma.$disconnect();
  }
}

main();
