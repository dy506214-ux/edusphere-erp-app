const express = require('express');
const {
  markAttendance,
  getAttendanceByDate,
  handleRFIDScan,
  handleQRScan,
  bulkMarkAttendance,
  getAttendanceReport,
  createSlot,
  getSlots,
  getSlotWithStudents,
  deleteSlot,
  submitSlotAttendance,
  submitStaffAttendance,
  getAttendanceAnalytics,
  getMyAttendance,
} = require('../controllers/attendanceController');
const { authMiddleware, requireRole } = require('../middleware/auth');
const validate = require('../middleware/validate');
const { 
  markAttendanceSchema, 
  bulkMarkSchema, 
  qrScanSchema, 
  submitSlotSchema 
} = require('../validators/attendanceValidator');

const router = express.Router();

// Public/Kiosk routes
router.post('/qr-scan', validate(qrScanSchema), handleQRScan);
router.post('/rfid-scan', handleRFIDScan);

// Authenticated routes below
router.use(authMiddleware);
router.get('/my', getMyAttendance);

router.post('/mark', requireRole('SUPER_ADMIN', 'ADMIN', 'TEACHER'), validate(markAttendanceSchema), markAttendance);
router.get('/date', getAttendanceByDate);
router.post('/bulk', requireRole('SUPER_ADMIN', 'ADMIN', 'TEACHER'), validate(bulkMarkSchema), bulkMarkAttendance);
router.get('/report', getAttendanceReport);
router.get('/analytics', requireRole('SUPER_ADMIN', 'ADMIN', 'TEACHER'), getAttendanceAnalytics);

// Slot routes
router.post('/slots', requireRole('SUPER_ADMIN', 'ADMIN', 'TEACHER'), createSlot);
router.get('/slots', requireRole('SUPER_ADMIN', 'ADMIN', 'TEACHER'), getSlots);
router.get('/slots/:id', requireRole('SUPER_ADMIN', 'ADMIN', 'TEACHER'), getSlotWithStudents);
router.delete('/slots/:id', requireRole('SUPER_ADMIN', 'ADMIN', 'TEACHER'), deleteSlot);
router.post('/slots/:id/submit', requireRole('SUPER_ADMIN', 'ADMIN', 'TEACHER'), validate(submitSlotSchema), submitSlotAttendance);
router.post('/staff-batch', requireRole('SUPER_ADMIN', 'ADMIN', 'HR_MANAGER'), submitStaffAttendance);

module.exports = router;
