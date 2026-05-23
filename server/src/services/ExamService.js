const ExamRepository = require('../repositories/ExamRepository');
const { getConfigValue } = require('../utils/configHelper');
const { DEFAULTS, EXAM_STATUS } = require('../constants');
const AppError = require('../utils/AppError');

/**
 * Service for Exam related business logic
 */
class ExamService {
    async getExams(query) {
        const { academicYearId, classId, examType, status, page = 1, limit = 25 } = query;

        const where = {};
        if (academicYearId) where.academicYearId = academicYearId;
        if (classId) where.classId = classId;
        if (examType) where.examType = examType;
        if (status) where.status = status;

        const skip = (parseInt(page) - 1) * parseInt(limit);
        const include = {
            class: { select: { name: true } },
            academicYear: { select: { name: true } },
            examSubjects: {
                include: {
                    subject: { select: { name: true, code: true } },
                },
            },
        };

        const [exams, total] = await Promise.all([
            ExamRepository.findExams(where, skip, parseInt(limit), { startDate: 'desc' }, include),
            ExamRepository.countExams(where)
        ]);

        return {
            exams,
            pagination: {
                total,
                page: parseInt(page),
                limit: parseInt(limit),
                totalPages: Math.ceil(total / parseInt(limit)),
            },
        };
    }

    async getTeacherExams(userId) {
        const teacher = await ExamRepository.findTeacherByUserId(userId);
        if (!teacher) throw new AppError('Teacher profile not found', 404);

        const assignments = await ExamRepository.findSubjectTeacherAssignments(teacher.id);
        if (assignments.length === 0) return { tasks: [] };

        const classIds = [...new Set(assignments.map((a) => a.subject.classId))];
        const exams = await ExamRepository.findActiveExamsForClasses(classIds, [EXAM_STATUS.PUBLISHED, EXAM_STATUS.IN_PROGRESS]);

        const tasks = [];
        exams.forEach((exam) => {
            const teacherClassAssignments = assignments.filter((a) => a.subject.classId === exam.classId);

            teacherClassAssignments.forEach((assignment) => {
                const es = exam.examSubjects.find((s) => s.subjectId === assignment.subjectId);
                if (!es) return;

                const totalStudents = exam.class._count.students;
                const entered = exam.examResults.filter((er) =>
                    er.marks.some((m) => m.subjectCode === es.subject.code)
                ).length;

                tasks.push({
                    examId: exam.id,
                    examName: exam.name,
                    classId: exam.classId,
                    className: exam.class.name,
                    subjectId: es.subjectId,
                    subjectName: es.subject.name,
                    subjectCode: es.subject.code,
                    progress: {
                        entered,
                        total: totalStudents,
                        isComplete: entered >= totalStudents && totalStudents > 0,
                    },
                });
            });
        });

        return { tasks };
    }

    async getExam(id) {
        const include = {
            class: true,
            academicYear: true,
            examSubjects: { include: { subject: true } },
            examResults: {
                include: {
                    student: {
                        include: {
                            user: { select: { firstName: true, lastName: true } },
                        },
                    },
                },
            },
        };

        const exam = await ExamRepository.findExamById(id, include);
        if (!exam) throw new AppError('Exam not found', 404);
        return { exam };
    }

    async createExam(data) {
        const {
            name, description, examType, classId, academicYearId, termId, gradeScaleId, startDate, endDate, subjects
        } = data;

        if (!name || !examType || !classId || !academicYearId || !startDate) {
            throw new AppError('Required fields missing', 400);
        }

        const examData = {
            name,
            description: description || null,
            examType,
            classId,
            academicYearId,
            termId: termId || null,
            gradeScaleId: gradeScaleId || null,
            startDate: new Date(startDate),
            endDate: endDate ? new Date(endDate) : null,
            status: EXAM_STATUS.DRAFT,
        };

        const passPercentage = await getConfigValue('passing_percentage', DEFAULTS.PASS_PERCENTAGE);

        if (subjects && Array.isArray(subjects) && subjects.length > 0) {
            examData.examSubjects = {
                create: subjects.map(s => ({
                    subjectId: s.subjectId,
                    examDate: new Date(s.examDate),
                    startTime: s.startTime || DEFAULTS.EXAM_START_TIME,
                    duration: parseInt(s.duration) || DEFAULTS.EXAM_DURATION,
                    totalMarks: parseFloat(s.totalMarks),
                    passMarks: parseFloat(s.passMarks) >= 0 ? parseFloat(s.passMarks) : parseFloat(s.totalMarks) * (passPercentage / 100),
                    theoryMaxMarks: parseFloat(s.theoryMaxMarks) || 0,
                    practicalMaxMarks: parseFloat(s.practicalMaxMarks) || 0,
                    internalMaxMarks: parseFloat(s.internalMaxMarks) || 0,
                }))
            };
        }

        const include = {
            class: true,
            academicYear: true,
            term: true,
            gradeScale: true,
            examSubjects: { include: { subject: true } }
        };

        return await ExamRepository.createExam(examData, include);
    }

