const payrollRepo = require('../repositories/PayrollRepository');
const { emitEvent } = require('./socketService');
const NotFoundError = require('../errors/NotFoundError');
const ValidationError = require('../errors/ValidationError');

class PayrollService {
    async getSalaryStructures() {
        return payrollRepo.findSalaryStructures();
    }

    async setSalaryStructure(data) {
        const { employeeId, basicSalary, allowances = 0, deductions = 0, effectiveFrom } = data;

        if (!employeeId || basicSalary === undefined) {
            throw new ValidationError('employeeId and basicSalary are required');
        }

        const grossSalary = parseFloat(basicSalary) + parseFloat(allowances) - parseFloat(deductions);

        const result = await payrollRepo.upsertSalaryStructure(employeeId, {
            basicSalary: parseFloat(basicSalary),
            allowances: parseFloat(allowances),
            deductions: parseFloat(deductions),
            grossSalary,
            effectiveFrom: effectiveFrom ? new Date(effectiveFrom) : new Date(),
        });

        emitEvent('PAYROLL_STRUCTURE_UPDATED', result, 'ADMIN');
        return result;
    }

    async generatePayroll(month, year) {
        const m = parseInt(month);
        const y = parseInt(year);

        if (!m || !y || m < 1 || m > 12) {
            throw new ValidationError('Valid month (1-12) and year are required');
        }

        const activeStructures = await payrollRepo.findActiveStructures();
        if (activeStructures.length === 0) {
            throw new ValidationError('No active employees with salary structures found');
        }

        const created = [];
        const skipped = [];

        const startDate = new Date(y, m - 1, 1);
        const endDate = new Date(y, m, 0);
        const daysInMonth = endDate.getDate();

        let workingDaysInMonth = 0;
        for (let d = 1; d <= daysInMonth; d++) {
            const day = new Date(y, m - 1, d).getDay();
            if (day !== 0 && day !== 6) workingDaysInMonth++;
        }

        for (const structure of activeStructures) {
            const existing = await payrollRepo.findPayroll(structure.employeeId, m, y);
            if (existing) {
                skipped.push(structure.employee.id);
                continue;
            }

            const presentRecords = await payrollRepo.countAttendanceRecords({
                attendeeType: { in: ['TEACHER', 'STAFF'] },
                OR: [
                    { teacher: { userId: structure.employeeId } },
                    { staff: { userId: structure.employeeId } }
                ],
                date: { gte: startDate, lte: endDate },
                status: { in: ['PRESENT', 'LATE'] }
            });

            const absentRecords = await payrollRepo.countAttendanceRecords({
                attendeeType: { in: ['TEACHER', 'STAFF'] },
                OR: [
                    { teacher: { userId: structure.employeeId } },
                    { staff: { userId: structure.employeeId } }
                ],
                date: { gte: startDate, lte: endDate },
                status: 'ABSENT'
            });

            const approvedLeaves = await payrollRepo.findApprovedLeaves({
                requesterId: structure.employeeId,
                type: 'LEAVE',
                status: 'APPROVED',
                startDate: { lte: endDate },
                endDate: { gte: startDate }
            });

            let paidLeaveDays = 0;
            approvedLeaves.forEach(leave => {
                const lStart = new Date(Math.max(new Date(leave.startDate).getTime(), startDate.getTime()));
                const lEnd = new Date(Math.min(new Date(leave.endDate).getTime(), endDate.getTime()));
                const diff = Math.round((lEnd - lStart) / (1000 * 60 * 60 * 24)) + 1;
                
                // Check metadata for standardized leave codes or subject for UNPAID keyword
                const leaveType = leave.metadata?.leaveType || '';
                const isPaidType = ['CL', 'SL', 'EL', 'ML'].includes(leaveType);
                const isExplicitlyUnpaid = leave.subject.toUpperCase().includes('UNPAID');

                if (isPaidType || !isExplicitlyUnpaid) {
                    paidLeaveDays += diff;
                }
            });

            const payableDays = Math.min(workingDaysInMonth, presentRecords + paidLeaveDays);
            const unpaidDays = Math.max(0, workingDaysInMonth - payableDays);
            const dailyRate = structure.grossSalary / (workingDaysInMonth || 30);
            const netSalary = Math.round((structure.grossSalary - (unpaidDays * dailyRate)) * 100) / 100;

            const payroll = await payrollRepo.createPayroll({
                structureId: structure.id,
                employeeId: structure.employeeId,
                month: m,
                year: y,
                presentDays: presentRecords,
                absentDays: absentRecords + unpaidDays - absentRecords,
                basicSalary: structure.basicSalary,
                allowances: structure.allowances,
                deductions: structure.deductions,
                netSalary: netSalary,
                status: 'PENDING',
                remarks: `Auto-generated. Payable Days: ${payableDays} (Present: ${presentRecords}, Paid Leave: ${paidLeaveDays})`
            });
            created.push(payroll.id);
        }

        const result = { created: created.length, skipped: skipped.length };
        emitEvent('PAYROLL_GENERATED', result, 'ADMIN');
        return result;
    }

