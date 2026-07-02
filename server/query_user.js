const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  try {
    const slot = await prisma.attendanceSlot.findUnique({
      where: { id: '8c0df2d0-1da3-47d1-8c14-f00dbe2c09f4' },
      include: { records: true }
    });
    console.log('Slot 8c0df2d0-1da3-47d1-8c14-f00dbe2c09f4:', slot);
  } catch (err) {
    console.error(err);
  } finally {
    await prisma.$disconnect();
  }
}

main();
