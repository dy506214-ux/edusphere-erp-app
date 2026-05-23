const notificationService = require('../services/NotificationService');
const asyncHandler = require('../utils/asyncHandler');

const getNotifications = asyncHandler(async (req, res) => {
    const result = await notificationService.getNotifications(req.user.userId);
    res.status(200).json({
        success: true,
        ...result
    });
});

const markAsRead = asyncHandler(async (req, res) => {
    const { id } = req.params;
    await notificationService.markAsRead(id, req.user.userId);
    res.status(200).json({
        success: true,
        message: 'Notification marked as read'
    });
});

const markAllRead = asyncHandler(async (req, res) => {
    await notificationService.markAllRead(req.user.userId);
    res.status(200).json({
        success: true,
        message: 'All notifications marked as read'
    });
});

module.exports = {
    getNotifications,
    markAsRead,
    markAllRead
};
