const prisma = require('../config/database');

/**
 * Repository for Dashboard related database operations
 */
class DashboardRepository {
    // --- Student Stats ---
    async getStudentById(userId) {
        return prisma.student.findUnique({
            where: { userId },
            include: { currentClass: true, section: true }
        });
    }

    async getStudentAttendance(studentId, fromDate) {
        return prisma.attendanceRecord.findMany({
            where: {
                studentId,
                attendeeType: 'STUDENT',
                date: { gte: fromDate }
            },
            select: { date: true, status: true }
        });
    }

    // Bug #24 fix: Use ledger pending amount instead of payment count
    async countPendingFees(studentId) {
        const result = await prisma.studentFeeLedger.aggregate({
            where: { studentId, totalPending: { gt: 0 } },
            _sum: { totalPending: true },
        });
        return result._sum.totalPending || 0;
    }

    async getNextExam(classId, fromDate) {
        return prisma.exam.findFirst({
            where: { classId, startDate: { gte: fromDate } },
            orderBy: { startDate: 'asc' },
            select: { name: true, startDate: true }
        });
    }

    async countBooksDue(studentId, date) {
        return prisma.libraryIssue.count({
            where: {
                studentId,
                status: { in: ['ISSUED', 'OVERDUE'] },
                dueDate: { lt: date }
            }
        });
    }

    // --- Teacher Stats ---
    async getTeacherById(userId) {
        return prisma.teacher.findUnique({ where: { userId } });
    }

    async getClassByTeacher(teacherId) {
        return prisma.class.findUnique({
            where: { classTeacherId: teacherId },
            include: { _count: { select: { students: true } } }
        });
    }

    async getTimetableSlots(teacherId, dayOfWeek) {
        return prisma.timetableSlot.findMany({
            where: { teacherId, dayOfWeek },
            select: { sectionId: true, subjectId: true }
        });
    }

    async countAttendanceSlots(date, sectionIds) {
        return prisma.attendanceSlot.count({
            where: {
                date,
                sectionId: { in: sectionIds }
            }
        });
    }

    async getClassStudents(classId) {
        return prisma.student.findMany({
            where: { currentClassId: classId },
            select: { id: true }
        });
    }

    async countOverdueBooks(studentIdOrList, teacherId) {
        const studentFilter = Array.isArray(studentIdOrList)
            ? { studentId: { in: studentIdOrList } }
            : { studentId: studentIdOrList };

        return prisma.libraryIssue.count({
            where: {
                ...studentFilter,
                status: 'OVERDUE'
            }
        });
    }

    // --- Accountant Stats ---
    async getFeeSum(status, fromDate, toDate) {
        const where = { status };
        if (fromDate || toDate) {
            where.paymentDate = {};
            if (fromDate) where.paymentDate.gte = fromDate;
            if (toDate) where.paymentDate.lt = toDate;
        }

        const result = await prisma.feePayment.aggregate({
            _sum: { amount: true },
            where
        });

        return result || { _sum: { amount: 0 } };
    }

    async countFeeTransactions(status, fromDate, toDate) {
        const where = { status };
        if (fromDate || toDate) {
            where.paymentDate = {};
            if (fromDate) where.paymentDate.gte = fromDate;
            if (toDate) where.paymentDate.lt = toDate;
        }
        return prisma.feePayment.count({ where });
    }

    // --- Admission Manager Stats ---
    async countStudentsByStatus(status) {
        return prisma.student.count({ where: { status } });
    }

    async countAdmissions(fromDate, toDate) {
        return prisma.student.count({
            where: { createdAt: { gte: fromDate, lt: toDate } }
        });
    }

    async countEnquiriesByStatus(status) {
        return prisma.enquiry.count({ where: { status } });
    }

    async getClassDistribution(limit = 5) {
        const distribution = await prisma.student.groupBy({
            by: ['currentClassId'],
            where: { currentClassId: { not: null }, status: 'ACTIVE' },
            _count: { id: true },
            orderBy: { _count: { id: 'desc' } }
        });
        return distribution.slice(0, limit);
    }

    async getClassesByIds(ids) {
        return prisma.class.findMany({
            where: { id: { in: ids } },
            select: { id: true, name: true }
        });
    }

    async getRecentEnquiries(limit = 5) {
        return prisma.enquiry.findMany({
            take: limit,
            orderBy: { createdAt: 'desc' },
            include: { class: { select: { name: true } } }
        });
    }

    // --- Admin Stats ---
    async countUsersByRole(role, isActive = true) {
        return prisma.user.count({ where: { role, isActive } });
    }

    async countSubjectTeachers(teacherId) {
        return prisma.subjectTeacher.count({
            where: { teacherId }
        });
    }

    async countClasses() {
        return prisma.class.count();
    }

    async countTotalSections() {
        return prisma.section.count();
    }

    async countMarkedAttendanceSlots(date) {
        return prisma.attendanceSlot.count({
            where: {
                date: date,
                attendeeType: 'STUDENT'
            }
        });
    }

