const { getSchoolDate, getStartOfDay } = require('../utils/dateUtils');
const DashboardRepository = require('../repositories/DashboardRepository');
const CalendarService = require('./CalendarService');
const logger = require('../config/logger');

/**
 * Service for Dashboard operations
 */
class DashboardService {
    async getDashboardStats(userRole, userId) {
        const today = getSchoolDate();
        const todayEvents = await CalendarService.getEvents(today, today);
        const todayEvent = todayEvents.length > 0 ? todayEvents[0] : null;

        const todayStart = getStartOfDay(today);
        const tomorrow = new Date(todayStart);
        tomorrow.setDate(tomorrow.getDate() + 1);
        const firstDayOfMonth = new Date(today.getFullYear(), today.getMonth(), 1);
        firstDayOfMonth.setHours(0, 0, 0, 0);

        try {
            if (userRole === 'STUDENT') {
                const stats = await this._getStudentStats(userId, firstDayOfMonth, today);
                return { ...stats, todayEvent };
            }

            if (userRole === 'TEACHER') {
                const stats = await this._getTeacherStats(userId, todayStart);
                return { ...stats, todayEvent };
            }

            if (userRole === 'ACCOUNTANT') {
                const stats = await this._getAccountantStats(today, tomorrow);
                return { ...stats, todayEvent };
            }

            if (userRole === 'ADMISSION_MANAGER') {
                const stats = await this._getAdmissionManagerStats(todayStart, tomorrow);
                return { ...stats, todayEvent };
            }

            if (userRole === 'ADMIN' || userRole === 'SUPER_ADMIN') {
                const stats = await this._getAdminStats(todayStart, tomorrow);
                return { ...stats, todayEvent };
            }
        } catch (error) {
            logger.error(`Error in getDashboardStats for role ${userRole}:`, error);
            // Return minimal fallback stats if requested role fails
            return { role: userRole, error: 'Partial data failure', todayEvent };
        }

        throw new Error(`Unsupported role: ${userRole}`);
    }

    async _getStudentStats(userId, firstDayOfMonth, today) {
        const student = await DashboardRepository.getStudentById(userId);
        if (!student) throw new Error('Student record not found');

        const attendanceRecords = await DashboardRepository.getStudentAttendance(student.id, firstDayOfMonth);

        const uniqueDaysCount = new Set(attendanceRecords.map(r => r.date.toISOString().split('T')[0])).size;
        const presentDaysCount = new Set(
            attendanceRecords
                .filter(r => r.status === 'PRESENT' || r.status === 'LATE')
                .map(r => r.date.toISOString().split('T')[0])
        ).size;

        const attendancePercentage = uniqueDaysCount > 0 ? ((presentDaysCount / uniqueDaysCount) * 100).toFixed(1) : 0;
        const pendingFees = await DashboardRepository.countPendingFees(student.id);
        const nextExam = await DashboardRepository.getNextExam(student.currentClassId, today);
        const booksDue = await DashboardRepository.countBooksDue(student.id, today);

        return {
            studentId: student.id,
            attendancePercentage: parseFloat(attendancePercentage),
            pendingFees,
            nextExam: nextExam ? { name: nextExam.name, date: nextExam.startDate } : null,
            booksDue,
            transport: student.transportAllocation ? {
                route: student.transportAllocation.route.name,
                stop: student.transportAllocation.stop.name,
                time: student.transportAllocation.stop.arrivalTime
            } : null,
            role: 'STUDENT'
        };
    }

