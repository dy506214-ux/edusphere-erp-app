import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../main_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Event model
// ═══════════════════════════════════════════════════════════════════════════════
enum EventType { holiday, event, exam, emergency, notice }

extension EventTypeExtension on EventType {
  Color get color {
    switch (this) {
      case EventType.holiday:   return const Color(0xFFEF4444);
      case EventType.event:     return const Color(0xFF3B82F6);
      case EventType.exam:      return const Color(0xFFF59E0B);
      case EventType.emergency: return const Color(0xFF8B5CF6);
      case EventType.notice:    return const Color(0xFF94A3B8);
    }
  }

  Color get bgColor {
    switch (this) {
      case EventType.holiday:   return const Color(0xFFFEE2E2);
      case EventType.event:     return const Color(0xFFDBEAFE);
      case EventType.exam:      return const Color(0xFFFEF3C7);
      case EventType.emergency: return const Color(0xFFEDE9FE);
      case EventType.notice:    return const Color(0xFFF1F5F9);
    }
  }

  String get label {
    switch (this) {
      case EventType.holiday:   return 'Holiday';
      case EventType.event:     return 'Event';
      case EventType.exam:      return 'Exam';
      case EventType.emergency: return 'Emergency';
      case EventType.notice:    return 'Notice';
    }
  }
}

class CalendarEvent {
  final String title;
  final EventType type;
  final String? time;
  const CalendarEvent(this.title, this.type, {this.time});
}

