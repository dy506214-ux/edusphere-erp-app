const fs = require('fs');
const path = require('path');
const { getSchoolDate, getStartOfDay } = require('../utils/dateUtils');
const transportRepo = require('../repositories/TransportRepository');
const prisma = require('../config/database');
const ValidationError = require('../errors/ValidationError');
const NotFoundError = require('../errors/NotFoundError');

const SETTINGS_PATH = path.join(__dirname, '../config/transportSettings.json');

class TransportService {
    // --- Vehicle Management ---
    async getVehicles(filters = {}) {
        const where = {};
        if (filters.status) where.status = filters.status;
        if (filters.fuelType) where.fuelType = filters.fuelType;
        if (filters.search) {
            where.OR = [
                { name: { contains: filters.search, mode: 'insensitive' } },
                { registrationNumber: { contains: filters.search, mode: 'insensitive' } }
            ];
        }
        
        const page = parseInt(filters.page) || 1;
        const take = parseInt(filters.limit) || 10;
        const skip = (page - 1) * take;

        const { vehicles, total } = await transportRepo.findVehicles(where, { skip, take });
        
        return {
            vehicles,
            meta: {
                total,
                page,
                limit: take,
                totalPages: Math.ceil(total / take)
            }
        };
    }

    async getVehicleById(id) {
        const vehicle = await transportRepo.findVehicleById(id);
        if (!vehicle) throw new NotFoundError('Vehicle not found');
        
        // --- Calculate Compliance Stats ---
        const today = getSchoolDate();
        const documentStatus = [
            { label: 'Insurance Policy', expiry: vehicle.insuranceExpiry, field: 'insuranceExpiry' },
            { label: 'State Permit', expiry: vehicle.permitExpiry, field: 'permitExpiry' },
            { label: 'Pollution/Fitness', expiry: vehicle.fitnessExpiry, field: 'fitnessExpiry' },
            { label: 'Registration', expiry: vehicle.registrationExpiry, field: 'registrationExpiry' },
            { label: 'PUC Certificate', expiry: vehicle.pucExpiry, field: 'pucExpiry' }
        ].map(doc => {
            const daysLeft = doc.expiry ? Math.ceil((new Date(doc.expiry).getTime() - today.getTime()) / (1000 * 3600 * 24)) : 0;
            return {
                ...doc,
                daysRemaining: daysLeft,
                status: daysLeft < 0 ? 'EXPIRED' : daysLeft < 30 ? 'CRITICAL' : 'OK'
            };
        });

        // --- Calculate Enrollment Stats ---
        // Find all routes this vehicle is assigned to via trips or primary assignment
        const enrollmentCount = await prisma.transportAllocation.count({
            where: {
                route: {
                    trips: {
                        some: { vehicleId: id }
                    }
                }
            }
        });

        return {
            ...vehicle,
            documentStatus,
            enrolledCount: enrollmentCount || 0
        };
    }

    async logMaintenance(vehicleId, data) {
        await this.getVehicleById(vehicleId);
        
        // Validate odometer reading (cannot be less than current)
        const vehicle = await prisma.vehicle.findUnique({ where: { id: vehicleId } });
        if (parseFloat(data.odometerReading) < vehicle.odometerReading) {
            throw new ValidationError(`Odometer reading cannot be less than the current value (${vehicle.odometerReading})`);
        }

        const log = await prisma.vehicleMaintenance.create({
            data: {
                vehicleId,
                serviceDate: new Date(data.serviceDate || new Date()),
                serviceType: data.serviceType,
                odometerReading: parseFloat(data.odometerReading),
                cost: parseFloat(data.cost),
                vendorName: data.vendorName,
                description: data.description,
                nextServiceDue: data.nextServiceDue ? new Date(data.nextServiceDue) : null
            }
        });

        // Update vehicle odometer
        await prisma.vehicle.update({
            where: { id: vehicleId },
            data: { odometerReading: parseFloat(data.odometerReading) }
        });

        return log;
    }

