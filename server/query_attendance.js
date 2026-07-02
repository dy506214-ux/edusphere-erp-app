const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  try {
    console.log('DATABASE_URL:', process.env.DATABASE_URL);
    console.log('Fetching last 20 attendance slots...');
    const slots = await prisma.attendanceSlot.findMany({
      take: 20,
      orderBy: { createdAt: 'desc' },
      include: {
        _count: { select: { records: true } }
      }
    });
    console.log('Slots:', JSON.stringify(slots, null, 2));

    console.log('Fetching last 20 attendance records...');
    const records = await prisma.attendanceRecord.findMany({
      take: 20,
      orderBy: { createdAt: 'desc' },
      include: {
        student: {
          select: {
            rollNumber: true,
            user: { select: { firstName: true, lastName: true } }
          }
        }
      }
    });
    console.log('Records:', JSON.stringify(records, null, 2));

  } catch (error) {
    console.error('Error querying DB:', error);
  } finally {
    await prisma.$disconnect();
  }
}

main();
