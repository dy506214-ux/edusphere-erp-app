const express = require('express');
const {
  getStudents,
  getStudent,
  createStudent,
  updateStudent,
  deleteStudent,
  getStudentAttendance,
  getAttendanceReport, // Import new method
  registerStudent,
  getMeStudent,
  updateMeStudent
} = require('../controllers/studentController');
const {
  uploadDocument,
  getStudentDocuments,
  deleteDocument
} = require('../controllers/studentDocumentController');
const { authMiddleware, requireRole } = require('../middleware/auth');

// Zod Validation Middleware and Schemas
const validate = require('../middleware/validate');
const {
  createStudentSchema,
  updateStudentSchema,
  registerStudentSchema
} = require('../validators/studentValidator');

const router = express.Router();

// All routes require authentication
router.use(authMiddleware);

// Get all students — Admins, Teachers, Accountants (read-only), Admission Managers
router.get('/', requireRole('SUPER_ADMIN', 'ADMIN', 'TEACHER', 'ACCOUNTANT', 'ADMISSION_MANAGER'), getStudents);

// Get current student profile
router.get('/me', requireRole('STUDENT', 'PARENT'), getMeStudent);

// Update current student profile
router.put('/me', requireRole('STUDENT', 'PARENT'), updateMeStudent);

// Get single student — same as list
router.get('/:id', requireRole('SUPER_ADMIN', 'ADMIN', 'TEACHER', 'ACCOUNTANT', 'ADMISSION_MANAGER'), getStudent);

// Get student attendance
router.get('/:id/attendance', requireRole('SUPER_ADMIN', 'ADMIN', 'TEACHER', 'STUDENT', 'PARENT', 'ADMISSION_MANAGER'), getStudentAttendance);

// Get attendance report (PDF)
router.get('/:id/attendance/report', requireRole('SUPER_ADMIN', 'ADMIN', 'TEACHER', 'STUDENT', 'PARENT', 'ADMISSION_MANAGER'), getAttendanceReport);

// Create student (Admin / Admission Manager only — Accountant removed)
router.post(
  '/',
  requireRole('SUPER_ADMIN', 'ADMIN', 'ADMISSION_MANAGER'),
  validate(createStudentSchema),
  createStudent
);

// Register student — comprehensive (Admin / Admission Manager only — Accountant removed)
router.post(
  '/register',
  requireRole('SUPER_ADMIN', 'ADMIN', 'ADMISSION_MANAGER'),
  validate(registerStudentSchema),
  registerStudent
);

// Update student (Admin / Admission Manager only)
router.put(
  '/:id',
  requireRole('SUPER_ADMIN', 'ADMIN', 'ADMISSION_MANAGER'),
  validate(updateStudentSchema),
  updateStudent
);

// Delete student (Admin only)
router.delete('/:id', requireRole('SUPER_ADMIN', 'ADMIN'), deleteStudent);

// Student Documents
router.post('/:id/documents', requireRole('SUPER_ADMIN', 'ADMIN', 'TEACHER', 'STUDENT'), uploadDocument);
router.get('/:id/documents', requireRole('SUPER_ADMIN', 'ADMIN', 'TEACHER', 'STUDENT', 'PARENT'), getStudentDocuments);
router.delete('/documents/:documentId', requireRole('SUPER_ADMIN', 'ADMIN', 'STUDENT'), deleteDocument);

module.exports = router;
