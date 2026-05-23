-- AlterTable
ALTER TABLE "Staff" ADD COLUMN     "assignedScannerId" TEXT;

-- AlterTable
ALTER TABLE "Teacher" ADD COLUMN     "assignedScannerId" TEXT;

-- AddForeignKey
ALTER TABLE "Teacher" ADD CONSTRAINT "Teacher_assignedScannerId_fkey" FOREIGN KEY ("assignedScannerId") REFERENCES "QRScanner"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Staff" ADD CONSTRAINT "Staff_assignedScannerId_fkey" FOREIGN KEY ("assignedScannerId") REFERENCES "QRScanner"("id") ON DELETE SET NULL ON UPDATE CASCADE;
