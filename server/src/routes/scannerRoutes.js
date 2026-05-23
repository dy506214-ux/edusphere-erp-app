const express = require('express');
const {
    getScanners,
    createScanner,
    getScannerById,
    updateScanner,
    deleteScanner,
    getScannerStats,
} = require('../controllers/scannerController');
const { authMiddleware, requireRole } = require('../middleware/auth');

const router = express.Router();

router.use(authMiddleware);

// List all scanners
router.get('/', requireRole('SUPER_ADMIN', 'ADMIN', 'HR_MANAGER'), getScanners);
// Create scanner
router.post('/', requireRole('SUPER_ADMIN', 'ADMIN'), createScanner);
// Get scanner (also used by the live scan page to load scanner meta)
router.get('/:id', requireRole('SUPER_ADMIN', 'ADMIN', 'HR_MANAGER', 'TEACHER'), getScannerById);
// Update scanner
router.put('/:id', requireRole('SUPER_ADMIN', 'ADMIN'), updateScanner);
// Deactivate scanner (soft delete)
router.delete('/:id', requireRole('SUPER_ADMIN'), deleteScanner);
// Stats
router.get('/:id/stats', requireRole('SUPER_ADMIN', 'ADMIN', 'HR_MANAGER'), getScannerStats);

module.exports = router;
