const express = require('express');
const { createOrder, verifyPayment, getMyPaymentHistory } = require('../controllers/paymentController');
const { authMiddleware, requireRole } = require('../middleware/auth');

const router = express.Router();

router.use(authMiddleware);

// Create Razorpay order for a fee ledger
router.post('/create-order', requireRole('STUDENT', 'PARENT'), createOrder);

// Verify Razorpay payment after checkout
router.post('/verify', requireRole('STUDENT', 'PARENT'), verifyPayment);

// Get my payment history
router.get('/my-history', requireRole('STUDENT', 'PARENT'), getMyPaymentHistory);

module.exports = router;
