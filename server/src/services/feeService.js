const feeRepo = require('../repositories/feeRepository');
const prisma = require('../config/database');
const NotFoundError = require('../errors/NotFoundError');
const ValidationError = require('../errors/ValidationError');
const logger = require('../config/logger');

class FeeService {
    /**
     * Get all fee structures with filters
     */
    async getFeeStructures(filters) {
        const { classId, academicYearId, isActive } = filters;

        const where = {};
        if (classId) where.classId = classId;
        if (academicYearId) where.academicYearId = academicYearId;
        if (isActive !== undefined) where.isActive = isActive === 'true';

        // Bug #7 fix: Use include to fetch class + academicYear in one query
        const feeStructures = await feeRepo.findFeeStructures(where, {
            class: { select: { id: true, name: true } },
            academicYear: { select: { id: true, name: true } },
            items: true,
        });

        const enrichedStructures = feeStructures.map(structure => ({
            ...structure,
            amount: structure.totalAmount, // Alias for frontend compatibility
        }));

        // Bug #9 fix: Apply pagination slice
        const page = parseInt(filters.page) || 1;
        const limit = parseInt(filters.limit) || 10;
        const total = enrichedStructures.length;
        const start = (page - 1) * limit;
        const paginatedStructures = enrichedStructures.slice(start, start + limit);

        return {
            structures: paginatedStructures,
            pagination: {
                total,
                pages: Math.ceil(total / limit),
                page,
                limit
            }
        };
    }

    /**
     * Get students with fee status for Fee Management listing
     */
    async getFeeStudents(query) {
        const {
            search,
            classId,
            sectionId,
            status, // PAID, PENDING, or OVERDUE
            page = 1,
            limit = 10
        } = query;

        const skip = (parseInt(page) - 1) * parseInt(limit);
        const take = parseInt(limit);

        const where = { status: 'ACTIVE' }; // Only active students

        if (classId) where.currentClassId = classId;
        if (sectionId) where.sectionId = sectionId;

        if (search) {
            where.OR = [
                { admissionNumber: { contains: search, mode: 'insensitive' } },
                { user: { firstName: { contains: search, mode: 'insensitive' } } },
                { user: { lastName: { contains: search, mode: 'insensitive' } } },
                { rollNumber: { contains: search, mode: 'insensitive' } }
            ];
        }

        const [students, total] = await feeRepo.getFeeStudentsList(where, skip, take);

        // Compute fee status per student based on ledgers
        const enrichedStudents = students.map(student => {
            let totalPayable = 0;
            let totalPaid = 0;
            let totalPending = 0;

            if (student.feeLedgers && student.feeLedgers.length > 0) {
                totalPayable = student.feeLedgers.reduce((sum, l) => sum + (l.totalPayable || 0), 0);
                totalPaid = student.feeLedgers.reduce((sum, l) => sum + (l.totalPaid || 0), 0);
                totalPending = student.feeLedgers.reduce((sum, l) => sum + (l.totalPending || 0), 0);
            }

            let computedStatus = 'PAID';
            if (totalPayable === 0) {
                computedStatus = 'N/A';
            } else if (totalPending > 0) {
                // Bug #22 fix: Check if any ledger is actually overdue
                const today = new Date();
                const currentDay = today.getDate();
                const isAnyOverdue = student.feeLedgers.some(l => {
                    const dueDay = l.feeStructure?.dueDay || 10;
                    return l.totalPending > 0 && currentDay > dueDay;
                });
                
                if (isAnyOverdue) {
                    computedStatus = 'OVERDUE';
                } else {
                    computedStatus = totalPaid > 0 ? 'PARTIAL' : 'PENDING';
                }
            }

            return {
                id: student.id,
                admissionNumber: student.admissionNumber,
                rollNumber: student.rollNumber,
                name: `${student.user?.firstName || ''} ${student.user?.lastName || ''}`.trim(),
                className: student.currentClass?.name || 'N/A',
                sectionName: student.section?.name || 'N/A',
                totalPayable,
                totalPaid,
                totalPending,
                feeStatus: computedStatus
            };
        });

        // Bug #22 fix: Handle OVERDUE status filter
        let resultStudents = enrichedStudents;
        if (status) {
            resultStudents = resultStudents.filter(s => {
                if (status === 'PAID') return s.feeStatus === 'PAID';
                if (status === 'PENDING') return s.feeStatus === 'PENDING' || s.feeStatus === 'PARTIAL';
                if (status === 'OVERDUE') return s.feeStatus === 'PENDING' || s.feeStatus === 'PARTIAL';
                return true;
            });
        }

        // Bug #8 fix: Use filtered count for pagination, not raw DB count
        return {
            students: resultStudents,
            pagination: {
                total: status ? resultStudents.length : total,
                pages: Math.ceil((status ? resultStudents.length : total) / take),
                page: parseInt(page),
                limit: take
            }
        };
    }

