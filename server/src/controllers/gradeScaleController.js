const prisma = require('../config/database');
const asyncHandler = require('../utils/asyncHandler');
const logger = require('../config/logger');

// Get all grade scales
const getGradeScales = asyncHandler(async (req, res) => {
    const scales = await prisma.gradeScale.findMany({
        include: {
            entries: { orderBy: { order: 'asc' } },
        },
        orderBy: { name: 'asc' },
    });

    res.status(200).json({ 
        success: true,
        scales 
    });
});

// Create grade scale with entries
const createGradeScale = asyncHandler(async (req, res) => {
    const { name, scaleType, isDefault, entries } = req.body;

    if (!name || !scaleType || !entries || !Array.isArray(entries) || entries.length === 0) {
        return res.status(400).json({ 
            success: false,
            message: 'Required: name, scaleType, entries (array with at least one entry)' 
        });
    }

    // If setting as default, unset other defaults
    if (isDefault) {
        await prisma.gradeScale.updateMany({
            where: { isDefault: true },
            data: { isDefault: false },
        });
    }

    try {
        const scale = await prisma.gradeScale.create({
            data: {
                name,
                scaleType,
                isDefault: isDefault || false,
                entries: {
                    create: entries.map((entry, idx) => ({
                        grade: entry.grade,
                        minPercent: parseFloat(entry.minPercent),
                        maxPercent: parseFloat(entry.maxPercent),
                        gradePoint: entry.gradePoint ? parseFloat(entry.gradePoint) : null,
                        description: entry.description || null,
                        order: entry.order || idx + 1,
                    })),
                },
            },
            include: {
                entries: { orderBy: { order: 'asc' } },
            },
        });

        res.status(201).json({ 
            success: true,
            message: 'Grade scale created successfully', 
            scale 
        });
    } catch (error) {
        if (error.code === 'P2002') {
            return res.status(409).json({ 
                success: false,
                message: 'A grade scale with this name already exists' 
            });
        }
        throw error;
    }
});

// Update grade scale (replace entries)
const updateGradeScale = asyncHandler(async (req, res) => {
    const { id } = req.params;
    const { name, scaleType, isDefault, entries } = req.body;

    const existing = await prisma.gradeScale.findUnique({ where: { id } });
    if (!existing) {
        return res.status(404).json({ error: 'Grade scale not found' });
    }

    // If setting as default, unset other defaults
    if (isDefault) {
        await prisma.gradeScale.updateMany({
            where: { isDefault: true, id: { not: id } },
            data: { isDefault: false },
        });
    }

    // Transaction: update scale + replace entries
    const scale = await prisma.$transaction(async (tx) => {
        // Delete old entries
        await tx.gradeScaleEntry.deleteMany({ where: { gradeScaleId: id } });

        // Update scale and create new entries
        return tx.gradeScale.update({
            where: { id },
            data: {
                name: name || existing.name,
                scaleType: scaleType || existing.scaleType,
                isDefault: isDefault !== undefined ? isDefault : existing.isDefault,
                entries: entries ? {
                    create: entries.map((entry, idx) => ({
                        grade: entry.grade,
                        minPercent: parseFloat(entry.minPercent),
                        maxPercent: parseFloat(entry.maxPercent),
                        gradePoint: entry.gradePoint ? parseFloat(entry.gradePoint) : null,
                        description: entry.description || null,
                        order: entry.order || idx + 1,
                    })),
                } : undefined,
            },
            include: {
                entries: { orderBy: { order: 'asc' } },
            },
        });
    });

    res.status(200).json({ 
        success: true,
        message: 'Grade scale updated successfully', 
        scale 
    });
});

// Delete grade scale
const deleteGradeScale = asyncHandler(async (req, res) => {
    const { id } = req.params;

    const existing = await prisma.gradeScale.findUnique({
        where: { id },
        include: { _count: { select: { exams: true } } },
    });

    if (!existing) {
        return res.status(404).json({ error: 'Grade scale not found' });
    }

    if (existing._count.exams > 0) {
        return res.status(400).json({ 
            success: false,
            message: `Cannot delete: ${existing._count.exams} exams use this grade scale` 
        });
    }

    await prisma.gradeScale.delete({ where: { id } });

    res.status(200).json({ 
        success: true,
        message: 'Grade scale deleted successfully' 
    });
});

module.exports = {
    getGradeScales,
    createGradeScale,
    updateGradeScale,
    deleteGradeScale,
};