    async _getTeacherStats(userId, todayStart) {
        const teacher = await DashboardRepository.getTeacherById(userId);
        if (!teacher) throw new Error('Teacher record not found');

        const [myClass, subjectCount, scheduledSlots] = await Promise.all([
            DashboardRepository.getClassByTeacher(teacher.id),
            DashboardRepository.countSubjectTeachers(teacher.id),
            DashboardRepository.getTimetableSlots(teacher.id, todayStart.getDay())
        ]);

        const sectionIds = scheduledSlots.map(s => s.sectionId);
        const markedSlots = sectionIds.length > 0 ? await DashboardRepository.countAttendanceSlots(todayStart, sectionIds) : 0;

        const classesToday = scheduledSlots.length;
        const pendingAttendance = Math.max(0, classesToday - markedSlots);

        const classStudents = myClass ? await DashboardRepository.getClassStudents(myClass.id) : [];
        const studentIds = classStudents.map(s => s.id);
        const overdueBooks = await DashboardRepository.countOverdueBooks(studentIds.length > 0 ? studentIds : [], teacher.id);

        return {
            isClassTeacher: !!myClass,
            myClassId: myClass ? myClass.id : null,
            myClassName: myClass ? myClass.name : null,
            myClassStudents: myClass?._count?.students || 0,
            subjectCount: subjectCount || 0,
            classesToday,
            pendingAttendance,
            overdueBooks,
            role: 'TEACHER'
        };
    }

    async _getAccountantStats(today, tomorrow) {
        const yearStart = new Date(today.getFullYear(), 0, 1);
        const [todayColl, yearColl, txToday, pendingAmt] = await Promise.all([
            DashboardRepository.getFeeSum('COMPLETED', today, tomorrow),
            DashboardRepository.getFeeSum('COMPLETED', yearStart),
            DashboardRepository.countFeeTransactions('COMPLETED', today, tomorrow),
            DashboardRepository.getFeeSum('PENDING')
        ]);

        return {
            role: 'ACCOUNTANT',
            todayCollection: parseFloat(todayColl?._sum?.amount || 0) || 0,
            yearCollection: parseFloat(yearColl?._sum?.amount || 0) || 0,
            pendingAmount: parseFloat(pendingAmt?._sum?.amount || 0) || 0,
            txToday: txToday || 0,
        };
    }

    async getAccountantStats() {
        const today = getSchoolDate();
        const todayStart = getStartOfDay(today);
        const tomorrow = new Date(todayStart);
        tomorrow.setDate(tomorrow.getDate() + 1);

        const [stats, todayPayments, modeBreakdown] = await Promise.all([
            this._getAccountantStats(today, tomorrow),
            DashboardRepository.getRecentFeePayments(50, null), // Detailed list for accountant
            DashboardRepository.getFeeModeBreakdown(today, tomorrow)
        ]);

        return {
            ...stats,
            todayTransactions: todayPayments.map(p => ({
                id: p.id,
                receipt: p.receiptNumber,
                studentName: p.student ? `${p.student.user.firstName} ${p.student.user.lastName}` : 'Unknown',
                class: p.student?.currentClass?.name || 'N/A',
                amount: parseFloat(p.amount || 0),
                mode: p.paymentMode,
                time: p.paymentDate,
            })),
            modeBreakdown: modeBreakdown.map(m => ({
                mode: m.paymentMode,
                amount: m._sum.amount || 0,
                count: m._count.id,
            })),
        };
    }

