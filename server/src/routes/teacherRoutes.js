const express = require('express');
const {
  getTeachers,
  getTeacher,
  createTeacher,
  updateTeacher,
  assignSubject,
  getMySchedule,
  getMyClasses,
} = require('../controllers/teacherController');
const { authMiddleware, requireRole } = require('../middleware/auth');

const router = express.Router();

router.use(authMiddleware);

router.get('/', getTeachers);
router.get('/my-classes', requireRole('TEACHER'), getMyClasses);
router.get('/my-schedule', requireRole('TEACHER'), getMySchedule);
router.get('/:id', getTeacher);
router.post('/', requireRole('SUPER_ADMIN', 'ADMIN'), createTeacher);
router.put('/:id', requireRole('SUPER_ADMIN', 'ADMIN'), updateTeacher);
router.post('/:id/subjects', requireRole('SUPER_ADMIN', 'ADMIN'), assignSubject);

module.exports = router;
