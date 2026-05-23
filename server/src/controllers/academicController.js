const prisma = require('../config/database');
const fs = require('fs');
const path = require('path');
const asyncHandler = require('../utils/asyncHandler');
const logger = require('../config/logger');

// Academic Years
const getAcademicYears = asyncHandler(async (req, res) => {
  const academicYears = await prisma.academicYear.findMany({
    orderBy: { startDate: 'desc' },
  });
  res.status(200).json({ 
    success: true,
    academicYears 
  });
});

const createAcademicYear = asyncHandler(async (req, res) => {
  const { name, startDate, endDate, isCurrent } = req.body;

  if (!name || !startDate || !endDate) {
    return res.status(400).json({ 
      success: false,
      message: 'Name, start date, and end date are required' 
    });
  }

  // If this is set to current, unset others first
  if (isCurrent) {
    await prisma.academicYear.updateMany({
      where: { isCurrent: true },
      data: { isCurrent: false }
    });
  }

  const year = await prisma.academicYear.create({
    data: {
      name,
      startDate: new Date(startDate),
      endDate: new Date(endDate),
      isCurrent: Boolean(isCurrent),
    }
  });

  res.status(201).json({
    success: true,
    message: 'Academic year created successfully',
    year,
  });
});

const setCurrentAcademicYear = asyncHandler(async (req, res) => {
  const { id } = req.params;

  // Check if year exists
  const year = await prisma.academicYear.findUnique({ where: { id } });
  if (!year) {
    return res.status(404).json({ 
      success: false,
      message: 'Academic year not found' 
    });
  }

  // Transaction to ensure atomicity
  await prisma.$transaction([
    // Unset current for all
    prisma.academicYear.updateMany({
      where: { isCurrent: true },
      data: { isCurrent: false }
    }),
    // Set new current
    prisma.academicYear.update({
      where: { id },
      data: { isCurrent: true }
    })
  ]);

  res.status(200).json({ 
    success: true,
    message: 'Current academic year updated successfully' 
  });
});

// Classes
const getClasses = asyncHandler(async (req, res) => {
  const { academicYearId } = req.query;
  const where = {};
  if (academicYearId) where.academicYearId = academicYearId;

  // Role-based filtering for teachers
  if (req.user && req.user.role === 'TEACHER') {
    const teacher = await prisma.teacher.findUnique({
      where: { userId: req.user.userId },
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

      // If no assignments found, ensure they see nothing instead of everything
      if (assignedClassIds.size === 0) {
        where.id = 'none'; // Will result in empty array
      } else {
        where.id = { in: Array.from(assignedClassIds) };
      }
    }
  }

  const classes = await prisma.class.findMany({
    where,
    include: {
      academicYear: true,
      classTeacher: {
        include: { user: true },
      },
      sections: true,
      _count: {
        select: {
          students: true,
          subjects: true,
        },
      },
    },
    orderBy: { numericValue: 'asc' },
  });
  res.status(200).json({ 
    success: true,
    classes 
  });
});

const createClass = asyncHandler(async (req, res) => {
  const { name, numericValue, description, academicYearId, classTeacherId } = req.body;

  if (!name || !numericValue || !academicYearId) {
    return res.status(400).json({ 
      success: false,
      message: 'Name, numeric level, and academic year are required' 
    });
  }

  const parsedNumericValue = parseInt(numericValue);
  if (isNaN(parsedNumericValue)) {
    return res.status(400).json({ 
      success: false,
      message: 'Numeric level must be a valid number' 
    });
  }

  const classData = await prisma.class.create({
    data: {
      name,
      numericValue: parsedNumericValue,
      description: description || null,
      academicYearId,
      classTeacherId: classTeacherId || null,
    },
    include: {
      academicYear: true,
      classTeacher: { include: { user: true } },
    },
  });

  res.status(201).json({
    success: true,
    message: 'Class created successfully',
    class: classData,
  });
});

// Subjects
const getSubjects = asyncHandler(async (req, res) => {
  const { classId } = req.query;

  const where = {};
  if (classId) where.classId = classId;

  const subjects = await prisma.subject.findMany({
    where,
    include: {
      class: true,
      teachers: {
        include: {
          teacher: {
            include: { user: true },
          },
        },
      },
    },
  });

  res.status(200).json({ 
    success: true,
    subjects 
  });
});

const createSubject = asyncHandler(async (req, res) => {
  const { name, code, description, classId, type, totalMarks, passMarks, teacherId } = req.body;

  if (!name || !code || !classId) {
    return res.status(400).json({ 
      success: false,
      message: 'Name, code, and class are required' 
    });
  }

  const result = await prisma.$transaction(async (tx) => {
    const subject = await tx.subject.create({
      data: {
        name,
        code,
        description: description || null,
        classId,
        type: type || 'CORE',
        totalMarks: parseInt(totalMarks) || 100,
        passMarks: parseInt(passMarks) || 40,
      },
      include: { class: true },
    });

    if (teacherId) {
      await tx.subjectTeacher.create({
        data: {
          subjectId: subject.id,
          teacherId,
        },
      });
    }

    return subject;
  });

  res.status(201).json({
    success: true,
    message: 'Subject created successfully',
    subject: result,
  });
});

const assignSubjectTeacher = asyncHandler(async (req, res) => {
  const { subjectId, teacherId } = req.body;

  if (!subjectId || !teacherId) {
    return res.status(400).json({ 
      success: false,
      message: 'Subject and Teacher IDs are required' 
    });
  }

  const assignment = await prisma.subjectTeacher.create({
    data: {
      subjectId,
      teacherId,
    },
    include: {
      subject: true,
      teacher: { include: { user: true } },
    }
  });

  res.status(201).json({
    success: true,
    message: 'Teacher assigned to subject successfully',
    assignment,
  });
});

// Sections
const getSections = asyncHandler(async (req, res) => {
  const { classId } = req.query;

  const where = {};
  if (classId) where.classId = classId;

  const sections = await prisma.section.findMany({
    where,
    include: {
      class: true,
      _count: {
        select: { students: true },
      },
    },
  });

  res.status(200).json({ 
    success: true,
    sections 
  });
});

const createSection = asyncHandler(async (req, res) => {
  const { name, classId, maxStudents } = req.body;

  const section = await prisma.section.create({
    data: {
      name,
      classId,
      maxStudents: parseInt(maxStudents) || 40,
    },
    include: { class: true },
  });

  res.status(201).json({
    success: true,
    message: 'Section created successfully',
    section,
  });
});

const updateClass = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { name, numericValue, description, academicYearId, classTeacherId } = req.body;

  if (!name || !numericValue || !academicYearId) {
    return res.status(400).json({ 
      success: false,
      message: 'Name, numeric level, and academic year are required' 
    });
  }

  const parsedNumericValue = parseInt(numericValue);
  if (isNaN(parsedNumericValue)) {
    return res.status(400).json({ 
      success: false,
      message: 'Numeric level must be a valid number' 
    });
  }

  const existing = await prisma.class.findUnique({ where: { id } });
  if (!existing) return res.status(404).json({ 
    success: false,
    message: 'Class not found' 
  });

  const classData = await prisma.class.update({
    where: { id },
    data: {
      name,
      numericValue: parsedNumericValue,
      description: description || null,
      academicYearId,
      classTeacherId: classTeacherId || null,
    },
    include: { academicYear: true, classTeacher: { include: { user: true } } },
  });

  res.status(200).json({ 
    success: true,
    message: 'Class updated successfully', 
    class: classData 
  });
});

