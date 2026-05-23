const prisma = require('../config/database');
const { generateReportCardPDF } = require('../utils/reportCardGenerator');
const asyncHandler = require('../utils/asyncHandler');
const logger = require('../config/logger');

// Generate report cards for students
const generateReportCards = asyncHandler(async (req, res) => {
    const { examId, studentIds } = req.body;

    if (!examId || !studentIds || !Array.isArray(studentIds) || studentIds.length === 0) {
        return res.status(400).json({ 
            success: false,
            message: 'Required: examId and studentIds (non-empty array)' 
        });
    }

    const exam = await prisma.exam.findUnique({
        where: { id: examId },
        include: { examResults: { select: { studentId: true } } },
    });

    if (!exam) {
        return res.status(404).json({ 
            success: false,
            message: 'Exam not found' 
        });
    }

    const generatedBy = req.user.id;
    const created = [];
    const errors = [];

    for (const studentId of studentIds) {
        try {
            // Check if exam result exists for this student
            const hasResult = exam.examResults.some(r => r.studentId === studentId);
            if (!hasResult) {
                errors.push({ studentId, reason: 'No exam result found for this student' });
                continue;
            }

            const reportCard = await prisma.reportCard.upsert({
                where: { examId_studentId: { examId, studentId } },
                create: {
                    examId,
                    studentId,
                    generatedBy,
                    status: 'DRAFT',
                },
                update: {
                    generatedBy,
                    status: 'DRAFT',
                    submittedAt: null,
                    approvedBy: null,
                    approvedAt: null,
                    rejectionRemark: null,
                },
            });
            created.push(reportCard);
        } catch (err) {
            logger.error(`Error generating report card for student ${studentId}:`, err);
            errors.push({ studentId, reason: err.message });
        }
    }

    res.status(201).json({
        success: true,
        message: `Generated ${created.length} report cards`,
        created: created.length,
        errors,
    });
});

// Get report cards (with filters)
const getReportCards = asyncHandler(async (req, res) => {
    const { examId, status, classId, studentId: queryStudentId } = req.query;

    const where = {};
    if (examId) where.examId = examId;
    if (status) where.status = status;

    // Data isolation: Students only see their own published report cards
    if (req.user.role === 'STUDENT') {
        const student = await prisma.student.findFirst({ where: { userId: req.user.id } });
        if (!student) return res.status(404).json({ 
            success: false,
            message: 'Student profile not found' 
        });
        where.studentId = student.id;
        where.status = 'PUBLISHED'; // Force status for students
    } else if (queryStudentId) {
        where.studentId = queryStudentId;
    }

    if (classId) {
        where.exam = { classId };
    }

    const reportCards = await prisma.reportCard.findMany({
        where,
        include: {
            exam: {
                include: {
                    academicYear: { select: { name: true } },
                    term: { select: { name: true } }
                }
            },
            student: {
                include: {
                    user: { select: { firstName: true, lastName: true } },
                    section: { select: { name: true } },
                },
            },
        },
        orderBy: { createdAt: 'desc' },
    });

    res.status(200).json({ 
        success: true,
        reportCards 
    });
});

// Submit report card for approval (class teacher → principal)
const submitReportCard = asyncHandler(async (req, res) => {
    const { id } = req.params;

    const reportCard = await prisma.reportCard.findUnique({ where: { id } });
    if (!reportCard) {
        return res.status(404).json({ 
            success: false,
            message: 'Report card not found' 
        });
    }

    if (reportCard.status !== 'DRAFT' && reportCard.status !== 'REJECTED') {
        return res.status(400).json({ 
            success: false,
            message: 'Only DRAFT or REJECTED report cards can be submitted' 
        });
    }

    const updated = await prisma.reportCard.update({
        where: { id },
        data: {
            status: 'SUBMITTED',
            submittedAt: new Date(),
            rejectionRemark: null,
        },
    });

    res.status(200).json({ 
        success: true,
        message: 'Report card submitted for approval', 
        reportCard: updated 
    });
});

