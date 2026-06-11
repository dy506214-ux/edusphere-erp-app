import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/api_service.dart';
import 'dart:developer' as dev;
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

  late DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime? _selectedDay;
  bool _isMonthView = true;
  bool _isLoading = false;

  String _selectedFilter = 'All Categories';
  final ScreenshotController _screenshotController = ScreenshotController();

  // Events keyed by "year-month-day"
  final Map<String, List<CalendarEvent>> _events = {};
  RealtimeChannel? _realtimeChannel;
  String _selectedFilter = 'All Categories';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month, 1);
    _selectedDay = now;
    _loadEvents();
    _connectRealTime();
  }

  @override
  void dispose() {
    if (_realtimeChannel != null) {
      try {
        Supabase.instance.client.removeChannel(_realtimeChannel!);
      } catch (_) {}
    }
    super.dispose();
  }

  Future<void> _loadEvents() async {
    try {
      final now = DateTime.now();
      final startDate = '${now.year - 1}-01-01';
      final endDate = '${now.year + 1}-12-31';
      final res = await ApiService.instance.get(
        'calendar',
        queryParams: {'startDate': startDate, 'endDate': endDate},
      );
      
      if (res['success'] == true && mounted) {
        final apiEvents = res['events'] as List? ?? [];
        setState(() {
          _events.clear();
          for (var item in apiEvents) {
            final dateStr = item['date']?.toString();
            if (dateStr == null) continue;
            try {
              final parsedDate = DateTime.parse(dateStr).toLocal();
              final title = item['title']?.toString() ?? 'No Title';
              final typeStr = item['type']?.toString().toLowerCase();
              EventType eventType;
              switch (typeStr) {
                case 'holiday':
                  eventType = EventType.holiday;
                  break;
                case 'exam':
                  eventType = EventType.exam;
                  break;
                case 'emergency':
                  eventType = EventType.emergency;
                  break;
                case 'notice':
                  eventType = EventType.notice;
                  break;
                default:
                  eventType = EventType.event;
              }
              final timeStr = item['startTime']?.toString();
              
              _addEvent(parsedDate.year, parsedDate.month, parsedDate.day, 
                  CalendarEvent(title, eventType, time: timeStr));
            } catch (e) {
              dev.log('Error parsing calendar event date: $e');
            }
          }
        });
      }
    } catch (e) {
      dev.log('Error loading calendar events from API: $e');
      _loadMockEvents();
    }
  }

  void _loadMockEvents() {
    final now = DateTime.now();
    final y = now.year;
    final m = now.month;

    setState(() {
      _events.clear();
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
    });
  }

  void _connectRealTime() {
    try {
      final client = Supabase.instance.client;
      if (_realtimeChannel != null) {
        client.removeChannel(_realtimeChannel!);
      }
      
      _realtimeChannel = client.channel('public:school_calendar_sync')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'SchoolCalendar',
          callback: (_) {
            if (mounted) {
              _loadEvents();
            }
          },
        );
      
      _realtimeChannel!.subscribe((status, [error]) {
        dev.log('📡 Supabase Realtime Academic Calendar channel status: $status', name: 'AcademicCalendarScreen');
        if (error != null) {
          dev.log('❌ Supabase Realtime Academic Calendar subscription error: $error', name: 'AcademicCalendarScreen');
        }
      });
    } catch (e) {
      dev.log('Error connecting realtime in calendar: $e');
    }
  }

  void _addEvent(int year, int month, int day, CalendarEvent event) {
    final key = '$year-$month-$day';
    _events.putIfAbsent(key, () => []).add(event);
  }

  String _eventKey(int year, int month, int day) => '$year-$month-$day';

  List<CalendarEvent> _eventsForDay(int year, int month, int day) {
    final evs = _events[_eventKey(year, month, day)] ?? [];
    if (_selectedFilter == 'All Categories') return evs;
    return evs.where((e) {
      return e.type.label.toLowerCase() == _selectedFilter.toLowerCase();
    }).toList();
  }

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
        if (_selectedFilter == 'All Categories' || e.type.label == _selectedFilter) {
          result.add(MapEntry(DateTime(year, month, d), e));
        }
      }
    }
    return result;
  }

  Future<void> _exportCalendar() async {
    try {
      // Request gallery permission via gal
      bool hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        hasAccess = await Gal.requestAccess();
        if (!hasAccess) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Gallery permission is required to save the calendar.'), backgroundColor: Colors.red),
            );
          }
          return;
        }
      }
    } catch (e) {
      dev.log("Permission request error: $e");
    }

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Capturing calendar...'), duration: Duration(seconds: 1), backgroundColor: Colors.blue),
        );
      }
      
      final imageBytes = await _screenshotController.capture(delay: const Duration(milliseconds: 100));
      if (imageBytes != null) {
        await Gal.putImageBytes(
          imageBytes,
          name: "Academic_Calendar_${DateTime.now().millisecondsSinceEpoch}"
        );
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Calendar exported to Gallery successfully!'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      dev.log("Export failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e'), backgroundColor: Colors.red),
        );
      }
    }
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Screenshot(
              controller: _screenshotController,
              child: Container(
                color: const Color(0xFFF0F4F8),
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
            ),
      bottomNavigationBar: widget.showAppBar
          ? const TeacherBottomNavBar(activeIndex: 1)
          : null,
    );
  }

  Widget _actionBtn(
    IconData icon,
    String label, {
    IconData? trailingIcon,
    bool isActive = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFE0F2FE) : Colors.white,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: isActive ? const Color(0xFF0066CC) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16.sp,
              color: isActive ? const Color(0xFF0066CC) : const Color(0xFF64748B),
            ),
            SizedBox(width: 6.w),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? const Color(0xFF0066CC) : const Color(0xFF0F172A),
              ),
            ),
            if (trailingIcon != null) ...[
              SizedBox(width: 4.w),
              Icon(
                trailingIcon,
                size: 16.sp,
                color: isActive ? const Color(0xFF0066CC) : const Color(0xFF64748B),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Academic Calendar',
                style: GoogleFonts.outfit(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0077D6),
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
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<String>(
              onSelected: (value) {
                setState(() => _selectedFilter = value);
              },
              offset: const Offset(0, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              color: Colors.white,
              elevation: 4,
              itemBuilder: (context) {
                final options = [
                  'All Categories',
                  'Holiday',
                  'Event',
                  'Exam',
                  'Emergency',
                  'Notice'
                ];
                return options.map((choice) {
                  final isSelected = choice == _selectedFilter;
                  return PopupMenuItem<String>(
                    value: choice,
                    height: 36.h,
                    child: Container(
                      width: double.infinity,
                      decoration: isSelected
                          ? BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(6.r),
                            )
                          : null,
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                      child: Text(
                        choice,
                        style: GoogleFonts.inter(
                          fontSize: 13.sp,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  );
                }).toList();
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  children: [
                    Icon(Icons.filter_alt_outlined, size: 14.sp, color: const Color(0xFF475569)),
                    SizedBox(width: 4.w),
                    Text(
                      _selectedFilter == 'All Categories' ? 'Filters' : _selectedFilter,
                      style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF475569)),
                    ),
                    SizedBox(width: 4.w),
                    Icon(Icons.keyboard_arrow_down_rounded, size: 14.sp, color: const Color(0xFF475569)),
                  ],
                ),
              ),
            ),
            SizedBox(width: 8.w),
            OutlinedButton.icon(
              onPressed: _exportCalendar,
              icon: Icon(Icons.upload_outlined, size: 14.sp, color: const Color(0xFF475569)),
              label: Text('Export', style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF475569))),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
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
              ),
            ),
            Row(
              children: [
                Builder(
                  builder: (context) {
                    final isFilterActive = _selectedFilter != 'All Categories';
                    return _actionBtn(
                      Icons.filter_alt_outlined, 
                      isFilterActive ? _selectedFilter : 'Filters',
                      trailingIcon: Icons.keyboard_arrow_down,
                      isActive: isFilterActive,
                      onTap: () {
                        final RenderBox button = context.findRenderObject() as RenderBox;
                        _showFiltersMenu(context, button);
                      }
                    );
                  }
                ),
                SizedBox(width: 8.w),
                _actionBtn(
                  Icons.file_upload_outlined, 
                  'Export',
                  onTap: _exportCalendar,
                ),
              ],
            )
          ],
        ),
      ],
    );
  }

  void _showFiltersMenu(BuildContext context, RenderBox button) {
    final RenderBox overlay = Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset(0, button.size.height + 8), ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(const Offset(0, 8)), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      color: Colors.white,
      elevation: 4,
      items: [
        'All Categories',
        'Holiday',
        'Event',
        'Exam',
        'Emergency',
        'Notice'
      ].map((String choice) {
        final isSelected = choice == _selectedFilter;
        return PopupMenuItem<String>(
          value: choice,
          padding: EdgeInsets.zero,
          child: Container(
            width: 140.w,
            margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFE0F2FE) : Colors.transparent,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              choice,
              style: GoogleFonts.inter(
                fontSize: 13.sp,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? const Color(0xFF0066CC) : const Color(0xFF0F172A),
              ),
            ),
          ),
        );
      }).toList(),
    ).then((value) {
      if (value != null) {
        setState(() {
          _selectedFilter = value;
        });
      }
    });
  }

  Future<void> _exportCalendar() async {
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Storage Permission', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('EduSphere needs access to your files and gallery to save the exported calendar.', style: GoogleFonts.inter()),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Deny', style: GoogleFonts.inter(color: Colors.grey, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0066CC),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Allow', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
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

    return Column(
      children: [
        _buildCalendarHeader(year, month),
        SizedBox(height: 14.h),
        if (_isMonthView)
          Container(
            clipBehavior: Clip.hardEdge,
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
                _buildWeekdayRow(),
                // Calendar rows
                Column(
                  children: List.generate(rows, (row) {
                    return _buildCalendarRow(row, startOffset, daysInMonth, year, month, rows);
                  }),
                ),
              ],
            ),
          )
        else
          _buildListView(),
      ],
    );
  }

  Widget _buildListView() {
    final events = _monthEventHorizons;
    
    if (events.isEmpty) {
      return Container(
        height: 400.h,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today_outlined, size: 70.sp, color: const Color(0xFFCBD5E1)),
            SizedBox(height: 24.h),
            Text(
              'No events found for this month.',
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      );
    }
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: EdgeInsets.all(16.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: events.map((e) => _buildListEventItem(e)).toList(),
      ),
    );
  }

  Widget _buildListEventItem(MapEntry<DateTime, CalendarEvent> entry) {
    final date = entry.key;
    final event = entry.value;
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: event.type.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Column(
              children: [
                Text(
                  DateFormat('MMM').format(date).toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w700, color: event.type.color),
                ),
                Text(
                  '${date.day}',
                  style: GoogleFonts.outfit(fontSize: 18.sp, fontWeight: FontWeight.w800, color: event.type.color),
                ),
              ],
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 6.h),
                Text(
                  event.title,
                  style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                ),
                if (event.time != null) ...[
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 12.sp, color: const Color(0xFF64748B)),
                      SizedBox(width: 4.w),
                      Text(event.time!, style: GoogleFonts.inter(fontSize: 12.sp, color: const Color(0xFF64748B))),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Calendar top bar: < June 2026 > Today  [Month] [List]
  Widget _buildCalendarHeader(int year, int month) {
    return Row(
      children: [
        // Left container for < June 2026 > Today
        Container(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Row(
            children: [
              _navBtn(Icons.chevron_left_rounded, _goToPreviousMonth),
              SizedBox(width: 12.w),
              Text(
                DateFormat('MMMM yyyy').format(_focusedMonth),
                style: GoogleFonts.outfit(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              SizedBox(width: 12.w),
              _navBtn(Icons.chevron_right_rounded, _goToNextMonth),
              SizedBox(width: 12.w),
              GestureDetector(
                onTap: _goToToday,
                child: Text(
                  'Today',
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0066CC),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
            ],
          ),
        ),
        const Spacer(),
        // Month / List toggle
        Container(
          padding: EdgeInsets.all(3.r),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: const Color(0xFFE2E8F0)),
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
    );
  }

  Widget _navBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28.w,
          height: 28.w,
          color: Colors.transparent,
          child: Icon(icon, size: 20.sp, color: const Color(0xFF0F172A)),
        ),
      );

  Widget _toggleBtn(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF0066CC) : Colors.transparent,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  // SUN MON TUE WED THU FRI SAT
  Widget _buildWeekdayRow() {
    const days = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: Row(
        children: days.asMap().entries.map((e) => Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 14.h),
            decoration: BoxDecoration(
              border: e.key < 6 ? const Border(right: BorderSide(color: Color(0xFFE2E8F0), width: 1)) : null,
            ),
            child: Center(
              child: Text(
                e.value,
                style: GoogleFonts.inter(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF94A3B8),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        )).toList(),
      ),
    );
  }

  // One row of 7 cells
  Widget _buildCalendarRow(
      int row, int startOffset, int daysInMonth, int year, int month, int rows) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(7, (col) {
          final cellIndex = row * 7 + col;
          final day = cellIndex - startOffset + 1;

          final isLastCol = col == 6;
          final isLastRow = row == rows - 1;
          
          BoxDecoration cellDecoration(bool isSel, bool isT) {
            return BoxDecoration(
              color: isSel && !isT ? const Color(0xFFEFF6FF) : Colors.transparent,
              border: Border(
                right: isLastCol ? BorderSide.none : const BorderSide(color: Color(0xFFE2E8F0), width: 1),
                bottom: isLastRow ? BorderSide.none : const BorderSide(color: Color(0xFFE2E8F0), width: 1),
              ),
            );
          }

          if (day < 1 || day > daysInMonth) {
            // Empty cell
            return Expanded(
              child: Container(
                constraints: BoxConstraints(minHeight: 64.h),
                decoration: cellDecoration(false, false),
              ),
            );
          }

          final now       = DateTime.now();
          final isToday   = day == now.day && month == now.month && year == now.year;
          final isSelected = _selectedDay != null &&
              day == _selectedDay!.day &&
              month == _selectedDay!.month &&
              year == _selectedDay!.year;

          final rawEvents = _eventsForDay(year, month, day);
          final dayEvents = _selectedFilter == 'All Categories'
              ? rawEvents
              : rawEvents.where((e) => e.type.label == _selectedFilter).toList();
          final hasEvents = dayEvents.isNotEmpty;

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedDay = DateTime(year, month, day)),
              child: Container(
                constraints: BoxConstraints(minHeight: 64.h),
                decoration: cellDecoration(isSelected, isToday),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (hasEvents) SizedBox(height: 6.h) else const Spacer(),
                    Container(
                      width: 32.w,
                      height: 32.w,
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
                            fontSize: 13.sp,
                            fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                            color: isToday
                                ? Colors.white
                                : const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    ),
                    if (hasEvents && _isMonthView) ...[
                      SizedBox(height: 4.h),
                      for (final ev in dayEvents.take(2))
                        _buildEventChip(ev),
                      SizedBox(height: 4.h),
                    ] else
                      const Spacer(),
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
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  Icons.calendar_today_outlined,
                  size: 20.sp,
                  color: const Color(0xFF0077D6),
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
                    'Chronological list of milestones.',
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
                padding: EdgeInsets.symmetric(vertical: 30.h),
                child: Column(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 36.sp, color: const Color(0xFF475569)),
                    SizedBox(height: 12.h),
                    Text(
                      'No events in horizon',
                      style: GoogleFonts.inter(
                        fontSize: 13.sp,
                        color: const Color(0xFF64748B),
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
      padding: EdgeInsets.all(20.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Institutional Legend',
            style: GoogleFonts.outfit(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _legendItem(const Color(0xFFEF4444), 'Holiday'),
                    SizedBox(height: 12.h),
                    _legendItem(const Color(0xFF3B82F6), 'Event'),
                    SizedBox(height: 12.h),
                    _legendItem(const Color(0xFFF59E0B), 'Exam'),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _legendItem(const Color(0xFFDC2626), 'Emergency'),
                    SizedBox(height: 12.h),
                    _legendItem(const Color(0xFF475569), 'Notice'),
                  ],
                ),
              ),
            ],
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
