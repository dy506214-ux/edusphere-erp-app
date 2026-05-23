const { z } = require('zod');

/**
 * Validator schemas for Attendance related routes
 */

const markAttendanceSchema = z.object({
    studentId: z.string().min(1, 'Student ID is required'),
    date: z.string().optional(),
    status: z.enum(['PRESENT', 'ABSENT', 'LATE', 'HALF_DAY']),
    remarks: z.string().optional(),
    deviceId: z.string().optional(),
});

const bulkMarkSchema = z.object({
    date: z.string().min(1, 'Date is required'),
    attendanceData: z.array(z.object({
        studentId: z.string().min(1, 'Student ID is required'),
        status: z.enum(['PRESENT', 'ABSENT', 'LATE', 'HALF_DAY']),
    })).min(1, 'Attendance data cannot be empty'),
});

const submitSlotSchema = z.object({
    attendanceData: z.array(z.object({
        entityId: z.string().min(1, 'Entity ID is required'),
        status: z.enum(['PRESENT', 'ABSENT', 'LATE', 'HALF_DAY']),
    })).min(1, 'Attendance data cannot be empty'),
});

const qrScanSchema = z.object({
    qrPayload: z.string().min(1, 'QR payload is required'),
    scannerId: z.string().min(1, 'Scanner ID is required'),
    scanLat: z.number().optional(),
    scanLng: z.number().optional(),
    action: z.enum(['checkin', 'checkout']).optional(),
});

module.exports = {
    markAttendanceSchema,
    bulkMarkSchema,
    submitSlotSchema,
    qrScanSchema,
};