// Bulk submit report cards
const bulkSubmitReportCards = asyncHandler(async (req, res) => {
    const { reportCardIds } = req.body;

    if (!reportCardIds || !Array.isArray(reportCardIds) || reportCardIds.length === 0) {
        return res.status(400).json({ 
            success: false,
            message: 'Required: reportCardIds (non-empty array)' 
        });
    }

    const result = await prisma.reportCard.updateMany({
        where: {
            id: { in: reportCardIds },
            status: { in: ['DRAFT', 'REJECTED'] },
        },
        data: {
            status: 'SUBMITTED',
            submittedAt: new Date(),
            rejectionRemark: null,
        },
    });

    res.status(200).json({ 
        success: true,
        message: `${result.count} report cards submitted for approval` 
    });
});

// Approve report card (principal)
const approveReportCard = asyncHandler(async (req, res) => {
    const { id } = req.params;

    const reportCard = await prisma.reportCard.findUnique({ where: { id } });
    if (!reportCard) {
        return res.status(404).json({ 
            success: false,
            message: 'Report card not found' 
        });
    }

    if (reportCard.status !== 'SUBMITTED') {
        return res.status(400).json({ 
            success: false,
            message: 'Only SUBMITTED report cards can be approved' 
        });
    }

    const updated = await prisma.reportCard.update({
        where: { id },
        data: {
            status: 'APPROVED',
            approvedBy: req.user.id,
            approvedAt: new Date(),
        },
    });

    res.status(200).json({ 
        success: true,
        message: 'Report card approved', 
        reportCard: updated 
    });
});

// Bulk approve
const bulkApproveReportCards = asyncHandler(async (req, res) => {
    const { reportCardIds } = req.body;

    if (!reportCardIds || !Array.isArray(reportCardIds) || reportCardIds.length === 0) {
        return res.status(400).json({ 
            success: false,
            message: 'Required: reportCardIds (non-empty array)' 
        });
    }

    const result = await prisma.reportCard.updateMany({
        where: {
            id: { in: reportCardIds },
            status: 'SUBMITTED',
        },
        data: {
            status: 'APPROVED',
            approvedBy: req.user.id,
            approvedAt: new Date(),
        },
    });

    res.status(200).json({ 
        success: true,
        message: `${result.count} report cards approved` 
    });
});

// Reject report card (principal)
const rejectReportCard = asyncHandler(async (req, res) => {
    const { id } = req.params;
    const { remark } = req.body;

    if (!remark) {
        return res.status(400).json({ 
            success: false,
            message: 'Rejection remark is required' 
        });
    }

    const reportCard = await prisma.reportCard.findUnique({ where: { id } });
    if (!reportCard) {
        return res.status(404).json({ 
            success: false,
            message: 'Report card not found' 
        });
    }

    if (reportCard.status !== 'SUBMITTED') {
        return res.status(400).json({ 
            success: false,
            message: 'Only SUBMITTED report cards can be rejected' 
        });
    }

    const updated = await prisma.reportCard.update({
        where: { id },
        data: {
            status: 'REJECTED',
            rejectionRemark: remark,
        },
    });

    res.status(200).json({ 
        success: true,
        message: 'Report card rejected', 
        reportCard: updated 
    });
});