    async getPayrollList(month, year) {
        const m = parseInt(month);
        const y = parseInt(year);
        const payrolls = await payrollRepo.findPayrollsByMonth(m, y);

        const summary = {
            total: payrolls.length,
            paid: payrolls.filter((p) => p.status === 'PAID').length,
            pending: payrolls.filter((p) => p.status === 'PENDING').length,
            totalAmount: payrolls.reduce((sum, p) => sum + p.netSalary, 0),
            paidAmount: payrolls.filter((p) => p.status === 'PAID').reduce((sum, p) => sum + p.netSalary, 0),
        };

        return { payrolls, summary };
    }

    async markPaid(id, remarks, userId) {
        const payroll = await payrollRepo.findPayrollById(id);
        if (!payroll) throw new NotFoundError('Payroll record not found');
        if (payroll.status === 'PAID') throw new ValidationError('Payroll already marked as paid');

        const result = await payrollRepo.updatePayroll(id, {
            status: 'PAID',
            paidAt: new Date(),
            paidBy: userId,
            remarks: remarks || null,
        });

        emitEvent('PAYROLL_PAID', result, 'ADMIN');
        emitEvent('PAYROLL_PAID', result, 'STUDENT', result.employeeId); // "STUDENT" room is used for personal notifications for now
        return result;
    }

    async updatePayrollDays(id, daysData) {
        const { presentDays, absentDays, remarks } = daysData;
        const payroll = await payrollRepo.findPayrollById(id);
        if (!payroll) throw new NotFoundError('Payroll record not found');

        const pDays = presentDays !== undefined ? parseInt(presentDays) : payroll.presentDays;
        const aDays = absentDays !== undefined ? parseInt(absentDays) : payroll.absentDays;
        const totalDays = pDays + aDays;
        let netSalary = payroll.netSalary;

        if (totalDays > 0) {
            const daysInMonth = new Date(payroll.year, payroll.month, 0).getDate();
            let weekdays = 0;
            for (let d = 1; d <= daysInMonth; d++) {
                const day = new Date(payroll.year, payroll.month - 1, d).getDay();
                if (day !== 0 && day !== 6) weekdays++;
            }
            const workingDays = weekdays || 26;
            const dailyRate = payroll.structure.grossSalary / workingDays;
            netSalary = Math.round(dailyRate * pDays * 100) / 100;
        }

        const result = await payrollRepo.updatePayroll(id, {
            presentDays: pDays,
            absentDays: aDays,
            netSalary,
            remarks: remarks !== undefined ? remarks : payroll.remarks,
        });

        emitEvent('PAYROLL_UPDATED', result, 'ADMIN');
        return result;
    }

    async getMyPayroll(userId) {
        return payrollRepo.findMyPayrolls(userId);
    }
}

module.exports = new PayrollService();
