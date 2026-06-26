const express = require('express');
const {
  createAssignment,
  getStudentAssignments,
  getTeacherAssignments,
  getAssignmentDetails,
  deleteAssignment,
} = require('../controllers/assignmentController');
const {
  submitAssignment,
  gradeSubmission,
} = require('../controllers/submissionController');
const { authMiddleware, requireRole } = require('../middleware/auth');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

const router = express.Router();

// Configure multer for file uploads
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const isSubmission = req.path.includes('submit');
    const folder = isSubmission ? 'submissions' : 'assignments';
    const uploadPath = path.join(__dirname, '..', '..', 'uploads', folder);
    
    if (!fs.existsSync(uploadPath)) {
      fs.mkdirSync(uploadPath, { recursive: true });
    }
    cb(null, uploadPath);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, file.fieldname + '-' + uniqueSuffix + path.extname(file.originalname));
  },
});

const upload = multer({ 
  storage,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB
});

router.use(authMiddleware);

// Assignment routes
router.post('/', requireRole('SUPER_ADMIN', 'ADMIN', 'TEACHER'), upload.single('file'), createAssignment);
router.get('/student', requireRole('STUDENT'), getStudentAssignments);
router.get('/teacher', requireRole('SUPER_ADMIN', 'ADMIN', 'TEACHER'), getTeacherAssignments);
router.get('/:id', requireRole('SUPER_ADMIN', 'ADMIN', 'TEACHER', 'STUDENT'), getAssignmentDetails);
router.delete('/:id', requireRole('SUPER_ADMIN', 'ADMIN', 'TEACHER'), deleteAssignment);

// Submission routes
router.post('/submit', requireRole('STUDENT'), upload.single('file'), submitAssignment);
router.put('/submissions/:submissionId/grade', requireRole('SUPER_ADMIN', 'ADMIN', 'TEACHER'), gradeSubmission);

module.exports = router;
