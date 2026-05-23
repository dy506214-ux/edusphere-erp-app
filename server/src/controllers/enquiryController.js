const prisma = require('../config/database');
const logger = require('../config/logger');
const asyncHandler = require('../utils/asyncHandler');

/**
 * Get all enquiries with filters
 */
const getEnquiries = asyncHandler(async (req, res) => {
    const { status, classId, source, search } = req.query;

    const where = {};
    if (status) where.status = status;
    if (classId) where.classId = classId;
    if (source) where.source = source;
    if (search) {
        where.OR = [
            { studentName: { contains: search, mode: 'insensitive' } },
            { parentName: { contains: search, mode: 'insensitive' } },
            { phone: { contains: search, mode: 'insensitive' } },
            { email: { contains: search, mode: 'insensitive' } }
        ];
    }

    const enquiries = await prisma.enquiry.findMany({
        where,
        include: {
            class: { select: { name: true } },
            academicYear: { select: { name: true } },
            _count: { select: { followUps: true } }
        },
        orderBy: { createdAt: 'desc' }
    });

    res.status(200).json({ success: true, enquiries });
});

/**
 * Create new enquiry
 */
const createEnquiry = asyncHandler(async (req, res) => {
    const { studentName, parentName, phone, email, classId, source, academicYearId } = req.body;

    if (!studentName || !parentName || !phone || !classId || !academicYearId) {
        return res.status(400).json({ success: false, message: 'Required fields missing' });
    }

    const enquiry = await prisma.enquiry.create({
        data: {
            studentName,
            parentName,
            phone,
            email,
            classId,
            source: source || 'WALK_IN',
            academicYearId,
            status: 'PENDING'
        }
    });

    res.status(201).json({ success: true, message: 'Enquiry created successfully', enquiry });
});

/**
 * Get enquiry by ID with follow-ups
 */
const getEnquiryById = asyncHandler(async (req, res) => {
    const { id } = req.params;
    const enquiry = await prisma.enquiry.findUnique({
        where: { id },
        include: {
            class: true,
            academicYear: true,
            followUps: {
                orderBy: { createdAt: 'desc' }
            }
        }
    });

    if (!enquiry) {
        return res.status(404).json({ success: false, message: 'Enquiry not found' });
    }

    res.status(200).json({ success: true, enquiry });
});

/**
 * Update enquiry status or details
 */
const updateEnquiry = asyncHandler(async (req, res) => {
    const { id } = req.params;
    const updates = req.body;

    const enquiry = await prisma.enquiry.update({
        where: { id },
        data: updates
    });

    res.status(200).json({ success: true, message: 'Enquiry updated successfully', enquiry });
});

/**
 * Add follow-up record
 */
const addFollowUp = asyncHandler(async (req, res) => {
    const { id } = req.params;
    const { remark, nextFollowUpDate } = req.body;
    const staffId = req.user.userId;

    const [followUp, enquiry] = await prisma.$transaction([
        prisma.enquiryFollowUp.create({
            data: {
                enquiryId: id,
                staffId,
                remark,
                nextFollowUpDate: nextFollowUpDate ? new Date(nextFollowUpDate) : null
            }
        }),
        prisma.enquiry.update({
            where: { id },
            data: { status: 'FOLLOW_UP' }
        })
    ]);

    res.status(201).json({ success: true, message: 'Follow-up added successfully', followUp });
});

/**
 * Delete enquiry
 */
const deleteEnquiry = asyncHandler(async (req, res) => {
    const { id } = req.params;
    await prisma.enquiry.delete({ where: { id } });
    res.status(200).json({ success: true, message: 'Enquiry deleted successfully' });
});

module.exports = {
    getEnquiries,
    createEnquiry,
    getEnquiryById,
    updateEnquiry,
    addFollowUp,
    deleteEnquiry
};
