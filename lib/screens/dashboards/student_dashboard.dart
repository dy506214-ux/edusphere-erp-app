import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../features/attendance_screen.dart';
import '../features/results_screen.dart';
import '../features/fee_ledger_screen.dart';
import '../features/library_overdue_screen.dart';
import '../features/academic_calendar_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:async';
import 'dart:developer' as dev;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/api_service.dart';

class StudentDashboard extends StatefulWidget {
  final RoleTheme theme;
  const StudentDashboard({super.key, required this.theme});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  // Student Profile Data
  String studentName = 'Test Student';
  String studentEmail = 'eduspherestudent@gmail.com';
  String studentPhone = '—';
  String admissionNo = 'ADM240001';
  String className = 'Class 1';
  String sectionName = 'Section A';
  String rollNo = '24';
  
  String dob = '—';
  String gender = '—';
  String fatherName = '—';
  String familyPhone = '—';
  String address = '—';

  // Metrics Data
  double attendanceRate = 0.0;
  bool _attendanceLoaded = false;
  int pendingFee = 0;
  int booksDue = 0;
  int pendingCount = 0;

  // Calendar State
  late DateTime _selectedMonth;
  late DateTime _selectedDay;
  List<dynamic> _calendarEvents = [];
  List<dynamic> _upcomingEvents = [];
  bool _upcomingEventsLoaded = false;