    async updateExam(id, updates) {
        const exam = await ExamRepository.findExamById(id);
        if (!exam) throw new AppError('Exam not found', 404);
        if (exam.isFrozen) throw new AppError('Cannot update a frozen exam', 403);

        const allowedUpdates = [
            'name', 'description', 'examType', 'startDate', 'endDate',
            'termId', 'gradeScaleId', 'status',
        ];

        const updateData = {};
        Object.keys(updates).forEach((key) => {
            if (allowedUpdates.includes(key)) {
                if (key === 'startDate' || key === 'endDate') {
                    updateData[key] = new Date(updates[key]);
                } else {
                    updateData[key] = updates[key];
                }
            }
        });

        const include = {
            class: true,
            academicYear: true,
            term: true,
            gradeScale: true,
        };

        return await ExamRepository.updateExam(id, updateData, include);
    }

    async deleteExam(id) {
        const exam = await ExamRepository.findExamById(id);
        if (!exam) throw new AppError('Exam not found', 404);
        if (exam.isFrozen) throw new AppError('Cannot delete a frozen exam. Unfreeze it first.', 403);

        return await ExamRepository.deleteExam(id);
    }

    async addSubjectToExam(id, data) {
        const { subjectId, examDate, startTime, duration, totalMarks, passMarks, theoryMaxMarks, practicalMaxMarks, internalMaxMarks } = data;

        if (!subjectId || !examDate || !totalMarks) {
            throw new AppError('Required fields missing', 400);
        }

        const passPercentage = await getConfigValue('passing_percentage', DEFAULTS.PASS_PERCENTAGE);

        const examSubjectData = {
            examId: id,
            subjectId,
            examDate: new Date(examDate),
            startTime: startTime || DEFAULTS.EXAM_START_TIME,
            duration: parseInt(duration) || DEFAULTS.EXAM_DURATION,
            totalMarks: parseFloat(totalMarks),
            passMarks: parseFloat(passMarks) >= 0 ? parseFloat(passMarks) : parseFloat(totalMarks) * (passPercentage / 100),
            theoryMaxMarks: parseFloat(theoryMaxMarks) || 0,
            practicalMaxMarks: parseFloat(practicalMaxMarks) || 0,
            internalMaxMarks: parseFloat(internalMaxMarks) || 0,
        };

        return await ExamRepository.createExamSubject(examSubjectData, { subject: true });
    }

