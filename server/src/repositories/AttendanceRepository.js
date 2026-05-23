const prisma = require('../config/database');
const { ROLES } = require('../constants');

/**
 * Repository for Attendance related database operations
 */
class AttendanceRepository {
    async findAttendance(entityId, date, attendeeType, subjectId = null) {
        const where = { date, attendeeType };
        if (attendeeType === ROLES.STUDENT) where.studentId = entityId;
        else if (attendeeType === ROLES.TEACHER) where.teacherId = entityId;
        else if (attendeeType === ROLES.STAFF) where.staffId = entityId;

        if (subjectId) where.subjectId = subjectId;

        return prisma.attendanceRecord.findFirst({ where });
    }

    async createAttendance(data) {
        return prisma.attendanceRecord.create({
            data,
            include: {
                student: {
                    include: {
                        user: { select: { firstName: true, lastName: true } }
                    }
                }
            }
        });
    }

    async updateAttendance(id, data) {
        return prisma.attendanceRecord.update({
            where: { id },
            data
        });
    }

    async findActiveStudents(where) {
        return prisma.student.findMany({
            where: { ...where, status: 'ACTIVE' },
            include: {
                user: { select: { id: true, firstName: true, lastName: true } },
                currentClass: { select: { id: true, name: true } },
                section: { select: { id: true, name: true } }
            }
        });
    }

    async findAttendanceRecords(where, options = {}) {
        return prisma.attendanceRecord.findMany({ 
            where,
            ...options 
        });
    }

    async findRFIDCard(cardNumber) {
        return prisma.rFIDCard.findUnique({
            where: { cardNumber },
            include: {
                student: {
                    include: {
                        user: true,
                        currentClass: true,
                        section: true
                    }
                }
            }
        });
    }

    async findAttendanceSlot(where) {
        return prisma.attendanceSlot.findFirst({ where });
    }

    async findAttendanceSlotById(id) {
        return prisma.attendanceSlot.findUnique({
            where: { id },
            include: {
                class: true,
                section: true,
                subject: true,
                records: true,
                _count: { select: { records: true } }
            }
        });
    }

    async findAttendanceSlots(where) {
        return prisma.attendanceSlot.findMany({
            where,
            include: {
                class: true,
                section: true,
                subject: true,
                _count: { select: { records: true } }
            },
            orderBy: { createdAt: 'desc' }
        });
    }

    async createAttendanceSlot(data) {
        return prisma.attendanceSlot.create({
            data,
            include: { class: true, section: true, subject: true }
        });
    }

    async upsertAttendanceSlot(data) {
        const { date, attendeeType, classId, sectionId, subjectId } = data;
        
        return prisma.$transaction(async (tx) => {
            const existing = await tx.attendanceSlot.findFirst({
                where: {
                    date,
                    attendeeType,
                    classId: classId || null,
                    sectionId: sectionId || null,
                    subjectId: subjectId || null
                }
            });

            if (existing) return existing;

            return tx.attendanceSlot.create({
                data,
                include: { class: true, section: true, subject: true }
            });
        });
    }

    async deleteAttendanceSlot(id) {
        return prisma.attendanceSlot.delete({ where: { id } });
    }

    async findStudentsForSlot(classId, sectionId) {
        const where = { currentClassId: classId, status: 'ACTIVE' };
        if (sectionId) where.sectionId = sectionId;

        return prisma.student.findMany({
            where,
            include: {
                user: { select: { firstName: true, lastName: true } },
                section: { select: { id: true, name: true } }
            },
            orderBy: { admissionNumber: 'asc' }
        });
    }

    async findTeachersForSlot() {
        return prisma.teacher.findMany({
            where: { status: 'ACTIVE' },
            include: { user: { select: { firstName: true, lastName: true } } },
            orderBy: { employeeId: 'asc' }
        });
    }

    async findStaffForSlot() {
        return prisma.staff.findMany({
            where: { status: 'ACTIVE' },
            include: { user: { select: { firstName: true, lastName: true } } },
            orderBy: { employeeId: 'asc' }
        });
    }

    async deleteRecordsBySlot(slotId) {
        return prisma.attendanceRecord.deleteMany({ where: { slotId } });
    }

    async createManyRecords(data) {
        return prisma.attendanceRecord.createMany({ data });
    }

    async updateSlot(id, data) {
        return prisma.attendanceSlot.update({ where: { id }, data });
    }

    async deleteAttendanceRecords(where) {
        return prisma.attendanceRecord.deleteMany({ where });
    }

    async findTeacherByUserId(userId) {
        return prisma.teacher.findUnique({ where: { userId } });
    }

    async findStaffByUserId(userId) {
        return prisma.staff.findUnique({ where: { userId } });
    }

    async findUserById(id) {
        return prisma.user.findUnique({
            where: { id },
            select: {
                id: true, firstName: true, lastName: true, role: true, roles: true, avatar: true, isActive: true,
                student: { select: { id: true, currentClassId: true, sectionId: true } },
                teacher: { select: { id: true, assignedScannerId: true } },
                staff: { select: { id: true, assignedScannerId: true } },
            }
        });
    }

    async findScannerById(id) {
        return prisma.qRScanner.findUnique({ where: { id } });
    }

    async executeTransaction(callback) {
        return prisma.$transaction(callback);
    }
}

module.exports = new AttendanceRepository();
