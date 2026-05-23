const express = require('express');
const {
    getNotifications,
    markAsRead,
    markAllRead
} = require('../controllers/notificationController');
const { authMiddleware } = require('../middleware/auth');

const router = express.Router();

router.use(authMiddleware);

router.get('/', getNotifications);
router.put('/:id/read', markAsRead);
router.put('/mark-all-read', markAllRead);

module.exports = router;