    async _getAdmissionManagerStats(todayStart, tomorrow) {
        const thisMonthStart = new Date(todayStart.getFullYear(), todayStart.getMonth(), 1);

        const [totalStudents, admissionsToday, admissionsThisMonth] = await Promise.all([
            DashboardRepository.countStudentsByStatus('ACTIVE'),
            DashboardRepository.countAdmissions(todayStart, tomorrow),
            DashboardRepository.countAdmissions(thisMonthStart),
        ]);

        const [pendingEnq, followUpEnq, convertedEnq] = await Promise.all([
            DashboardRepository.countEnquiriesByStatus('PENDING'),
            DashboardRepository.countEnquiriesByStatus('FOLLOW_UP'),
            DashboardRepository.countEnquiriesByStatus('CONVERTED'),
        ]);

        const classDistribution = await DashboardRepository.getClassDistribution();
        const classes = await DashboardRepository.getClassesByIds(classDistribution.map(item => item.currentClassId));
        const classMap = classes.reduce((acc, curr) => ({ ...acc, [curr.id]: curr.name }), {});

        const formattedDistribution = classDistribution.map(item => ({
            name: classMap[item.currentClassId] || 'Unknown',
            count: item._count.id
        }));

        const recentEnquiries = await DashboardRepository.getRecentEnquiries();

        return {
            role: 'ADMISSION_MANAGER',
            totalStudents,
            admissionsToday,
            admissionsThisMonth,
            funnelStats: { pending: pendingEnq, followUp: followUpEnq, converted: convertedEnq },
            classDistribution: formattedDistribution,
            recentEnquiries: recentEnquiries.map(enq => ({
                id: enq.id,
                studentName: enq.studentName,
                parentName: enq.parentName,
                phone: enq.phone,
                class: enq.class?.name || 'Unknown',
                status: enq.status,
                createdAt: enq.createdAt
            }))
        };
    }

    async _getAdminStats(todayStart, tomorrow) {
        const thisMonthStart = new Date(todayStart);
        thisMonthStart.setDate(1);
        thisMonthStart.setHours(0, 0, 0, 0);

        const lastMonthStart = new Date(thisMonthStart);
        lastMonthStart.setMonth(lastMonthStart.getMonth() - 1);

        // Core Counts
        const countsResults = await Promise.allSettled([
            DashboardRepository.countUsersByRole('STUDENT'),
            DashboardRepository.countUsersByRole('TEACHER'),
            DashboardRepository.countClasses(),
            DashboardRepository.countAdmissions(thisMonthStart), // studentsThisMonth
            DashboardRepository.countAdmissions(lastMonthStart, thisMonthStart), // studentsLastMonth
        ]);

        const [totalStudents, totalTeachers, totalClasses, studentsThisMonth, studentsLastMonth] = countsResults.map(r => r.status === 'fulfilled' ? r.value : 0);

        // Financial & Attendance Trends
        const trendResults = await Promise.allSettled([
            DashboardRepository.getFeeSum('COMPLETED', thisMonthStart),
            DashboardRepository.getFeeSum('COMPLETED', lastMonthStart, thisMonthStart),
            DashboardRepository.aggregateAttendance(thisMonthStart, null, ['PRESENT', 'LATE']),
            DashboardRepository.aggregateAttendance(lastMonthStart, thisMonthStart, ['PRESENT', 'LATE']),
            DashboardRepository.countAttendanceRecords(thisMonthStart),
            DashboardRepository.countAttendanceRecords(lastMonthStart, thisMonthStart),
            DashboardRepository.countAttendanceRecords(todayStart, tomorrow), // totalAttToday
            DashboardRepository.countAttendanceRecords(todayStart, tomorrow, ['PRESENT', 'LATE']), // presentAttToday
        ]);

        const [thisMonthFee, lastMonthFee, thisMonthAttPresent, lastMonthAttPresent, thisMonthAttTotal, lastMonthAttTotal, totalAttToday, presentAttToday] = trendResults.map(r => r.status === 'fulfilled' ? r.value : null);

        // Operational Metrics
        const opResults = await Promise.allSettled([
            DashboardRepository.countFeeTransactions('PENDING'),
            DashboardRepository.countUpcomingExams(todayStart, new Date(todayStart.getTime() + 30 * 24 * 60 * 60 * 1000)),
            DashboardRepository.countLibraryIssuesByStatus('OVERDUE'),
            DashboardRepository.countMarkedAttendanceSlots(todayStart),
            DashboardRepository.countTotalSections(),
        ]);

        const [pendingFeeCount, upcomingExamCount, overdueBooks, markedSections, totalSectionsCount] = opResults.map(r => r.status === 'fulfilled' ? r.value : 0);

        // Calculations
        const attendanceToday = totalAttToday > 0 ? parseFloat(((presentAttToday / totalAttToday) * 100).toFixed(1)) : 0;

        const thisMonthAvg = thisMonthAttTotal > 0 ? ((thisMonthAttPresent?._count?.id || 0) / thisMonthAttTotal) : 0;
        const lastMonthAvg = lastMonthAttTotal > 0 ? ((lastMonthAttPresent?._count?.id || 0) / lastMonthAttTotal) : 0;
        const attendanceChange = lastMonthAvg > 0 ? parseFloat(((thisMonthAvg - lastMonthAvg) / lastMonthAvg * 100).toFixed(1)) : 0;

        const thisMonthFeesAmount = parseFloat(thisMonthFee?._sum?.amount || 0);
        const lastMonthFeesAmount = parseFloat(lastMonthFee?._sum?.amount || 0);
        const feesChange = lastMonthFeesAmount > 0 ? parseFloat(((thisMonthFeesAmount - lastMonthFeesAmount) / lastMonthFeesAmount * 100).toFixed(1)) : 0;

        const studentsChange = studentsLastMonth > 0 ? parseFloat(((studentsThisMonth - studentsLastMonth) / studentsLastMonth * 100).toFixed(1)) : 0;

        return {
            totalStudents: totalStudents || 0,
            totalTeachers: totalTeachers || 0,
            totalClasses: totalClasses || 0,
            attendanceToday: attendanceToday || 0,
            attendanceChange: attendanceChange || 0,
            attendanceDetails: {
                marked: markedSections || 0,
                total: totalSectionsCount || 0
            },
            feesCollected: thisMonthFeesAmount || 0,
            feesChange: feesChange || 0,
            studentsChange: studentsChange || 0,
            recentAdmissions: studentsThisMonth || 0,
            upcomingExamCount: upcomingExamCount || 0,
            overdueBooks: overdueBooks || 0,
            transport: await this._getTransportOverallStats(),
            inventorySummary: await DashboardRepository.getInventorySummaryData(),
            librarySummary: await DashboardRepository.getLibrarySummaryData(),
            role: 'ADMIN'
        };
    }

