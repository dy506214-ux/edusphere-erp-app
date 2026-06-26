const { getSchoolDate, getStartOfDay } = require('../utils/dateUtils');
const libraryRepo = require('../repositories/LibraryRepository');
const { emitEvent } = require('./socketService');
const NotFoundError = require('../errors/NotFoundError');
const ValidationError = require('../errors/ValidationError');
const { getConfigValue } = require('../utils/configHelper');

class LibraryService {
    async getBooks(filters) {
        const { category, type, status, condition, search, page = 1, limit = 25, isActive } = filters;

        const where = {};
        if (category) where.category = category;
        if (type) where.type = type;
        if (status) where.status = status;
        if (condition) where.condition = condition;
        
        if (isActive === 'true') where.isActive = true;
        else if (isActive === 'false') where.isActive = false;

        if (search) {
            where.OR = [
                { title: { contains: search, mode: 'insensitive' } },
                { author: { contains: search, mode: 'insensitive' } },
                { isbn: { contains: search, mode: 'insensitive' } },
                { publisher: { contains: search, mode: 'insensitive' } },
            ];
        }

        const skip = (parseInt(page) - 1) * parseInt(limit);
        const [books, total] = await Promise.all([
            libraryRepo.findBooks(where, skip, parseInt(limit)),
            libraryRepo.countBooks(where)
        ]);

        return {
            books,
            pagination: {
                total,
                page: parseInt(page),
                limit: parseInt(limit),
                totalPages: Math.ceil(total / parseInt(limit)),
            },
        };
    }

    async getBookById(id) {
        const book = await libraryRepo.findBookById(id);
        if (!book) throw new NotFoundError('Book not found');
        return book;
    }

    async createBook(data) {
        const { isbn, totalCopies } = data;

        if (isbn) {
            const existing = await libraryRepo.findBookByIsbn(isbn);
            if (existing) throw new ValidationError('ISBN already exists');
        }

        const copies = parseInt(totalCopies) || 1;
        const book = await libraryRepo.createBook({
            ...data,
            publishedYear: data.publishedYear ? parseInt(data.publishedYear) : null,
            totalCopies: copies,
            availableCopies: copies,
            price: data.price ? parseFloat(data.price) : null,
            status: 'AVAILABLE'
        });

        emitEvent('LIBRARY_BOOK_CREATED', book, 'ADMIN');
        return book;
    }

    async updateBook(id, updates) {
        const book = await libraryRepo.findBookById(id);
        if (!book) throw new NotFoundError('Book not found');

        const allowedUpdates = [
            'title', 'author', 'publisher', 'publishedYear', 'category', 'subCategory',
            'language', 'type', 'condition', 'status', 'price', 'description', 
            'totalCopies', 'shelfLocation', 'isActive'
        ];

        const updateData = {};
        Object.keys(updates).forEach((key) => {
            if (allowedUpdates.includes(key)) {
                if (['publishedYear', 'totalCopies'].includes(key)) {
                    updateData[key] = parseInt(updates[key]);
                } else if (key === 'price') {
                    updateData[key] = parseFloat(updates[key]);
                } else {
                    updateData[key] = updates[key];
                }
            }
        });

        if (updateData.totalCopies !== undefined) {
            const difference = updateData.totalCopies - book.totalCopies;
            updateData.availableCopies = Math.max(0, book.availableCopies + difference);
        }

        const updatedBook = await libraryRepo.updateBook(id, updateData);
        emitEvent('LIBRARY_BOOK_UPDATED', updatedBook, 'ADMIN');
        return updatedBook;
    }

    async issueBook(issueData, issuedBy) {
        const { bookId, studentId, dueDate } = issueData;

        // 1. Find Student
        let student = await libraryRepo.findStudentByAdmissionNumber(studentId) || 
                      await libraryRepo.findStudentById(studentId);
        
        if (!student) throw new NotFoundError('Student not found');

        // 2. Find Book
        const book = await libraryRepo.findBookById(bookId);
        if (!book) throw new NotFoundError('Book not found');
        if (book.availableCopies <= 0 || book.status !== 'AVAILABLE') {
            throw new ValidationError('Book is currently not available for issue');
        }

        const defaultDays = await getConfigValue('library_issue_days', 14);
        const issueDueDate = dueDate ? new Date(dueDate) : new Date(getSchoolDate().getTime() + parseInt(defaultDays) * 24 * 60 * 60 * 1000);

        const result = await libraryRepo.executeTransaction(async (tx) => {
            // Lock the book record for update to prevent double-issue race conditions
            const txBook = await tx.book.findUnique({ where: { id: bookId } });
            if (!txBook || txBook.availableCopies <= 0 || txBook.status !== 'AVAILABLE') {
                throw new ValidationError('Book is no longer available for issue');
            }

            const issue = await tx.libraryIssue.create({
                data: {
                    bookId,
                    studentId: student.id,
                    issueDate: getSchoolDate(),
                    dueDate: issueDueDate,
                    status: 'ISSUED',
                    issuedBy,
                },
                include: { book: true, student: { include: { user: true } } }
            });

            await tx.book.update({
                where: { id: bookId },
                data: { 
                    availableCopies: txBook.availableCopies - 1,
                    status: txBook.availableCopies - 1 === 0 ? 'ISSUED' : 'AVAILABLE'
                },
            });

            return issue;
        });

        emitEvent('LIBRARY_BOOK_ISSUED', result, 'ADMIN');
        emitEvent('LIBRARY_BOOK_ISSUED', result, 'STUDENT', student.userId);
        return result;
    }

