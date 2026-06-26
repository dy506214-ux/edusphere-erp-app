const express = require('express');
const router = express.Router();
const CalendarController = require('../controllers/calendarController');
const { authMiddleware, requireRole: authorize } = require('../middleware/auth');

// Publicly readable for all authenticated users
router.use(authMiddleware);

router.get('/', CalendarController.getEvents);
router.get('/upcoming', CalendarController.getUpcomingEvents);

// Administrative Mutations
router.post('/', authorize('ADMIN', 'SUPER_ADMIN', 'PRINCIPAL'), CalendarController.createEvent);
router.patch('/:id', authorize('ADMIN', 'SUPER_ADMIN', 'PRINCIPAL'), CalendarController.updateEvent);
router.delete('/:id', authorize('ADMIN', 'SUPER_ADMIN', 'PRINCIPAL'), CalendarController.deleteEvent);

module.exports = router;
