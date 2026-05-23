const prisma = require('../config/database');
const asyncHandler = require('../utils/asyncHandler');
const logger = require('../config/logger');

// Create a new performance review (Principal/Admin)
const createPerformanceReview = asyncHandler(async (req, res) => {
    const { employeeId, periodStart, periodEnd, ratings, strengths, improvements, comments } = req.body;
    const reviewerId = req.user.userId;

    if (!employeeId || !periodStart || !periodEnd || !ratings) {
        return res.status(400).json({ 
            success: false,
            message: 'Required fields missing' 
        });
    }

    const review = await prisma.performanceReview.create({
        data: {
            employeeId,
            reviewerId,
            periodStart: new Date(periodStart),
            periodEnd: new Date(periodEnd),
            ratings, // Json object: { academic: 4, discipline: 5, punctuality: 4 }
            strengths,
            improvements,
            comments,
            status: 'SUBMITTED'
        }
    });

    res.status(201).json({ 
        success: true,
        message: 'Performance review submitted', 
        review 
    });
});

// Get reviews for an employee (self view or manager view)
const getEmployeeReviews = asyncHandler(async (req, res) => {
    const { employeeId } = req.params;
    const { userId, role } = req.user;

    // Security check: Teachers can only view their own reviews
    if (role === 'TEACHER' && employeeId !== userId) {
        return res.status(403).json({ 
            success: false,
            message: 'Access denied' 
        });
    }

    const reviews = await prisma.performanceReview.findMany({
        where: { employeeId },
        include: {
            reviewer: { select: { firstName: true, lastName: true, role: true } }
        },
        orderBy: { reviewDate: 'desc' }
    });

    res.status(200).json({ 
        success: true,
        reviews 
    });
});

// Ack review (Employee)
const acknowledgeReview = asyncHandler(async (req, res) => {
    const { id } = req.params;
    const { userId } = req.user;

    const review = await prisma.performanceReview.findUnique({ where: { id } });
    if (!review || review.employeeId !== userId) {
        return res.status(404).json({ 
            success: false,
            message: 'Review not found' 
        });
    }

    const updated = await prisma.performanceReview.update({
        where: { id },
        data: { status: 'ACKNOWLEDGED' }
    });

    res.status(200).json({ 
        success: true,
        message: 'Review acknowledged', 
        review: updated 
    });
});

module.exports = {
    createPerformanceReview,
    getEmployeeReviews,
    acknowledgeReview
};