    async enterMarks(examId, data, userId, userRole) {
        const { subjectId, marks } = data;

        if (!subjectId || !marks || !Array.isArray(marks) || marks.length === 0) {
            throw new AppError('Required: subjectId, marks (non-empty array)', 400);
        }

        const exam = await ExamRepository.findExamById(examId, {
            gradeScale: { include: { entries: { orderBy: { order: 'asc' } } } },
        });

        if (!exam) throw new AppError('Exam not found', 404);
        if (exam.isFrozen) throw new AppError('Exam results are frozen. Cannot enter marks.', 403);

        const examSubject = await ExamRepository.findExamSubject(examId, subjectId);
        if (!examSubject) throw new AppError('This subject is not part of the exam', 404);

        if (userRole === 'TEACHER') {
            const assignment = await ExamRepository.findTeacherAssignment(userId, subjectId);
            if (!assignment) throw new AppError('You are not assigned to this subject', 403);
        }

        const validationErrors = [];
        for (const m of marks) {
            if (!m.isAbsent) {
                if (examSubject.theoryMaxMarks > 0 && (m.theoryObtained || 0) > examSubject.theoryMaxMarks) {
                    validationErrors.push({ studentId: m.studentId, field: 'theoryObtained', message: `Exceeds max ${examSubject.theoryMaxMarks}` });
                }
                if (examSubject.practicalMaxMarks > 0 && (m.practicalObtained || 0) > examSubject.practicalMaxMarks) {
                    validationErrors.push({ studentId: m.studentId, field: 'practicalObtained', message: `Exceeds max ${examSubject.practicalMaxMarks}` });
                }
                if (examSubject.internalMaxMarks > 0 && (m.internalObtained || 0) > examSubject.internalMaxMarks) {
                    validationErrors.push({ studentId: m.studentId, field: 'internalObtained', message: `Exceeds max ${examSubject.internalMaxMarks}` });
                }
            }
        }

        if (validationErrors.length > 0) {
            throw new AppError('Marks exceed maximum allowed', 400, validationErrors);
        }

        const gradeEntries = exam.gradeScale?.entries || [];
        const calcGrade = (pct) => this.calculateGrade(pct, { entries: gradeEntries });
        const passPct = await getConfigValue('passing_percentage', DEFAULTS.PASS_PERCENTAGE);

        const savedBy = userId || null;
        const savedAt = new Date();
        const saved = [];

        await ExamRepository.executeTransaction(async (tx) => {
            const studentIds = marks.map(m => m.studentId);
            
            // Batch fetch existing results and marks
            const existingResults = await tx.examResult.findMany({
                where: { examId, studentId: { in: studentIds } },
                include: { marks: true }
            });
            
            const resultMap = new Map(existingResults.map(r => [r.studentId, r]));

            for (const m of marks) {
                const theory = m.isAbsent ? 0 : parseFloat(m.theoryObtained) || 0;
                const practical = m.isAbsent ? 0 : parseFloat(m.practicalObtained) || 0;
                const internal = m.isAbsent ? 0 : parseFloat(m.internalObtained) || 0;
                const obtainedMarks = theory + practical + internal;
                const pct = (examSubject.totalMarks && examSubject.totalMarks > 0) ? (obtainedMarks / examSubject.totalMarks) * 100 : 0;

                let examResult = resultMap.get(m.studentId);
                if (!examResult) {
                    examResult = await tx.examResult.create({
                        data: {
                            examId,
                            studentId: m.studentId,
                            totalMarks: 0,
                            obtainedMarks: 0,
                            percentage: 0,
                            result: 'PASS',
                        },
                        include: { marks: true }
                    });
                }

                const existingMark = examResult.marks.find((mk) => mk.subjectCode === examSubject.subject.code);

                const markData = {
                    subjectName: examSubject.subject.name,
                    subjectCode: examSubject.subject.code,
                    totalMarks: examSubject.totalMarks,
                    obtainedMarks,
                    grade: m.isAbsent ? (m.absenceType === 'MEDICAL' ? 'MED' : 'AB') : calcGrade(pct),
                    theoryObtained: theory,
                    practicalObtained: practical,
                    internalObtained: internal,
                    isAbsent: m.isAbsent || false,
                    absenceType: m.isAbsent ? (m.absenceType || 'ABSENT') : null,
                    enteredBy: savedBy,
                    enteredAt: savedAt,
                };

                if (existingMark) {
                    await tx.examMark.update({ where: { id: existingMark.id }, data: markData });
                } else {
                    await tx.examMark.create({ data: { examResultId: examResult.id, ...markData } });
                }

                // Optimization: Refetch all marks for this result in one query at the end? 
                // No, we need it to update total marks for THIS student. 
                // But we can fetch it once per student.
                const allMarks = await tx.examMark.findMany({ where: { examResultId: examResult.id } });
                const totalMax = allMarks.reduce((sum, mk) => sum + mk.totalMarks, 0);
                const totalObt = allMarks.filter(mk => !mk.isAbsent)
                    .reduce((sum, mk) => sum + mk.obtainedMarks, 0);
                const totalMaxForCalc = allMarks.filter(mk => !mk.isAbsent)
                    .reduce((sum, mk) => sum + mk.totalMarks, 0);
                
                const overallPct = totalMaxForCalc > 0 ? (totalObt / totalMaxForCalc) * 100 : 0;
                
                // Fetch all exam subjects to get their specific passMarks
                const allExamSubjects = await tx.examSubject.findMany({
                    where: { examId }
                });
                const subjectPassMap = new Map(allExamSubjects.map(es => [es.subjectId, es.passMarks]));
                const subjectCodeToIdMap = new Map(allExamSubjects.map(es => [es.subjectId, es.subjectId])); // This needs subject code?
                // Actually, let's use subjectCode since mark has subjectCode
                const allSubjects = await tx.subject.findMany({
                    where: { id: { in: allExamSubjects.map(es => es.subjectId) } }
                });
                const codeToPassMarks = new Map(allExamSubjects.map(es => {
                    const s = allSubjects.find(sub => sub.id === es.subjectId);
                    return [s.code, es.passMarks];
                }));

                const hasFailingSubject = allMarks.some(mk => {
                    if (mk.isAbsent) return mk.absenceType !== 'MEDICAL';
                    const specificPassMarks = codeToPassMarks.get(mk.subjectCode) || (mk.totalMarks * (passPct / 100));
                    return mk.obtainedMarks < specificPassMarks;
                });

                await tx.examResult.update({
                    where: { id: examResult.id },
                    data: {
                        totalMarks: totalMax,
                        obtainedMarks: totalObt,
                        percentage: parseFloat(overallPct.toFixed(2)),
                        grade: calcGrade(overallPct),
                        result: (overallPct >= passPct && !hasFailingSubject) ? 'PASS' : 'FAIL',
                        remarks: this.generateRemarks(overallPct, { entries: gradeEntries }),
                    },
                });

                saved.push(m.studentId);
            }
        });

        return { saved: saved.length };
    }

