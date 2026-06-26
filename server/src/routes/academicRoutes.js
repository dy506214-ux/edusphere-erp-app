const express = require('express');
const {
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
} = require('../controllers/academicController');
const { authMiddleware, requireRole } = require('../middleware/auth');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

// Configure multer for timetable PDF uploads
const UPLOAD_DIR = path.join(__dirname, '..', '..', 'uploads', 'timetables');

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    if (!fs.existsSync(UPLOAD_DIR)) {
      fs.mkdirSync(UPLOAD_DIR, { recursive: true });
    }
    cb(null, UPLOAD_DIR);
  },
  filename: (req, file, cb) => {
    cb(null, `timetable-${Date.now()}${path.extname(file.originalname)}`);
  },
});

const upload = multer({
  storage,
  fileFilter: (req, file, cb) => {
    if (file.mimetype === 'application/pdf') {
      cb(null, true);
    } else {
      cb(new Error('Only PDF files are allowed'), false);
    }
  },
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
});

const router = express.Router();

router.use(authMiddleware);

// Dashboard
router.get('/dashboard', requireRole('SUPER_ADMIN', 'ADMIN'), getAcademicDashboardStats);

// Timetables
router.get('/timetables', requireRole('SUPER_ADMIN', 'ADMIN', 'TEACHER', 'STUDENT'), getTimetables);
router.post('/timetables', requireRole('SUPER_ADMIN', 'ADMIN'), upload.single('file'), createTimetable);
router.delete('/timetables/:id', requireRole('SUPER_ADMIN', 'ADMIN'), deleteTimetable);

// Academic Years
router.get('/years', requireRole('SUPER_ADMIN', 'ADMIN', 'TEACHER', 'ACCOUNTANT'), getAcademicYears);
router.post('/years', requireRole('SUPER_ADMIN', 'ADMIN'), createAcademicYear);
router.put('/years/:id/current', requireRole('SUPER_ADMIN', 'ADMIN'), setCurrentAcademicYear);

// Classes
router.get('/classes', requireRole('SUPER_ADMIN', 'ADMIN', 'TEACHER', 'ACCOUNTANT'), getClasses);
router.post('/classes', requireRole('SUPER_ADMIN', 'ADMIN'), createClass);
router.put('/classes/:id', requireRole('SUPER_ADMIN', 'ADMIN'), updateClass);
router.delete('/classes/:id', requireRole('SUPER_ADMIN', 'ADMIN'), deleteClass);

// Subjects
router.get('/subjects', requireRole('SUPER_ADMIN', 'ADMIN', 'TEACHER', 'STUDENT', 'PARENT'), getSubjects);
router.post('/subjects', requireRole('SUPER_ADMIN', 'ADMIN'), createSubject);
router.put('/subjects/:id', requireRole('SUPER_ADMIN', 'ADMIN'), updateSubject);
router.delete('/subjects/:id', requireRole('SUPER_ADMIN', 'ADMIN'), deleteSubject);
router.post('/subjects/assign', requireRole('SUPER_ADMIN', 'ADMIN'), assignSubjectTeacher);

// Sections
router.get('/sections', requireRole('SUPER_ADMIN', 'ADMIN', 'TEACHER', 'ACCOUNTANT', 'STUDENT'), getSections);
router.post('/sections', requireRole('SUPER_ADMIN', 'ADMIN'), createSection);
router.put('/sections/:id', requireRole('SUPER_ADMIN', 'ADMIN'), updateSection);
router.delete('/sections/:id', requireRole('SUPER_ADMIN', 'ADMIN'), deleteSection);

module.exports = router;

