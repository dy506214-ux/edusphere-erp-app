const express = require('express');
const {
    manualBackup,
    getBackupHistory,
} = require('../controllers/backupController');
const { authMiddleware, requireRole } = require('../middleware/auth');

const router = express.Router();

// All backup routes are strictly for SUPER_ADMIN
router.use(authMiddleware);
router.use(requireRole('SUPER_ADMIN'));

// Trigger a new backup
router.post('/trigger', manualBackup);

// Get backup list
router.get('/history', getBackupHistory);

module.exports = router;
