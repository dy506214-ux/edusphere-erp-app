import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart' as intl;
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:developer' as dev;
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import '../main_screen.dart';
import '../../widgets/teacher_app_bar.dart';
import '../../widgets/teacher_scaffold.dart';
import 'package:edusphere/theme/typography.dart';

class TeacherPersonalAttendanceScreen extends StatefulWidget {
  final RoleTheme theme;
  const TeacherPersonalAttendanceScreen({super.key, required this.theme});

  @override
  State<TeacherPersonalAttendanceScreen> createState() =>
      _TeacherPersonalAttendanceScreenState();
}

class _TeacherPersonalAttendanceScreenState
    extends State<TeacherPersonalAttendanceScreen> {
  bool _isLoading = true;
  String _teacherIdStr = '';

  List<Map<String, dynamic>> _allRecords = [];
  List<Map<String, dynamic>> _filteredRecords = [];

  DateTime? _startDate;
  DateTime? _endDate;

  int _presentCount = 0;
  int _absentCount = 0;
  double? _attendanceRate;

  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadTeacherInfo();
    _connectRealTime();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    try {
      SocketService().off('attendanceMarked', _onRealtimeEvent);
      SocketService().off('ATTENDANCE_MARKED', _onRealtimeEvent);
      SocketService().off('ATTENDANCE_UPDATED', _onRealtimeEvent);
    } catch (_) {}
    super.dispose();
  }

  Future<void> _loadTeacherInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _teacherIdStr = prefs.getString('teacher_id') ?? '';
      await _loadAttendance(showLoading: true);
    } catch (e) {
      dev.log('Error loading teacher info: $e',
          name: 'TeacherPersonalAttendance');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAttendance({bool showLoading = false}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final response = await ApiService.instance.get('attendance/my');
      final List<dynamic> list = response['records'] ?? [];
      _allRecords = list.map((x) => Map<String, dynamic>.from(x)).toList();
      _applyFiltersAndCalculate();
    } catch (e) {
      dev.log('Error loading attendance data: $e',
          name: 'TeacherPersonalAttendance');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onRealtimeEvent(dynamic payload) {
    if (mounted) {
      _loadAttendance(showLoading: false);
    }
  }



  void _connectRealTime() {
    try {
      SocketService().off('attendanceMarked', _onRealtimeEvent);
      SocketService().off('ATTENDANCE_MARKED', _onRealtimeEvent);
      SocketService().off('ATTENDANCE_UPDATED', _onRealtimeEvent);

      SocketService().on('attendanceMarked', _onRealtimeEvent);
      SocketService().on('ATTENDANCE_MARKED', _onRealtimeEvent);
      SocketService().on('ATTENDANCE_UPDATED', _onRealtimeEvent);
    } catch (e) {
      dev.log('Error connecting Socket.IO: $e',
          name: 'TeacherPersonalAttendance');
    }

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (mounted) {
        _loadAttendance(showLoading: false);
      }
    });
  }

  void _applyFiltersAndCalculate() {
    // Generate dates for table
    final DateTime today = DateTime.now();
    DateTime rangeEnd = _endDate ?? today;
    DateTime rangeStart = _startDate ?? today;

    // If both start and end date are not selected, the range is just today
    final bool hasNoRange = (_startDate == null && _endDate == null);

    final List<DateTime> dateList = [];
    if (hasNoRange) {
      dateList.add(DateTime(today.year, today.month, today.day));
    } else {
      // Ensure rangeStart <= rangeEnd
      if (rangeStart.isAfter(rangeEnd)) {
        final temp = rangeStart;
        rangeStart = rangeEnd;
        rangeEnd = temp;
      }
      // Generate days descending
      DateTime current = DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day);
      final DateTime boundary =
          DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
      while (!current.isBefore(boundary)) {
        dateList.add(current);
        current = current.subtract(const Duration(days: 1));
      }
    }

    int present = 0;
    int absent = 0;
    final List<Map<String, dynamic>> logs = [];

    for (var date in dateList) {
      final dateStr = intl.DateFormat('yyyy-MM-dd').format(date);
      // Find record in _allRecords
      final record = _allRecords.firstWhere(
        (r) => r['date']?.toString().split('T')[0] == dateStr,
        orElse: () => {},
      );

      final isWeekend =
          date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

      if (record.isNotEmpty) {
        final status = record['status']?.toString().toUpperCase() ?? '';
        final checkInVal = record['checkInTime'];
        final createdAtVal = record['createdAt'];
        final markedByVal = record['markedBy']?.toString() ?? 'HR';

        String timeStr = '—';
        final timeSource = checkInVal ?? createdAtVal;
        if (timeSource != null) {
          try {
            final parsedTime = DateTime.parse(timeSource.toString());
            timeStr = intl.DateFormat('hh:mm a').format(parsedTime.toLocal());
          } catch (_) {}
        }

        logs.add({
          'date': date,
          'status': status,
          'markedBy': markedByVal.length > 20 ? 'HR' : markedByVal,
          'checkIn': timeStr,
        });

        if (status == 'PRESENT' ||
            status == 'P' ||
            status == 'LATE' ||
            status == 'Late' ||
            status == 'HALF_DAY') {
          present++;
        } else if (status == 'ABSENT' || status == 'A') {
          absent++;
        }
      } else {
        logs.add({
          'date': date,
          'status': isWeekend ? 'WEEKEND' : 'NOT_MARKED',
          'markedBy': '—',
          'checkIn': '—',
        });
      }
    }

    final int totalMarked = present + absent;

    setState(() {
      _filteredRecords = logs;
      _presentCount = present;
      _absentCount = absent;
      _attendanceRate = totalMarked > 0 ? (present / totalMarked) * 100 : null;
    });
  }

  void _openCustomDatePicker(bool isStartDate) async {
    final DateTime? initialDate = isStartDate ? _startDate : _endDate;
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => CustomCalendarPickerDialog(
        initialDate: initialDate ?? DateTime.now(),
      ),
    );

    if (mounted) {
      if (picked != null) {
        setState(() {
          if (isStartDate) {
            _startDate = picked;
          } else {
            _endDate = picked;
          }
        });
        _applyFiltersAndCalculate();
      } else if (picked == null && initialDate != null) {
        // If they chose clear (which returns null, but we distinguish returning null vs dismissing)
        // Let's handle explicit clear action in dialog which returns a special sentinel date or we handle it via CustomCalendarPickerDialog result
      }
    }
  }

  void _clearDate(bool isStartDate) {
    setState(() {
      if (isStartDate) {
        _startDate = null;
      } else {
        _endDate = null;
      }
    });
    _applyFiltersAndCalculate();
  }

  @override
  Widget build(BuildContext context) {
    return TeacherScaffold(
      title: 'My Attendance',
      activeIndex: 3,
      body: Column(
        children: [
          PageHeader(
            title: 'My Attendance Record',
            subtitle: 'History of your presence marked by HR.',
            theme: widget.theme,
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.teacherPrimary))
                : RefreshIndicator(
                    onRefresh: () => _loadAttendance(showLoading: true),
                    color: AppColors.teacherPrimary,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.all(16.r),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Start & End Date Selector Row ──
                          _buildDateFilterRow(),
                          SizedBox(height: 20.h),

                          // ── Statistics Grid ──
                          _buildStatsGrid(),
                          SizedBox(height: 24.h),

                          // ── Detailed Logs Section ──
                          _buildDetailedLogsSection(),
                          SizedBox(height: 80.h),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilterRow() {
    final startLabel = _startDate == null
        ? 'dd-mm-yyyy'
        : intl.DateFormat('dd-MM-yyyy').format(_startDate!);
    final endLabel = _endDate == null
        ? 'dd-mm-yyyy'
        : intl.DateFormat('dd-MM-yyyy').format(_endDate!);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Start Date
            Expanded(
              child: GestureDetector(
                onTap: () => _openCustomDatePicker(true),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'START DATE',
                              style: AppTypography.caption.copyWith(
                                  color: AppColors.textMedium,
                                  letterSpacing: 0.5),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              startLabel,
                              style: AppTypography.caption.copyWith(
                                  color: _startDate == null
                                      ? AppColors.textLight
                                      : AppColors.textDark),
                            ),
                          ],
                        ),
                      ),
                      if (_startDate != null)
                        GestureDetector(
                          onTap: () => _clearDate(true),
                          child: Icon(Icons.clear_rounded,
                              size: 16.sp, color: AppColors.textLight),
                        )
                      else
                        Icon(Icons.calendar_today_outlined,
                            size: 16.sp, color: AppColors.textMedium),
                    ],
                  ),
                ),
              ),
            ),

            // Divider
            Container(
              width: 1.w,
              color: AppColors.border,
              margin: EdgeInsets.symmetric(vertical: 8.h),
            ),

            // End Date
            Expanded(
              child: GestureDetector(
                onTap: () => _openCustomDatePicker(false),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'END DATE',
                              style: AppTypography.caption.copyWith(
                                  color: AppColors.textMedium,
                                  letterSpacing: 0.5),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              endLabel,
                              style: AppTypography.caption.copyWith(
                                  color: _endDate == null
                                      ? AppColors.textLight
                                      : AppColors.textDark),
                            ),
                          ],
                        ),
                      ),
                      if (_endDate != null)
                        GestureDetector(
                          onTap: () => _clearDate(false),
                          child: Icon(Icons.clear_rounded,
                              size: 16.sp, color: AppColors.textLight),
                        )
                      else
                        Icon(Icons.calendar_today_outlined,
                            size: 16.sp, color: AppColors.textMedium),
                    ],
                  ),
                ),
              ),
            ),

            // Divider
            Container(
              width: 1.w,
              color: AppColors.border,
              margin: EdgeInsets.symmetric(vertical: 8.h),
            ),

            // Filter Funnel Icon on the right corner
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              child: Icon(
                Icons.filter_alt_outlined,
                size: 20.sp,
                color: const Color(0xFF0F2547),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    final rateStr = _attendanceRate == null
        ? '—%'
        : '${_attendanceRate!.toStringAsFixed(0)}%';

    return Column(
      children: [
        // Present card
        Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TOTAL PRESENT',
                    style: AppTypography.caption.copyWith(
                        color: const Color(0xFF047857), letterSpacing: 0.5),
                  ),
                  Icon(Icons.check_circle_outline_rounded,
                      size: 18.sp, color: const Color(0xFF10B981)),
                ],
              ),
              SizedBox(height: 12.h),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$_presentCount',
                    style: AppTypography.h3
                        .copyWith(color: const Color(0xFF064E3B)),
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    'days',
                    style: AppTypography.caption
                        .copyWith(color: const Color(0xFF047857)),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 12.h),

        // Absent card
        Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
                color: const Color(0xFFEF4444).withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TOTAL ABSENT',
                    style: AppTypography.caption.copyWith(
                        color: const Color(0xFFB91C1C), letterSpacing: 0.5),
                  ),
                  Icon(Icons.cancel_outlined,
                      size: 18.sp, color: const Color(0xFFEF4444)),
                ],
              ),
              SizedBox(height: 12.h),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$_absentCount',
                    style: AppTypography.h3
                        .copyWith(color: const Color(0xFF7F1D1D)),
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    'days',
                    style: AppTypography.caption
                        .copyWith(color: const Color(0xFFB91C1C)),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 12.h),

        // Percentage card
        Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ATTENDANCE %',
                    style: AppTypography.caption.copyWith(
                        color: const Color(0xFF1D4ED8), letterSpacing: 0.5),
                  ),
                  Icon(Icons.calendar_month_outlined,
                      size: 18.sp, color: const Color(0xFF3B82F6)),
                ],
              ),
              SizedBox(height: 12.h),
              Text(
                rateStr,
                style:
                    AppTypography.h3.copyWith(color: const Color(0xFF1E3A8A)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedLogsSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detailed Logs',
            style: AppTypography.body.copyWith(color: AppColors.textDark),
          ),
          SizedBox(height: 4.h),
          Text(
            'Comprehensive history showing all dates in the range.',
            style: AppTypography.caption.copyWith(color: AppColors.textMedium),
          ),
          SizedBox(height: 20.h),

          // Table Header Row
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'Date',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textMedium),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Status',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textMedium),
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: Text(
                    'Marked\nBy',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textMedium),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Check-in\nTime',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textMedium),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          Divider(color: AppColors.border, thickness: 1, height: 16.h),

          // Logs List
          if (_filteredRecords.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 24.h),
              child: Center(
                child: Text(
                  'No records within range',
                  style: AppTypography.caption.copyWith(
                      color: AppColors.textLight, fontStyle: FontStyle.italic),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredRecords.length,
              itemBuilder: (context, idx) {
                final log = _filteredRecords[idx];
                final date = log['date'] as DateTime;
                final status = log['status'] as String;
                final markedBy = log['markedBy'] as String;
                final checkIn = log['checkIn'] as String;

                final String dateLine1 =
                    intl.DateFormat('EEE, MMM').format(date);
                final String dateLine2 =
                    intl.DateFormat('dd, yyyy').format(date);

                String statusLabel = 'Not Marked';
                Color statusBg = Colors.white;
                Color statusText = const Color(0xFF64748B);
                Border? statusBorder =
                    Border.all(color: const Color(0xFFCBD5E1));

                if (status == 'PRESENT' || status == 'P') {
                  statusLabel = 'Present';
                  statusBg = const Color(0xFFE6F4EA);
                  statusText = const Color(0xFF137333);
                  statusBorder = null;
                } else if (status == 'ABSENT' || status == 'A') {
                  statusLabel = 'Absent';
                  statusBg = const Color(0xFFFCE8E6);
                  statusText = const Color(0xFFC5221F);
                  statusBorder = null;
                } else if (status == 'LATE' || status == 'Late') {
                  statusLabel = 'Late';
                  statusBg = const Color(0xFFFEF7E0);
                  statusText = const Color(0xFFB06000);
                  statusBorder = null;
                } else if (status == 'HALF_DAY') {
                  statusLabel = 'Half Day';
                  statusBg = Colors.orange.shade50;
                  statusText = Colors.orange.shade900;
                  statusBorder = null;
                } else if (status == 'WEEKEND') {
                  statusLabel = 'Weekend';
                  statusBg = const Color(0xFFF1F3F4);
                  statusText = const Color(0xFF5F6368);
                  statusBorder = null;
                }

                return Container(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.border, width: 0.8),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Date
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dateLine1,
                              style: AppTypography.caption
                                  .copyWith(color: AppColors.textDark),
                            ),
                            Text(
                              dateLine2,
                              style: AppTypography.caption
                                  .copyWith(color: AppColors.textDark),
                            ),
                          ],
                        ),
                      ),

                      // Status tag
                      Expanded(
                        flex: 3,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 10.w, vertical: 5.h),
                            decoration: BoxDecoration(
                              color: statusBg,
                              border: statusBorder,
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Text(
                              statusLabel,
                              style: AppTypography.caption
                                  .copyWith(color: statusText),
                            ),
                          ),
                        ),
                      ),

                      // Marked By
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: Text(
                            markedBy,
                            style: AppTypography.caption
                                .copyWith(color: AppColors.textDark),
                          ),
                        ),
                      ),

                      // Check-in Time
                      Expanded(
                        flex: 3,
                        child: Text(
                          checkIn,
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textDark),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// CUSTOM CALENDAR DIALOG
// ══════════════════════════════════════════════════════════════════════════
class CustomCalendarPickerDialog extends StatefulWidget {
  final DateTime initialDate;
  const CustomCalendarPickerDialog({super.key, required this.initialDate});

  @override
  State<CustomCalendarPickerDialog> createState() =>
      _CustomCalendarPickerDialogState();
}

class _CustomCalendarPickerDialogState
    extends State<CustomCalendarPickerDialog> {
  late DateTime _currentMonth;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _currentMonth =
        DateTime(widget.initialDate.year, widget.initialDate.month, 1);
    _selectedDate = widget.initialDate;
  }

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final String monthTitle =
        intl.DateFormat('MMMM, yyyy').format(_currentMonth);

    // Days in current month
    final int daysInMonth =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    // Weekday of the first day
    final int firstDayOffset =
        _currentMonth.weekday % 7; // Sunday = 0, Monday = 1...
    final int totalCells = daysInMonth + firstDayOffset;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      elevation: 8,
      insetPadding: EdgeInsets.all(24.r),
      child: Container(
        padding: EdgeInsets.all(20.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Month navigation header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        monthTitle,
                        style: AppTypography.small
                            .copyWith(color: AppColors.textDark),
                      ),
                      SizedBox(width: 8.w),
                      // Up/down switches
                      GestureDetector(
                        onTap: _prevMonth,
                        child: Icon(Icons.arrow_upward_rounded,
                            size: 16.sp, color: AppColors.textMedium),
                      ),
                      SizedBox(width: 6.w),
                      GestureDetector(
                        onTap: _nextMonth,
                        child: Icon(Icons.arrow_downward_rounded,
                            size: 16.sp, color: AppColors.textMedium),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),

            // Weekdays row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'].map((d) {
                return Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textLight),
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 8.h),

            // GridView of cells
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 1,
              ),
              itemCount: totalCells,
              itemBuilder: (context, i) {
                if (i < firstDayOffset) {
                  return const SizedBox.shrink();
                }

                final int day = i - firstDayOffset + 1;
                final DateTime cellDate =
                    DateTime(_currentMonth.year, _currentMonth.month, day);
                final bool isSelected = _selectedDate != null &&
                    cellDate.year == _selectedDate!.year &&
                    cellDate.month == _selectedDate!.month &&
                    cellDate.day == _selectedDate!.day;

                final DateTime today = DateTime.now();
                final bool isToday = cellDate.year == today.year &&
                    cellDate.month == today.month &&
                    cellDate.day == today.day;

                Color bg = Colors.transparent;
                Color fg = AppColors.textDark;
                FontWeight weight = FontWeight.w600;

                if (isSelected) {
                  bg = const Color(0xFF0077D6);
                  fg = Colors.white;
                  weight = FontWeight.w900;
                } else if (isToday) {
                  bg = const Color(0xFF0077D6).withValues(alpha: 0.15);
                  fg = const Color(0xFF0077D6);
                  weight = FontWeight.w900;
                }

                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop(cellDate);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: bg,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$day',
                        style: AppTypography.caption.copyWith(color: fg, fontWeight: weight),
                      ),
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: 20.h),

            // Dialog action footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    // Return null to signify clear
                    Navigator.of(context).pop(null);
                  },
                  child: Text(
                    'Clear',
                    style: AppTypography.caption.copyWith(color: Colors.red),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Return today
                    Navigator.of(context).pop(DateTime.now());
                  },
                  child: Text(
                    'Today',
                    style: AppTypography.caption
                        .copyWith(color: const Color(0xFF0077D6)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
