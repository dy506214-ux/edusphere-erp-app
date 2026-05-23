const express = require('express');
const { getConfig, uploadLogo, updateConfig } = require('../controllers/schoolConfigController');
const { authMiddleware, requireRole } = require('../middleware/auth');

const router = express.Router();

router.use(authMiddleware);

// Get school config (logo, name, etc.) — any authenticated user
router.get('/', getConfig);

// Upload school logo — SUPER_ADMIN only
router.post('/logo', requireRole('SUPER_ADMIN'), uploadLogo);

// Update any school config key — SUPER_ADMIN only
router.put('/', requireRole('SUPER_ADMIN'), updateConfig);

module.exports = router;
