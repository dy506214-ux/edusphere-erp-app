const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  console.log('Environment DATABASE_URL:', process.env.DATABASE_URL);
  
  // Try querying a user
  const count = await prisma.user.count();
  console.log('User count in this database:', count);
  
  const slot = await prisma.attendanceSlot.findUnique({
    where: { id: '8c0df2d0-1da3-47d1-8c14-f00dbe2c09f4' }
  });
  console.log('Slot in this database:', slot);
  
  await prisma.$disconnect();
}
main();
