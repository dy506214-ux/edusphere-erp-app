import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart' as intl;
import '../theme/colors.dart';
import 'features/schedule_screen.dart';
import 'features/study_materials_screen.dart';
import 'features/assignments_screen.dart';
import 'features/quiz_screen.dart';
import 'features/exam_schedule_screen.dart';
import 'features/results_screen.dart';
import 'features/exam_terms_screen.dart';
import 'features/exam_report_card_screen.dart';
import 'features/attendance_screen.dart';
import 'features/academic_calendar_screen.dart';

// ── Academic Hub Screen (main tab) ───────────────────────────────────────────
class AcademicScreen extends StatefulWidget {
  final RoleTheme theme;
  final VoidCallback? onBack;
  const AcademicScreen({super.key, required this.theme, this.onBack});

  @override
  State<AcademicScreen> createState() => _AcademicScreenState();
}

class _AcademicScreenState extends State<AcademicScreen> {
  bool _isLoading = true;
  double attendanceRate = 0.0;
  String studentName = 'Student';
  String _className = 'Class 1';
  String _section = 'A';
  final List<Map<String, dynamic>> _attendanceHistory = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() { _isLoading = true; });

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      studentName = prefs.getString('student_name') ??
          prefs.getString('user_name') ??
          'Student';
    });

    try {
      final savedEmail = prefs.getString('student_email') ??
          prefs.getString('user_email') ??
          'alex.rivera@edusmart.edu';

      final studentRes = await Supabase.instance.client
          .from('students')
          .select()
          .eq('email', savedEmail)
          .maybeSingle();

      if (studentRes != null) {
        final studentId = studentRes['id'] as String;
        final className = studentRes['class_name'] as String? ?? 'Grade 12';
        final section = studentRes['section'] as String? ?? 'A';

        if (mounted) {
          setState(() {
            _className = className;
            _section = section;
          });
        }

        // Attendance rate
        final attendanceRes = await Supabase.instance.client
            .from('attendance')
            .select()
            .eq('student_id', studentId);

        double rate = 0.0;
        if (attendanceRes.isNotEmpty) {
          int present = 0;
          for (var r in attendanceRes) {
            final s = r['status'] as String? ?? '';
            if (s == 'P' || s == 'Present' || s == 'L' || s == 'Late' || s == 'Leave') {
              present++;
            }
          }
          rate = (present / attendanceRes.length) * 100;
        }

        // Fetch recent attendance records for Attendance History
        final List<dynamic> attendanceHistoryRes = await Supabase.instance.client
            .from('attendance')
            .select()
            .eq('student_id', studentId)
            .order('date', ascending: false)
            .limit(5);

        final List<Map<String, dynamic>> tempHistory = [];
        for (var att in attendanceHistoryRes) {
          final rawDate = att['date'] as String;
          final status = att['status'] as String? ?? 'Present';
          
          DateTime? date;
          try {
            date = DateTime.parse(rawDate);
          } catch (_) {}

          String formattedDate = rawDate;
          if (date != null) {
            formattedDate = intl.DateFormat('MMMM d, yyyy').format(date);
          }

          tempHistory.add({
            'date': formattedDate,
            'status': status,
          });
        }

        if (mounted) {
          setState(() {
            attendanceRate = rate;
            _attendanceHistory.clear();
            _attendanceHistory.addAll(tempHistory);
          });
        }
      }
    } catch (e) {
      dev.log('Error loading academic data: $e');
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Custom clean header matching React Client style
            Padding(
              padding: EdgeInsets.fromLTRB(24.r, 24.r, 24.r, 8.r),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (canPop || widget.onBack != null) ...[
                        GestureDetector(
                          onTap: () {
                            if (canPop) {
                              Navigator.pop(context);
                            } else if (widget.onBack != null) {
                              widget.onBack!();
                            }
                          },
                          child: Container(
                            width: 40.w,
                            height: 40.w,
                            margin: EdgeInsets.only(right: 12.w),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Icon(Icons.arrow_back_ios_new_rounded,
                                size: 18.sp, color: AppColors.textDark),
                          ),
                        ),
                      ],
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Academic Overview',
                            style: GoogleFonts.inter(
                              fontSize: 26.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'Manage your academic journey',
                            style: GoogleFonts.inter(
                              fontSize: 14.sp,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  _buildRefreshButton(),
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.studentPrimary))
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      color: widget.theme.primary,
                      child: ListView(
                        padding: EdgeInsets.all(24.r),
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          if (isDesktop) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: _buildCurrentSubjectsCard(),
                                ),
                                SizedBox(width: 24.w),
                                Expanded(
                                  flex: 2,
                                  child: _buildTimetablesCard(),
                                ),
                              ],
                            ),
                          ] else ...[
                            _buildCurrentSubjectsCard(),
                            SizedBox(height: 24.h),
                            _buildTimetablesCard(),
                          ],
                          SizedBox(height: 24.h),
                          _buildAcademicStatusCard(),
                          SizedBox(height: 24.h),
                          _buildAttendanceHistoryCard(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRefreshButton() {
    return TextButton.icon(
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
        backgroundColor: Colors.white,
      ),
      onPressed: _loadData,
      icon: Icon(Icons.refresh_rounded, size: 16.sp, color: const Color(0xFF0F172A)),
      label: Text(
        'Refresh',
        style: GoogleFonts.inter(
          fontSize: 13.sp,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF0F172A),
        ),
      ),
    );
  }

  Widget _buildCurrentSubjectsCard() {
    final hasSubjects = _className.contains('12');
    return Container(
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 16.r,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book_outlined, color: widget.theme.primary, size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                'Current Subjects',
                style: GoogleFonts.inter(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            'Subjects assigned to your class',
            style: GoogleFonts.inter(
                fontSize: 12.sp, color: AppColors.textMedium),
          ),
          SizedBox(height: 16.h),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(3),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(2),
            },
            children: [
              TableRow(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
                ),
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    child: Text('Subject', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppColors.textMedium)),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    child: Text('Code', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppColors.textMedium)),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    child: Text('Type', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppColors.textMedium)),
                  ),
                ],
              ),
              if (hasSubjects) ...[
                _subjectRow('Mathematics', 'MATH12', 'Core'),
                _subjectRow('Physics', 'PHYS12', 'Core'),
                _subjectRow('Chemistry', 'CHEM12', 'Core'),
                _subjectRow('English', 'ENGL12', 'Language'),
              ],
            ],
          ),
          if (!hasSubjects)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 36.h),
              child: Center(
                child: Text(
                  'No subjects listed',
                  style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textMedium),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimetablesCard() {
    return Container(
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 16.r,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.access_time_rounded, color: widget.theme.primary, size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                'Timetables',
                style: GoogleFonts.inter(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            'Recent class schedules',
            style: GoogleFonts.inter(
                fontSize: 12.sp, color: AppColors.textMedium),
          ),
          SizedBox(height: 16.h),
          CustomPaint(
            painter: DashedRectPainter(
              color: const Color(0xFFCBD5E1),
              radius: 12.r,
            ),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 36.h),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'No timetables uploaded yet',
                    style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textMedium,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcademicStatusCard() {
    return Container(
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 16.r,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_outlined, color: widget.theme.primary, size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                'Academic Status',
                style: GoogleFonts.inter(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 12.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.school_outlined, color: const Color(0xFF64748B), size: 24.sp),
                      SizedBox(height: 10.h),
                      Text(
                        'Target Class',
                        style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: AppColors.textMedium),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '$_className ($_section)',
                        style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w800, color: widget.theme.primary),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 12.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.check_circle_outline_rounded, color: const Color(0xFF64748B), size: 24.sp),
                      SizedBox(height: 10.h),
                      Text(
                        'Attendance Progress',
                        style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: AppColors.textMedium),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        _isLoading ? 'Loading...' : '${attendanceRate.toStringAsFixed(0)}%',
                        style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w800, color: const Color(0xFF15803D)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceHistoryCard() {
    return Container(
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 16.r,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_toggle_off_rounded, color: widget.theme.primary, size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                'Attendance History',
                style: GoogleFonts.inter(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            'Recent attendance records',
            style: GoogleFonts.inter(
                fontSize: 12.sp, color: AppColors.textMedium),
          ),
          SizedBox(height: 16.h),
          if (_attendanceHistory.isEmpty)
            CustomPaint(
              painter: DashedRectPainter(
                color: const Color(0xFFCBD5E1),
                radius: 12.r,
              ),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 36.h),
                child: Column(
                  children: [
                    Icon(Icons.history_rounded, color: const Color(0xFFCBD5E1), size: 32.sp),
                    SizedBox(height: 8.h),
                    Text(
                      'No attendance records found',
                      style: GoogleFonts.inter(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textMedium,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _attendanceHistory.length,
              separatorBuilder: (_, __) => const Divider(height: 16, color: AppColors.border),
              itemBuilder: (_, index) {
                final r = _attendanceHistory[index];
                final status = r['status'] as String;
                final bool isPresent = status == 'Present' || status == 'P';
                
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      r['date'] as String,
                      style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w600, color: AppColors.textDark),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: isPresent ? const Color(0xFFDCFCE7) : const Color(0xFFFFE4E6),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Text(
                        status,
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          color: isPresent ? const Color(0xFF15803D) : const Color(0xFFE11D48),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  TableRow _subjectRow(String sub, String code, String type) {
    return TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
      ),
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          child: Text(sub, style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w500, color: AppColors.textDark)),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          child: Text(code, style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w500, color: AppColors.textMedium)),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          child: Text(type, style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w500, color: AppColors.textMedium)),
        ),
      ],
    );
  }
}

// ── All Academic Features Screen ──────────────────────────────────────────────
class AcademicFeaturesScreen extends StatelessWidget {
  final RoleTheme theme;
  final int pendingCount;
  final double attendanceRate;

  const AcademicFeaturesScreen({
    super.key,
    required this.theme,
    this.pendingCount = 0,
    this.attendanceRate = 75.0,
  });

  @override
  Widget build(BuildContext context) {
    final features = [
      {
        'title': 'My Schedule',
        'desc': "Today's classes",
        'icon': Icons.calendar_today_rounded,
        'color': const Color(0xFF3B82F6),
        'screen': ScheduleScreen(theme: theme, role: 'student'),
      },
      {
        'title': 'Study Materials',
        'desc': '24 new PDFs available',
        'icon': Icons.menu_book_rounded,
        'color': const Color(0xFF6366F1),
        'screen': const StudyMaterialsScreen(),
      },
      {
        'title': 'Assignments',
        'desc': '$pendingCount pending task${pendingCount == 1 ? "" : "s"}',
        'icon': Icons.assignment_rounded,
        'color': const Color(0xFFF97316),
        'screen': const AssignmentsScreen(),
      },
      {
        'title': 'Quiz & Assessments',
        'desc': 'Practice quizzes & exams',
        'icon': Icons.psychology_rounded,
        'color': const Color(0xFFEC4899),
        'screen': const QuizScreen(),
      },
      {
        'title': 'Exam Schedule',
        'desc': 'Finals: June 10-20',
        'icon': Icons.assignment_outlined,
        'color': const Color(0xFFF59E0B),
        'screen': const ExamScheduleScreen(),
      },
      {
        'title': 'Results & Grade Card',
        'desc': 'Latest: Physics 85/100',
        'icon': Icons.emoji_events_rounded,
        'color': const Color(0xFF8B5CF6),
        'screen': const ResultsScreen(),
      },
      {
        'title': 'Exam Terms',
        'desc': 'Term wise guidelines',
        'icon': Icons.calendar_month_rounded,
        'color': const Color(0xFF7C3AED),
        'screen': ExamTermsScreen(theme: theme),
      },
      {
        'title': 'Official Report Card',
        'desc': 'Download official PDF',
        'icon': Icons.school_rounded,
        'color': const Color(0xFFEC4899),
        'screen': ExamReportCardScreen(theme: theme),
      },
      {
        'title': 'Attendance & Leave',
        'desc': '${attendanceRate.toStringAsFixed(0)}% this month',
        'icon': Icons.check_circle_rounded,
        'color': const Color(0xFF10B981),
        'screen': const AttendanceScreen(),
      },
      {
        'title': 'Academic Calendar',
        'desc': 'Upcoming events & dates',
        'icon': Icons.event_rounded,
        'color': const Color(0xFF0EA5E9),
        'screen': const AcademicCalendarScreen(),
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context)),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) =>
                    _buildFeatureTile(context, features[index]),
                childCount: features.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40.w,
                      height: 40.w,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 18.sp, color: AppColors.textDark),
                    ),
                  ),
                  SizedBox(width: 14.w),
                  Text(
                    'Academic',
                    style: GoogleFonts.inter(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textDark),
                  ),
                ],
              ),
            ),
            // Hub banner
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
              child: Container(
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEEF2FF), Color(0xFFDDE1FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18.r),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Academic Hub',
                            style: GoogleFonts.inter(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textDark),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'All your study tools\nin one place',
                            style: GoogleFonts.inter(
                                fontSize: 12.sp,
                                color: AppColors.textMedium,
                                height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 62.w,
                      height: 62.w,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      child: Icon(Icons.menu_book_rounded,
                          size: 34.sp, color: const Color(0xFF6366F1)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureTile(
      BuildContext context, Map<String, dynamic> feature) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => feature['screen'] as Widget),
      ),
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8.r,
                offset: Offset(0, 2.h))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48.w,
              height: 48.w,
              decoration: BoxDecoration(
                color: feature['color'] as Color,
                borderRadius: BorderRadius.circular(14.r),
                boxShadow: [
                  BoxShadow(
                    color:
                        (feature['color'] as Color).withValues(alpha: 0.3),
                    blurRadius: 8.r,
                    offset: Offset(0, 3.h),
                  )
                ],
              ),
              child: Icon(feature['icon'] as IconData,
                  color: Colors.white, size: 24.sp),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feature['title'] as String,
                    style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    feature['desc'] as String,
                    style: GoogleFonts.inter(
                        fontSize: 12.sp, color: AppColors.textMedium),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.textLight, size: 20.sp),
          ],
        ),
      ),
    );
  }
}

class DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double dashLength;
  final double radius;

  DashedRectPainter({
    this.color = const Color(0xFFCBD5E1),
    this.strokeWidth = 1.0,
    this.gap = 4.0,
    this.dashLength = 6.0,
    this.radius = 12.0,
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
        Radius.circular(radius),
      ));

    final dashPath = Path();
    double distance = 0.0;
    for (final pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        final len = dashLength;
        final nextDistance = distance + len;
        final isLast = nextDistance >= pathMetric.length;
        
        dashPath.addPath(
          pathMetric.extractPath(distance, isLast ? pathMetric.length : nextDistance),
          Offset.zero,
        );
        
        distance = nextDistance + gap;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(DashedRectPainter oldDelegate) => false;
}
