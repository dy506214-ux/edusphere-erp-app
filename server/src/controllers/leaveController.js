const { getSchoolDate, getStartOfDay } = require('../utils/dateUtils');
const prisma = require('../config/database');
const asyncHandler = require('../utils/asyncHandler');
const logger = require('../config/logger');
const { ROLES } = require('../constants');

/**
 * Calculate working days between two dates (excludes Saturdays & Sundays)
 */
const countWorkingDays = (startDate, endDate) => {
    let count = 0;
    // Anchor to 12:00 PM to avoid DST/Timezone edge cases during iteration
    const cursor = new Date(startDate);
    cursor.setHours(12, 0, 0, 0);
    
    const end = new Date(endDate);
    end.setHours(12, 0, 0, 0);

    while (cursor <= end) {
        const day = cursor.getDay();
        if (day !== 0 && day !== 6) count++; // Skip Sunday (0) and Saturday (6)
        cursor.setDate(cursor.getDate() + 1);
    }
    return count;
};

// Initialize leave balances for an employee for the current academic year
const initializeLeaveBalances = asyncHandler(async (req, res) => {
    const { employeeId, academicYearId } = req.body;

    if (!employeeId || !academicYearId) {
        return res.status(400).json({ 
            success: false,
            message: 'Employee ID and Academic Year ID are required' 
        });
    }

    // Default quotas (could be moved to a config table later)
    const defaultQuotas = [
        { type: 'CL', total: 12 },
        { type: 'SL', total: 10 },
        { type: 'EL', total: 15 },
    ];

    const balances = await Promise.all(
        defaultQuotas.map(async (quota) => {
            return await prisma.leaveBalance.upsert({
                where: {
                    employeeId_leaveType_academicYearId: {
                        employeeId,
                        leaveType: quota.type,
                        academicYearId
                    }
                },
                update: { total: quota.total },
                create: {
                    employeeId,
                    leaveType: quota.type,
                    academicYearId,
                    total: quota.total,
                    used: 0,
                    pending: 0
                }
            });
        })
    );

    res.status(200).json({ 
        success: true,
        message: 'Leave balances initialized', 
        balances 
    });
});

// Get leave balances for an employee (with auto-initialization)
const getMyBalances = asyncHandler(async (req, res) => {
    const { userId } = req.user;
    const { academicYearId } = req.query;

    // 1. Get current academic year if not provided
    let targetYearId = academicYearId;
    if (!targetYearId) {
        const currentYear = await prisma.academicYear.findFirst({ where: { isCurrent: true } });
        if (!currentYear) {
            return res.status(404).json({ 
                success: false,
                message: 'No current academic year found' 
            });
        }
        targetYearId = currentYear.id;
    }

    // 2. Check if balances exist
    let balances = await prisma.leaveBalance.findMany({
        where: { employeeId: userId, academicYearId: targetYearId },
        include: { academicYear: { select: { name: true, isCurrent: true } } }
    });

    // 3. Auto-initialize if empty
    if (balances.length === 0) {
        const defaultQuotas = [
            { type: 'CL', total: 12 },
            { type: 'SL', total: 10 },
            { type: 'EL', total: 15 },
        ];

        await Promise.all(defaultQuotas.map(quota =>
            prisma.leaveBalance.create({
                data: {
                    employeeId: userId,
                    leaveType: quota.type,
                    academicYearId: targetYearId,
                    total: quota.total,
                    used: 0,
                    pending: 0
                }
            })
        ));

        // Fetch again after creation
        balances = await prisma.leaveBalance.findMany({
            where: { employeeId: userId, academicYearId: targetYearId },
            include: { academicYear: { select: { name: true, isCurrent: true } } }
        });
    }

    res.status(200).json({ 
        success: true,
        balances 
    });
});

