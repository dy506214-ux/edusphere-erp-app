import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:intl/intl.dart' as intl;
import '../theme/colors.dart';
import 'features/exam_schedule_screen.dart';
import 'features/exam_terms_screen.dart';
import 'features/exam_report_card_screen.dart';
import 'features/exam_marks_entry_screen.dart';
import 'features/teacher_more_screen.dart';
import 'main_screen.dart';
import 'welcome_screen.dart';
import 'profile_screen.dart';
import 'community_screen.dart';
import 'features/create_assignment_screen.dart';
import 'features/schedule_screen.dart';
import 'features/announcements_screen.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Academic Screen — supports student Academic Overview & teacher Academic Management
// ══════════════════════════════════════════════════════════════════════════════
class AcademicScreen extends StatefulWidget {
  final RoleTheme theme;
  final VoidCallback? onBack;
  final bool showAppBar;
  final String role; // 'student' or 'teacher'

  const AcademicScreen({
    super.key,
    required this.theme,
    this.onBack,
    this.showAppBar = true,
    this.role = 'student',
  });

  @override
  State<AcademicScreen> createState() => _AcademicScreenState();
}

class _AcademicScreenState extends State<AcademicScreen> {
  // ── Teacher/Management State ──
  int _activeTab = 0; // 0 = Classes, 1 = Subjects, 2 = Sections, 3 = Exams & Results

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _showFabMenu = true;
  String _userName = 'Emma Johnson';
  String _userRole = 'teacher';
  String _subjectSearchQuery = '';
  String _sectionSearchQuery = '';

  // ── Database Lists ──
  List<Map<String, dynamic>> _classesList = [];
  List<Map<String, dynamic>> _subjectsList = [];
  List<Map<String, dynamic>> _sectionsList = [];

  // ── Student/Overview State ──
  bool _isLoadingStudent = true;
  String _studentEmail = '';
  String _studentName = '';
  String _studentId = '';
  String _classId = '';
  String _className = 'Grade 1 (G1)';
  String _sectionId = '';
  List<Map<String, dynamic>> _studentSubjects = [];
  List<Map<String, dynamic>> _timetableSlots = [];
  List<Map<String, dynamic>> _attendanceRecords = [];
  double _attendanceRate = 100.0;
  bool _hasAttendanceData = false;

  // ── Selected day for timetable ──
  int _selectedTimetableDay = DateTime.now().weekday == 7 ? 1 : DateTime.now().weekday;

  final Map<int, List<Map<String, dynamic>>> _mockTimetable = {
    1: [ // Monday
      {'subject': 'Mathematics', 'code': 'MAT-3', 'time': '08:30 AM - 09:30 AM', 'room': 'Room 201', 'type': 'CORE'},
      {'subject': 'English', 'code': 'ENG-3', 'time': '09:45 AM - 10:45 AM', 'room': 'Room 105', 'type': 'CORE'},
      {'subject': 'Science', 'code': 'SCI-3', 'time': '11:00 AM - 12:00 PM', 'room': 'Lab 402', 'type': 'CORE'},
      {'subject': 'Hindi', 'code': 'HIN-3', 'time': '01:00 PM - 02:00 PM', 'room': 'Room 102', 'type': 'CORE'},
    ],
    2: [ // Tuesday
      {'subject': 'Science', 'code': 'SCI-3', 'time': '08:30 AM - 09:30 AM', 'room': 'Lab 402', 'type': 'CORE'},
      {'subject': 'Mathematics', 'code': 'MAT-3', 'time': '09:45 AM - 10:45 AM', 'room': 'Room 201', 'type': 'CORE'},
      {'subject': 'Social Science', 'code': 'SOC-3', 'time': '11:00 AM - 12:00 PM', 'room': 'Room 108', 'type': 'CORE'},
      {'subject': 'Computer', 'code': 'COM-3', 'time': '01:00 PM - 02:00 PM', 'room': 'Lab 501', 'type': 'ELECTIVE'},
    ],
    3: [ // Wednesday
      {'subject': 'English', 'code': 'ENG-3', 'time': '08:30 AM - 09:30 AM', 'room': 'Room 105', 'type': 'CORE'},
      {'subject': 'Hindi', 'code': 'HIN-3', 'time': '09:45 AM - 10:45 AM', 'room': 'Room 102', 'type': 'CORE'},
      {'subject': 'Mathematics', 'code': 'MAT-3', 'time': '11:00 AM - 12:00 PM', 'room': 'Room 201', 'type': 'CORE'},
      {'subject': 'Science', 'code': 'SCI-3', 'time': '01:00 PM - 02:00 PM', 'room': 'Lab 402', 'type': 'CORE'},
    ],
    4: [ // Thursday
      {'subject': 'Social Science', 'code': 'SOC-3', 'time': '08:30 AM - 09:30 AM', 'room': 'Room 108', 'type': 'CORE'},
      {'subject': 'Science', 'code': 'SCI-3', 'time': '09:45 AM - 10:45 AM', 'room': 'Lab 402', 'type': 'CORE'},
      {'subject': 'English', 'code': 'ENG-3', 'time': '11:00 AM - 12:00 PM', 'room': 'Room 105', 'type': 'CORE'},
      {'subject': 'Computer', 'code': 'COM-3', 'time': '01:00 PM - 02:00 PM', 'room': 'Lab 501', 'type': 'ELECTIVE'},
    ],
    5: [ // Friday
      {'subject': 'Mathematics', 'code': 'MAT-3', 'time': '08:30 AM - 09:30 AM', 'room': 'Room 201', 'type': 'CORE'},
      {'subject': 'Hindi', 'code': 'HIN-3', 'time': '09:45 AM - 10:45 AM', 'room': 'Room 102', 'type': 'CORE'},
      {'subject': 'Social Science', 'code': 'SOC-3', 'time': '11:00 AM - 12:00 PM', 'room': 'Room 108', 'type': 'CORE'},
      {'subject': 'English', 'code': 'ENG-3', 'time': '01:00 PM - 02:00 PM', 'room': 'Room 105', 'type': 'CORE'},
    ],
    6: [ // Saturday
      {'subject': 'Computer', 'code': 'COM-3', 'time': '08:30 AM - 09:30 AM', 'room': 'Lab 501', 'type': 'ELECTIVE'},
      {'subject': 'Mathematics', 'code': 'MAT-3', 'time': '09:45 AM - 10:45 AM', 'room': 'Room 201', 'type': 'CORE'},
    ],
  };

  RealtimeChannel? _realtimeChannel;
  Timer? _realtimePollTimer;

  @override
  void initState() {
    super.initState();
    if (widget.role == 'student') {
      _loadStudentOverviewData();
      _connectRealTime();
    } else {
      _loadLocalData();
    }
  }

  @override
  void dispose() {
    _realtimePollTimer?.cancel();
    if (_realtimeChannel != null) {
      try {
        Supabase.instance.client.removeChannel(_realtimeChannel!);
      } catch (_) {}
    }
    super.dispose();
  }

