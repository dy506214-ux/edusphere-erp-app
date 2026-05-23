-- Migration: Remove Parent User Accounts (Single Identity System)
-- Parents NO LONGER have separate user accounts
-- They login using student credentials

-- Step 1: Add new columns to Parent table for personal info
ALTER TABLE "Parent" ADD COLUMN IF NOT EXISTS "firstName" TEXT;
ALTER TABLE "Parent" ADD COLUMN IF NOT EXISTS "lastName" TEXT;
ALTER TABLE "Parent" ADD COLUMN IF NOT EXISTS "email" TEXT;
ALTER TABLE "Parent" ADD COLUMN IF NOT EXISTS "phone" TEXT;

-- Step 2: Migrate data from User to Parent (if any existing parent users)
UPDATE "Parent" p
SET
  "firstName" = u."firstName",
  "lastName" = u."lastName",
  "email" = u.email,
  "phone" = u.phone
FROM "User" u
WHERE p."userId" = u.id
AND p."firstName" IS NULL; -- Only update if not already migrated

-- Step 3: Make firstName and lastName required after data migration
-- (We'll do this after verifying data is migrated)

-- Step 4: Drop the userId foreign key constraint
ALTER TABLE "Parent" DROP CONSTRAINT IF EXISTS "Parent_userId_fkey";

-- Step 5: Drop userId unique index
DROP INDEX IF EXISTS "Parent_userId_key";

-- Step 6: Drop userId index
DROP INDEX IF EXISTS "Parent_userId_idx";

-- Step 7: Remove userId column
ALTER TABLE "Parent" DROP COLUMN IF EXISTS "userId";

-- Step 8: Add new index on email for searching
CREATE INDEX IF NOT EXISTS "Parent_email_idx" ON "Parent"("email");

-- Step 9: Cleanup - Remove any orphaned parent users from User table
-- (Users with role PARENT that don't have student relationships)
-- COMMENTED OUT FOR SAFETY - Review before running:
-- DELETE FROM "User" WHERE role = 'PARENT' AND id NOT IN (SELECT DISTINCT "userId" FROM "Student");

-- Step 10: Make firstName and lastName NOT NULL
-- Run this AFTER verifying all parents have data:
-- ALTER TABLE "Parent" ALTER COLUMN "firstName" SET NOT NULL;
-- ALTER TABLE "Parent" ALTER COLUMN "lastName" SET NOT NULL;

-- Verification queries:
-- SELECT COUNT(*) FROM "Parent" WHERE "firstName" IS NULL OR "lastName" IS NULL;
-- SELECT * FROM "Parent" LIMIT 10;