    async _getTransportOverallStats() {
        try {
            const [totalVehicles, activeTrips, totalAllocations, pending, activeRoutes, totalRoutes] = await Promise.all([
                DashboardRepository.countVehicles(),
                DashboardRepository.countActiveTrips(),
                DashboardRepository.countTransportAllocations(),
                DashboardRepository.countStudentsWithoutTransport(),
                DashboardRepository.countActiveRoutes(),
                DashboardRepository.countTotalRoutes()
            ]);

            return {
                totalVehicles,
                activeTrips,
                totalAllocations,
                pending,
                coverage: totalRoutes > 0 ? Math.round((activeRoutes / totalRoutes) * 100) : 0,
                onRoad: activeTrips > 0
            };
        } catch (err) {
            logger.error('Error fetching transport stats:', err);
            return { totalVehicles: 0, activeTrips: 0, totalAllocations: 0, pending: 0, coverage: 0, onRoad: false };
        }
    }

    async getAttendanceTrendData(startDate, classId, studentId) {
        return DashboardRepository.getAttendanceTrendData(startDate, classId, studentId);
    }

    async countTransportAllocations() {
        return DashboardRepository.countTransportAllocations();
    }

    async getRecentActivities(userRole, userId, limit = 10) {
        if (userRole === 'ACCOUNTANT') {
            const recentPayments = await DashboardRepository.getRecentFeePayments(limit);
            return recentPayments.map(p => ({
                id: `fee-${p.id}`,
                type: 'Fee',
                description: `Fee ₹${p.amount} collected from ${p.student.user.firstName} ${p.student.user.lastName}`,
                time: getRelativeTime(p.paymentDate),
                timestamp: new Date(p.paymentDate).getTime(),
                mode: p.paymentMode,
                receipt: p.receiptNumber,
            }));
        }

        let studentId = null;
        if (userRole === 'STUDENT') {
            const student = await DashboardRepository.getStudentById(userId);
            if (student) studentId = student.id;
        }

        let recentStudents = [];
        if (['SUPER_ADMIN', 'ADMIN', 'TEACHER'].includes(userRole)) {
            recentStudents = await DashboardRepository.getRecentStudents(3);
        }

        const [recentPayments, recentExams, recentAttendance, recentLibrary] = await Promise.all([
            DashboardRepository.getRecentFeePayments(3, studentId),
            DashboardRepository.getRecentExams(2, studentId),
            DashboardRepository.getRecentAttendanceDates(2, studentId),
            DashboardRepository.getRecentLibraryIssues(2, studentId)
        ]);

        const activities = [];

        recentStudents.forEach(s => activities.push({
            id: `student-${s.id}`,
            type: 'Student',
            description: `New student admission: ${s.user.firstName} ${s.user.lastName} (${s.currentClass?.name || 'No Class'})`,
            time: getRelativeTime(s.createdAt),
            timestamp: new Date(s.createdAt).getTime(),
        }));

        recentPayments.forEach(p => activities.push({
            id: `fee-${p.id}`,
            type: 'Fee',
            description: `Fee payment received from ${p.student.user.firstName} ${p.student.user.lastName}`,
            time: getRelativeTime(p.paymentDate),
            timestamp: new Date(p.paymentDate).getTime(),
        }));

        recentExams.forEach(e => activities.push({
            id: `exam-${e.id}`,
            type: 'Exam',
            description: `${e.name} results published for ${e.class?.name || 'Multiple Classes'}`,
            time: getRelativeTime(e.createdAt),
            timestamp: new Date(e.createdAt).getTime(),
        }));

        for (const att of recentAttendance) {
            const slot = await DashboardRepository.getAttendanceSlotByDate(att.date);
            activities.push({
                id: `attendance-${att.date.getTime()}`,
                type: 'Attendance',
                description: slot?.class ? `Attendance session recorded for ${slot.class.name}` : 'Daily attendance session completed',
                time: getRelativeTime(att.date),
                timestamp: new Date(att.date).getTime(),
            });
        }

        recentLibrary.forEach(l => activities.push({
            id: `library-${l.id}`,
            type: 'Library',
            description: `Book issued to ${l.student.user.firstName} ${l.student.user.lastName}`,
            time: getRelativeTime(l.issueDate),
            timestamp: new Date(l.issueDate).getTime(),
        }));

        return activities.sort((a, b) => b.timestamp - a.timestamp).slice(0, limit);
    }

