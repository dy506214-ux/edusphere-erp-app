const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  try {
    const studentUser = await prisma.user.findFirst({
      where: { email: 'alex.rivera@edusmart.edu' },
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
    console.log('Alex Rivera Student User:', JSON.stringify(studentUser, null, 2));
  } catch (error) {
    console.error('Error finding student details:', error);
  } finally {
    await prisma.$disconnect();
  }
}

main();
