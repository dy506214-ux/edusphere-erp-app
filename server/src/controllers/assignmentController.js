const { getSchoolDate, getStartOfDay } = require('../utils/dateUtils');
const prisma = require('../config/database');
const asyncHandler = require('../utils/asyncHandler');
const NotFoundError = require('../errors/NotFoundError');
const ValidationError = require('../errors/ValidationError');
const logger = require('../config/logger');

// Create a new assignment (Teacher only)
const createAssignment = asyncHandler(async (req, res) => {
  const { title, description, dueDate, subjectId, classId, sectionId } = req.body;
  const userId = req.user.userId || req.user.id;

  // Resolve teacherId from userId
  const teacher = await prisma.teacher.findFirst({ where: { userId } });
  if (!teacher) {
    throw new ValidationError('Teacher profile not found for this user');
  }
  const teacherId = teacher.id;

  // Handle file upload (path from multer or AI generated)
  let filePath = req.file ? `/uploads/assignments/${req.file.filename}` : null;
  
  // If no file uploaded but AI generated PDF path is provided
  if (!filePath && req.body.aiPdfPath) {
    filePath = req.body.aiPdfPath;
  }

  const assignment = await prisma.assignment.create({
    data: {
      title,
      description,
      dueDate: new Date(dueDate),
      filePath,
      subjectId,
      classId,
      sectionId: sectionId || null,
      teacherId,
    },
  });

  res.status(201).json({
    message: 'Assignment created successfully',
    assignment,
  });
});

// Get assignments for a student (based on their class/section)
const getStudentAssignments = asyncHandler(async (req, res) => {
  const student = await prisma.student.findFirst({
    where: { userId: req.user.id },
  });

  if (!student) {
    throw new NotFoundError('Student profile not found');
  }

  const assignments = await prisma.assignment.findMany({
    where: {
      classId: student.currentClassId,
      OR: [
        { sectionId: student.sectionId },
        { sectionId: null },
      ],
    },
    include: {
      subject: { select: { name: true } },
      teacher: { select: { user: { select: { firstName: true, lastName: true } } } },
      submissions: {
        where: { studentId: student.id },
        select: { status: true, grade: true, submittedAt: true },
      },
    },
    orderBy: { dueDate: 'asc' },
  });

  res.json({ assignments });
});

// Get assignments created by a teacher
const getTeacherAssignments = asyncHandler(async (req, res) => {
  const { teacherId, role } = req.user;

  // Roles allowed to see all assignments in the system
  const managementRoles = ['SUPER_ADMIN', 'ADMIN', 'PRINCIPAL', 'HOD', 'ADMISSION_MANAGER'];
  const isManagement = managementRoles.includes(role);

  if (!teacherId && !isManagement) {
    // If not management and not a teacher profile, return error
    if (role === 'TEACHER') {
      throw new ValidationError('Teacher profile not linked to your user account');
    }
    throw new ValidationError('Insufficient permissions to view teacher assignments');
  }

  const where = isManagement ? {} : { teacherId };

  const assignments = await prisma.assignment.findMany({
    where,
    include: {
      subject: { select: { name: true } },
      class: { select: { name: true } },
      section: { select: { name: true } },
      _count: { select: { submissions: true } },
    },
    orderBy: { createdAt: 'desc' },
  });

  res.json({ assignments });
});

// Get assignment details with submissions (for teacher)
const getAssignmentDetails = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const assignment = await prisma.assignment.findUnique({
    where: { id },
    include: {
      subject: { select: { name: true } },
      class: { select: { name: true } },
      section: { select: { name: true } },
      submissions: {
        include: {
          student: {
            select: {
              admissionNumber: true,
              user: { select: { firstName: true, lastName: true } },
            },
          },
        },
      },
    },
  });

  if (!assignment) {
    throw new NotFoundError('Assignment not found');
  }

  res.json({ assignment });
});

// Delete assignment
const deleteAssignment = asyncHandler(async (req, res) => {
  // Resolve teacherId from userId
  const requesterTeacher = await prisma.teacher.findFirst({ where: { userId: req.user.userId || req.user.id } });
  const teacherId = requesterTeacher ? requesterTeacher.id : null;

  if (assignment.teacherId !== teacherId && req.user.role !== 'ADMIN' && req.user.role !== 'SUPER_ADMIN') {
    throw new ValidationError('You are not authorized to delete this assignment');
  }

  await prisma.assignment.delete({ where: { id } });

  res.json({ message: 'Assignment deleted successfully' });
});

module.exports = {
  createAssignment,
  getStudentAssignments,
  getTeacherAssignments,
  getAssignmentDetails,
  deleteAssignment,
};
