import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/socket_service.dart';
import '../services/student_service.dart';
import '../services/academic_service.dart';
import '../services/auth_service.dart';
import 'dart:developer' as dev;
import 'package:intl/intl.dart' as intl;
import '../theme/colors.dart';
import 'features/exam_schedule_screen.dart';
import 'features/exam_terms_screen.dart';
import 'features/results_screen.dart';
import 'main_screen.dart';
import 'welcome_screen.dart';
import 'profile_screen.dart';
import 'community_screen.dart';
import 'features/create_assignment_screen.dart';
import 'features/schedule_screen.dart';
import 'features/student_timetable_screen.dart';
import 'features/announcements_screen.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../widgets/navigation_widgets.dart';
import '../widgets/common_widgets.dart';
import 'package:edusphere/theme/typography.dart';
import '../config/api_endpoints.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Academic Screen — supports student Academic Overview & teacher Academic Management
// ══════════════════════════════════════════════════════════════════════════════
class AcademicScreen extends StatefulWidget {
  final RoleTheme theme;
  final VoidCallback? onBack;
  final bool showAppBar;
  final String role; // 'student' or 'teacher'
  final bool showBackButton;

  const AcademicScreen({
    super.key,
    required this.theme,
    this.onBack,
    this.showAppBar = true,
    this.role = 'student',
    this.showBackButton = false,
  });

  @override
  State<AcademicScreen> createState() => _AcademicScreenState();
}

class _AcademicScreenState extends State<AcademicScreen> {
  // ── Teacher/Management State ──
  int _activeTab =
      0; // 0 = Classes, 1 = Subjects, 2 = Sections, 3 = Exams & Results

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _userName = 'Emma Johnson';
  String _userRole = 'teacher';

  // ── Database Lists ──
  List<Map<String, dynamic>> _classesList = [];
  List<Map<String, dynamic>> _subjectsList = [];
  List<Map<String, dynamic>> _sectionsList = [];

  // ── Student/Overview State ──
  bool _isLoadingStudent = true;
  String _studentEmail = '';
  // ignore: unused_field
  String _studentName = '';
  String _studentId = '';
  String _classId = '';
  String _className = 'Grade 8';
  String _sectionId = '';
  List<Map<String, dynamic>> _studentSubjects = [];
  List<Map<String, dynamic>> _timetableSlots = [];
  final List<Map<String, dynamic>> _attendanceRecords = [];
  double _attendanceRate = 100.0;
  bool _hasAttendanceData = false;
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  // ── Selected day for timetable ──
  final int _selectedTimetableDay = DateTime.now().weekday;

  Timer? _realtimePollTimer;

  @override
  void initState() {
    super.initState();
    if (widget.role == 'student') {
      _loadStudentOverviewData();
    } else {
      _loadLocalData();
    }
    _connectRealTime();
  }