  RealtimeChannel? _dashboardChannel;
  Timer? _dashboardPollTimer;
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
    _selectedDay = now;
    _loadStudentData();
    _connectRealTime();
  }

  @override
  void dispose() {
    _dashboardPollTimer?.cancel();
    if (_dashboardChannel != null) {
      try {
        Supabase.instance.client.removeChannel(_dashboardChannel!);
      } catch (_) {}
    }
    super.dispose();
  }


  void _connectRealTime() {
    try {
      final client = Supabase.instance.client;
      if (_dashboardChannel != null) {
        client.removeChannel(_dashboardChannel!);
      }
      
      _dashboardChannel = client.channel('public:student_dashboard_sync')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'Assignment',
          callback: (_) {
            if (mounted) _loadStudentData();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'AssignmentSubmission',
          callback: (_) {
            if (mounted) _loadStudentData();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'AttendanceRecord',
          callback: (_) {
            if (mounted) _loadStudentData();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'StudentFeeLedger',
          callback: (_) {
            if (mounted) _loadStudentData();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'LibraryIssue',
          callback: (_) {
            if (mounted) _loadStudentData();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'SchoolCalendar',
          callback: (_) {
            if (mounted) {
              _loadCalendarEvents();
              _loadUpcomingEvents();
            }
          },
        );
      
      _dashboardChannel!.subscribe((status, [error]) {
        dev.log('📡 Supabase Realtime Student Dashboard channel status: $status', name: 'StudentDashboard');
        if (error != null) {
          dev.log('❌ Supabase Realtime Student Dashboard subscription error: $error', name: 'StudentDashboard');
        }
      });
    } catch (e) {
      dev.log('Error connecting realtime in dashboard: $e');
    }
    
    // Polling fallback every 30 seconds
    _dashboardPollTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadStudentData();
      }
    });
  }

  Future<void> _loadStudentData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final savedEmail = prefs.getString('student_email') ?? prefs.getString('user_email') ?? '';
    final savedName = prefs.getString('student_name') ?? prefs.getString('user_name') ?? 'Student';

    setState(() {
      studentName = savedName;
      studentEmail = savedEmail;
    });

    // ── 1. Fetch full student profile from backend ─────────────────────────
    try {
      final res = await ApiService.instance.get('students/me');
      if (res['success'] == true && res['student'] != null) {
        final s = res['student'] as Map<String, dynamic>;
        final u = s['user'] as Map? ?? {};
        final cls = s['currentClass'] as Map? ?? {};
        final sec = s['section'] as Map? ?? {};

        final fName = u['firstName'] as String? ?? '';
        final lName = u['lastName'] as String? ?? '';
        final fullName = '$fName $lName'.trim();
        final studentId = s['id'] as String? ?? '';

        // Persist student_id for other screens
        await prefs.setString('student_id', studentId);

        // Parent data
        String parentName = '—';
        String parentPhone = '—';
        final parents = s['parents'] as List? ?? [];
        if (parents.isNotEmpty) {
          final parentMap = (parents.first as Map? ?? {})['parent'] as Map? ?? {};
          parentName = '${parentMap['firstName'] ?? ''} ${parentMap['lastName'] ?? ''}'.trim();
          parentPhone = parentMap['phone'] as String? ?? '—';
        }

        if (!mounted) return;
        setState(() {
          studentName = fullName.isNotEmpty ? fullName : savedName;
          studentEmail = u['email'] as String? ?? savedEmail;
          studentPhone = u['phone'] as String? ?? '—';
          className = cls['name'] as String? ?? className;
          sectionName = sec['name'] as String? ?? sectionName;
          rollNo = s['rollNumber']?.toString() ?? rollNo;
          admissionNo = s['admissionNumber'] as String? ?? admissionNo;
          fatherName = parentName;
          familyPhone = parentPhone;
          final rawDob = u['dateOfBirth'];
          if (rawDob != null) dob = rawDob.toString().split('T')[0];
          gender = u['gender']?.toString() ?? '—';
          address = u['address'] as String? ?? '—';
        });

        // ── 2. Attendance % (current month) ───────────────────────────────
        try {
          final now = DateTime.now();
          final monthStart = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
          final attRes = await ApiService.instance.get(
            'students/$studentId/attendance',
            queryParams: {'startDate': monthStart},
          );
          if (attRes['success'] == true) {
            final stats = attRes['stats'] as Map? ?? {};
            final pct = (stats['percentage'] ?? 0) as num;
            if (mounted) setState(() { attendanceRate = pct.toDouble(); _attendanceLoaded = true; });
          } else {
            if (mounted) setState(() { attendanceRate = 100.0; _attendanceLoaded = true; });
          }
        } catch (e) {
          dev.log('Error loading attendance from API: $e');
          if (mounted) setState(() { attendanceRate = 100.0; _attendanceLoaded = true; });
        }

        // ── 3. Pending Assignments ─────────────────────────────────────────
        try {
          final assignRes = await ApiService.instance.get('assignments/student');
          final assignments = (assignRes['assignments'] as List? ?? []);
          final pending = assignments.where((a) {
            final subs = a['submissions'] as List? ?? [];
            return subs.isEmpty;
          }).length;
          if (mounted) setState(() { pendingCount = pending.clamp(0, 99); });
        } catch (e) {
          dev.log('Error loading assignments from API: $e');
        }

        // ── 4. Pending Fees ────────────────────────────────────────────────
        try {
          final feeRes = await ApiService.instance.get('fees/students/me/status');
          if (feeRes['success'] == true) {
            final summary = feeRes['summary'] as Map? ?? feeRes;
            final outstanding = (summary['totalOutstanding'] ?? summary['totalPending'] ?? 0) as num;
            if (mounted) setState(() { pendingFee = outstanding.toInt().clamp(0, 999999); });
          }
        } catch (e) {
          dev.log('Error loading fees from API: $e');
        }

        // ── 5. Books Due ───────────────────────────────────────────────────
        try {
          final libRes = await ApiService.instance.get(
            'library/issues',
            queryParams: {'studentId': studentId, 'status': 'ISSUED'},
          );
          if (libRes['success'] == true) {
            final issues = libRes['issues'] as List? ?? [];
            if (mounted) setState(() { booksDue = issues.length; });
          }
        } catch (e) {
          dev.log('Error loading library from API: $e');
        }

        // ── 6. Calendar Events ─────────────────────────────────────────────
        await _loadCalendarEvents();
        await _loadUpcomingEvents();
      }
    } catch (e) {
      dev.log('Error loading student data from backend API: $e');
      // Fallback: load from SharedPreferences only
      if (mounted) setState(() { _attendanceLoaded = true; });
    }
  }

  Future<void> _loadCalendarEvents() async {
    try {
      final now = DateTime.now();
      final startDate = '${now.year}-01-01';
      final endDate = '${now.year}-12-31';
      final res = await ApiService.instance.get(
        'calendar',
        queryParams: {'startDate': startDate, 'endDate': endDate},
      );
      if (res['success'] == true && mounted) {
        final events = res['events'] as List? ?? [];
        setState(() { _calendarEvents = events; });
      }
    } catch (e) {
      dev.log('Error loading calendar events from API: $e');
    }
  }

  Future<void> _loadUpcomingEvents() async {
    try {
      final res = await ApiService.instance.get('calendar/upcoming', queryParams: {'limit': '10'});
      if (res['success'] == true && mounted) {
        final events = res['events'] as List? ?? [];
        setState(() {
          _upcomingEvents = events;
          _upcomingEventsLoaded = true;
        });
        dev.log('📅 Loaded ${events.length} upcoming events from API', name: 'StudentDashboard');
      } else {
        if (mounted) setState(() { _upcomingEventsLoaded = true; });
      }
    } catch (e) {
      dev.log('Error loading upcoming events from API: $e');
      if (mounted) setState(() { _upcomingEventsLoaded = true; });
    }
  }

  List<dynamic> _getEventsForDay(DateTime date) {
    return _calendarEvents.where((event) {
      if (event['date'] == null) return false;
      try {
        final parsedDate = DateTime.parse(event['date'].toString()).toLocal();
        return parsedDate.year == date.year &&
            parsedDate.month == date.month &&
            parsedDate.day == date.day;
      } catch (e) {
        return false;
      }
    }).toList();
  }

  Color? _getDateTextColor(DateTime date, bool isSelected, bool isToday) {
    if (isSelected) return Colors.white;
    final dayEvents = _getEventsForDay(date);
    if (dayEvents.isEmpty) {
      return isToday ? const Color(0xFF0077D6) : AppColors.textDark;
    }
    
    // Prioritize holiday, then exam
    final hasHoliday = dayEvents.any((e) => e['type']?.toString().toUpperCase() == 'HOLIDAY');
    if (hasHoliday) return const Color(0xFFEF4444);
    
    final hasExam = dayEvents.any((e) => e['type']?.toString().toUpperCase() == 'EXAM');
    if (hasExam) return const Color(0xFFF59E0B);
    
    return AppColors.textDark;
  }

  Color? _getEventDotColor(List<dynamic> dayEvents) {
    if (dayEvents.isEmpty) return null;
    final hasHoliday = dayEvents.any((e) => e['type']?.toString().toUpperCase() == 'HOLIDAY');
    if (hasHoliday) return const Color(0xFFEF4444);
    
    final hasExam = dayEvents.any((e) => e['type']?.toString().toUpperCase() == 'EXAM');
    if (hasExam) return const Color(0xFFF59E0B);
    
    return const Color(0xFF0077D6); // Default/Event blue dot
  }

  String _getMonthAbbreviation(int month) {
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return months[month - 1];
  }

  Widget _buildDayEventsList(DateTime date) {
    final dayEvents = _getEventsForDay(date);
    if (dayEvents.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 32.sp,
                color: Colors.grey.shade400,
              ),
              SizedBox(height: 8.h),
              Text(
                'No events scheduled',
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: dayEvents.length,
      separatorBuilder: (_, __) => SizedBox(height: 12.h),
      itemBuilder: (context, index) {
        final event = dayEvents[index];
        final type = event['type']?.toString().toUpperCase() ?? 'EVENT';
        
        Color accentColor;
        switch (type) {
          case 'HOLIDAY':
            accentColor = const Color(0xFFEF4444);
            break;
          case 'EXAM':
            accentColor = const Color(0xFFF59E0B);
            break;
          case 'EMERGENCY':
            accentColor = const Color(0xFF8B5CF6);
            break;
          default:
            accentColor = const Color(0xFF0077D6);
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 5.w,
                    color: accentColor,
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(12.r),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  event['title'] ?? 'Academic Event',
                                  style: GoogleFonts.inter(
                                    fontSize: 13.5.sp,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                child: Text(
                                  type,
                                  style: GoogleFonts.inter(
                                    fontSize: 9.sp,
                                    fontWeight: FontWeight.w800,
                                    color: accentColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (event['description'] != null && event['description'].toString().isNotEmpty) ...[
                            SizedBox(height: 4.h),
                            Text(
                              event['description'],
                              style: GoogleFonts.inter(
                                fontSize: 11.sp,
                                color: AppColors.textLight,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildViewScheduleButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: const Color(0xFFF0F9FF),
          foregroundColor: const Color(0xFF0077D6),
          padding: EdgeInsets.symmetric(vertical: 14.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
            side: const BorderSide(color: Color(0xFFE0F2FE)),
          ),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AcademicCalendarScreen(
                onOpenDrawer: () {},
                showAppBar: true,
              ),
            ),
          );
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'View Full Academic Schedule',
              style: GoogleFonts.inter(
                fontSize: 13.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(width: 6.w),
            Icon(Icons.chevron_right_rounded, size: 18.sp),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadStudentData,
        color: AppColors.studentPrimary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(24.r),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Greeting Header
                  _buildGreetingHeader(),
                  SizedBox(height: 20.h),
                  
                  // Profile Banner Section
                  _buildProfileBanner(isDesktop),
                  SizedBox(height: 24.h),
                  
                  // Metrics Grid Row
                  _buildMetricsRow(isDesktop),
                  SizedBox(height: 24.h),
                  
                  // Bottom grid/stack
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: _buildSchoolCalendar()),
                        SizedBox(width: 24.w),
                        Expanded(flex: 4, child: _buildUpcomingEvents()),
                      ],
                    )
                  else
                    Column(
                      children: [
                        _buildSchoolCalendar(),
                        SizedBox(height: 24.h),
                        _buildUpcomingEvents(),
                      ],
                    ),
                  SizedBox(height: 40.h),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── GREETING HEADER WIDGET ─────────────────────────────────────────────────
  Widget _buildGreetingHeader() {
    final firstName = studentName.split(' ').first;
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Hi, $firstName 👋',
                style: GoogleFonts.inter(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4.h),
              Text(
                'Here\'s your personal summary.',
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        SizedBox(width: 8.w),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton.icon(
              onPressed: _loadStudentData,
              icon: Icon(Icons.history_rounded, size: 16.sp, color: const Color(0xFF64748B)),
              label: Text(
                'Refresh',
                style: GoogleFonts.inter(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            SizedBox(width: 6.w),
            StreamBuilder<DateTime>(
              stream: Stream.periodic(const Duration(minutes: 1), (_) => DateTime.now()),
              initialData: DateTime.now(),
              builder: (context, snapshot) {
                final now = snapshot.data!;
                final dateFormatted = '${['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][now.weekday % 7]}, ${now.day} ${['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][now.month - 1]} ${now.year}';
                return OutlinedButton(
                  onPressed: () {}, // Interactive just like the refresh button
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                    backgroundColor: const Color(0xFFE0F2FE),
                    side: const BorderSide(color: Color(0xFFBAE6FD)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    dateFormatted,
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0284C7),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  // ── PROFILE BANNER WIDGET ──────────────────────────────────────────────────
  Widget _buildProfileBanner(bool isDesktop) {
    String formattedDob = dob;
    try {
      final d = DateTime.parse(dob);
      formattedDob = '${d.day}/${d.month}/${d.year}';
    } catch (_) {}

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: const Color(0xFFE0F2FE)),
      ),
      padding: EdgeInsets.all(24.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Top Profile details
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 60.w,
                height: 60.w,
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFBFDBFE), width: 1.w),
                ),
                child: Icon(Icons.school_rounded, color: const Color(0xFF3B82F6), size: 28.sp),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      studentName,
                      style: GoogleFonts.inter(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'ADM: $admissionNo',
                          style: GoogleFonts.inter(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.w),
                          child: Text(
                            '•',
                            style: GoogleFonts.inter(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                        Text(
                          '$className - $sectionName',
                          style: GoogleFonts.inter(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF0EA5E9),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  'ACTIVE',
                  style: GoogleFonts.inter(
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 20.h),
          Container(
            height: 1.h,
            color: const Color(0xFFE2E8F0),
          ),
          SizedBox(height: 20.h),
          
          // Info Grid
          isDesktop 
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildInfoColumn('PERSONAL', [
                      _buildInfoRow('DOB', formattedDob),
                      _buildInfoRow('Gender', gender.toUpperCase()),
                    ]),
                  ),
                  Expanded(
                    flex: 2,
                    child: _buildInfoColumn('FAMILY', [
                      _buildInfoRow('Father', fatherName),
                      _buildInfoRow('Ph', familyPhone),
                    ]),
                  ),
                  Expanded(
                    flex: 3,
                    child: _buildInfoColumn('CONTACT', [
                      _buildInfoRow('Email', studentEmail),
                      _buildInfoRow('Phone', studentPhone),
                    ]),
                  ),
                  Expanded(
                    flex: 2,
                    child: _buildInfoColumn('ADDRESS', [
                      _buildInfoText(address),
                    ]),
                  ),
                ],
              )
            : Wrap(
                spacing: 16.w,
                runSpacing: 20.h,
                alignment: WrapAlignment.start,
                children: [
                  SizedBox(
                    width: MediaQuery.of(context).size.width / 2 - 48.w,
                    child: _buildInfoColumn('PERSONAL', [
                      _buildInfoRow('DOB', dob),
                      _buildInfoRow('Gender', gender.toUpperCase()),
                    ]),
                  ),
                  SizedBox(
                    width: MediaQuery.of(context).size.width / 2 - 48.w,
                    child: _buildInfoColumn('FAMILY', [
                      _buildInfoRow('Father', fatherName),
                      _buildInfoRow('Ph', familyPhone),
                    ]),
                  ),
                  SizedBox(
                    width: MediaQuery.of(context).size.width - 72.w,
                    child: _buildInfoColumn('CONTACT', [
                      _buildInfoRow('Email', studentEmail),
                      _buildInfoRow('Phone', studentPhone),
                    ]),
                  ),
                  SizedBox(
                    width: MediaQuery.of(context).size.width - 72.w,
                    child: _buildInfoColumn('ADDRESS', [
                      _buildInfoText(address),
                    ]),
                  ),
                ],
              ),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 9.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF94A3B8),
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 6.h),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4.h),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.inter(
            fontSize: 11.sp,
            color: const Color(0xFF475569),
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoText(String value) {
    return Text(
      value,
      style: GoogleFonts.inter(
        fontSize: 11.sp,
        fontWeight: FontWeight.w500,
        color: const Color(0xFF475569),
        height: 1.4,
      ),
    );
  }

  // ── METRICS GRID ROW WIDGET ────────────────────────────────────────────────
  Widget _buildMetricsRow(bool isDesktop) {
    return isDesktop
        ? Row(
            children: [
              Expanded(child: _metricCard(
                title: 'ATTENDANCE',
                value: _attendanceLoaded ? '${attendanceRate.toStringAsFixed(0)}%' : '—%',
                leftBorderColor: const Color(0xFF3B82F6),
                bottomWidget: Padding(
                  padding: EdgeInsets.only(top: 8.h),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4.r),
                    child: LinearProgressIndicator(
                      value: _attendanceLoaded ? attendanceRate / 100.0 : 0,
                      backgroundColor: const Color(0xFFEFF6FF),
                      color: const Color(0xFF3B82F6),
                      minHeight: 4.h,
                    ),
                  ),
                ),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen())),
              )),
              SizedBox(width: 16.w),
              Expanded(child: _metricCard(
                title: 'PENDING FEE',
                value: '$pendingFee',
                leftBorderColor: const Color(0xFFEF4444),
                valueColor: const Color(0xFFEF4444),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FeeLedgerScreen(theme: widget.theme))),
              )),
              SizedBox(width: 16.w),
              Expanded(child: _metricCard(
                title: 'BOOKS DUE',
                value: '$booksDue',
                leftBorderColor: const Color(0xFF64748B),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LibraryOverdueScreen(theme: widget.theme))),
              )),
              SizedBox(width: 16.w),
              Expanded(child: _metricCard(
                title: 'RESULTS',
                value: 'View Report',
                leftBorderColor: const Color(0xFF8B5CF6),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ResultsScreen())),
              )),
            ],
          )
        : Column(
            children: [
              Row(
                children: [
                  Expanded(child: _metricCard(
                    title: 'ATTENDANCE',
                    value: _attendanceLoaded ? '${attendanceRate.toStringAsFixed(0)}%' : '—%',
                    leftBorderColor: const Color(0xFF3B82F6),
                    bottomWidget: Padding(
                      padding: EdgeInsets.only(top: 8.h),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4.r),
                        child: LinearProgressIndicator(
                          value: _attendanceLoaded ? attendanceRate / 100.0 : 0,
                          backgroundColor: const Color(0xFFEFF6FF),
                          color: const Color(0xFF3B82F6),
                          minHeight: 4.h,
                        ),
                      ),
                    ),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen())),
                  )),
                  SizedBox(width: 16.w),
                  Expanded(child: _metricCard(
                    title: 'PENDING FEE',
                    value: '$pendingFee',
                    leftBorderColor: const Color(0xFFEF4444),
                    valueColor: const Color(0xFFEF4444),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FeeLedgerScreen(theme: widget.theme))),
                  )),
                ],
              ),
              SizedBox(height: 16.h),
              Row(
                children: [
                  Expanded(child: _metricCard(
                    title: 'BOOKS DUE',
                    value: '$booksDue',
                    leftBorderColor: const Color(0xFF64748B),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LibraryOverdueScreen(theme: widget.theme))),
                  )),
                  SizedBox(width: 16.w),
                  Expanded(child: _metricCard(
                    title: 'RESULTS',
                    value: 'View Report',
                    leftBorderColor: const Color(0xFF8B5CF6),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ResultsScreen())),
                  )),
                ],
              ),
            ],
          );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required Color leftBorderColor,
    required VoidCallback onTap,
    Color? valueColor,
    Widget? bottomWidget,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10.r, offset: Offset(0, 4.h)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16.r),
          child: Container(
            decoration: BoxDecoration(border: Border(left: BorderSide(color: leftBorderColor, width: 4.w))),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.8),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Icon(Icons.arrow_forward_rounded, size: 14.sp, color: const Color(0xFF94A3B8)),
                  ],
                ),
                SizedBox(height: 8.h),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: GoogleFonts.inter(fontSize: 22.sp, fontWeight: FontWeight.w900, color: valueColor ?? const Color(0xFF0F172A)),
                  ),
                ),
                if (bottomWidget != null) bottomWidget,
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── SCHOOL CALENDAR CARD WIDGET ────────────────────────────────────────────
  Widget _buildSchoolCalendar() {
    final daysInMonth = DateUtils.getDaysInMonth(_selectedMonth.year, _selectedMonth.month);
    final firstDayOffset = DateTime(_selectedMonth.year, _selectedMonth.month, 1).weekday % 7;
    final totalCells = daysInMonth + firstDayOffset;
    final monthName = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][_selectedMonth.month - 1];

    return Container(
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10.r),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(
                        Icons.calendar_today_rounded,
                        color: const Color(0xFF0077D6),
                        size: 20.sp,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'School Calendar',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textDark,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            'Academic schedule & events',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11.sp,
                              color: AppColors.textLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.chevron_left_rounded, size: 22.sp, color: AppColors.textMedium),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      setState(() {
                        _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
                      });
                    },
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    '$monthName ${_selectedMonth.year}',
                    style: GoogleFonts.inter(
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  IconButton(
                    icon: Icon(Icons.chevron_right_rounded, size: 22.sp, color: AppColors.textMedium),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      setState(() {
                        _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 20.h),
          
          // Days Header (Sun - Sat)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'].map((d) {
              return Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w800, color: AppColors.textLight),
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 12.h),
          
          // Calendar Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1,
            ),
            itemCount: totalCells,
            itemBuilder: (context, index) {
              if (index < firstDayOffset) return const SizedBox.shrink();
              final dayVal = index - firstDayOffset + 1;
              final cellDate = DateTime(_selectedMonth.year, _selectedMonth.month, dayVal);
              final isSelected = cellDate.year == _selectedDay.year && cellDate.month == _selectedDay.month && cellDate.day == _selectedDay.day;
              
              final now = DateTime.now();
              final isToday = cellDate.year == now.year && cellDate.month == now.month && cellDate.day == now.day;

              final dayEvents = _getEventsForDay(cellDate);
              final dotColor = _getEventDotColor(dayEvents);
              final textColor = _getDateTextColor(cellDate, isSelected, isToday);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDay = cellDate;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF0077D6)
                        : (isToday ? const Color(0xFF0077D6).withValues(alpha: 0.15) : Colors.transparent),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dayVal.toString(),
                        style: GoogleFonts.inter(
                          fontSize: 13.sp,
                          fontWeight: isSelected || isToday ? FontWeight.w900 : FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      if (dotColor != null) ...[
                        SizedBox(height: 2.h),
                        Container(
                          width: 5.r,
                          height: 5.r,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : dotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ] else
                        SizedBox(height: 7.r),
                    ],
                  ),
                ),
              );
            },
          ),
          SizedBox(height: 20.h),
          const Divider(color: AppColors.border, thickness: 1),
          SizedBox(height: 16.h),
          
          // Header: EVENTS FOR X
          Text(
            'EVENTS FOR ${_selectedDay.day} ${_getMonthAbbreviation(_selectedDay.month)}',
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF334155),
              letterSpacing: 1.0,
            ),
          ),
          SizedBox(height: 16.h),
          
          // Event list
          _buildDayEventsList(_selectedDay),
          
          SizedBox(height: 24.h),
          
          // View Full Academic Schedule Button
          _buildViewScheduleButton(),
        ],
      ),
    );
  }

  // ── UPCOMING EVENTS WIDGET ─────────────────────────────────────────────────
  Widget _buildUpcomingEvents() {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 16.r, offset: Offset(0, 8.h)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.event_note_rounded, color: widget.theme.primary, size: 20.sp),
                  SizedBox(width: 8.w),
                  Text(
                    'Upcoming Events',
                    style: GoogleFonts.inter(fontSize: 15.sp, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ],
              ),
              // Live indicator dot
              Row(
                children: [
                  Container(
                    width: 7.w,
                    height: 7.w,
                    decoration: const BoxDecoration(
                      color: Color(0xFF22C55E),
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    'LIVE',
                    style: GoogleFonts.inter(fontSize: 9.sp, fontWeight: FontWeight.w800, color: const Color(0xFF22C55E)),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Text(
            'School activities & schedule',
            style: GoogleFonts.inter(fontSize: 11.sp, color: Colors.white.withValues(alpha: 0.5), fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 16.h),

          // Events content
          if (!_upcomingEventsLoaded)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20.h),
                child: SizedBox(
                  width: 22.w,
                  height: 22.w,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: widget.theme.primary,
                  ),
                ),
              ),
            )
          else if (_upcomingEvents.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 30.h),
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12.r),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.calendar_today_outlined, color: Colors.white.withValues(alpha: 0.25), size: 28.sp),
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      'No upcoming events scheduled',
                      style: GoogleFonts.inter(fontSize: 12.sp, color: Colors.white.withValues(alpha: 0.4), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            )
          else
            ...(_upcomingEvents.map((event) {
              final title = event['title']?.toString() ?? 'Event';
              final description = event['description']?.toString() ?? '';
              final type = (event['type']?.toString() ?? 'EVENT').toUpperCase();
              final rawDate = event['date']?.toString() ?? '';
              final location = event['location']?.toString();

              // Parse date
              DateTime? parsedDate;
              try { parsedDate = DateTime.parse(rawDate).toLocal(); } catch (_) {}
              final displayDate = parsedDate != null
                  ? '${parsedDate.day} ${['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][parsedDate.month]}'
                  : rawDate.split('T')[0];
              final dayName = parsedDate != null
                  ? ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][parsedDate.weekday - 1]
                  : '';

              // Type-based color & icon
              Color typeColor;
              IconData typeIcon;
              Color typeBg;
              switch (type) {
                case 'HOLIDAY':
                  typeColor = const Color(0xFFEF4444);
                  typeBg = const Color(0xFFEF4444).withValues(alpha: 0.15);
                  typeIcon = Icons.beach_access_rounded;
                  break;
                case 'EXAM':
                  typeColor = const Color(0xFFF59E0B);
                  typeBg = const Color(0xFFF59E0B).withValues(alpha: 0.15);
                  typeIcon = Icons.assignment_outlined;
                  break;
                case 'MEETING':
                  typeColor = const Color(0xFF818CF8);
                  typeBg = const Color(0xFF818CF8).withValues(alpha: 0.15);
                  typeIcon = Icons.groups_2_outlined;
                  break;
                default: // EVENT, CULTURAL, etc.
                  typeColor = widget.theme.primary;
                  typeBg = widget.theme.primary.withValues(alpha: 0.15);
                  typeIcon = Icons.celebration_rounded;
              }

              return Container(
                margin: EdgeInsets.only(bottom: 10.h),
                padding: EdgeInsets.all(14.r),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date badge
                    Container(
                      width: 44.w,
                      padding: EdgeInsets.symmetric(vertical: 6.h),
                      decoration: BoxDecoration(
                        color: typeBg,
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Column(
                        children: [
                          Text(
                            parsedDate != null ? '${parsedDate.day}' : '—',
                            style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.w900, color: typeColor),
                          ),
                          Text(
                            ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][parsedDate?.month ?? 1],
                            style: GoogleFonts.inter(fontSize: 9.sp, fontWeight: FontWeight.w700, color: typeColor),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 12.w),
                    // Event info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w800, color: Colors.white),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: 6.w),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                                decoration: BoxDecoration(
                                  color: typeBg,
                                  borderRadius: BorderRadius.circular(6.r),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(typeIcon, size: 9.sp, color: typeColor),
                                    SizedBox(width: 3.w),
                                    Text(
                                      type == 'EVENT' ? 'Event' : type[0] + type.substring(1).toLowerCase(),
                                      style: GoogleFonts.inter(fontSize: 8.5.sp, fontWeight: FontWeight.w800, color: typeColor),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (description.isNotEmpty) ...[
                            SizedBox(height: 3.h),
                            Text(
                              description,
                              style: GoogleFonts.inter(fontSize: 10.5.sp, color: Colors.white.withValues(alpha: 0.55), fontWeight: FontWeight.w500),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          SizedBox(height: 5.h),
                          Row(
                            children: [
                              Icon(Icons.calendar_today_outlined, size: 10.sp, color: Colors.white.withValues(alpha: 0.4)),
                              SizedBox(width: 4.w),
                              Text(
                                '$dayName, $displayDate',
                                style: GoogleFonts.inter(fontSize: 10.sp, color: Colors.white.withValues(alpha: 0.45), fontWeight: FontWeight.w600),
                              ),
                              if (location != null && location.isNotEmpty) ...[
                                SizedBox(width: 8.w),
                                Icon(Icons.place_outlined, size: 10.sp, color: Colors.white.withValues(alpha: 0.4)),
                                SizedBox(width: 3.w),
                                Expanded(
                                  child: Text(
                                    location,
                                    style: GoogleFonts.inter(fontSize: 10.sp, color: Colors.white.withValues(alpha: 0.45), fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList()),

          SizedBox(height: 6.h),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AcademicCalendarScreen()),
                );
              },
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                decoration: const BoxDecoration(
                  color: Colors.transparent,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'View Full Schedule',
                      style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w800, color: widget.theme.primary),
                    ),
                    SizedBox(width: 4.w),
                    Icon(Icons.arrow_forward_ios_rounded, size: 10.sp, color: widget.theme.primary),
                  ],
                ),
              ),
            ),
          ],
      ),
    );
  }
}