    async countAttendanceRecords(fromDate, toDate, status) {
        const where = {};
        if (fromDate || toDate) {
            where.date = {};
            if (fromDate) where.date.gte = fromDate;
            if (toDate) where.date.lt = toDate;
        }

        if (status) {
            if (Array.isArray(status)) {
                where.status = { in: status };
            } else {
                where.status = status;
            }
        }
        return prisma.attendanceRecord.count({ where });
    }

    async aggregateAttendance(fromDate, toDate, status) {
        const where = {};
        if (fromDate || toDate) {
            where.date = {};
            if (fromDate) where.date.gte = fromDate;
            if (toDate) where.date.lt = toDate;
        }

        if (status) {
            if (Array.isArray(status)) {
                where.status = { in: status };
            } else {
                where.status = status;
            }
        }

        const result = await prisma.attendanceRecord.aggregate({
            _count: { id: true },
            where
        });
        return result || { _count: { id: 0 } };
    }

    async countUpcomingExams(fromDate, toDate) {
        return prisma.exam.count({
            where: { startDate: { gte: fromDate, lte: toDate } }
        });
    }

    async countLibraryIssuesByStatus(status) {
        return prisma.libraryIssue.count({ where: { status } });
    }

    // --- Activities & Exams ---
    async getRecentFeePayments(limit, studentId = null) {
        return prisma.feePayment.findMany({
            take: limit,
            orderBy: { paymentDate: 'desc' },
            where: studentId ? { studentId } : {},
            include: {
                student: {
                    include: { user: { select: { firstName: true, lastName: true } } }
                }
            }
        });
    }

    async getRecentStudents(limit) {
        return prisma.student.findMany({
            take: limit,
            orderBy: { createdAt: 'desc' },
            include: {
                user: { select: { firstName: true, lastName: true } },
                currentClass: { select: { name: true } }
            }
        });
    }

    async getRecentExams(limit, studentId = null) {
        const where = { endDate: { lte: new Date() } };
        if (studentId) {
            where.examResults = { some: { studentId } };
        }
        return prisma.exam.findMany({
            take: limit,
            orderBy: { createdAt: 'desc' },
            where,
            include: { class: { select: { name: true } } }
        });
    }

    async getRecentAttendanceDates(limit, studentId = null) {
        return prisma.attendanceRecord.findMany({
            take: limit,
            orderBy: { date: 'desc' },
            distinct: ['date'],
            where: studentId ? { studentId } : {},
            select: { date: true }
        });
    }

    async getAttendanceSlotByDate(date) {
        return prisma.attendanceSlot.findFirst({
            where: { date },
            include: { class: { select: { name: true } } }
        });
    }

    async getRecentLibraryIssues(limit, studentId = null) {
        return prisma.libraryIssue.findMany({
            take: limit,
            orderBy: { issueDate: 'desc' },
            where: studentId ? { studentId } : {},
            include: {
                student: {
                    include: { user: { select: { firstName: true, lastName: true } } }
                }
            }
        });
    }

    async getExams(where, take, orderBy, include) {
        return prisma.exam.findMany({ where, take, orderBy, include });
    }

    async getActiveFeeStructures() {
        return prisma.feeStructure.findMany({ where: { isActive: true } });
    }

    async getLowStockItems() {
        // Bug #17 fix: Using findMany with client-side filter for column comparison
        // or just keep raw SQL if preferred, but ensuring it's cleaner.
        // Prisma doesn't support column-to-column compare in 'where' natively yet.
        const items = await prisma.inventoryItem.findMany();
        return items.filter(item => item.quantity <= item.minStockLevel);
    }

    // --- Performance & Trends ---
    async getAttendanceCount(where) {
        return prisma.attendanceRecord.count({ where });
    }

    async getLatestCompletedExam(classId) {
        return prisma.exam.findFirst({
            where: { classId, status: 'COMPLETED' },
            orderBy: { updatedAt: 'desc' },
            include: {
                examResults: {
                    take: 10,
                    include: { student: true }
                }
            }
        });
    }

    async getLatestStudentResult(studentId) {
        return prisma.examResult.findFirst({
            where: { studentId },
            orderBy: { updatedAt: 'desc' },
            include: {
                marks: true,
                exam: true
            }
        });
    }

    // --- Library ---
    async getBooksByCategory() {
        return prisma.book.groupBy({
            by: ['category'],
            _count: { id: true }
        });
    }

    async countBooks() {
        return prisma.book.count();
    }

    async countLibraryIssues(status, dateRange) {
        const where = {};
        if (status) where.status = status;
        if (dateRange) {
            where.issueDate = { gte: dateRange.start, lte: dateRange.end };
        }
        return prisma.libraryIssue.count({ where });
    }

    // --- HR ---
    async countTeachers() {
        return prisma.teacher.count();
    }

    async countStaff() {
        return prisma.staff.count();
    }

