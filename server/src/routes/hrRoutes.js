const express = require('express');
const router = express.Router();
const { authMiddleware, requireRole } = require('../middleware/auth');
const {
    getEmployees,
    getEmployee,
    createEmployee,
    updateEmployee,
    toggleEmployeeStatus,
} = require('../controllers/hrController');
const validate = require('../middleware/validate');
const { hrCreateEmployeeSchema } = require('../validators/userValidator');
const {
    initializeLeaveBalances,
    getMyBalances,
    createLeaveRequest,
    processLeaveRequest,
} = require('../controllers/leaveController');
const {
    createPerformanceReview,
    getEmployeeReviews,
    acknowledgeReview,
} = require('../controllers/perfReviewController');

const HR_ROLES = ['SUPER_ADMIN', 'ADMIN', 'HR_MANAGER'];

router.use(authMiddleware);

// List all employees (Teachers + Staff)
router.get('/', requireRole(...HR_ROLES), getEmployees);

// Get single employee
router.get('/:id', requireRole(...HR_ROLES), getEmployee);

// Create new employee
router.post('/', requireRole(...HR_ROLES), validate(hrCreateEmployeeSchema), createEmployee);

// Update employee profile
router.put('/:id', requireRole(...HR_ROLES), updateEmployee);

// Toggle active/inactive status
router.patch('/:id/status', requireRole(...HR_ROLES), toggleEmployeeStatus);

// Leave management
router.post('/leaves/initialize', requireRole('SUPER_ADMIN', 'HR_MANAGER'), initializeLeaveBalances);
router.get('/leaves/my-balances', getMyBalances);
router.post('/leaves/request', createLeaveRequest);
router.post('/leaves/:id/process', requireRole('SUPER_ADMIN', 'HR_MANAGER', 'PRINCIPAL', 'HOD'), processLeaveRequest);

// Performance Reviews
router.post('/reviews', requireRole('SUPER_ADMIN', 'HR_MANAGER', 'PRINCIPAL'), createPerformanceReview);
router.get('/:employeeId/reviews', getEmployeeReviews);
router.patch('/reviews/:id/acknowledge', acknowledgeReview);

module.exports = router;