    async getConsolidatedMarks(examId) {
        const include = {
            class: {
                include: {
                    students: {
                        include: {
                            user: { select: { firstName: true, lastName: true } },
                            section: { select: { name: true } },
                        },
                        where: { status: 'ACTIVE' },
                        orderBy: { admissionNumber: 'asc' },
                    },
                },
            },
            academicYear: { select: { name: true } },
            examSubjects: {
                include: { subject: { select: { name: true, code: true } } },
                orderBy: { examDate: 'asc' },
            },
            examResults: {
                include: { marks: true },
            },
        };

        const exam = await ExamRepository.findExamById(examId, include);
        if (!exam) throw new AppError('Exam not found', 404);

        const students = exam.class.students;
        const totalStudents = students.length;

        const results = students.map(student => {
            const dbResult = exam.examResults.find(er => er.studentId === student.id);

            return {
                studentId: student.id,
                studentName: `${student.user.firstName} ${student.user.lastName}`,
                admissionNo: student.admissionNumber || '-',
                section: student.section?.name || '-',
                totalMarks: dbResult?.totalMarks || 0,
                obtainedMarks: dbResult?.obtainedMarks || 0,
                percentage: dbResult?.percentage || 0,
                grade: dbResult?.grade || '-',
                rank: dbResult?.rank || '-',
                result: dbResult?.result || 'PENDING',
                marks: dbResult?.marks || [],
            };
        });

        const sortedResults = [...results].sort((a, b) => b.percentage - a.percentage);
        let currentRank = 1;
        sortedResults.forEach((r, idx) => {
            if (idx > 0 && r.percentage < sortedResults[idx - 1].percentage) {
                currentRank = idx + 1;
            }
            const original = results.find(o => o.studentId === r.studentId);
            if (original) original.rank = currentRank;
        });

        const subjectProgress = exam.examSubjects.map(es => {
            const entered = exam.examResults.filter(er =>
                er.marks.some(mk => mk.subjectCode === es.subject.code)
            ).length;
            return {
                subjectId: es.subjectId,
                subjectName: es.subject.name,
                subjectCode: es.subject.code,
                totalMarks: es.totalMarks,
                theoryMax: es.theoryMaxMarks,
                practicalMax: es.practicalMaxMarks,
                internalMax: es.internalMaxMarks,
                entered,
                total: totalStudents,
                isComplete: entered >= totalStudents && totalStudents > 0,
            };
        });

        return {
            exam: {
                id: exam.id,
                name: exam.name,
                className: exam.class.name,
                academicYear: exam.academicYear.name,
                isFrozen: exam.isFrozen,
                status: exam.status,
            },
            subjectProgress,
            results,
        };
    }

