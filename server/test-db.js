const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function testConnection() {
  try {
    console.log('Testing connection to:', process.env.DATABASE_URL);
    await prisma.$connect();
    console.log('Successfully connected to database!');
    const userCount = await prisma.user.count();
    console.log('User count:', userCount);
  } catch (error) {
    console.error('Failed to connect to database:', error);
  } finally {
    await prisma.$disconnect();
  }
}

testConnection();
