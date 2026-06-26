const HRRepository = require('../repositories/HRRepository');
const bcrypt = require('bcrypt');
const { getConfigValue } = require('../utils/configHelper');
const AppError = require('../utils/AppError');
const logger = require('../config/logger');

/**
 * Service for HR / Employee related business logic
 */
class HRService {
    async getEmployees(query) {
        const { search, status, type, page = 1, limit = 25 } = query;
        const skip = (parseInt(page) - 1) * parseInt(limit);

        const HR_EMPLOYEE_ROLES = ['TEACHER', 'LIBRARIAN', 'ACCOUNTANT', 'ADMIN', 'SUPER_ADMIN', 'HR_MANAGER'];

        const roleCondition = {
            OR: [
                { role: { in: HR_EMPLOYEE_ROLES } },
                { roles: { hasSome: HR_EMPLOYEE_ROLES } },
            ],
        };

        const conditions = [roleCondition];

        if (status === 'ACTIVE') conditions.push({ isActive: true });
        if (status === 'INACTIVE') conditions.push({ isActive: false });

        if (search) {
            conditions.push({
                OR: [
                    { firstName: { contains: search, mode: 'insensitive' } },
                    { lastName: { contains: search, mode: 'insensitive' } },
                    { email: { contains: search, mode: 'insensitive' } },
                    { teacher: { employeeId: { contains: search, mode: 'insensitive' } } },
                    { staff: { employeeId: { contains: search, mode: 'insensitive' } } },
                ],
            });
        }

        if (type === 'TEACHER') {
            conditions.push({
                OR: [{ role: 'TEACHER' }, { roles: { has: 'TEACHER' } }],
            });
        } else if (type === 'STAFF') {
            const staffRoles = ['LIBRARIAN', 'ACCOUNTANT', 'ADMIN', 'SUPER_ADMIN', 'HR_MANAGER', 'RECEPTIONIST', 'SECURITY', 'MAINTENANCE'];
            conditions.push({
                AND: [
                    { teacher: null },
                    {
                        OR: [
                            { role: { in: staffRoles } },
                            { roles: { hasSome: staffRoles } },
                        ],
                    },
                ],
            });
        }

        const where = { AND: conditions };
        const select = {
            id: true,
            email: true,
            firstName: true,
            lastName: true,
            phone: true,
            role: true,
            roles: true,
            isActive: true,
            createdAt: true,
            staff: {
                select: {
                    id: true,
                    employeeId: true,
                    joiningDate: true,
                    designation: true,
                    department: true,
                    status: true,
                    assignedScanner: { select: { id: true, name: true } },
                },
            },
            teacher: {
                select: {
                    id: true,
                    employeeId: true,
                    joiningDate: true,
                    qualification: true,
                    specialization: true,
                    experience: true,
                    status: true,
                    assignedScanner: { select: { id: true, name: true } },
                },
            },
            salaryStructure: {
                select: { basicSalary: true, grossSalary: true },
            },
        };

        const [users, total] = await Promise.all([
            HRRepository.findEmployees(where, skip, parseInt(limit), { createdAt: 'desc' }, select),
            HRRepository.countEmployees(where),
        ]);

        return {
            employees: users,
            pagination: {
                total,
                page: parseInt(page),
                limit: parseInt(limit),
                totalPages: Math.ceil(total / parseInt(limit)),
            },
        };
    }

    async getEmployee(id) {
        const include = {
            teacher: { include: { subjects: { include: { subject: true } }, assignedClass: true, assignedScanner: true } },
            staff: { include: { assignedScanner: true } },
            salaryStructure: true,
            payrolls: { orderBy: [{ year: 'desc' }, { month: 'desc' }], take: 12 },
        };

        const user = await HRRepository.findEmployeeById(id, include);
        if (!user) throw new AppError('Employee not found', 404);
        return { employee: user };
    }