    async getUpcomingExams(userId, userRole, limit = 10) {
        const today = getSchoolDate();
        let classFilter = {};

        if (userRole === 'STUDENT') {
            const student = await DashboardRepository.getStudentById(userId);
            if (student && student.currentClassId) {
                classFilter = { classId: student.currentClassId };
            }
        }

        const exams = await DashboardRepository.getExams(
            { startDate: { gte: today }, ...classFilter },
            limit,
            { startDate: 'asc' },
            { class: { select: { name: true } }, examSubjects: { take: 1, include: { subject: { select: { name: true } } } } }
        );

        return exams.map(exam => ({
            id: exam.id,
            name: exam.name,
            class: exam.class?.name || 'All Classes',
            date: exam.startDate ? new Date(exam.startDate).toISOString().split('T')[0] : 'N/A',
            subject: exam.examSubjects[0]?.subject?.name || 'Multiple Subjects'
        }));
    }

    async getFeeCollectionSummary() {
        const thisMonthStart = new Date();
        thisMonthStart.setDate(1);
        thisMonthStart.setHours(0, 0, 0, 0);

        const activeFeeStructures = await DashboardRepository.getActiveFeeStructures();
        const totalExpected = activeFeeStructures.reduce((sum, s) => sum + parseFloat(s.totalAmount || 0), 0);
        const collectedThisMonth = await DashboardRepository.getFeeSum('COMPLETED', thisMonthStart);

        const collected = collectedThisMonth._sum.amount || 0;
        return {
            totalExpected: parseFloat(totalExpected),
            collected: parseFloat(collected),
            pending: totalExpected - parseFloat(collected || 0),
            collectionRate: totalExpected > 0 ? ((parseFloat(collected || 0) / totalExpected) * 100).toFixed(1) : 0
        };
    }

