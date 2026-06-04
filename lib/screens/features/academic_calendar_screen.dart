import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';

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
  
  const AcademicCalendarScreen({super.key});

  @override
  State<AcademicCalendarScreen> createState() => _AcademicCalendarScreenState();
}

class _AcademicCalendarScreenState extends State<AcademicCalendarScreen> {
  late DateTime _focusedMonth;
  DateTime? _selectedDay;
  bool _isMonthView = true;

  // Events keyed by year-month-day
  final Map<String, List<CalendarEvent>> _events = {};

  @override
  void initState() {
    super.initState();
    // Default to June 2026 as in the image
    _focusedMonth = DateTime(2026, 6, 1);
    _selectedDay = DateTime(2026, 6, 4);
    _loadEvents();
  }

  void _loadEvents() {
    // Adding events matching the 2nd image dots:
    _events['2026-6-4']  = [const CalendarEvent('Project Presentation', EventType.event)];
    _events['2026-6-5']  = [const CalendarEvent('Club Activity', EventType.event)];
    _events['2026-6-11'] = [const CalendarEvent('Math Semester Exam', EventType.exam)];
    _events['2026-6-12'] = [const CalendarEvent('Volleyball Match', EventType.event)];
    _events['2026-6-16'] = [const CalendarEvent('Holiday - Youth Day', EventType.holiday)];
    _events['2026-6-18'] = [const CalendarEvent('Seminar', EventType.event)];
    _events['2026-6-19'] = [const CalendarEvent('Chemistry Lab Exam', EventType.exam)];
    _events['2026-6-22'] = [const CalendarEvent('Power Failure Outage', EventType.emergency)];
    _events['2026-6-25'] = [const CalendarEvent('Music Festival', EventType.event)];
    _events['2026-6-29'] = [const CalendarEvent('Summer Break Begins', EventType.holiday)];
  }

  String _eventKey(int year, int month, int day) => '$year-$month-$day';

  int get _eventsToday {
    return _events[_eventKey(2026, 6, 4)]?.length ?? 0;
  }

  int get _upcomingCount {
    return 5; // Hardcoded to match the image requirements exactly
  }

  int get _holidaysThisMonth {
    return 1; // Hardcoded to match the image requirements exactly
  }