const deleteClass = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const existing = await prisma.class.findUnique({
    where: { id },
    include: { 
      _count: { 
        select: { 
          students: true, 
          sections: true, 
          subjects: true,
          attendanceRecords: true,
          examResults: true
        } 
      } 
    },
  });
  if (!existing) return res.status(404).json({ error: 'Class not found' });

  if (existing._count.students > 0) {
    return res.status(400).json({ 
      success: false,
      message: `Cannot delete class with ${existing._count.students} currently enrolled student(s).` 
    });
  }

  if (existing._count.attendanceRecords > 0 || existing._count.examResults > 0) {
    return res.status(400).json({ 
      success: false,
      message: `Cannot delete class with historical records (${existing._count.attendanceRecords} attendance, ${existing._count.examResults} exams). Use Archive instead.` 
    });
  }

  // Delete related subjects and sections first
  await prisma.subject.deleteMany({ where: { classId: id } });
  await prisma.section.deleteMany({ where: { classId: id } });
  await prisma.class.delete({ where: { id } });

  res.status(200).json({ 
    success: true,
    message: 'Class deleted successfully' 
  });
});

const updateSubject = asyncHandler(async (req, res) => {
  // ... (unchanged)
  const { id } = req.params;
  const { name, code, description, classId, type, totalMarks, passMarks } = req.body;

  if (!name || !code || !classId) {
    return res.status(400).json({ 
      success: false,
      message: 'Name, code, and class are required' 
    });
  }

  const existing = await prisma.subject.findUnique({ where: { id } });
  if (!existing) return res.status(404).json({ error: 'Subject not found' });

  const subject = await prisma.subject.update({
    where: { id },
    data: {
      name,
      code,
      description: description || null,
      classId,
      type: type || 'CORE',
      totalMarks: parseInt(totalMarks) || 100,
      passMarks: parseInt(passMarks) || 40,
    },
    include: { class: true },
  });

  res.status(200).json({ 
    success: true,
    message: 'Subject updated successfully', 
    subject 
  });
});

const deleteSubject = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const existing = await prisma.subject.findUnique({ where: { id } });
  if (!existing) return res.status(404).json({ error: 'Subject not found' });

  await prisma.subject.delete({ where: { id } });
  res.status(200).json({ 
    success: true,
    message: 'Subject deleted successfully' 
  });
});

const updateSection = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { name, classId, maxStudents } = req.body;

  if (!name || !classId) {
    return res.status(400).json({ 
      success: false,
      message: 'Name and class are required' 
    });
  }

  const existing = await prisma.section.findUnique({ where: { id } });
  if (!existing) return res.status(404).json({ 
    success: false,
    message: 'Section not found' 
  });

  const section = await prisma.section.update({
    where: { id },
    data: { name, classId, maxStudents: parseInt(maxStudents) || 40 },
    include: { class: true },
  });

  res.status(200).json({ 
    success: true,
    message: 'Section updated successfully', 
    section 
  });
});

