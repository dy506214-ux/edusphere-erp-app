const { z } = require('zod');

/**
 * Validator schemas for Exam related routes
 */

const examCreateSchema = z.object({
    name: z.string().min(1, 'Exam name is required'),
    examType: z.enum(['QUARTERLY', 'HALF_YEARLY', 'ANNUAL', 'UNIT_TEST', 'MONTHLY_TEST']),
    classId: z.string().min(1, 'Class ID is required'),
    academicYearId: z.string().min(1, 'Academic Year ID is required'),
    termId: z.string().optional(),
    gradeScaleId: z.string().optional(),
    startDate: z.string().min(1, 'Start date is required'),
    endDate: z.string().optional(),
    subjects: z.array(z.object({
        subjectId: z.string().min(1, 'Subject ID is required'),
        examDate: z.string().min(1, 'Exam date is required'),
        startTime: z.string().optional(),
        duration: z.number().optional(),
        totalMarks: z.number().min(1, 'Total marks is a required positive number'),
        passMarks: z.number().optional(),
        theoryMaxMarks: z.number().optional(),
        practicalMaxMarks: z.number().optional(),
        internalMaxMarks: z.number().optional(),
    })).optional(),
});

const enterMarksSchema = z.object({
    subjectId: z.string().min(1, 'Subject ID is required'),
    marks: z.array(z.object({
        studentId: z.string().min(1, 'Student ID is required'),
        theoryObtained: z.number().optional(),
        practicalObtained: z.number().optional(),
        internalObtained: z.number().optional(),
        isAbsent: z.boolean().optional(),
        absenceType: z.string().optional(),
    })).min(1, 'Marks data cannot be empty'),
});

const addSubjectSchema = z.object({
    subjectId: z.string().min(1, 'Subject ID is required'),
    examDate: z.string().min(1, 'Exam date is required'),
    startTime: z.string().optional(),
    duration: z.number().optional(),
    totalMarks: z.number().min(1, 'Total marks is required'),
    passMarks: z.number().optional(),
    theoryMaxMarks: z.number().optional(),
    practicalMaxMarks: z.number().optional(),
    internalMaxMarks: z.number().optional(),
});

module.exports = {
    examCreateSchema,
    enterMarksSchema,
    addSubjectSchema,
};
