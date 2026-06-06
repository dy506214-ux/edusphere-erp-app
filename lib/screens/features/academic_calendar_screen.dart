import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// ── Event model ──────────────────────────────────────────────────────────────
enum EventType { holiday, event, exam, emergency, notice }

class CalendarEvent {
  final String title;
  final EventType type;
  const CalendarEvent(this.title, this.type);

  Color get dotColor {
    switch (type) {
      case EventType.holiday:   return const Color(0xFFEF4444); // Red
      case EventType.event:     return const Color(0xFF3B82F6); // Blue
      case EventType.exam:      return const Color(0xFFF59E0B); // Orange
      case EventType.emergency: return const Color(0xFF8B5CF6); // Purple
      case EventType.notice:    return const Color(0xFF94A3B8); // Grey
    }
  }
}

// ── Screen ───────────────────────────────────────────────────────────────────
class AcademicCalendarScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  final bool showAppBar;
  
  const AcademicCalendarScreen({
    super.key,
    this.onOpenDrawer,
    this.showAppBar = true,
  });
  
  @override
  State<AcademicCalendarScreen> createState() => _AcademicCalendarScreenState();
}

class _AcademicCalendarScreenState extends State<AcademicCalendarScreen> {
  late DateTime _focusedMonth;
  DateTime? _selectedDay;
  bool _isMonthView = true;
  int _localNoticesCount = 1;

