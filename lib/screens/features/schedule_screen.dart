import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/academic_service.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import '../../services/api_service.dart';
import '../main_screen.dart';
import '../../widgets/teacher_app_bar.dart';
import '../../widgets/teacher_scaffold.dart';
import 'package:edusphere/theme/typography.dart';

class ScheduleScreen extends StatefulWidget {
  final String role;
  final RoleTheme theme;
  final VoidCallback? onOpenDrawer;
  final bool showAppBar;

  const ScheduleScreen({
    super.key,
    required this.role,
    required this.theme,
    this.onOpenDrawer,
    this.showAppBar = false,
  });

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoading = true;
  String _selectedDay = 'Mon'; // Default, will resolve to today's day on load
  List<Map<String, dynamic>> _allEntries = [];
  List<Map<String, dynamic>> _filteredEntries = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _resolveTodayName();
    _loadTimetableData();

    // Start periodic timer to refresh the "NOW" period highlight dynamically every 60 seconds
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {}); // Trigger repaint to check active period highlights
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _resolveTodayName() {
    final weekday = DateTime.now().weekday;
    final Map<int, String> dayNames = {
      DateTime.monday: 'Mon',
      DateTime.tuesday: 'Tue',
      DateTime.wednesday: 'Wed',
      DateTime.thursday: 'Thu',
      DateTime.friday: 'Fri',
      DateTime.saturday: 'Sat',
    };
    // Default to 'Mon' if Sunday or unresolved
    _selectedDay = dayNames[weekday] ?? 'Mon';
  }

  Future<void> _loadTimetableData() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final isStudent = widget.role == 'student';

      Map<String, dynamic> response = {};
      if (isStudent) {
        String? sectionId = prefs.getString('student_section_id');
        if (sectionId == null || sectionId.isEmpty) {
          // Fetch student profile first to get sectionId
          final profileRes = await ApiService.instance.get('students/me');
          if (profileRes != null &&
              profileRes['success'] == true &&
              profileRes['student'] != null) {
            final studentData = profileRes['student'] as Map<String, dynamic>;
            sectionId = studentData['sectionId'] as String?;
            if (sectionId != null) {
              await prefs.setString('student_section_id', sectionId);
            }
          }
        }
        if (sectionId == null || sectionId.isEmpty) {
          throw Exception('Student section ID could not be resolved');
        }

        response = await AcademicService.instance.getStudentTimetable(sectionId);
      } else {
        String? teacherId = prefs.getString('teacher_id');
        if (teacherId == null || teacherId.isEmpty) {
          teacherId = 'me';
        }
        response = await AcademicService.instance.getTeacherTimetable(teacherId);
      }

      final List<dynamic> slotsRes = response['schedule'] ?? response['data'] ?? [];

      final rawSchedule = slotsRes.map((slot) {
        final subject = (slot['subject'] ?? slot['Subject']) as Map<String, dynamic>?;
        final section = (slot['section'] ?? slot['Section']) as Map<String, dynamic>?;
        final classData = (section?['class'] ?? section?['Class']) as Map<String, dynamic>?;
        final teacher = (slot['teacher'] ?? slot['Teacher']) as Map<String, dynamic>?;
        final user = (teacher?['user'] ?? teacher?['User']) as Map<String, dynamic>?;
        final room = (slot['room'] ?? slot['Room']) as Map<String, dynamic>?;

        String resolvedTeacherName = 'Class Teacher';
        if (user != null) {
          resolvedTeacherName =
              '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
        } else if (teacher != null && teacher['name'] != null) {
          resolvedTeacherName = teacher['name'] as String;
        }

        return {
          'dayOfWeek': slot['dayOfWeek'],
          'startTime': slot['startTime'],
          'endTime': slot['endTime'],
          'room': {
            'name': room?['name'] ?? slot['roomId'] ?? 'Room 101',
          },
          'section': {
            'name': section?['name'] ?? '',
            'class': {
              'name': classData?['name'] ?? '',
            },
          },
          'subject': subject,
          'teacher': {
            'user': user,
            'name': resolvedTeacherName,
          },
        };
      }).toList();

      const Map<int, String> weekdayToName = {
        1: 'Mon',
        2: 'Tue',
        3: 'Wed',
        4: 'Thu',
        5: 'Fri',
        6: 'Sat',
        7: 'Sun',
      };

      _allEntries = rawSchedule.map((sMap) {
        final teacherObj = sMap['teacher'] as Map<String, dynamic>?;
        final userObj = teacherObj?['user'] as Map<String, dynamic>?;
        String resolvedTeacherName = 'Class Teacher';
        if (userObj != null) {
          resolvedTeacherName =
              '${userObj['firstName'] ?? ''} ${userObj['lastName'] ?? ''}'
                  .trim();
        } else if (teacherObj?['name'] != null) {
          resolvedTeacherName = teacherObj!['name'] as String;
        }

        final roomObj = sMap['room'] as Map<String, dynamic>?;
        final sectionObj = sMap['section'] as Map<String, dynamic>?;
        final classObj = sectionObj?['class'] as Map<String, dynamic>?;

        return {
          'day_of_week': weekdayToName[sMap['dayOfWeek']] ?? 'Mon',
          'start_time': sMap['startTime'] ?? '08:00',
          'end_time': sMap['endTime'] ?? '08:45',
          'room_number': roomObj?['name'] ?? 'Room 101',
          'class_name': classObj?['name'] ?? '',
          'section': sectionObj?['name'] ?? '',
          'subject': sMap['subject'],
          'teacher': {
            'name': resolvedTeacherName,
          },
        };
      }).toList();

      _applyFilters();
    } catch (e) {
      debugPrint('Error loading timetable entries: $e');
      if (mounted) {
        showToast(context, 'Failed to load timetable', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilters() {
    // Filter and sort by period start_time
    _filteredEntries = _allEntries.where((entry) {
      return entry['day_of_week'].toString().toLowerCase() ==
          _selectedDay.toLowerCase();
    }).toList();

    _filteredEntries.sort((a, b) {
      final aTime = a['start_time'].toString();
      final bTime = b['start_time'].toString();
      return aTime.compareTo(bTime);
    });
  }

  bool _isCurrentPeriod(
      String dayOfWeek, String startTimeStr, String endTimeStr) {
    final now = DateTime.now();

    // 1. Day Check
    final Map<int, String> dayNames = {
      DateTime.monday: 'Mon',
      DateTime.tuesday: 'Tue',
      DateTime.wednesday: 'Wed',
      DateTime.thursday: 'Thu',
      DateTime.friday: 'Fri',
      DateTime.saturday: 'Sat',
    };
    final todayName = dayNames[now.weekday];
    if (todayName != dayOfWeek) return false;

    // 2. Time Check
    try {
      final startParts = startTimeStr.split(':');
      final endParts = endTimeStr.split(':');

      final startMin = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
      final endMin = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
      final currentMin = now.hour * 60 + now.minute;

      return currentMin >= startMin && currentMin <= endMin;
    } catch (_) {
      return false;
    }
  }

  Widget _buildDaySelector() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: days.map((day) {
          final isSelected = _selectedDay == day;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDay = day;
                _applyFilters();
              });
            },
            child: Container(
              margin: EdgeInsets.only(right: 10.w),
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: isSelected ? widget.theme.primary : Colors.white,
                borderRadius: BorderRadius.circular(24.r),
                border: Border.all(
                  color: isSelected ? Colors.transparent : AppColors.border,
                  width: 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: widget.theme.primary.withValues(alpha: 0.25),
                          blurRadius: 8.r,
                          offset: Offset(0, 3.h),
                        )
                      ]
                    : [],
              ),
              child: Text(
                day,
                style: AppTypography.caption.copyWith(
                    color: isSelected ? Colors.white : AppColors.textMedium),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPeriodCard(Map<String, dynamic> entry) {
    final dayOfWeek = entry['day_of_week'] ?? 'Mon';
    final startTime = entry['start_time'] ?? '08:00';
    final endTime = entry['end_time'] ?? '08:45';
    final roomNumber = entry['room_number'] ?? 'Room 101';
    final className = entry['class_name'] ?? '';
    final section = entry['section'] ?? '';

    // Extract Subject details
    final subject = entry['subject'] as Map<String, dynamic>?;
    final subjectName = subject?['name'] ?? 'General Subject';
    final subjectCode = subject?['code'] ?? '';

    // Extract Teacher details
    final teacher = entry['teacher'] as Map<String, dynamic>?;
    final teacherName = teacher?['name'] ?? 'Class Teacher';

    final isNow = _isCurrentPeriod(dayOfWeek, startTime, endTime);

    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isNow ? widget.theme.primary : AppColors.border,
          width: isNow ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isNow
                ? widget.theme.primary.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.02),
            blurRadius: 10.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: Row(
          children: [
            // Time Column
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  startTime,
                  style: AppTypography.body.copyWith(color: AppColors.textDark),
                ),
                Text(
                  endTime,
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textMedium),
                ),
                SizedBox(height: 6.h),
                if (isNow)
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: widget.theme.primary,
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      'NOW',
                      style: AppTypography.caption
                          .copyWith(color: Colors.white, letterSpacing: 0.5),
                    ),
                  ),
              ],
            ),
            SizedBox(width: 16.w),
            // Divider line
            Container(
              height: 60.h,
              width: 1.w,
              color: isNow
                  ? widget.theme.primary.withValues(alpha: 0.3)
                  : AppColors.border,
            ),
            SizedBox(width: 16.w),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: widget.theme.light,
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          subjectCode.isNotEmpty ? subjectCode : 'CORE',
                          style: AppTypography.caption
                              .copyWith(color: widget.theme.primary),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Icon(
                            Icons.meeting_room_outlined,
                            size: 12.sp,
                            color: AppColors.textMedium,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            roomNumber,
                            style: AppTypography.caption
                                .copyWith(color: AppColors.textMedium),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    subjectName,
                    style:
                        AppTypography.small.copyWith(color: AppColors.textDark),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Icon(
                        widget.role == 'student'
                            ? Icons.person_outline_rounded
                            : Icons.school_outlined,
                        size: 14.sp,
                        color: AppColors.textLight,
                      ),
                      SizedBox(width: 6.w),
                      Expanded(
                        child: Text(
                          widget.role == 'student'
                              ? 'Instructor: $teacherName'
                              : 'Class: $className - $section',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textMedium),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 48.h, horizontal: 24.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: widget.theme.light,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.calendar_month_outlined,
              size: 48.sp,
              color: widget.theme.primary,
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'No Classes Today 🎉',
            style: AppTypography.body.copyWith(color: AppColors.textDark),
          ),
          SizedBox(height: 8.h),
          Text(
            'Enjoy your study leave or personal project hours. Keep learning!',
            style: AppTypography.caption
                .copyWith(color: AppColors.textMedium, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherHeader() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MY SCHEDULE',
                  style: GoogleFonts.outfit(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF007FD4), // bold blue
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  'View your weekly teaching schedule and class load.',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 16.w),
          Container(
            width: 44.r,
            height: 44.r,
            decoration: const BoxDecoration(
              color: Color(0xFFE0F2FE), // light blue
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.access_time_rounded,
                color: Color(0xFF007FD4),
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherEmptyState() {
    return CustomPaint(
      painter: DashedBorderPainter(
        color: const Color(0xFFCBD5E1),
        borderRadius: 16.r,
        dashLength: 6.w,
        gap: 4.w,
        strokeWidth: 1.5.w,
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 48.h, horizontal: 24.w),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC), // light blue-slate
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.calendar_today_outlined, // gray outlined calendar icon
              size: 56,
              color: Color(0xFFCBD5E1),
            ),
            SizedBox(height: 16.h),
            Text(
              'No Classes Assigned',
              style: GoogleFonts.outfit(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              "The academic department hasn't assigned periods to your timetable yet.",
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isPushed = Navigator.canPop(context);
    final bool isTeacher = widget.role == 'teacher';

    final Widget header = isTeacher
        ? _buildTeacherHeader()
        : PageHeader(
            title: 'Class Schedule',
            subtitle: widget.role == 'student'
                ? 'Your weekly timetable lectures'
                : 'Your active classes & slots',
            theme: widget.theme,
            showBackButton: widget.showAppBar,
          );

    final Widget emptyState = isTeacher
        ? Padding(
            padding: EdgeInsets.all(16.r),
            child: _buildTeacherEmptyState(),
          )
        : Padding(
            padding: EdgeInsets.all(16.r),
            child: _buildEmptyState(),
          );

    final bodyContent = Column(
      children: [
        header,
        if (_isLoading)
          Expanded(
            child: Center(
              child: CircularProgressIndicator(
                color: widget.theme.primary,
                strokeWidth: 3.w,
              ),
            ),
          )
        else ...[
          // Show day selector only if the timetable is not entirely empty
          if (_allEntries.isNotEmpty) _buildDaySelector(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadTimetableData,
              color: widget.theme.primary,
              child: _filteredEntries.isEmpty || _allEntries.isEmpty
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.all(16.r),
                      child: emptyState,
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 16.h),
                      itemCount: _filteredEntries.length,
                      itemBuilder: (context, index) {
                        return _buildPeriodCard(_filteredEntries[index]);
                      },
                    ),
            ),
          ),
        ],
      ],
    );

    if (isTeacher && widget.showAppBar) {
      return TeacherScaffold(
        scaffoldKey: _scaffoldKey,
        title: 'EduSphere',
        activeIndex: 10,
        body: bodyContent,
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
              leading: IconButton(
                icon: Icon(Icons.menu, size: 28.sp),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
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
                  icon: Icon(Icons.notifications_none_rounded, size: 28.sp),
                  onPressed: () {},
                ),
                SizedBox(width: 8.w),
              ],
            )
          : null,
      body: bodyContent,
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double dashLength;
  final double borderRadius;

  DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.gap = 4.0,
    this.dashLength = 6.0,
    this.borderRadius = 12.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(borderRadius),
      ));

    final dashPath = Path();
    var distance = 0.0;
    
    for (final pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        dashPath.addPath(
          pathMetric.extractPath(distance, distance + dashLength),
          Offset.zero,
        );
        distance += dashLength + gap;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.gap != gap ||
      oldDelegate.dashLength != dashLength ||
      oldDelegate.borderRadius != borderRadius;
}
