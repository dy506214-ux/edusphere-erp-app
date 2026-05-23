const { z } = require('zod');

/**
 * Validator schemas for Transport related routes
 */

const routeCreateSchema = z.object({
    name: z.string().min(1, 'Route name is required'),
    description: z.string().optional(),
    vehicleIds: z.array(z.string()).optional(),
    stops: z.array(z.object({
        name: z.string().min(1, 'Stop name is required'),
        arrivalTime: z.string().optional(),
        latitude: z.number().optional(),
        longitude: z.number().optional(),
        order: z.number().optional()
    })).optional()
});

const vehicleCreateSchema = z.object({
    vehicleNumber: z.string().min(1, 'Vehicle number is required'),
    capacity: z.number().min(1, 'Capacity is required'),
    type: z.string().optional(),
    ownerName: z.string().optional(),
    ownerPhone: z.string().optional(),
    driverId: z.string().optional()
});

const allocationCreateSchema = z.object({
    studentId: z.string().min(1, 'Student ID is required'),
    routeId: z.string().min(1, 'Route ID is required'),
    stopId: z.string().min(1, 'Stop ID is required'),
    academicYearId: z.string().min(1, 'Academic Year ID is required'),
    startDate: z.string().optional(),
    feeAmount: z.number().optional()
});

module.exports = {
    routeCreateSchema,
    vehicleCreateSchema,
    allocationCreateSchema
};