  // Events keyed by year-month-day
  final Map<String, List<CalendarEvent>> _events = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month, 1);
    _selectedDay = now;
    _loadEvents();
    _loadLocalNoticesCount();
  }

  Future<void> _loadLocalNoticesCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getString('local_announcements_list');
      if (rawList != null) {
        final List<dynamic> decoded = json.decode(rawList);
        if (mounted) {
          setState(() {
            _localNoticesCount = decoded.length;
          });
        }
      }
    } catch (_) {}
  }

  void _loadEvents() {
    final now = DateTime.now();
    final y = now.year;
    final m = now.month;

    // Adding events matching the 2nd image dots:
    _events['$y-$m-4']  = [const CalendarEvent('Project Presentation', EventType.event)];
    _events['$y-$m-5']  = [const CalendarEvent('Club Activity', EventType.event)];
    _events['$y-$m-11'] = [const CalendarEvent('Math Semester Exam', EventType.exam)];
    _events['$y-$m-12'] = [const CalendarEvent('Volleyball Match', EventType.event)];
    _events['$y-$m-16'] = [const CalendarEvent('Holiday - Youth Day', EventType.holiday)];
    _events['$y-$m-18'] = [const CalendarEvent('Seminar', EventType.event)];
    _events['$y-$m-19'] = [const CalendarEvent('Chemistry Lab Exam', EventType.exam)];
    _events['$y-$m-22'] = [const CalendarEvent('Power Failure Outage', EventType.emergency)];
    _events['$y-$m-25'] = [const CalendarEvent('Music Festival', EventType.event)];
    _events['$y-$m-29'] = [const CalendarEvent('Summer Break Begins', EventType.holiday)];
  }

  String _eventKey(int year, int month, int day) => '$year-$month-$day';

  int get _eventsToday {
    final now = DateTime.now();
    return _events[_eventKey(now.year, now.month, now.day)]?.length ?? 0;
  }

  int get _upcomingCount {
    int count = 0;
    final today = DateTime.now();
    for (int i = 0; i < 7; i++) {
      final date = today.add(Duration(days: i));
      final key = _eventKey(date.year, date.month, date.day);
      final dayEvents = _events[key];
      if (dayEvents != null) {
        count += dayEvents.length;
      }
    }
    return count;
  }

  int get _holidaysThisMonth {
    int count = 0;
    final year = _focusedMonth.year;
    final month = _focusedMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    for (int day = 1; day <= daysInMonth; day++) {
      final key = _eventKey(year, month, day);
      final dayEvents = _events[key];
      if (dayEvents != null) {
        for (var event in dayEvents) {
          if (event.type == EventType.holiday) {
            count++;
          }
        }
      }
    }
    return count;
  }

  int get _noticesCount {
    return _localNoticesCount;
  }

  void _goToPreviousMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
    });
  }

  void _goToNextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
    });
  }

  void _goToToday() {
    setState(() {
      final now = DateTime.now();
      _focusedMonth = DateTime(now.year, now.month, 1);
      _selectedDay = now;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: Navigator.canPop(context)
                  ? const BackButton(color: Colors.black)
                  : IconButton(
                      icon: const Icon(Icons.menu, color: Colors.black),
                      onPressed: widget.onOpenDrawer,
                    ),
              title: Text(
                'EduSphere',
                style: GoogleFonts.outfit(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_none_rounded, color: Colors.black),
                  onPressed: () {},
                ),
                SizedBox(width: 8.w),
              ],
            )
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTitle(),
              SizedBox(height: 16.h),
              _buildStatsRow(),
              SizedBox(height: 20.h),
              _buildCalendarCard(),
              SizedBox(height: 20.h),
              _buildBottomCards(isDesktop),
              SizedBox(height: 16.h),
              _buildBottomStatsBar(),
              SizedBox(height: 80.h),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: const Color(0xFF0066CC),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.r)),
        child: Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 24.sp),
      ),
    );
  }

  // ── Title + Date Badge ─────────────────────────────────────────────────────
  Widget _buildTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Academic Calendar',
                style: GoogleFonts.outfit(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: const Color(0xFFDBEAFE)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_month_rounded, size: 14.sp, color: const Color(0xFF1E6091)),
                  SizedBox(width: 4.w),
                  Text(
                    DateFormat('EEE, d MMM yyyy').format(DateTime.now()),
                    style: GoogleFonts.inter(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E6091),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 4.h),
        Text(
          'Institutional schedule, public holidays, and event horizons.',
          style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF64748B)),
        ),
      ],
    );
  }

  // ── 4 Stats Cards ──────────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildStatCard('EVENTS TODAY', '$_eventsToday', 'Events scheduled',
              const Color(0xFF3B82F6), Icons.calendar_today_outlined),
          SizedBox(width: 10.w),
          _buildStatCard('UPCOMING EVENTS', '$_upcomingCount', 'Next 7 days',
              const Color(0xFF10B981), Icons.calendar_today_outlined),
          SizedBox(width: 10.w),
          _buildStatCard('HOLIDAYS', '$_holidaysThisMonth', 'This month',
              const Color(0xFFF59E0B), Icons.umbrella_rounded),
          SizedBox(width: 10.w),
          _buildStatCard('NOTICES', '$_noticesCount', 'New updates',
              const Color(0xFF8B5CF6), Icons.volume_up_outlined),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, String subtitle, Color accent, IconData icon) {
    return Container(
      width: 130.w,
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border(left: BorderSide(color: accent, width: 3.5.w)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 8.sp, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.3)),
              ),
              Container(
                padding: EdgeInsets.all(4.r),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Icon(icon, size: 14.sp, color: accent),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(value,
              style: GoogleFonts.outfit(
                  fontSize: 22.sp, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
          SizedBox(height: 2.h),
          Text(subtitle,
              style: GoogleFonts.inter(fontSize: 9.sp, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ── Calendar Card ──────────────────────────────────────────────────────────
  Widget _buildCalendarCard() {
    final year = _focusedMonth.year;
    final month = _focusedMonth.month;
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startOffset = firstDay.weekday % 7; // Sunday = 0
    final totalCells = startOffset + daysInMonth;
    final rows = ((totalCells) / 7).ceil();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // Calendar Header
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
            child: Row(
              children: [
                // Month nav
                GestureDetector(
                  onTap: _goToPreviousMonth,
                  child: Icon(Icons.chevron_left_rounded, size: 22.sp, color: const Color(0xFF475569)),
                ),
                SizedBox(width: 12.w),
                Text(
                  DateFormat('MMMM yyyy').format(_focusedMonth),
                  style: GoogleFonts.outfit(
                      fontSize: 15.sp, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                ),
                SizedBox(width: 12.w),
                GestureDetector(
                  onTap: _goToNextMonth,
                  child: Icon(Icons.chevron_right_rounded, size: 22.sp, color: const Color(0xFF475569)),
                ),
                SizedBox(width: 16.w),
                GestureDetector(
                  onTap: _goToToday,
                  child: Text('Today',
                      style: GoogleFonts.inter(
                          fontSize: 11.sp, fontWeight: FontWeight.w700, color: const Color(0xFF0066CC))),
                ),
                const Spacer(),
                // Month / List toggle
                Container(
                  padding: EdgeInsets.all(3.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    children: [
                      _toggleButton('Month', _isMonthView, () => setState(() => _isMonthView = true)),
                      _toggleButton('List', !_isMonthView, () => setState(() => _isMonthView = false)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Day-of-week headers
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: Row(
              children: ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT']
                  .map((d) => Expanded(
                        child: Center(
                          child: Text(d,
                              style: GoogleFonts.inter(
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF94A3B8))),
                        ),
                      ))
                  .toList(),
            ),
          ),
          SizedBox(height: 8.h),

          // Calendar Grid
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: Column(
              children: List.generate(rows, (row) {
                return Padding(
                  padding: EdgeInsets.only(bottom: 4.h),
                  child: Row(
                    children: List.generate(7, (col) {
                      final cellIndex = row * 7 + col;
                      final day = cellIndex - startOffset + 1;

                      if (day < 1 || day > daysInMonth) {
                        return Expanded(child: SizedBox(height: 44.h));
                      }

                      final now = DateTime.now();
                      final isToday = day == now.day && month == now.month && year == now.year;
                      final isSelected = _selectedDay != null &&
                          day == _selectedDay!.day &&
                          month == _selectedDay!.month &&
                          year == _selectedDay!.year;
                      
                      final key = _eventKey(year, month, day);
                      final dayEvents = _events[key];

                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedDay = DateTime(year, month, day)),
                          child: Container(
                            height: 44.h,
                            decoration: BoxDecoration(
                              color: isToday
                                  ? const Color(0xFF0066CC)
                                  : isSelected
                                      ? const Color(0xFFEFF6FF)
                                      : Colors.transparent,
                              borderRadius: BorderRadius.circular(10.r),
                              border: isSelected && !isToday
                                  ? Border.all(color: const Color(0xFF3B82F6), width: 1.5)
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$day',
                                  style: GoogleFonts.inter(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w600,
                                    color: isToday
                                        ? Colors.white
                                        : const Color(0xFF1E293B),
                                  ),
                                ),
                                if (dayEvents != null) ...[
                                  SizedBox(height: 3.h),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: dayEvents
                                        .take(3)
                                        .map((e) => Container(
                                              width: 4.w,
                                              height: 4.h,
                                              margin: EdgeInsets.symmetric(horizontal: 1.w),
                                              decoration: BoxDecoration(
                                                color: isToday
                                                    ? Colors.white
                                                    : e.dotColor,
                                                shape: BoxShape.circle,
                                              ),
                                            ))
                                        .toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                );
              }),
            ),
          ),
          SizedBox(height: 12.h),
        ],
      ),
    );
  }

  Widget _toggleButton(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF0066CC) : Colors.transparent,
          borderRadius: BorderRadius.circular(6.r),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10.sp,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  // ── Bottom Cards: Event Horizons + Legend ───────────────────────────────────
  Widget _buildBottomCards(bool isDesktop) {
    final children = [
      // Event Horizons
      Expanded(
        child: Container(
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: const Color(0xFF0B132B),
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_month_rounded, size: 18.sp, color: const Color(0xFF475569)),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Event Horizons',
                            style: GoogleFonts.outfit(
                                fontSize: 13.sp, fontWeight: FontWeight.w700, color: Colors.white)),
                        SizedBox(height: 1.h),
                        Text('Chronological list of milestones',
                            style: GoogleFonts.inter(
                                fontSize: 9.sp, color: const Color(0xFF94A3B8))),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24.h),
              Center(
                child: Column(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 28.sp, color: const Color(0xFF1C2541)),
                    SizedBox(height: 8.h),
                    Text('No records in ledger',
                        style: GoogleFonts.inter(
                            fontSize: 10.sp,
                            fontStyle: FontStyle.italic,
                            color: const Color(0xFF475569))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      SizedBox(width: isDesktop ? 16.w : 12.w),
      // Institutional Legend
      Expanded(
        child: Container(
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Institutional Legend',
                  style: GoogleFonts.outfit(
                      fontSize: 13.sp, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
              SizedBox(height: 12.h),
              _legendItem(const Color(0xFFEF4444), 'Holiday'),
              SizedBox(height: 8.h),
              _legendItem(const Color(0xFF3B82F6), 'Event'),
              SizedBox(height: 8.h),
              _legendItem(const Color(0xFFF59E0B), 'Exam'),
              SizedBox(height: 8.h),
              _legendItem(const Color(0xFF8B5CF6), 'Emergency'),
              SizedBox(height: 8.h),
              _legendItem(const Color(0xFF94A3B8), 'Notice'),
            ],
          ),
        ),
      ),
    ];

    if (isDesktop) {
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: children);
    } else {
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: children);
    }
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8.w,
          height: 8.h,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 8.w),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 11.sp, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
      ],
    );
  }

  // ── Bottom Stats Bar ───────────────────────────────────────────────────────
  Widget _buildBottomStatsBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _bottomStat(Icons.calendar_today_rounded, '$_eventsToday', 'Events Today', const Color(0xFF3B82F6)),
          _bottomStat(Icons.calendar_today_outlined, '$_upcomingCount', 'Upcoming', const Color(0xFF10B981)),
          _bottomStat(Icons.umbrella_rounded, '$_holidaysThisMonth', 'Holidays', const Color(0xFFF59E0B)),
          _bottomStat(Icons.volume_up_outlined, '$_localNoticesCount', 'Notices', const Color(0xFF8B5CF6)),
        ],
      ),
    );
  }

  Widget _bottomStat(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 14.sp, color: color),
            SizedBox(width: 4.w),
            Text(value,
                style: GoogleFonts.outfit(
                    fontSize: 14.sp, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
          ],
        ),
        SizedBox(height: 2.h),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 9.sp, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8))),
      ],
    );
  }
}
