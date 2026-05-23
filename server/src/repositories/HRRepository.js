const prisma = require('../config/database');

/**
 * Repository for HR / Employee related database operations
 */
class HRRepository {
    async findEmployees(where, skip, take, orderBy, select) {
        return prisma.user.findMany({
            where,
            skip,
            take,
            orderBy,
            select
        });
    }

    async countEmployees(where) {
        return prisma.user.count({ where });
    }

    async findEmployeeById(id, include) {
        return prisma.user.findUnique({
            where: { id },
            include
        });
    }

    async findUserByEmail(email) {
        return prisma.user.findUnique({ where: { email } });
    }

    async countUsersByRoles(roles) {
        return prisma.user.count({
            where: { role: { in: roles } },
        });
    }

    async findTeacherByEmployeeId(employeeId) {
        return prisma.teacher.findUnique({ where: { employeeId } });
    }

    async findStaffByEmployeeId(employeeId) {
        return prisma.staff.findUnique({ where: { employeeId } });
    }

    async createTeacher(teacherData) {
        return prisma.teacher.create({
            data: teacherData,
            include: { user: true }
        });
    }

    async createStaff(staffData) {
        return prisma.staff.create({
            data: staffData,
            include: { user: true }
        });
    }

    async updateUser(id, data) {
        return prisma.user.update({ where: { id }, data });
    }

    async updateTeacher(id, data) {
        return prisma.teacher.update({ where: { id }, data });
    }

    async updateStaff(id, data) {
        return prisma.staff.update({ where: { id }, data });
    }

    async findCurrentAcademicYear() {
        return prisma.academicYear.findFirst({ where: { isCurrent: true } });
    }

    async createLeaveBalance(data) {
        return prisma.leaveBalance.create({ data });
    }

    async executeTransaction(callback) {
        return prisma.$transaction(callback);
    }
}

module.exports = new HRRepository();
