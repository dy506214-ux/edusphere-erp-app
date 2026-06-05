const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  try {
    const result = await prisma.$queryRawUnsafe(`
      SELECT column_name, column_default, is_nullable 
      FROM information_schema.columns 
      WHERE table_name = 'AttendanceRecord'
    `);
    console.log('Column details for AttendanceRecord:');
    console.log(JSON.stringify(result, null, 2));
  } catch (error) {
    console.error('Error querying columns:', error);
  } finally {
    await prisma.$disconnect();
  }
}

main();