    async logFuel(vehicleId, data) {
        await this.getVehicleById(vehicleId);

        // Validate odometer reading
        const vehicle = await prisma.vehicle.findUnique({ where: { id: vehicleId } });
        if (parseFloat(data.odometerReading) < vehicle.odometerReading) {
            throw new ValidationError(`Odometer reading cannot be less than the current value (${vehicle.odometerReading})`);
        }

        const log = await prisma.vehicleFuelLog.create({
            data: {
                vehicleId,
                date: new Date(data.date || new Date()),
                quantity: parseFloat(data.quantity),
                amount: parseFloat(data.amount),
                odometerReading: parseFloat(data.odometerReading),
                stationName: data.stationName
            }
        });

        // Update vehicle odometer
        await prisma.vehicle.update({
            where: { id: vehicleId },
            data: { odometerReading: parseFloat(data.odometerReading) }
        });

        return log;
    }

    async createVehicle(data) {
        const existing = await prisma.vehicle.findUnique({
            where: { registrationNumber: data.registrationNumber }
        });
        if (existing) throw new ValidationError('Registration number already exists');

        return transportRepo.createVehicle(this._formatVehicleData(data));
    }

    async updateVehicle(id, data) {
        await this.getVehicleById(id);
        return transportRepo.updateVehicle(id, this._formatVehicleData(data));
    }

    async getGlobalLogs(query = {}) {
        const [maintenance, fuel] = await Promise.all([
            prisma.vehicleMaintenance.findMany({
                orderBy: { serviceDate: 'desc' },
                include: { vehicle: { select: { name: true, registrationNumber: true } } },
                take: 50
            }),
            prisma.vehicleFuelLog.findMany({
                orderBy: { date: 'desc' },
                include: { vehicle: { select: { name: true, registrationNumber: true } } },
                take: 50
            })
        ]);

        return { maintenance, fuel };
    }

    _formatVehicleData(data) {
        const formatted = { ...data };
        const dateFields = [
            'registrationDate', 'registrationExpiry', 'insuranceExpiry', 
            'fitnessExpiry', 'permitExpiry', 'pucExpiry'
        ];
        
        dateFields.forEach(field => {
            if (formatted[field]) {
                const date = new Date(formatted[field]);
                if (!isNaN(date.getTime())) {
                    formatted[field] = date;
                }
            }
        });
        
        return formatted;
    }

    // --- Route Management ---
    async getRoutes(filters = {}) {
        const where = {};
        if (filters.search) {
            where.OR = [
                { name: { contains: filters.search, mode: 'insensitive' } },
                { startLocation: { contains: filters.search, mode: 'insensitive' } },
                { endLocation: { contains: filters.search, mode: 'insensitive' } }
            ];
        }

        const page = parseInt(filters.page) || 1;
        const take = parseInt(filters.limit) || 10;
        const skip = (page - 1) * take;

        const { routes, total } = await transportRepo.findRoutes(where, { skip, take });
        
        return {
            routes,
            meta: {
                total,
                page,
                limit: take,
                totalPages: Math.ceil(total / take)
            }
        };
    }

    async getRouteById(id) {
        const route = await transportRepo.findRouteById(id);
        if (!route) throw new NotFoundError('Route not found');
        return route;
    }

    async createRoute(data) {
        const existing = await prisma.transportRoute.findFirst({
            where: { name: data.name }
        });
        if (existing) throw new ValidationError('Route name already exists');
        
        return transportRepo.createRoute(data);
    }

    async updateRoute(id, data) {
        await this.getRouteById(id);
        
        // Handle name uniqueness if changing
        if (data.name) {
            const existing = await prisma.transportRoute.findFirst({
                where: { name: data.name, id: { not: id } }
            });
            if (existing) throw new ValidationError('Another route with this name already exists');
        }

        return transportRepo.updateRoute(id, data);
    }

