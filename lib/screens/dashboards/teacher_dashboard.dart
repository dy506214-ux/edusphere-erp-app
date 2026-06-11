import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'dart:developer' as dev;
import '../features/academic_calendar_screen.dart';
import '../../theme/colors.dart';
import '../../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main_screen.dart';
import '../features/teacher_overdue_management_screen.dart';

class TeacherDashboard extends StatefulWidget {
  final RoleTheme theme;
  const TeacherDashboard({super.key, required this.theme});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  List<dynamic> _upcomingEvents = [];
  bool _upcomingEventsLoaded = false;
  RealtimeChannel? _teacherDashChannel;
  Timer? _teacherDashTimer;
  String _teacherName = 'Teacher';

  // Refresh state
  bool _isRefreshing = false;

  // Dynamic Statistics
  int _studentCount = 60;
  int _pendingAttendance = 0;
  int _overdueBooks = 0;
  double _attendanceTodayPercentage = 90.0;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadTeacherName();
    _loadUpcomingEvents();
    _loadDashboardStats();
    _connectRealTime();
  }

  @override
  void dispose() {
    _teacherDashTimer?.cancel();
    if (_teacherDashChannel != null) {
      try {
        Supabase.instance.client.removeChannel(_teacherDashChannel!);
      } catch (_) {}
    }
    super.dispose();
  }

  Future<void> _refreshDashboard() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await Future.wait([
        _loadUpcomingEvents(),
        _loadDashboardStats(),
      ]);
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _connectRealTime() async {
    try {
      final client = Supabase.instance.client;
      _teacherDashChannel = client.channel('public:teacher_dash_events')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'SchoolCalendar',
          callback: (_) {
            if (mounted) {
              _loadUpcomingEvents();
              _loadDashboardStats();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'AttendanceRecord',
          callback: (_) {
            if (mounted) _loadDashboardStats();
          },
        );
      _teacherDashChannel!.subscribe();
    } catch (e) {
      dev.log('Teacher dash realtime error: $e');
    }
    _teacherDashTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (mounted) {
        _loadUpcomingEvents();
        _loadDashboardStats();
      }
    });
  }



  Future<void> _loadTeacherName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('teacher_name') ?? prefs.getString('user_name') ?? 'Teacher';
    if (mounted) {
      setState(() {
        _teacherName = name.trim().split(' ').first;
      });
    }
  }

  Future<void> _loadDashboardStats() async {
    try {
      final supabase = Supabase.instance.client;
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // 1. Fetch student count
      final studentCountRes = await supabase.from('Student').select('id');
      final studentCount = studentCountRes.length;

      // 2. Fetch overdue books count (unreturned issues whose dueDate is before today)
      final activeIssuesRes = await supabase.from('LibraryIssue').select('dueDate').isFilter('returnDate', null);
      int overdueCount = 0;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      for (var issue in activeIssuesRes) {
        final dueDateStr = issue['dueDate'] ?? '';
        if (dueDateStr.isNotEmpty) {
          try {
            final dueDate = DateTime.parse(dueDateStr);
            final dueNormalized = DateTime(dueDate.year, dueDate.month, dueDate.day);
            if (dueNormalized.isBefore(today)) {
              overdueCount++;
            }
          } catch (_) {}
        }
      }

      // 3. Fetch attendance today percentage
      final attendanceRecords = await supabase.from('AttendanceRecord').select('status').eq('date', todayStr);
      double attendancePct = 90.0;
      if (attendanceRecords.isNotEmpty) {
        final presentCount = attendanceRecords.where((r) => r['status'] == 'PRESENT').length;
        attendancePct = (presentCount / attendanceRecords.length) * 100.0;
      }

      // 4. Fetch pending attendance count (classes without attendance marked today)
      final classesRes = await supabase.from('Class').select('id');
      final markedTodayRes = await supabase.from('AttendanceRecord').select('classId').eq('date', todayStr);
      final markedClassIds = markedTodayRes.map((r) => r['classId']?.toString()).toSet();
      int pendingAttend = 0;
      for (var c in classesRes) {
        final classId = c['id']?.toString();
        if (classId != null && !markedClassIds.contains(classId)) {
          pendingAttend++;
        }
      }

      if (mounted) {
        setState(() {
          _studentCount = studentCount > 0 ? studentCount : 60;
          _overdueBooks = overdueCount;
          _attendanceTodayPercentage = attendancePct;
          _pendingAttendance = pendingAttend;
        });
      }
    } catch (e) {
      dev.log('Error loading teacher dashboard stats: $e');
    }
  }

  Map<String, List<dynamic>> _calendarEvents = {};

  Future<void> _loadUpcomingEvents() async {
    try {
      final res = await ApiService.instance.get('calendar/upcoming', queryParams: {'limit': '8'});
      if (res['success'] == true && mounted) {
        final events = res['events'] as List? ?? [];
        setState(() {
          _upcomingEvents = events;
          _upcomingEventsLoaded = true;
        });
      } else {
        if (mounted) setState(() { _upcomingEventsLoaded = true; });
      }
    } catch (e) {
      dev.log('Error loading teacher upcoming events from API: $e');
      if (mounted) setState(() { _upcomingEventsLoaded = true; });
    }
    await _loadCalendarEvents();
  }

  Future<void> _loadCalendarEvents() async {
    try {
      final now = DateTime.now();
      final startDate = '${now.year - 1}-01-01';
      final endDate = '${now.year + 1}-12-31';
      final res = await ApiService.instance.get(
        'calendar',
        queryParams: {'startDate': startDate, 'endDate': endDate},
      );
      if (res != null && res['success'] == true && mounted) {
        final List apiEvents = res['events'] as List? ?? [];
        final Map<String, List<dynamic>> newEvents = {};
        for (var item in apiEvents) {
          final dateStr = item['date']?.toString();
          if (dateStr == null) continue;
          try {
            final parsedDate = DateTime.parse(dateStr).toLocal();
            final key = '${parsedDate.year}-${parsedDate.month}-${parsedDate.day}';
            newEvents.putIfAbsent(key, () => []).add(item);
          } catch (_) {}
        }
        setState(() {
          _calendarEvents = newEvents;
        });
      } else {
        // no-op
      }
    } catch (e) {
      dev.log('Error loading calendar events in dashboard: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }

  Widget _buildMobileLayout() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadUpcomingEvents();
        await _loadDashboardStats();
      },
      color: const Color(0xFF0EA5E9),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(false),
            SizedBox(height: 24.h),
            _buildMetricsGrid(false),
            SizedBox(height: 24.h),
            _buildSchoolCalendar(),
            SizedBox(height: 24.h),
            _buildUpcomingEvents(),
            SizedBox(height: 40.h),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadUpcomingEvents();
        await _loadDashboardStats();
      },
      color: const Color(0xFF0EA5E9),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(32.r),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(true),
                SizedBox(height: 24.h),
                _buildMetricsGrid(true),
                SizedBox(height: 24.h),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: _buildSchoolCalendar(),
                    ),
                    SizedBox(width: 24.w),
                    Expanded(
                      flex: 4,
                      child: _buildUpcomingEvents(),
                    ),
                  ],
                ),
                SizedBox(height: 40.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDesktop) {
    if (isDesktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Teacher Dashboard',
                  style: GoogleFonts.outfit(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A))),
              Row(
                children: [
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8.r),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8.r),
                      onTap: _isRefreshing ? null : _refreshDashboard,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            _isRefreshing
                                ? SizedBox(
                                    width: 16.sp,
                                    height: 16.sp,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF0EA5E9),
                                    ),
                                  )
                                : Icon(Icons.refresh_rounded,
                                    size: 16.sp,
                                    color: const Color(0xFF475569)),
                            SizedBox(width: 6.w),
                            Text(
                              _isRefreshing ? 'Refreshing...' : 'Refresh',
                              style: GoogleFonts.inter(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                  color: _isRefreshing
                                      ? const Color(0xFF0EA5E9)
                                      : const Color(0xFF475569)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: const Color(0xFFBAE6FD)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_month_rounded, size: 16.sp, color: const Color(0xFF0284C7)),
                        SizedBox(width: 6.w),
                        Text(DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                            style: GoogleFonts.inter(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF0284C7))),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text('Good day, $_teacherName. Here\'s what\'s happening in your classes.',
              style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  color: const Color(0xFF64748B))),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Teacher Dashboard',
              style: GoogleFonts.outfit(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A))),
          SizedBox(height: 4.h),
          Text('Good day, $_teacherName. Here\'s what\'s happening in your classes.',
              style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  color: const Color(0xFF64748B))),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10.r),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10.r),
                    onTap: _isRefreshing ? null : _refreshDashboard,
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(
                          color: _isRefreshing
                              ? const Color(0xFF93C5FD)
                              : const Color(0xFFD2E2F4),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _isRefreshing
                              ? SizedBox(
                                  width: 16.sp,
                                  height: 16.sp,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF0EA5E9),
                                  ),
                                )
                              : Icon(
                                  Icons.refresh_rounded,
                                  size: 16.sp,
                                  color: const Color(0xFF475569),
                                ),
                          SizedBox(width: 6.w),
                          Text(
                            _isRefreshing ? 'Refreshing...' : 'Refresh',
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: _isRefreshing
                                  ? const Color(0xFF0EA5E9)
                                  : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 10.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: const Color(0xFFBAE6FD)),
                  ),
                  child: Center(
                    child: Text(
                      DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0284C7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }
  }


  Widget _buildMetricsGrid(bool isDesktop) {
    final cards = [
      _buildResponsiveStatCard(
        title: 'ATTENDANCE TODAY',
        value: '${_attendanceTodayPercentage.toStringAsFixed(0)}%',
        color: const Color(0xFF3B82F6),
        showProgress: true,
        onTap: () => MainScreen.navigateTo(context, 3),
      ),
      _buildResponsiveStatCard(
        title: 'MY STUDENTS',
        value: '$_studentCount',
        color: const Color(0xFF0EA5E9),
        showProgress: false,
        onTap: () => MainScreen.navigateTo(context, 2),
      ),
      _buildResponsiveStatCard(
        title: 'PENDING ATTEND.',
        value: '$_pendingAttendance',
        color: const Color(0xFFF59E0B),
        showProgress: false,
        onTap: () => MainScreen.navigateTo(context, 3),
      ),
      _buildResponsiveStatCard(
        title: 'OVERDUE BOOKS',
        value: '$_overdueBooks',
        color: const Color(0xFFEF4444),
        showProgress: false,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TeacherOverdueManagementScreen(theme: widget.theme),
          ),
        ),
      ),
    ];

    if (isDesktop) {
      return Row(
        children: cards.map((c) => Expanded(child: c)).toList(),
      );
    } else {
      return Column(
        children: cards.expand((c) => [c, SizedBox(height: 12.h)]).toList()..removeLast(),
      );
    }
  }

  Widget _buildResponsiveStatCard({
    required String title,
    required String value,
    required Color color,
    required bool showProgress,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF475569),
                    letterSpacing: 0.5,
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(4.r),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 14.sp,
                    color: color,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 28.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            if (showProgress) ...[
              SizedBox(height: 10.h),
              Container(
                height: 4.h,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2.r),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (_attendanceTodayPercentage / 100.0).clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSchoolCalendar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(20.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        color: const Color(0xFF0EA5E9), size: 20.sp),
                    SizedBox(width: 8.w),
                    Text('School Calendar',
                        style: GoogleFonts.outfit(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A))),
                  ],
                ),
                SizedBox(height: 4.h),
                Text('Academic schedule & events',
                    style: GoogleFonts.inter(
                        fontSize: 12.sp, color: const Color(0xFF64748B))),
              ],
            ),
          ),
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            eventLoader: (day) {
              final key = '${day.year}-${day.month}-${day.day}';
              return _calendarEvents[key] ?? [];
            },
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: GoogleFonts.inter(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A)),
              leftChevronIcon:
                  Icon(Icons.chevron_left, color: const Color(0xFF0F172A), size: 24.sp),
              rightChevronIcon:
                  Icon(Icons.chevron_right, color: const Color(0xFF0F172A), size: 24.sp),
              headerPadding: EdgeInsets.symmetric(vertical: 8.h),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: GoogleFonts.inter(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B)),
              weekendStyle: GoogleFonts.inter(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B)),
            ),
            calendarStyle: CalendarStyle(
              defaultTextStyle: GoogleFonts.inter(
                  fontSize: 13.sp, color: const Color(0xFF1E293B)),
              weekendTextStyle: GoogleFonts.inter(
                  fontSize: 13.sp, color: const Color(0xFF1E293B)),
              outsideTextStyle: GoogleFonts.inter(
                  fontSize: 13.sp, color: const Color(0xFF94A3B8)),
              markerDecoration: const BoxDecoration(
                color: Color(0xFF0EA5E9),
                shape: BoxShape.circle,
              ),
              markersMaxCount: 3,
              todayDecoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF0EA5E9), width: 1.5),
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(8.r),
              ),
              todayTextStyle: GoogleFonts.inter(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0EA5E9)),
              selectedDecoration: BoxDecoration(
                color: const Color(0xFF0EA5E9),
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(8.r),
              ),
              selectedTextStyle: GoogleFonts.inter(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(20.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'EVENTS FOR ${DateFormat('d MMM').format(_selectedDay ?? DateTime.now()).toUpperCase()}',
                    style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.5)),
                SizedBox(height: 12.h),
                const Divider(color: Color(0xFFE2E8F0)),
                SizedBox(height: 16.h),
                (() {
                  final key = _selectedDay != null
                      ? '${_selectedDay!.year}-${_selectedDay!.month}-${_selectedDay!.day}'
                      : '';
                  final dayEvents = _calendarEvents[key] ?? [];
                  if (dayEvents.isEmpty) {
                    return Center(
                      child: Column(
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              color: const Color(0xFFCBD5E1), size: 32.sp),
                          SizedBox(height: 12.h),
                          Text('No events scheduled',
                              style: GoogleFonts.inter(
                                  fontSize: 13.sp,
                                  fontStyle: FontStyle.italic,
                                  color: const Color(0xFF64748B))),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: dayEvents.length,
                    itemBuilder: (context, index) {
                      final event = dayEvents[index];
                      final title = event['title']?.toString() ?? 'Event';
                      final type = (event['type']?.toString() ?? 'EVENT').toUpperCase();
                      final description = event['description']?.toString() ?? '';
                      final time = event['startTime']?.toString() ?? '';

                      Color typeColor = const Color(0xFF0EA5E9);
                      if (type == 'HOLIDAY') typeColor = const Color(0xFFEF4444);
                      if (type == 'EXAM') typeColor = const Color(0xFFF59E0B);
                      if (type == 'MEETING') typeColor = const Color(0xFF8B5CF6);

                      return Container(
                        margin: EdgeInsets.only(bottom: 8.h),
                        padding: EdgeInsets.all(12.r),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 4.w,
                              height: 32.h,
                              decoration: BoxDecoration(
                                color: typeColor,
                                borderRadius: BorderRadius.circular(2.r),
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: GoogleFonts.inter(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF0F172A)),
                                  ),
                                  if (description.isNotEmpty) ...[
                                    SizedBox(height: 2.h),
                                    Text(
                                      description,
                                      style: GoogleFonts.inter(
                                          fontSize: 11.sp,
                                          color: const Color(0xFF64748B)),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (time.isNotEmpty)
                              Text(
                                time,
                                style: GoogleFonts.inter(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF64748B)),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                })(),
                SizedBox(height: 24.h),
                GestureDetector(
                  onTap: () => MainScreen.navigateTo(context, 1),
                  onTap: () {
                    final isDesktop = MediaQuery.of(context).size.width > 900;
                    if (isDesktop) {
                      MainScreen.navigateTo(context, 1);
                    } else {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AcademicCalendarScreen()));
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F4F8),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('View Full Academic Schedule',
                            style: GoogleFonts.inter(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF0F172A))),
                        SizedBox(width: 4.w),
                        Icon(Icons.chevron_right,
                            size: 16.sp, color: const Color(0xFF0F172A)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingEvents() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B1120),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(20.r),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_month_rounded, color: const Color(0xFF0EA5E9), size: 20.sp),
                        SizedBox(width: 8.w),
                        Text('Upcoming Events',
                            style: GoogleFonts.outfit(fontSize: 18.sp, fontWeight: FontWeight.w700, color: Colors.white)),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text('School activities & schedule',
                        style: GoogleFonts.inter(fontSize: 12.sp, color: const Color(0xFF94A3B8))),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      width: 7.w,
                      height: 7.w,
                      decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
                    ),
                    SizedBox(width: 4.w),
                    Text('LIVE', style: GoogleFonts.inter(fontSize: 9.sp, fontWeight: FontWeight.w800, color: const Color(0xFF22C55E))),
                  ],
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF1E293B)),
          Padding(
            padding: EdgeInsets.all(20.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_upcomingEventsLoaded)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20.h),
                      child: SizedBox(
                        width: 22.w, height: 22.w,
                        child: const CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF0EA5E9)),
                      ),
                    ),
                  )
                else if (_upcomingEvents.isEmpty)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.h),
                      child: Column(
                        children: [
                          Container(
                            padding: EdgeInsets.all(16.r),
                            decoration: const BoxDecoration(color: Color(0xFF1E293B), shape: BoxShape.circle),
                            child: Icon(Icons.calendar_today_rounded, color: const Color(0xFF475569), size: 32.sp),
                          ),
                          SizedBox(height: 16.h),
                          Text('No upcoming events scheduled',
                              style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w500, color: const Color(0xFF94A3B8))),
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

                    DateTime? parsedDate;
                    try { parsedDate = DateTime.parse(rawDate).toLocal(); } catch (_) {}
                    final displayDate = parsedDate != null
                        ? DateFormat('dd MMM').format(parsedDate)
                        : rawDate.split('T')[0];
                    final dayName = parsedDate != null
                        ? DateFormat('EEE').format(parsedDate)
                        : '';

                    Color typeColor;
                    IconData typeIcon;
                    switch (type) {
                      case 'HOLIDAY':
                        typeColor = const Color(0xFFEF4444);
                        typeIcon = Icons.beach_access_rounded;
                        break;
                      case 'EXAM':
                        typeColor = const Color(0xFFF59E0B);
                        typeIcon = Icons.assignment_outlined;
                        break;
                      case 'MEETING':
                        typeColor = const Color(0xFF818CF8);
                        typeIcon = Icons.groups_2_outlined;
                        break;
                      default:
                        typeColor = const Color(0xFF0EA5E9);
                        typeIcon = Icons.celebration_rounded;
                    }

                    return Container(
                      margin: EdgeInsets.only(bottom: 10.h),
                      padding: EdgeInsets.all(12.r),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: typeColor.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40.w,
                            padding: EdgeInsets.symmetric(vertical: 6.h),
                            decoration: BoxDecoration(
                              color: typeColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Column(
                              children: [
                                Icon(typeIcon, size: 14.sp, color: typeColor),
                                SizedBox(height: 2.h),
                                Text(
                                  parsedDate != null ? '${parsedDate.day}' : '--',
                                  style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w900, color: typeColor),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title,
                                    style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w700, color: Colors.white),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                                if (description.isNotEmpty) ...[
                                  SizedBox(height: 2.h),
                                  Text(description,
                                      style: GoogleFonts.inter(fontSize: 10.5.sp, color: const Color(0xFF94A3B8)),
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                ],
                                SizedBox(height: 3.h),
                                Text('$dayName, $displayDate',
                                    style: GoogleFonts.inter(fontSize: 10.sp, color: typeColor.withValues(alpha: 0.8), fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList()),

                SizedBox(height: 12.h),
                GestureDetector(
                  onTap: () {
                    final isDesktop = MediaQuery.of(context).size.width > 900;
                    if (isDesktop) {
                      MainScreen.navigateTo(context, 1);
                    } else {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AcademicCalendarScreen()));
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('View Full Schedule',
                            style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: const Color(0xFF38BDF8))),
                        SizedBox(width: 4.w),
                        Icon(Icons.chevron_right, size: 16.sp, color: const Color(0xFF38BDF8)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
