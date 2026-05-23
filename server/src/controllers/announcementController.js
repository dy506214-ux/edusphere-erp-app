const announcementService = require('../services/AnnouncementService');
const asyncHandler = require('../utils/asyncHandler');

// Get all announcements
const getAnnouncements = asyncHandler(async (req, res) => {
  const result = await announcementService.getAnnouncements(req.query);
    res.status(200).json({ 
        success: true,
        ...result 
    });
});

// Get single announcement
const getAnnouncement = asyncHandler(async (req, res) => {
  const announcement = await announcementService.getAnnouncementById(req.params.id);
    res.status(200).json({ 
        success: true,
        announcement 
    });
});

// Create announcement
const createAnnouncement = asyncHandler(async (req, res) => {
  const announcement = await announcementService.createAnnouncement(req.body, req.user.userId || req.user.id);
    res.status(201).json({
        success: true,
        message: 'Announcement created successfully',
        announcement,
    });
});

// Update announcement
const updateAnnouncement = asyncHandler(async (req, res) => {
  const announcement = await announcementService.updateAnnouncement(req.params.id, req.body);
    res.status(200).json({
        success: true,
        message: 'Announcement updated successfully',
        announcement,
    });
});

// Delete announcement
const deleteAnnouncement = asyncHandler(async (req, res) => {
  await announcementService.deleteAnnouncement(req.params.id);
    res.status(200).json({ 
        success: true,
        message: 'Announcement deleted successfully' 
    });
});

// Get active announcements for user
const getActiveAnnouncementsForUser = asyncHandler(async (req, res) => {
  const result = await announcementService.getActiveAnnouncementsForUser(req.user);
  res.status(200).json({ 
    success: true,
    ...result 
  });
});

module.exports = {
  getAnnouncements,
  getAnnouncement,
  createAnnouncement,
  updateAnnouncement,
  deleteAnnouncement,
  getActiveAnnouncementsForUser,
};