    async getInventoryAlerts() {
        const items = await DashboardRepository.getLowStockItems();
        return {
            lowStockCount: items.length,
            items
        };
    }

    async getAttendanceTrend(classId, studentId) {
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const sevenDaysAgo = new Date(today);
        sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 6);

        const trendData = await this.getAttendanceTrendData(sevenDaysAgo, classId, studentId);

        // Map results to the 7-day structure
        const days = [];
        for (let i = 6; i >= 0; i--) {
            const date = new Date(today);
            date.setDate(date.getDate() - i);
            const dateKey = date.toISOString().split('T')[0];
            
            const dailyStats = trendData.filter(d => d.date.toISOString().split('T')[0] === dateKey);
            
            const total = dailyStats.reduce((sum, d) => sum + d._count.id, 0);
            const present = dailyStats
                .filter(d => ['PRESENT', 'LATE'].includes(d.status))
                .reduce((sum, d) => sum + d._count.id, 0);

            days.push({
                date: date.toLocaleDateString('en-US', { weekday: 'short' }),
                present,
                total,
                percentage: total > 0 ? parseFloat(((present / total) * 100).toFixed(1)) : 0
            });
        }
        return days;
    }

    async getClassPerformance(classId) {
        const latestExam = await DashboardRepository.getLatestCompletedExam(classId);
        if (!latestExam) {
            return { examName: 'No recent exams', performance: [] };
        }

        const performance = latestExam.examResults.map(r => ({
            name: r.student.admissionNumber,
            score: r.percentage
        }));

        return { examName: latestExam.name, performance };
    }

    async getStudentPerformance(studentId) {
        const latestResult = await DashboardRepository.getLatestStudentResult(studentId);
        if (!latestResult) {
            return { examName: 'No exams yet', marks: [] };
        }

        const marks = latestResult.marks.map(m => ({
            subject: m.subjectName,
            score: m.obtainedMarks,
            total: m.totalMarks
        }));

        return { examName: latestResult.exam.name, marks };
    }

    async getLibraryStats() {
        const [categories, totalBooks, issuedBooks, overdueBooks] = await Promise.all([
            DashboardRepository.getBooksByCategory(),
            DashboardRepository.countBooks(),
            DashboardRepository.countLibraryIssues('ISSUED'),
            DashboardRepository.countLibraryIssues('OVERDUE')
        ]);

        const months = [];
        const today = new Date();
        for (let i = 5; i >= 0; i--) {
            const d = new Date(today.getFullYear(), today.getMonth() - i, 1);
            const start = new Date(d.getFullYear(), d.getMonth(), 1);
            const end = new Date(d.getFullYear(), d.getMonth() + 1, 0);

            const count = await DashboardRepository.countLibraryIssues(null, { start, end });
            months.push({
                month: d.toLocaleString('default', { month: 'short' }),
                count
            });
        }

        return {
            summary: { totalBooks, issuedBooks, overdueBooks, availableBooks: totalBooks - issuedBooks },
            categories: categories.map(c => ({ name: c.category || 'Uncategorized', value: c._count.id })),
            trend: months
        };
    }

    async getHRStats() {
        const [totalTeachers, totalStaff, leaves] = await Promise.all([
            DashboardRepository.countTeachers(),
            DashboardRepository.countStaff(),
            DashboardRepository.getLeaveDistribution()
        ]);

        const trend = [];
        const today = new Date();
        today.setHours(0, 0, 0, 0);

        for (let i = 6; i >= 0; i--) {
            const d = new Date(today);
            d.setDate(d.getDate() - i);
            const nextD = new Date(d);
            nextD.setDate(nextD.getDate() + 1);

            const present = await DashboardRepository.getAttendanceCount({
                date: { gte: d, lt: nextD },
                attendeeType: { in: ['TEACHER', 'STAFF'] },
                status: 'PRESENT'
            });

            trend.push({
                date: d.toLocaleDateString('en-US', { weekday: 'short' }),
                present
            });
        }

        return {
            summary: { totalTeachers, totalStaff, totalEmployees: totalTeachers + totalStaff },
            leaveDistribution: leaves.map(l => ({ name: l.leaveType, value: l._count.id })),
            attendanceTrend: trend
        };
    }

    async getFinanceStats() {
        const today = new Date();
        const months = [];

        for (let i = 5; i >= 0; i--) {
            const d = new Date(today.getFullYear(), today.getMonth() - i, 1);
            const start = new Date(d.getFullYear(), d.getMonth(), 1);
            const end = new Date(d.getFullYear(), d.getMonth() + 1, 0);

            const incomeRes = await DashboardRepository.getFeeSum('COMPLETED', start, end);
            const pendingRes = await DashboardRepository.getFeeSum('PENDING', start, end);

            const income = parseFloat(incomeRes._sum.amount || 0);
            const pending = parseFloat(pendingRes._sum.amount || 0);
            const target = (income + pending) * 0.9; // Target 90% collection

            months.push({
                month: d.toLocaleString('default', { month: 'short' }),
                collected: income,
                pending: pending,
                target
            });
        }

        const modeBreakdown = await DashboardRepository.getFeeModeBreakdown();

        return {
            trend: months,
            modes: modeBreakdown.map(m => ({
                name: m.paymentMode,
                value: parseFloat(m._sum.amount || 0)
            }))
        };
    }

    async getExamStats(classId) {
        const [marks, results] = await Promise.all([
            DashboardRepository.getSubjectAverages(classId),
            DashboardRepository.getRecentExamsAndResults(classId)
        ]);

        return {
            subjectAverages: marks.map(m => ({
                subject: m.subjectName,
                average: parseFloat(m._avg.obtainedMarks || 0).toFixed(1)
            })),
            recentPerformance: results.slice(0, 10).map(r => ({
                student: r.student.admissionNumber,
                percentage: r.percentage,
                exam: r.exam.name
            }))
        };
    }

    async getInventoryStats() {
        const [categories, movements] = await Promise.all([
            DashboardRepository.getInventoryCategories(),
            DashboardRepository.getInventoryMovements()
        ]);

        const stockDistribution = categories.map(c => ({
            name: c.category || 'Other',
            value: Number(c._sum.quantity || 0)
        }));

        const movementData = await Promise.all(movements.map(async m => {
            const name = await DashboardRepository.getInventoryItemName(m.itemId);
            return {
                name: name ? name.name : 'Unknown',
                movements: m._count.id
            };
        }));

        return {
            stockDistribution,
            movementData
        };
    }
}

/**
 * Helper function to get relative time
 */
function getRelativeTime(date) {
    const now = getSchoolDate();
    const diff = now - new Date(date);
    const minutes = Math.floor(diff / 60000);
    const hours = Math.floor(diff / 3600000);
    const days = Math.floor(diff / 86400000);

    if (minutes < 1) return 'Just now';
    if (minutes < 0) return 'Just now'; // Handle minor clock skews
    if (minutes < 60) return `${minutes}m ago`;
    if (hours < 24) return `${hours}h ago`;
    return `${days}d ago`;
}

module.exports = new DashboardService();
