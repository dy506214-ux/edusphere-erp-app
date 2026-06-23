import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import 'exam_report_card_screen.dart';
import 'exam_approval_screen.dart';
import '../main_screen.dart';
import '../../widgets/teacher_app_bar.dart';
import 'package:edusphere/theme/typography.dart';

class ExamTermsScreen extends StatefulWidget {
  final RoleTheme theme;
  const ExamTermsScreen({super.key, required this.theme});

  @override
  State<ExamTermsScreen> createState() => _ExamTermsScreenState();
}

class _ExamTermsScreenState extends State<ExamTermsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _loading = false;

  // List of academic terms fetched from terms table
  List<Map<String, dynamic>> _termsList = [];

  // Mapping of term ID to exam count for teachers
  final Map<String, int> _examsCountMap = {};

  @override
  void initState() {
    super.initState();
    _loadTermsAndExams();
  }

  bool get _isTeacher => widget.theme.label.toLowerCase() == 'teacher';

  Future<void> _loadTermsAndExams() async {
    setState(() {
      _loading = true;
    });

    try {
      // 1. Fetch terms from Supabase Term table, ordered by startDate ascending
      final termsResponse = await Supabase.instance.client
          .from('Term')
          .select()
          .order('startDate', ascending: true);

      final List<Map<String, dynamic>> termsData =
          List<Map<String, dynamic>>.from(termsResponse);

      _termsList = termsData;

      // 2. Fetch exam counts to build mapping from Exam table
      try {
        final examsResponse =
            await Supabase.instance.client.from('Exam').select('id, termId');

        final List<Map<String, dynamic>> examsData =
            List<Map<String, dynamic>>.from(examsResponse);

        _examsCountMap.clear();
        for (var exam in examsData) {
          final termId = exam['termId'] as String?;
          if (termId != null) {
            _examsCountMap[termId] = (_examsCountMap[termId] ?? 0) + 1;
          }
        }
      } catch (e) {
        debugPrint('Error loading exam counts: $e');
        _examsCountMap.clear();
      }

      setState(() {});
    } catch (e) {
      _termsList = [];
      _examsCountMap.clear();
      debugPrint('Error loading academic terms: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // Format date helper: returns "DD MMM YYYY" (e.g. "20 May 2026")
  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'TBD';
    try {
      final parsed = DateTime.parse(dateStr);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      final day = parsed.day.toString().padLeft(2, '0');
      final month = months[parsed.month - 1];
      final year = parsed.year;
      return '$day $month $year';
    } catch (e) {
      return dateStr;
    }
  }

  // Dynamic status evaluation: returns status string, text color, and background color
  Map<String, dynamic> _getTermStatus(String? startStr, String? endStr) {
    if (startStr == null || endStr == null) {
      return {
        'label': 'Upcoming',
        'textColor': const Color(0xFF2563EB),
        'bgColor': const Color(0xFFDBEAFE),
      };
    }

    try {
      final start = DateTime.parse(startStr);
      final end = DateTime.parse(endStr);
      final now = DateTime.now();

      // Normalize dates for clean day-by-day comparison
      final today = DateTime(now.year, now.month, now.day);
      final startDateOnly = DateTime(start.year, start.month, start.day);
      final endDateOnly = DateTime(end.year, end.month, end.day);

      if (today.isBefore(startDateOnly)) {
        return {
          'label': 'Upcoming',
          'textColor': const Color(0xFF2563EB),
          'bgColor': const Color(0xFFDBEAFE),
        };
      } else if (today.isAfter(endDateOnly)) {
        return {
          'label': 'Completed',
          'textColor': const Color(0xFF4B5563),
          'bgColor': const Color(0xFFF3F4F6),
        };
      } else {
        return {
          'label': 'Active',
          'textColor': const Color(0xFF16A34A),
          'bgColor': const Color(0xFFDCFCE7),
        };
      }
    } catch (e) {
      return {
        'label': 'Upcoming',
        'textColor': const Color(0xFF2563EB),
        'bgColor': const Color(0xFFDBEAFE),
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isPushed = Navigator.canPop(context);
    return Scaffold(
      key: _scaffoldKey,
      drawer: (isPushed && _isTeacher)
          ? const EduSphereDrawer(role: 'teacher', activeLabel: 'Academic')
          : null,
      backgroundColor: AppColors.background,
      appBar: _isTeacher ? const TeacherAppBar(title: 'Academic Terms') : null,
      bottomNavigationBar:
          _isTeacher ? const TeacherBottomNavBar(activeIndex: 7) : null,
      body: Column(
        children: [
          PageHeader(
            title: 'Academic Terms',
            subtitle: _isTeacher
                ? 'View performance & manage exams'
                : 'View your term report cards',
            theme: widget.theme,
            leading: (isPushed && _isTeacher)
                ? GestureDetector(
                    onTap: () => _scaffoldKey.currentState?.openDrawer(),
                    child: Container(
                      width: 40.w,
                      height: 40.w,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(Icons.menu, color: Colors.white, size: 20.sp),
                    ),
                  )
                : null,
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.studentPrimary))
                : RefreshIndicator(
                    onRefresh: _loadTermsAndExams,
                    color: widget.theme.primary,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(16.r),
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionTitle(title: 'School Calendar Terms'),
                          SizedBox(height: 12.h),

                          // Term cards list
                          ..._termsList.map((term) {
                            final termId = term['id'] as String;
                            final name = term['name'] as String;
                            final start = term['startDate'] as String?;
                            final end = term['endDate'] as String?;

                            // Dynamic calculations
                            final statusInfo = _getTermStatus(start, end);
                            final computedStatus =
                                statusInfo['label'] as String;
                            final badgeColor = statusInfo['textColor'] as Color;
                            final bgBadgeColor = statusInfo['bgColor'] as Color;
                            final examCount = _examsCountMap[termId] ?? 0;

                            return Container(
                              margin: EdgeInsets.only(bottom: 14.h),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(22.r),
                                border: Border.all(color: AppColors.border),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 10.r,
                                    offset: Offset(0, 4.h),
                                  )
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(22.r),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ExamReportCardScreen(
                                          theme: widget.theme,
                                          initialExamId: termId,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: EdgeInsets.all(18.r),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Header Row: Term Name and Badges
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                name,
                                                style: AppTypography.body
                                                    .copyWith(
                                                        color:
                                                            AppColors.textDark),
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                // Teacher Count Badge
                                                if (_isTeacher) ...[
                                                  Container(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                            horizontal: 10.w,
                                                            vertical: 4.h),
                                                    margin: EdgeInsets.only(
                                                        right: 8.w),
                                                    decoration: BoxDecoration(
                                                      color: widget.theme.light,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8.r),
                                                    ),
                                                    child: Text(
                                                      '$examCount exam${examCount == 1 ? "" : "s"}',
                                                      style: AppTypography
                                                          .caption
                                                          .copyWith(
                                                              color: widget
                                                                  .theme
                                                                  .primary),
                                                    ),
                                                  ),
                                                ],
                                                // Dynamic Status Chip
                                                Container(
                                                  padding: EdgeInsets.symmetric(
                                                      horizontal: 10.w,
                                                      vertical: 4.h),
                                                  decoration: BoxDecoration(
                                                    color: bgBadgeColor,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8.r),
                                                  ),
                                                  child: Text(
                                                    computedStatus,
                                                    style: AppTypography.caption
                                                        .copyWith(
                                                            color: badgeColor),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 12.h),

                                        // Dates formatted as: "Start: DD MMM YYYY → End: DD MMM YYYY"
                                        Row(
                                          children: [
                                            Icon(Icons.date_range_rounded,
                                                size: 14.sp,
                                                color: AppColors.textLight),
                                            SizedBox(width: 6.w),
                                            Expanded(
                                              child: Text(
                                                'Start: ${_formatDate(start)} → End: ${_formatDate(end)}',
                                                style: AppTypography.caption
                                                    .copyWith(
                                                        color: AppColors
                                                            .textMedium),
                                              ),
                                            ),
                                          ],
                                        ),

                                        Divider(
                                            height: 24.h,
                                            color: AppColors.border),

                                        // Role Specific Actions & Quick Links
                                        if (_isTeacher) ...[
                                          Row(
                                            children: [
                                              Expanded(
                                                child: OutlinedButton(
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                    side: BorderSide(
                                                        color: widget
                                                            .theme.primary,
                                                        width: 1.5.w),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12.r)),
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                            vertical: 12.h),
                                                  ),
                                                  onPressed: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) =>
                                                            ExamApprovalScreen(
                                                                theme: widget
                                                                    .theme),
                                                      ),
                                                    );
                                                  },
                                                  child: Text(
                                                    '✅ Approvals',
                                                    style: AppTypography.caption
                                                        .copyWith(
                                                            color: widget
                                                                .theme.primary),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ] else ...[
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              Text(
                                                'Tap to View Report Card',
                                                style: AppTypography.caption
                                                    .copyWith(
                                                        color: widget
                                                            .theme.primary),
                                              ),
                                              SizedBox(width: 2.w),
                                              Icon(
                                                  Icons
                                                      .arrow_forward_ios_rounded,
                                                  size: 11.sp,
                                                  color: widget.theme.primary),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),

                          SizedBox(height: 20.h),

                          // Policy informational card
                          Container(
                            padding: EdgeInsets.all(18.r),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20.r),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline_rounded,
                                    color: widget.theme.primary, size: 24.sp),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Academic Schedule Policy',
                                        style: AppTypography.caption.copyWith(
                                            color: AppColors.textDark),
                                      ),
                                      SizedBox(height: 4.h),
                                      Text(
                                        'Term schedules and grading guidelines are administered by the board of trustees. Selecting any term will reveal official signed grade records.',
                                        style: AppTypography.caption.copyWith(
                                            color: AppColors.textMedium),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
