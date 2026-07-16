class ApiEndpoints {
  ApiEndpoints._();

  static const String login = 'auth/login';
  static const String logout = 'auth/logout';
  static const String announcements = 'announcements';
  static const String activeAnnouncements = 'announcements/active';

  // Timetables
  static const String timetables = 'timetables';
  static String studentTimetable(String sectionId) => 'timetables/student/$sectionId';
  static String teacherTimetable(String teacherId) => 'timetables/teacher/$teacherId';

  // Transport Allocations
  static const String transportAllocations = 'transport/allocations';
  static const String myTransportAllocation = 'transport/my-transport';
  static String deleteTransportAllocation(String id) => 'transport/allocations/$id';
  static const String transportRoutes = 'transport/routes';

  // Calendar
  static const String calendar = 'calendar';
  static const String calendarUpcoming = 'calendar/upcoming';

  // Students
  static const String studentsMe = 'students/me';
  static String studentProfile(String id) => 'students/$id';
  static String studentAttendance(String id) => 'students/$id/attendance';
  static String studentDocuments(String id) => 'students/$id/documents';
  static String deleteStudentDocument(String documentId) => 'students/documents/$documentId';

  // Fees
  static String studentFeeStatus(String studentId) => 'fees/students/$studentId/status';
  static const String myFeeStatus = 'fees/students/me/status';

  // Exams
  static String studentExamResults(String studentId) => 'exams/students/$studentId/results';

  // Users
  static String userQrCode(String userId) => 'users/$userId/qr';
}
