const prisma = require('../config/database');

/**
 * Repository for Payroll related database operations
 */
class PayrollRepository {
    async findSalaryStructures() {
        return prisma.salaryStructure.findMany({
            include: {
                employee: {
                    select: { id: true, firstName: true, lastName: true, role: true, isActive: true },
                },
            },
            orderBy: { createdAt: 'desc' },
        });
    }

    async upsertSalaryStructure(employeeId, data) {
        return prisma.salaryStructure.upsert({
            where: { employeeId },
            create: { employeeId, ...data },
            update: data,
            include: {
                employee: { select: { id: true, firstName: true, lastName: true } },
            },
        });
    }

    async findActiveStructures() {
        return prisma.salaryStructure.findMany({
            include: {
                employee: { select: { id: true, isActive: true, firstName: true, lastName: true, userId: true } },
            },
            where: {
                employee: { isActive: true }
            }
        });
    }

    async findPayroll(employeeId, month, year) {
        return prisma.payroll.findUnique({
            where: {
                employeeId_month_year: {
                    employeeId,
                    month,
                    year,
                },
            },
        });
    }

    async createPayroll(data) {
        return prisma.payroll.create({ data });
    }

    async findPayrollsByMonth(month, year) {
        return prisma.payroll.findMany({
            where: { month, year },
            include: {
                employee: {
                    select: {
                        id: true, firstName: true, lastName: true, role: true, roles: true,
                        teacher: { select: { employeeId: true, specialization: true } },
                        staff: { select: { employeeId: true, designation: true } },
                    },
                },
            },
            orderBy: { employee: { firstName: 'asc' } },
        });
    }

    async findPayrollById(id) {
        return prisma.payroll.findUnique({
            where: { id },
            include: { structure: true },
        });
    }

    async updatePayroll(id, data) {
        return prisma.payroll.update({
            where: { id },
            data,
            include: {
                employee: { select: { id: true, firstName: true, lastName: true } },
            },
        });
    }

    async findMyPayrolls(employeeId) {
        return prisma.payroll.findMany({
            where: { employeeId },
            orderBy: [{ year: 'desc' }, { month: 'desc' }],
        });
    }

    async countAttendanceRecords(where) {
        return prisma.attendanceRecord.count({ where });
    }

    async findApprovedLeaves(where) {
        return prisma.serviceRequest.findMany({ where });
    }

    async executeTransaction(callback) {
        return prisma.$transaction(callback);
    }
}

module.exports = new PayrollRepository();
