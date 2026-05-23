const bcrypt = require('bcrypt');
const studentRepo = require('../repositories/studentRepository');
const prisma = require('../config/database');
const NotFoundError = require('../errors/NotFoundError');
const ValidationError = require('../errors/ValidationError');

class StudentService {
    /**
     * Get paginated and filtered students
     */
    async getStudents(filters, userContext) {
        const { classId, sectionId, status, search, page = 1, limit = 25 } = filters;

        const where = {};
        
        // Role-based filtering for teachers
        if (userContext && userContext.role === 'TEACHER') {
            const teacher = await prisma.teacher.findUnique({
                where: { userId: userContext.userId },
                include: {
                    subjects: {
                        include: { subject: true }
                    }
                }
            });

            if (teacher) {
                const assignedClassIds = new Set();
                
                // 1. Classes where they are the Class Teacher
                const classTeacherClasses = await prisma.class.findMany({
                    where: { classTeacherId: teacher.id },
                    select: { id: true }
                });
                classTeacherClasses.forEach(c => assignedClassIds.add(c.id));

                // 2. Classes where they teach a subject
                teacher.subjects.forEach(st => {
                    if (st.subject && st.subject.classId) {
                        assignedClassIds.add(st.subject.classId);
                    }
                });

                const assignedClassIdsArray = Array.from(assignedClassIds);

                // If a specific classId is requested, ensure it's in assignments
                if (classId) {
                    if (assignedClassIds.has(classId)) {
                        where.currentClassId = classId;
                    } else {
                        // Forbidden class requested - force empty result
                        where.currentClassId = 'none';
                    }
                } else {
                    // Default to all assigned classes
                    if (assignedClassIdsArray.length === 0) {
                        where.currentClassId = 'none';
                    } else {
                        where.currentClassId = { in: assignedClassIdsArray };
                    }
                }
            } else {
                where.currentClassId = 'none';
            }
        } else {
            // Admin/Other roles can filter freely
            if (classId) where.currentClassId = classId;
        }

        if (sectionId) where.sectionId = sectionId;
        if (status) where.status = status;

        if (search) {
            where.OR = [
                { user: { firstName: { contains: search, mode: 'insensitive' } } },
                { user: { lastName: { contains: search, mode: 'insensitive' } } },
                { user: { email: { contains: search, mode: 'insensitive' } } },
                { admissionNumber: { contains: search, mode: 'insensitive' } },
            ];
        }

        const skip = (parseInt(page) - 1) * parseInt(limit);

        // Repository call
        const [students, total] = await studentRepo.findManyWithFilters(where, skip, parseInt(limit));

        return {
            students,
            pagination: {
                total,
                page: parseInt(page),
                limit: parseInt(limit),
                totalPages: Math.ceil(total / parseInt(limit)),
            },
        };
    }

    /**
     * Get single student by ID
     */
    async getStudentById(id) {
        const student = await studentRepo.findById(id);
        if (!student) {
            throw new NotFoundError('Student not found');
        }
        return student;
    }

    /**
     * Create basic student
     */
    async createStudent(data) {
        // 1. Business Logic: Check if admission number exists
        const existingStudent = await studentRepo.findByAdmissionNumber(data.admissionNumber);
        if (existingStudent) {
            throw new ValidationError('Admission number already exists');
        }

        // 2. Hash password
        const hashedPassword = await bcrypt.hash(data.password, 10);

        // 3. Format data for repository creation
        const studentData = {
            admissionNumber: data.admissionNumber,
            rollNumber: data.rollNumber,
            currentClassId: data.currentClassId,
            sectionId: data.sectionId,
            academicYearId: data.academicYearId,
            joiningDate: data.joiningDate ? new Date(data.joiningDate) : new Date(),
            emergencyContact: data.emergencyContact,
            emergencyPhone: data.emergencyPhone,
            medicalConditions: data.medicalConditions,
            allergies: data.allergies,
            user: {
                create: {
                    email: data.email,
                    password: hashedPassword,
                    firstName: data.firstName,
                    lastName: data.lastName,
                    phone: data.phone,
                    dateOfBirth: data.dateOfBirth ? new Date(data.dateOfBirth) : null,
                    gender: data.gender,
                    bloodGroup: data.bloodGroup,
                    address: data.address,
                    role: 'STUDENT',
                    roles: ['STUDENT'], // Ensure role restriction
                },
            },
        };

        return studentRepo.create(studentData);
    }

