const payrollService = require('../services/PayrollService');
const asyncHandler = require('../utils/asyncHandler');

// Get salary structures (list)
const getSalaryStructures = asyncHandler(async (req, res) => {
    const structures = await payrollService.getSalaryStructures();
    res.status(200).json({ 
        success: true,
        structures 
    });
});

// Set (upsert) salary structure for an employee
const setSalaryStructure = asyncHandler(async (req, res) => {
    const structure = await payrollService.setSalaryStructure(req.body);
    res.status(200).json({ 
        success: true,
        message: 'Salary structure saved successfully', 
        structure 
    });
});

// Generate payroll for a given month/year
const generatePayroll = asyncHandler(async (req, res) => {
    const { month, year } = req.params;
    const result = await payrollService.generatePayroll(month, year);
    res.status(200).json({
        success: true,
        message: `Payroll generated: ${result.created} created, ${result.skipped} already existed`,
        created: result.created,
        skipped: result.skipped,
    });
});

// Get payroll list for a month/year
const getPayrollList = asyncHandler(async (req, res) => {
    const { month, year } = req.params;
    const result = await payrollService.getPayrollList(month, year);
    res.status(200).json({
        success: true,
        ...result
    });
});

// Mark payroll as paid
const markPaid = asyncHandler(async (req, res) => {
    const payroll = await payrollService.markPaid(req.params.id, req.body.remarks, req.user.userId);
    res.status(200).json({ 
        success: true,
        message: 'Payroll marked as paid', 
        payroll 
    });
});

// Update payroll present/absent days
const updatePayrollDays = asyncHandler(async (req, res) => {
    const updated = await payrollService.updatePayrollDays(req.params.id, req.body);
    res.status(200).json({ 
        success: true,
        message: 'Payroll updated', 
        payroll: updated 
    });
});

// Get payroll for logged in employee
const getMyPayroll = asyncHandler(async (req, res) => {
    const payrolls = await payrollService.getMyPayroll(req.user.userId);
    res.status(200).json({
        success: true,
        payrolls
    });
});

module.exports = {
    getSalaryStructures,
    setSalaryStructure,
    generatePayroll,
    getPayrollList,
    markPaid,
    updatePayrollDays,
    getMyPayroll,
};
