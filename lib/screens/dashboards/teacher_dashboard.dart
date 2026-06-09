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

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadTeacherName();
    _loadUpcomingEvents();
    _connectRealTime();
  }

  @override
  void dispose() {
    _teacherDashTimer?.cancel();
    if (_teacherDashChannel != null) {
      try { Supabase.instance.client.removeChannel(_teacherDashChannel!); } catch (_) {}
    }
    super.dispose();
  }

  void _connectRealTime() {
    try {
      final client = Supabase.instance.client;
      _teacherDashChannel = client.channel('public:teacher_dash_events')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'SchoolCalendar',
          callback: (_) {
            if (mounted) _loadUpcomingEvents();
          },
        );
      _teacherDashChannel!.subscribe();
    } catch (e) {
      dev.log('Teacher dash realtime error: $e');
    }
    _teacherDashTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (mounted) _loadUpcomingEvents();
    });
  }

  Future<void> _loadTeacherName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('teacher_name') ?? prefs.getString('user_name') ?? 'Teacher';
    if (mounted) setState(() { _teacherName = name.trim().split(' ').first; });
  }

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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            SizedBox(height: 24.h),
            _buildMetricsGrid(),
            SizedBox(height: 24.h),
            _buildSchoolCalendar(),
            SizedBox(height: 24.h),
            _buildUpcomingEvents(),
            SizedBox(height: 80.h), // space for FAB
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: () {},
        backgroundColor: const Color(0xFF0EA5E9),
        child: Icon(Icons.auto_awesome, color: Colors.white, size: 28.sp), // closest to the spark icon
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Teacher Dashboard',
                style: GoogleFonts.outfit(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A))),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: GestureDetector(
                onTap: _loadUpcomingEvents,
                child: Row(
                  children: [
                    Icon(Icons.refresh_rounded, size: 16.sp, color: const Color(0xFF64748B)),
                    SizedBox(width: 4.w),
                    Text('Refresh',
                        style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF475569))),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Good day, $_teacherName.',
                      style: GoogleFonts.inter(
                          fontSize: 14.sp,
                          color: const Color(0xFF64748B))),
                  SizedBox(height: 4.h),
                  Text('Here\'s what\'s happening in your classes.',
                      style: GoogleFonts.inter(
                          fontSize: 14.sp,
                          color: const Color(0xFF64748B))),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_month_rounded, size: 16.sp, color: const Color(0xFF3B82F6)),
                  SizedBox(width: 6.w),
                  Text(DateFormat('EEE, d MMM yyyy').format(DateTime.now()),
                      style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF3B82F6))),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16.w,
      mainAxisSpacing: 16.h,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
            'ATTENDANCE TODAY', '95%', Icons.people_outline_rounded,
            const Color(0xFF0EA5E9), const Color(0xFFE0F2FE), true),
        _buildStatCard(
            'MY STUDENTS', '300', Icons.school_outlined,
            const Color(0xFF0EA5E9), const Color(0xFFE0F2FE), false),
        _buildStatCard(
            'PENDING ATTEND.', '0', Icons.access_time_rounded,
            const Color(0xFFF59E0B), const Color(0xFFFEF3C7), false),
        _buildStatCard(
            'OVERDUE BOOKS', '0', Icons.menu_book_rounded,
            const Color(0xFFEF4444), const Color(0xFFFEE2E2), false),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color iconColor, Color bgColor, bool showProgress) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border(left: BorderSide(color: iconColor, width: 4.w)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                        letterSpacing: 0.5)),
              ),
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 18.sp),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: GoogleFonts.outfit(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A))),
              if (showProgress) ...[
                SizedBox(height: 8.h),
                Container(
                  height: 4.h,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.95,
                    child: Container(
                      decoration: BoxDecoration(
                        color: iconColor,
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
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
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4))
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
                SizedBox(height: 24.h),
                Center(
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
                ),
                SizedBox(height: 24.h),
                Container(
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
                // Live indicator
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
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AcademicCalendarScreen())),
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