    async createEmployee(data) {
        const {
            firstName, lastName, email, password, phone, gender, address, dateOfBirth,
            role = 'TEACHER',
            qualification, experience, specialization,
            joiningDate,
            designation, department,
            assignedScannerId,
        } = data;

        if (!firstName || !email || !password) {
            throw new AppError('firstName, email, and password are required', 400);
        }

        const existing = await HRRepository.findUserByEmail(email);
        if (existing) throw new AppError('Email already exists', 400);

        const hashedPassword = await bcrypt.hash(password, 10);
        const employeeId = await this.generateEmployeeId();
        const joinDate = joiningDate ? new Date(joiningDate) : new Date();

        return await HRRepository.executeTransaction(async (tx) => {
            let result;

            if (role === 'TEACHER') {
                const teacherData = {
                    employeeId,
                    joiningDate: joinDate,
                    qualification: qualification || '',
                    experience: experience ? parseInt(experience) : null,
                    specialization: specialization || null,
                    assignedScannerId: assignedScannerId || null,
                    user: {
                        create: {
                            email, password: hashedPassword, firstName, lastName,
                            phone: phone || null, gender: gender || null,
                            address: address || null,
                            dateOfBirth: dateOfBirth ? new Date(dateOfBirth) : null,
                            role: 'TEACHER', roles: ['TEACHER'],
                        },
                    },
                };
                result = await tx.teacher.create({ 
                    data: teacherData,
                    include: { user: true }
                });
            } else {
                const staffData = {
                    employeeId,
                    joiningDate: joinDate,
                    designation: designation || role,
                    department: department || null,
                    assignedScannerId: assignedScannerId || null,
                    user: {
                        create: {
                            email, password: hashedPassword, firstName, lastName,
                            phone: phone || null, gender: gender || null,
                            address: address || null,
                            dateOfBirth: dateOfBirth ? new Date(dateOfBirth) : null,
                            role, roles: [role],
                        },
                    },
                };
                result = await tx.staff.create({
                    data: staffData,
                    include: { user: true }
                });
            }

            // Initialize leave balances within the SAME TRANSACTION
            const currentYear = await tx.academicYear.findFirst({ where: { isCurrent: true } });
            if (currentYear) {
                const userId = result.user ? result.user.id : result.userId;
                
                const clTotal = await getConfigValue('default_cl_quota', 12);
                const slTotal = await getConfigValue('default_sl_quota', 10);
                const elTotal = await getConfigValue('default_el_quota', 15);

                const defaultQuotas = [
                    { type: 'CL', total: parseInt(clTotal) },
                    { type: 'SL', total: parseInt(slTotal) },
                    { type: 'EL', total: parseInt(elTotal) },
                ];

                await Promise.all(
                    defaultQuotas.map(q =>
                        tx.leaveBalance.create({
                            data: {
                                employeeId: userId,
                                leaveType: q.type,
                                academicYearId: currentYear.id,
                                total: q.total
                            }
                        })
                    )
                );
            }

            return result;
        });
    }

    async updateEmployee(id, data) {
        const { firstName, lastName, phone, gender, address,
            qualification, specialization, experience,
            designation, department, status,
            assignedScannerId } = data;

        const user = await HRRepository.findEmployeeById(id, { teacher: true, staff: true });
        if (!user) throw new AppError('Employee not found', 404);

        const userUpdate = {};
        if (firstName !== undefined) userUpdate.firstName = firstName;
        if (lastName !== undefined) userUpdate.lastName = lastName;
        if (phone !== undefined) userUpdate.phone = phone;
        if (gender !== undefined) userUpdate.gender = gender;
        if (address !== undefined) userUpdate.address = address;

        if (Object.keys(userUpdate).length > 0) {
            await HRRepository.updateUser(id, userUpdate);
        }

        if (user.teacher) {
            const teacherUpdate = {};
            if (qualification !== undefined) teacherUpdate.qualification = qualification;
            if (specialization !== undefined) teacherUpdate.specialization = specialization;
            if (experience !== undefined) teacherUpdate.experience = parseInt(experience);
            if (status !== undefined) teacherUpdate.status = status;
            if (assignedScannerId !== undefined) teacherUpdate.assignedScannerId = assignedScannerId || null;
            if (Object.keys(teacherUpdate).length > 0) {
                await HRRepository.updateTeacher(user.teacher.id, teacherUpdate);
            }
        }

        if (user.staff) {
            const staffUpdate = {};
            if (designation !== undefined) staffUpdate.designation = designation;
            if (department !== undefined) staffUpdate.department = department;
            if (status !== undefined) staffUpdate.status = status;
            if (assignedScannerId !== undefined) staffUpdate.assignedScannerId = assignedScannerId || null;
            if (Object.keys(staffUpdate).length > 0) {
                await HRRepository.updateStaff(user.staff.id, staffUpdate);
            }
        }

        return await HRRepository.findEmployeeById(id, { teacher: true, staff: true });
    }

    async toggleEmployeeStatus(id, data) {
        const { isActive, status } = data;

        const user = await HRRepository.findEmployeeById(id, { teacher: true, staff: true });
        if (!user) throw new AppError('Employee not found', 404);

        const newActive = typeof isActive === 'boolean' ? isActive : !user.isActive;
        await HRRepository.updateUser(id, { isActive: newActive });

        const employeeStatus = status || (newActive ? 'ACTIVE' : 'RESIGNED');

        if (user.teacher) {
            await HRRepository.updateTeacher(user.teacher.id, { status: employeeStatus });
        }
        if (user.staff) {
            await HRRepository.updateStaff(user.staff.id, { status: employeeStatus });
        }

        return { activated: newActive };
    }

    async generateEmployeeId(maxRetries = 5) {
        const HR_EMPLOYEE_ROLES = ['TEACHER', 'LIBRARIAN', 'ACCOUNTANT', 'ADMIN', 'SUPER_ADMIN', 'HR_MANAGER'];
        
        for (let attempt = 0; attempt < maxRetries; attempt++) {
            const count = await HRRepository.countUsersByRoles(HR_EMPLOYEE_ROLES);
            const suffix = attempt > 0 ? Math.floor(Math.random() * 100) : 0;
            const id = `EMP${String(count + 1 + suffix).padStart(5, '0')}`;

            const existsInTeacher = await HRRepository.findTeacherByEmployeeId(id);
            const existsInStaff = await HRRepository.findStaffByEmployeeId(id);
            if (!existsInTeacher && !existsInStaff) return id;
        }
        return `EMP${Date.now().toString(36).toUpperCase()}`;
    }
}

module.exports = new HRService();