    async freezeExam(examId, userId) {
        const exam = await ExamRepository.findExamById(examId);
        if (!exam) throw new AppError('Exam not found', 404);
        if (exam.isFrozen) throw new AppError('Exam is already frozen', 400);

        return await ExamRepository.updateExam(examId, {
            isFrozen: true,
            frozenAt: new Date(),
            frozenBy: userId || null,
            status: EXAM_STATUS.FROZEN,
        });
    }

    async unfreezeExam(examId) {
        const exam = await ExamRepository.findExamById(examId);
        if (!exam) throw new AppError('Exam not found', 404);
        if (!exam.isFrozen) throw new AppError('Exam is not frozen', 400);

        return await ExamRepository.updateExam(examId, {
            isFrozen: false,
            frozenAt: null,
            frozenBy: null,
            status: EXAM_STATUS.COMPLETED,
        });
    }

    async getStudentExamResults(studentId, query) {
        const { academicYearId, examType } = query;
        const where = { studentId };

        if (academicYearId || examType) {
            where.exam = {};
            if (academicYearId) where.exam.academicYearId = academicYearId;
            if (examType) where.exam.examType = examType;
        }

        const include = {
            exam: {
                include: {
                    class: { select: { name: true } },
                    academicYear: { select: { name: true } },
                },
            },
            marks: true,
        };

        const results = await ExamRepository.findExamResults(where, include, { createdAt: 'desc' });
        return { results };
    }

    async getExamResultsReport(examId, query) {
        const { classId, passFail } = query;
        const where = { examId };

        const results = await ExamRepository.findExamResults(where, {
            student: {
                include: {
                    user: { select: { firstName: true, lastName: true } },
                    currentClass: { select: { name: true } },
                },
            },
            exam: {
                include: {
                    examSubjects: { include: { subject: true } },
                },
            },
            marks: true,
        }, { percentage: 'desc' });

        // Bug #10 fix: Use configurable pass percentage instead of hardcoded 40
        const passPct = await getConfigValue('passing_percentage', DEFAULTS.PASS_PERCENTAGE);

        let filteredResults = results;
        if (classId) {
            filteredResults = results.filter((r) => r.student.currentClassId === classId);
        }

        if (passFail === 'pass') {
            filteredResults = filteredResults.filter((r) => r.percentage >= passPct);
        } else if (passFail === 'fail') {
            filteredResults = filteredResults.filter((r) => r.percentage < passPct);
        }

        const stats = {
            totalStudents: filteredResults.length,
            passed: filteredResults.filter((r) => r.percentage >= passPct).length,
            failed: filteredResults.filter((r) => r.percentage < passPct).length,
            averagePercentage: filteredResults.length > 0
                ? (filteredResults.reduce((sum, r) => sum + r.percentage, 0) / filteredResults.length).toFixed(2)
                : 0,
            highestPercentage: filteredResults.length > 0 ? filteredResults[0].percentage : 0,
            lowestPercentage: filteredResults.length > 0 ? filteredResults[filteredResults.length - 1].percentage : 0,
        };

        return { results: filteredResults, stats };
    }

    calculateGrade(percentage, gradeScale = null) {
        if (gradeScale && gradeScale.entries && gradeScale.entries.length > 0) {
            const entry = gradeScale.entries.find(e => percentage >= e.minPercent && percentage <= e.maxPercent);
            if (entry) return entry.grade;
        }
        
        if (percentage >= 90) return 'A+';
        if (percentage >= 80) return 'A';
        if (percentage >= 70) return 'B+';
        if (percentage >= 60) return 'B';
        if (percentage >= 50) return 'C';
        if (percentage >= 40) return 'D';
        return 'F';
    }

    generateRemarks(percentage, gradeScale = null) {
        if (gradeScale && gradeScale.entries && gradeScale.entries.length > 0) {
            const entry = gradeScale.entries.find(e => percentage >= e.minPercent && percentage <= e.maxPercent);
            if (entry && entry.description) return entry.description;
        }

        if (percentage >= 90) return 'Outstanding';
        if (percentage >= 80) return 'Excellent';
        if (percentage >= 70) return 'Very Good';
        if (percentage >= 60) return 'Good';
        if (percentage >= 50) return 'Satisfactory';
        if (percentage >= 40) return 'Pass';
        return 'Needs Improvement';
    }
}

module.exports = new ExamService();
