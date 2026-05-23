const express = require('express');
const router = express.Router();
const { authMiddleware, requireRole } = require('../middleware/auth');
const {
  getAllUsers,
  getUserById,
  createUser,
  updateUser,
  deleteUser,
  updateUserRoles,
  getUsersByRole,
  resetPassword,
  updateProfilePicture,
  uploadProfilePicture,
  getUserQR,
  regenerateUserQR,
  toggleQRIssued,
  changePassword,
} = require('../controllers/userController');

// All user management routes require authentication
router.use(authMiddleware);

// ── Self-service routes ──
router.post('/me/change-password', changePassword);

// Get all users (paginated with filters) - Admin only
router.get('/', requireRole('SUPER_ADMIN', 'ADMIN'), getAllUsers);

// Get users by role - Admin only
router.get('/role/:role', requireRole('SUPER_ADMIN', 'ADMIN'), getUsersByRole);

// ── QR Code routes (MUST be before /:id to avoid Express matching /:id/qr as id="qr") ──
// Get QR code - user can get own QR, admin can get any
router.get('/:id/qr', getUserQR);
// Regenerate QR code - Admin only
router.post('/:id/qr/regenerate', requireRole('SUPER_ADMIN', 'ADMIN'), regenerateUserQR);
// Toggle QR Issued Status - Admin only
router.post('/:id/qr/status', requireRole('SUPER_ADMIN', 'ADMIN'), toggleQRIssued);

// Get single user by ID - Admin or self (permission check in controller)
router.get('/:id', getUserById);

// Create new user - Admin only
router.post('/', requireRole('SUPER_ADMIN', 'ADMIN'), createUser);

// Update user - Admin only
router.put('/:id', requireRole('SUPER_ADMIN', 'ADMIN'), updateUser);

// Update user roles - Admin only
router.patch('/:id/roles', requireRole('SUPER_ADMIN', 'ADMIN'), updateUserRoles);

// Reset user password - Admin only
router.post('/:id/reset-password', requireRole('SUPER_ADMIN', 'ADMIN'), resetPassword);

// Update profile picture - Anyone for their own account, or Admin for anyone
router.patch('/:id/avatar', uploadProfilePicture, updateProfilePicture);

// Delete user (soft delete) - Super Admin only
router.delete('/:id', requireRole('SUPER_ADMIN'), deleteUser);

module.exports = router;