  int get _noticesCount {
    return 3; // Hardcoded to match the image requirements exactly
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
      _focusedMonth = DateTime(2026, 6, 1);
      _selectedDay = DateTime(2026, 6, 4);
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
                    'Thu, 4 Jun 2026',
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
  DateTime _selectedMonth = DateTime(2026, 6, 1);
  DateTime _selectedDay = DateTime(2026, 6, 4);

  final List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header matching screenshot
          PageHeader(
            title: 'Academic Calendar',
            subtitle: 'Institutional schedule, public holidays, and event horizons.',
            theme: roleThemes['student']!,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24.r),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    children: [
                      // Navigation & Filter Bar
                      _buildControlBar(isDesktop),
                      SizedBox(height: 20.h),

                      // Responsive grid structure
                      if (isDesktop)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 7, child: _buildCalendarGrid()),
                            SizedBox(width: 24.w),
                            Expanded(
                              flex: 4,
                              child: Column(
                                children: [
                                  _buildEventHorizonsCard(),
                                  SizedBox(height: 16.h),
                                  _buildLegendCard(),
                                  SizedBox(height: 16.h),
                                  _buildAssistantBubble(),
                                ],
                              ),
                            ),
                          ],
                        )
                      else
                        Column(
                          children: [
                            _buildCalendarGrid(),
                            SizedBox(height: 20.h),
                            _buildEventHorizonsCard(),
                            SizedBox(height: 16.h),
                            _buildLegendCard(),
                            SizedBox(height: 16.h),
                            _buildAssistantBubble(),
                          ],
                        ),
                      SizedBox(height: 40.h),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── CONTROL & NAVIGATION BAR ────────────────────────────────────────────────
  Widget _buildControlBar(bool isDesktop) {
    final monthName = _months[_selectedMonth.month - 1];
    
    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.chevron_left_rounded, size: 24.sp, color: AppColors.textMedium),
          onPressed: () {
            setState(() {
              _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
            });
          },
        ),
        SizedBox(width: 8.w),
        Text(
          '$monthName ${_selectedMonth.year}',
          style: GoogleFonts.inter(fontSize: 18.sp, fontWeight: FontWeight.w900, color: AppColors.textDark),
        ),
        SizedBox(width: 8.w),
        IconButton(
          icon: Icon(Icons.chevron_right_rounded, size: 24.sp, color: AppColors.textMedium),
          onPressed: () {
            setState(() {
              _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
            });
          },
        ),
        SizedBox(width: 16.w),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF0284C7),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
          ),
          onPressed: () {
            setState(() {
              _selectedMonth = DateTime(2026, 6, 1);
              _selectedDay = DateTime(2026, 6, 4);
            });
          },
          child: Text('Today', style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w800)),
        ),
      ],
    );

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _actionOutlineButton(Icons.filter_list_rounded, 'Filters'),
        SizedBox(width: 10.w),
        _actionOutlineButton(Icons.file_download_outlined, 'Export'),
        SizedBox(width: 10.w),
        // Toggle view
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(10.r),
          ),
          padding: EdgeInsets.all(2.r),
          child: Row(
            children: [
              _toggleItem('Month', true),
              _toggleItem('List', false),
            ],
          ),
        ),
      ],
    );

    if (isDesktop) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [controls, actions],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          controls,
          SizedBox(height: 12.h),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: actions),
        ],
      );
    }
  }

  Widget _actionOutlineButton(IconData icon, String label) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textMedium,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      ),
      onPressed: () {},
      icon: Icon(icon, size: 16.sp),
      label: Text(label, style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w700)),
    );
  }

  Widget _toggleItem(String label, bool active) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: active ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(8.r),
        boxShadow: active ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)] : null,
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12.sp,
          fontWeight: active ? FontWeight.w900 : FontWeight.w700,
          color: active ? const Color(0xFF0284C7) : AppColors.textLight,
        ),
      ),
    );
  }

  // ── CALENDAR GRID ──────────────────────────────────────────────────────────
  Widget _buildCalendarGrid() {
    final daysInMonth = DateUtils.getDaysInMonth(_selectedMonth.year, _selectedMonth.month);
    final firstDayOffset = DateTime(_selectedMonth.year, _selectedMonth.month, 1).weekday % 7;
    
    // We want a Grid representing days
    final weekDays = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 4)),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 12.r, offset: Offset(0, 4.h)),
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

                      final isToday = day == 4 && month == 6 && year == 2026;
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
          _bottomStat(Icons.calendar_today_rounded, '2', 'Events Today', const Color(0xFF3B82F6)),
          _bottomStat(Icons.calendar_today_outlined, '5', 'Upcoming', const Color(0xFF10B981)),
          _bottomStat(Icons.umbrella_rounded, '1', 'Holidays', const Color(0xFFF59E0B)),
          _bottomStat(Icons.volume_up_outlined, '3', 'Notices', const Color(0xFF8B5CF6)),
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
          // Weekdays header
          Row(
            children: weekDays.map((d) {
              return Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Center(
                    child: Text(
                      d,
                      style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w800, color: AppColors.textLight, letterSpacing: 0.5),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          
          // Days grid with solid borders
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 35, // 5 rows * 7 columns standard grid representation
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.0,
              mainAxisSpacing: 0,
              crossAxisSpacing: 0,
            ),
            itemBuilder: (context, index) {
              final dayVal = index - firstDayOffset + 1;
              final isValidDay = dayVal > 0 && dayVal <= daysInMonth;
              
              if (!isValidDay) {
                return Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border.withValues(alpha: 0.5), width: 0.5),
                  ),
                );
              }

              final cellDate = DateTime(_selectedMonth.year, _selectedMonth.month, dayVal);
              final isSelected = cellDate.year == _selectedDay.year && cellDate.month == _selectedDay.month && cellDate.day == _selectedDay.day;
              
              // Hardcoded event June 4, 2026 highlight match
              final isJune4_2026 = cellDate.year == 2026 && cellDate.month == 6 && cellDate.day == 4;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDay = cellDate;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border.withValues(alpha: 0.5), width: 0.5),
                  ),
                  padding: EdgeInsets.all(8.r),
                  child: Stack(
                    children: [
                      // Highlight selector
                      if (isJune4_2026 || isSelected)
                        Center(
                          child: Container(
                            width: 32.w, height: 32.h,
                            decoration: const BoxDecoration(color: Color(0xFF0284C7), shape: BoxShape.circle),
                          ),
                        ),
                      // Day number
                      Align(
                        alignment: isJune4_2026 || isSelected ? Alignment.center : Alignment.topLeft,
                        child: Text(
                          dayVal.toString(),
                          style: GoogleFonts.inter(
                            fontSize: 13.sp,
                            fontWeight: isJune4_2026 || isSelected ? FontWeight.w900 : FontWeight.w700,
                            color: isJune4_2026 || isSelected ? Colors.white : AppColors.textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── EVENT HORIZONS CARD ────────────────────────────────────────────────────
  Widget _buildEventHorizonsCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Dark slate
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 16.r, offset: Offset(0, 8.h)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Event Horizons',
            style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.w900, color: Colors.white),
          ),
          SizedBox(height: 2.h),
          Text(
            'Chronological list of milestones',
            style: GoogleFonts.inter(fontSize: 11.sp, color: Colors.white.withValues(alpha: 0.5), fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 48.h),
          // Calendar Icon & Empty State
          Center(
            child: Column(
              children: [
                Icon(Icons.calendar_today_rounded, size: 40.sp, color: Colors.white.withValues(alpha: 0.25)),
                SizedBox(height: 12.h),
                Text(
                  'No records in ledger',
                  style: GoogleFonts.inter(fontSize: 12.sp, color: Colors.white.withValues(alpha: 0.4), fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          SizedBox(height: 40.h),
        ],
      ),
    );
  }

  // ── INSTITUTIONAL LEGEND CARD ──────────────────────────────────────────────
  Widget _buildLegendCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'INSTITUTIONAL LEGEND',
            style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w800, color: AppColors.textLight, letterSpacing: 0.8),
          ),
          SizedBox(height: 16.h),
          _legendItem(const Color(0xFFEF4444), 'Holiday'),
          SizedBox(height: 12.h),
          _legendItem(const Color(0xFF3B82F6), 'Event'),
          SizedBox(height: 12.h),
          _legendItem(const Color(0xFFF59E0B), 'Exam'),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8.w, height: 8.h,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 10.w),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w700, color: AppColors.textMedium),
        ),
      ],
    );
  }

  // ── ASSISTANT BUBBLE ───────────────────────────────────────────────────────
  Widget _buildAssistantBubble() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2FE),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.r),
          topRight: Radius.circular(20.r),
          bottomRight: Radius.circular(20.r),
        ),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HI PRIYA!',
            style: GoogleFonts.outfit(fontSize: 13.sp, fontWeight: FontWeight.w900, color: const Color(0xFF0369A1)),
          ),
          SizedBox(height: 4.h),
          Text(
            'HOW CAN I HELP?',
            style: GoogleFonts.outfit(fontSize: 14.sp, fontWeight: FontWeight.w900, color: const Color(0xFF0284C7)),
          ),
        ],
      ),
    );
  }
}
