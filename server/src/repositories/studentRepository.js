const prisma = require('../config/database');

class StudentRepository {
    /**
     * Find students with filtering and pagination
     */
    async findManyWithFilters(where, skip, take) {
        const students = await prisma.student.findMany({
            where,
            include: {
                user: {
                    select: {
                        id: true,
                        email: true,
                        firstName: true,
                        lastName: true,
                        phone: true,
                        dateOfBirth: true,
                        gender: true,
                        avatar: true,
                    },
                },
                currentClass: { select: { id: true, name: true } },
                section: { select: { id: true, name: true } },
                academicYear: { select: { id: true, name: true } },
            },
            skip,
            take,
            orderBy: { createdAt: 'desc' },
        });

        const total = await prisma.student.count({ where });

        return [students, total];
    }

    /**
     * Find a single student by ID
     */
    async findById(id) {
        return prisma.student.findUnique({
            where: { id },
            // FIXED N+1 QUERY: Fetching all relations in one query
            include: {
                user: true,
                currentClass: true,
                section: true,
                academicYear: true,
                parents: {
                    include: {
                        parent: true,
                    },
                },
                rfidCard: true,
                documents: true,
                transportAllocation: { include: { route: true, stop: true } },
            },
        });
    }

    /**
     * Find a student by admission number
     */
    async findByAdmissionNumber(admissionNumber) {
        return prisma.student.findUnique({
            where: { admissionNumber },
        });
    }

    /**
     * Find a student by User ID
     */
    async findByUserId(userId) {
        return prisma.student.findFirst({
            where: { userId },
            include: {
                user: true,
                currentClass: true,
                section: true,
                academicYear: true,
                parents: {
                    include: {
                        parent: true,
                    },
                },
                rfidCard: true,
                documents: true,
                transportAllocation: { include: { route: true, stop: true } },
            },
        });
    }

    /**
     * Create a basic student
     */
    async create(data) {
        return prisma.student.create({
            data,
            include: {
                user: true,
                currentClass: true,
                section: true,
                academicYear: true,
            },
        });
    }

    /**
     * Update student details
     */
    async update(id, data) {
        return prisma.student.update({
            where: { id },
            data,
            include: {
                user: true,
                currentClass: true,
                section: true,
            },
        });
    }

    /**
     * Get student attendance with date filters
     */
    async getAttendance(studentId, dateFilters) {
        const where = { studentId, ...dateFilters };
        return prisma.attendanceRecord.findMany({
            where,
            orderBy: { date: 'desc' },
        });
    }

    /**
     * Get student count for a specific class and section
     */
    async countByClassAndSection(classId, sectionId) {
        return prisma.student.count({
            where: { currentClassId: classId, sectionId },
        });
    }

    /**
     * Delete student and clean up orphans (Uses transaction context from service)
     */
    async deleteStudentTx(id, tx) {
        const client = this.getClient(tx);

        // Fetch parent IDs before student is deleted
        const studentParents = await client.studentParent.findMany({
            where: { studentId: id },
            select: { parentId: true }
        });

        // Delete the student (Prisma schema handles most cascades including studentParent)
        const deletedStudent = await client.student.delete({
            where: { id }
        });

        // Clean up orphaned parents
        if (studentParents.length > 0) {
            for (const { parentId } of studentParents) {
                const otherChildren = await client.studentParent.count({
                    where: { parentId }
                });

                if (otherChildren === 0) {
                    await client.parent.delete({ where: { id: parentId } });
                    logger.info(`[StudentRepository] Deleted orphaned parent: ${parentId}`);
                }
            }
        }

        return deletedStudent;
    }
}

module.exports = new StudentRepository();