    async returnBook(returnData, returnedBy) {
        const { issueId, conditionOnReturn, remarks } = returnData;

        const issue = await libraryRepo.findIssueById(issueId);
        if (!issue || issue.status === 'RETURNED') {
            throw new ValidationError('Invalid issue record or already returned');
        }

        const returnDate = getStartOfDay(getSchoolDate());
        const dueDate = getStartOfDay(new Date(issue.dueDate));
        const isOverdue = returnDate > dueDate;

        let fine = 0;
        if (isOverdue) {
            const daysOverdue = Math.round((returnDate.getTime() - dueDate.getTime()) / (1000 * 60 * 60 * 24));
            const finePerDay = await getConfigValue('library_fine_per_day', 5);
            fine = daysOverdue * parseFloat(finePerDay);
        }

        const result = await libraryRepo.executeTransaction(async (tx) => {
            const updatedIssue = await tx.libraryIssue.update({
                where: { id: issueId },
                data: {
                    returnDate,
                    status: 'RETURNED', // Corrected: even if overdue, it's now returned
                    isOverdue,
                    conditionOnReturn,
                    remarks,
                    returnedBy,
                },
                include: { book: true, student: { include: { user: true } } }
            });

            await tx.book.update({
                where: { id: issue.bookId },
                data: {
                    availableCopies: issue.book.availableCopies + 1,
                    status: 'AVAILABLE',
                    condition: conditionOnReturn || issue.book.condition
                },
            });

            return { updatedIssue, fine };
        });

        emitEvent('LIBRARY_BOOK_RETURNED', result.updatedIssue, 'ADMIN');
        emitEvent('LIBRARY_BOOK_RETURNED', result.updatedIssue, 'STUDENT', result.updatedIssue.student.userId);
        return result;
    }

    async renewBook(issueId) {
        const issue = await libraryRepo.findIssueById(issueId);
        if (!issue || issue.status !== 'ISSUED') {
            throw new ValidationError('Active issue record not found');
        }

        const renewalDays = await getConfigValue('library_renewal_days', 14);
        const extendedDueDate = new Date(new Date(issue.dueDate).getTime() + parseInt(renewalDays) * 24 * 60 * 60 * 1000);

        const updatedIssue = await libraryRepo.updateIssue(issueId, {
            dueDate: extendedDueDate,
            renewalCount: issue.renewalCount + 1
        });

        emitEvent('LIBRARY_BOOK_RENEWED', updatedIssue, 'ADMIN');
        return updatedIssue;
    }

    async reserveBook(reservationData) {
        const { bookId, studentId, teacherId, expiryDate } = reservationData;

        let resolvedStudentId = null;
        let resolvedTeacherId = null;

        if (studentId) {
            const student = await libraryRepo.findStudentByAdmissionNumber(studentId) || 
                          await libraryRepo.findStudentById(studentId);
            if (!student) throw new NotFoundError('Student not found');
            resolvedStudentId = student.id;
        }

        if (teacherId) {
            const teacher = await libraryRepo.findTeacherByEmployeeId(teacherId) || 
                          await libraryRepo.findTeacherById(teacherId);
            if (!teacher) throw new NotFoundError('Teacher not found');
            resolvedTeacherId = teacher.id;
        }

        const book = await libraryRepo.findBookById(bookId);
        if (!book) throw new NotFoundError('Book not found');

        const reservation = await libraryRepo.createReservation({
            bookId,
            studentId: resolvedStudentId,
            teacherId: resolvedTeacherId,
            expiryDate: expiryDate ? new Date(expiryDate) : new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
            status: 'PENDING'
        });

        if (book.availableCopies === 0) {
            await libraryRepo.updateBook(bookId, { status: 'RESERVED' });
        }

        emitEvent('LIBRARY_BOOK_RESERVED', reservation, 'ADMIN');
        return reservation;
    }

    async getReservations(status = 'PENDING') {
        const where = status !== 'ALL' ? { status } : {};
        return libraryRepo.findReservations(where);
    }

    async getBookIssues(filters) {
        const { studentId, bookId, status, page = 1, limit = 25 } = filters;

        const where = {};
        if (studentId) {
            const student = await libraryRepo.findStudentByAdmissionNumber(studentId) || 
                          await libraryRepo.findStudentById(studentId);
            if (student) where.studentId = student.id;
        }
        if (bookId) where.bookId = bookId;
        if (status) where.status = status;

        const skip = (parseInt(page) - 1) * parseInt(limit);
        const [issues, total] = await Promise.all([
            libraryRepo.findIssues(where, skip, parseInt(limit)),
            libraryRepo.countIssues(where)
        ]);

        return {
            issues,
            pagination: { total, page: parseInt(page), limit: parseInt(limit) }
        };
    }

    async getOverdueBooks() {
        const now = getSchoolDate();
        const overdueIssues = await libraryRepo.findOverdueIssues(now);
        const finePerDay = await getConfigValue('library_fine_per_day', 5);
        
        return overdueIssues.map((issue) => {
            const issueDueDate = getStartOfDay(new Date(issue.dueDate));
            const daysOverdue = Math.round((now.getTime() - issueDueDate.getTime()) / (1000 * 60 * 60 * 24));
            return { ...issue, daysOverdue, calculatedFine: daysOverdue * parseFloat(finePerDay) };
        });
    }
}

module.exports = new LibraryService();
