const express = require('express');
const router = express.Router();
const { authMiddleware, requireRole } = require('../middleware/auth');
const {
    getSalaryStructures,
    setSalaryStructure,
    generatePayroll,
    getPayrollList,
    markPaid,
    updatePayrollDays,
    getMyPayroll,
} = require('../controllers/payrollController');

const HR_ROLES = ['SUPER_ADMIN', 'ADMIN', 'HR_MANAGER'];
const PAY_ROLES = ['SUPER_ADMIN', 'ADMIN', 'ACCOUNTANT', 'HR_MANAGER'];

router.use(authMiddleware);

// Salary structures
router.get('/salary-structures', requireRole(...HR_ROLES), getSalaryStructures);
router.post('/salary-structures', requireRole(...HR_ROLES), setSalaryStructure);

// Personal payroll
router.get('/my', getMyPayroll);

// Payroll for a specific month/year
router.get('/:month/:year', requireRole(...PAY_ROLES), getPayrollList);

// Generate payroll records for a month/year
router.post('/generate/:month/:year', requireRole(...HR_ROLES), generatePayroll);

// Mark individual payroll as paid
router.patch('/:id/pay', requireRole(...PAY_ROLES), markPaid);

// Update present/absent days on a payroll record
router.patch('/:id/days', requireRole(...HR_ROLES), updatePayrollDays);

module.exports = router;
