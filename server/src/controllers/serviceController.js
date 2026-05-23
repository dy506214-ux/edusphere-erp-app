const prisma = require('../config/database');
const asyncHandler = require('../utils/asyncHandler');
const logger = require('../config/logger');

const generateRequestNumber = () => {
    return `SR-${Date.now().toString().slice(-6)}-${Math.floor(Math.random() * 1000)}`;
};

// Get service requests (Students see their own, Admins see all)
const getServiceRequests = asyncHandler(async (req, res) => {
    const { role, userId } = req.user;
    const { status, type } = req.query;

    const where = {};
    if (status) where.status = status;
    if (type) where.type = type;

    // Student can only see their own requests
    if (role === 'STUDENT') {
        where.requesterId = userId;
    }

    const requests = await prisma.serviceRequest.findMany({
        where,
        include: {
            requester: {
                select: {
                    id: true,
                    firstName: true,
                    lastName: true,
                    email: true,
                    role: true,
                    avatar: true,
                }
            },
            reviewer: {
                select: {
                    id: true,
                    firstName: true,
                    lastName: true,
                }
            }
        },
        orderBy: { createdAt: 'desc' },
    });

    res.status(200).json({ 
        success: true,
        requests 
    });
});

// Create a new service request
const createServiceRequest = asyncHandler(async (req, res) => {
    const { userId } = req.user;
    const { type, subject, description, priority, startDate, endDate, attachmentUrl } = req.body;

    if (!type || !subject || !description) {
        return res.status(400).json({ 
            success: false,
            message: 'Required fields missing' 
        });
    }

    const request = await prisma.serviceRequest.create({
        data: {
            requestNumber: generateRequestNumber(),
            requesterId: userId,
            type,
            subject,
            description,
            priority: priority || 'NORMAL',
            startDate: startDate ? new Date(startDate) : null,
            endDate: endDate ? new Date(endDate) : null,
            attachmentUrl,
        }
    });

    res.status(201).json({ 
        success: true,
        message: 'Request submitted successfully', 
        request 
    });
});

// Update request status (Admin/Teacher only)
const updateServiceRequest = asyncHandler(async (req, res) => {
    const { userId } = req.user;
    const { id } = req.params;
    const { status, reviewerRemarks } = req.body;

    const request = await prisma.serviceRequest.findUnique({ where: { id } });

    if (!request) {
        return res.status(404).json({ 
            success: false,
            message: 'Request not found' 
        });
    }

    const updatedRequest = await prisma.serviceRequest.update({
        where: { id },
        data: {
            status,
            reviewerRemarks,
            reviewerId: userId,
            reviewedAt: new Date(),
        },
        include: {
            requester: {
                select: {
                    id: true,
                    firstName: true,
                    lastName: true,
                    email: true,
                    role: true,
                    avatar: true,
                }
            },
            reviewer: {
                select: {
                    id: true,
                    firstName: true,
                    lastName: true,
                }
            }
        }
    });

    res.status(200).json({ 
        success: true,
        message: 'Request updated successfully', 
        request: updatedRequest 
    });
});

module.exports = {
    getServiceRequests,
    createServiceRequest,
    updateServiceRequest,
};
