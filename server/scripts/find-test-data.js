const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
    console.log('--- Database Exploration ---');
    
    try {
        const countVehicles = await prisma.vehicle.count();
        const countRoutes = await prisma.transportRoute.count();
        
        console.log(`Vehicles: ${countVehicles}`);
        console.log(`Routes: ${countRoutes}`);

        if (countVehicles > 0 && countRoutes > 0) {
            const vehicle = await prisma.vehicle.findFirst({
                include: { primaryDriver: { include: { user: true } } }
            });
            const route = await prisma.transportRoute.findFirst();
            
            console.log('\n--- Selected for Test ---');
            console.log(`Vehicle ID: ${vehicle.id} (${vehicle.name})`);
            console.log(`Route ID: ${route.id} (${route.name})`);
            if (vehicle.primaryDriver) {
                console.log(`Driver ID: ${vehicle.primaryDriver.id}`);
                console.log(`User ID: ${vehicle.primaryDriver.userId}`);
                console.log(`Driver Name: ${vehicle.primaryDriver.user.firstName} ${vehicle.primaryDriver.user.lastName}`);
            } else {
                console.log('No primary driver assigned to this vehicle.');
            }
        } else {
            console.log('No vehicles or routes found to test with.');
        }
    } catch (err) {
        console.error('Error during database exploration:', err);
    }
}

main()
  .catch(e => console.error(e))
  .finally(() => prisma.$disconnect());