// Submit a leave request — uses metadata JSON to store leaveType reliably
const createLeaveRequest = asyncHandler(async (req, res) => {
    const { userId, role } = req.user;
    const { leaveType, startDate, endDate, reason, priority = 'NORMAL' } = req.body;

    if (!leaveType || !startDate || !endDate || !reason) {
        return res.status(400).json({ 
            success: false,
            message: 'Required fields missing' 
        });
    }

    // 1. Verify balance
    const currentYear = await prisma.academicYear.findFirst({ where: { isCurrent: true } });
    if (!currentYear) {
        return res.status(400).json({ 
            success: false,
            message: 'No current academic year found' 
        });
    }

    const today = getSchoolDate();
    const start = new Date(startDate);
    const end = new Date(endDate);
    
    if (start < getStartOfDay(today)) {
        return res.status(400).json({ 
            success: false,
            message: 'Cannot apply for leave in the past' 
        });
    }

    let balance = await prisma.leaveBalance.findFirst({
        where: {
            employeeId: userId,
            leaveType,
            academicYearId: currentYear.id
        }
    });

    // Auto-initialize if missing
    if (!balance && leaveType !== 'UNPAID') {
        const defaultQuotas = { 'CL': 12, 'SL': 10, 'EL': 15, 'MATERNITY': 180 };
        balance = await prisma.leaveBalance.create({
            data: {
                employeeId: userId,
                leaveType,
                academicYearId: currentYear.id,
                total: defaultQuotas[leaveType] || 0,
                used: 0,
                pending: 0
            }
        });
    }

    if (leaveType !== 'UNPAID' && (!balance || (balance.total - balance.used - balance.pending) <= 0)) {
        return res.status(400).json({ 
            success: false,
            message: `Insufficient ${leaveType} balance` 
        });
    }

    const days = countWorkingDays(start, end);

    if (days <= 0) {
        return res.status(400).json({ 
            success: false,
            message: 'Leave period must include at least one working day' 
        });
    }

    if (leaveType !== 'UNPAID' && (balance.total - balance.used - balance.pending) < days) {
        return res.status(400).json({ 
            success: false,
            message: `Requested ${days} working days exceeds remaining balance` 
        });
    }

    // 2. Create the service request — store leaveType in metadata (JSON field)
    //    so we never have to parse it from the subject string.
    const request = await prisma.serviceRequest.create({
        data: {
            requestNumber: `LV-${Date.now().toString().slice(-6)}`,
            requesterId: userId,
            type: 'LEAVE',
            subject: `${leaveType} Request: ${startDate} to ${endDate}`,
            description: reason,
            priority,
            startDate: start,
            endDate: end,
            metadata: JSON.stringify({ leaveType, days }),
            // ADMIN (Principal) can approve directly; all others go through ADMIN approval
            status: 'PENDING_ADMIN',
        }
    });

    // 3. Mark balance as pending
    if (leaveType !== 'UNPAID') {
        await prisma.leaveBalance.update({
            where: { id: balance.id },
            data: { pending: { increment: days } }
        });
    }

    logger.info(`Leave request ${request.requestNumber} created by user ${userId} for ${days} working days`);
    res.status(201).json({ 
        success: true,
        message: 'Leave request submitted', 
        request 
    });
});

/**
 * Process leave request (ADMIN / SUPER_ADMIN can approve or reject)
 * Bug #2 fix: replaced non-existent HOD/PRINCIPAL roles with ADMIN/SUPER_ADMIN
 * Bug #3 fix: reads leaveType from metadata JSON instead of parsing subject string
 */
const processLeaveRequest = asyncHandler(async (req, res) => {
    const { userId, role } = req.user;
    const { id } = req.params;
    const { status, remarks } = req.body; // status: APPROVED or REJECTED

    if (!['APPROVED', 'REJECTED'].includes(status)) {
        return res.status(400).json({ 
            success: false,
            message: 'Status must be APPROVED or REJECTED' 
        });
    }

    const request = await prisma.serviceRequest.findUnique({
        where: { id },
        include: { requester: true }
    });

    if (!request || request.type !== 'LEAVE') {
        return res.status(404).json({ 
            success: false,
            message: 'Leave request not found' 
        });
    }

    if (request.status !== 'PENDING_ADMIN' && request.status !== 'PENDING_HOD' && request.status !== 'PENDING_PRINCIPAL') {
        return res.status(400).json({ 
            success: false,
            message: `This request is already ${request.status}` 
        });
    }

    // Permission check: PRINCIPAL, HOD, ADMIN or SUPER_ADMIN can process leave
    const approverRoles = [ROLES.ADMIN, ROLES.SUPER_ADMIN, ROLES.HR_MANAGER, ROLES.PRINCIPAL, ROLES.HOD];
    if (!approverRoles.includes(role)) {
        return res.status(403).json({ 
            success: false,
            message: 'Unauthorized to process leave requests' 
        });
    }

    // Extract leaveType and days from metadata (Bug #3 fix)
    let leaveType, days;
    try {
        const meta = JSON.parse(request.metadata || '{}');
        leaveType = meta.leaveType;
        days = meta.days;
    } catch {
        // Fallback: parse from subject for backward compatibility with old records
        leaveType = request.subject ? request.subject.split(' ')[0].replace(':', '') : null;
        days = countWorkingDays(request.startDate, request.endDate);
    }

    if (!days || days <= 0) {
        days = countWorkingDays(request.startDate, request.endDate);
    }

    const updated = await prisma.serviceRequest.update({
        where: { id },
        data: {
            status,
            reviewerRemarks: remarks,
            reviewerId: userId,
            reviewedAt: new Date()
        }
    });

    // Adjust leave balance
    if (leaveType && leaveType !== 'UNPAID') {
        const balance = await prisma.leaveBalance.findFirst({
            where: { employeeId: request.requesterId, leaveType, academicYear: { isCurrent: true } }
        });

        if (balance) {
            if (status === 'REJECTED') {
                // Restore pending balance
                await prisma.leaveBalance.update({
                    where: { id: balance.id },
                    data: { pending: { decrement: days } }
                });
            } else if (status === 'APPROVED') {
                // Move from pending to used
                await prisma.leaveBalance.update({
                    where: { id: balance.id },
                    data: {
                        used: { increment: days },
                        pending: { decrement: days }
                    }
                });
            }
        }
    }

    logger.info(`Leave request ${request.requestNumber} ${status} by ${userId}`);
    res.status(200).json({ 
        success: true,
        message: `Leave request ${status.toLowerCase()}`, 
        request: updated 
    });
});

module.exports = {
    initializeLeaveBalances,
    getMyBalances,
    createLeaveRequest,
    processLeaveRequest
};