    // --- Allocation & Nearest Stop logic ---
    async suggestNearestStops(studentId, routeId) {
        const student = await prisma.student.findUnique({
            where: { id: studentId },
            select: { latitude: true, longitude: true }
        });

        if (!student || student.latitude === null || student.longitude === null) {
            // Return empty instead of throwing to prevent UI crash
            return [];
        }

        const route = await this.getRouteById(routeId);
        const stops = route.stops;

        const stopsWithDistance = stops.map(stop => ({
            ...stop,
            distanceFromHome: this._calculateDistance(
                student.latitude, student.longitude,
                stop.latitude, stop.longitude
            )
        })).sort((a, b) => a.distanceFromHome - b.distanceFromHome);

        return stopsWithDistance.slice(0, 3);
    }

    async allocateStudent(data) {
        const { studentId, routeId, stopId, academicYearId } = data;
        
        const student = await prisma.student.findUnique({ where: { id: studentId } });
        if (!student) throw new NotFoundError('Student not found');

        const stop = await prisma.routeStop.findUnique({
            where: { id: stopId },
            include: { route: true }
        });
        if (!stop || stop.routeId !== routeId) {
            throw new ValidationError('Invalid stop or route combination');
        }

        // --- Capacity Check ---
        // Find if any vehicle is currently assigned to this route
        const activeTrip = await prisma.transportTrip.findFirst({
            where: { routeId, status: 'IN_PROGRESS' },
            include: { vehicle: true }
        });

        // Even if no active trip, we check the global allocation count for this route vs assigned vehicle capacity
        // Note: Routes might have primary vehicles in a real enterprise setup, here we'll check the route's current allocations
        const currentAllocations = await prisma.transportAllocation.count({
          where: { routeId, status: 'ACTIVE' }
        });

        // If a vehicle is associated with this route (via any recent trip or primary assignment)
        const vehicle = activeTrip?.vehicle || await prisma.vehicle.findFirst({
            where: { trips: { some: { routeId } } } // Heuristic: Find vehicle that usually flies this route
        });

        if (vehicle && currentAllocations >= vehicle.capacity) {
            // Check if this student is already allocated (update case)
            const existing = await prisma.transportAllocation.findUnique({ where: { studentId } });
            if (!existing || existing.routeId !== routeId) {
                throw new ValidationError(`Route ${stop.route.name} is at full capacity (${vehicle.capacity} seats)`);
            }
        }

        return transportRepo.upsertAllocation(studentId, {
            routeId,
            stopId,
            academicYearId,
            status: 'ACTIVE'
        });
    }

    async getAllocations(filters = {}) {
        const where = {};
        if (filters.search) {
            where.OR = [
                { student: { user: { firstName: { contains: filters.search, mode: 'insensitive' } } } },
                { student: { user: { lastName: { contains: filters.search, mode: 'insensitive' } } } },
                { route: { name: { contains: filters.search, mode: 'insensitive' } } }
            ];
        }

        const page = parseInt(filters.page) || 1;
        const take = parseInt(filters.limit) || 10;
        const skip = (page - 1) * take;

        const { allocations, total } = await transportRepo.findAllocations(where, { skip, take });
        
        return {
            allocations,
            meta: {
                total,
                page,
                limit: take,
                totalPages: Math.ceil(total / take)
            }
        };
    }

    // --- Trip Management ---
    async startTrip(data) {
        const { routeId, vehicleId, type } = data;
        
        const activeTrip = await prisma.transportTrip.findFirst({
            where: { vehicleId, status: 'IN_PROGRESS' }
        });
        if (activeTrip) throw new ValidationError('Vehicle is already on an active trip');

        return transportRepo.createTrip({
            routeId,
            vehicleId,
            type,
            status: 'IN_PROGRESS',
            actualStartTime: getSchoolDate()
        });
    }

    async stopTrip(tripId) {
        const trip = await prisma.transportTrip.findUnique({ where: { id: tripId } });
        if (!trip) throw new NotFoundError('Trip not found');
        if (trip.status !== 'IN_PROGRESS') throw new ValidationError('Trip is not in progress');

        return transportRepo.updateTripStatus(tripId, 'COMPLETED', 'actualEndTime');
    }

