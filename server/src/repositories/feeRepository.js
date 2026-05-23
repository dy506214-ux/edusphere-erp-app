const prisma = require('../config/database');
const crypto = require('crypto');
const logger = require('../config/logger');

// Generate a unique receipt/refund number that is safe under concurrency
const generateUniqueId = (prefix) => `${prefix}${crypto.randomUUID().replace(/-/g, '').slice(0, 12).toUpperCase()}`;

class FeeRepository {
    /**
     * Find fee structures with filtering
     */
    async findFeeStructures(where, include = { items: true }) {
        return prisma.feeStructure.findMany({
            where,
            orderBy: { createdAt: 'desc' },
            include,
        });
    }

    /**
     * Get students with their fee ledger status for the fee management listing
     */
    async getFeeStudentsList(where, skip, take) {
        try {
            const students = await prisma.student.findMany({
                where,
                include: {
                    user: {
                        select: { firstName: true, lastName: true, email: true }
                    },
                    currentClass: {
                        select: { name: true }
                    },
                    section: {
                        select: { name: true }
                    }
                },
                skip,
                take,
                orderBy: { createdAt: 'desc' }
            });

            const total = await prisma.student.count({ where });

            // Fetch ledgers safely for each student sequentially to respect connection limits
            const enrichedStudents = [];
            for (const student of students) {
                let feeLedgers = [];
                try {
                    feeLedgers = await prisma.studentFeeLedger.findMany({
                        where: { studentId: student.id },
                        include: { feeStructure: true }
                    });
                } catch (err) {
                    // Silently ignore if studentFeeLedger model doesn't exist yet
                }
                enrichedStudents.push({ ...student, feeLedgers });
            }

            return [enrichedStudents, total];
        } catch (err) {
            logger.error(`[feeRepository] Error fetching fee students: ${err.message}`);
            return [[], 0];
        }
    }

    /**
     * Find a single active fee structure for a class and year
     */
    async findActiveFeeStructure(classId, academicYearId) {
        return prisma.feeStructure.findFirst({
            where: {
                OR: [
                    { classId, academicYearId, isActive: true },
                    { classId: null, academicYearId, isActive: true } // Applied to all classes
                ]
            }
        });
    }

    /**
     * Find all active students for a class or all classes
     */
    async findActiveStudentsForSync(classId) {
        const where = { status: 'ACTIVE' };
        if (classId) where.currentClassId = classId;
        return prisma.student.findMany({ where, select: { id: true, academicYearId: true } });
    }

    /**
     * Sync student fee ledger (Create if not exists, update payable if exists and not paid)
     */
    async syncStudentFeeLedgers(studentIds, structure) {
        return prisma.$transaction(async (tx) => {
            const results = [];
            for (const studentId of studentIds) {
                // Find existing ledger for this student and structure
                const existing = await tx.studentFeeLedger.findFirst({
                    where: { studentId, feeStructureId: structure.id }
                });

                if (!existing) {
                    // Create new ledger
                    results.push(await tx.studentFeeLedger.create({
                        data: {
                            studentId,
                            feeStructureId: structure.id,
                            academicYearId: structure.academicYearId || null,
                            totalPayable: structure.totalAmount,
                            totalPaid: 0,
                            totalPending: structure.totalAmount,
                            totalDiscount: 0,
                            status: 'PENDING'
                        }
                    }));
                } else if (existing.totalPaid === 0 && existing.totalDiscount === 0) {
                    // Update existing ledger only if no payments/discounts processed yet
                    // to avoid messing up active financial records
                    results.push(await tx.studentFeeLedger.update({
                        where: { id: existing.id },
                        data: {
                            totalPayable: structure.totalAmount,
                            totalPending: structure.totalAmount,
                        }
                    }));
                }
            }
            return results;
        });
    }

    /**
     * Create a new fee structure
     */
    async createFeeStructure(data) {
        return prisma.feeStructure.create({
            data,
            include: { items: true },
        });
    }

    /**
     * Find fee structure by ID
     */
    async findFeeStructureById(id) {
        return prisma.feeStructure.findUnique({
            where: { id },
            include: { items: true },
        });
    }

    /**
     * Update fee structure
     */
    async updateFeeStructure(id, data) {
        // Delete old items and create new ones if items are provided
        if (data.items) {
            return prisma.$transaction(async (tx) => {
                await tx.feeStructureItem.deleteMany({
                    where: { feeStructureId: id },
                });

                return tx.feeStructure.update({
                    where: { id },
                    data,
                    include: { items: true },
                });
            });
        }

        return prisma.feeStructure.update({
            where: { id },
            data,
            include: { items: true },
        });
    }