  @override
  void dispose() {
    _realtimePollTimer?.cancel();
    try {
      SocketService().off('attendanceMarked', _onRealtimeEvent);
      SocketService().off('ATTENDANCE_MARKED', _onRealtimeEvent);
      SocketService().off('TIMETABLE_UPDATE', _onRealtimeEvent);
    } catch (_) {}
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
      final savedEmail = prefs.getString('student_email') ??
          prefs.getString('user_email') ??
          'student1@demoschool.com';
      _studentEmail = savedEmail;

      final cachedId = prefs.getString('student_id') ?? '';
      final cachedName = prefs.getString('student_name') ?? '';
      final cachedClassId = prefs.getString('student_class_id') ?? '';
      final cachedSectionId = prefs.getString('student_section_id') ?? '';
      final cachedClassName = prefs.getString('student_class') ?? '';

      // 1. Fetch Student profile via REST API
      try {
        final profileRes = await StudentService.instance.getStudentProfile();
        final student = profileRes['student'];
        if (student != null) {
          _studentId = student['id'] ?? '';
          final user = student['user'] ?? {};
          _studentName = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
          _classId = student['currentClassId'] ?? '';
          _sectionId = student['sectionId'] ?? '';
          
          final classNameVal = student['currentClass']?['name'] ?? '';
          final sectionNameVal = student['section']?['name'] ?? '';
          if (classNameVal.isNotEmpty && sectionNameVal.isNotEmpty) {
            _className = '$classNameVal ($sectionNameVal)';
          } else if (classNameVal.isNotEmpty) {
            _className = classNameVal;
          } else {
            _className = 'Grade 8';
          }

          await prefs.setString('student_id', _studentId);
          await prefs.setString('student_name', _studentName);
          await prefs.setString('student_class_id', _classId);
          await prefs.setString('student_section_id', _sectionId);
          await prefs.setString('student_class', _className);
        }
      } catch (e) {
        dev.log('Error fetching student profile: $e', name: 'AcademicScreen');
      }

      // If profile API failed or returned empty but we have cached values, restore them
      if (_studentId.isEmpty && cachedId.isNotEmpty) {
        _studentId = cachedId;
        _studentName = cachedName;
        _classId = cachedClassId;
        _sectionId = cachedSectionId;
        _className = cachedClassName;
      }

      // 2. Fetch Subjects assigned to their class via REST API
      if (_classId.isNotEmpty) {
        try {
          final subjectsRes = await AcademicService.instance.getSubjects(classId: _classId);
          final rawSubjects = subjectsRes['subjects'] ?? subjectsRes['data'] ?? [];
          _studentSubjects = List<Map<String, dynamic>>.from(rawSubjects);
        } catch (e) {
          dev.log('Error fetching subjects: $e', name: 'AcademicScreen');
        }
      }

      // 3. Fetch Timetable slots for their section/class via REST API
      if (_sectionId.isNotEmpty) {
        try {
          final timetableRes = await ApiService.instance.get(ApiEndpoints.studentTimetable(_sectionId));
          if (timetableRes['success'] == true) {
            _timetableSlots = List<Map<String, dynamic>>.from(timetableRes['schedule'] ?? []);
          }
        } catch (e) {
          dev.log('Error fetching timetable: $e', name: 'AcademicScreen');
        }
      }

      // 4. Fetch Attendance records via REST API
      if (_studentId.isNotEmpty) {
        try {
          final attendanceRes = await ApiService.instance.get(ApiEndpoints.studentAttendance(_studentId));
          if (attendanceRes['success'] == true) {
            _hasAttendanceData = true;

            final List<dynamic> rawList = attendanceRes['attendance'] ?? [];
            int totalMarked = 0;
            double totalPresent = 0.0;
            List<Map<String, dynamic>> validRecords = [];

            for (var r in rawList) {
              final dateStr = r['date']?.toString() ?? '';
              if (dateStr.isEmpty) continue;
              validRecords.add(Map<String, dynamic>.from(r));

              final status = (r['status']?.toString() ?? '').toUpperCase();
              if (status == 'PRESENT' || status == 'P' || status == 'LATE') {
                totalMarked++;
                totalPresent += 1.0;
              } else if (status == 'ABSENT' || status == 'A') {
                totalMarked++;
              } else if (status == 'HALF_DAY') {
                totalMarked++;
                totalPresent += 0.5;
              }
            }

            if (totalMarked > 0) {
              _attendanceRate = (totalPresent / totalMarked) * 100.0;
            } else {
              _attendanceRate = 100.0;
            }

            // Sort by date descending
            validRecords.sort((a, b) {
              final da = a['date']?.toString() ?? '';
              final db = b['date']?.toString() ?? '';
              return db.compareTo(da);
            });

            _attendanceRecords.clear();
            for (var rec in validRecords) {
              final dateStr = rec['date']?.toString() ?? '';
              String normalizedDate = dateStr;
              if (dateStr.contains('T')) {
                normalizedDate = dateStr.split('T')[0];
              }
              _attendanceRecords.add({
                ...rec,
                'date': normalizedDate,
                'isWeekend': false,
                'markedBy': rec['markedByName'] ?? rec['markedBy'] ?? 'System',
              });
            }
          }
        } catch (e) {
          dev.log('❌ Error fetching Attendance from REST API: $e', name: 'AcademicScreen');
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

  void _onRealtimeEvent(dynamic payload) {
    dev.log('🔥 Real-time event received in AcademicScreen: $payload', name: 'AcademicScreen');
    if (mounted) {
      if (widget.role == 'student') {
        _loadStudentOverviewData(showLoading: false);
      } else {
        _loadLocalData();
      }
    }
  }



  void _connectRealTime() {
    try {
      SocketService().off('attendanceMarked', _onRealtimeEvent);
      SocketService().off('ATTENDANCE_MARKED', _onRealtimeEvent);
      SocketService().off('TIMETABLE_UPDATE', _onRealtimeEvent);

      SocketService().on('attendanceMarked', _onRealtimeEvent);
      SocketService().on('ATTENDANCE_MARKED', _onRealtimeEvent);
      SocketService().on('TIMETABLE_UPDATE', _onRealtimeEvent);
    } catch (e) {
      dev.log('⚠️ Error connecting Socket.IO for Academic Screen: $e', name: 'AcademicScreen');
    }

    // Polling fallback every 5 minutes
    _realtimePollTimer?.cancel();
    _realtimePollTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (mounted) {
        if (widget.role == 'student') {
          _loadStudentOverviewData(showLoading: false);
        } else {
          _loadLocalData();
        }
      }
    });
  }

  // ═════════════════════════════════════════════════════════════════════════
  // TEACHER LOCAL DATA PERSISTENCE
  // ═════════════════════════════════════════════════════════════════════════
  Future<void> _loadLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userName = prefs.getString('teacher_name') ??
          prefs.getString('student_name') ??
          'Emma Johnson';
      _userRole = prefs.getString('user_role') ?? 'teacher';

      // Fetch from ApiService for real-time accurate backend data
      final results = await Future.wait([
        ApiService.instance.get('academic/classes'),
        ApiService.instance.get('academic/subjects'),
        ApiService.instance.get('academic/sections'),
      ]);

      final rawClasses =
          (results[0]['classes'] ?? results[0]['data'] ?? []) as List;
      final rawSubjects =
          (results[1]['subjects'] ?? results[1]['data'] ?? []) as List;
      final rawSections =
          (results[2]['sections'] ?? results[2]['data'] ?? []) as List;

      final List<Map<String, dynamic>> loadedClasses = rawClasses.map((c) {
        final classTeacher = c['classTeacher'] as Map?;
        final user = classTeacher != null ? classTeacher['user'] as Map? : null;
        
        final tName = user != null
            ? '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim()
            : '—';

        // Use Prisma's _count if available, else 0
        final stCount =
            c['_count']?['students'] ?? c['_count']?['Student'] ?? 0;

        return {
          'id': c['id'],
          'name': c['name']?.toString() ?? '',
          'level': c['numericValue']?.toString() ?? c['level']?.toString() ?? '',
          'academic_year': c['academicYear'] != null ? c['academicYear']['name']?.toString() ?? '2024-2025' : '2024-2025',
          'class_teacher': tName.isNotEmpty ? tName : '—',
          'students': stCount,
        };
      }).toList();

      final List<Map<String, dynamic>> loadedSubjects = rawSubjects.map((s) {
        final classData = s['Class'] ?? s['class'] as Map?;
        final className =
            classData != null ? classData['name']?.toString() ?? '—' : '—';
        
        final teachersList = s['teachers'] as List?;
        String tName = '—';
        if (teachersList != null && teachersList.isNotEmpty) {
          final firstTeacher = teachersList[0]['teacher'] as Map?;
          if (firstTeacher != null && firstTeacher['user'] != null) {
            final user = firstTeacher['user'];
            tName = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
          }
        }

        return {
          'id': s['id'],
          'name': s['name']?.toString() ?? '',
          'code': s['code']?.toString() ?? '',
          'class': className,
          'teacher': tName.isNotEmpty ? tName : '—',
          'description': s['description']?.toString() ?? '-',
        };
      }).toList();

      final List<Map<String, dynamic>> loadedSections = rawSections.map((sec) {
        final classData = sec['Class'] ?? sec['class'] as Map?;
        final className =
            classData != null ? classData['name']?.toString() ?? '—' : '—';

        final stCount =
            sec['_count']?['students'] ?? sec['_count']?['Student'] ?? 0;

        return {
          'id': sec['id'],
          'name': sec['name']?.toString() ?? '',
          'class': className,
          'max_students': sec['maxStudents'] ?? 40,
          'students': stCount,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _classesList = loadedClasses;
          _subjectsList = loadedSubjects;
          _sectionsList = loadedSections;
        });
      }
    } catch (e) {
      dev.log('Error loading teacher database data: $e');
    }
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
        // Sort by period number
        filtered.sort((a, b) {
          final pa = a['period'] is int
              ? a['period'] as int
              : int.tryParse(a['period']?.toString() ?? '0') ?? 0;
          final pb = b['period'] is int
              ? b['period'] as int
              : int.tryParse(b['period']?.toString() ?? '0') ?? 0;
          return pa.compareTo(pb);
        });
        return filtered.map((slot) {
          final subName = slot['subject']?['name'] ?? 'Class Slot';
          final subCode = slot['subject']?['code'] ?? 'N/A';
          final roomId = slot['roomId'];
          final period = slot['period'];
          final room = (roomId != null && roomId.toString().isNotEmpty)
              ? roomId.toString()
              : (period != null ? 'Period $period' : 'Classroom');
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

    // Fallback to mock data removed for production database lock
    return const [];
  }

  void _showAllTimetablesSheet() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const StudentTimetableScreen()),
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
                      key: _refreshIndicatorKey,
                      onRefresh: () =>
                          _loadStudentOverviewData(showLoading: false),
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
    final canGoBack = widget.showBackButton &&
        (widget.onBack != null || Navigator.canPop(context));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (canGoBack) ...[
          GestureDetector(
            onTap: () {
              if (widget.onBack != null) {
                widget.onBack!();
              } else {
                Navigator.maybePop(context);
              }
            },
            child: Container(
              padding: EdgeInsets.all(10.r),
              margin: EdgeInsets.only(right: 12.w),
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
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  color: const Color(0xFF0F2547), size: 16.sp),
            ),
          ),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Academic Overview',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    AppTypography.h3.copyWith(color: const Color(0xFF0F2547)),
              ),
              SizedBox(height: 4.h),
              Text(
                'Manage your academic journey',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption
                    .copyWith(color: const Color(0xFF6B7A90)),
              ),
            ],
          ),
        ),
        SizedBox(width: 12.w),
        GestureDetector(
          onTap: () => _loadStudentOverviewData(showLoading: true),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: const Color(0xFFE2EAF4)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 6.r,
                )
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.refresh_rounded,
                  color: const Color(0xFF0D7DDC),
                  size: 16.sp,
                ),
                SizedBox(width: 6.w),
                Text(
                  'Refresh',
                  style: GoogleFonts.outfit(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
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
                child: Icon(Icons.book_outlined,
                    color: const Color(0xFF0076F6), size: 20.sp),
              ),
              SizedBox(width: 14.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Subjects',
                    style: AppTypography.small
                        .copyWith(color: const Color(0xFF0F2547)),
                  ),
                  Text(
                    'Subjects assigned to your class',
                    style: AppTypography.caption
                        .copyWith(color: const Color(0xFF6B7A90)),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 20.h),

          // Table Header
          Row(
            children: [
              Expanded(
                  flex: 3,
                  child: Text('Subject',
                      style: AppTypography.caption
                          .copyWith(color: const Color(0xFF94A3B8)))),
              Expanded(
                  flex: 2,
                  child: Center(
                      child: Text('Code',
                          style: AppTypography.caption
                              .copyWith(color: const Color(0xFF94A3B8))))),
              Expanded(
                  flex: 2,
                  child: Center(
                      child: Text('Type',
                          style: AppTypography.caption
                              .copyWith(color: const Color(0xFF94A3B8))))),
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
                        style: AppTypography.caption
                            .copyWith(color: const Color(0xFF0F2547)),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Text(
                          sub['code'] as String,
                          style: AppTypography.caption
                              .copyWith(color: const Color(0xFF6B7A90)),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8.w, vertical: 3.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Text(
                            (sub['type'] ?? 'CORE').toString().toUpperCase(),
                            style: AppTypography.caption
                                .copyWith(color: const Color(0xFF475569)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          SizedBox(height: 8.h),
        ],
      ),
    );
  }

  Widget _buildTimetableCard() {
    // ignore: unused_local_variable
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
                child: Icon(Icons.schedule_rounded,
                    color: const Color(0xFF0076F6), size: 20.sp),
              ),
              SizedBox(width: 14.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Timetable',
                    style: AppTypography.small
                        .copyWith(color: const Color(0xFF0F2547)),
                  ),
                  Text(
                    'Recent class schedules',
                    style: AppTypography.caption
                        .copyWith(color: const Color(0xFF6B7A90)),
                  ),
                ],
              ),
            ],
          ),
          // Sub-card
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: const Color(0xFFE2EAF4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_className - A Weekly Routine',
                  style: AppTypography.small
                      .copyWith(color: const Color(0xFF0F2547)),
                ),
                SizedBox(height: 6.h),
                Text(
                  'DAILY',
                  style: AppTypography.caption
                      .copyWith(color: const Color(0xFF6B7A90)),
                ),
              ],
            ),
          ),
          SizedBox(height: 20.h),

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
                  'View All',
                  style: AppTypography.caption
                      .copyWith(color: const Color(0xFF0076F6)),
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
            Icon(Icons.check_circle_outline_rounded,
                color: const Color(0xFF0076F6), size: 20.sp),
            SizedBox(width: 8.w),
            Text(
              'Academic Status',
              style:
                  AppTypography.small.copyWith(color: const Color(0xFF0F2547)),
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
                value: _hasAttendanceData
                    ? 'Status Available'
                    : 'Status Available',
              ),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildStatusMetricCard(
      {required IconData icon, required String label, required String value}) {
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
            style:
                AppTypography.caption.copyWith(color: const Color(0xFF6B7A90)),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style:
                AppTypography.caption.copyWith(color: const Color(0xFF0076F6)),
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
                child: Icon(Icons.calendar_month_outlined,
                    color: const Color(0xFF0076F6), size: 20.sp),
              ),
              SizedBox(width: 14.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Attendance History',
                    style: AppTypography.small
                        .copyWith(color: const Color(0xFF0F2547)),
                  ),
                  Text(
                    'Recent attendance records',
                    style: AppTypography.caption
                        .copyWith(color: const Color(0xFF6B7A90)),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 24.h),

          if (_attendanceRecords.isEmpty) ...[
            Center(
              child: Column(
                children: [
                  _buildCalendarIllustration(),
                  SizedBox(height: 14.h),
                  Text(
                    'No attendance records found',
                    style: AppTypography.small
                        .copyWith(color: const Color(0xFF0F2547)),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Your attendance records will appear here',
                    style: AppTypography.caption
                        .copyWith(color: const Color(0xFF6B7A90)),
                  ),
                  SizedBox(height: 20.h),
                ],
              ),
            )
          ] else ...[
            // Table Header
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Text(
                    'S.No.',
                    style: AppTypography.caption
                        .copyWith(color: const Color(0xFF475569), fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Date',
                    style: AppTypography.caption
                        .copyWith(color: const Color(0xFF475569), fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Marked By',
                    style: AppTypography.caption
                        .copyWith(color: const Color(0xFF475569), fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Text(
                      'Status',
                      style: AppTypography.caption
                          .copyWith(color: const Color(0xFF475569), fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            Divider(color: const Color(0xFFE2E8F0), thickness: 1, height: 24.h),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _attendanceRecords.length,
              itemBuilder: (ctx, index) {
                final record = _attendanceRecords[index];
                final rawDate = record['date']?.toString() ?? '';
                final status =
                    (record['status']?.toString() ?? 'PRESENT').toUpperCase();

                DateTime? parsedDate;
                try {
                  parsedDate = DateTime.parse(rawDate);
                } catch (_) {}

                final displayDate = parsedDate != null
                    ? '${parsedDate.month}/${parsedDate.day}/${parsedDate.year}'
                    : rawDate;

                String markedByStr = 'System';
                final markedByVal = record['markedBy']?.toString();
                if (markedByVal != null && markedByVal.isNotEmpty) {
                  markedByStr = markedByVal.length > 20 ? 'Teacher' : markedByVal;
                }

                // Determine badge style based on status
                Color badgeBg = Colors.white;
                Color badgeText = const Color(0xFF64748B);
                String badgeLabel = 'NOT MARKED';

                if (status == 'PRESENT' || status == 'P') {
                  badgeLabel = 'PRESENT';
                  badgeBg = const Color(0xFFDCFCE7);
                  badgeText = const Color(0xFF16A34A);
                } else if (status == 'ABSENT' || status == 'A') {
                  badgeLabel = 'ABSENT';
                  badgeBg = const Color(0xFFFEE2E2);
                  badgeText = const Color(0xFFDC2626);
                } else if (status == 'LATE') {
                  badgeLabel = 'LATE';
                  badgeBg = const Color(0xFFFEF9C3);
                  badgeText = const Color(0xFFCA8A04);
                } else if (status == 'HALF_DAY') {
                  badgeLabel = 'HALF DAY';
                  badgeBg = const Color(0xFFE0E7FF);
                  badgeText = const Color(0xFF4F46E5);
                } else if (status == 'LEAVE' || status == 'ON_LEAVE') {
                  badgeLabel = 'LEAVE';
                  badgeBg = const Color(0xFFF3E8FF);
                  badgeText = const Color(0xFF9333EA);
                } else if (status == 'WEEKEND' || status == 'HOLIDAY') {
                  badgeLabel = 'WEEKEND';
                  badgeBg = const Color(0xFFF1F5F9);
                  badgeText = const Color(0xFF6B7A90);
                } else {
                  badgeLabel = status;
                  badgeBg = const Color(0xFFF1F5F9);
                  badgeText = const Color(0xFF475569);
                }

                return Container(
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1.0),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // S.No.
                      Expanded(
                        flex: 1,
                        child: Text(
                          '${index + 1}',
                          style: AppTypography.caption
                              .copyWith(color: const Color(0xFF0F2547), fontWeight: FontWeight.bold),
                        ),
                      ),
                      // Date Column
                      Expanded(
                        flex: 3,
                        child: Text(
                          displayDate,
                          style: AppTypography.caption
                              .copyWith(color: const Color(0xFF0F2547)),
                        ),
                      ),
                      // Marked By Column
                      Expanded(
                        flex: 3,
                        child: Text(
                          markedByStr,
                          style: AppTypography.caption
                              .copyWith(color: const Color(0xFF475569)),
                        ),
                      ),
                      // Status Column
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 10.w, vertical: 6.h),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Text(
                              badgeLabel,
                              style: AppTypography.caption
                                  .copyWith(color: badgeText, fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
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
                    padding:
                        EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(4, (rowIndex) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(5, (colIndex) {
                            final isSelected = rowIndex == 2 && colIndex == 3;
                            return Container(
                              width: 5.w,
                              height: 5.w,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF3B82F6)
                                    : const Color(0xFFE2EAF4),
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
      drawer: widget.showBackButton ? _buildDrawer() : null,
      appBar: widget.showAppBar
          ? const TeacherTopNavbar(title: 'Academic')
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
      floatingActionButton: null,
      bottomNavigationBar:
          widget.showAppBar ? _buildBottomNavigationBar() : null,
    );
  }

  Widget _buildManagementHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 16.h),
      child: Row(
        children: [
          if (widget.showBackButton) ...[
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
                  style: AppTypography.caption
                      .copyWith(color: const Color(0xFF64748B)),
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
          style: AppTypography.caption.copyWith(
              color: isSelected
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF64748B)),
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
                Text('Classes',
                    style: GoogleFonts.outfit(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A))),
                SizedBox(height: 4.h),
                Text('Manage class/grade levels',
                    style: AppTypography.caption
                        .copyWith(color: const Color(0xFF64748B))),
              ],
            ),
          ),
          _classesList.isEmpty
              ? _buildEmptyState('No classes found. Create one to get started.',
                  _showAddClassDialog)
              : _buildCustomClassesTable(),
        ],
      ),
    );
  }

  Widget _buildCustomClassesTable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        const double minTableWidth = 580.0;
        final bool useHorizontalScroll = availableWidth < minTableWidth;

        Widget tableContent = Column(
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
                  Expanded(
                      flex: 3,
                      child: _buildTableHeaderCell('Name', TextAlign.left)),
                  Expanded(
                      flex: 2,
                      child: _buildTableHeaderCell('Level', TextAlign.center)),
                  Expanded(
                      flex: 3,
                      child:
                          _buildTableHeaderCell('Academic Year', TextAlign.center)),
                  Expanded(
                      flex: 4,
                      child:
                          _buildTableHeaderCell('Class Teacher', TextAlign.center)),
                  Expanded(
                      flex: 3,
                      child: _buildTableHeaderCell('Students', TextAlign.center)),
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
                isHoveredDemo:
                    false, // Ensure this relies on real hover, not demo effect
              );
            }),
            SizedBox(height: 12.h),
          ],
        );

        if (useHorizontalScroll) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: minTableWidth,
              child: tableContent,
            ),
          );
        } else {
          return tableContent;
        }
      },
    );
  }

  Widget _buildTableHeaderCell(String text,
      [TextAlign align = TextAlign.left]) {
    return Text(
      text,
      textAlign: align,
      style: AppTypography.caption.copyWith(color: const Color(0xFF64748B)),
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
                Text('Subjects',
                    style: GoogleFonts.outfit(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A))),
                SizedBox(height: 4.h),
                Text('Manage academic subjects',
                    style: AppTypography.caption
                        .copyWith(color: const Color(0xFF64748B))),
              ],
            ),
          ),

          // Removed Search Bar as per image

          _subjectsList.isEmpty
              ? Padding(
                  padding: EdgeInsets.only(bottom: 20.h),
                  child: _buildEmptyState(
                      'No subjects found. Create one to get started.',
                      _showAddSubjectDialog),
                )
              : _buildCustomSubjectsTable(),
        ],
      ),
    );
  }

  Widget _buildCustomSubjectsTable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        const double minTableWidth = 580.0;
        final bool useHorizontalScroll = availableWidth < minTableWidth;

        Widget tableContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              decoration: const BoxDecoration(
                border:
                    Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
              ),
              child: Row(
                children: [
                  Expanded(
                      flex: 3,
                      child: _buildTableHeaderCell('Name', TextAlign.left)),
                  Expanded(
                      flex: 2,
                      child: _buildTableHeaderCell('Code', TextAlign.left)),
                  Expanded(
                      flex: 2,
                      child: _buildTableHeaderCell('Class', TextAlign.left)),
                  Expanded(
                      flex: 2,
                      child: _buildTableHeaderCell('Teacher', TextAlign.left)),
                  Expanded(
                      flex: 2,
                      child: _buildTableHeaderCell('Description', TextAlign.left)),
                ],
              ),
            ),
            // Data Rows
            ..._subjectsList.map((s) {
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

        if (useHorizontalScroll) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: minTableWidth,
              child: tableContent,
            ),
          );
        } else {
          return tableContent;
        }
      },
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
                Text('Sections',
                    style: GoogleFonts.outfit(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A))),
                SizedBox(height: 4.h),
                Text('Manage class sections/divisions',
                    style: AppTypography.caption
                        .copyWith(color: const Color(0xFF64748B))),
              ],
            ),
          ),

          // Removed Search Bar

          _sectionsList.isEmpty
              ? Padding(
                  padding: EdgeInsets.only(bottom: 20.h),
                  child: _buildEmptyState(
                      'No sections found. Create one to get started.',
                      _showAddSectionDialog),
                )
              : _buildCustomSectionsTable(),
        ],
      ),
    );
  }

  // ── Teacher exams listing ──
  Widget _buildCustomSectionsTable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        const double minTableWidth = 580.0;
        final bool useHorizontalScroll = availableWidth < minTableWidth;

        Widget tableContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              decoration: const BoxDecoration(
                border:
                    Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
              ),
              child: Row(
                children: [
                  Expanded(
                      flex: 4,
                      child: _buildTableHeaderCell('Name', TextAlign.left)),
                  Expanded(
                      flex: 3,
                      child: _buildTableHeaderCell('Class', TextAlign.left)),
                  Expanded(
                      flex: 3,
                      child:
                          _buildTableHeaderCell('Max\nStudents', TextAlign.left)),
                  Expanded(
                      flex: 3,
                      child: _buildTableHeaderCell('Students', TextAlign.left)),
                ],
              ),
            ),
            // Data Rows
            ..._sectionsList.map((s) {
              final rawName = s['name']?.toString().trim() ?? '';
              String formattedName = rawName;
              if (rawName.isNotEmpty &&
                  !rawName.toLowerCase().startsWith('section')) {
                formattedName = 'Section\n$rawName';
              } else if (rawName.toLowerCase().startsWith('section ')) {
                // Replace the first space with a newline to match the stacked look
                formattedName = rawName.replaceFirst(' ', '\n');
              }

              return _SectionsRowItem(
                name: formattedName,
                className: s['class']?.toString() ?? '—',
                maxStudents: s['max_students']?.toString() ?? '40',
                students: s['students']?.toString() ?? '0',
              );
            }),
            SizedBox(height: 12.h),
          ],
        );

        if (useHorizontalScroll) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: minTableWidth,
              child: tableContent,
            ),
          );
        } else {
          return tableContent;
        }
      },
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // EXAMS & RESULTS TAB
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildExamsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Examination & Results',
            style: GoogleFonts.outfit(
                fontSize: 16.sp, fontWeight: FontWeight.w800)),
        Text('Configure terms, grading scales, and manage student results.',
            style:
                AppTypography.caption.copyWith(color: const Color(0xFF64748B))),
        SizedBox(height: 20.h),
        _buildActionCard(
          title: 'Exam Management',
          subtitle:
              'Create and schedule exams, assign subjects and marks structure.',
          buttonLabel: 'Go to Exams',
          onPressed: () => MainScreen.navigateTo(context, 8),
        ),
        SizedBox(height: 16.h),
        _buildDualActionCard(
          title: 'Terms & Grading',
          subtitle:
              'Define academic terms and customize grading scales for the institution.',
          btn1Label: 'Terms',
          onBtn1Pressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ExamTermsScreen(theme: widget.theme))),
          btn2Label: 'Grading',
          onBtn2Pressed: () => _showGradingScaleDialog(),
        ),
        SizedBox(height: 16.h),
        _buildActionCard(
          title: 'Approvals',
          subtitle:
              'Principal review and approval of generated student report cards.',
          buttonLabel: 'Pending Review',
          isPrimary: false,
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ResultsScreen())),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required String buttonLabel,
    required VoidCallback onPressed,
    bool isPrimary = true,
  }) {
    return CustomPaint(
      painter: _DashedRectPainter(
          color: const Color(0xFFCBD5E1),
          strokeWidth: 1.5,
          gap: 4,
          dash: 6,
          radius: 16.r),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: GoogleFonts.outfit(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A))),
            SizedBox(height: 4.h),
            Text(subtitle,
                style: AppTypography.caption
                    .copyWith(color: const Color(0xFF64748B))),
            SizedBox(height: 16.h),
            SizedBox(
              width: double.infinity,
              height: 44.h,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPrimary
                      ? const Color(0xFF0066CC)
                      : const Color(0xFFE0F2FE),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r)),
                ),
                onPressed: onPressed,
                child: Text(
                  buttonLabel,
                  style: AppTypography.caption.copyWith(
                      color:
                          isPrimary ? Colors.white : const Color(0xFF0F172A)),
                ),
              ),
            ),
          ],
        ),
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
    return CustomPaint(
      painter: _DashedRectPainter(
          color: const Color(0xFFCBD5E1),
          strokeWidth: 1.5,
          gap: 4,
          dash: 6,
          radius: 16.r),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: GoogleFonts.outfit(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A))),
            SizedBox(height: 4.h),
            Text(subtitle,
                style: AppTypography.caption
                    .copyWith(color: const Color(0xFF64748B))),
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44.h,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r)),
                      ),
                      onPressed: onBtn1Pressed,
                      child: Text(
                        btn1Label,
                        style: AppTypography.caption
                            .copyWith(color: const Color(0xFF0F172A)),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: SizedBox(
                    height: 44.h,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r)),
                      ),
                      onPressed: onBtn2Pressed,
                      child: Text(
                        btn2Label,
                        style: AppTypography.caption
                            .copyWith(color: const Color(0xFF0F172A)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showGradingScaleDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text('Grading System',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• A+ : 95% - 100% (Excellent)',
                style: TextStyle(fontWeight: FontWeight.w500)),
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
            Text('• F  : Below 60% (Fail)',
                style: TextStyle(color: Colors.red)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text('Create Class',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
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
              _buildDialogField(
                  teacherCtrl, 'Class Teacher', 'e.g. Mr. John Doe'),
              SizedBox(height: 12.h),
              _buildDialogField(studentsCtrl, 'Students Count', 'e.g. 40',
                  keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: widget.theme.primary),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final navigator = Navigator.of(ctx);
              try {
                final yearsRes = await ApiService.instance.get('academic/years');
                final years = (yearsRes['academicYears'] ?? []) as List;
                String? academicYearId;
                if (years.isNotEmpty) {
                  final currentYear = years.firstWhere(
                    (y) => y['isCurrent'] == true,
                    orElse: () => years.first,
                  );
                  academicYearId = currentYear['id'];
                }

                if (academicYearId == null) {
                  final classesRes = await ApiService.instance.get('academic/classes');
                  final classes = (classesRes['classes'] ?? classesRes['data'] ?? []) as List;
                  if (classes.isNotEmpty) {
                    academicYearId = classes.first['academicYearId'];
                  }
                }

                await ApiService.instance.post('academic/classes', body: {
                  'name': nameCtrl.text.trim(),
                  'numericValue': int.tryParse(levelCtrl.text.trim()) ?? 1,
                  'academicYearId': academicYearId,
                });

                if (mounted) {
                  showToast(context, 'Class Created Successfully!');
                  navigator.pop();
                  _loadLocalData();
                }
              } catch (e) {
                dev.log('Error creating class: $e');
                if (mounted) {
                  showToast(context, 'Failed to create class', isError: true);
                }
              }
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text('Create Subject',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
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
              _buildDialogField(
                  teacherCtrl, 'Subject Teacher', 'e.g. Dr. Emily Green'),
              SizedBox(height: 12.h),
              _buildDialogField(
                  descCtrl, 'Description', 'e.g. Intro to Mechanics'),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: widget.theme.primary),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final navigator = Navigator.of(ctx);
              try {
                final className = classCtrl.text.trim();
                String? targetClassId;
                final match = _classesList.firstWhere(
                  (c) => c['name'].toString().toLowerCase() == className.toLowerCase(),
                  orElse: () => {},
                );
                if (match.isNotEmpty) {
                  targetClassId = match['id'];
                }

                if (targetClassId == null) {
                  final yearsRes = await ApiService.instance.get('academic/years');
                  final years = (yearsRes['academicYears'] ?? []) as List;
                  String? academicYearId;
                  if (years.isNotEmpty) {
                    final currentYear = years.firstWhere(
                      (y) => y['isCurrent'] == true,
                      orElse: () => years.first,
                    );
                    academicYearId = currentYear['id'];
                  }
                  
                  final newClassRes = await ApiService.instance.post('academic/classes', body: {
                    'name': className,
                    'numericValue': 1,
                    'academicYearId': academicYearId,
                  });
                  final newClass = newClassRes['class'] ?? newClassRes['data'] ?? {};
                  targetClassId = newClass['id'];
                }

                await ApiService.instance.post('academic/subjects', body: {
                  'name': nameCtrl.text.trim(),
                  'code': codeCtrl.text.trim(),
                  'classId': targetClassId,
                  'description': descCtrl.text.trim(),
                  'type': 'CORE',
                  'totalMarks': 100,
                  'passMarks': 33,
                });

                if (mounted) {
                  showToast(context, 'Subject Created Successfully!');
                  navigator.pop();
                  _loadLocalData();
                }
              } catch (e) {
                dev.log('Error creating subject: $e');
                if (mounted) {
                  showToast(context, 'Failed to create subject', isError: true);
                }
              }
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text('Create Section',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogField(nameCtrl, 'Section Name', 'e.g. Section A'),
              SizedBox(height: 12.h),
              _buildDialogField(classCtrl, 'Class', 'e.g. Class 10'),
              SizedBox(height: 12.h),
              _buildDialogField(maxCtrl, 'Max Students', 'e.g. 40',
                  keyboardType: TextInputType.number),
              SizedBox(height: 12.h),
              _buildDialogField(studentsCtrl, 'Current Students', 'e.g. 35',
                  keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: widget.theme.primary),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final navigator = Navigator.of(ctx);
              try {
                final className = classCtrl.text.trim();
                String? targetClassId;
                final match = _classesList.firstWhere(
                  (c) => c['name'].toString().toLowerCase() == className.toLowerCase(),
                  orElse: () => {},
                );
                if (match.isNotEmpty) {
                  targetClassId = match['id'];
                }

                if (targetClassId == null) {
                  final yearsRes = await ApiService.instance.get('academic/years');
                  final years = (yearsRes['academicYears'] ?? []) as List;
                  String? academicYearId;
                  if (years.isNotEmpty) {
                    final currentYear = years.firstWhere(
                      (y) => y['isCurrent'] == true,
                      orElse: () => years.first,
                    );
                    academicYearId = currentYear['id'];
                  }
                  
                  final newClassRes = await ApiService.instance.post('academic/classes', body: {
                    'name': className,
                    'numericValue': 1,
                    'academicYearId': academicYearId,
                  });
                  final newClass = newClassRes['class'] ?? newClassRes['data'] ?? {};
                  targetClassId = newClass['id'];
                }

                await ApiService.instance.post('academic/sections', body: {
                  'name': nameCtrl.text.trim(),
                  'classId': targetClassId,
                  'maxStudents': int.tryParse(maxCtrl.text.trim()) ?? 40,
                });

                if (mounted) {
                  showToast(context, 'Section Created Successfully!');
                  navigator.pop();
                  _loadLocalData();
                }
              } catch (e) {
                dev.log('Error creating section: $e');
                if (mounted) {
                  showToast(context, 'Failed to create section', isError: true);
                }
              }
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
        labelStyle: AppTypography.caption,
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
          Icon(Icons.folder_open_rounded,
              size: 48.sp, color: const Color(0xFFCBD5E1)),
          SizedBox(height: 12.h),
          Text(
            text,
            style:
                AppTypography.caption.copyWith(color: const Color(0xFF94A3B8)),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.theme.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r)),
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
            ),
            onPressed: onCreate,
            child:
                const Text('Create One', style: TextStyle(color: Colors.white)),
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
                    MaterialPageRoute(
                        builder: (_) =>
                            MainScreen(role: _userRole, initialIndex: 0)),
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
                  MainScreen.navigateTo(context, 8);
                },
              ),
              _buildBottomNavItem(
                icon: Icons.more_vert_rounded,
                label: 'More',
                isSelected: false,
                onTap: () {
                  MainScreen.navigateTo(context, 4);
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
              style: AppTypography.caption
                  .copyWith(color: isSelected ? activeColor : inactiveColor),
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
      width: MediaQuery.of(context).size.width * 0.8,
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
                style: AppTypography.h4.copyWith(
                    color: const Color(0xFF0F172A), letterSpacing: 0.3),
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
                                MaterialPageRoute(
                                    builder: (_) => const MainScreen(
                                        role: 'teacher', initialIndex: 0)),
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
                                MaterialPageRoute(
                                    builder: (_) => const MainScreen(
                                        role: 'teacher', initialIndex: 1)),
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
                                MaterialPageRoute(
                                    builder: (_) => const MainScreen(
                                        role: 'teacher', initialIndex: 2)),
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
                                MaterialPageRoute(
                                    builder: (_) => const MainScreen(
                                        role: 'teacher', initialIndex: 3)),
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
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const CreateAssignmentScreen()));
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
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const ExamScheduleScreen()));
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
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => ScheduleScreen(
                                          role: 'teacher',
                                          theme: widget.theme)));
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
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => AnnouncementsScreen(
                                          theme: widget.theme)));
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
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CommunityScreen(
                                        theme: widget.theme,
                                        showAppBar: true,
                                        onBack: () => Navigator.pop(context)),
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
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => ProfileScreen(
                                          role: 'teacher',
                                          theme: widget.theme)));
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
                                MaterialPageRoute(
                                    builder: (_) => const MainScreen(
                                        role: 'student', initialIndex: 0)),
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
                                MaterialPageRoute(
                                    builder: (_) => const MainScreen(
                                        role: 'student', initialIndex: 1)),
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
                                MaterialPageRoute(
                                    builder: (_) => const MainScreen(
                                        role: 'student', initialIndex: 2)),
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
                                MaterialPageRoute(
                                    builder: (_) => const MainScreen(
                                        role: 'student', initialIndex: 4)),
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
                                MaterialPageRoute(
                                    builder: (_) => const MainScreen(
                                        role: 'student', initialIndex: 5)),
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
                                MaterialPageRoute(
                                    builder: (_) => const MainScreen(
                                        role: 'student', initialIndex: 6)),
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
                                MaterialPageRoute(
                                    builder: (_) => const MainScreen(
                                        role: 'student', initialIndex: 7)),
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
                                MaterialPageRoute(
                                    builder: (_) => const MainScreen(
                                        role: 'student', initialIndex: 8)),
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
                                MaterialPageRoute(
                                    builder: (_) => const MainScreen(
                                        role: 'student', initialIndex: 10)),
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
              onTap: () async {
                await AuthService.logout(context);
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
                      style: AppTypography.caption.copyWith(color: activeBlue),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userName,
                          style: AppTypography.caption
                              .copyWith(color: const Color(0xFF0F172A)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 1.h),
                        Text(
                          _userRole.toUpperCase(),
                          style: AppTypography.caption
                              .copyWith(color: activeBlue, letterSpacing: 0.8),
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
          color: _isHovered || widget.isHoveredDemo
              ? const Color(0xFFF8FAFC)
              : Colors.white,
          border: const Border(
              bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                widget.name,
                textAlign: TextAlign.left,
                style: AppTypography.caption
                    .copyWith(color: const Color(0xFF0F172A)),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                widget.level,
                textAlign: TextAlign.center,
                style: AppTypography.caption
                    .copyWith(color: const Color(0xFF1E293B)),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                widget.academicYear,
                textAlign: TextAlign.center,
                style: AppTypography.caption
                    .copyWith(color: const Color(0xFF1E293B)),
              ),
            ),
            Expanded(
              flex: 4,
              child: Text(
                widget.classTeacher,
                textAlign: TextAlign.center,
                style: AppTypography.caption
                    .copyWith(color: const Color(0xFF1E293B)),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                widget.students,
                textAlign: TextAlign.center,
                style: AppTypography.caption
                    .copyWith(color: const Color(0xFF1E293B)),
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
            color: showBlue ? widget.activeBlue : Colors.transparent,
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
                          style: AppTypography.small.copyWith(
                            color:
                                showBlue ? Colors.white : widget.inactiveText,
                          ),
                          child: Text(widget.label)),
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

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: _isHovered ? const Color(0xFFF8FAFC) : Colors.white,
          border: const Border(
              bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                widget.name,
                style: AppTypography.caption
                    .copyWith(color: const Color(0xFF0F172A)),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                widget.code,
                textAlign: TextAlign.left,
                style: AppTypography.caption
                    .copyWith(color: const Color(0xFF1E293B)),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                widget.className,
                textAlign: TextAlign.left,
                style: AppTypography.caption
                    .copyWith(color: const Color(0xFF1E293B)),
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: widget.teacher == '—' || widget.teacher.isEmpty
                    ? Text(
                        '—',
                        style: AppTypography.caption
                            .copyWith(color: const Color(0xFF1E293B)),
                      )
                    : Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE), // Light blue background
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Text(
                          widget.teacher,
                          style: AppTypography.caption.copyWith(
                            color: const Color(0xFF475569),
                          ),
                        ),
                      ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                widget.description,
                textAlign: TextAlign.left,
                style: AppTypography.caption
                    .copyWith(color: const Color(0xFF1E293B)),
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

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: _isHovered ? const Color(0xFFF8FAFC) : Colors.white,
          border: const Border(
              bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Text(
                widget.name,
                style: AppTypography.caption
                    .copyWith(color: const Color(0xFF0F172A)),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                widget.className,
                textAlign: TextAlign.left,
                style: AppTypography.caption
                    .copyWith(color: const Color(0xFF1E293B)),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                widget.maxStudents,
                textAlign: TextAlign.left,
                style: AppTypography.caption
                    .copyWith(color: const Color(0xFF1E293B)),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                widget.students,
                textAlign: TextAlign.left,
                style: AppTypography.caption
                    .copyWith(color: const Color(0xFF1E293B)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double dash;
  final double radius;

  _DashedRectPainter({
    required this.color,
    required this.strokeWidth,
    required this.gap,
    required this.dash,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(radius),
      ));

    final dashPath = Path();
    var distance = 0.0;
    for (final pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        dashPath.addPath(
          pathMetric.extractPath(distance, distance + dash),
          Offset.zero,
        );
        distance += dash + gap;
      }
      distance = 0.0;
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
