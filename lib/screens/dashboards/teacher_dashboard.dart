import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:async';
import 'dart:developer' as dev;
import '../features/academic_calendar_screen.dart';
import '../../theme/colors.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../services/app_state_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main_screen.dart';
import '../features/teacher_overdue_management_screen.dart';
import '../features/teacher_self_attendance_screen.dart';
import 'package:edusphere/theme/typography.dart';

class TeacherDashboard extends StatefulWidget {
  final RoleTheme theme;
  const TeacherDashboard({super.key, required this.theme});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard>
    with WidgetsBindingObserver {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  List<dynamic> _upcomingEvents = [];
  bool _upcomingEventsLoaded = false;
  Timer? _teacherDashTimer;
  String _teacherName = 'Teacher';

  // Refresh state
  bool _isRefreshing = false;

  // Dynamic Statistics
  int _studentCount = 60;
  int _pendingAttendance = 0;
  int _overdueBooks = 0;
  double _attendanceTodayPercentage = 90.0;

  double _teacherAttendanceRate = 100.0;
  bool _teacherAttendanceLoaded = false;

  DateTime? _lastRefreshTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedDay = _focusedDay;
    _loadTeacherName();
    _loadUpcomingEvents();
    _fetchDashboardData('initial');
    _loadTeacherAttendance();
    _connectRealTime();
  }

