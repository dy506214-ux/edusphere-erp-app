const studentService = require('../services/studentService');
const { emitEvent } = require('../services/socketService');
const studentRepo = require('../repositories/studentRepository');
const asyncHandler = require('../utils/asyncHandler');
const NotFoundError = require('../errors/NotFoundError');
const { generateAttendanceReportPDF } = require('../utils/attendanceReportGenerator');

/**
 * Get all students with filters
 * Route: GET /api/students
 */
const getStudents = asyncHandler(async (req, res) => {
  const result = await studentService.getStudents(req.query, req.user);

  res.status(200).json({
    success: true,
    ...result
  });
});

/**
 * Get single student
 * Route: GET /api/students/:id
 */
const getStudent = asyncHandler(async (req, res) => {
  const student = await studentService.getStudentById(req.params.id);

  res.status(200).json({
    success: true,
    student
  });
});

/**
 * Create basic student
 * Route: POST /api/students
 */
const createStudent = asyncHandler(async (req, res) => {
  const student = await studentService.createStudent(req.body);

  res.status(201).json({
    success: true,
    message: 'Student created successfully',
    student,
  });

  // Emit real-time event
  emitEvent('STUDENT_CREATED', {
    studentId: student.id,
    name: `${student.user?.firstName || ''} ${student.user?.lastName || ''}`,
    class: student.currentClass?.name
  }, 'ADMIN');
});

/**
 * Update student
 * Route: PUT /api/students/:id
 */
const updateStudent = asyncHandler(async (req, res) => {
  const student = await studentService.updateStudent(req.params.id, req.body);

  res.status(200).json({
    success: true,
    message: 'Student updated successfully',
    student,
  });
});

/**
 * Delete student (soft delete)
 * Route: DELETE /api/students/:id
 */
const deleteStudent = asyncHandler(async (req, res) => {
  await studentService.deleteStudent(req.params.id);

  res.status(200).json({ 
    success: true,
    message: 'Student deleted successfully' 
  });
});

/**
 * Get student attendance
 * Route: GET /api/students/:id/attendance
 */
const getStudentAttendance = asyncHandler(async (req, res) => {
  const { startDate, endDate } = req.query;
  const result = await studentService.getStudentAttendance(req.params.id, startDate, endDate);

  res.status(200).json({
    success: true,
    ...result
  });
});

/**
 * Register new student (Comprehensive)
 * Route: POST /api/students/register
 */
const registerStudent = asyncHandler(async (req, res) => {
  // Pass req.user for audit logging (who collected the fee)
  const result = await studentService.registerStudent(req.body, req.user);

  res.status(201).json({
    success: true,
    message: 'Student registered successfully',
    data: result
  });

  // Emit real-time event
  emitEvent('STUDENT_REGISTERED', {
    studentId: result.student?.id,
    name: `${result.student?.user?.firstName || ''} ${result.student?.user?.lastName || ''}`,
    class: result.student?.currentClass?.name
  }, 'ADMIN');
});

/**
 * Get current student profile (For STUDENT role)
 * Route: GET /api/students/me
 */
const getMeStudent = asyncHandler(async (req, res) => {
  // Use repository directly to bypass any Admin-only filters in service
  const student = await studentRepo.findByUserId(req.user.userId);
  if (!student) {
    throw new NotFoundError('Student profile not found for this user');
  }

  res.status(200).json({
    success: true,
    student
  });
});

/**
 * Update current student profile (For STUDENT role)
 * Route: PUT /api/students/me
 */
const updateMeStudent = asyncHandler(async (req, res) => {
  // 1. Get the student record for the logged-in user
  const student = await studentRepo.findByUserId(req.user.userId);
  if (!student) {
    throw new NotFoundError('Student profile not found for this user');
  }

  // 2. Filter allowed updates to prevent privilege escalation or core identity changes
  const allowedUpdates = {};
  const { phone, address, emergencyContact, emergencyPhone, medicalConditions, allergies } = req.body;

  // User model fields
  if (phone !== undefined) allowedUpdates.phone = phone;
  if (address !== undefined) allowedUpdates.address = address;

  // Student model fields
  if (emergencyContact !== undefined) allowedUpdates.emergencyContact = emergencyContact;
  if (emergencyPhone !== undefined) allowedUpdates.emergencyPhone = emergencyPhone;
  if (medicalConditions !== undefined) allowedUpdates.medicalConditions = medicalConditions;
  if (allergies !== undefined) allowedUpdates.allergies = allergies;

  // 3. Update using student service
  const updatedStudent = await studentService.updateStudent(student.id, allowedUpdates);

  res.status(200).json({
    success: true,
    message: 'Profile updated successfully',
    student: updatedStudent,
  });
});

/**
 * Get student attendance report in PDF
 * Route: GET /api/students/:id/attendance/report
 */
const getAttendanceReport = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { startDate, endDate } = req.query;

  // 1. Get student details and attendance data
  const student = await studentService.getStudentById(id);
  const attData = await studentService.getStudentAttendance(id, startDate, endDate);

  // 2. Format data for PDF generator
  const pdfData = {
    student: {
      name: `${student.user.firstName} ${student.user.lastName}`,
      admissionNo: student.admissionNumber,
      className: student.currentClass?.name,
      sectionName: student.section?.name,
    },
    attendance: attData.attendance,
    stats: attData.stats,
    subjectWise: attData.subjectWise,
    dateRange: {
      start: startDate || 'Start',
      end: endDate || 'Now'
    },
    schoolConfig: {
      schoolName: process.env.SCHOOL_NAME || 'EduSphere ERP'
    }
  };

  // 3. Generate PDF
  const buffer = await generateAttendanceReportPDF(pdfData);

  // 4. Send response
  res.set({
    'Content-Type': 'application/pdf',
    'Content-Disposition': `attachment; filename=Attendance_Report_${student.admissionNumber}.pdf`,
    'Content-Length': buffer.length,
  });

  res.status(200).send(buffer);
});

module.exports = {
  getStudents,
  getStudent,
  createStudent,
  updateStudent,
  deleteStudent,
  getStudentAttendance,
  registerStudent,
  getMeStudent,
  updateMeStudent,
  getAttendanceReport, // Export new method
};
