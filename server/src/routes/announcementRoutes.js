const express = require('express');
const {
  getAnnouncements,
  getAnnouncement,
  createAnnouncement,
  updateAnnouncement,
  deleteAnnouncement,
  getActiveAnnouncementsForUser,
} = require('../controllers/announcementController');
const { authMiddleware, requireRole } = require('../middleware/auth');

const router = express.Router();

router.use(authMiddleware);

// Announcement management
router.get('/', getAnnouncements);
router.get('/active', getActiveAnnouncementsForUser);
router.get('/:id', getAnnouncement);
router.post('/', requireRole('SUPER_ADMIN', 'ADMIN', 'TEACHER'), createAnnouncement);
router.put('/:id', requireRole('SUPER_ADMIN', 'ADMIN', 'TEACHER'), updateAnnouncement);
router.delete('/:id', requireRole('SUPER_ADMIN', 'ADMIN'), deleteAnnouncement);

module.exports = router;