// ═══════════════════════════════════════════════════════════════════════════════
// Academic Calendar Screen
// ═══════════════════════════════════════════════════════════════════════════════
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late DateTime _focusedMonth;
  DateTime? _selectedDay;
  bool _isMonthView = true;

  // Events keyed by "year-month-day"
  final Map<String, List<CalendarEvent>> _events = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month, 1);
    _selectedDay = now;
    _loadEvents();
  }

  void _loadEvents() {
    final now = DateTime.now();
    final y = now.year;
    final m = now.month;

    // Pre-loaded institutional events
    _addEvent(y, m, 1,  const CalendarEvent('Start of Academic Year 2025-2026', EventType.event));
    _addEvent(y, m, 15, const CalendarEvent('Science Fair 2026', EventType.event, time: '10:00 AM'));
    _addEvent(y, m, 20, const CalendarEvent('National Holiday', EventType.holiday));
    _addEvent(y, m, 25, const CalendarEvent('Mid-Term Examinations', EventType.exam));

    // Next month events
    _addEvent(y, m + 1, 5,  const CalendarEvent('Parents Meeting', EventType.event));
    _addEvent(y, m + 1, 14, const CalendarEvent('Independence Day', EventType.holiday));
    _addEvent(y, m + 1, 22, const CalendarEvent('Annual Sports Day', EventType.event));
    _addEvent(y, m + 1, 28, const CalendarEvent('Chemistry Lab Exam', EventType.exam));
  }

  void _addEvent(int year, int month, int day, CalendarEvent event) {
    final key = '$year-$month-$day';
    _events.putIfAbsent(key, () => []).add(event);
  }

  String _eventKey(int year, int month, int day) => '$year-$month-$day';

  List<CalendarEvent> _eventsForDay(int year, int month, int day) =>
      _events[_eventKey(year, month, day)] ?? [];

  void _goToPreviousMonth() => setState(() {
        _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
      });

  void _goToNextMonth() => setState(() {
        _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
      });

  void _goToToday() => setState(() {
        final now = DateTime.now();
        _focusedMonth = DateTime(now.year, now.month, 1);
        _selectedDay = now;
      });

  // All events in focused month sorted by day
  List<MapEntry<DateTime, CalendarEvent>> get _monthEventHorizons {
    final year = _focusedMonth.year;
    final month = _focusedMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;

    final List<MapEntry<DateTime, CalendarEvent>> result = [];
    for (int d = 1; d <= daysInMonth; d++) {
      final events = _eventsForDay(year, month, d);
      for (var e in events) {
        result.add(MapEntry(DateTime(year, month, d), e));
      }
    }
    return result;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF0F4F8),
      drawer: widget.showAppBar
          ? const EduSphereDrawer(role: 'teacher', activeLabel: 'Academic Calendar')
          : null,
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.menu, size: 28.sp, color: const Color(0xFF0F172A)),
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                  widget.onOpenDrawer?.call();
                },
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
                  icon:
                      Icon(Icons.notifications_none_rounded, size: 26.sp),
                  onPressed: () {},
                ),
                SizedBox(width: 8.w),
              ],
            )
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              SizedBox(height: 18.h),
              _buildCalendarCard(),
              SizedBox(height: 14.h),
              _buildEventHorizons(),
              SizedBox(height: 14.h),
              _buildLegend(),
              SizedBox(height: 80.h),
            ],
          ),
        ),
      ),
      bottomNavigationBar: widget.showAppBar
          ? const TeacherBottomNavBar(activeIndex: 1)
          : null,
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Academic Calendar',
          style: GoogleFonts.outfit(
            fontSize: 24.sp,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          'Institutional schedule, public holidays, and event horizons.',
          style: GoogleFonts.inter(
            fontSize: 12.sp,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  // ── Full Calendar Card ─────────────────────────────────────────────────────
  Widget _buildCalendarCard() {
    final year  = _focusedMonth.year;
    final month = _focusedMonth.month;
    final firstDay     = DateTime(year, month, 1);
    final daysInMonth  = DateTime(year, month + 1, 0).day;
    // Sunday = 0  (Dart weekday: Mon=1..Sun=7)
    final startOffset  = firstDay.weekday % 7;
    final totalCells   = startOffset + daysInMonth;
    final rows         = (totalCells / 7).ceil();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildCalendarHeader(year, month),
          _buildWeekdayRow(),
          SizedBox(height: 4.h),
          // Calendar rows
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.w),
            child: Column(
              children: List.generate(rows, (row) {
                return _buildCalendarRow(row, startOffset, daysInMonth, year, month);
              }),
            ),
          ),
          SizedBox(height: 10.h),
        ],
      ),
    );
  }

  // Calendar top bar: < June 2026 > Today  [Month] [List]
  Widget _buildCalendarHeader(int year, int month) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 14.h, 12.w, 10.h),
      child: Row(
        children: [
          // Prev button
          _navBtn(Icons.chevron_left_rounded, _goToPreviousMonth),
          SizedBox(width: 8.w),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                DateFormat('MMMM yyyy').format(_focusedMonth),
                style: GoogleFonts.outfit(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          // Next button
          _navBtn(Icons.chevron_right_rounded, _goToNextMonth),
          SizedBox(width: 12.w),
          // Today link
          GestureDetector(
            onTap: _goToToday,
            child: Text(
              'Today',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0066CC),
              ),
            ),
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
                _toggleBtn('Month', _isMonthView,
                    () => setState(() => _isMonthView = true)),
                _toggleBtn('List', !_isMonthView,
                    () => setState(() => _isMonthView = false)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28.w,
          height: 28.w,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6.r),
          ),
          child: Icon(icon, size: 18.sp, color: const Color(0xFF475569)),
        ),
      );

  Widget _toggleBtn(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF0066CC) : Colors.transparent,
          borderRadius: BorderRadius.circular(6.r),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  // SUN MON TUE WED THU FRI SAT
  Widget _buildWeekdayRow() {
    const days = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8.w),
      padding: EdgeInsets.symmetric(vertical: 8.h),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFF1F5F9), width: 1),
          bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
        ),
      ),
      child: Row(
        children: days
            .map((d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: GoogleFonts.inter(
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF94A3B8),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  // One row of 7 cells
  Widget _buildCalendarRow(
      int row, int startOffset, int daysInMonth, int year, int month) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(7, (col) {
          final cellIndex = row * 7 + col;
          final day = cellIndex - startOffset + 1;

          if (day < 1 || day > daysInMonth) {
            // Empty cell
            return Expanded(
              child: Container(
                margin: EdgeInsets.all(1.r),
                constraints: BoxConstraints(minHeight: 54.h),
              ),
            );
          }

          final now       = DateTime.now();
          final isToday   = day == now.day && month == now.month && year == now.year;
          final isSelected = _selectedDay != null &&
              day == _selectedDay!.day &&
              month == _selectedDay!.month &&
              year == _selectedDay!.year;

          final dayEvents = _eventsForDay(year, month, day);
          final hasEvents = dayEvents.isNotEmpty;

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedDay = DateTime(year, month, day)),
              child: Container(
                margin: EdgeInsets.all(1.r),
                constraints: BoxConstraints(minHeight: 54.h),
                decoration: BoxDecoration(
                  color: isSelected && !isToday
                      ? const Color(0xFFEFF6FF)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8.r),
                  border: isSelected && !isToday
                      ? Border.all(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                          width: 1)
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Day number row
                    Padding(
                      padding: EdgeInsets.fromLTRB(4.w, 4.h, 4.w, 2.h),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 22.w,
                            height: 22.w,
                            decoration: isToday
                                ? const BoxDecoration(
                                    color: Color(0xFF0066CC),
                                    shape: BoxShape.circle,
                                  )
                                : null,
                            child: Center(
                              child: Text(
                                '$day',
                                style: GoogleFonts.inter(
                                  fontSize: 11.sp,
                                  fontWeight: isToday || isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: isToday
                                      ? Colors.white
                                      : const Color(0xFF1E293B),
                                ),
                              ),
                            ),
                          ),
                          if (hasEvents)
                            Expanded(
                              child: Text(
                                '${dayEvents.length} ${dayEvents.length == 1 ? 'Item' : 'Items'}',
                                textAlign: TextAlign.right,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 7.sp,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Event chips
                    if (hasEvents && _isMonthView) ...[
                      for (final ev in dayEvents.take(2))
                        _buildEventChip(ev),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEventChip(CalendarEvent ev) {
    return Container(
      margin: EdgeInsets.only(left: 2.w, right: 2.w, bottom: 2.h),
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: ev.type.bgColor,
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Text(
        ev.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          fontSize: 7.5.sp,
          fontWeight: FontWeight.w600,
          color: ev.type.color,
        ),
      ),
    );
  }

  // ── Event Horizons Panel ───────────────────────────────────────────────────
  Widget _buildEventHorizons() {
    final horizons = _monthEventHorizons;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B1437),
        borderRadius: BorderRadius.circular(18.r),
      ),
      padding: EdgeInsets.all(18.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6.r),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  Icons.event_note_rounded,
                  size: 16.sp,
                  color: const Color(0xFF94A3B8),
                ),
              ),
              SizedBox(width: 10.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Event Horizons',
                    style: GoogleFonts.outfit(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Chronological list of milestones',
                    style: GoogleFonts.inter(
                      fontSize: 10.sp,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 18.h),

          if (horizons.isEmpty) ...[
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20.h),
                child: Column(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 30.sp, color: const Color(0xFF1C2541)),
                    SizedBox(height: 8.h),
                    Text(
                      'No events this month',
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        fontStyle: FontStyle.italic,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            for (int i = 0; i < horizons.length; i++) ...[
              _buildHorizonItem(horizons[i].key, horizons[i].value,
                  isLast: i == horizons.length - 1),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildHorizonItem(DateTime date, CalendarEvent event,
      {bool isLast = false}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline column
          Column(
            children: [
              Container(
                width: 10.w,
                height: 10.w,
                decoration: BoxDecoration(
                  color: event.type.color,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1.5.w,
                    color: Colors.white.withValues(alpha: 0.07),
                  ),
                ),
            ],
          ),
          SizedBox(width: 12.w),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        DateFormat('d MMM').format(date),
                        style: GoogleFonts.inter(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 8.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: event.type.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Text(
                          event.type.label,
                          style: GoogleFonts.inter(
                            fontSize: 8.5.sp,
                            fontWeight: FontWeight.w700,
                            color: event.type.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    event.title,
                    style: GoogleFonts.outfit(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  if (event.time != null) ...[
                    SizedBox(height: 2.h),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded,
                            size: 10.sp, color: const Color(0xFF64748B)),
                        SizedBox(width: 3.w),
                        Text(
                          event.time!,
                          style: GoogleFonts.inter(
                            fontSize: 9.5.sp,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Institutional Legend ───────────────────────────────────────────────────
  Widget _buildLegend() {
    const items = [
      (Color(0xFFEF4444), 'Holiday'),
      (Color(0xFF3B82F6), 'Event'),
      (Color(0xFFF59E0B), 'Exam'),
      (Color(0xFF8B5CF6), 'Emergency'),
      (Color(0xFF94A3B8), 'Notice'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(16.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'INSTITUTIONAL LEGEND',
            style: GoogleFonts.inter(
              fontSize: 9.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF94A3B8),
              letterSpacing: 0.8,
            ),
          ),
          SizedBox(height: 14.h),
          Wrap(
            spacing: 20.w,
            runSpacing: 10.h,
            children: items
                .map((item) => _legendItem(item.$1, item.$2))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9.w,
          height: 9.w,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 6.w),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF475569),
          ),
        ),
      ],
    );
  }
}