    /**
     * Update existing student
     */
    async updateStudent(id, updates) {
        const student = await studentRepo.findById(id);
        if (!student) {
            throw new NotFoundError('Student not found');
        }

        // Separate user updates from student updates
        const userUpdates = {};
        const studentUpdates = {};

        const userFields = ['firstName', 'lastName', 'phone', 'dateOfBirth', 'gender', 'bloodGroup', 'address'];
        const studentFields = ['rollNumber', 'currentClassId', 'sectionId', 'emergencyContact', 'emergencyPhone', 'medicalConditions', 'allergies', 'status'];

        Object.keys(updates).forEach((key) => {
            if (userFields.includes(key)) {
                userUpdates[key] = updates[key];
            } else if (studentFields.includes(key)) {
                studentUpdates[key] = updates[key];
            }
        });

        const updateData = {
            ...studentUpdates,
            ...(Object.keys(userUpdates).length > 0 && {
                user: {
                    update: userUpdates,
                },
            }),
        };

        return studentRepo.update(id, updateData);
    }

    /**
     * Delete (Soft-Delete) student
     */
    async deleteStudent(id) {
        const student = await studentRepo.findById(id);
        if (!student) {
            throw new NotFoundError('Student not found');
        }

        const updateData = {
            status: 'INACTIVE',
            user: {
                update: {
                    isActive: false,
                },
            },
        };

        return studentRepo.update(id, updateData);
    }

    /**
     * Get student attendance stats
     */
    async getStudentAttendance(id, startDate, endDate) {
        // 1. Ensure student exists
        await this.getStudentById(id);

        // 2. Build date filters
        const dateFilters = {};
        if (startDate || endDate) {
            dateFilters.date = {};
            if (startDate) dateFilters.date.gte = new Date(startDate);
            if (endDate) dateFilters.date.lte = new Date(endDate);
        }

        const attendance = await studentRepo.getAttendance(id, dateFilters);

        // Fetch User details for the 'markedBy' field to show who took attendance
        const markerIds = [...new Set(attendance.map(a => a.markedBy).filter(Boolean))];
        let markerMap = new Map();
        if (markerIds.length > 0) {
            const markers = await prisma.user.findMany({
                where: { id: { in: markerIds } },
                select: { id: true, firstName: true, lastName: true }
            });
            markers.forEach(m => markerMap.set(m.id, `${m.firstName} ${m.lastName}`));
        }

        const enrichedAttendance = attendance.map(a => ({
            ...a,
            markedByName: a.markedBy ? markerMap.get(a.markedBy) || 'System' : 'System'
        }));

        // 3. Business logic: Calculate statistics
        const stats = {
            total: enrichedAttendance.length,
            present: enrichedAttendance.filter((a) => a.status === 'PRESENT').length,
            absent: enrichedAttendance.filter((a) => a.status === 'ABSENT').length,
            late: enrichedAttendance.filter((a) => a.status === 'LATE').length,
            halfDay: enrichedAttendance.filter((a) => a.status === 'HALF_DAY').length,
        };

        stats.percentage = stats.total > 0 ? Number((((stats.present + stats.late) / stats.total) * 100).toFixed(2)) : 0;

        // 4. Calculate Streak (Presence Streak)
        let currentStreak = 0;
        const sortedAttendance = [...enrichedAttendance].sort((a, b) => new Date(b.date) - new Date(a.date));
        for (const record of sortedAttendance) {
            if (record.status === 'PRESENT' || record.status === 'LATE') {
                currentStreak++;
            } else if (record.status === 'ABSENT') {
                break;
            }
            // Skip other statuses or count them as gaps? Usually only consecutive presence counts.
        }
        stats.currentStreak = currentStreak;

        // 5. Calculate Subject-wise stats
        const subjectWise = {};
        enrichedAttendance.forEach(a => {
            if (a.subjectId) {
                if (!subjectWise[a.subjectId]) {
                    subjectWise[a.subjectId] = {
                        name: a.subject?.name || 'Unknown Subject',
                        total: 0,
                        present: 0,
                        absent: 0,
                        late: 0
                    };
                }
                const s = subjectWise[a.subjectId];
                s.total++;
                if (a.status === 'PRESENT') s.present++;
                else if (a.status === 'ABSENT') s.absent++;
                else if (a.status === 'LATE') s.late++;
                
                s.percentage = s.total > 0 ? (((s.present + s.late) / s.total) * 100).toFixed(1) : 0;
            }
        });

        // 6. Monthly Comparison (Current month vs Last month)
        const now = new Date();
        const firstDayThisMonth = new Date(now.getFullYear(), now.getMonth(), 1);
        const firstDayLastMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);
        const lastDayLastMonth = new Date(now.getFullYear(), now.getMonth(), 0);

