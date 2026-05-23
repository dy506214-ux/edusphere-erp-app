const { z } = require('zod');

// Schema for fee structure creation
const createFeeStructureSchema = z.object({
    name: z.string().min(1, 'Name is required'),
    description: z.string().optional(),
    classId: z.string().uuid('Invalid Class ID').nullable().optional(),
    academicYearId: z.string().uuid('Invalid Academic Year ID'),
    frequency: z.enum(['ONE_TIME', 'MONTHLY', 'QUARTERLY', 'HALF_YEARLY', 'YEARLY']),
    dueDay: z.coerce.number().int().min(1).max(31).optional().default(10),
    earlyPaymentDiscount: z.coerce.number().min(0).optional().default(0),
    latePaymentPenalty: z.coerce.number().min(0).optional().default(0),
    feeHeads: z.array(z.object({
        headName: z.enum(['TUITION', 'EXAM', 'TRANSPORT', 'LATE_FEE', 'MISC']),
        amount: z.coerce.number().min(0, 'Amount must be a positive number')
    })).min(1, 'At least one fee head is required'),
});

// Schema for creating a fee payment
const createFeePaymentSchema = z.object({
    studentId: z.string().uuid('Invalid Student ID'),
    ledgerId: z.string().uuid('Invalid Ledger ID'),
    amount: z.coerce.number().positive('Amount must be positive'),
    paymentMode: z.enum(['CASH', 'CHEQUE', 'CARD', 'UPI', 'NET_BANKING', 'OTHER']),
    transactionId: z.string().optional(),
    forMonth: z.coerce.number().int().min(1).max(12).optional(),
    forYear: z.coerce.number().int().min(2000).max(2100).optional(),
});

// Schema for requesting a fee adjustment
const requestAdjustmentSchema = z.object({
    studentId: z.string().uuid('Invalid Student ID'),
    ledgerId: z.string().uuid('Invalid Ledger ID'),
    type: z.enum(['DISCOUNT', 'SCHOLARSHIP', 'REFUND', 'PENALTY_WAIVER']),
    amount: z.coerce.number().positive('Amount must be positive'),
    reason: z.string().min(5, 'Reason is required and should be descriptive'),
});

// Schema for approving/rejecting a fee adjustment
const approveAdjustmentSchema = z.object({
    status: z.enum(['APPROVED', 'REJECTED']),
});

// Schema for processing a refund
const processRefundSchema = z.object({
    originalReceiptNumber: z.string().min(1, 'Original receipt number is required'),
    amount: z.coerce.number().positive('Refund amount must be positive'),
    reason: z.string().min(5, 'Reason for refund is required'),
});

module.exports = {
    createFeeStructureSchema,
    createFeePaymentSchema,
    requestAdjustmentSchema,
    approveAdjustmentSchema,
    processRefundSchema,
};
