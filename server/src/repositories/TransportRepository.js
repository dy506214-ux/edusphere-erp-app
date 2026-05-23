const prisma = require('../config/database');
const { getSchoolDate } = require('../utils/dateUtils');

class TransportRepository {
    // --- Vehicle Management ---
    async findVehicles(where = {}, options = { skip: 0, take: 50 }) {
        const [vehicles, total] = await Promise.all([
            prisma.vehicle.findMany({
                where,
                include: {
                    primaryDriver: {
                        include: {
                            user: {
                                select: { firstName: true, lastName: true, phone: true }
                            }
                        }
                    },
                    attendant: {
                        include: {
                            user: {
                                select: { firstName: true, lastName: true, phone: true }
                            }
                        }
                    }
                },
                orderBy: { name: 'asc' },
                skip: options.skip,
                take: options.take
            }),
            prisma.vehicle.count({ where })
        ]);

        return { vehicles, total };
    }

    async findVehicleById(id) {
        return prisma.vehicle.findUnique({
            where: { id },
            include: {
                primaryDriver: { include: { user: true } },
                attendant: { include: { user: true } },
                maintenanceLogs: { orderBy: { serviceDate: 'desc' }, take: 10 },
                fuelLogs: { orderBy: { date: 'desc' }, take: 10 },
                dailyChecklists: { orderBy: { checkDate: 'desc' }, take: 5 }
            }
        });
    }

    async createVehicle(data) {
        return prisma.vehicle.create({ data });
    }

    async updateVehicle(id, data) {
        return prisma.vehicle.update({
            where: { id },
            data
        });
    }

    // --- Route Management ---
    async findRoutes(where = {}, options = { skip: 0, take: 50 }) {
        const [routes, total] = await Promise.all([
            prisma.transportRoute.findMany({
                where,
                include: {
                    stops: { orderBy: { order: 'asc' } },
                    _count: {
                        select: { stops: true, allocations: true }
                    }
                },
                orderBy: { name: 'asc' },
                skip: options.skip,
                take: options.take
            }),
            prisma.transportRoute.count({ where })
        ]);
        return { routes, total };
    }

    async findRouteById(id) {
        return prisma.transportRoute.findUnique({
            where: { id },
            include: {
                stops: { orderBy: { order: 'asc' } },
                allocations: {
                    include: {
                        student: {
                            include: {
                                user: { select: { firstName: true, lastName: true } }
                            }
                        },
                        stop: true
                    }
                }
            }
        });
    }

    async createRoute(data) {
        const { stops, ...routeData } = data;
        return prisma.transportRoute.create({
            data: {
                ...routeData,
                stops: {
                    create: stops
                }
            }
        });
    }

    async updateRoute(id, data) {
        const { stops, ...routeData } = data;
        
        return prisma.$transaction(async (tx) => {
            // Update route basic details
            const route = await tx.transportRoute.update({
                where: { id },
                data: routeData
            });

            if (stops) {
                // To keep it simple and maintain referential integrity without complex diffing,
                // we'll update based on order/ids if provided, or replace them.
                // However, since allocations depend on stopId, we should ideally not delete everything.
                
                // Let's get existing stops
                const existingStops = await tx.routeStop.findMany({
                    where: { routeId: id }
                });

                // Diffing:
                const stopsToUpdate = stops.filter(s => s.id && existingStops.some(es => es.id === s.id));
                const stopsToCreate = stops.filter(s => !s.id);
                const stopIdsToKeep = stopsToUpdate.map(s => s.id);
                const stopsToDelete = existingStops.filter(es => !stopIdsToKeep.includes(es.id));

                // 1. Delete removed stops
                if (stopsToDelete.length > 0) {
                    await tx.routeStop.deleteMany({
                        where: { id: { in: stopsToDelete.map(s => s.id) } }
                    });
                }

                // 2. Update existing stops
                for (const stop of stopsToUpdate) {
                    const { id: stopId, ...stopData } = stop;
                    await tx.routeStop.update({
                        where: { id: stopId },
                        data: stopData
                    });
                }

                // 3. Create new stops
                if (stopsToCreate.length > 0) {
                    await tx.routeStop.createMany({
                        data: stopsToCreate.map(s => ({ ...s, routeId: id }))
                    });
                }
            }

            return tx.transportRoute.findUnique({
                where: { id },
                include: { stops: { orderBy: { order: 'asc' } } }
            });
        });
    }

    // --- Allocation ---
    async upsertAllocation(studentId, data) {
        return prisma.transportAllocation.upsert({
            where: { studentId },
            update: data,
            create: {
                studentId,
                ...data
            }
        });
    }

    async findAllocations(where = {}, options = { skip: 0, take: 50 }) {
        const [allocations, total] = await Promise.all([
            prisma.transportAllocation.findMany({
                where,
                include: {
                    student: {
                        include: {
                            user: { select: { firstName: true, lastName: true } },
                            currentClass: { select: { name: true } }
                        }
                    },
                    route: { select: { name: true } },
                    stop: { select: { name: true } }
                },
                skip: options.skip,
                take: options.take
            }),
            prisma.transportAllocation.count({ where })
        ]);
        return { allocations, total };
    }

    // --- Trip Tracking ---
    async createTrip(data) {
        return prisma.transportTrip.create({
            data,
            include: {
                route: { include: { stops: true } },
                vehicle: true
            }
        });
    }

    async findTripById(id) {
        return prisma.transportTrip.findUnique({
            where: { id },
            include: {
                route: { include: { stops: true } },
                vehicle: {
                    include: {
                        primaryDriver: { select: { id: true, userId: true } }
                    }
                },
                locationLogs: { orderBy: { timestamp: 'desc' }, take: 1 }
            }
        });
    }

    async updateTripStatus(id, status, actualTimeField) {
        return prisma.transportTrip.update({
            where: { id },
            data: {
                status,
                [actualTimeField]: getSchoolDate()
            }
        });
    }

    async logVehicleLocation(tripId, data) {
        return prisma.vehicleLocation.create({
            data: {
                tripId,
                ...data
            }
        });
    }
}

module.exports = new TransportRepository();