// Download report card as PDF
const downloadReportCard = asyncHandler(async (req, res) => {
    const { id } = req.params;

    const reportCard = await prisma.reportCard.findUnique({
        where: { id },
        include: {
            student: {
                include: {
                    user: { select: { firstName: true, lastName: true } },
                    section: { select: { name: true } },
                    class: { select: { name: true } },
                },
            },
            exam: {
                include: {
                    academicYear: { select: { name: true } },
                    term: { select: { name: true } },
                    examSubjects: {
                        include: { subject: { select: { name: true } } },
                    },
                },
            },
        },
    });

    if (!reportCard) {
        return res.status(404).json({ 
            success: false,
            message: 'Report card not found' 
        });
    }

    // IDOR Check: Students can only download their own report card
    if (req.user.role === 'STUDENT') {
        const student = await prisma.student.findFirst({ where: { userId: req.user.id } });
        if (!student || reportCard.studentId !== student.id) {
            return res.status(403).json({ 
                success: false,
                message: 'Forbidden: You can only download your own report card' 
            });
        }
        
        // Students can only download if it is PUBLISHED
        if (reportCard.status !== 'PUBLISHED') {
            return res.status(403).json({ 
                success: false,
                message: 'Forbidden: Report card is not yet published' 
            });
        }
    }

    // Fetch detailed marks for this student and exam
    const examResults = await prisma.examMark.findMany({
        where: {
            studentId: reportCard.studentId,
            examSubject: { examId: reportCard.examId },
        },
        include: {
            examSubject: {
                include: { subject: { select: { name: true } } },
            },
        },
    });

    // Prepare data for PDF generator
    // Fetch school branding config
    const brandingEntries = await prisma.schoolBranding.findMany();
    const brandingMap = {};
    brandingEntries.forEach(e => { brandingMap[e.key] = e.value; });

    const pdfData = {
        student: {
            name: `${reportCard.student.user.firstName} ${reportCard.student.user.lastName}`,
            admissionNo: reportCard.student.admissionNo,
        },
        exam: {
            name: reportCard.exam.name,
        },
        term: reportCard.exam.term?.name || '-',
        class: reportCard.student.class?.name || '-',
        section: reportCard.student.section?.name || '-',
        academicYear: reportCard.exam.academicYear?.name || '-',
        results: examResults.map(m => ({
            subjectName: m.examSubject.subject.name,
            theoryObtained: m.theoryObtained,
            practicalObtained: m.practicalObtained,
            internalObtained: m.internalObtained,
            obtainedMarks: m.obtainedMarks,
            totalMarks: m.examSubject.totalMarks,
            passMarks: m.examSubject.passMarks,
            grade: m.grade,
            isAbsent: m.isAbsent,
            absenceType: m.absenceType,
        })),
        template: await prisma.reportTemplate.findFirst({ where: { isDefault: true } }) || {},
        schoolConfig: {
            schoolName: brandingMap.school_name || process.env.SCHOOL_NAME,
            logoPath: brandingMap.school_logo || null,
        },
    };

    const pdfBuffer = await generateReportCardPDF(pdfData);

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename=ReportCard_${pdfData.student.admissionNo}.pdf`);
    res.send(pdfBuffer);
});

// Bulk publish report cards
const bulkPublishReportCards = asyncHandler(async (req, res) => {
    const { reportCardIds } = req.body;

    if (!reportCardIds || !Array.isArray(reportCardIds) || reportCardIds.length === 0) {
        return res.status(400).json({ 
            success: false,
            message: 'Required: reportCardIds (non-empty array)' 
        });
    }

    const result = await prisma.reportCard.updateMany({
        where: {
            id: { in: reportCardIds },
            status: 'APPROVED',
        },
        data: {
            status: 'PUBLISHED',
        },
    });

    res.status(200).json({ 
        success: true,
        message: `${result.count} report cards published successfully` 
    });
});

// --- Report Template Controllers ---

const getReportTemplates = asyncHandler(async (req, res) => {
    const templates = await prisma.reportTemplate.findMany({
        orderBy: { createdAt: 'desc' }
    });
    res.status(200).json({ 
        success: true,
        templates 
    });
});

const createReportTemplate = asyncHandler(async (req, res) => {
    const templateData = req.body;
    if (templateData.isDefault) {
        await prisma.reportTemplate.updateMany({ data: { isDefault: false } });
    }
    const template = await prisma.reportTemplate.create({ data: templateData });
    res.status(201).json({ 
        success: true,
        template 
    });
});

const updateReportTemplate = asyncHandler(async (req, res) => {
    const { id } = req.params;
    const updates = req.body;
    if (updates.isDefault) {
        await prisma.reportTemplate.updateMany({
            where: { id: { not: id } },
            data: { isDefault: false }
        });
    }
    const template = await prisma.reportTemplate.update({
        where: { id },
        data: updates
    });
    res.status(200).json({ 
        success: true,
        template 
    });
});

module.exports = {
    generateReportCards,
    getReportCards,
    submitReportCard,
    bulkSubmitReportCards,
    approveReportCard,
    bulkApproveReportCards,
    rejectReportCard,
    downloadReportCard,
    bulkPublishReportCards,
    getReportTemplates,
    createReportTemplate,
    updateReportTemplate,
};