    async updateLocation(tripId, locationData) {
        const { latitude, longitude, speed } = locationData;
        
        const log = await transportRepo.logVehicleLocation(tripId, {
            latitude,
            longitude,
            speed,
            timestamp: getSchoolDate()
        });

        // --- Geofencing Engine ---
        const trip = await transportRepo.findTripById(tripId);
        if (trip && trip.route?.stops && trip.route.stops.length > 0) {
            const settings = await this.getTransportSettings();
            
            // Calculate minimum distance to any stop in the route
            const distances = trip.route.stops.map(stop => 
                this._calculateDistance(latitude, longitude, stop.latitude, stop.longitude)
            );
            const minDistance = Math.min(...distances);

            // Trigger deviation alert based on dynamic threshold
            const threshold = settings.geofenceThreshold || 2000;
            if (minDistance > threshold) {
                const fifteenMinutesAgo = new Date(getSchoolDate().getTime() - 15 * 60 * 1000);
                const redundantAlert = await prisma.transportAlert.findFirst({
                    where: {
                        tripId,
                        type: 'ROUTE_DEVIATION',
                        createdAt: { gte: fifteenMinutesAgo }
                    }
                });

                if (!redundantAlert) {
                    await prisma.transportAlert.create({
                        data: {
                            tripId,
                            vehicleId: trip.vehicleId,
                            type: 'ROUTE_DEVIATION',
                            severity: 'HIGH',
                            message: `Vehicle ${trip.vehicle.name} deviated ${Math.round(minDistance)}m from defined route points. Threshold: ${threshold}m.`,
                            latitude,
                            longitude
                        }
                    });
                }
            }
        }

        return log;
    }

    async getTripById(id) {
        return transportRepo.findTripById(id);
    }

    async getMyAllocation(userId, role) {
        if (role === 'STUDENT' || role === 'PARENT') {
            const student = await prisma.student.findFirst({
                where: { userId },
                include: { 
                    transportAllocation: { 
                        include: { 
                            route: { include: { stops: true } },
                            stop: true
                        } 
                    } 
                }
            });
            if (!student || !student.transportAllocation) return null;
            return student.transportAllocation;
        }
        return null;
    }

    async getActiveTripForUser(userId, role) {
        if (['SUPER_ADMIN', 'ADMIN', 'TRANSPORT_MANAGER'].includes(role)) {
            return prisma.transportTrip.findMany({
                where: { status: 'IN_PROGRESS' },
                include: { route: true, vehicle: true }
            });
        }

        if (role === 'DRIVER') {
            const staff = await prisma.staff.findUnique({
                where: { userId },
                select: { id: true }
            });
            if (!staff) throw new NotFoundError('Driver profile not found');

            return prisma.transportTrip.findFirst({
                where: { 
                    status: 'IN_PROGRESS',
                    vehicle: { driverId: staff.id }
                },
                include: { route: true, vehicle: true }
            });
        }

        if (['STUDENT', 'PARENT'].includes(role)) {
            const student = await prisma.student.findFirst({
                where: { userId },
                include: { transportAllocation: true }
            });

            if (!student || !student.transportAllocation) {
                throw new NotFoundError('No transport allocation found for this user');
            }

            return prisma.transportTrip.findFirst({
                where: { 
                    routeId: student.transportAllocation.routeId,
                    status: 'IN_PROGRESS'
                },
                include: { 
                    route: { include: { stops: true } }, 
                    vehicle: { include: { primaryDriver: { include: { user: true } } } } 
                }
            });
        }

        return null;
    }

