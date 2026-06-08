const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const record = await prisma.attendanceRecord.findFirst();
  if (record) {
    console.log('=== AttendanceRecord fields ===');
    console.log(JSON.stringify(record, null, 2));
    console.log('\n=== Field names ===');
    console.log(Object.keys(record));
  } else {
    console.log('No attendance records found. Checking count...');
    const count = await prisma.attendanceRecord.count();
    console.log('Total records:', count);
  }
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
