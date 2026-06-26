/**
 * db-migrate.js
 * Run with: node db-migrate.js
 *
 * Creates the SalaryStructure and Payroll tables and PayrollStatus enum
 * for the HR/Payroll module. Safe to run multiple times (uses IF NOT EXISTS).
 */

require('dotenv').config();
const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

async function main() {
    console.log('🔄 Running HR/Payroll migration...\n');

    // 1. Create PayrollStatus enum (safe if already exists)
    await prisma.$executeRawUnsafe(`
    DO $$ BEGIN
      CREATE TYPE "PayrollStatus" AS ENUM ('PENDING', 'PAID', 'CANCELLED');
    EXCEPTION
      WHEN duplicate_object THEN NULL;
    END $$;
  `);
    console.log('✅ PayrollStatus enum OK');

    // 2. Create SalaryStructure table
    await prisma.$executeRawUnsafe(`
    CREATE TABLE IF NOT EXISTS "SalaryStructure" (
      "id"            TEXT NOT NULL,
      "employeeId"    TEXT NOT NULL,
      "basicSalary"   DOUBLE PRECISION NOT NULL,
      "allowances"    DOUBLE PRECISION NOT NULL DEFAULT 0,
      "deductions"    DOUBLE PRECISION NOT NULL DEFAULT 0,
      "grossSalary"   DOUBLE PRECISION NOT NULL,
      "effectiveFrom" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
      "createdAt"     TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
      "updatedAt"     TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

      CONSTRAINT "SalaryStructure_pkey" PRIMARY KEY ("id"),
      CONSTRAINT "SalaryStructure_employeeId_key" UNIQUE ("employeeId"),
      CONSTRAINT "SalaryStructure_employeeId_fkey"
        FOREIGN KEY ("employeeId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE
    );
  `);
    console.log('✅ SalaryStructure table OK');

    // 3. Create Payroll table
    await prisma.$executeRawUnsafe(`
    CREATE TABLE IF NOT EXISTS "Payroll" (
      "id"           TEXT NOT NULL,
      "structureId"  TEXT NOT NULL,
      "employeeId"   TEXT NOT NULL,
      "month"        INTEGER NOT NULL,
      "year"         INTEGER NOT NULL,
      "presentDays"  INTEGER NOT NULL DEFAULT 0,
      "absentDays"   INTEGER NOT NULL DEFAULT 0,
      "basicSalary"  DOUBLE PRECISION NOT NULL,
      "allowances"   DOUBLE PRECISION NOT NULL,
      "deductions"   DOUBLE PRECISION NOT NULL,
      "netSalary"    DOUBLE PRECISION NOT NULL,
      "status"       "PayrollStatus" NOT NULL DEFAULT 'PENDING',
      "paidAt"       TIMESTAMP(3),
      "paidBy"       TEXT,
      "remarks"      TEXT,
      "createdAt"    TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
      "updatedAt"    TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

      CONSTRAINT "Payroll_pkey" PRIMARY KEY ("id"),
      CONSTRAINT "Payroll_employeeId_month_year_key" UNIQUE ("employeeId", "month", "year"),
      CONSTRAINT "Payroll_structureId_fkey"
        FOREIGN KEY ("structureId") REFERENCES "SalaryStructure"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
      CONSTRAINT "Payroll_employeeId_fkey"
        FOREIGN KEY ("employeeId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE
    );
  `);
    console.log('✅ Payroll table OK');

    // 4. Create indexes
    await prisma.$executeRawUnsafe(`
    CREATE INDEX IF NOT EXISTS "Payroll_month_year_idx" ON "Payroll"("month", "year");
  `);
    await prisma.$executeRawUnsafe(`
    CREATE INDEX IF NOT EXISTS "Payroll_status_idx" ON "Payroll"("status");
  `);
    console.log('✅ Indexes OK');

    console.log('\n🎉 Migration complete! SalaryStructure and Payroll tables are ready.\n');
}

main()
    .catch((e) => {
        console.error('❌ Migration failed:', e.message);
        process.exit(1);
    })
    .finally(() => prisma.$disconnect());
