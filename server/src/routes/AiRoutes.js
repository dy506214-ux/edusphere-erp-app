const express = require('express');
const router = express.Router();
const AiController = require('../controllers/AiController');
const { authMiddleware } = require('../middleware/auth');

/**
 * AI Assistant Routes
 * All routes are protected by authMiddleware to ensure role-based context works
 */

router.post('/init', authMiddleware, AiController.initChat);
router.post('/chat', authMiddleware, AiController.sendMessage);
router.post('/action', authMiddleware, AiController.executeAction);
router.post('/generate-smart-assignment', authMiddleware, AiController.generateSmartAssignment);

module.exports = router;