    /**
     * Create new fee structure
     */
    async createFeeStructure(data) {
        // Allow multiple structures (e.g., Tuition, Transport, Exam). 
        // Only prevent duplicates if the name matches for the exact same class/year scope.
        const existing = await feeRepo.findFeeStructures({
            name: data.name,
            classId: data.classId,
            academicYearId: data.academicYearId,
            isActive: true
        });

        if (existing && existing.length > 0) {
            throw new ValidationError(`An active fee structure named '${data.name}' already exists for this class and academic year`);
        }

        const feeHeads = data.feeHeads || [];
        const totalAmount = feeHeads.reduce((sum, head) => sum + parseFloat(head.amount || 0), 0);

        const feeStructureData = {
            name: data.name,
            description: data.description,
            classId: data.classId,
            academicYearId: data.academicYearId,
            totalAmount,
            frequency: data.frequency,
            dueDay: parseInt(data.dueDay) || 10,
            earlyPaymentDiscount: parseFloat(data.earlyPaymentDiscount || 0),
            latePaymentPenalty: parseFloat(data.latePaymentPenalty || 0),
            items: {
                create: feeHeads.map(item => ({
                    headName: item.headName,
                    amount: parseFloat(item.amount || 0),
                })),
            },
        };

        const structure = await feeRepo.createFeeStructure(feeStructureData);

        // Retrospective sync for existing students in the class
        await this._syncStudentsWithStructure(structure);

        return structure;
    }

    /**
     * Internal helper to sync students with a fee structure
     * @private
     */
    async _syncStudentsWithStructure(structure) {
        try {
            const students = await feeRepo.findActiveStudentsForSync(structure.classId);
            if (students.length > 0) {
                const studentIds = students.map(s => s.id);
                await feeRepo.syncStudentFeeLedgers(studentIds, structure);
                logger.info(`[FeeService] Synced ${students.length} students with structure ${structure.name}`);
            }
        } catch (err) {
            logger.error(`[FeeService] Failed to sync students with structure: ${err.message}`);
            // We don't throw here to avoid failing the main creation process, 
            // but in a production app we might want to queue this or retry.
        }
    }

    /**
     * Get fee structure by ID
     */
    async getFeeStructureById(id) {
        const structure = await feeRepo.findFeeStructureById(id);
        if (!structure) {
            throw new NotFoundError('Fee structure not found');
        }

        // Add amount alias for frontend
        return {
            ...structure,
            amount: structure.totalAmount
        };
    }

    /**
     * Update fee structure
     */
    async updateFeeStructure(id, data) {
        const structure = await feeRepo.findFeeStructureById(id);
        if (!structure) {
            throw new NotFoundError('Fee structure not found');
        }

        const updateData = {
            name: data.name,
            description: data.description,
            classId: data.classId === 'all' ? null : data.classId,
            academicYearId: data.academicYearId,
            frequency: data.frequency,
            dueDay: parseInt(data.dueDay) || 10,
            earlyPaymentDiscount: parseFloat(data.earlyPaymentDiscount || 0),
            latePaymentPenalty: parseFloat(data.latePaymentPenalty || 0),
        };

        if (data.feeHeads) {
            updateData.totalAmount = data.feeHeads.reduce((sum, head) => sum + parseFloat(head.amount || 0), 0);
            // Bug #12 fix: Delete old items before creating new ones
            updateData.items = {
                deleteMany: {},
                create: data.feeHeads.map(item => ({
                    headName: item.headName,
                    amount: parseFloat(item.amount || 0),
                })),
            };
        }

        const updatedStructure = await feeRepo.updateFeeStructure(id, updateData);

        // Re-sync if amount or class changed
        await this._syncStudentsWithStructure(updatedStructure);

        return updatedStructure;
    }

    /**
     * Delete fee structure
     */
    async deleteFeeStructure(id) {
        const structure = await feeRepo.findFeeStructureById(id);
        if (!structure) {
            throw new NotFoundError('Fee structure not found');
        }

        // Safety check: Don't delete if it has ledgers or payments
        // For simplicity in this ERP, we might just allow it if no payments exist
        // or just let Prisma throw a foreign key error which our error handler handles.

        return feeRepo.deleteFeeStructure(id);
    }

    /**
     * Get paginated fee payments
     */
    async getFeePayments(filters) {
        const { studentId, academicYearId, status, startDate, endDate, page = 1, limit = 25 } = filters;

        const where = {};
        if (studentId) where.studentId = studentId;
        if (academicYearId) where.academicYearId = academicYearId;
        if (status) where.status = status;

        if (startDate || endDate) {
            where.paymentDate = {};
            if (startDate) where.paymentDate.gte = new Date(startDate);
            if (endDate) where.paymentDate.lte = new Date(endDate);
        }

        const skip = (parseInt(page) - 1) * parseInt(limit);

        const [payments, total] = await feeRepo.findFeePayments(where, skip, parseInt(limit));

        return {
            payments,
            pagination: {
                total,
                page: parseInt(page),
                limit: parseInt(limit),
                totalPages: Math.ceil(total / parseInt(limit)),
            },
        };
    }

