const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  try {
    const studentUser = await prisma.user.findFirst({
      where: { email: 'student1@demoschool.com' },
      include: {
        student: {
          include: {
            transportAllocation: {
              include: {
                route: {
                  include: {
                    stops: true
                  }
                },
                stop: true
              }
            }
          }
        }
      }
    });
    console.log('student1@demoschool.com User:', JSON.stringify(studentUser, null, 2));
  } catch (error) {
    console.error('Error finding student details:', error);
  } finally {
    await prisma.$disconnect();
  }
}

main();
