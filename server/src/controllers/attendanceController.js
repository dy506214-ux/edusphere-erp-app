const AttendanceService = require('../services/AttendanceService');
const { emitEvent } = require('../services/socketService');
const asyncHandler = require('../utils/asyncHandler');
const { ROLES } = require('../constants');

// Mark attendance (manual or RFID)
const markAttendance = asyncHandler(async (req, res) => {
  const attendance = await AttendanceService.markAttendance(req.body, req.user.userId);
  res.status(201).json({
    success: true,
    message: 'Attendance marked successfully',
    attendance
  });

  emitEvent('ATTENDANCE_MARKED', {
    studentId: attendance.studentId,
    status: attendance.status,
    date: attendance.date,
    studentName: `${attendance.student.user.firstName} ${attendance.student.user.lastName}`
  }, 'ADMIN');
});

// Get attendance for a date
const getAttendanceByDate = asyncHandler(async (req, res) => {
  const result = await AttendanceService.getAttendanceByDate(req.query);
  res.status(200).json({
    success: true,
    ...result
  });
});

// RFID scan handler
const handleRFIDScan = asyncHandler(async (req, res) => {
  const { cardNumber, deviceId } = req.body;
  const result = await AttendanceService.handleRFIDScan(cardNumber, deviceId);
  const { action, student, attendance } = result;

  res.status(action === 'checkin' ? 201 : 200).json({
    success: true,
    ...result
  });

  if (action === 'checkin') {
    emitEvent('ATTENDANCE_MARKED', {
      studentId: attendance.studentId,
      status: attendance.status,
      date: attendance.date,
      studentName: `${student.user.firstName} ${student.user.lastName}`,
      type: 'RFID'
    }, 'ADMIN');
  }
});

// Bulk mark attendance
const bulkMarkAttendance = asyncHandler(async (req, res) => {
  const { date, attendanceData } = req.body;
  const result = await AttendanceService.bulkMarkAttendance(date, attendanceData, req.user.userId);
  res.status(200).json({
    success: true,
    message: `Marked attendance for ${result.successful} students`,
    ...result
  });
});

// Get attendance report
const getAttendanceReport = asyncHandler(async (req, res) => {
  const result = await AttendanceService.getAttendanceReport(req.query);
  res.status(200).json({
    success: true,
    ...result
  });
});

// ── Attendance Slots ─────────────────────────────────────────────────

// Create a daily attendance slot for a class
const createSlot = asyncHandler(async (req, res) => {
  const result = await AttendanceService.createSlot(req.body, req.user.userId);
  res.status(201).json({
    success: true,
    message: 'Attendance slot created',
    slot: result
  });
});

// List attendance slots
const getSlots = asyncHandler(async (req, res) => {
  const slots = await AttendanceService.getSlots(req.query);
  res.status(200).json({
    success: true,
    slots
  });
});

// Get a single slot with its student list and any existing attendance
const getSlotWithStudents = asyncHandler(async (req, res) => {
  const result = await AttendanceService.getSlotWithEntities(req.params.id);
  res.status(200).json({
    success: true,
    ...result
  });
});

// Delete a slot (only if OPEN and no records)
const deleteSlot = asyncHandler(async (req, res) => {
  await AttendanceService.deleteSlot(req.params.id);
  res.status(200).json({
    success: true,
    message: 'Slot deleted successfully'
  });
});

// Submit attendance for a slot — single batch transaction
const submitSlotAttendance = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { attendanceData } = req.body;
  const result = await AttendanceService.submitSlotAttendance(id, attendanceData, req.user.userId);
  res.status(200).json({
    success: true,
    message: `Attendance saved for ${result.count} entries`,
    ...result
  });
});

// Submit batch attendance for staff/teachers
const submitStaffAttendance = asyncHandler(async (req, res) => {
  const result = await AttendanceService.submitStaffAttendance(req.body, req.user.userId);
  res.status(200).json({
    success: true,
    message: `Batch attendance saved`,
    ...result
  });
});

// QR scan handler — used by kiosk/scanner page
// POST /api/attendance/qr-scan
// Body: { qrPayload, scannerId, scanLat, scanLng }
const handleQRScan = asyncHandler(async (req, res) => {
  const result = await AttendanceService.handleQRScan(req.body, req.user?.userId);
  const { action, user, attendance } = result;

  res.status(action === 'checkin' ? 201 : 200).json({
    success: true,
    ...result
  });

  // Emit real-time event
  emitEvent('ATTENDANCE_MARKED', {
    studentId: attendance.studentId,
    teacherId: attendance.teacherId,
    staffId: attendance.staffId,
    status: attendance.status,
    date: attendance.date,
    studentName: `${user.firstName} ${user.lastName}`,
    type: 'QR'
  }, 'ADMIN');

  // Socket.io for real-time dashboard
  const io = req.app.get('io');
  if (io) {
    io.emit('attendance:qr-scan', {
      action,
      user: { id: user.id, firstName: user.firstName, lastName: user.lastName, role: user.role, avatar: user.avatar },
      record: attendance,
      timestamp: new Date().toISOString()
    });
  }
});


// Attendance Analytics (date-wise)
const getAttendanceAnalytics = asyncHandler(async (req, res) => {
  const result = await AttendanceService.getAttendanceAnalytics(req.query);
  res.status(200).json({
    success: true,
    ...result
  });
});

// Get logged-in user's attendance records
const getMyAttendance = asyncHandler(async (req, res) => {
  const result = await AttendanceService.getMyAttendance(req.user.userId, req.query);
  res.status(200).json({
    success: true,
    ...result
  });
});

module.exports = {
  markAttendance,
  getAttendanceByDate,
  handleRFIDScan,
  handleQRScan,
  bulkMarkAttendance,
  getAttendanceReport,
  createSlot,
  getSlots,
  getSlotWithStudents,
  deleteSlot,
  submitSlotAttendance,
  submitStaffAttendance,
  getAttendanceAnalytics,
  getMyAttendance,
};
