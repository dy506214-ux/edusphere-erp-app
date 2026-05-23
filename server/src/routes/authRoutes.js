const express = require('express');
const { register, login, getMe, logout } = require('../controllers/authController');
const { authMiddleware, requireRole } = require('../middleware/auth');

const router = express.Router();

// Auth routes
router.post('/login', login);
router.post('/register', authMiddleware, requireRole('ADMIN'), register);
router.post('/logout', authMiddleware, logout);
router.get('/me', authMiddleware, getMe);

module.exports = router;
