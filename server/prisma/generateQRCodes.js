/**
 * Bulk QR Code Generation Script
 * Generates unique QR codes for ALL existing users who don't have one yet.
 * Run: node prisma/generateQRCodes.js
 */

require('dotenv').config();
const { PrismaClient } = require('@prisma/client');
const QRCode = require('qrcode');

const prisma = new PrismaClient();

const generateUserQR = async (userId) => {
    const payload = JSON.stringify({ uid: userId, v: 1 });
    return QRCode.toDataURL(payload, {
        width: 350,
        margin: 2,
        errorCorrectionLevel: 'H',
        color: { dark: '#1a1a2e', light: '#ffffff' },
    });
};

async function main() {
    console.log('\n🔄 Starting bulk QR code generation...\n');

    // Find all users without a QR code
    const usersWithoutQR = await prisma.user.findMany({
        where: { qrCode: null },
        select: { id: true, firstName: true, lastName: true, role: true },
    });

    console.log(`📊 Found ${usersWithoutQR.length} users without QR codes\n`);

    if (usersWithoutQR.length === 0) {
        console.log('✅ All users already have QR codes!');
        return;
    }

    let success = 0;
    let failed = 0;

    for (const user of usersWithoutQR) {
        try {
            const qrCode = await generateUserQR(user.id);
            await prisma.user.update({
                where: { id: user.id },
                data: { qrCode },
            });
            success++;
            console.log(`  ✅ ${user.firstName} ${user.lastName} (${user.role})`);
        } catch (err) {
            failed++;
            console.error(`  ❌ ${user.firstName} ${user.lastName} — ${err.message}`);
        }
    }

    console.log(`\n📈 Results:`);
    console.log(`  ✅ Success: ${success}`);
    console.log(`  ❌ Failed:  ${failed}`);
    console.log(`  📊 Total processed: ${usersWithoutQR.length}\n`);
}

main()
    .catch(console.error)
    .finally(() => prisma.$disconnect());
