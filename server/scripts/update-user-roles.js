/**
 * Migration script to update existing users with roles array
 * This ensures backward compatibility with users created before multi-role support
 */

require('dotenv').config();
const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');
const { Pool } = require('pg');

// Create PostgreSQL connection pool
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

// Create Prisma adapter
const adapter = new PrismaPg(pool);

// Initialize Prisma with adapter
const prisma = new PrismaClient({
  adapter,
});

async function updateUserRoles() {
  try {
    console.log('Starting user roles migration...');

    // Get all users
    const users = await prisma.user.findMany({
      select: {
        id: true,
        email: true,
        role: true,
        roles: true,
      },
    });

    console.log(`Found ${users.length} users to check`);

    let updated = 0;
    let skipped = 0;

    for (const user of users) {
      // If roles is null or empty, set it to [role]
      if (!user.roles || user.roles.length === 0) {
        await prisma.user.update({
          where: { id: user.id },
          data: { roles: [user.role] },
        });
        console.log(`✓ Updated user ${user.email} with roles: [${user.role}]`);
        updated++;
      } else {
        console.log(`- Skipped user ${user.email} (already has roles)`);
        skipped++;
      }
    }

    console.log('\n✅ Migration completed successfully!');
    console.log(`- Updated: ${updated} users`);
    console.log(`- Skipped: ${skipped} users`);
  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
    await pool.end();
  }
}

// Run migration
updateUserRoles();
