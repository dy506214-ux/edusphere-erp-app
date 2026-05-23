const TransportService = require('../services/TransportService');
const asyncHandler = require('../utils/asyncHandler');
const { emitEvent } = require('../services/socketService');

// --- Vehicle Management ---
const getVehicles = asyncHandler(async (req, res) => {
    const { vehicles, meta } = await TransportService.getVehicles(req.query);
    res.status(200).json({ success: true, vehicles, meta });
});

const getVehicleById = asyncHandler(async (req, res) => {
    const vehicle = await TransportService.getVehicleById(req.params.id);
    res.status(200).json({ success: true, vehicle });
});

const createVehicle = asyncHandler(async (req, res) => {
    const vehicle = await TransportService.createVehicle(req.body);
    res.status(201).json({ success: true, message: 'Vehicle created successfully', vehicle });
});

const updateVehicle = asyncHandler(async (req, res) => {
    const vehicle = await TransportService.updateVehicle(req.params.id, req.body);
    emitEvent('TRANSPORT_UPDATE', { type: 'VEHICLE', id: req.params.id }, 'ADMIN');
    res.status(200).json({ success: true, message: 'Vehicle updated successfully', vehicle });
});

// --- Route Management ---
const getRoutes = asyncHandler(async (req, res) => {
    const { routes, meta } = await TransportService.getRoutes(req.query);
    res.status(200).json({ success: true, routes, meta });
});

const getRouteById = asyncHandler(async (req, res) => {
    const route = await TransportService.getRouteById(req.params.id);
    res.status(200).json({ success: true, route });
});

const createRoute = asyncHandler(async (req, res) => {
    const route = await TransportService.createRoute(req.body);
    res.status(201).json({ success: true, message: 'Route created successfully', route });
});

const updateRoute = asyncHandler(async (req, res) => {
    const route = await TransportService.updateRoute(req.params.id, req.body);
    res.status(200).json({ success: true, message: 'Route updated successfully', route });
});

// --- Allocation ---
const suggestNearestStops = asyncHandler(async (req, res) => {
    const { studentId, routeId } = req.query;
    const suggestions = await TransportService.suggestNearestStops(studentId, routeId);
    res.status(200).json({ success: true, suggestions });
});

const allocateStudent = asyncHandler(async (req, res) => {
    const allocation = await TransportService.allocateStudent(req.body);
    emitEvent('TRANSPORT_UPDATE', { type: 'ALLOCATION', studentId: req.body.studentId }, 'ADMIN');
    res.status(201).json({ success: true, message: 'Student allocated to transport successfully', allocation });
});

const getAllocations = asyncHandler(async (req, res) => {
    const { allocations, meta } = await TransportService.getAllocations(req.query);
    res.status(200).json({ success: true, allocations, meta });
});

const getGlobalLogs = asyncHandler(async (req, res) => {
    const logs = await TransportService.getGlobalLogs(req.query);
    res.status(200).json({ success: true, logs });
});

// --- Trip & Real-time Tracking ---
const startTrip = asyncHandler(async (req, res) => {
    const trip = await TransportService.startTrip(req.body);
    res.status(201).json({ success: true, message: 'Trip started successfully', trip });
    
    // Emit real-time event to admins
    emitEvent('TRANSPORT_TRIP_STARTED', {
        tripId: trip.id,
        routeId: trip.routeId,
        vehicleId: trip.vehicleId,
        vehicleName: trip.vehicle.name
    }, 'ADMIN');
});

const stopTrip = asyncHandler(async (req, res) => {
    const trip = await TransportService.stopTrip(req.params.id);
    res.status(200).json({ success: true, message: 'Trip completed successfully', trip });
    
    emitEvent('TRANSPORT_TRIP_COMPLETED', {
        tripId: trip.id
    }, 'ADMIN');
});

const updateLocation = asyncHandler(async (req, res) => {
    const { tripId, latitude, longitude, speed } = req.body;
    const userId = req.user.id;
    const role = req.user.role;
    
    // Security check: Only assigned driver or admin can update
    const trip = await TransportService.getTripById(tripId);
    if (!trip) return res.status(404).json({ success: false, message: 'Trip not found' });

    const isAdmin = ['SUPER_ADMIN', 'ADMIN', 'TRANSPORT_MANAGER'].includes(role);
    const isAssignedDriver = trip.vehicle?.primaryDriver?.userId === userId;

    if (!isAdmin && !isAssignedDriver) {
        return res.status(403).json({ success: false, message: 'Unauthorized: You are not the assigned driver for this trip' });
    }
    
    const log = await TransportService.updateLocation(tripId, { latitude, longitude, speed });
    
    res.status(200).json({ success: true, log });

    // Broadcast live location to the specific trip room (Parents & Admin)
    const io = req.app.get('io');
    if (io) {
        io.to(`trip_${tripId}`).emit('bus_location_update', {
            tripId,
            latitude,
            longitude,
            speed,
            timestamp: new Date().toISOString()
        });
    }
});

const getActiveTrip = asyncHandler(async (req, res) => {
    const trip = await TransportService.getActiveTripForUser(req.user.id, req.user.role);
    res.status(200).json({ success: true, trip });
});

const getMyAllocation = asyncHandler(async (req, res) => {
    const allocation = await TransportService.getMyAllocation(req.user.id, req.user.role);
    res.status(200).json({ success: true, allocation });
});

const getDriverAssignment = asyncHandler(async (req, res) => {
    const { vehicle, route, activeTrip } = await TransportService.getDriverAssignment(req.user.id);
    res.status(200).json({ success: true, vehicle, route, activeTrip });
});

const getDashboardStats = asyncHandler(async (req, res) => {
    const stats = await TransportService.getDashboardStats();
    res.status(200).json({ success: true, stats });
});

const logMaintenance = asyncHandler(async (req, res) => {
    const log = await TransportService.logMaintenance(req.params.id, req.body);
    emitEvent('TRANSPORT_UPDATE', { type: 'MAINTENANCE', vehicleId: req.params.id }, 'ADMIN');
    res.status(201).json({ success: true, message: 'Maintenance record logged successfully', log });
});

const logFuel = asyncHandler(async (req, res) => {
    const log = await TransportService.logFuel(req.params.id, req.body);
    emitEvent('TRANSPORT_UPDATE', { type: 'FUEL', vehicleId: req.params.id }, 'ADMIN');
    res.status(201).json({ success: true, message: 'Fuel record logged successfully', log });
});

const getTransportSettings = asyncHandler(async (req, res) => {
    const settings = await TransportService.getTransportSettings();
    res.status(200).json({ success: true, settings });
});

const updateTransportSettings = asyncHandler(async (req, res) => {
    const settings = await TransportService.updateTransportSettings(req.body);
    res.status(200).json({ success: true, message: 'Transport settings updated successfully', settings });
});

module.exports = {
    getVehicles,
    getVehicleById,
    createVehicle,
    updateVehicle,
    getRoutes,
    getRouteById,
    createRoute,
    updateRoute,
    suggestNearestStops,
    allocateStudent,
    getAllocations,
    getGlobalLogs,
    startTrip,
    stopTrip,
    updateLocation,
    getDriverAssignment,
    getDashboardStats,
    logMaintenance,
    logFuel,
    getActiveTrip,
    getMyAllocation,
    getTransportSettings,
    updateTransportSettings
};
