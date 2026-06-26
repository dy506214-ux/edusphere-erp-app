const express = require('express');
const {
    getServiceRequests,
    createServiceRequest,
    updateServiceRequest,
} = require('../controllers/serviceController');
const { authMiddleware, requireRole } = require('../middleware/auth');

const router = express.Router();

router.use(authMiddleware);

// Get service requests
router.get('/', getServiceRequests);

// Create service request
router.post('/', createServiceRequest);

// Update status (Admin/Teacher)
router.patch('/:id', requireRole('SUPER_ADMIN', 'ADMIN', 'TEACHER'), updateServiceRequest);

module.exports = router;
