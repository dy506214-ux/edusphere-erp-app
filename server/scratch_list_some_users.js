const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  try {
    const students = await prisma.student.findMany({
      include: {
        user: { select: { email: true, firstName: true, lastName: true } },
        transportAllocation: { include: { route: true, stop: true } }
      },
      take: 10
    });
    console.log('Students count:', students.length);
    students.forEach(s => {
      console.log(`Student ID: ${s.id}, Email: ${s.user.email}, Name: ${s.user.firstName} ${s.user.lastName}`);
      if (s.transportAllocation) {
        console.log(`  -> Transport Route: ${s.transportAllocation.route.name}, Stop: ${s.transportAllocation.stop.name}`);
      } else {
        console.log(`  -> No transport allocation`);
      }
    });
  } catch (error) {
    console.error('Error listing students:', error);
  } finally {
    await prisma.$disconnect();
  }
}

main();
