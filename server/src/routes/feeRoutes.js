const express = require('express');
const {
  getFeeStructures,
  getFeeStructureById,
  updateFeeStructure,
  deleteFeeStructure,
  getFeeStudents,
  createFeeStructure,
  getFeePayments,
  createFeePayment,
  getStudentFeeStatus,
  requestAdjustment,
  approveAdjustment,
  processRefund,
  getAdjustments,
  getFeeStats,
  downloadFeeStatement
} = require('../controllers/feeController');
const { authMiddleware, requireRole } = require('../middleware/auth');

// Zod Validation Middleware and Schemas
const validate = require('../middleware/validate');
const {
  createFeeStructureSchema,
  createFeePaymentSchema,
  requestAdjustmentSchema,
  approveAdjustmentSchema,
  processRefundSchema,
} = require('../validators/feeValidator');

const router = express.Router();

router.use(authMiddleware);

// Fee structures
router.get('/structures', requireRole('SUPER_ADMIN', 'ADMIN', 'ACCOUNTANT'), getFeeStructures);
router.get('/structures/:id', requireRole('SUPER_ADMIN', 'ADMIN', 'ACCOUNTANT'), getFeeStructureById);
router.post('/structures', requireRole('SUPER_ADMIN', 'ADMIN'), validate(createFeeStructureSchema), createFeeStructure);
router.put('/structures/:id', requireRole('SUPER_ADMIN', 'ADMIN'), validate(createFeeStructureSchema), updateFeeStructure);
router.delete('/structures/:id', requireRole('SUPER_ADMIN', 'ADMIN'), deleteFeeStructure);

// Fee Students List
router.get('/students', requireRole('SUPER_ADMIN', 'ADMIN', 'ACCOUNTANT'), getFeeStudents);

// Fee payments
router.get('/payments', requireRole('SUPER_ADMIN', 'ADMIN', 'ACCOUNTANT'), getFeePayments);
router.post('/payments', requireRole('SUPER_ADMIN', 'ADMIN', 'ACCOUNTANT'), validate(createFeePaymentSchema), createFeePayment);

// Adjustments (Discounts & Scholarships)
router.get('/stats', requireRole('SUPER_ADMIN', 'ADMIN', 'ACCOUNTANT'), getFeeStats);
router.get('/adjustments', requireRole('SUPER_ADMIN', 'ADMIN', 'ACCOUNTANT'), getAdjustments);
router.post('/adjustments/request', requireRole('SUPER_ADMIN', 'ADMIN', 'ACCOUNTANT'), validate(requestAdjustmentSchema), requestAdjustment);
router.put('/adjustments/:id/approve', requireRole('SUPER_ADMIN', 'ADMIN'), validate(approveAdjustmentSchema), approveAdjustment);

// Refunds
router.post('/refunds', requireRole('SUPER_ADMIN', 'ADMIN', 'ACCOUNTANT'), validate(processRefundSchema), processRefund);

// Student fee status/ledger
router.get('/students/:id/status', requireRole('SUPER_ADMIN', 'ADMIN', 'ACCOUNTANT', 'STUDENT', 'PARENT'), getStudentFeeStatus);
router.get('/students/:id/statement', requireRole('SUPER_ADMIN', 'ADMIN', 'ACCOUNTANT', 'STUDENT', 'PARENT'), downloadFeeStatement);

module.exports = router;