    /**
     * Delete fee structure
     */
    async deleteFeeStructure(id) {
        return prisma.feeStructure.delete({
            where: { id },
        });
    }

    /**
     * Find class details by ID
     */
    async findClassById(id) {
        return prisma.class.findUnique({
            where: { id },
            select: { id: true, name: true },
        });
    }

    /**
     * Find academic year details by ID
     */
    async findAcademicYearById(id) {
        return prisma.academicYear.findUnique({
            where: { id },
            select: { id: true, name: true },
        });
    }

    /**
     * Get fee payments with filtering and pagination
     */
    async findFeePayments(where, skip, take) {
        const payments = await prisma.feePayment.findMany({
            where,
            include: {
                student: {
                    include: {
                        user: {
                            select: { firstName: true, lastName: true },
                        },
                        currentClass: { select: { name: true } },
                    },
                },
                feeStructure: true,
                ledger: true,
            },
            skip,
            take,
            orderBy: { paymentDate: 'desc' },
        });

        const total = await prisma.feePayment.count({ where });

        return [payments, total];
    }

    /**
     * Create a fee payment (Uses transaction)
     */
    async createFeePaymentTx(studentId, ledgerId, parsedAmount, paymentMode, transactionId, forMonth, forYear, userId) {
        return prisma.$transaction(async (tx) => {
            const ledger = await tx.studentFeeLedger.findUnique({
                where: { id: ledgerId },
                include: { feeStructure: true },
            });

            if (!ledger) {
                throw new Error('Fee ledger not found');
            }

            if (parsedAmount > ledger.totalPending) {
                throw new Error(`Amount cannot exceed pending balance of ${ledger.totalPending}`);
            }

            const receiptNumber = generateUniqueId('REC');

            const payment = await tx.feePayment.create({
                data: {
                    receiptNumber,
                    studentId,
                    feeStructureId: ledger.feeStructureId,
                    ledgerId: ledger.id,
                    academicYearId: ledger.academicYearId,
                    amount: parsedAmount,
                    totalAmount: parsedAmount,
                    paymentType: 'RECEIPT',
                    paymentMode,
                    transactionId,
                    forMonth: forMonth ? parseInt(forMonth) : null,
                    forYear: forYear ? parseInt(forYear) : null,
                    status: 'COMPLETED',
                    collectedBy: userId,
                },
            });

            const updatedLedger = await tx.studentFeeLedger.update({
                where: { id: ledger.id },
                data: {
                    totalPaid: { increment: parsedAmount },
                    totalPending: { decrement: parsedAmount },
                    status: (ledger.totalPending - parsedAmount) <= 0 ? 'PAID' : 'PARTIALLY_PAID',
                },
            });

            return { payment, updatedLedger };
        });
    }

    /**
     * Get a single fee payment with all details
     */
    async findPaymentById(id) {
        return prisma.feePayment.findUnique({
            where: { id },
            include: {
                student: { include: { user: true } },
                feeStructure: true,
                ledger: true,
            },
        });
    }

    /**
     * Find ledgers for a student
     */
    async findStudentLedgers(studentId, academicYearId) {
        const where = { studentId };
        if (academicYearId) where.academicYearId = academicYearId;

        try {
            return await prisma.studentFeeLedger.findMany({
                where,
                include: {
                    feeStructure: { include: { items: true } },
                    payments: { orderBy: { paymentDate: 'desc' } },
                    adjustments: true,
                },
                orderBy: { createdAt: 'desc' },
            });
        } catch (err) {
            // Prisma client hasn't been regenerated yet — return empty array
            // Run: cd server && npx prisma generate
            logger.error(`[feeRepository] studentFeeLedger unavailable: ${err.message}`);
            return [];
        }
    }

    /**
     * Get student details for fee status
     */
    async findStudentForFeeStatus(id) {
        return prisma.student.findUnique({
            where: { id },
            include: {
                user: true,
                currentClass: true,
                academicYear: true,
            },
        });
    }

    /**
     * Create a fee adjustment request
     */
    async createFeeAdjustment(data) {
        return prisma.feeAdjustment.create({
            data,
        });
    }

