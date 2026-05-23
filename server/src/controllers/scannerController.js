const prisma = require('../config/database');
const { checkGeofence } = require('../utils/geoUtils');
const asyncHandler = require('../utils/asyncHandler');
const logger = require('../config/logger');

// ── Helpers ──────────────────────────────────────────────────────────

const buildScannerWhere = (query) => {
    const where = {};
    if (query.isActive !== undefined) where.isActive = query.isActive === 'true';
    if (query.scannerType) where.scannerType = query.scannerType;
    if (query.search) {
        where.OR = [
            { name: { contains: query.search, mode: 'insensitive' } },
            { location: { contains: query.search, mode: 'insensitive' } },
        ];
    }
    return where;
};

// ── Get all scanners ─────────────────────────────────────────────────

const getScanners = asyncHandler(async (req, res) => {
        const where = buildScannerWhere(req.query);

        const scanners = await prisma.qRScanner.findMany({
            where,
            orderBy: { createdAt: 'desc' },
            include: {
                _count: { select: { attendanceRecords: true } },
            },
        });

        res.status(200).json({ success: true, scanners });
});

// ── Create scanner ───────────────────────────────────────────────────

const createScanner = asyncHandler(async (req, res) => {
        const {
            name,
            location,
            scannerType,
            latitude,
            longitude,
            geofenceRadius,
            allowedRoles,
            isActive,
        } = req.body;

        if (!name) {
            return res.status(400).json({ success: false, message: 'Scanner name is required' });
        }
        if (!allowedRoles || !Array.isArray(allowedRoles) || allowedRoles.length === 0) {
            return res.status(400).json({ success: false, message: 'At least one allowed role must be specified' });
        }

        const scanner = await prisma.qRScanner.create({
            data: {
                name,
                location: location || null,
                scannerType: scannerType || 'ENTRY',
                latitude: latitude != null ? parseFloat(latitude) : null,
                longitude: longitude != null ? parseFloat(longitude) : null,
                geofenceRadius: geofenceRadius != null ? parseInt(geofenceRadius) : 10,
                allowedRoles,
                isActive: isActive !== false,
                createdBy: req.user.userId,
            },
        });

        res.status(201).json({ success: true, message: 'Scanner created successfully', scanner });
});

// ── Get single scanner ───────────────────────────────────────────────

const getScannerById = asyncHandler(async (req, res) => {
        const { id } = req.params;

        const scanner = await prisma.qRScanner.findUnique({
            where: { id },
            include: {
                _count: { select: { attendanceRecords: true } },
                attendanceRecords: {
                    orderBy: { createdAt: 'desc' },
                    take: 20,
                    include: {
                        student: { include: { user: { select: { firstName: true, lastName: true, avatar: true, role: true } } } },
                        teacher: { include: { user: { select: { firstName: true, lastName: true, avatar: true, role: true } } } },
                        staff: { include: { user: { select: { firstName: true, lastName: true, avatar: true, role: true } } } },
                    },
                },
            },
        });

        if (!scanner) {
            return res.status(404).json({ success: false, message: 'Scanner not found' });
        }

        res.status(200).json({ success: true, scanner });
});

// ── Update scanner ───────────────────────────────────────────────────

const updateScanner = asyncHandler(async (req, res) => {
        const { id } = req.params;
        const {
            name,
            location,
            scannerType,
            latitude,
            longitude,
            geofenceRadius,
            allowedRoles,
            isActive,
        } = req.body;

        const existing = await prisma.qRScanner.findUnique({ where: { id } });
        if (!existing) {
            return res.status(404).json({ success: false, message: 'Scanner not found' });
        }

        const data = {};
        if (name !== undefined) data.name = name;
        if (location !== undefined) data.location = location;
        if (scannerType !== undefined) data.scannerType = scannerType;
        if (latitude !== undefined) data.latitude = latitude != null ? parseFloat(latitude) : null;
        if (longitude !== undefined) data.longitude = longitude != null ? parseFloat(longitude) : null;
        if (geofenceRadius !== undefined) data.geofenceRadius = parseInt(geofenceRadius);
        if (allowedRoles !== undefined) data.allowedRoles = allowedRoles;
        if (isActive !== undefined) data.isActive = isActive;

        const scanner = await prisma.qRScanner.update({ where: { id }, data });
        res.status(200).json({ success: true, message: 'Scanner updated successfully', scanner });
});

// ── Delete scanner (soft) ────────────────────────────────────────────

const deleteScanner = asyncHandler(async (req, res) => {
        const { id } = req.params;
        const existing = await prisma.qRScanner.findUnique({ where: { id } });
        if (!existing) {
            return res.status(404).json({ success: false, message: 'Scanner not found' });
        }

        await prisma.qRScanner.update({ where: { id }, data: { isActive: false } });
        res.status(200).json({ success: true, message: 'Scanner deactivated successfully' });
});

// ── Get scanner stats ────────────────────────────────────────────────

const getScannerStats = asyncHandler(async (req, res) => {
        const { id } = req.params;

        const scanner = await prisma.qRScanner.findUnique({ where: { id } });
        if (!scanner) {
            return res.status(404).json({ success: false, message: 'Scanner not found' });
        }

        const todayStart = new Date();
        todayStart.setHours(0, 0, 0, 0);
        const monthStart = new Date(new Date().getFullYear(), new Date().getMonth(), 1);

        const [totalScans, todayScans, monthScans, lastScan] = await Promise.all([
            prisma.attendanceRecord.count({ where: { scannerId: id } }),
            prisma.attendanceRecord.count({ where: { scannerId: id, createdAt: { gte: todayStart } } }),
            prisma.attendanceRecord.count({ where: { scannerId: id, createdAt: { gte: monthStart } } }),
            prisma.attendanceRecord.findFirst({
                where: { scannerId: id },
                orderBy: { createdAt: 'desc' },
                include: {
                    student: { include: { user: { select: { firstName: true, lastName: true } } } },
                    teacher: { include: { user: { select: { firstName: true, lastName: true } } } },
                    staff: { include: { user: { select: { firstName: true, lastName: true } } } },
                },
            }),
        ]);

        res.status(200).json({
            success: true,
            stats: { totalScans, todayScans, monthScans, lastScan },
        });
});

module.exports = {
    getScanners,
    createScanner,
    getScannerById,
    updateScanner,
    deleteScanner,
    getScannerStats,
};
