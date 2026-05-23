const prisma = require('../config/database');

/**
 * Repository for Library related database operations
 */
class LibraryRepository {
    async findBooks(where, skip, take) {
        return prisma.book.findMany({
            where,
            skip,
            take,
            orderBy: { createdAt: 'desc' },
            include: {
                _count: {
                    select: { 
                        issues: { where: { status: 'ISSUED' } }, 
                        reservations: { where: { status: 'PENDING' } } 
                    }
                }
            }
        });
    }

    async countBooks(where) {
        return prisma.book.count({ where });
    }

    async findBookById(id) {
        return prisma.book.findUnique({
            where: { id },
            include: {
                issues: {
                    include: {
                        student: {
                            include: {
                                user: {
                                    select: { firstName: true, lastName: true },
                                },
                            },
                        },
                    },
                    orderBy: { issueDate: 'desc' },
                    take: 20,
                },
                reservations: {
                    where: { status: 'PENDING' },
                    include: {
                        student: {
                            include: { user: { select: { firstName: true, lastName: true } } }
                        },
                        teacher: {
                            include: { user: { select: { firstName: true, lastName: true } } }
                        }
                    },
                    orderBy: { reservationDate: 'asc' }
                }
            },
        });
    }

    async findBookByIsbn(isbn) {
        return prisma.book.findUnique({ where: { isbn } });
    }

    async createBook(data) {
        return prisma.book.create({ data });
    }

    async updateBook(id, data) {
        return prisma.book.update({
            where: { id },
            data,
        });
    }

    async findStudentByAdmissionNumber(admissionNumber) {
        return prisma.student.findUnique({
            where: { admissionNumber }
        });
    }

    async findStudentById(id) {
        return prisma.student.findUnique({
            where: { id }
        });
    }

    async findTeacherByEmployeeId(employeeId) {
        return prisma.teacher.findUnique({
            where: { employeeId }
        });
    }

    async findTeacherById(id) {
        return prisma.teacher.findUnique({
            where: { id }
        });
    }

    async countActiveIssues(studentId) {
        return prisma.libraryIssue.count({
            where: { studentId, status: 'ISSUED' },
        });
    }

    async createIssue(data) {
        return prisma.libraryIssue.create({ data });
    }

    async findIssueById(id) {
        return prisma.libraryIssue.findUnique({
            where: { id },
            include: { book: true },
        });
    }

    async updateIssue(id, data) {
        return prisma.libraryIssue.update({
            where: { id },
            data,
        });
    }

    async createReservation(data) {
        return prisma.libraryReservation.create({ data });
    }

    async findIssues(where, skip, take) {
        return prisma.libraryIssue.findMany({
            where,
            include: {
                book: { select: { title: true, author: true, isbn: true } },
                student: {
                    include: { 
                        user: { select: { firstName: true, lastName: true } },
                        currentClass: { select: { name: true } }
                    }
                },
            },
            skip,
            take,
            orderBy: { issueDate: 'desc' },
        });
    }

    async countIssues(where) {
        return prisma.libraryIssue.count({ where });
    }

    async findOverdueIssues(now) {
        return prisma.libraryIssue.findMany({
            where: {
                status: { in: ['ISSUED', 'OVERDUE'] },
                dueDate: { lt: now },
            },
            include: {
                book: { select: { title: true, author: true, isbn: true } },
                student: {
                    include: { user: { select: { firstName: true, lastName: true, email: true, phone: true } } }
                },
            },
            orderBy: { dueDate: 'asc' },
        });
    }

    async findReservations(where) {
        return prisma.libraryReservation.findMany({
            where,
            include: {
                book: true,
                student: { include: { user: true } },
                teacher: { include: { user: true } }
            },
            orderBy: { reservationDate: 'asc' }
        });
    }

    async executeTransaction(callback) {
        return prisma.$transaction(callback);
    }
}

module.exports = new LibraryRepository();