  @override
  void dispose() {
    _teacherDashTimer?.cancel();

    // Clean up Socket.IO listeners cleanly
    try {
      for (var event in _socketEvents) {
        SocketService().off(event, _onRealtimeEvent);
      }
    } catch (e) {
      dev.log('Error unregistering Socket.IO events: $e',
          name: 'TeacherDashboard');
    }

    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      dev.log('📱 App resumed from background. Triggering dashboard refresh...',
          name: 'TeacherDashboard');
      _loadUpcomingEvents();
      _fetchDashboardData('app_resume');
    }
  }

  Future<void> _refreshDashboard() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    AppStateNotifier.refreshNotificationsTrigger.value++;
    try {
      await Future.wait([
        _loadUpcomingEvents(),
        _fetchDashboardData('manual'),
        _loadTeacherAttendance(),
      ]);
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  final List<String> _socketEvents = [
    'STUDENT_ADDED',
    'STUDENT_DELETED',
    'STUDENT_UPDATED',
    'ATTENDANCE_UPDATED',
    'CLASS_UPDATED',
    'EVENT_UPDATED',
    'DASHBOARD_STATS_CHANGED'
  ];

  void _onRealtimeEvent(dynamic data) {
    dev.log('⚡ Socket.IO event received on Teacher Dashboard', name: 'TeacherDashboard');
    AppStateNotifier.refreshNotificationsTrigger.value++;
    if (mounted) {
      _loadUpcomingEvents();
      _fetchDashboardData('realtime_event', eventName: 'SocketIO:Event');
    }
  }



  Future<void> _connectRealTime() async {
    // Connect Socket.IO events
    try {
      for (var event in _socketEvents) {
        SocketService().off(event, _onRealtimeEvent);
        SocketService().on(event, _onRealtimeEvent);
      }
    } catch (e) {
      dev.log('Error registering Socket.IO events: $e',
          name: 'TeacherDashboard');
    }

    _teacherDashTimer?.cancel();
    _teacherDashTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (mounted) {
        _loadUpcomingEvents();
        _fetchDashboardData('periodic');
        _loadTeacherAttendance();
      }
    });
  }

  Future<void> _loadTeacherName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('teacher_name') ??
        prefs.getString('user_name') ??
        'Teacher';
    if (mounted) {
      setState(() {
        _teacherName = name.trim().split(' ').first;
      });
    }
  }

  Future<void> _loadDashboardStats() async {
    await _fetchDashboardData('initial');
  }

  Future<void> _fetchDashboardData(String triggerSource,
      {String? eventName}) async {
    const apiUrl = 'dashboard/stats';
    dev.log('📡 FETCHING Teacher Dashboard stats...', name: 'TeacherDashboard');
    dev.log('🔗 API URL Path: $apiUrl', name: 'TeacherDashboard');
    dev.log('👉 Trigger Source: $triggerSource', name: 'TeacherDashboard');
    if (eventName != null) {
      dev.log('⚡ Realtime Event: $eventName', name: 'TeacherDashboard');
    }

    try {
      final response = await ApiService.instance.get(apiUrl);

      dev.log('📥 Response Data: $response', name: 'TeacherDashboard');

      if (response != null && response['success'] == true) {
        final stats = response['stats'] as Map<String, dynamic>? ?? {};

        final studentCount = stats['totalStudents'] as int? ??
            stats['activeStudents'] as int? ??
            60;
        final overdueCount = stats['overdueBooks'] as int? ?? 0;

        final attDetails = stats['attendanceDetails'] as Map<String, dynamic>?;
        double attendancePct = 90.0;
        int pendingAttend = 0;
        if (attDetails != null) {
          final marked = attDetails['marked'] as int? ?? 0;
          final total = attDetails['total'] as int? ?? 0;
          if (total > 0) {
            attendancePct = (marked / total) * 100.0;
            pendingAttend = (total - marked).clamp(0, 9999);
          }
        }

        if (mounted) {
          setState(() {
            _studentCount = studentCount;
            _overdueBooks = overdueCount;
            _attendanceTodayPercentage = attendancePct;
            _pendingAttendance = pendingAttend;
            _lastRefreshTime = DateTime.now();
          });
        }

        dev.log(
            '🕒 Last Refresh Time: ${_lastRefreshTime.toString()} | Trigger: $triggerSource | Event: $eventName',
            name: 'TeacherDashboard');
      }
    } catch (e) {
      dev.log('❌ Error fetching dashboard REST API: $e',
          name: 'TeacherDashboard');
    }
  }

  Future<void> _loadTeacherAttendance() async {
    try {
      final response = await ApiService.instance.get('attendance/my');
      if (response != null && response['success'] == true && response['stats'] != null) {
        final stats = response['stats'] as Map<String, dynamic>;
        final int total = stats['total'] as int? ?? 0;
        final int present = stats['present'] as int? ?? 0;
        final int late = stats['late'] as int? ?? 0;

        final double pct = total > 0 ? ((present + late) / total) * 100.0 : 100.0;
        if (mounted) {
          setState(() {
            _teacherAttendanceRate = pct;
            _teacherAttendanceLoaded = true;
          });
        }
      }
    } catch (e) {
      dev.log('Error loading teacher attendance stats: $e',
          name: 'TeacherDashboard');
    }
  }

  Map<String, List<dynamic>> _calendarEvents = {};

  Future<void> _loadUpcomingEvents() async {
    try {
      final res = await ApiService.instance
          .get('calendar/upcoming', queryParams: {'limit': '8'});
      if (res['success'] == true && mounted) {
        final events = res['events'] as List? ?? [];
        setState(() {
          _upcomingEvents = events;
          _upcomingEventsLoaded = true;
        });
      } else {
        if (mounted) {
          setState(() {
            _upcomingEventsLoaded = true;
          });
        }
      }
    } catch (e) {
      dev.log('Error loading teacher upcoming events from API: $e');
      if (mounted) {
        setState(() {
          _upcomingEventsLoaded = true;
        });
      }
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
            final key =
                '${parsedDate.year}-${parsedDate.month}-${parsedDate.day}';
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth;
        // Even if isDesktop is true, if the available width is narrow (e.g. less than 650),
        // we lay it out vertically to avoid horizontal overflow.
        final showVertical = !isDesktop || maxWidth < 650;

        if (!showVertical) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Teacher Dashboard',
                      style: GoogleFonts.outfit(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8.r),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8.r),
                          onTap: _isRefreshing ? null : _refreshDashboard,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 16.w, vertical: 8.h),
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
                                  style: AppTypography.caption.copyWith(
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
                        padding:
                            EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(color: const Color(0xFFBAE6FD)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_month_rounded,
                                size: 16.sp, color: const Color(0xFF0284C7)),
                            SizedBox(width: 6.w),
                            Text(
                                DateFormat('EEEE, d MMMM yyyy')
                                    .format(DateTime.now()),
                                style: AppTypography.caption
                                    .copyWith(color: const Color(0xFF0284C7))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 6.h),
              Text(
                  'Good day, $_teacherName. Here\'s what\'s happening in your classes.',
                  style: AppTypography.caption
                      .copyWith(color: const Color(0xFF64748B))),
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
              Text(
                  'Good day, $_teacherName. Here\'s what\'s happening in your classes.',
                  style: AppTypography.caption
                      .copyWith(color: const Color(0xFF64748B))),
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
                                style: AppTypography.caption.copyWith(
                                    color: _isRefreshing
                                        ? const Color(0xFF0EA5E9)
                                        : const Color(0xFF475569)),
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
                          style: AppTypography.caption
                              .copyWith(color: const Color(0xFF0284C7)),
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
      },
    );
  }

  Widget _buildMetricsGrid(bool isDesktop) {
    final cards = [
      _buildResponsiveStatCard(
        title: 'ATTENDANCE TODAY',
        value: _teacherAttendanceLoaded
            ? '${_teacherAttendanceRate.toStringAsFixed(0)}%'
            : '—%',
        color: const Color(0xFF3B82F6),
        showProgress: true,
        progress: _teacherAttendanceRate,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  TeacherPersonalAttendanceScreen(theme: widget.theme),
            ),
          );
        },
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
        children: cards.expand((c) => [c, SizedBox(height: 12.h)]).toList()
          ..removeLast(),
      );
    }
  }

  Widget _buildResponsiveStatCard({
    required String title,
    required String value,
    required Color color,
    required bool showProgress,
    double? progress,
    VoidCallback? onTap,
  }) {
    final cardContent = Container(
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
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.caption.copyWith(
                      color: const Color(0xFF475569), letterSpacing: 0.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onTap != null) ...[
                SizedBox(width: 8.w),
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
                widthFactor: ((progress ?? _attendanceTodayPercentage) / 100.0)
                    .clamp(0.0, 1.0),
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
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: cardContent,
      );
    }
    return cardContent;
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
                    Expanded(
                      child: Text('School Calendar',
                          style: GoogleFonts.outfit(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text('Academic schedule & events',
                    style: AppTypography.caption
                        .copyWith(color: const Color(0xFF64748B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
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
              titleTextStyle:
                  AppTypography.small.copyWith(color: const Color(0xFF0F172A)),
              leftChevronIcon: Icon(Icons.chevron_left,
                  color: const Color(0xFF0F172A), size: 24.sp),
              rightChevronIcon: Icon(Icons.chevron_right,
                  color: const Color(0xFF0F172A), size: 24.sp),
              headerPadding: EdgeInsets.symmetric(vertical: 8.h),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: AppTypography.caption
                  .copyWith(color: const Color(0xFF64748B)),
              weekendStyle: AppTypography.caption
                  .copyWith(color: const Color(0xFF64748B)),
            ),
            calendarStyle: CalendarStyle(
              defaultTextStyle: AppTypography.caption
                  .copyWith(color: const Color(0xFF1E293B)),
              weekendTextStyle: AppTypography.caption
                  .copyWith(color: const Color(0xFF1E293B)),
              outsideTextStyle: AppTypography.caption
                  .copyWith(color: const Color(0xFF94A3B8)),
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
              todayTextStyle: AppTypography.caption
                  .copyWith(color: const Color(0xFF0EA5E9)),
              selectedDecoration: BoxDecoration(
                color: const Color(0xFF0EA5E9),
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(8.r),
              ),
              selectedTextStyle:
                  AppTypography.caption.copyWith(color: Colors.white),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(20.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'EVENTS FOR ${DateFormat('d MMM').format(_selectedDay ?? DateTime.now()).toUpperCase()}',
                    style: AppTypography.caption.copyWith(
                        color: const Color(0xFF64748B), letterSpacing: 0.5)),
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
                              style: AppTypography.caption.copyWith(
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
                      final type =
                          (event['type']?.toString() ?? 'EVENT').toUpperCase();
                      final description =
                          event['description']?.toString() ?? '';
                      final time = event['startTime']?.toString() ?? '';

                      Color typeColor = const Color(0xFF0EA5E9);
                      if (type == 'HOLIDAY') {
                        typeColor = const Color(0xFFEF4444);
                      }
                      if (type == 'EXAM') typeColor = const Color(0xFFF59E0B);
                      if (type == 'MEETING') {
                        typeColor = const Color(0xFF8B5CF6);
                      }

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
                                    style: AppTypography.caption.copyWith(
                                        color: const Color(0xFF0F172A)),
                                  ),
                                  if (description.isNotEmpty) ...[
                                    SizedBox(height: 2.h),
                                    Text(
                                      description,
                                      style: AppTypography.caption.copyWith(
                                          color: const Color(0xFF64748B)),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (time.isNotEmpty)
                              Text(
                                time,
                                style: AppTypography.caption
                                    .copyWith(color: const Color(0xFF64748B)),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                })(),
                SizedBox(height: 24.h),
                GestureDetector(
                  onTap: () {
                    final isDesktop = MediaQuery.of(context).size.width > 900;
                    if (isDesktop) {
                      MainScreen.navigateTo(context, 1);
                    } else {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AcademicCalendarScreen()));
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
                            style: AppTypography.caption
                                .copyWith(color: const Color(0xFF0F172A))),
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
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10))
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_month_rounded,
                              color: const Color(0xFF0EA5E9), size: 20.sp),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text('Upcoming Events',
                                style: GoogleFonts.outfit(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Text('School activities & schedule',
                          style: AppTypography.caption
                              .copyWith(color: const Color(0xFF94A3B8)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7.w,
                      height: 7.w,
                      decoration: const BoxDecoration(
                          color: Color(0xFF22C55E), shape: BoxShape.circle),
                    ),
                    SizedBox(width: 4.w),
                    Text('LIVE',
                        style: AppTypography.caption
                            .copyWith(color: const Color(0xFF22C55E))),
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
                        width: 22.w,
                        height: 22.w,
                        child: const CircularProgressIndicator(
                            strokeWidth: 2.5, color: Color(0xFF0EA5E9)),
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
                            decoration: const BoxDecoration(
                                color: Color(0xFF1E293B),
                                shape: BoxShape.circle),
                            child: Icon(Icons.calendar_today_rounded,
                                color: const Color(0xFF475569), size: 32.sp),
                          ),
                          SizedBox(height: 16.h),
                          Text('No upcoming events scheduled',
                              style: AppTypography.caption
                                  .copyWith(color: const Color(0xFF94A3B8))),
                        ],
                      ),
                    ),
                  )
                else
                  ...(_upcomingEvents.map((event) {
                    final title = event['title']?.toString() ?? 'Event';
                    final description = event['description']?.toString() ?? '';
                    final type =
                        (event['type']?.toString() ?? 'EVENT').toUpperCase();
                    final rawDate = event['date']?.toString() ?? '';

                    DateTime? parsedDate;
                    try {
                      parsedDate = DateTime.parse(rawDate).toLocal();
                    } catch (_) {}
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
                        border:
                            Border.all(color: typeColor.withValues(alpha: 0.2)),
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
                                  parsedDate != null
                                      ? '${parsedDate.day}'
                                      : '--',
                                  style: AppTypography.small
                                      .copyWith(color: typeColor),
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
                                    style: AppTypography.caption
                                        .copyWith(color: Colors.white),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                if (description.isNotEmpty) ...[
                                  SizedBox(height: 2.h),
                                  Text(description,
                                      style: AppTypography.caption.copyWith(
                                          color: const Color(0xFF94A3B8)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ],
                                SizedBox(height: 3.h),
                                Text('$dayName, $displayDate',
                                    style: AppTypography.caption.copyWith(
                                        color:
                                            typeColor.withValues(alpha: 0.8))),
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
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AcademicCalendarScreen()));
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
                            style: AppTypography.caption
                                .copyWith(color: const Color(0xFF38BDF8))),
                        SizedBox(width: 4.w),
                        Icon(Icons.chevron_right,
                            size: 16.sp, color: const Color(0xFF38BDF8)),
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
