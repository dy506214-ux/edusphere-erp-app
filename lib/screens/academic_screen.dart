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

  @override
  void initState() {
    super.initState();
    if (widget.role == 'student') {
      _loadStudentOverviewData();
    } else {
      _loadLocalData();
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // STUDENT DATA LOADING
  // ═════════════════════════════════════════════════════════════════════════
  Future<void> _loadStudentOverviewData() async {
    if (!mounted) return;
    setState(() {
      _isLoadingStudent = true;
    });

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

  // ═════════════════════════════════════════════════════════════════════════
  // TEACHER LOCAL DATA PERSISTENCE
  // ═════════════════════════════════════════════════════════════════════════
  Future<void> _loadLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final classesJson = prefs.getString('academic_classes_list');
      if (classesJson != null) {
        _classesList = List<Map<String, dynamic>>.from(json.decode(classesJson));
      }
      
      final subjectsJson = prefs.getString('academic_subjects_list');
      if (subjectsJson != null) {
        _subjectsList = List<Map<String, dynamic>>.from(json.decode(subjectsJson));
      }

      final sectionsJson = prefs.getString('academic_sections_list');
      if (sectionsJson != null) {
        _sectionsList = List<Map<String, dynamic>>.from(json.decode(sectionsJson));
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
    if (_timetableSlots.isNotEmpty) {
      return _timetableSlots.map((slot) {
        final subName = slot['subject']?['name'] ?? 'Class Slot';
        return {
          'title': '${_className.split(' ')[0]} • $subName',
          'time': '${slot['startTime']} - ${slot['endTime']}',
        };
      }).toList();
    }
    return [
      {'title': 'Grade 3 • Weekly Timetable', 'time': '9:00 AM - 10:00 AM'},
      {'title': 'Grade 2 • Weekly Timetable', 'time': '10:15 AM - 11:15 AM'},
      {'title': 'Grade 1 • Weekly Timetable', 'time': '1:00 PM - 2:00 PM'},
    ];
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
                      SizedBox(height: 100.h), // Offset for FAB
                    ],
                  ),
                ),
              ),

              // Bottom right timetable slots FAB
              Positioned(
                right: 24.w,
                bottom: 24.h,
                child: FloatingActionButton(
                  onPressed: _showAllTimetablesSheet,
                  backgroundColor: const Color(0xFF0076F6),
                  elevation: 6,
                  child: Icon(Icons.departure_board, color: Colors.white, size: 26.sp),
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Academic Overview',
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
              style: GoogleFonts.inter(
                fontSize: 13.5.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF6B7A90),
              ),
            ),
          ],
        ),

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

          // Timetable Cards List
          ...list.map((slot) => Container(
            width: double.infinity,
            margin: EdgeInsets.only(bottom: 12.h),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: const Color(0xFFE2EAF4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot['title'] as String,
                  style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w800, color: const Color(0xFF0F2547)),
                ),
                SizedBox(height: 4.h),
                Text(
                  slot['time'] as String,
                  style: GoogleFonts.inter(fontSize: 11.5.sp, color: const Color(0xFF6B7A90), fontWeight: FontWeight.w600),
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
              itemCount: _attendanceRecords.length.clamp(0, 5),
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
              leading: Navigator.canPop(context)
                  ? const BackButton(color: Color(0xFF0F172A))
                  : IconButton(
                      icon: Icon(Icons.menu, size: 28.sp),
                      onPressed: () => Scaffold.of(context).openDrawer(),
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
                  icon: Icon(Icons.notifications_none_rounded, size: 28.sp),
                  onPressed: () {},
                ),
                SizedBox(width: 8.w),
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
          ? FloatingActionButton(
              onPressed: _activeTab == 0
                  ? _showAddClassDialog
                  : _activeTab == 1
                      ? _showAddSubjectDialog
                      : _showAddSectionDialog,
              backgroundColor: widget.theme.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildManagementHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      color: Colors.white,
      child: Row(
        children: [
          if (!widget.showAppBar) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
              onPressed: widget.onBack ?? () => Navigator.pop(context),
            ),
            SizedBox(width: 8.w),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Academic Management',
                  style: GoogleFonts.outfit(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Manage classes, subjects, and sections',
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF0F172A)),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildManagementTabs() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        child: Row(
          children: [
            _buildTabSelector(0, 'Classes'),
            SizedBox(width: 6.w),
            _buildTabSelector(1, 'Subjects'),
            SizedBox(width: 6.w),
            _buildTabSelector(2, 'Sections'),
            SizedBox(width: 6.w),
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
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isSelected ? const Color(0xFFBFDBFE) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          style: GoogleFonts.inter(
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF475569),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Classes', style: GoogleFonts.outfit(fontSize: 16.sp, fontWeight: FontWeight.w800)),
        Text('Manage class/grade levels', style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF64748B))),
        SizedBox(height: 16.h),
        _classesList.isEmpty
            ? _buildEmptyState('No classes found. Create one to get started.', _showAddClassDialog)
            : _buildClassesTable(),
      ],
    );
  }

  Widget _buildClassesTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
          columns: const [
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Level')),
            DataColumn(label: Text('Academic Year')),
            DataColumn(label: Text('Class Teacher')),
            DataColumn(label: Text('Students')),
          ],
          rows: _classesList.map((c) {
            return DataRow(cells: [
              DataCell(Text(c['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(Text(c['level']?.toString() ?? '')),
              DataCell(Text(c['academic_year']?.toString() ?? '')),
              DataCell(Text(c['class_teacher']?.toString() ?? '')),
              DataCell(Text(c['students']?.toString() ?? '0')),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  // ── Teacher subjects listing ──
  Widget _buildSubjectsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Subjects', style: GoogleFonts.outfit(fontSize: 16.sp, fontWeight: FontWeight.w800)),
        Text('Manage academic subjects', style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF64748B))),
        SizedBox(height: 16.h),
        _subjectsList.isEmpty
            ? _buildEmptyState('No subjects found. Create one to get started.', _showAddSubjectDialog)
            : _buildSubjectsTable(),
      ],
    );
  }

  Widget _buildSubjectsTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
          columns: const [
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Code')),
            DataColumn(label: Text('Class')),
            DataColumn(label: Text('Teacher')),
            DataColumn(label: Text('Description')),
          ],
          rows: _subjectsList.map((s) {
            return DataRow(cells: [
              DataCell(Text(s['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(Text(s['code']?.toString() ?? '')),
              DataCell(Text(s['class']?.toString() ?? '')),
              DataCell(Text(s['teacher']?.toString() ?? '')),
              DataCell(Text(s['description']?.toString() ?? '', overflow: TextOverflow.ellipsis)),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  // ── Teacher sections listing ──
  Widget _buildSectionsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sections', style: GoogleFonts.outfit(fontSize: 16.sp, fontWeight: FontWeight.w800)),
        Text('Manage class sections/divisions', style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF64748B))),
        SizedBox(height: 16.h),
        _sectionsList.isEmpty
            ? _buildEmptyState('No sections found. Create one to get started.', _showAddSectionDialog)
            : _buildSectionsTable(),
      ],
    );
  }

  Widget _buildSectionsTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
          columns: const [
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Class')),
            DataColumn(label: Text('Max Students')),
            DataColumn(label: Text('Students')),
          ],
          rows: _sectionsList.map((s) {
            return DataRow(cells: [
              DataCell(Text(s['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(Text(s['class']?.toString() ?? '')),
              DataCell(Text(s['max_students']?.toString() ?? '40')),
              DataCell(Text(s['students']?.toString() ?? '0')),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  // ── Teacher exams listing ──
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
}
