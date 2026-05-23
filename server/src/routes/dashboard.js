const express = require('express');
const router = express.Router();
const { authMiddleware, requireRole } = require('../middleware/auth');
const {
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
} = require('../controllers/dashboardController');

// All dashboard routes require authentication
router.use(authMiddleware);

// Get dashboard statistics
router.get('/stats', getDashboardStats);

// Get recent activities
router.get('/activities', getRecentActivities);

// Get upcoming examinations
router.get('/upcoming-exams', getUpcomingExams);

// Get fee collection summary
router.get('/fee-summary', getFeeCollectionSummary);

// Get inventory alerts
router.get('/inventory-alerts', getInventoryAlerts);

// Accountant-specific detailed stats (requires ACCOUNTANT role)
router.get('/accountant-stats', requireRole('SUPER_ADMIN', 'ADMIN', 'ACCOUNTANT'), getAccountantStats);

// Get attendance trend (Last 7 days)
router.get('/attendance-trend', getAttendanceTrend);
router.get('/class-performance', getClassPerformance);
router.get('/student-performance', getStudentPerformance);

// Phase 2: Premium Dashboard Routes
router.get('/library-stats', getLibraryStats);
router.get('/hr-stats', getHRStats);
router.get('/finance-stats', getFinanceStats);
router.get('/exam-stats', getExamStats);
router.get('/inventory-stats', getInventoryStats);

module.exports = router;
