const express = require('express');
const {
  getExams,
  getExam,
  createExam,
  updateExam,
  deleteExam,
  addSubjectToExam,
  enterMarks,
  getConsolidatedMarks,
  freezeExam,
  unfreezeExam,
  submitExamResults,
  getStudentExamResults,
  getExamResultsReport,
  getTeacherExams,
} = require('../controllers/examController');
const { authMiddleware, requireRole } = require('../middleware/auth');
const validate = require('../middleware/validate');
const { examCreateSchema, enterMarksSchema, addSubjectSchema } = require('../validators/examValidator');

const router = express.Router();

router.use(authMiddleware);

// Exam management
router.get('/', getExams);
router.get('/teacher-tasks', requireRole('TEACHER'), getTeacherExams);

// Results — MUST be above /:id to avoid collision
router.post('/results', requireRole('SUPER_ADMIN', 'ADMIN', 'TEACHER'), submitExamResults);
router.get('/students/:studentId/results', getStudentExamResults);

// Single exam — wildcard /:id must come LAST in this group
router.get('/:id', requireRole('SUPER_ADMIN', 'ADMIN', 'TEACHER', 'STUDENT'), getExam);
router.post('/', requireRole('SUPER_ADMIN', 'ADMIN'), validate(examCreateSchema), createExam);
router.put('/:id', requireRole('SUPER_ADMIN', 'ADMIN'), updateExam);
router.delete('/:id', requireRole('SUPER_ADMIN', 'ADMIN'), deleteExam);

// Exam subjects
router.post('/:id/subjects', requireRole('SUPER_ADMIN', 'ADMIN'), validate(addSubjectSchema), addSubjectToExam);

// Marks entry (subject teacher)
router.post('/:examId/marks', requireRole('SUPER_ADMIN', 'ADMIN', 'TEACHER'), validate(enterMarksSchema), enterMarks);

// Consolidated marks (class teacher / admin)
router.get('/:examId/consolidated', requireRole('SUPER_ADMIN', 'ADMIN', 'TEACHER'), getConsolidatedMarks);

// Freeze / Unfreeze (admin only)
router.put('/:examId/freeze', requireRole('SUPER_ADMIN', 'ADMIN'), freezeExam);
router.put('/:examId/unfreeze', requireRole('SUPER_ADMIN', 'ADMIN'), unfreezeExam);

// Exam report - restricted to staff
router.get('/:examId/report', requireRole('SUPER_ADMIN', 'ADMIN', 'TEACHER'), getExamResultsReport);

module.exports = router;
