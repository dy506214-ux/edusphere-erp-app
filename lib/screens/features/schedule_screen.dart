import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import '../../services/api_service.dart';
import '../main_screen.dart';


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
    this.showAppBar = true,
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
    _timer = Timer.periodic(const Duration(seconds: 60), (timer) {
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

      dynamic response;
      if (isStudent) {
        String? sectionId = prefs.getString('student_section_id');
        if (sectionId == null || sectionId.isEmpty) {
          // Fetch student profile first to get sectionId
          final profileRes = await ApiService.instance.get('students/me');
          if (profileRes != null && profileRes['success'] == true && profileRes['student'] != null) {
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

        response = await ApiService.instance.get('timetable/student/$sectionId');
      } else {
        String? teacherId = prefs.getString('teacher_id');
        if (teacherId == null || teacherId.isEmpty) {
          teacherId = 'me';
        }
        response = await ApiService.instance.get('timetable/teacher/$teacherId');
      }

      if (response != null && response['success'] == true) {
        final rawSchedule = response['schedule'] as List<dynamic>? ?? [];
        final Map<int, String> weekdayToName = {
          1: 'Mon',
          2: 'Tue',
          3: 'Wed',
          4: 'Thu',
          5: 'Fri',
          6: 'Sat',
          7: 'Sun',
        };

        _allEntries = rawSchedule.map((slot) {
          final sMap = slot as Map<String, dynamic>;
          final teacherObj = sMap['teacher'] as Map<String, dynamic>?;
          final userObj = teacherObj?['user'] as Map<String, dynamic>?;
          String resolvedTeacherName = 'Class Teacher';
          if (userObj != null) {
            resolvedTeacherName = '${userObj['firstName'] ?? ''} ${userObj['lastName'] ?? ''}'.trim();
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
      } else {
        throw Exception(response?['message'] ?? 'Failed to load timetable response');
      }

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
      return entry['day_of_week'].toString().toLowerCase() == _selectedDay.toLowerCase();
    }).toList();

    _filteredEntries.sort((a, b) {
      final aTime = a['start_time'].toString();
      final bTime = b['start_time'].toString();
      return aTime.compareTo(bTime);
    });
  }

  bool _isCurrentPeriod(String dayOfWeek, String startTimeStr, String endTimeStr) {
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
                style: GoogleFonts.inter(
                  fontSize: 13.sp,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textMedium,
                ),
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
                  style: GoogleFonts.inter(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  endTime,
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMedium,
                  ),
                ),
                SizedBox(height: 6.h),
                if (isNow)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: widget.theme.primary,
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      'NOW',
                      style: GoogleFonts.inter(
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: 16.w),
            // Divider line
            Container(
              height: 60.h,
              width: 1.w,
              color: isNow ? widget.theme.primary.withValues(alpha: 0.3) : AppColors.border,
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
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: widget.theme.light,
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          subjectCode.isNotEmpty ? subjectCode : 'CORE',
                          style: GoogleFonts.inter(
                            fontSize: 8.sp,
                            fontWeight: FontWeight.w900,
                            color: widget.theme.primary,
                          ),
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
                            style: GoogleFonts.inter(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMedium,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    subjectName,
                    style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
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
                          style: GoogleFonts.inter(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMedium,
                          ),
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
            style: GoogleFonts.inter(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Enjoy your study leave or personal project hours. Keep learning!',
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.textMedium,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isPushed = Navigator.canPop(context);
    final bool isTeacher = widget.role == 'teacher';

    return Scaffold(
      key: _scaffoldKey,
      drawer: (isPushed && isTeacher) ? const EduSphereDrawer(role: 'teacher', activeLabel: 'My Schedule') : null,
      bottomNavigationBar: (isPushed && isTeacher) ? const TeacherBottomNavBar(activeIndex: 10) : null,
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
      body: Column(
        children: [
          PageHeader(
            title: 'Class Schedule',
            subtitle: widget.role == 'student' 
                ? 'Your weekly timetable lectures'
                : 'Your active classes & slots',
            theme: widget.theme,
            showBackButton: widget.showAppBar,
          ),
          _buildDaySelector(),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: widget.theme.primary,
                      strokeWidth: 3.w,
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadTimetableData,
                    color: widget.theme.primary,
                    child: _filteredEntries.isEmpty
                        ? SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.all(16.r),
                            child: _buildEmptyState(),
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
      ),
    );
  }
}
