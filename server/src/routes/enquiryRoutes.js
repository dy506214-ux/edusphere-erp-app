const express = require('express');
const router = express.Router();
const enquiryController = require('../controllers/enquiryController');
const { authMiddleware, requireRole } = require('../middleware/auth');

// Basic crud and listing
router.get('/', authMiddleware, requireRole('SUPER_ADMIN', 'ADMIN', 'ADMISSION_MANAGER'), enquiryController.getEnquiries);
router.post('/', authMiddleware, requireRole('SUPER_ADMIN', 'ADMIN', 'ADMISSION_MANAGER'), enquiryController.createEnquiry);

router.get('/:id', authMiddleware, requireRole('SUPER_ADMIN', 'ADMIN', 'ADMISSION_MANAGER'), enquiryController.getEnquiryById);
router.put('/:id', authMiddleware, requireRole('SUPER_ADMIN', 'ADMIN', 'ADMISSION_MANAGER'), enquiryController.updateEnquiry);
router.delete('/:id', authMiddleware, requireRole('SUPER_ADMIN', 'ADMIN', 'ADMISSION_MANAGER'), enquiryController.deleteEnquiry);

// Follow-ups
router.post('/:id/follow-up', authMiddleware, requireRole('SUPER_ADMIN', 'ADMIN', 'ADMISSION_MANAGER'), enquiryController.addFollowUp);

module.exports = router;
