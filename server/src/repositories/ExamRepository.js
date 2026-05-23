const prisma = require('../config/database');

/**
 * Repository for Exam related database operations
 */
class ExamRepository {
    async findExams(where, skip, take, orderBy, include) {
        return prisma.exam.findMany({
            where,
            skip,
            take,
            orderBy,
            include
        });
    }

    async countExams(where) {
        return prisma.exam.count({ where });
    }

    async findExamById(id, include = {}) {
        return prisma.exam.findUnique({
            where: { id },
            include
        });
    }

    async createExam(data, include = {}) {
        return prisma.exam.create({
            data,
            include
        });
    }

    async updateExam(id, data, include = {}) {
        return prisma.exam.update({
            where: { id },
            data,
            include
        });
    }

    async deleteExam(id) {
        return prisma.exam.delete({ where: { id } });
    }

    async findTeacherByUserId(userId) {
        return prisma.teacher.findUnique({ where: { userId } });
    }

    async findSubjectTeacherAssignments(teacherId) {
        return prisma.subjectTeacher.findMany({
            where: { teacherId },
            include: {
                subject: {
                    include: {
                        class: { select: { id: true, name: true } },
                    },
                },
            },
        });
    }

    async findActiveExamsForClasses(classIds, statusIn) {
        return prisma.exam.findMany({
            where: {
                classId: { in: classIds },
                status: { in: statusIn },
                isFrozen: false,
            },
            include: {
                class: {
                    select: {
                        name: true,
                        _count: { select: { students: true } }
                    }
                },
                examSubjects: {
                    include: { subject: { select: { id: true, name: true, code: true } } },
                },
                examResults: {
                    select: {
                        id: true,
                        marks: { select: { subjectCode: true } }
                    },
                },
            },
            orderBy: { startDate: 'asc' },
        });
    }

    async createExamSubject(data, include = {}) {
        return prisma.examSubject.create({
            data,
            include
        });
    }

    async findExamSubject(examId, subjectId) {
        return prisma.examSubject.findUnique({
            where: { examId_subjectId: { examId, subjectId } },
            include: { subject: true },
        });
    }

    async findGradeScaleById(id) {
        return prisma.gradeScale.findUnique({
            where: { id },
            include: { entries: { orderBy: { order: 'asc' } } }
        });
    }

    async findActiveStudentsByClass(classId) {
        return prisma.student.findMany({
            where: { classId, status: 'ACTIVE' },
            include: {
                user: { select: { firstName: true, lastName: true } },
                section: { select: { name: true } },
            },
            orderBy: { admissionNumber: 'asc' },
        });
    }

    async findActiveStudents(where) {
        return prisma.student.findMany({
            where: { ...where, status: 'ACTIVE' },
            include: {
                user: { select: { id: true, firstName: true, lastName: true } },
                currentClass: { select: { id: true, name: true } },
                section: { select: { id: true, name: true } }
            },
            orderBy: { admissionNumber: 'asc' }
        });
    }

    async upsertExamResult(examId, studentId, createData) {
        return prisma.examResult.upsert({
            where: { examId_studentId: { examId, studentId } },
            create: {
                examId,
                studentId,
                ...createData
            },
            update: {},
        });
    }

    async findExamMarkBySubject(examResultId, subjectCode) {
        return prisma.examMark.findFirst({
            where: { examResultId, subjectCode },
        });
    }

    async updateExamMark(id, data) {
        return prisma.examMark.update({
            where: { id },
            data,
        });
    }

    async createExamMark(data) {
        return prisma.examMark.create({ data });
    }

    async findExamMarks(examResultId) {
        return prisma.examMark.findMany({
            where: { examResultId },
        });
    }

    async updateExamResult(id, data) {
        return prisma.examResult.update({
            where: { id },
            data,
        });
    }

    async findExamResults(where, include, orderBy) {
        return prisma.examResult.findMany({
            where,
            include,
            orderBy
        });
    }

    async findTeacherAssignment(userId, subjectId) {
        return prisma.subjectTeacher.findFirst({
            where: {
                teacher: { userId },
                subjectId,
            },
        });
    }

    async executeTransaction(callback) {
        return prisma.$transaction(callback);
    }
}

module.exports = new ExamRepository();
