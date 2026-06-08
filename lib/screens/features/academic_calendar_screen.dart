import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Event Type Colors ─────────────────────────────────────────────────────────
Color _typeColor(String? type) {
  switch ((type ?? '').toUpperCase()) {
    case 'HOLIDAY':
      return const Color(0xFFEF4444);
    case 'EXAM':
      return const Color(0xFFF59E0B);
    case 'EMERGENCY':
      return const Color(0xFF8B5CF6);
    case 'NOTICE':
      return const Color(0xFF94A3B8);
    default:
      return const Color(0xFF3B82F6);
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

  // Real-time events from Supabase
  List<dynamic> _allEvents = [];
  bool _isLoading = true;

  RealtimeChannel? _calendarChannel;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month, 1);
    _selectedDay = now;
    _loadCalendarEvents();
    _loadLocalNoticesCount();
    _connectRealtime();
  }

  @override
  void dispose() {
    if (_calendarChannel != null) {
      try {
        Supabase.instance.client.removeChannel(_calendarChannel!);
      } catch (_) {}
    }
    super.dispose();
  }

  void _connectRealtime() {
    try {
      final client = Supabase.instance.client;
      if (_calendarChannel != null) {
        client.removeChannel(_calendarChannel!);
      }
      _calendarChannel = client
          .channel('public:academic_calendar_screen')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'SchoolCalendar',
            callback: (_) {
              if (mounted) _loadCalendarEvents();
            },
          );
      _calendarChannel!.subscribe((status, [error]) {
        dev.log(
          '📡 AcademicCalendarScreen realtime status: $status',
          name: 'AcademicCalendar',
        );
        if (error != null) {
          dev.log(
            '❌ AcademicCalendarScreen realtime error: $error',
            name: 'AcademicCalendar',
          );
        }
      });
    } catch (e) {
      dev.log('Error connecting realtime in AcademicCalendarScreen: $e');
    }
  }

  Future<void> _loadCalendarEvents() async {
    try {
      final res = await Supabase.instance.client
          .from('SchoolCalendar')
          .select()
          .order('date', ascending: true);
      if (mounted) {
        setState(() {
          _allEvents = res as List<dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      dev.log('Error loading calendar events: $e');
      if (mounted) setState(() => _isLoading = false);
    }
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

  // ── Helpers ─────────────────────────────────────────────────────────────────
  List<dynamic> _getEventsForDay(int year, int month, int day) {
    return _allEvents.where((event) {
      if (event['date'] == null) return false;
      try {
        final d = DateTime.parse(event['date'].toString()).toLocal();
        return d.year == year && d.month == month && d.day == day;
      } catch (_) {
        return false;
      }
    }).toList();
  }

  int get _eventsToday {
    final now = DateTime.now();
    return _getEventsForDay(now.year, now.month, now.day).length;
  }

  int get _upcomingCount {
    int count = 0;
    final today = DateTime.now();
    for (int i = 0; i < 7; i++) {
      final date = today.add(Duration(days: i));
      count += _getEventsForDay(date.year, date.month, date.day).length;
    }
    return count;
  }

  int get _holidaysThisMonth {
    return _allEvents.where((event) {
      if (event['date'] == null) return false;
      if ((event['type'] ?? '').toString().toUpperCase() != 'HOLIDAY') return false;
      try {
        final d = DateTime.parse(event['date'].toString()).toLocal();
        return d.year == _focusedMonth.year && d.month == _focusedMonth.month;
      } catch (_) {
        return false;
      }
    }).length;
  }

  // Upcoming events sorted by date (next 90 days)
  List<dynamic> get _upcomingEventsList {
    final now = DateTime.now();
    final cutoff = now.add(const Duration(days: 90));
    final filtered = _allEvents.where((event) {
      if (event['date'] == null) return false;
      try {
        final d = DateTime.parse(event['date'].toString()).toLocal();
        return d.isAfter(now.subtract(const Duration(days: 1))) &&
            d.isBefore(cutoff);
      } catch (_) {
        return false;
      }
    }).toList();
    filtered.sort((a, b) {
      final da = DateTime.parse(a['date'].toString()).toLocal();
      final db = DateTime.parse(b['date'].toString()).toLocal();
      return da.compareTo(db);
    });
    return filtered;
  }

  void _goToPreviousMonth() {
    setState(() {
      _focusedMonth =
          DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
    });
  }

  void _goToNextMonth() {
    setState(() {
      _focusedMonth =
          DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
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
                // Realtime indicator dot
                Padding(
                  padding: EdgeInsets.only(right: 8.w),
                  child: Row(
                    children: [
                      Container(
                        width: 8.w,
                        height: 8.h,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        'Live',
                        style: GoogleFonts.inter(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                      Icons.notifications_none_rounded,
                      color: Colors.black),
                  onPressed: () {},
                ),
                SizedBox(width: 8.w),
              ],
            )
          : null,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0077D6)))
          : SafeArea(
              child: SingleChildScrollView(
                padding:
                    EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
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
    );
  }

  // ── Title + Date Badge ──────────────────────────────────────────────────────
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
              padding:
                  EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: const Color(0xFFDBEAFE)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_month_rounded,
                      size: 14.sp, color: const Color(0xFF1E6091)),
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
          style: GoogleFonts.inter(
              fontSize: 11.sp, color: const Color(0xFF64748B)),
        ),
      ],
    );
  }

  // ── 4 Stats Cards ───────────────────────────────────────────────────────────
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
          _buildStatCard('NOTICES', '$_localNoticesCount', 'New updates',
              const Color(0xFF8B5CF6), Icons.volume_up_outlined),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, String subtitle,
      Color accent, IconData icon) {
    return Container(
      width: 130.w,
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border(left: BorderSide(color: accent, width: 3.5.w)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2)),
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
                        fontSize: 8.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.3)),
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
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A))),
          SizedBox(height: 2.h),
          Text(subtitle,
              style: GoogleFonts.inter(
                  fontSize: 9.sp,
                  color: const Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ── Calendar Card ────────────────────────────────────────────────────────────
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
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 4)),
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
                  child: Icon(Icons.chevron_left_rounded,
                      size: 22.sp, color: const Color(0xFF475569)),
                ),
                SizedBox(width: 12.w),
                Text(
                  DateFormat('MMMM yyyy').format(_focusedMonth),
                  style: GoogleFonts.outfit(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A)),
                ),
                SizedBox(width: 12.w),
                GestureDetector(
                  onTap: _goToNextMonth,
                  child: Icon(Icons.chevron_right_rounded,
                      size: 22.sp, color: const Color(0xFF475569)),
                ),
                SizedBox(width: 16.w),
                GestureDetector(
                  onTap: _goToToday,
                  child: Text('Today',
                      style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0066CC))),
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
                      _toggleButton('Month', _isMonthView,
                          () => setState(() => _isMonthView = true)),
                      _toggleButton('List', !_isMonthView,
                          () => setState(() => _isMonthView = false)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (_isMonthView) ...[
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
                        final isToday = day == now.day &&
                            month == now.month &&
                            year == now.year;
                        final isSelected = _selectedDay != null &&
                            day == _selectedDay!.day &&
                            month == _selectedDay!.month &&
                            year == _selectedDay!.year;

                        final dayEventsRaw =
                            _getEventsForDay(year, month, day);
                        final hasEvents = dayEventsRaw.isNotEmpty;

                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(
                                () => _selectedDay = DateTime(year, month, day)),
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
                                    ? Border.all(
                                        color: const Color(0xFF3B82F6),
                                        width: 1.5)
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
                                  if (hasEvents) ...[
                                    SizedBox(height: 3.h),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: dayEventsRaw
                                          .take(3)
                                          .map((e) => Container(
                                                width: 4.w,
                                                height: 4.h,
                                                margin: EdgeInsets.symmetric(
                                                    horizontal: 1.w),
                                                decoration: BoxDecoration(
                                                  color: isToday
                                                      ? Colors.white
                                                      : _typeColor(
                                                          e['type']
                                                              ?.toString()),
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

            // Selected day events list
            if (_selectedDay != null) ...[
              const Divider(color: Color(0xFFE2E8F0), thickness: 1),
              Padding(
                padding: EdgeInsets.all(16.r),
                child: _buildSelectedDayEvents(),
              ),
            ],
          ] else ...[
            // List view
            Padding(
              padding: EdgeInsets.all(16.r),
              child: _buildListView(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectedDayEvents() {
    final d = _selectedDay!;
    final events = _getEventsForDay(d.year, d.month, d.day);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Events for ${DateFormat('EEEE, d MMMM').format(d)}',
          style: GoogleFonts.inter(
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF475569),
              letterSpacing: 0.5),
        ),
        SizedBox(height: 10.h),
        if (events.isEmpty)
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: Column(
                children: [
                  Icon(Icons.event_busy_rounded,
                      size: 32.sp, color: const Color(0xFFCBD5E1)),
                  SizedBox(height: 8.h),
                  Text('No events scheduled',
                      style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          color: const Color(0xFF94A3B8),
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          )
        else
          ...events.map((event) => _buildEventTile(event)),
      ],
    );
  }

  Widget _buildListView() {
    final upcoming = _upcomingEventsList;
    if (upcoming.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32.h),
          child: Column(
            children: [
              Icon(Icons.calendar_today_outlined,
                  size: 36.sp, color: const Color(0xFFCBD5E1)),
              SizedBox(height: 12.h),
              Text('No upcoming events in the next 90 days',
                  style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      color: const Color(0xFF94A3B8),
                      fontStyle: FontStyle.italic)),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'UPCOMING EVENTS (NEXT 90 DAYS)',
          style: GoogleFonts.inter(
              fontSize: 9.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF94A3B8),
              letterSpacing: 1),
        ),
        SizedBox(height: 12.h),
        ...upcoming.map((event) => Padding(
              padding: EdgeInsets.only(bottom: 10.h),
              child: _buildEventTile(event),
            )),
      ],
    );
  }

  Widget _buildEventTile(dynamic event) {
    final type = (event['type'] ?? 'EVENT').toString().toUpperCase();
    final accent = _typeColor(event['type']?.toString());
    DateTime? date;
    try {
      date = DateTime.parse(event['date'].toString()).toLocal();
    } catch (_) {}

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10.r),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4.w, color: accent),
              Expanded(
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                  child: Row(
                    children: [
                      // Date badge
                      if (date != null)
                        Container(
                          width: 40.w,
                          margin: EdgeInsets.only(right: 12.w),
                          padding: EdgeInsets.symmetric(vertical: 4.h),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                DateFormat('d').format(date),
                                style: GoogleFonts.outfit(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w800,
                                    color: accent),
                              ),
                              Text(
                                DateFormat('MMM').format(date).toUpperCase(),
                                style: GoogleFonts.inter(
                                    fontSize: 8.sp,
                                    fontWeight: FontWeight.w700,
                                    color: accent),
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    event['title'] ?? 'Event',
                                    style: GoogleFonts.inter(
                                        fontSize: 12.5.sp,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF0F172A)),
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 6.w, vertical: 2.h),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6.r),
                                  ),
                                  child: Text(type,
                                      style: GoogleFonts.inter(
                                          fontSize: 8.sp,
                                          fontWeight: FontWeight.w800,
                                          color: accent)),
                                ),
                              ],
                            ),
                            if (event['description'] != null &&
                                event['description'].toString().isNotEmpty) ...[
                              SizedBox(height: 3.h),
                              Text(
                                event['description'].toString(),
                                style: GoogleFonts.inter(
                                    fontSize: 10.sp,
                                    color: const Color(0xFF64748B),
                                    fontWeight: FontWeight.w500),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
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

  // ── Bottom Cards: Event Horizons + Legend ─────────────────────────────────
  Widget _buildBottomCards(bool isDesktop) {
    final upcomingList = _upcomingEventsList.take(5).toList();

    final children = [
      // Event Horizons (real data)
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
                  Icon(Icons.calendar_month_rounded,
                      size: 18.sp, color: const Color(0xFF475569)),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Event Horizons',
                            style: GoogleFonts.outfit(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                        SizedBox(height: 1.h),
                        Text('Chronological list of milestones',
                            style: GoogleFonts.inter(
                                fontSize: 9.sp,
                                color: const Color(0xFF94A3B8))),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              if (upcomingList.isEmpty)
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 28.sp, color: const Color(0xFF1C2541)),
                      SizedBox(height: 8.h),
                      Text('No records in ledger',
                          style: GoogleFonts.inter(
                              fontSize: 10.sp,
                              fontStyle: FontStyle.italic,
                              color: const Color(0xFF475569))),
                    ],
                  ),
                )
              else
                ...upcomingList.map((event) {
                  final accent = _typeColor(event['type']?.toString());
                  DateTime? date;
                  try {
                    date =
                        DateTime.parse(event['date'].toString()).toLocal();
                  } catch (_) {}
                  return Container(
                    margin: EdgeInsets.only(bottom: 10.h),
                    child: Row(
                      children: [
                        Container(
                          width: 4.w,
                          height: 36.h,
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(2.r),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event['title'] ?? 'Event',
                                style: GoogleFonts.inter(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (date != null)
                                Text(
                                  DateFormat('EEE, d MMM yyyy').format(date),
                                  style: GoogleFonts.inter(
                                      fontSize: 9.sp,
                                      color: const Color(0xFF64748B),
                                      fontWeight: FontWeight.w500),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
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
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A))),
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

    return Row(
        crossAxisAlignment: CrossAxisAlignment.start, children: children);
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
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF475569))),
      ],
    );
  }

  // ── Bottom Stats Bar ────────────────────────────────────────────────────────
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
          _bottomStat(Icons.calendar_today_rounded, '$_eventsToday',
              'Events Today', const Color(0xFF3B82F6)),
          _bottomStat(Icons.calendar_today_outlined, '$_upcomingCount',
              'Upcoming', const Color(0xFF10B981)),
          _bottomStat(Icons.umbrella_rounded, '$_holidaysThisMonth',
              'Holidays', const Color(0xFFF59E0B)),
          _bottomStat(Icons.volume_up_outlined, '$_localNoticesCount',
              'Notices', const Color(0xFF8B5CF6)),
        ],
      ),
    );
  }

  Widget _bottomStat(
      IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 14.sp, color: color),
            SizedBox(width: 4.w),
            Text(value,
                style: GoogleFonts.outfit(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A))),
          ],
        ),
        SizedBox(height: 2.h),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 9.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF94A3B8))),
      ],
    );
  }
}