const deleteSection = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const existing = await prisma.section.findUnique({
    where: { id },
    include: { 
      _count: { 
        select: { 
          students: true,
          attendanceRecords: true,
          examResults: true
        } 
      } 
    },
  });
  if (!existing) return res.status(404).json({ error: 'Section not found' });

  if (existing._count.students > 0) {
    return res.status(400).json({ 
      success: false,
      message: `Cannot delete section with ${existing._count.students} currently enrolled student(s).` 
    });
  }

  if (existing._count.attendanceRecords > 0 || existing._count.examResults > 0) {
    return res.status(400).json({ 
      success: false,
      message: `Cannot delete section with historical records (${existing._count.attendanceRecords} attendance, ${existing._count.examResults} exams).` 
    });
  }

  await prisma.section.delete({ where: { id } });
  res.status(200).json({ 
    success: true,
    message: 'Section deleted successfully' 
  });
});

// Dashboard Stats
const getAcademicDashboardStats = asyncHandler(async (req, res) => {
  const totalYears = await prisma.academicYear.count();
  const currentYear = await prisma.academicYear.findFirst({ where: { isCurrent: true } });
  const totalClasses = await prisma.class.count();
  const totalSections = await prisma.section.count();
  const totalSubjects = await prisma.subject.count();
  const totalTeachers = await prisma.teacher.count({ where: { status: 'ACTIVE' } });

  res.status(200).json({
    success: true,
    stats: {
      totalYears,
      currentYear,
      totalClasses,
      totalSections,
      totalSubjects,
      totalTeachers,
    }
  });
});

// Timetables
const getTimetables = asyncHandler(async (req, res) => {
  const { classId, type } = req.query;
  const where = { isActive: true };
  if (classId) where.classId = classId;
  if (type) where.type = type;

  // For students/teachers, we might want to restrict based on their class
  if (req.user.role === 'STUDENT') {
    const student = await prisma.student.findFirst({ where: { userId: req.user.userId } });
    if (student && student.currentClassId) {
      where.classId = student.currentClassId;
    }
  } else if (req.user.role === 'TEACHER') {
    // Teachers can see for their assigned class or based on the classId filter
  }

  const timetables = await prisma.timetable.findMany({
    where,
    include: {
      class: true,
    },
    orderBy: { createdAt: 'desc' },
  });
  res.status(200).json({ 
    success: true,
    timetables 
  });
});

const createTimetable = asyncHandler(async (req, res) => {
  const { name, classId, type, effectiveFrom, effectiveTo } = req.body;
  const pdfUrl = req.file ? `/uploads/timetables/${req.file.filename}` : null;

  if (!name || !classId || !effectiveFrom) {
    return res.status(400).json({ 
        success: false,
        message: 'Name, class, and effective date are required' 
    });
  }

  // Verify classId exists
  const classExists = await prisma.class.findUnique({ where: { id: classId } });
  if (!classExists) {
    return res.status(400).json({ 
        success: false,
        message: 'Class not found with given classId' 
    });
  }

  const timetable = await prisma.timetable.create({
    data: {
      name,
      classId,
      type: type || 'DAILY',
      pdfUrl,
      effectiveFrom: new Date(effectiveFrom),
      effectiveTo: effectiveTo ? new Date(effectiveTo) : null,
    },
    include: { class: true },
  });

  res.status(201).json({
    success: true,
    message: 'Timetable created successfully',
    timetable,
  });
});


const deleteTimetable = asyncHandler(async (req, res) => {
  const { id } = req.params;

  // Find timetable first to get pdfUrl
  const timetable = await prisma.timetable.findUnique({ where: { id } });
  if (!timetable) {
    return res.status(404).json({ 
      success: false,
      message: 'Timetable not found' 
    });
  }

  // Hard delete from DB
  await prisma.timetable.delete({ where: { id } });

  // Delete physical PDF file if it exists
  if (timetable.pdfUrl) {
    const filename = path.basename(timetable.pdfUrl);
    const filePath = path.join(__dirname, '..', '..', 'uploads', 'timetables', filename);
    if (fs.existsSync(filePath)) {
      try {
        fs.unlinkSync(filePath);
      } catch (unlinkErr) {
        logger.error(`Failed to delete timetable file: ${filePath}`, unlinkErr);
      }
    }
  }
  res.status(200).json({ 
    success: true,
    message: 'Timetable deleted successfully' 
  });
});

module.exports = {
  getAcademicYears,
  createAcademicYear,
  setCurrentAcademicYear,
  getClasses,
  createClass,
  updateClass,
  deleteClass,
  getSubjects,
  createSubject,
  updateSubject,
  deleteSubject,
  assignSubjectTeacher,
  getSections,
  createSection,
  updateSection,
  deleteSection,
  getAcademicDashboardStats,
  getTimetables,
  createTimetable,
  deleteTimetable,
};

