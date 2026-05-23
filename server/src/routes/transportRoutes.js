const express = require('express');
const {
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
    getActiveTrip,
    getMyAllocation,
    getDashboardStats,
    logMaintenance,
    logFuel,
    getTransportSettings,
    updateTransportSettings
} = require('../controllers/transportController');
const { authMiddleware, requireRole } = require('../middleware/auth');
const validate = require('../middleware/validate');
const { vehicleCreateSchema, routeCreateSchema, allocationCreateSchema } = require('../validators/transportValidator');

const router = express.Router();

// All routes require authentication
router.use(authMiddleware);

router.get('/stats', requireRole('SUPER_ADMIN', 'ADMIN', 'TRANSPORT_MANAGER'), getDashboardStats);

// --- Vehicle Management ---
router.get('/vehicles', requireRole('SUPER_ADMIN', 'ADMIN', 'TRANSPORT_MANAGER'), getVehicles);
router.get('/vehicles/:id', requireRole('SUPER_ADMIN', 'ADMIN', 'TRANSPORT_MANAGER'), getVehicleById);
router.post('/vehicles/:id/maintenance', requireRole('SUPER_ADMIN', 'ADMIN', 'TRANSPORT_MANAGER'), logMaintenance);
router.post('/vehicles/:id/fuel', requireRole('SUPER_ADMIN', 'ADMIN', 'TRANSPORT_MANAGER'), logFuel);
router.post('/vehicles', requireRole('SUPER_ADMIN', 'ADMIN', 'TRANSPORT_MANAGER'), validate(vehicleCreateSchema), createVehicle);
router.put('/vehicles/:id', requireRole('SUPER_ADMIN', 'ADMIN', 'TRANSPORT_MANAGER'), updateVehicle);

// --- Route Management ---
router.get('/routes', requireRole('SUPER_ADMIN', 'ADMIN', 'TRANSPORT_MANAGER', 'TEACHER'), getRoutes);
router.get('/routes/:id', requireRole('SUPER_ADMIN', 'ADMIN', 'TRANSPORT_MANAGER'), getRouteById);
router.post('/routes', requireRole('SUPER_ADMIN', 'ADMIN', 'TRANSPORT_MANAGER'), validate(routeCreateSchema), createRoute);
router.put('/routes/:id', requireRole('SUPER_ADMIN', 'ADMIN', 'TRANSPORT_MANAGER'), updateRoute);

// --- Allocation ---
router.get('/allocations', requireRole('SUPER_ADMIN', 'ADMIN', 'TRANSPORT_MANAGER'), getAllocations);
router.get('/logs', requireRole('SUPER_ADMIN', 'ADMIN', 'TRANSPORT_MANAGER'), getGlobalLogs);
router.get('/allocations/my', requireRole('STUDENT', 'PARENT'), getMyAllocation);
router.get('/suggestions/nearest-stops', requireRole('SUPER_ADMIN', 'ADMIN', 'TRANSPORT_MANAGER', 'ADMISSION_MANAGER'), suggestNearestStops);
router.post('/allocate', requireRole('SUPER_ADMIN', 'ADMIN', 'TRANSPORT_MANAGER', 'ADMISSION_MANAGER'), validate(allocationCreateSchema), allocateStudent);

// --- Trip & Tracking ---
router.get('/trips/active', requireRole('DRIVER', 'STUDENT', 'PARENT', 'ADMIN', 'SUPER_ADMIN', 'TRANSPORT_MANAGER'), getActiveTrip);
router.post('/trips/start', requireRole('SUPER_ADMIN', 'ADMIN', 'DRIVER', 'TRANSPORT_MANAGER'), startTrip);
router.post('/trips/:id/stop', requireRole('SUPER_ADMIN', 'ADMIN', 'DRIVER', 'TRANSPORT_MANAGER'), stopTrip);
router.post('/trips/update-location', requireRole('DRIVER', 'ADMIN', 'SUPER_ADMIN'), updateLocation);

// --- Settings Management ---
router.get('/settings', requireRole('SUPER_ADMIN', 'ADMIN', 'TRANSPORT_MANAGER'), getTransportSettings);
router.post('/settings', requireRole('SUPER_ADMIN', 'ADMIN', 'TRANSPORT_MANAGER'), updateTransportSettings);

// --- Driver Utilities ---
router.get('/driver/assignment', requireRole('DRIVER', 'ADMIN', 'SUPER_ADMIN'), getDriverAssignment);

module.exports = router;
