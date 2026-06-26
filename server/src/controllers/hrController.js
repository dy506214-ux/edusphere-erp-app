const HRService = require('../services/HRService');
const asyncHandler = require('express-async-handler');

/**
 * Controller for HR / Employee related routes
 */

// Get all employees
const getEmployees = asyncHandler(async (req, res) => {
    const result = await HRService.getEmployees(req.query);
    res.json(result);
});

// Get single employee
const getEmployee = asyncHandler(async (req, res) => {
    const { id } = req.params;
    const result = await HRService.getEmployee(id);
    res.json(result);
});

// Create employee
const createEmployee = asyncHandler(async (req, res) => {
    const employee = await HRService.createEmployee(req.body);
    res.status(201).json({
        success: true,
        message: 'Employee created successfully',
        employee
    });
});

// Update employee
const updateEmployee = asyncHandler(async (req, res) => {
    const { id } = req.params;
    const updated = await HRService.updateEmployee(id, req.body);
    res.status(200).json({
        success: true,
        message: 'Employee updated successfully',
        employee: updated
    });
});

// Toggle active/inactive status
const toggleEmployeeStatus = asyncHandler(async (req, res) => {
    const { id } = req.params;
    const result = await HRService.toggleEmployeeStatus(id, req.body);
    res.status(200).json({
        success: true,
        message: `Employee ${result.activated ? 'activated' : 'deactivated'} successfully`
    });
});

module.exports = {
    getEmployees,
    getEmployee,
    createEmployee,
    updateEmployee,
    toggleEmployeeStatus
};