    /**
     * Process a fee adjustment approval/rejection (Uses transaction)
     */
    async processAdjustmentTx(id, status, userId) {
        return prisma.$transaction(async (tx) => {
            const adjustment = await tx.feeAdjustment.findUnique({ where: { id } });
            if (!adjustment) throw new Error('Adjustment not found');
            if (adjustment.status !== 'PENDING') throw new Error('Adjustment already processed');

            const updatedAdjustment = await tx.feeAdjustment.update({
                where: { id },
                data: {
                    status,
                    approvedBy: userId,
                    approvedAt: new Date(),
                },
            });

            if (status === 'APPROVED') {
                const ledger = await tx.studentFeeLedger.findUnique({ where: { id: adjustment.ledgerId } });
                if (!ledger) throw new Error('Ledger not found');

                await tx.studentFeeLedger.update({
                    where: { id: ledger.id },
                    data: {
                        totalDiscount: { increment: adjustment.amount },
                        totalPayable: { decrement: adjustment.amount },
                        totalPending: { decrement: adjustment.amount },
                        status: (ledger.totalPending - adjustment.amount) <= 0 ? 'PAID' : ledger.status
                    },
                });
            }

            return updatedAdjustment;
        });
    }

    /**
     * Process a refund (Uses transaction)
     */
    async processRefundTx(originalReceiptNumber, parsedAmount, reason, userId) {
        return prisma.$transaction(async (tx) => {
            const originalPayment = await tx.feePayment.findUnique({
                where: { receiptNumber: originalReceiptNumber },
            });

            if (!originalPayment) {
                throw new Error('Original payment not found');
            }

            if (parsedAmount > originalPayment.amount) {
                throw new Error('Refund amount cannot exceed original payment amount');
            }

            const refundPayment = await tx.feePayment.create({
                data: {
                    receiptNumber: generateUniqueId('REF'),
                    studentId: originalPayment.studentId,
                    feeStructureId: originalPayment.feeStructureId,
                    ledgerId: originalPayment.ledgerId,
                    academicYearId: originalPayment.academicYearId,
                    amount: -parsedAmount,
                    totalAmount: -parsedAmount,
                    paymentType: 'REFUND',
                    paymentMode: originalPayment.paymentMode,
                    transactionId: `REF-${originalPayment.transactionId || ''}`, // Fallback if null
                    status: 'COMPLETED',
                    collectedBy: userId,
                },
            });

            const ledger = await tx.studentFeeLedger.findUnique({
                where: { id: originalPayment.ledgerId },
            });

            if (ledger) {
                await tx.studentFeeLedger.update({
                    where: { id: ledger.id },
                    data: {
                        totalPaid: { decrement: parsedAmount },
                        totalPending: { increment: parsedAmount },
                        status: 'PARTIALLY_PAID'
                    }
                });
            }

            await tx.feeAdjustment.create({
                data: {
                    studentId: originalPayment.studentId,
                    ledgerId: originalPayment.ledgerId,
                    type: 'REFUND',
                    amount: parsedAmount,
                    reason,
                    status: 'APPROVED',
                    requestedBy: userId,
                    approvedBy: userId,
                    approvedAt: new Date(),
                },
            });

            return refundPayment;
        });
    }

    /**
     * Get all fee adjustments
     */
    async findAdjustments(where) {
        return prisma.feeAdjustment.findMany({
            where,
            include: {
                student: {
                    include: {
                        user: { select: { firstName: true, lastName: true } },
                        currentClass: { select: { name: true } },
                    },
                },
                ledger: {
                    include: {
                        feeStructure: { select: { name: true } },
                    },
                },
            },
            orderBy: { createdAt: 'desc' },
        });
    }

    /**
     * Get fee statistics
     */
    async getFeeStats() {
        const now = new Date();
        const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);

        // Month's collection total
        const monthlyCollection = await prisma.feePayment.aggregate({
            where: { status: 'COMPLETED', paymentDate: { gte: startOfMonth } },
            _sum: { amount: true },
        });

        // Total pending (summed from StudentFeeLedger.totalPending)
        let pendingTotal = null;
        let topDefaulters = [];
        try {
            pendingTotal = await prisma.studentFeeLedger.aggregate({
                _sum: { totalPending: true },
            });
            topDefaulters = await prisma.studentFeeLedger.findMany({
                where: { totalPending: { gt: 0 } },
                take: 5,
                orderBy: { totalPending: 'desc' },
                include: {
                    student: {
                        include: {
                            user: { select: { firstName: true, lastName: true } },
                            currentClass: { select: { name: true } },
                        },
                    },
                },
            });
        } catch (err) {
            logger.error(`[feeRepository] studentFeeLedger unavailable for stats: ${err.message}`);
        }

        return [monthlyCollection, pendingTotal, topDefaulters];
    }

    /**
     * Get monthly collection trend
     */
    async getMonthlyCollection(start, end) {
        return prisma.feePayment.aggregate({
            where: {
                status: 'COMPLETED',
                paymentDate: { gte: start, lte: end },
            },
            _sum: { amount: true },
        });
    }
}

module.exports = new FeeRepository();