        const thisMonthRecords = enrichedAttendance.filter(a => new Date(a.date) >= firstDayThisMonth);
        const lastMonthRecords = enrichedAttendance.filter(a => new Date(a.date) >= firstDayLastMonth && new Date(a.date) <= lastDayLastMonth);

        const calcPct = (recs) => {
            if (recs.length === 0) return 0;
            const p = recs.filter(r => r.status === 'PRESENT' || r.status === 'LATE').length;
            return (p / recs.length) * 100;
        };

        const thisMonthPct = calcPct(thisMonthRecords);
        const lastMonthPct = calcPct(lastMonthRecords);
        
        stats.monthlyDelta = lastMonthPct > 0 ? (thisMonthPct - lastMonthPct).toFixed(1) : thisMonthPct.toFixed(1);

        return { 
            attendance: enrichedAttendance, 
            stats,
            subjectWise: Object.values(subjectWise)
        };
    }

    /**
     * Complex Student Registration Transaction
     */
    async registerStudent(data, reqUser) {
        // 1. Generate Credentials
        const year = new Date().getFullYear();
        const randomSuffix = Math.floor(1000 + Math.random() * 9000);
        const username = `STD${year}${randomSuffix}`;
        const passwordRaw = `PASS${Math.floor(100000 + Math.random() * 900000)}`;
        const hashedPassword = await bcrypt.hash(passwordRaw, 10);

        // 2. Auto-calculate Roll Number
        const studentCount = await studentRepo.countByClassAndSection(data.classId, data.sectionId);
        const rollNumber = (studentCount + 1).toString();

        // 3. Generate Admission Number
        const admissionNumber = `ADM${Date.now()}${Math.floor(100 + Math.random() * 899)}`;

        // Validate essential relations before starting Transaction to fail fast
        const [cls, section, yearRecord] = await Promise.all([
            prisma.class.findUnique({ where: { id: data.classId } }),
            prisma.section.findUnique({ where: { id: data.sectionId } }),
            prisma.academicYear.findUnique({ where: { id: data.academicYearId } })
        ]);

        if (!cls) throw new ValidationError(`Class with ID ${data.classId} not found`);
        if (!section) throw new ValidationError(`Section with ID ${data.sectionId} not found`);
        if (!yearRecord) throw new ValidationError(`Academic Year with ID ${data.academicYearId} not found`);

        // 4. Delegate complex transaction to repository via Prisma transaction
        // Passing the Prisma client instance to ensure everything runs in the same transaction
        const result = await prisma.$transaction(async (tx) => {

            // A. Create/Find Father
            let father = await tx.parent.findUnique({ where: { phone: data.fatherPhone } });
            if (!father) {
                father = await tx.parent.create({
                    data: {
                        firstName: data.fatherName,
                        lastName: '', // Assuming single name field
                        phone: data.fatherPhone,
                        email: data.fatherEmail,
                        occupation: data.fatherOccupation,
                        aadhaar: data.fatherAadhaar,
                        pan: data.fatherPan,
                    }
                });
            }

            // B. Create/Find Mother (Optional)
            let mother = null;
            if (data.motherName && data.motherPhone) {
                mother = await tx.parent.findUnique({ where: { phone: data.motherPhone } });
                if (!mother) {
                    mother = await tx.parent.create({
                        data: {
                            firstName: data.motherName,
                            lastName: '',
                            phone: data.motherPhone,
                            occupation: data.motherOccupation,
                            aadhaar: data.motherAadhaar,
                            pan: data.motherPan,
                        }
                    });
                }
            }

            // C. Create User Login
            const user = await tx.user.create({
                data: {
                    email: data.email || `${username}@school.com`, 
                    username: username,
                    password: hashedPassword,
                    firstName: data.firstName,
                    lastName: data.lastName || '',
                    dateOfBirth: new Date(data.dateOfBirth),
                    gender: data.gender,
                    bloodGroup: data.bloodGroup,
                    address: data.currentAddress,
                    role: 'STUDENT',
                    roles: ['STUDENT'],
                    avatar: data.photo,
                }
            });

            // D. Create Student Record
            const student = await tx.student.create({
                data: {
                    user: { connect: { id: user.id } },
                    admissionNumber,
                    rollNumber,
                    joiningDate: data.admissionDate ? new Date(data.admissionDate) : new Date(),
                    currentClass: { connect: { id: data.classId } },
                    section: { connect: { id: data.sectionId } },
                    academicYear: { connect: { id: data.academicYearId } },

                    // Extended Details
                    admissionType: data.admissionType,
                    medium: data.medium,
                    previousSchool: data.previousSchool,
                    previousClass: data.previousClass,
                    tcNumber: data.tcNumber,
                    tcIssueDate: data.tcIssueDate ? new Date(data.tcIssueDate) : null,
                    leavingReason: data.leavingReason,
                    religion: data.religion,
                    caste: data.caste,
                    nationality: data.nationality,
                    permanentAddress: data.permanentAddress,
                    city: data.city,
                    state: data.state,
                    pincode: data.pincode,

                    // Parents Link
                    parents: {
                        create: [
                            { parentId: father.id, relationship: 'FATHER' },
                            ...(mother && mother.id !== father.id ? [{ parentId: mother.id, relationship: 'MOTHER' }] : [])
                        ]
                    }
                }
            });

            // E. Assign RFID (Optional)
            if (data.rfidCardUid) {
                await tx.rFIDCard.upsert({
                    where: { cardNumber: data.rfidCardUid },
                    update: { studentId: student.id, holderType: 'STUDENT', isActive: true },
                    create: {
                        cardNumber: data.rfidCardUid,
                        studentId: student.id,
                        holderType: 'STUDENT',
                        isActive: true
                    }
                });
            }

            // F. Process Fee Assignment & Initial Payment
            let feePayments = [];
            let remainingInitialPayment = data.initialPayment?.amount || 0;

            if (data.feeStructureIds && data.feeStructureIds.length > 0) {
                const receiptBase = `REC${Date.now()}`;

                for (const structureId of data.feeStructureIds) {
                    const structure = await tx.feeStructure.findUnique({ where: { id: structureId } });
                    if (structure) {
                        const discount = data.feeDiscounts?.[structureId] || 0;
                        const totalPayable = Math.max(structure.totalAmount - discount, 0);

                        // Create ledger with initial totals (totalPaid = 0, pending = totalPayable)
                        const ledger = await tx.studentFeeLedger.create({
                            data: {
                                studentId: student.id,
                                academicYearId: data.academicYearId,
                                feeStructureId: structure.id,
                                totalPayable,
                                totalPaid: 0,
                                totalPending: totalPayable,
                                totalDiscount: discount,
                                status: 'PENDING'
                            }
                        });

                        // Apply a portion of the initial payment if balance remains
                        if (remainingInitialPayment > 0 && totalPayable > 0) {
                            const paymentAmount = Math.min(remainingInitialPayment, totalPayable);
                            const remainingBalanceForLedger = totalPayable - paymentAmount;

                            const payment = await tx.feePayment.create({
                                data: {
                                    receiptNumber: `${receiptBase}-${structureId.slice(0, 4)}-${Math.floor(Math.random() * 1000)}`,
                                    studentId: student.id,
                                    feeStructureId: structureId,
                                    ledgerId: ledger.id,
                                    academicYearId: data.academicYearId,
                                    amount: paymentAmount,
                                    discount: 0,
                                    penalty: 0,
                                    totalAmount: paymentAmount,
                                    paymentType: 'RECEIPT',
                                    paymentMode: data.initialPayment.paymentMode || 'CASH',
                                    transactionId: data.initialPayment.transactionId || null,
                                    status: 'COMPLETED',
                                    collectedBy: reqUser?.userId || null,
                                },
                            });

                            // Update ledger to reflect the payment
                            await tx.studentFeeLedger.update({
                                where: { id: ledger.id },
                                data: {
                                    totalPaid: paymentAmount,
                                    totalPending: remainingBalanceForLedger,
                                    status: remainingBalanceForLedger <= 0 ? 'PAID' : 'PARTIAL'
                                }
                            });

                            feePayments.push(payment);
                            remainingInitialPayment -= paymentAmount;
                        }
                    }
                }
            }

            return { student, user, credentials: { username, password: passwordRaw }, feePayments };
        }, { timeout: 20000 });

        return result;
    }
}

module.exports = new StudentService();
