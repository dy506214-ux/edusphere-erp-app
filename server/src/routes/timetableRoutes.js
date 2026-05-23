const express = require('express');
const router = express.Router();
const TimetableController = require('../controllers/TimetableController');
const { authMiddleware, requireRole } = require('../middleware/auth');

// Auth for all routes
router.use(authMiddleware);

/**
 * Configuration & Wizard
 */
router.get('/config', requireRole('ADMIN', 'SUPER_ADMIN'), TimetableController.getConfig);
router.put('/config/:classId', requireRole('ADMIN', 'SUPER_ADMIN'), TimetableController.updateConfig);
router.post('/generate-baseline/:timetableId?', requireRole('ADMIN', 'SUPER_ADMIN'), TimetableController.generateBaseline);

/**
 * Slot Management
 */
router.patch('/slots/:slotId', requireRole('ADMIN', 'SUPER_ADMIN'), TimetableController.updateSlot);

/**
 * Profile-specific Schedules
 */
router.get('/teacher/:teacherId', TimetableController.getTeacherSchedule);
router.get('/student/:sectionId', TimetableController.getStudentSchedule);

/**
 * Room Management
 */
router.get('/rooms', TimetableController.getRooms);
router.post('/rooms', requireRole('ADMIN', 'SUPER_ADMIN'), TimetableController.createRoom);

module.exports = router;