  // ═════════════════════════════════════════════════════════════════════════
  // STUDENT DATA LOADING
  // ═════════════════════════════════════════════════════════════════════════
  Future<void> _loadStudentOverviewData({bool showLoading = true}) async {
    if (!mounted) return;
    if (showLoading) {
      setState(() {
        _isLoadingStudent = true;
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('student_email') ?? prefs.getString('user_email') ?? 'student1@demoschool.com';
      _studentEmail = savedEmail;

      // 1. Fetch User and Student profile
      final userRes = await Supabase.instance.client
          .from('User')
          .select()
          .eq('email', _studentEmail)
          .maybeSingle();

      if (userRes != null) {
        final userId = userRes['id'] as String;
        _studentName = '${userRes['firstName'] ?? ''} ${userRes['lastName'] ?? ''}'.trim();

        final studentRes = await Supabase.instance.client
            .from('Student')
            .select('*, currentClass:Class(name)')
            .eq('userId', userId)
            .maybeSingle();

        if (studentRes != null) {
          _studentId = studentRes['id'] as String;
          _classId = studentRes['currentClassId'] as String? ?? '';
          _sectionId = studentRes['sectionId'] as String? ?? '';
          if (studentRes['currentClass'] != null) {
            _className = studentRes['currentClass']['name'] as String? ?? 'Grade 1';
          }
        }
      }

      // 2. Fetch Subjects assigned to their class
      if (_classId.isNotEmpty) {
        final List<dynamic> subjectsRes = await Supabase.instance.client
            .from('Subject')
            .select()
            .eq('classId', _classId);
        
        _studentSubjects = List<Map<String, dynamic>>.from(subjectsRes);
      }

      // 3. Fetch Timetable slots for their section/class
      if (_sectionId.isNotEmpty) {
        final List<dynamic> slotsRes = await Supabase.instance.client
            .from('TimetableSlot')
            .select('*, subject:Subject(name, code)')
            .eq('sectionId', _sectionId);
        
        _timetableSlots = List<Map<String, dynamic>>.from(slotsRes);
      }

      // 4. Fetch Attendance records
      if (_studentId.isNotEmpty) {
        final List<dynamic> attendanceRes = await Supabase.instance.client
            .from('AttendanceRecord')
            .select()
            .eq('studentId', _studentId);

        _attendanceRecords = List<Map<String, dynamic>>.from(attendanceRes);
        if (_attendanceRecords.isNotEmpty) {
          int present = 0;
          for (var record in _attendanceRecords) {
            final status = record['status'] as String? ?? '';
            if (status == 'PRESENT' || status == 'P' || status == 'LATE' || status == 'LEAVE') {
              present++;
            }
          }
          _attendanceRate = (present / _attendanceRecords.length) * 100;
          _hasAttendanceData = true;
        } else {
          _hasAttendanceData = false;
        }
      }

      if (mounted) {
        setState(() {
          _isLoadingStudent = false;
        });
      }
    } catch (e) {
      dev.log('Error loading academic overview data: $e');
      if (mounted) {
        setState(() {
          _isLoadingStudent = false;
        });
      }
    }
  }

  void _connectRealTime() {
    try {
      final client = Supabase.instance.client;
      if (_realtimeChannel != null) {
        client.removeChannel(_realtimeChannel!);
      }

      dev.log('📡 Subscribing to Supabase Realtime changes for Academic Screen...', name: 'AcademicScreen');
      _realtimeChannel = client.channel('public:academic_screen_sync')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'AttendanceRecord',
          callback: (payload) {
            dev.log('🔥 Real-time attendance change payload: $payload', name: 'AcademicScreen');
            if (mounted) _loadStudentOverviewData(showLoading: false);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'Subject',
          callback: (payload) {
            dev.log('🔥 Real-time subject change payload: $payload', name: 'AcademicScreen');
            if (mounted) _loadStudentOverviewData(showLoading: false);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'TimetableSlot',
          callback: (payload) {
            dev.log('🔥 Real-time timetable slot change payload: $payload', name: 'AcademicScreen');
            if (mounted) _loadStudentOverviewData(showLoading: false);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'Student',
          callback: (payload) {
            dev.log('🔥 Real-time student profile change payload: $payload', name: 'AcademicScreen');
            if (mounted) _loadStudentOverviewData(showLoading: false);
          },
        );

      _realtimeChannel!.subscribe((status, [error]) {
        dev.log('📡 Supabase Realtime Academic channel status: $status', name: 'AcademicScreen');
        if (error != null) {
          dev.log('❌ Supabase Realtime Academic subscription error: $error', name: 'AcademicScreen');
        }
      });
    } catch (e) {
      dev.log('⚠️ Error connecting Supabase Realtime Academic channel: $e', name: 'AcademicScreen');
    }

    // Polling fallback every 2 seconds for robust background sync
    _realtimePollTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted && widget.role == 'student') {
        _loadStudentOverviewData(showLoading: false);
      }
    });
  }

  // ═════════════════════════════════════════════════════════════════════════
  // TEACHER LOCAL DATA PERSISTENCE
  // ═════════════════════════════════════════════════════════════════════════
  Future<void> _loadLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userName = prefs.getString('teacher_name') ?? prefs.getString('student_name') ?? 'Emma Johnson';
      _userRole = prefs.getString('user_role') ?? 'teacher';
      
      final classesJson = prefs.getString('academic_classes_list');
      if (classesJson != null) {
        _classesList = List<Map<String, dynamic>>.from(json.decode(classesJson));
      }
      
      if (_classesList.isEmpty) {
        _classesList = List.generate(10, (i) => {
          'name': 'Grade ${i + 1}',
          'level': '${i + 1}',
          'academic_year': '—',
          'class_teacher': '—',
          'students': 0,
        });
      }
      
      final subjectsJson = prefs.getString('academic_subjects_list');
      if (subjectsJson != null) {
        _subjectsList = List<Map<String, dynamic>>.from(json.decode(subjectsJson));
      }

      if (_subjectsList.isEmpty) {
        final defaultSubjects = [
          {'name': 'Mathematics', 'code': 'MAT-1'},
          {'name': 'Science', 'code': 'SCI-1'},
          {'name': 'English', 'code': 'ENG-1'},
          {'name': 'Social Studies', 'code': 'SOC-1'},
          {'name': 'Hindi', 'code': 'HIN-1'},
          {'name': 'Computer', 'code': 'COM-1'},
          {'name': 'Mathematics', 'code': 'MAT-2'},
          {'name': 'Science', 'code': 'SCI-2'},
          {'name': 'English', 'code': 'ENG-2'},
          {'name': 'Social Studies', 'code': 'SOC-2'},
          {'name': 'Hindi', 'code': 'HIN-2'},
          {'name': 'Computer', 'code': 'COM-2'},
        ];
        _subjectsList = defaultSubjects.map((s) => {
          'name': s['name'],
          'code': s['code'],
          'class': '—',
          'teacher': '—',
          'description': '-',
        }).toList();
      }

      final sectionsJson = prefs.getString('academic_sections_list');
      if (sectionsJson != null) {
        _sectionsList = List<Map<String, dynamic>>.from(json.decode(sectionsJson));
      }

      if (_sectionsList.isEmpty) {
        final List<Map<String, dynamic>> defaultSections = [];
        for (int gradeNum = 1; gradeNum <= 4; gradeNum++) {
          defaultSections.add({
            'name': 'Section A',
            'class': 'Grade $gradeNum',
            'max_students': 40,
            'students': 0,
          });
          defaultSections.add({
            'name': 'Section B',
            'class': 'Grade $gradeNum',
            'max_students': 40,
            'students': 0,
          });
          defaultSections.add({
            'name': 'Section C',
            'class': 'Grade $gradeNum',
            'max_students': 40,
            'students': 0,
          });
        }
        _sectionsList = defaultSections;
      }

      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _saveLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('academic_classes_list', json.encode(_classesList));
      await prefs.setString('academic_subjects_list', json.encode(_subjectsList));
      await prefs.setString('academic_sections_list', json.encode(_sectionsList));
    } catch (_) {}
  }

  // ═════════════════════════════════════════════════════════════════════════
  // DIALOGS & SHEET GENERATORS
  // ═════════════════════════════════════════════════════════════════════════
  List<Map<String, dynamic>> _getSubjects() {
    if (_studentSubjects.isNotEmpty) {
      return _studentSubjects;
    }
    return [
      {'name': 'Mathematics', 'code': 'MATH-1', 'type': 'CORE'},
      {'name': 'Science', 'code': 'SCI-1', 'type': 'CORE'},
      {'name': 'English', 'code': 'ENG-1', 'type': 'CORE'},
      {'name': 'Social Studies', 'code': 'SST-1', 'type': 'CORE'},
      {'name': 'Hindi', 'code': 'HIN-1', 'type': 'CORE'},
      {'name': 'Computer', 'code': 'CS-1', 'type': 'CORE'},
    ];
  }

  List<Map<String, dynamic>> _getTimetableSlots() {
    // Filter database slots if available
    if (_timetableSlots.isNotEmpty) {
      final filtered = _timetableSlots.where((slot) {
        final dayVal = slot['dayOfWeek'];
        if (dayVal is int) {
          return dayVal == _selectedTimetableDay;
        } else if (dayVal is String) {
          return int.tryParse(dayVal) == _selectedTimetableDay;
        }
        return false;
      }).toList();

      if (filtered.isNotEmpty) {
        return filtered.map((slot) {
          final subName = slot['subject']?['name'] ?? 'Class Slot';
          final subCode = slot['subject']?['code'] ?? 'N/A';
          final room = slot['roomId'] ?? 'Room 101';
          return {
            'title': '${_className.split(' ')[0]} • $subName',
            'time': '${slot['startTime']} - ${slot['endTime']}',
            'subject': subName,
            'code': subCode,
            'room': room,
          };
        }).toList();
      }
    }

    // Fallback to mock data for the selected day
    final mockList = _mockTimetable[_selectedTimetableDay] ?? [];
    return mockList.map((slot) => {
      'title': '${_className.split(' ')[0]} • ${slot['subject']}',
      'time': slot['time'],
      'subject': slot['subject'],
      'code': slot['code'],
      'room': slot['room'],
    }).toList();
  }

  void _showAllSubjectsSheet() {
    final list = _getSubjects();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: EdgeInsets.all(24.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '📚 All Subjects',
                  style: GoogleFonts.inter(fontSize: 18.sp, fontWeight: FontWeight.w800, color: const Color(0xFF0F2547)),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            ...list.map((sub) => Container(
              margin: EdgeInsets.only(bottom: 12.h),
              padding: EdgeInsets.all(16.r),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: const Color(0xFFE2EAF4)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10.r),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Icon(Icons.book_outlined, color: const Color(0xFF0076F6), size: 18.sp),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sub['name'] as String, style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w800, color: const Color(0xFF0F2547))),
                        Text('Code: ${sub['code']} • Type: ${sub['type'] ?? 'CORE'}', style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF6B7A90))),
                      ],
                    ),
                  ),
                ],
              ),
            )),
            SizedBox(height: 12.h),
          ],
        ),
      ),
    );
  }

  void _showAllTimetablesSheet() {
    final list = _getTimetableSlots();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: EdgeInsets.all(24.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '📅 Weekly Timetables',
                  style: GoogleFonts.inter(fontSize: 18.sp, fontWeight: FontWeight.w800, color: const Color(0xFF0F2547)),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            ...list.map((slot) => Container(
              margin: EdgeInsets.only(bottom: 12.h),
              padding: EdgeInsets.all(16.r),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F8FC),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: const Color(0xFFE9F0F7)),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule_rounded, color: const Color(0xFF0076F6), size: 18.sp),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(slot['title'] as String, style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w800, color: const Color(0xFF0F2547))),
                        Text(slot['time'] as String, style: GoogleFonts.inter(fontSize: 12.sp, color: const Color(0xFF5D7290), fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            )),
            SizedBox(height: 12.h),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // MAIN BUILDER SWITCH
  // ═════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (widget.role == 'student') {
      return _buildStudentOverviewUI();
    } else {
      return _buildTeacherManagementUI();
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // STUDENT PANEL: ACADEMIC OVERVIEW
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildStudentOverviewUI() {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF3F8FC), Color(0xFFFCFDFE)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: _isLoadingStudent
              ? Center(
                  child: CircularProgressIndicator(
                    color: const Color(0xFF0076F6),
                    strokeWidth: 3.w,
                  ),
                )
              : Stack(
                  children: [
              // Main scroll content
              RefreshIndicator(
                onRefresh: _loadStudentOverviewData,
                color: const Color(0xFF0076F6),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(24.r),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row (Academic Overview / Refresh)
                      _buildStudentHeader(),
                      SizedBox(height: 24.h),

                      // Column / Desktop Row of current subjects & timetable
                      if (isDesktop)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildCurrentSubjectsCard()),
                            SizedBox(width: 24.w),
                            Expanded(child: _buildTimetableCard()),
                          ],
                        )
                      else
                        Column(
                          children: [
                            _buildCurrentSubjectsCard(),
                            SizedBox(height: 24.h),
                            _buildTimetableCard(),
                          ],
                        ),
                      SizedBox(height: 24.h),

                      // Academic Status Cards
                      _buildAcademicStatusSection(isDesktop),
                      SizedBox(height: 24.h),

                      // Attendance History
                      _buildAttendanceHistoryCard(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Academic Overview',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 26.sp,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F2547),
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                _studentName.isNotEmpty
                    ? 'Welcome, $_studentName'
                    : 'Manage your academic journey',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF6B7A90),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 12.w),
        // Refresh Button
        GestureDetector(
          onTap: _loadStudentOverviewData,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: const Color(0xFFE2EAF4)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6.r,
                )
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh_rounded, color: const Color(0xFF0F2547), size: 16.sp),
                SizedBox(width: 6.w),
                Text(
                  'Refresh',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F2547),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentSubjectsCard() {
    final list = _getSubjects();

    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: const Color(0xFFE9F0F8), width: 1.5.w),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE2EAF4).withValues(alpha: 0.35),
            blurRadius: 20.r,
            offset: Offset(0, 8.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(Icons.book_outlined, color: const Color(0xFF0076F6), size: 20.sp),
              ),
              SizedBox(width: 14.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Subjects',
                    style: GoogleFonts.inter(fontSize: 15.sp, fontWeight: FontWeight.w800, color: const Color(0xFF0F2547)),
                  ),
                  Text(
                    'Subjects assigned to your class',
                    style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF6B7A90), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 20.h),

          // Table Header
          Row(
            children: [
              Expanded(flex: 3, child: Text('Subject', style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w700))),
              Expanded(flex: 2, child: Center(child: Text('Code', style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w700)))),
              Expanded(flex: 2, child: Center(child: Text('Type', style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w700)))),
            ],
          ),
          const Divider(color: Color(0xFFE2E8F0)),

          // Table Rows
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            itemBuilder: (ctx, index) {
              final sub = list[index];
              return Container(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        sub['name'] as String,
                        style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w700, color: const Color(0xFF0F2547)),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Text(
                          sub['code'] as String,
                          style: GoogleFonts.inter(fontSize: 11.5.sp, color: const Color(0xFF6B7A90), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Text(
                            (sub['type'] ?? 'CORE').toString().toUpperCase(),
                            style: GoogleFonts.inter(fontSize: 9.5.sp, fontWeight: FontWeight.w800, color: const Color(0xFF475569)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          SizedBox(height: 16.h),

          // Bottom Action Button
          Center(
            child: GestureDetector(
              onTap: _showAllSubjectsSheet,
              child: Text(
                'View All Subjects',
                style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w800, color: const Color(0xFF0076F6)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimetableCard() {
    final list = _getTimetableSlots();

    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: const Color(0xFFE9F0F8), width: 1.5.w),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE2EAF4).withValues(alpha: 0.35),
            blurRadius: 20.r,
            offset: Offset(0, 8.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(Icons.schedule_rounded, color: const Color(0xFF0076F6), size: 20.sp),
              ),
              SizedBox(width: 14.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Timetable',
                    style: GoogleFonts.inter(fontSize: 15.sp, fontWeight: FontWeight.w800, color: const Color(0xFF0F2547)),
                  ),
                  Text(
                    'Recent class schedules',
                    style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF6B7A90), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 20.h),

          // Horizontal Day Selector
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [1, 2, 3, 4, 5, 6].map((dayNum) {
                final Map<int, String> dayNames = {
                  1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat'
                };
                final isSelected = _selectedTimetableDay == dayNum;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedTimetableDay = dayNum;
                    });
                  },
                  child: Container(
                    margin: EdgeInsets.only(right: 8.w),
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF0076F6) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Text(
                      dayNames[dayNum]!,
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? Colors.white : const Color(0xFF475569),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          SizedBox(height: 16.h),

          // Timetable Cards List
          if (list.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 24.h),
              child: Center(
                child: Text(
                  'No classes scheduled for today',
                  style: GoogleFonts.inter(fontSize: 12.sp, color: const Color(0xFF6B7A90)),
                ),
              ),
            )
          else
            ...list.map((slot) => Container(
              width: double.infinity,
              margin: EdgeInsets.only(bottom: 12.h),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: const Color(0xFFE2EAF4)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              child: Text(
                                slot['code'] ?? 'CORE',
                                style: GoogleFonts.inter(
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0076F6),
                                ),
                              ),
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                Icon(Icons.meeting_room_outlined, size: 12.sp, color: const Color(0xFF6B7A90)),
                                SizedBox(width: 4.w),
                                Text(
                                  slot['room'] ?? 'Room 101',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF6B7A90),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          slot['subject'] ?? 'Subject',
                          style: GoogleFonts.inter(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F2547),
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          slot['time'] ?? '',
                          style: GoogleFonts.inter(
                            fontSize: 11.5.sp,
                            color: const Color(0xFF6B7A90),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
          SizedBox(height: 12.h),

          // Bottom Action Button
          GestureDetector(
            onTap: _showAllTimetablesSheet,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 12.h),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Center(
                child: Text(
                  'View All Timetables',
                  style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w800, color: const Color(0xFF0076F6)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcademicStatusSection(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.trending_up_rounded, color: const Color(0xFF0076F6), size: 20.sp),
            SizedBox(width: 8.w),
            Text(
              'Academic Status',
              style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w900, color: const Color(0xFF0F2547)),
            ),
          ],
        ),
        SizedBox(height: 14.h),
        Row(
          children: [
            Expanded(
              child: _buildStatusMetricCard(
                icon: Icons.school_outlined,
                label: 'Target Class',
                value: _className,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: _buildStatusMetricCard(
                icon: Icons.check_circle_outline_rounded,
                label: 'Attendance Progress',
                value: _hasAttendanceData ? '${_attendanceRate.toStringAsFixed(1)}%' : 'Data Available',
              ),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildStatusMetricCard({required IconData icon, required String label, required String value}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFE9F0F8), width: 1.5.w),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE2EAF4).withValues(alpha: 0.35),
            blurRadius: 16.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF0076F6), size: 30.sp),
          SizedBox(height: 12.h),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF6B7A90), fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 13.5.sp, fontWeight: FontWeight.w800, color: const Color(0xFF0076F6)),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceHistoryCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: const Color(0xFFE9F0F8), width: 1.5.w),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE2EAF4).withValues(alpha: 0.35),
            blurRadius: 20.r,
            offset: Offset(0, 8.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(Icons.calendar_month_outlined, color: const Color(0xFF0076F6), size: 20.sp),
              ),
              SizedBox(width: 14.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Attendance History',
                    style: GoogleFonts.inter(fontSize: 15.sp, fontWeight: FontWeight.w800, color: const Color(0xFF0F2547)),
                  ),
                  Text(
                    'Recent attendance records',
                    style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF6B7A90), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 24.h),

          // If attendance list empty, show calendar empty state illustration
          if (_attendanceRecords.isEmpty) ...[
            Center(
              child: Column(
                children: [
                  _buildCalendarIllustration(),
                  SizedBox(height: 14.h),
                  Text(
                    'No attendance records found',
                    style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w800, color: const Color(0xFF0F2547)),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Your attendance records will appear here',
                    style: GoogleFonts.inter(fontSize: 12.sp, color: const Color(0xFF6B7A90), fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 20.h),
                ],
              ),
            )
          ] else ...[
            // Renders clean list of dynamic attendance records
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _attendanceRecords.length,
              itemBuilder: (ctx, index) {
                final record = _attendanceRecords[index];
                final dateStr = record['date']?.toString() ?? '';
                final status = record['status']?.toString() ?? 'PRESENT';
                final checkIn = record['checkInTime'] != null 
                    ? intl.DateFormat('hh:mm a').format(DateTime.parse(record['checkInTime']))
                    : '--:--';
                final isPresent = status.toUpperCase().startsWith('P');

                return Container(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(dateStr, style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w700, color: const Color(0xFF0F2547))),
                          SizedBox(height: 2.h),
                          Text('Check In: $checkIn', style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF6B7A90))),
                        ],
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: isPresent ? const Color(0xFFECFDF5) : const Color(0xFFFFE4E6),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          isPresent ? 'Present' : 'Absent',
                          style: GoogleFonts.inter(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w800,
                            color: isPresent ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          ),
                        ),
                      )
                    ],
                  ),
                );
              },
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildCalendarIllustration() {
    return SizedBox(
      width: 120.w,
      height: 90.h,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Calendar Background Paper
          Container(
            width: 70.w,
            height: 70.h,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: const Color(0xFFBACADB), width: 1.5.w),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE2EAF4).withValues(alpha: 0.5),
                  blurRadius: 10.r,
                  offset: Offset(0, 4.h),
                )
              ],
            ),
            child: Column(
              children: [
                // Top header bar of calendar (blue)
                Container(
                  height: 16.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(10.r),
                      topRight: Radius.circular(10.r),
                    ),
                  ),
                ),
                SizedBox(height: 6.h),
                // Calendar grid rows
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(4, (rowIndex) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(5, (colIndex) {
                            final isSelected = rowIndex == 2 && colIndex == 3;
                            return Container(
                              width: 6.w,
                              height: 6.w,
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFFE2EAF4),
                                borderRadius: BorderRadius.circular(1.5.r),
                              ),
                            );
                          }),
                        );
                      }),
                    ),
                  ),
                )
              ],
            ),
          ),
          // Ring binders at the top of calendar
          Positioned(
            top: 2.h,
            left: 36.w,
            child: _buildCalendarRing(),
          ),
          Positioned(
            top: 2.h,
            right: 36.w,
            child: _buildCalendarRing(),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarRing() {
    return Container(
      width: 5.w,
      height: 12.h,
      decoration: BoxDecoration(
        color: const Color(0xFF94A3B8),
        borderRadius: BorderRadius.circular(2.r),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // TEACHER PANEL: ACADEMIC MANAGEMENT
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildTeacherManagementUI() {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: _buildDrawer(),
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
              leading: IconButton(
                icon: Icon(Icons.menu, size: 28.sp),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              title: Text(
                'EduSphere',
                style: GoogleFonts.outfit(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.notifications_none_rounded, size: 26.sp),
                  onPressed: () {},
                ),
                Container(
                  margin: EdgeInsets.only(right: 16.w, top: 8.h, bottom: 8.h),
                  padding: EdgeInsets.all(8.r),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE0F2FE),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text('AS', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: const Color(0xFF0284C7))),
                  ),
                ),
              ],
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            _buildManagementHeader(),
            _buildManagementTabs(),
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                child: _buildActiveTabContent(),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _activeTab < 3
          ? Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_showFabMenu) _buildFabMenu(),
                SizedBox(width: 12.w),
                FloatingActionButton(
                  heroTag: null,
                  onPressed: () => setState(() => _showFabMenu = !_showFabMenu),
                  backgroundColor: const Color(0xFF0D7DDC),
                  elevation: 4,
                  shape: const CircleBorder(),
                  child: _buildFabIcon(),
                ),
              ],
            )
          : null,
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildManagementHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 16.h),
      child: Row(
        children: [
          if (!widget.showAppBar) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
              onPressed: widget.onBack ?? () => Navigator.pop(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            SizedBox(width: 12.w),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Academic Management',
                  style: GoogleFonts.outfit(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Manage classes, subjects, and sections',
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManagementTabs() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: _buildTabs(),
    );
  }

  Widget _buildTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      child: Container(
        padding: EdgeInsets.all(4.r),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(100.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTabSelector(0, 'Classes'),
            _buildTabSelector(1, 'Subjects'),
            _buildTabSelector(2, 'Sections'),
            _buildTabSelector(3, 'Exams & Results'),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector(int index, String label) {
    final isSelected = _activeTab == index;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(100.r),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
          border: isSelected
              ? Border.all(color: const Color(0xFFE2EBF5), width: 1)
              : Border.all(color: Colors.transparent, width: 1),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.sp,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTabContent() {
    switch (_activeTab) {
      case 0:
        return _buildClassesTab();
      case 1:
        return _buildSubjectsTab();
      case 2:
        return _buildSectionsTab();
      case 3:
        return _buildExamsTab();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Teacher classes listing ──
  Widget _buildClassesTab() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 16.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Classes', style: GoogleFonts.outfit(fontSize: 18.sp, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                SizedBox(height: 4.h),
                Text('Manage class/grade levels', style: GoogleFonts.inter(fontSize: 12.sp, color: const Color(0xFF64748B))),
              ],
            ),
          ),
          _classesList.isEmpty
              ? _buildEmptyState('No classes found. Create one to get started.', _showAddClassDialog)
              : _buildCustomClassesTable(),
        ],
      ),
    );
  }

  Widget _buildCustomClassesTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Row
        Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
          ),
          child: Row(
            children: [
              Expanded(flex: 3, child: _buildTableHeaderCell('Name', TextAlign.left)),
              Expanded(flex: 2, child: _buildTableHeaderCell('Level', TextAlign.center)),
              Expanded(flex: 3, child: _buildTableHeaderCell('Academic Year', TextAlign.center)),
              Expanded(flex: 4, child: _buildTableHeaderCell('Class Teacher', TextAlign.center)),
              Expanded(flex: 3, child: _buildTableHeaderCell('Students', TextAlign.center)),
            ],
          ),
        ),
        // Data Rows
        ..._classesList.asMap().entries.map((entry) {
          final c = entry.value;
          return _ClassesRowItem(
            name: c['name']?.toString() ?? '',
            level: c['level']?.toString() ?? '',
            academicYear: c['academic_year']?.toString() ?? '—',
            classTeacher: c['class_teacher']?.toString() ?? '—',
            students: c['students']?.toString() ?? '0',
            isHoveredDemo: c['name'] == 'Grade 5', // Hover effect to match screenshot
          );
        }),
        SizedBox(height: 12.h),
      ],
    );
  }

  Widget _buildTableHeaderCell(String text, [TextAlign align = TextAlign.left]) {
    return Text(
      text,
      textAlign: align,
      style: GoogleFonts.inter(
        fontSize: 11.sp,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF64748B),
      ),
    );
  }

  // ── Teacher subjects listing ──
  Widget _buildSubjectsTab() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 16.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Subjects', style: GoogleFonts.outfit(fontSize: 18.sp, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                SizedBox(height: 4.h),
                Text('Manage academic subjects', style: GoogleFonts.inter(fontSize: 12.sp, color: const Color(0xFF64748B))),
              ],
            ),
          ),
          
          // Search Bar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: _buildSubjectsSearchBar(),
          ),
          SizedBox(height: 16.h),

          _subjectsList.isEmpty
              ? Padding(
                  padding: EdgeInsets.only(bottom: 20.h),
                  child: _buildEmptyState('No subjects found. Create one to get started.', _showAddSubjectDialog),
                )
              : _buildCustomSubjectsTable(),
        ],
      ),
    );
  }

  Widget _buildSubjectsSearchBar() {
    return Container(
      height: 44.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      child: Row(
        children: [
          Icon(Icons.search, size: 20.sp, color: const Color(0xFF94A3B8)),
          SizedBox(width: 8.w),
          Expanded(
            child: TextField(
              onChanged: (val) {
                setState(() {
                  _subjectSearchQuery = val;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search subjects...',
                hintStyle: GoogleFonts.inter(fontSize: 13.sp, color: const Color(0xFF94A3B8)),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10.h),
              ),
              style: GoogleFonts.inter(fontSize: 13.sp, color: const Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomSubjectsTable() {
    final filteredList = _subjectsList.where((s) {
      final name = s['name']?.toString().toLowerCase() ?? '';
      final code = s['code']?.toString().toLowerCase() ?? '';
      final query = _subjectSearchQuery.toLowerCase();
      return name.contains(query) || code.contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Row
        Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
          ),
          child: Row(
            children: [
              Expanded(flex: 4, child: _buildTableHeaderCell('Name', TextAlign.left)),
              Expanded(flex: 2, child: _buildTableHeaderCell('Code', TextAlign.center)),
              Expanded(flex: 2, child: _buildTableHeaderCell('Class', TextAlign.center)),
              Expanded(flex: 2, child: _buildTableHeaderCell('Teacher', TextAlign.center)),
              Expanded(flex: 2, child: _buildTableHeaderCell('Description', TextAlign.center)),
              const Expanded(flex: 1, child: SizedBox.shrink()), // Space for trailing chevron
            ],
          ),
        ),
        // Data Rows
        ...filteredList.map((s) {
          return _SubjectsRowItem(
            name: s['name']?.toString() ?? '',
            code: s['code']?.toString() ?? '',
            className: s['class']?.toString() ?? '—',
            teacher: s['teacher']?.toString() ?? '—',
            description: s['description']?.toString() ?? '-',
          );
        }),
        SizedBox(height: 12.h),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // SECTIONS TAB
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildSectionsTab() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 16.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sections', style: GoogleFonts.outfit(fontSize: 18.sp, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                SizedBox(height: 4.h),
                Text('Manage class sections/divisions', style: GoogleFonts.inter(fontSize: 12.sp, color: const Color(0xFF64748B))),
              ],
            ),
          ),
          
          // Search Bar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: _buildSectionsSearchBar(),
          ),
          SizedBox(height: 16.h),

          _sectionsList.isEmpty
              ? Padding(
                  padding: EdgeInsets.only(bottom: 20.h),
                  child: _buildEmptyState('No sections found. Create one to get started.', _showAddSectionDialog),
                )
              : _buildCustomSectionsTable(),
        ],
      ),
    );
  }

  Widget _buildSectionsSearchBar() {
    return Container(
      height: 44.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      child: Row(
        children: [
          Icon(Icons.search, size: 20.sp, color: const Color(0xFF94A3B8)),
          SizedBox(width: 8.w),
          Expanded(
            child: TextField(
              onChanged: (val) {
                setState(() {
                  _sectionSearchQuery = val;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search sections...',
                hintStyle: GoogleFonts.inter(fontSize: 13.sp, color: const Color(0xFF94A3B8)),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10.h),
              ),
              style: GoogleFonts.inter(fontSize: 13.sp, color: const Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Teacher exams listing ──
  Widget _buildCustomSectionsTable() {
    final filteredList = _sectionsList.where((s) {
      final name = s['name']?.toString().toLowerCase() ?? '';
      final className = s['class']?.toString().toLowerCase() ?? '';
      final query = _sectionSearchQuery.toLowerCase();
      return name.contains(query) || className.contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Row
        Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
          ),
          child: Row(
            children: [
              Expanded(flex: 4, child: _buildTableHeaderCell('Name', TextAlign.left)),
              Expanded(flex: 3, child: _buildTableHeaderCell('Class', TextAlign.center)),
              Expanded(flex: 3, child: _buildTableHeaderCell('Max Students', TextAlign.center)),
              Expanded(flex: 3, child: _buildTableHeaderCell('Students', TextAlign.center)),
              const Expanded(flex: 1, child: SizedBox.shrink()), // Space for trailing chevron
            ],
          ),
        ),
        // Data Rows
        ...filteredList.map((s) {
          return _SectionsRowItem(
            name: s['name']?.toString() ?? '',
            className: s['class']?.toString() ?? '—',
            maxStudents: s['max_students']?.toString() ?? '40',
            students: s['students']?.toString() ?? '0',
          );
        }),
        SizedBox(height: 12.h),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // EXAMS & RESULTS TAB
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildExamsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Examination & Results', style: GoogleFonts.outfit(fontSize: 16.sp, fontWeight: FontWeight.w800)),
        Text('Configure terms, grading scales, and manage student results.', style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF64748B))),
        SizedBox(height: 20.h),

        _buildActionCard(
          title: 'Exam Management',
          subtitle: 'Create and schedule exams, assign subjects and marks structure.',
          buttonLabel: 'Go to Exams',
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExamScheduleScreen())),
        ),
        SizedBox(height: 16.h),

        _buildDualActionCard(
          title: 'Terms & Grading',
          subtitle: 'Define academic terms and customize grading scales for the institution.',
          btn1Label: 'Terms',
          onBtn1Pressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExamTermsScreen(theme: widget.theme))),
          btn2Label: 'Grading',
          onBtn2Pressed: () => _showGradingScaleDialog(),
        ),
        SizedBox(height: 16.h),

        _buildActionCard(
          title: 'Approvals',
          subtitle: 'Principal review and approval of generated student report cards.',
          buttonLabel: 'Pending Review',
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExamReportCardScreen(theme: widget.theme))),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required String buttonLabel,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.outfit(fontSize: 14.sp, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
          SizedBox(height: 4.h),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF64748B))),
          SizedBox(height: 16.h),
          SizedBox(
            width: double.infinity,
            height: 44.h,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0066CC),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
              ),
              onPressed: onPressed,
              child: Text(
                buttonLabel,
                style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDualActionCard({
    required String title,
    required String subtitle,
    required String btn1Label,
    required VoidCallback onBtn1Pressed,
    required String btn2Label,
    required VoidCallback onBtn2Pressed,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.outfit(fontSize: 14.sp, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
          SizedBox(height: 4.h),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF64748B))),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44.h,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                    ),
                    onPressed: onBtn1Pressed,
                    child: Text(
                      btn1Label,
                      style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w700, color: const Color(0xFF475569)),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: SizedBox(
                  height: 44.h,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                    ),
                    onPressed: onBtn2Pressed,
                    child: Text(
                      btn2Label,
                      style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w700, color: const Color(0xFF475569)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showGradingScaleDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text('Grading System', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• A+ : 95% - 100% (Excellent)', style: TextStyle(fontWeight: FontWeight.w500)),
            SizedBox(height: 6),
            Text('• A  : 90% - 94% (Very Good)'),
            SizedBox(height: 6),
            Text('• B+ : 85% - 89% (Good)'),
            SizedBox(height: 6),
            Text('• B  : 80% - 84% (Above Average)'),
            SizedBox(height: 6),
            Text('• C  : 70% - 79% (Average)'),
            SizedBox(height: 6),
            Text('• D  : 60% - 69% (Pass)'),
            SizedBox(height: 6),
            Text('• F  : Below 60% (Fail)', style: TextStyle(color: Colors.red)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  // ── Create Dialog Helpers ──
  void _showAddClassDialog() {
    final nameCtrl = TextEditingController();
    final levelCtrl = TextEditingController();
    final yearCtrl = TextEditingController(text: '2026-2027');
    final teacherCtrl = TextEditingController();
    final studentsCtrl = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text('Create Class', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogField(nameCtrl, 'Class Name', 'e.g. Class 10 - A'),
              SizedBox(height: 12.h),
              _buildDialogField(levelCtrl, 'Level', 'e.g. Secondary'),
              SizedBox(height: 12.h),
              _buildDialogField(yearCtrl, 'Academic Year', 'e.g. 2026-2027'),
              SizedBox(height: 12.h),
              _buildDialogField(teacherCtrl, 'Class Teacher', 'e.g. Mr. John Doe'),
              SizedBox(height: 12.h),
              _buildDialogField(studentsCtrl, 'Students Count', 'e.g. 40', keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: widget.theme.primary),
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              setState(() {
                _classesList.add({
                  'name': nameCtrl.text.trim(),
                  'level': levelCtrl.text.trim(),
                  'academic_year': yearCtrl.text.trim(),
                  'class_teacher': teacherCtrl.text.trim(),
                  'students': int.tryParse(studentsCtrl.text.trim()) ?? 0,
                });
              });
              _saveLocalData();
              Navigator.pop(ctx);
            },
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddSubjectDialog() {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final classCtrl = TextEditingController();
    final teacherCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text('Create Subject', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogField(nameCtrl, 'Subject Name', 'e.g. Physics'),
              SizedBox(height: 12.h),
              _buildDialogField(codeCtrl, 'Subject Code', 'e.g. PHY101'),
              SizedBox(height: 12.h),
              _buildDialogField(classCtrl, 'Class/Grade', 'e.g. Class 10'),
              SizedBox(height: 12.h),
              _buildDialogField(teacherCtrl, 'Subject Teacher', 'e.g. Dr. Emily Green'),
              SizedBox(height: 12.h),
              _buildDialogField(descCtrl, 'Description', 'e.g. Intro to Mechanics'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: widget.theme.primary),
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              setState(() {
                _subjectsList.add({
                  'name': nameCtrl.text.trim(),
                  'code': codeCtrl.text.trim(),
                  'class': classCtrl.text.trim(),
                  'teacher': teacherCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                });
              });
              _saveLocalData();
              Navigator.pop(ctx);
            },
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddSectionDialog() {
    final nameCtrl = TextEditingController();
    final classCtrl = TextEditingController();
    final maxCtrl = TextEditingController(text: '40');
    final studentsCtrl = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text('Create Section', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogField(nameCtrl, 'Section Name', 'e.g. Section A'),
              SizedBox(height: 12.h),
              _buildDialogField(classCtrl, 'Class', 'e.g. Class 10'),
              SizedBox(height: 12.h),
              _buildDialogField(maxCtrl, 'Max Students', 'e.g. 40', keyboardType: TextInputType.number),
              SizedBox(height: 12.h),
              _buildDialogField(studentsCtrl, 'Current Students', 'e.g. 35', keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: widget.theme.primary),
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              setState(() {
                _sectionsList.add({
                  'name': nameCtrl.text.trim(),
                  'class': classCtrl.text.trim(),
                  'max_students': int.tryParse(maxCtrl.text.trim()) ?? 40,
                  'students': int.tryParse(studentsCtrl.text.trim()) ?? 0,
                });
              });
              _saveLocalData();
              Navigator.pop(ctx);
            },
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogField(
    TextEditingController ctrl,
    String label,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.inter(fontSize: 12.sp),
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // EMPTY STATE HELPER
  // ═════════════════════════════════════════════════════════════════════════
  // ═════════════════════════════════════════════════════════════════════════
  // EMPTY STATE HELPER
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildEmptyState(String text, VoidCallback onCreate) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 32.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(Icons.folder_open_rounded, size: 48.sp, color: const Color(0xFFCBD5E1)),
          SizedBox(height: 12.h),
          Text(
            text,
            style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8)),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.theme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
            ),
            onPressed: onCreate,
            child: const Text('Create One', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildFabIcon() {
    if (_activeTab == 0) {
      return Icon(Icons.person_add_rounded, color: const Color(0xFFFFD700), size: 28.sp);
    } else if (_activeTab == 1) {
      return Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(right: 2.w),
            child: Icon(Icons.menu_book_rounded, color: Colors.white, size: 20.sp),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.all(1.r),
              decoration: const BoxDecoration(
                color: Color(0xFF0D7DDC),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add, color: const Color(0xFFFFD700), size: 10.sp),
            ),
          ),
        ],
      );
    } else {
      return Icon(Icons.group_add_rounded, color: const Color(0xFFFFD700), size: 28.sp);
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // FAB POPUP MENU
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildFabMenu() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.help_outline_rounded, size: 20.sp, color: const Color(0xFF64748B)),
          SizedBox(height: 6.h),
          Text(
            'HELP',
            style: GoogleFonts.inter(
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF64748B),
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            'ARJUNIT',
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            'CCAV',
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF64748B),
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            'BONNI',
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0D7DDC),
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            'HELP?',
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0D7DDC),
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // BOTTOM NAVIGATION BAR
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 15,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomNavItem(
                icon: Icons.grid_view_outlined,
                label: 'Dashboard',
                isSelected: false,
                onTap: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => MainScreen(role: _userRole, initialIndex: 0)),
                    (r) => false,
                  );
                },
              ),
              _buildBottomNavItem(
                icon: Icons.menu_book_outlined,
                label: 'Academic',
                isSelected: true,
                onTap: () {},
              ),
              _buildBottomNavItem(
                icon: Icons.assignment_outlined,
                label: 'Examinations',
                isSelected: false,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ExamScheduleScreen()));
                },
              ),
              _buildBottomNavItem(
                icon: Icons.edit_note_rounded,
                label: 'Marks Entry',
                isSelected: false,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ExamMarksEntryScreen(theme: widget.theme)));
                },
              ),
              _buildBottomNavItem(
                icon: Icons.more_vert_rounded,
                label: 'More',
                isSelected: false,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => TeacherMoreScreen(theme: widget.theme, onNavigate: (i) {})));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    const activeColor = Color(0xFF0D7DDC);
    const inactiveColor = Color(0xFF94A3B8);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? activeColor : inactiveColor,
              size: 24.sp,
            ),
            SizedBox(height: 4.h),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10.sp,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // ACADEMIC DRAWER IMPLEMENTATION
  // ═════════════════════════════════════════════════════════════════════════
  final String _drawerActiveLabel = 'Academic';

  String _getDrawerInitials(String name) {
    try {
      final parts = name.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
        return parts[0][0].toUpperCase();
      }
    } catch (_) {}
    return 'U';
  }

  Widget _buildDrawer() {
    final initials = _getDrawerInitials(_userName);
    const activeBlue = Color(0xFF0D7DDC);
    const inactiveIcon = Color(0xFF4A6FA5);
    const inactiveText = Color(0xFF35526B);

    return Drawer(
      backgroundColor: Colors.white,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Logo / Brand ──
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 14.h),
              child: Text(
                'EduSphere',
                style: GoogleFonts.inter(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                  letterSpacing: 0.3,
                ),
              ),
            ),
            Divider(height: 1.h, thickness: 1, color: const Color(0xFFEDF2F7)),
            SizedBox(height: 8.h),

            // ── Menu Items ──
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                child: Column(
                  children: _userRole == 'teacher'
                      ? [
                          _drawerItem(
                            icon: Icons.grid_view_rounded,
                            label: 'Dashboard',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (_) => const MainScreen(role: 'teacher', initialIndex: 0)),
                                (r) => false,
                              );
                            },
                          ),
                          _drawerItem(
                            icon: Icons.calendar_month_outlined,
                            label: 'Academic Calendar',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (_) => const MainScreen(role: 'teacher', initialIndex: 1)),
                                (r) => false,
                              );
                            },
                          ),
                          _drawerItem(
                            icon: Icons.people_outline_rounded,
                            label: 'Students',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (_) => const MainScreen(role: 'teacher', initialIndex: 2)),
                                (r) => false,
                              );
                            },
                          ),
                          _drawerItem(
                            icon: Icons.calendar_today_outlined,
                            label: 'Attendance',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (_) => const MainScreen(role: 'teacher', initialIndex: 3)),
                                (r) => false,
                              );
                            },
                          ),
                          _drawerItem(
                            icon: Icons.check_box_outlined,
                            label: 'Assignments',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateAssignmentScreen()));
                            },
                          ),
                          _drawerItem(
                            icon: Icons.menu_book_outlined,
                            label: 'Academic',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () {
                              Navigator.pop(context);
                            },
                          ),
                          _drawerItem(
                            icon: Icons.description_outlined,
                            label: 'Examinations',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const ExamScheduleScreen()));
                            },
                          ),
                          _drawerItem(
                            icon: Icons.assignment_turned_in_outlined,
                            label: 'Marks Entry',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(context, MaterialPageRoute(builder: (_) => ExamMarksEntryScreen(theme: widget.theme)));
                            },
                          ),
                          _drawerItem(
                            icon: Icons.access_time_rounded,
                            label: 'My Schedule',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(context, MaterialPageRoute(builder: (_) => ScheduleScreen(role: 'teacher', theme: widget.theme)));
                            },
                          ),
                          _drawerItem(
                            icon: Icons.notifications_none_rounded,
                            label: 'Announcements',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(context, MaterialPageRoute(builder: (_) => AnnouncementsScreen(theme: widget.theme)));
                            },
                          ),
                          _drawerItem(
                            icon: Icons.group_outlined,
                            label: 'Community',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => CommunityScreen(theme: widget.theme, showAppBar: true, onBack: () => Navigator.pop(context)),
                              ));
                            },
                          ),
                          _drawerItem(
                            icon: Icons.person_outline_rounded,
                            label: 'My Profile',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(role: 'teacher', theme: widget.theme)));
                            },
                          ),
                        ]
                      : [
                          _drawerItem(
                            icon: Icons.grid_view_rounded,
                            label: 'Dashboard',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (_) => const MainScreen(role: 'student', initialIndex: 0)),
                                (r) => false,
                              );
                            },
                          ),
                          _drawerItem(
                            icon: Icons.calendar_month_outlined,
                            label: 'Academic Calendar',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (_) => const MainScreen(role: 'student', initialIndex: 1)),
                                (r) => false,
                              );
                            },
                          ),
                          _drawerItem(
                            icon: Icons.checklist_rounded,
                            label: 'Assignments',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (_) => const MainScreen(role: 'student', initialIndex: 2)),
                                (r) => false,
                              );
                            },
                          ),
                          _drawerItem(
                            icon: Icons.school_rounded,
                            label: 'Academic',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () {
                              Navigator.pop(context);
                            },
                          ),
                          _drawerItem(
                            icon: Icons.attach_money_rounded,
                            label: 'Fees',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (_) => const MainScreen(role: 'student', initialIndex: 4)),
                                (r) => false,
                              );
                            },
                          ),
                          _drawerItem(
                            icon: Icons.directions_bus_rounded,
                            label: 'Transport',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (_) => const MainScreen(role: 'student', initialIndex: 5)),
                                (r) => false,
                              );
                            },
                          ),
                          _drawerItem(
                            icon: Icons.notifications_none_rounded,
                            label: 'Announcements',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (_) => const MainScreen(role: 'student', initialIndex: 6)),
                                (r) => false,
                              );
                            },
                          ),
                          _drawerItem(
                            icon: Icons.group_outlined,
                            label: 'Community',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (_) => const MainScreen(role: 'student', initialIndex: 7)),
                                (r) => false,
                              );
                            },
                          ),
                          _drawerItem(
                            icon: Icons.room_service_outlined,
                            label: 'Services',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (_) => const MainScreen(role: 'student', initialIndex: 8)),
                                (r) => false,
                              );
                            },
                          ),
                          _drawerItem(
                            icon: Icons.person_rounded,
                            label: 'My Profile',
                            activeBlue: activeBlue,
                            inactiveIcon: inactiveIcon,
                            inactiveText: inactiveText,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (_) => const MainScreen(role: 'student', initialIndex: 9)),
                                (r) => false,
                              );
                            },
                          ),
                        ],
                ),
              ),
            ),

            // ── Divider + Logout ──
            Divider(height: 1.h, thickness: 1, color: const Color(0xFFEDF2F7)),
            _drawerItem(
              icon: Icons.logout_rounded,
              label: 'Logout',
              activeBlue: activeBlue,
              inactiveIcon: const Color(0xFF4A6FA5),
              inactiveText: const Color(0xFF35526B),
              forceInactive: true,
              onTap: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                  (route) => false,
                );
              },
            ),

            // ── Profile Card ──
            Container(
              margin: EdgeInsets.fromLTRB(12.w, 4.h, 12.w, 12.h),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7FB),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: const Color(0xFFE2EBF5), width: 1),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 19.r,
                    backgroundColor: activeBlue.withValues(alpha: 0.15),
                    child: Text(
                      initials,
                      style: GoogleFonts.inter(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w800,
                        color: activeBlue,
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userName,
                          style: GoogleFonts.inter(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 1.h),
                        Text(
                          _userRole.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700,
                            color: activeBlue,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String label,
    required Color activeBlue,
    required Color inactiveIcon,
    required Color inactiveText,
    required VoidCallback onTap,
    bool forceInactive = false,
  }) {
    final isActive = !forceInactive && _drawerActiveLabel == label;
    return _PremiumDrawerItem(
      icon: icon,
      label: label,
      isActive: isActive,
      activeBlue: activeBlue,
      inactiveIcon: inactiveIcon,
      inactiveText: inactiveText,
      onTap: onTap,
    );
  }
}

