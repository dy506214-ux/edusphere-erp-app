import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  int pendingCount = 0;
  double attendanceRate = 75.0;
  String studentName = 'Student';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
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
          '';
      if (savedEmail.isEmpty) {
        if (mounted) setState(() {});
        return;
      }

      final studentRes = await Supabase.instance.client
          .from('students')
          .select()
          .eq('email', savedEmail)
          .maybeSingle();

      if (studentRes != null && mounted) {
        final studentId = studentRes['id'] as String;
        final className = studentRes['class_name'] as String? ?? 'Grade 12';
        final section = studentRes['section'] as String? ?? 'A';

        // Attendance
        final attendanceRes = await Supabase.instance.client
            .from('attendance')
            .select()
            .eq('student_id', studentId);

        if (attendanceRes.isNotEmpty) {
          int present = 0;
          for (var r in attendanceRes) {
            final s = r['status'] as String? ?? '';
            if (s == 'P' || s == 'Present' || s == 'L' || s == 'Late') {
              present++;
            }
          }
          if (mounted) {
            setState(
                () => attendanceRate = (present / attendanceRes.length) * 100);
          }
        }

        // Pending assignments
        final assignmentsRes = await Supabase.instance.client
            .from('assignments')
            .select()
            .eq('class_name', className)
            .eq('section', section);

        final submissionsRes = await Supabase.instance.client
            .from('submissions')
            .select()
            .eq('student_id', studentId);

        final pending = assignmentsRes.length - submissionsRes.length;
        if (mounted) {
          setState(() => pendingCount = pending < 0 ? 0 : pending);
        }
      }
    } catch (_) {}

    if (mounted) setState(() {});
  }

  void _push(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen))
          .then((_) => _loadData());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: widget.theme.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 16.h),
                    _buildWelcomeBanner(),
                    SizedBox(height: 20.h),
                    _buildQuickAccess(),
                    SizedBox(height: 20.h),
                    _buildHubBanner(),
                    SizedBox(height: 20.h),
                    _buildOverview(),
                    SizedBox(height: 20.h),
                    _buildComingUpNext(),
                    SizedBox(height: 28.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final canPop = Navigator.canPop(context);
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
          child: Row(
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
                    width: 40.w, height: 40.w,
                    margin: EdgeInsets.only(right: 12.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textDark, size: 18.sp),
                  ),
                ),
              ] else ...[
                Text('🎓', style: TextStyle(fontSize: 22.sp)),
                SizedBox(width: 8.w),
              ],
              Text(
                'ACADEMIC',
                style: GoogleFonts.inter(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {},
                child: Container(
                  width: 40.w,
                  height: 40.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(Icons.notifications_outlined,
                            color: AppColors.textDark, size: 22.sp),
                      ),
                      Positioned(
                        top: 8.h,
                        right: 8.w,
                        child: Container(
                          width: 8.w,
                          height: 8.w,
                          decoration: const BoxDecoration(
                              color: Colors.red, shape: BoxShape.circle),
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

  // ── Welcome banner ──────────────────────────────────────────────────────────
  Widget _buildWelcomeBanner() {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEEF2FF), Color(0xFFDDE1FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22.r),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good to see you,',
                  style: GoogleFonts.inter(
                      fontSize: 13.sp, color: const Color(0xFF6366F1)),
                ),
                SizedBox(height: 6.h),
                Text(
                  'Keep learning,\nkeep growing! 🌱',
                  style: GoogleFonts.inter(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 72.w,
            height: 72.w,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.school_rounded,
                size: 40.sp, color: const Color(0xFF6366F1)),
          ),
        ],
      ),
    );
  }

  // ── Quick Access ────────────────────────────────────────────────────────────
  Widget _buildQuickAccess() {
    final items = [
      {
        'label': 'My\nSchedule',
        'icon': Icons.calendar_today_rounded,
        'color': const Color(0xFF3B82F6),
        'screen': ScheduleScreen(theme: widget.theme, role: 'student'),
      },
      {
        'label': 'Study\nMaterials',
        'icon': Icons.menu_book_rounded,
        'color': const Color(0xFF6366F1),
        'screen': const StudyMaterialsScreen(),
      },
      {
        'label': 'Assignments',
        'icon': Icons.assignment_rounded,
        'color': const Color(0xFFF97316),
        'screen': const AssignmentsScreen(),
      },
      {
        'label': 'Quiz &\nAssessments',
        'icon': Icons.psychology_rounded,
        'color': const Color(0xFFEC4899),
        'screen': const QuizScreen(),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Quick Access',
              style: GoogleFonts.inter(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark),
            ),
            GestureDetector(
              onTap: () => _push(AcademicFeaturesScreen(
                theme: widget.theme,
                pendingCount: pendingCount,
                attendanceRate: attendanceRate,
              )),
              child: Text(
                'View All',
                style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: widget.theme.primary),
              ),
            ),
          ],
        ),
        SizedBox(height: 14.h),
        Row(
          children: items.map((item) {
            return Expanded(
              child: GestureDetector(
                onTap: () => _push(item['screen'] as Widget),
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 4.w),
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18.r),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8.r)
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 44.w,
                        height: 44.w,
                        decoration: BoxDecoration(
                          color: item['color'] as Color,
                          borderRadius: BorderRadius.circular(14.r),
                          boxShadow: [
                            BoxShadow(
                              color: (item['color'] as Color)
                                  .withValues(alpha: 0.3),
                              blurRadius: 8.r,
                              offset: Offset(0, 3.h),
                            )
                          ],
                        ),
                        child: Icon(item['icon'] as IconData,
                            color: Colors.white, size: 22.sp),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        item['label'] as String,
                        style: GoogleFonts.inter(
                            fontSize: 9.5.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMedium),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Hub Banner ──────────────────────────────────────────────────────────────
  Widget _buildHubBanner() {
    return GestureDetector(
      onTap: () => _push(AcademicFeaturesScreen(
        theme: widget.theme,
        pendingCount: pendingCount,
        attendanceRate: attendanceRate,
      )),
      child: Container(
        padding: EdgeInsets.all(20.r),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E293B), Color(0xFF2D3F5C)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(22.r),
        ),
        child: Row(
          children: [
            Container(
              width: 50.w,
              height: 50.w,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Icon(Icons.school_rounded,
                  color: Colors.white, size: 28.sp),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Academic Hub',
                    style: GoogleFonts.inter(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w900,
                        color: Colors.white),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Everything you need for your success',
                    style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        color: Colors.white.withValues(alpha: 0.65),
                        height: 1.4),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white.withValues(alpha: 0.7), size: 16.sp),
          ],
        ),
      ),
    );
  }

  // ── Overview Grid ────────────────────────────────────────────────────────────
  Widget _buildOverview() {
    final items = [
      {
        'icon': Icons.menu_book_rounded,
        'color': const Color(0xFF6366F1),
        'label': 'Study Materials',
        'val': '24',
        'sub': 'New materials',
      },
      {
        'icon': Icons.assignment_rounded,
        'color': const Color(0xFFF97316),
        'label': 'Assignments',
        'val': pendingCount.toString(),
        'sub': 'Pending',
      },
      {
        'icon': Icons.psychology_rounded,
        'color': const Color(0xFFEC4899),
        'label': 'Quizzes',
        'val': '0',
        'sub': 'Upcoming',
      },
      {
        'icon': Icons.trending_up_rounded,
        'color': const Color(0xFF10B981),
        'label': 'Performance',
        'val': 'Good',
        'sub': 'Keep it up!',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: GoogleFonts.inter(
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark),
        ),
        SizedBox(height: 14.h),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12.w,
          mainAxisSpacing: 12.h,
          childAspectRatio: 1.55,
          children: items.map((item) {
            return Container(
              padding: EdgeInsets.all(14.r),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18.r),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8.r)
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 36.w,
                    height: 36.w,
                    decoration: BoxDecoration(
                      color:
                          (item['color'] as Color).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Icon(item['icon'] as IconData,
                        color: item['color'] as Color, size: 18.sp),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          item['label'] as String,
                          style: GoogleFonts.inter(
                              fontSize: 9.sp,
                              color: AppColors.textLight,
                              fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            item['val'] as String,
                            style: GoogleFonts.inter(
                                fontSize: 20.sp,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textDark),
                          ),
                        ),
                        Text(
                          item['sub'] as String,
                          style: GoogleFonts.inter(
                              fontSize: 9.sp, color: AppColors.textLight),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Coming Up Next ───────────────────────────────────────────────────────────
  Widget _buildComingUpNext() {
    return GestureDetector(
      onTap: () =>
          _push(const ExamScheduleScreen()),
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8.r)
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46.w,
              height: 46.w,
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Icon(Icons.event_rounded,
                  color: const Color(0xFF10B981), size: 24.sp),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Coming Up Next',
                    style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textLight),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Finals: June 10 - 20',
                    style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark),
                  ),
                  Text(
                    'Stay focused and do your best!',
                    style: GoogleFonts.inter(
                        fontSize: 11.sp, color: AppColors.textLight),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.textLight, size: 22.sp),
          ],
        ),
      ),
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
