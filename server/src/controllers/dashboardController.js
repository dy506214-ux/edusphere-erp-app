const logger = require('../config/logger');
const DashboardService = require('../services/DashboardService');
const asyncHandler = require('../utils/asyncHandler');

/**
 * Get dashboard statistics
 */
const getDashboardStats = asyncHandler(async (req, res) => {
  const stats = await DashboardService.getDashboardStats(req.user.role, req.user.userId);
  res.status(200).json({ success: true, stats });
});

/**
 * Get recent activities
 */
const getRecentActivities = asyncHandler(async (req, res) => {
  const limit = parseInt(req.query.limit) || 10;
  const activities = await DashboardService.getRecentActivities(req.user.role, req.user.userId, limit);
  res.status(200).json({ success: true, activities });
});

/**
 * Get upcoming examinations
 */
const getUpcomingExams = asyncHandler(async (req, res) => {
  const limit = parseInt(req.query.limit) || 10;
  const exams = await DashboardService.getUpcomingExams(req.user.userId, req.user.role, limit);
  res.status(200).json({ success: true, exams });
});

/**
 * Get fee collection summary
 */
const getFeeCollectionSummary = asyncHandler(async (req, res) => {
  const summary = await DashboardService.getFeeCollectionSummary();
  res.status(200).json({ success: true, summary });
});

/**
 * Get low stock inventory alerts
 */
const getInventoryAlerts = asyncHandler(async (req, res) => {
  const alerts = await DashboardService.getInventoryAlerts();
  res.status(200).json({ success: true, ...alerts });
});

/**
 * Accountant-specific detailed stats
 */
const getAccountantStats = asyncHandler(async (req, res) => {
  const stats = await DashboardService.getAccountantStats();
  res.json({ success: true, ...stats });
});

/**
 * Get attendance trend for the last 7 days
 */
const getAttendanceTrend = asyncHandler(async (req, res) => {
  const { classId, studentId } = req.query;
  const trend = await DashboardService.getAttendanceTrend(classId, studentId);
  res.status(200).json({ success: true, trend });
});

/**
 * Get class performance for the most recent exam
 */
const getClassPerformance = asyncHandler(async (req, res) => {
  const { classId } = req.query;
  if (!classId) return res.status(400).json({ success: false, message: 'classId is required' });

  const performance = await DashboardService.getClassPerformance(classId);
  res.json({ success: true, ...performance });
});

/**
 * Get student performance across subjects for latest exam
 */
const getStudentPerformance = asyncHandler(async (req, res) => {
  const { studentId } = req.query;
  if (!studentId) return res.status(400).json({ success: false, message: 'studentId is required' });

  const performance = await DashboardService.getStudentPerformance(studentId);
  res.json({ success: true, ...performance });
});

/**
 * Get library statistics
 */
const getLibraryStats = asyncHandler(async (req, res) => {
  const stats = await DashboardService.getLibraryStats();
  res.json({ success: true, ...stats });
});

/**
 * Get HR and staff stats
 */
const getHRStats = asyncHandler(async (req, res) => {
  const stats = await DashboardService.getHRStats();
  res.json({ success: true, ...stats });
});

/**
 * Get financial trends and payment mode breakdown
 */
const getFinanceStats = asyncHandler(async (req, res) => {
  const stats = await DashboardService.getFinanceStats();
  res.json({ success: true, ...stats });
});

/**
 * Get examination statistics and averages
 */
const getExamStats = asyncHandler(async (req, res) => {
  const { classId } = req.query;
  const stats = await DashboardService.getExamStats(classId);
  res.json({ success: true, ...stats });
});

/**
 * Get inventory distribution and movement stats
 */
const getInventoryStats = asyncHandler(async (req, res) => {
  const stats = await DashboardService.getInventoryStats();
  res.json({ success: true, ...stats });
});

module.exports = {
  getDashboardStats,
  getRecentActivities,
  getUpcomingExams,
  getFeeCollectionSummary,
  getInventoryAlerts,
  getAccountantStats,
  getAttendanceTrend,
  getClassPerformance,
  getStudentPerformance,
  getLibraryStats,
  getHRStats,
  getFinanceStats,
  getExamStats,
  getInventoryStats
};