class _ClassesRowItem extends StatefulWidget {
  final String name;
  final String level;
  final String academicYear;
  final String classTeacher;
  final String students;
  final bool isHoveredDemo;

  const _ClassesRowItem({
    required this.name,
    required this.level,
    required this.academicYear,
    required this.classTeacher,
    required this.students,
    this.isHoveredDemo = false,
  });

  @override
  State<_ClassesRowItem> createState() => _ClassesRowItemState();
}

class _ClassesRowItemState extends State<_ClassesRowItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: _isHovered || widget.isHoveredDemo ? const Color(0xFFF8FAFC) : Colors.white,
          border: const Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                widget.name,
                textAlign: TextAlign.left,
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                widget.level,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                widget.academicYear,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Text(
                widget.classTeacher,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                widget.students,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PREMIUM DRAWER ITEM — hover-aware blue pill
// ═══════════════════════════════════════════════════════════════
class _PremiumDrawerItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color activeBlue;
  final Color inactiveIcon;
  final Color inactiveText;
  final VoidCallback onTap;

  const _PremiumDrawerItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.activeBlue,
    required this.inactiveIcon,
    required this.inactiveText,
    required this.onTap,
  });

  @override
  State<_PremiumDrawerItem> createState() => _PremiumDrawerItemState();
}

