const crypto = require('crypto');
const razorpay = require('../config/razorpay');
const prisma = require('../config/database');
const feeService = require('../services/feeService');
const { getSchoolDate } = require('../utils/dateUtils');
const { getConfigValue } = require('../utils/configHelper');
const { DEFAULTS, ROLES } = require('../constants');
const asyncHandler = require('../utils/asyncHandler');
const logger = require('../config/logger');

/**
 * Create a Razorpay order for a specific fee ledger
 * POST /api/payments/create-order
 * Body: { ledgerId, amount }
 */
const createOrder = asyncHandler(async (req, res) => {
    const { ledgerId, amount } = req.body;
    const userId = req.user.userId || req.user.id;

    logger.info(`Creating payment order: ledgerId=${ledgerId}, amount=${amount}, userId=${userId}`);

    if (!ledgerId || !amount || amount <= 0) {
        logger.warn(`Invalid order request: ledgerId=${ledgerId}, amount=${amount}`);
        return res.status(400).json({ 
            success: false,
            message: 'ledgerId and a positive amount are required' 
        });
    }

    // Verify the ledger exists and belongs to this student
    const ledger = await prisma.studentFeeLedger.findUnique({
        where: { id: ledgerId },
        include: {
            student: { select: { userId: true } },
            feeStructure: { select: { name: true } },
        },
    });

    if (!ledger) {
        return res.status(404).json({ 
            success: false,
            message: 'Fee ledger not found' 
        });
    }

    // Students can only pay their own fees
    if (req.user.role === ROLES.STUDENT && ledger.student.userId !== userId) {
        return res.status(403).json({ 
            success: false,
            message: 'You can only pay your own fees' 
        });
    }

    if (ledger.totalPending <= 0) {
        return res.status(400).json({ 
            success: false,
            message: 'This fee is already fully paid' 
        });
    }

    // Cap amount to what's actually pending
    const payableAmount = Math.min(parseFloat(amount), ledger.totalPending);

    // Create Razorpay order (amount in paise)
    const orderOptions = {
        amount: Math.round(payableAmount * 100),
        currency: await getConfigValue('fee_currency', DEFAULTS.CURRENCY),
        receipt: `f_${ledgerId.substring(0, 8)}_${Date.now()}`,
        notes: {
            ledgerId,
            studentId: ledger.studentId,
            feeType: ledger.feeStructure.name,
        },
    };

    let order;
    try {
        order = await razorpay.orders.create(orderOptions);
    } catch (rpError) {
        logger.error(`Razorpay order creation failed: ${rpError.message}`, rpError);
        return res.status(rpError.statusCode || 400).json({
            success: false,
            message: rpError.message || 'Razorpay order creation failed'
        });
    }

    logger.info(`Razorpay order ${order.id} created for ledger ${ledgerId}`);

    res.status(201).json({
        success: true,
        orderId: order.id,
        razorpayKeyId: process.env.RAZORPAY_KEY_ID,
        amount: payableAmount,
        amountInPaise: order.amount,
        currency: order.currency,
        ledgerId,
        feeType: ledger.feeStructure.name,
    });
});

/**
 * Verify Razorpay payment signature and record the payment
 * POST /api/payments/verify
 * Body: { razorpayOrderId, razorpayPaymentId, razorpaySignature, ledgerId }
 */
const verifyPayment = asyncHandler(async (req, res) => {
    const { razorpayOrderId, razorpayPaymentId, razorpaySignature, ledgerId } = req.body;
    const userId = req.user.userId || req.user.id;

    if (!razorpayOrderId || !razorpayPaymentId || !razorpaySignature || !ledgerId) {
        return res.status(400).json({ 
            success: false,
            message: 'All payment fields are required' 
        });
    }

    // Verify HMAC signature
    const expectedSignature = crypto
        .createHmac('sha256', process.env.RAZORPAY_KEY_SECRET)
        .update(`${razorpayOrderId}|${razorpayPaymentId}`)
        .digest('hex');

    if (expectedSignature !== razorpaySignature) {
        return res.status(400).json({ 
            success: false,
            message: 'Payment verification failed — invalid signature' 
        });
    }

    // Fetch the Razorpay order to get the amount
    const rpOrder = await razorpay.orders.fetch(razorpayOrderId);
    const amountPaid = rpOrder.amount / 100; // Convert paise to rupees

    // Fetch ledger details
    const ledger = await prisma.studentFeeLedger.findUnique({
        where: { id: ledgerId },
        include: {
            student: { select: { userId: true } },
            feeStructure: true,
        },
    });

    if (!ledger) {
        return res.status(404).json({ 
            success: false,
            message: 'Ledger not found' 
        });
    }

    // Record the payment via the existing fee service
    const payment = await feeService.createFeePayment(
        {
            studentId: ledger.studentId,
            ledgerId: ledger.id,
            amount: amountPaid,
            paymentMode: 'ONLINE',
            transactionId: razorpayPaymentId,
            forMonth: getSchoolDate().getMonth() + 1,
            forYear: getSchoolDate().getFullYear(),
        },
        userId,
    );

    // Update the payment record with Razorpay IDs
    if (payment && payment.id) {
        await prisma.feePayment.update({
            where: { id: payment.id },
            data: {
                razorpayOrderId,
                razorpayPaymentId,
                razorpaySignature,
            },
        });
    }

    logger.info(`Payment verified: ${razorpayPaymentId}, amount: ${amountPaid}`);

    res.status(200).json({
        success: true,
        message: 'Payment verified and recorded successfully',
        payment,
        amountPaid,
    });
});

/**
 * Get the logged-in student's payment history
 * GET /api/payments/my-history
 */
const getMyPaymentHistory = asyncHandler(async (req, res) => {
    const userId = req.user.userId || req.user.id;

    const student = await prisma.student.findFirst({ where: { userId } });
    if (!student) {
        return res.status(404).json({ 
            success: false,
            message: 'Student profile not found' 
        });
    }

    const payments = await prisma.feePayment.findMany({
        where: { studentId: student.id },
        include: {
            feeStructure: { select: { name: true } },
            ledger: { select: { totalPayable: true, totalPaid: true, totalPending: true } },
        },
        orderBy: { paymentDate: 'desc' },
        take: 20,
    });

    res.status(200).json({ 
        success: true,
        payments 
    });
});

module.exports = { createOrder, verifyPayment, getMyPaymentHistory };
