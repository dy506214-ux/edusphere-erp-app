const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function clearDB() {
    console.log('Clearing all tables...');
    const tables = await prisma.$queryRawUnsafe(`SELECT tablename FROM pg_tables WHERE schemaname='public'`);
    for (const { tablename } of tables) {
        if (tablename !== '_prisma_migrations') {
            try {
                await prisma.$executeRawUnsafe(`TRUNCATE TABLE "${tablename}" CASCADE;`);
                console.log(`Truncated ${tablename}`);
            } catch (error) {
                console.log({ error });
            }
        }
    }
    console.log('Database cleared!');
}
clearDB().catch(console.error).finally(() => prisma.$disconnect());
