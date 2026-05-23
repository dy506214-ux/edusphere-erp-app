const feeService = require('../services/feeService');
const { emitEvent } = require('../services/socketService');
const studentRepo = require('../repositories/studentRepository');
const asyncHandler = require('../utils/asyncHandler');
const NotFoundError = require('../errors/NotFoundError');
const { generateFeeStatementPDF } = require('../utils/feeStatementGenerator');
const prisma = require('../config/database');

// Get fee structures
const getFeeStructures = asyncHandler(async (req, res) => {
  const result = await feeService.getFeeStructures(req.query);
  res.status(200).json({
    success: true,
    ...result
  });
});

// Get students with fee status
const getFeeStudents = asyncHandler(async (req, res) => {
  const result = await feeService.getFeeStudents(req.query);
  res.status(200).json({
    success: true,
    ...result
  });
});

// Create fee structure
const createFeeStructure = asyncHandler(async (req, res) => {
  const feeStructure = await feeService.createFeeStructure(req.body);
  res.status(201).json({
    success: true,
    message: 'Fee structure created successfully',
    feeStructure,
  });
});

// Get single fee structure
const getFeeStructureById = asyncHandler(async (req, res) => {
  const feeStructure = await feeService.getFeeStructureById(req.params.id);
  res.status(200).json({
    success: true,
    feeStructure
  });
});

// Update fee structure
const updateFeeStructure = asyncHandler(async (req, res) => {
  const feeStructure = await feeService.updateFeeStructure(req.params.id, req.body);
  res.status(200).json({
    success: true,
    message: 'Fee structure updated successfully',
    feeStructure,
  });
});

// Delete fee structure
const deleteFeeStructure = asyncHandler(async (req, res) => {
  await feeService.deleteFeeStructure(req.params.id);
  res.status(200).json({
    success: true,
    message: 'Fee structure deleted successfully',
  });
});

// Get fee payments
const getFeePayments = asyncHandler(async (req, res) => {
  const result = await feeService.getFeePayments(req.query);
  res.status(200).json({
    success: true,
    ...result
  });
});

// Create fee payment
const createFeePayment = asyncHandler(async (req, res) => {
  const payment = await feeService.createFeePayment(req.body, req.user.userId);
  res.status(201).json({
    success: true,
    message: 'Fee payment recorded successfully',
    payment,
  });

  // Emit real-time event
  emitEvent('FEE_PAYMENT_CREATED', {
    amount: payment.amount,
    studentId: payment.studentId,
    paymentDate: payment.paymentDate,
    status: payment.status
  }, 'ADMIN');
  
  emitEvent('FEE_PAYMENT_CREATED', {
    amount: payment.amount,
    paymentDate: payment.paymentDate
  }, 'ACCOUNTANT');
});

// Get student fee status
const getStudentFeeStatus = asyncHandler(async (req, res) => {
  let studentId = req.params.id;
  if (studentId === 'me') {
    const student = await studentRepo.findByUserId(req.user.userId);
    if (!student) {
      throw new NotFoundError('Student profile not found for this user');
    }
    studentId = student.id;
  }
  const result = await feeService.getStudentFeeStatus(studentId, req.query.academicYearId);
  res.status(200).json({
    success: true,
    ...result
  });
});

// Request Discount / Scholarship / Adjustment
const requestAdjustment = asyncHandler(async (req, res) => {
  const adjustment = await feeService.requestAdjustment(req.body, req.user.userId);
  res.status(201).json({
    success: true,
    message: 'Adjustment requested successfully',
    adjustment,
  });
});

// Approve/Reject Adjustment
const approveAdjustment = asyncHandler(async (req, res) => {
  const adjustment = await feeService.approveAdjustment(req.params.id, req.body.status, req.user.userId);
  res.status(200).json({
    success: true,
    message: `Adjustment ${req.body.status.toLowerCase()}`,
    adjustment,
  });
});

// Process Refund
const processRefund = asyncHandler(async (req, res) => {
  const refund = await feeService.processRefund(req.body, req.user.userId);
  res.status(201).json({
    success: true,
    message: 'Refund processed successfully',
    refund,
  });
});

// Get Adjustments
const getAdjustments = asyncHandler(async (req, res) => {
  const adjustments = await feeService.getAdjustments(req.query);
  res.status(200).json({ 
    success: true,
    adjustments 
  });
});

// Get Admin Fee Stats
const getFeeStats = asyncHandler(async (req, res) => {
  const stats = await feeService.getFeeStats();
  res.status(200).json({
    success: true,
    ...stats
  });
});

module.exports = {
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
  downloadFeeStatement: asyncHandler(async (req, res) => {
    let { id } = req.params;
    
    // If id is 'me', use the authenticated student's ID
    if (id === 'me' && req.user.role === 'STUDENT') {
      const student = await prisma.student.findFirst({ where: { userId: req.user.id } });
      if (!student) return res.status(404).json({ success: false, message: 'Student profile not found' });
      id = student.id;
    }

    const feeStatus = await feeService.getStudentFeeStatus(id);
    
    // Fetch branding config
    const brandingEntries = await prisma.schoolBranding.findMany();
    const brandingMap = {};
    brandingEntries.forEach(e => { brandingMap[e.key] = e.value; });

    const pdfData = {
      student: {
        name: feeStatus.student.user ? `${feeStatus.student.user.firstName} ${feeStatus.student.user.lastName}` : 'Student',
        admissionNo: feeStatus.student.admissionNumber,
        class: feeStatus.student.currentClass?.name,
        section: feeStatus.student.section?.name,
      },
      ledgers: feeStatus.ledgers,
      summary: feeStatus.summary,
      schoolConfig: {
        schoolName: brandingMap.school_name || process.env.SCHOOL_NAME,
        logoPath: brandingMap.school_logo || null,
      },
    };

    const pdfBuffer = await generateFeeStatementPDF(pdfData);

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename=FeeStatement_${pdfData.student.admissionNo}.pdf`);
    res.send(pdfBuffer);
  }),
};