    async getLeaveDistribution() {
        // Bug #21 fix: Grouping by leaveType (parsed from subject/metadata) in JavaScript
        // because subjects are unique and Prisma groupBy doesn't support string parsing.
        const requests = await prisma.serviceRequest.findMany({
            where: { type: 'LEAVE', status: 'APPROVED' },
            select: { subject: true, metadata: true }
        });

        const distribution = {};
        requests.forEach(req => {
            let type = 'Other';
            if (req.metadata) {
                try {
                    const meta = JSON.parse(req.metadata);
                    if (meta.leaveType) type = meta.leaveType;
                } catch (e) { }
            }
            if (type === 'Other' && req.subject) {
                type = req.subject.split(' ')[0].replace(':', '');
            }
            distribution[type] = (distribution[type] || 0) + 1;
        });

        return Object.entries(distribution).map(([leaveType, count]) => ({
            leaveType,
            _count: { id: count }
        }));
    }

    // --- Inventory ---
    async getInventoryCategories() {
        return prisma.inventoryItem.groupBy({
            by: ['category'],
            _sum: { quantity: true },
        });
    }

    async getInventoryMovements() {
        const movements = await prisma.stockMovement.groupBy({
            by: ['itemId'],
            _count: { id: true },
        });
        return movements.slice(0, 10);
    }

    async getInventoryItemName(id) {
        return prisma.inventoryItem.findUnique({
            where: { id },
            select: { name: true }
        });
    }

    async getFeeModeBreakdown(fromDate, toDate) {
        const where = { status: 'COMPLETED' };
        if (fromDate) {
            where.paymentDate = { gte: fromDate };
            if (toDate) where.paymentDate.lt = toDate;
        }
        return prisma.feePayment.groupBy({
            by: ['paymentMode'],
            where,
            _sum: { amount: true },
            _count: { id: true },
        });
    }

    async getSubjectAverages() {
        return prisma.examMark.groupBy({
            by: ['subjectName'],
            _avg: { obtainedMarks: true },
            _count: { id: true }
        });
    }

    async getRecentExamsAndResults(classId, limit = 50) {
        return prisma.examResult.findMany({
            where: classId ? { student: { currentClassId: classId } } : {},
            include: { student: true, exam: true },
            take: limit,
            orderBy: { updatedAt: 'desc' }
        });
    }

    // --- Transport Stats ---
    async countVehicles() {
        return prisma.vehicle.count();
    }

    async countActiveTrips() {
        return prisma.transportTrip.count({
            where: { status: 'IN_PROGRESS' }
        });
    }

    async countTransportAllocations() {
        return prisma.transportAllocation.count({
            where: { status: 'ACTIVE' }
        });
    }

    async getAttendanceTrendData(startDate, classId, studentId) {
        const where = {
            date: { gte: startDate },
            attendeeType: 'STUDENT'
        };

        if (studentId) {
            where.studentId = studentId;
        } else if (classId) {
            // Fix: Prisma groupBy does NOT support relation filters (filtering by student.currentClassId)
            // We fetch the student IDs for the class first.
            const students = await this.getClassStudents(classId);
            const studentIds = students.map(s => s.id);
            
            if (studentIds.length === 0) return []; // Fallback for empty classes
            
            where.studentId = { in: studentIds };
        }

        return prisma.attendanceRecord.groupBy({
            by: ['date', 'status'],
            where,
            _count: { id: true },
            orderBy: { date: 'asc' }
        });
    }
    // --- Dashboard Sync Methods ---
    async countStudentsWithoutTransport() {
        return prisma.student.count({
            where: {
                status: 'ACTIVE',
                transportAllocations: {
                    none: { status: 'ACTIVE' }
                }
            }
        });
    }

    async countActiveRoutes() {
        return prisma.transportRoute.count({
            where: {
                isActive: true,
                vehicles: { some: {} }
            }
        });
    }

    async countTotalRoutes() {
        return prisma.transportRoute.count();
    }

    async getInventorySummaryData() {
        const [totalItems, outOfStock, lowStock] = await Promise.all([
            prisma.inventoryItem.count(),
            prisma.inventoryItem.count({ where: { quantity: 0 } }),
            prisma.inventoryItem.findMany()
        ]);
        
        const lowStockCount = lowStock.filter(item => item.quantity > 0 && item.quantity <= item.minStockLevel).length;
        
        return {
            totalItems,
            outOfStock,
            lowStock: lowStockCount
        };
    }

    async getLibrarySummaryData() {
        const [totalBooks, issuedBooks, overdueBooks] = await Promise.all([
            prisma.book.count(),
            prisma.libraryIssue.count({ where: { status: 'ISSUED' } }),
            prisma.libraryIssue.count({ where: { status: 'OVERDUE' } })
        ]);

        return {
            totalBooks,
            availableBooks: totalBooks - (issuedBooks + overdueBooks),
            issuedBooks,
            overdueBooks
        };
    }
}

module.exports = new DashboardRepository();