class _PremiumDrawerItemState extends State<_PremiumDrawerItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final showBlue = widget.isActive || _isHovered;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 1.5.h),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          width: double.infinity,
          decoration: BoxDecoration(
            color: showBlue
                ? widget.activeBlue
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14.r),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14.r),
            child: InkWell(
              onTap: widget.onTap,
              onHighlightChanged: (highlighted) {
                if (highlighted != _isHovered) {
                  setState(() => _isHovered = highlighted);
                }
              },
              borderRadius: BorderRadius.circular(14.r),
              splashColor: Colors.white.withValues(alpha: 0.15),
              highlightColor: Colors.transparent,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
                child: Row(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, anim) =>
                          FadeTransition(opacity: anim, child: child),
                      child: Icon(
                        widget.icon,
                        key: ValueKey('${widget.label}-$showBlue'),
                        color: showBlue ? Colors.white : widget.inactiveIcon,
                        size: 20.sp,
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: GoogleFonts.inter(
                          fontSize: 15.sp,
                          fontWeight: showBlue
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: showBlue ? Colors.white : widget.inactiveText,
                        ),
                        child: Text(widget.label),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SUBJECTS ROW ITEM WIDGET
// ═══════════════════════════════════════════════════════════════
class _SubjectsRowItem extends StatefulWidget {
  final String name;
  final String code;
  final String className;
  final String teacher;
  final String description;

  const _SubjectsRowItem({
    required this.name,
    required this.code,
    required this.className,
    required this.teacher,
    required this.description,
  });

  @override
  State<_SubjectsRowItem> createState() => _SubjectsRowItemState();
}

class _SubjectsRowItemState extends State<_SubjectsRowItem> {
  bool _isHovered = false;

  Widget _buildSubjectAvatar(String name) {
    final cleanName = name.trim().toLowerCase();
    if (cleanName.contains('math')) {
      return Container(
        width: 32.r,
        height: 32.r,
        decoration: const BoxDecoration(
          color: Color(0xFFEFF6FF),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            'π',
            style: GoogleFonts.inter(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF2563EB),
            ),
          ),
        ),
      );
    } else if (cleanName.contains('science')) {
      return Container(
        width: 32.r,
        height: 32.r,
        decoration: const BoxDecoration(
          color: Color(0xFFF0FDF4),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            Icons.science_outlined,
            size: 16.sp,
            color: const Color(0xFF16A34A),
          ),
        ),
      );
    } else if (cleanName.contains('english')) {
      return Container(
        width: 32.r,
        height: 32.r,
        decoration: const BoxDecoration(
          color: Color(0xFFFFF7ED),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            Icons.menu_book_outlined,
            size: 16.sp,
            color: const Color(0xFFEA580C),
          ),
        ),
      );
    } else if (cleanName.contains('social') || cleanName.contains('history') || cleanName.contains('geography')) {
      return Container(
        width: 32.r,
        height: 32.r,
        decoration: const BoxDecoration(
          color: Color(0xFFFAF5FF),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            Icons.public_rounded,
            size: 16.sp,
            color: const Color(0xFF9333EA),
          ),
        ),
      );
    } else if (cleanName.contains('hindi') || cleanName.contains('sanskrit')) {
      return Container(
        width: 32.r,
        height: 32.r,
        decoration: const BoxDecoration(
          color: Color(0xFFFFFBEB),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            'वे',
            style: GoogleFonts.inter(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFD97706),
            ),
          ),
        ),
      );
    } else if (cleanName.contains('computer') || cleanName.contains('tech') || cleanName.contains('coding')) {
      return Container(
        width: 32.r,
        height: 32.r,
        decoration: const BoxDecoration(
          color: Color(0xFFEFF6FF),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            Icons.computer_rounded,
            size: 16.sp,
            color: const Color(0xFF2563EB),
          ),
        ),
      );
    } else {
      return Container(
        width: 32.r,
        height: 32.r,
        decoration: const BoxDecoration(
          color: Color(0xFFF1F5F9),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            Icons.book_rounded,
            size: 16.sp,
            color: const Color(0xFF64748B),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: _isHovered ? const Color(0xFFF8FAFC) : Colors.white,
          border: const Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  _buildSubjectAvatar(widget.name),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      widget.name,
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                widget.code,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                widget.className,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                widget.teacher,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                widget.description,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 16.sp,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SECTIONS ROW ITEM WIDGET
// ═══════════════════════════════════════════════════════════════
class _SectionsRowItem extends StatefulWidget {
  final String name;
  final String className;
  final String maxStudents;
  final String students;

  const _SectionsRowItem({
    required this.name,
    required this.className,
    required this.maxStudents,
    required this.students,
  });

  @override
  State<_SectionsRowItem> createState() => _SectionsRowItemState();
}

class _SectionsRowItemState extends State<_SectionsRowItem> {
  bool _isHovered = false;

  Widget _buildSectionAvatar(String name) {
    String letter = 'A';
    try {
      final parts = name.trim().split(RegExp(r'\s+'));
      if (parts.isNotEmpty) {
        final lastPart = parts.last;
        if (lastPart.isNotEmpty) {
          letter = lastPart[0].toUpperCase();
        }
      }
    } catch (_) {}

    Color bgColor;
    Color textColor;

    if (letter == 'A') {
      bgColor = const Color(0xFFFAF5FF); // light purple
      textColor = const Color(0xFF9333EA); // purple
    } else if (letter == 'B') {
      bgColor = const Color(0xFFEFF6FF); // light blue
      textColor = const Color(0xFF2563EB); // blue
    } else if (letter == 'C') {
      bgColor = const Color(0xFFF0FDF4); // light green
      textColor = const Color(0xFF16A34A); // green
    } else {
      bgColor = const Color(0xFFFFF7ED); // light orange
      textColor = const Color(0xFFEA580C); // orange
    }

    return Container(
      width: 32.r,
      height: 32.r,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          letter,
          style: GoogleFonts.inter(
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: _isHovered ? const Color(0xFFF8FAFC) : Colors.white,
          border: const Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  _buildSectionAvatar(widget.name),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      widget.name,
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                widget.className,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                widget.maxStudents,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                widget.students,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 16.sp,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

