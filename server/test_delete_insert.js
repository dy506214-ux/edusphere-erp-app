const { PrismaClient } = require('@prisma/client');

async function main() {
  const prisma = new PrismaClient();
  const slotId = '8c0df2d0-1da3-47d1-8c14-f00dbe2c09f4';
  const userId = 'b68e7472-d6f4-4f13-b610-b9c409f59483';
  
  // Dummy student IDs for class 9
  const studentIds = [
    'e3ec066a-5cb8-4f56-80ba-1fb15df520d3',
    '91a1f7de-6c0f-4902-bdd7-866232921c67'
  ];

  try {
    console.log('Simulating transaction...');
    await prisma.$transaction(async (tx) => {
      // 1. Find slot
      const slot = await tx.attendanceSlot.findUnique({ where: { id: slotId } });
      if (!slot) {
        console.log('Slot not found.');
        return;
      }
      console.log('Slot date:', slot.date);

      // 2. Delete existing records
      const delCount = await tx.attendanceRecord.deleteMany({
        where: {
          date: slot.date,
          attendeeType: slot.attendeeType,
          studentId: { in: studentIds }
        }
      });
      console.log('Deleted records count:', delCount.count);

      // 3. Create records
      const createCount = await tx.attendanceRecord.createMany({
        data: studentIds.map(sid => ({
          attendeeType: slot.attendeeType,
          studentId: sid,
          date: slot.date,
          status: 'PRESENT',
          slotId: slotId,
          markedBy: userId
        }))
      });
      console.log('Created records count:', createCount.count);
    });
  } catch (err) {
    console.error('Transaction failed:', err);
  } finally {
    await prisma.$disconnect();
  }
}
main();
