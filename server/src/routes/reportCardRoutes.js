const express = require('express');
const {
    generateReportCards,
    getReportCards,
    submitReportCard,
    bulkSubmitReportCards,
    approveReportCard,
    bulkApproveReportCards,
    rejectReportCard,
    downloadReportCard,
    bulkPublishReportCards,
    getReportTemplates,
    createReportTemplate,
    updateReportTemplate,
} = require('../controllers/reportCardController');
const { authMiddleware, requireRole } = require('../middleware/auth');

const router = express.Router();

router.use(authMiddleware);

// Get report cards (any authenticated user with appropriate filters)
router.get('/', getReportCards);

// Reports Template Management (Admin only)
router.get('/templates', requireRole('SUPER_ADMIN', 'ADMIN'), getReportTemplates);
router.post('/templates', requireRole('SUPER_ADMIN', 'ADMIN'), createReportTemplate);
router.put('/templates/:id', requireRole('SUPER_ADMIN', 'ADMIN'), updateReportTemplate);

// Generate (class teacher)
router.post('/generate', requireRole('SUPER_ADMIN', 'ADMIN', 'TEACHER'), generateReportCards);

// Submit for approval (class teacher)
router.put('/:id/submit', requireRole('SUPER_ADMIN', 'ADMIN', 'TEACHER'), submitReportCard);
router.post('/bulk-submit', requireRole('SUPER_ADMIN', 'ADMIN', 'TEACHER'), bulkSubmitReportCards);

// Approve / reject (principal only)
router.put('/:id/approve', requireRole('SUPER_ADMIN'), approveReportCard);
router.post('/bulk-approve', requireRole('SUPER_ADMIN'), bulkApproveReportCards);
router.put('/:id/reject', requireRole('SUPER_ADMIN'), rejectReportCard);

// Publish results to students (Class Teacher or Admin)
router.post('/publish', requireRole('SUPER_ADMIN', 'ADMIN', 'TEACHER'), bulkPublishReportCards);

// PDF Download
router.get('/:id/pdf', downloadReportCard);

module.exports = router;
