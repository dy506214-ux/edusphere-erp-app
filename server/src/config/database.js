const { PrismaClient } = require('@prisma/client');

/**
 * Prisma Client Singleton
 *
 * Connection pool is deliberately limited to avoid "MaxClientsInSessionMode"
 * errors on Supabase free tier (max 4 pooled connections).
 *
 * The connection_limit and pool_timeout are appended to the DATABASE_URL
 * at runtime only when the URL doesn't already contain these params,
 * so they never override explicit settings in .env.
 */

function buildDatabaseUrl() {
  const rawUrl = process.env.DATABASE_URL;
  if (!rawUrl) return rawUrl;

  try {
    const url = new URL(rawUrl);
    // Only set defaults if not explicitly provided in the URL
    if (!url.searchParams.has('connection_limit')) {
      url.searchParams.set('connection_limit', '10');
    }
    if (!url.searchParams.has('pool_timeout')) {
      url.searchParams.set('pool_timeout', '30');
    }
    return url.toString();
  } catch {
    // If URL parsing fails (e.g. non-standard format), return as-is
    return rawUrl;
  }
}

const prisma = new PrismaClient({
  log: process.env.NODE_ENV === 'development' ? ['query', 'error', 'warn'] : ['error'],
  datasources: {
    db: {
      url: buildDatabaseUrl(),
    },
  },
});

// Graceful disconnect on process exit
process.on('beforeExit', async () => {
  await prisma.$disconnect();
});

module.exports = prisma;