    /**
     * Create a new fee payment
     */
    async createFeePayment(data, userId) {
        const parsedAmount = parseFloat(data.amount);
        if (isNaN(parsedAmount) || parsedAmount <= 0) {
            throw new ValidationError('Invalid amount value');
        }
        // Financial Idempotency Check: Prevent duplicate transaction entries
        if (data.transactionId && data.paymentMode !== 'CASH') {
            const existingPayment = await prisma.feePayment.findFirst({
                where: { transactionId: data.transactionId }
            });
            if (existingPayment) {
                throw new ValidationError(`Transaction ID '${data.transactionId}' has already been processed.`);
            }
        }

        const result = await feeRepo.createFeePaymentTx(
            data.studentId,
            data.ledgerId,
            parsedAmount,
            data.paymentMode,
            data.transactionId,
            data.forMonth,
            data.forYear,
            userId
        );

        const paymentWithDetails = await feeRepo.findPaymentById(result.payment.id);
        return paymentWithDetails;
    }

    /**
     * Get student fee status (ledgers and summary)
     */
    async getStudentFeeStatus(studentId, academicYearId) {
        const ledgers = await feeRepo.findStudentLedgers(studentId, academicYearId);
        // Bug #23 fix: findMany returns [] not null, so check length
        if (!ledgers || ledgers.length === 0) {
            // Return empty summary instead of throwing — student may simply have no fees assigned
        }

        const student = await feeRepo.findStudentForFeeStatus(studentId);
        if (!student) {
            throw new NotFoundError('Student not found');
        }

        const totalPayable = ledgers.reduce((sum, l) => sum + l.totalPayable, 0);
        const totalPaid = ledgers.reduce((sum, l) => sum + l.totalPaid, 0);
        const totalPending = ledgers.reduce((sum, l) => sum + l.totalPending, 0);

        const recentPaymentsData = await feeRepo.findFeePayments({ studentId }, 0, 5);

        return {
            student,
            ledgers,
            recentPayments: recentPaymentsData[0],
            summary: {
                totalFees: totalPayable,
                totalPaid,
                totalDue: totalPending,
            },
        };
    }

    /**
     * Request a fee adjustment
     */
    async requestAdjustment(data, userId) {
        const adjustmentData = {
            studentId: data.studentId,
            ledgerId: data.ledgerId,
            type: data.type,
            amount: parseFloat(data.amount),
            reason: data.reason,
            status: 'PENDING',
            requestedBy: userId,
        };

        return feeRepo.createFeeAdjustment(adjustmentData);
    }

    /**
     * Approve or reject a fee adjustment
     */
    async approveAdjustment(id, status, userId) {
        if (!['APPROVED', 'REJECTED'].includes(status)) {
            throw new ValidationError('Invalid status');
        }

        return feeRepo.processAdjustmentTx(id, status, userId);
    }

    /**
     * Process a refund
     */
    async processRefund(data, userId) {
        const parsedAmount = parseFloat(data.amount);
        if (isNaN(parsedAmount) || parsedAmount <= 0) {
            throw new ValidationError('Invalid refund amount');
        }

        return feeRepo.processRefundTx(data.originalReceiptNumber, parsedAmount, data.reason, userId);
    }

    /**
     * Get adjustments list
     */
    async getAdjustments(filters) {
        const { status, type } = filters;
        const where = {};
        if (status) where.status = status;
        if (type) where.type = type;

        return feeRepo.findAdjustments(where);
    }

    /**
     * Get admin dashboard fee stats
     */
    async getFeeStats() {
        const summaryData = await feeRepo.getFeeStats();

        const totalCollected = summaryData[0]?._sum?.amount || 0;
        const totalPending = summaryData[1]?._sum?.totalPending || 0;
        const defaulters = summaryData[2]?.map(l => ({
            name: `${l.student.user.firstName} ${l.student.user.lastName}`,
            class: l.student.currentClass?.name || 'N/A',
            amount: l.totalPending,
        })) || [];

        const collectionRate = totalCollected + totalPending > 0
            ? (totalCollected / (totalCollected + totalPending)) * 100
            : 0;

        const trendData = [];
        const now = new Date();
        for (let i = 5; i >= 0; i--) {
            const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
            const start = new Date(d.getFullYear(), d.getMonth(), 1);
            const end = new Date(d.getFullYear(), d.getMonth() + 1, 0);

            const monthName = d.toLocaleString('default', { month: 'short' });
            const monthCollection = await feeRepo.getMonthlyCollection(start, end);

            trendData.push({
                month: monthName,
                collected: monthCollection?._sum?.amount || 0,
            });
        }

        return {
            summary: {
                totalCollected,
                pending: totalPending,
                collectionRate: Math.round(collectionRate * 10) / 10,
            },
            trend: trendData,
            defaulters,
        };
    }
}

module.exports = new FeeService();
