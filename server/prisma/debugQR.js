const { PrismaClient } = require('@prisma/client');
const QRCode = require('qrcode');
const prisma = new PrismaClient();

async function main() {
    const users = await prisma.user.findMany({
        where: { qrCode: null },
        select: { id: true, firstName: true, lastName: true, role: true },
    });

    console.log(`Found ${users.length} users missing QR`);

    for (const user of users) {
        try {
            const payload = JSON.stringify({ uid: user.id, v: 1 });
            const qrCode = await QRCode.toDataURL(payload, {
                width: 350, margin: 2, errorCorrectionLevel: 'H',
                color: { dark: '#1a1a2e', light: '#ffffff' },
            });
            const result = await prisma.user.update({
                where: { id: user.id },
                data: { qrCode },
            });
            console.log(`SUCCESS: ${user.firstName} ${user.lastName} — qrCode length: ${result.qrCode?.length}`);
        } catch (err) {
            console.error(`FAILED: ${user.firstName} ${user.lastName}`);
            console.error('  Error:', err.message);
            console.error('  Code:', err.code);
            if (err.meta) console.error('  Meta:', JSON.stringify(err.meta));
        }
    }

    await prisma.$disconnect();
}

main().catch(e => { console.error(e); process.exit(1); });