    async getDriverAssignment(userId) {
        const staff = await prisma.staff.findUnique({
            where: { userId },
            include: {
                managedVehicles: {
                    include: {
                        trips: { orderBy: { createdAt: 'desc' }, take: 1 }
                    }
                }
            }
        });

        if (!staff || !staff.managedVehicles) {
            throw new NotFoundError('No vehicle assigned to this driver');
        }

        const vehicle = staff.managedVehicles;
        const lastTrip = await prisma.transportTrip.findFirst({
            where: { vehicleId: vehicle.id },
            orderBy: { createdAt: 'desc' },
            include: { route: { include: { stops: true } } }
        });

        return { 
            vehicle, 
            route: lastTrip?.route || null,
            activeTrip: vehicle.trips?.[0] || null
        };
    }

    _calculateDistance(lat1, lon1, lat2, lon2) {
        if (!lat1 || !lon1 || !lat2 || !lon2) return Infinity;
        const R = 6371e3;
        const φ1 = lat1 * Math.PI/180;
        const φ2 = lat2 * Math.PI/180;
        const Δφ = (lat2-lat1) * Math.PI/180;
        const Δλ = (lon2-lon1) * Math.PI/180;
        const a = Math.sin(Δφ/2) * Math.sin(Δφ/2) +
                  Math.cos(φ1) * Math.cos(φ2) *
                  Math.sin(Δλ/2) * Math.sin(Δλ/2);
        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
        return R * c;
    }

    async getDashboardStats() {
        const today = new Date();
        today.setHours(0, 0, 0, 0);

        const thirtyDaysFromNow = new Date();
        thirtyDaysFromNow.setDate(thirtyDaysFromNow.getDate() + 30);

        // --- Housekeeping: Cleanup Stale Trips (>12 hours) - Non-blocking ---
        const twelveHoursAgo = new Date(getSchoolDate().getTime() - 12 * 60 * 60 * 1000);
        prisma.transportTrip.updateMany({
            where: { status: 'IN_PROGRESS', actualStartTime: { lte: twelveHoursAgo } },
            data: { status: 'COMPLETED', actualEndTime: getSchoolDate() }
        }).catch(err => logger.error('Stale trip cleanup failed', err));

        const [
            totalVehicles,
            activeRoutes,
            totalAllocations,
            activeTrips,
            maintenanceCount,
            todayAlerts,
            expiringDocs
        ] = await Promise.all([
            prisma.vehicle.count(),
            prisma.transportRoute.count(),
            prisma.transportAllocation.count({ where: { status: 'ACTIVE' } }),
            prisma.transportTrip.count({ where: { status: 'IN_PROGRESS' } }),
            prisma.vehicle.count({ where: { status: 'MAINTENANCE' } }),
            prisma.transportAlert.count({ where: { createdAt: { gte: getStartOfDay() } } }),
            prisma.vehicle.count({
                where: {
                    OR: [
                        { insuranceExpiry: { lte: thirtyDaysFromNow } },
                        { permitExpiry: { lte: thirtyDaysFromNow } },
                        { fitnessExpiry: { lte: thirtyDaysFromNow } }
                    ]
                }
            })
        ]);

        return {
            totalVehicles,
            activeRoutes,
            totalAllocations,
            activeTrips,
            maintenanceCount,
            todayAlerts,
            expiringDocs
        };
    }

    // --- Settings Management ---
    async getTransportSettings() {
        try {
            if (!fs.existsSync(SETTINGS_PATH)) {
                return {
                    geofenceThreshold: 500,
                    strictRouteDeviation: true,
                    pushNotifications: true,
                    emailSummaries: false,
                    dataRetentionDays: 90
                };
            }
            const data = fs.readFileSync(SETTINGS_PATH, 'utf8');
            return JSON.parse(data);
        } catch (err) {
            return { geofenceThreshold: 500 };
        }
    }

    async updateTransportSettings(newSettings) {
        const current = await this.getTransportSettings();
        const updated = { ...current, ...newSettings };
        fs.writeFileSync(SETTINGS_PATH, JSON.stringify(updated, null, 2), 'utf8');
        return updated;
    }
}

module.exports = new TransportService();
