const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  try {
    console.log('Fetching active routes...');
    const routes = await prisma.transportRoute.findMany();
    console.log('Routes count:', routes.length);
    console.log('Routes:', routes);

    console.log('Fetching allocations...');
    const allocations = await prisma.transportAllocation.findMany();
    console.log('Allocations count:', allocations.length);
    console.log('Allocations:', allocations);
  } catch (error) {
    console.error('Prisma query error:', error);
  } finally {
    await prisma.$disconnect();
  }
}

main();
