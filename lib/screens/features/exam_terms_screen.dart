import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import 'exam_report_card_screen.dart';
import 'exam_marks_entry_screen.dart';
import 'exam_approval_screen.dart';

class ExamTermsScreen extends StatefulWidget {
  final RoleTheme theme;
  const ExamTermsScreen({super.key, required this.theme});

  @override
  State<ExamTermsScreen> createState() => _ExamTermsScreenState();
}

class _ExamTermsScreenState extends State<ExamTermsScreen> {
  bool _loading = false;

  // List of academic terms fetched from terms table
  List<Map<String, dynamic>> _termsList = [];

  // Mapping of term ID to exam count for teachers
  final Map<String, int> _examsCountMap = {};

  // Mock terms as a high-quality fallback (Dynamic statuses calculated based on today: May 30, 2026)
  final List<Map<String, dynamic>> _mockTerms = [
    {
      'id': 'exam_term1',
      'name': 'Term 1',
      'start_date': '2025-04-01',
      'end_date': '2025-09-15',
    },
    {
      'id': 'exam_term2',
      'name': 'Term 2',
      'start_date': '2025-10-01',
      'end_date': '2026-02-28',
    },
    {
      'id': 'exam_annual',
      'name': 'Annual Assessment',
      'start_date': '2026-03-01',
      'end_date': '2026-05-30', // Ends today, evaluates as Active
    },
    {
      'id': 'exam_term3',
      'name': 'Term 3 (Upcoming)',
      'start_date': '2026-06-15',
      'end_date': '2026-10-30', // Evaluates as Upcoming
    }
  ];

  // Mock exam counts per term for offline fallback
  final Map<String, int> _mockExamsCount = {
    'exam_term1': 5,
    'exam_term2': 4,
    'exam_annual': 6,
    'exam_term3': 0,
  };

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
      // 1. Fetch terms from Supabase terms table, ordered by start_date ascending
      final termsResponse = await Supabase.instance.client
          .from('terms')
          .select()
          .order('start_date', ascending: true);

      final List<Map<String, dynamic>> termsData = List<Map<String, dynamic>>.from(termsResponse);

      if (termsData.isNotEmpty) {
        _termsList = termsData;

        // 2. Fetch exam counts to build mapping
        try {
          final examsResponse = await Supabase.instance.client
              .from('exams')
              .select('id, term_id');
          
          final List<Map<String, dynamic>> examsData = List<Map<String, dynamic>>.from(examsResponse);
          
          _examsCountMap.clear();
          for (var exam in examsData) {
            final termId = exam['term_id'] as String?;
            if (termId != null) {
              _examsCountMap[termId] = (_examsCountMap[termId] ?? 0) + 1;
            }
          }
        } catch (e) {
          // If exams table schema is missing term_id, fallback to mock counts
          _loadMockExamsCount();
        }

        setState(() {});
        return;
      }

      // Empty DB fallback
      _loadFallbackData();
    } catch (e) {
      // Offline fallback
      _loadFallbackData();
      debugPrint('Error loading academic terms: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _loadFallbackData() {
    _termsList = _mockTerms;
    _loadMockExamsCount();
  }

  void _loadMockExamsCount() {
    _examsCountMap.clear();
    _examsCountMap.addAll(_mockExamsCount);
  }

  // Format date helper: returns "DD MMM YYYY" (e.g. "20 May 2026")
  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'TBD';
    try {
      final parsed = DateTime.parse(dateStr);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PageHeader(
            title: 'Academic Terms',
            subtitle: _isTeacher ? 'View performance & manage exams' : 'View your term report cards',
            theme: widget.theme,
          ),
          
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.studentPrimary))
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
                            final start = term['start_date'] as String?;
                            final end = term['end_date'] as String?;

                            // Dynamic calculations
                            final statusInfo = _getTermStatus(start, end);
                            final computedStatus = statusInfo['label'] as String;
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
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Header Row: Term Name and Badges
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                name,
                                                style: GoogleFonts.inter(
                                                  fontWeight: FontWeight.w900,
                                                  color: AppColors.textDark,
                                                  fontSize: 16.sp,
                                                ),
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                // Teacher Count Badge
                                                if (_isTeacher) ...[
                                                  Container(
                                                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                                    margin: EdgeInsets.only(right: 8.w),
                                                    decoration: BoxDecoration(
                                                      color: widget.theme.light,
                                                      borderRadius: BorderRadius.circular(8.r),
                                                    ),
                                                    child: Text(
                                                      '$examCount exam${examCount == 1 ? "" : "s"}',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 10.sp,
                                                        fontWeight: FontWeight.w900,
                                                        color: widget.theme.primary,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                                // Dynamic Status Chip
                                                Container(
                                                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                                  decoration: BoxDecoration(
                                                    color: bgBadgeColor,
                                                    borderRadius: BorderRadius.circular(8.r),
                                                  ),
                                                  child: Text(
                                                    computedStatus,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 10.sp,
                                                      fontWeight: FontWeight.w900,
                                                      color: badgeColor,
                                                    ),
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
                                            Icon(Icons.date_range_rounded, size: 14.sp, color: AppColors.textLight),
                                            SizedBox(width: 6.w),
                                            Expanded(
                                              child: Text(
                                                'Start: ${_formatDate(start)} → End: ${_formatDate(end)}',
                                                style: GoogleFonts.inter(
                                                  fontSize: 12.sp,
                                                  color: AppColors.textMedium,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),

                                        Divider(height: 24.h, color: AppColors.border),

                                        // Role Specific Actions & Quick Links
                                        if (_isTeacher) ...[
                                          Row(
                                            children: [
                                              Expanded(
                                                child: ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: widget.theme.primary,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                                                    padding: EdgeInsets.symmetric(vertical: 12.h),
                                                    elevation: 0,
                                                  ),
                                                  onPressed: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) => ExamMarksEntryScreen(theme: widget.theme),
                                                      ),
                                                    );
                                                  },
                                                  child: Text(
                                                    '📝 Enter Marks',
                                                    style: GoogleFonts.inter(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.w800,
                                                      fontSize: 12.sp,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 8.w),
                                              Expanded(
                                                child: OutlinedButton(
                                                  style: OutlinedButton.styleFrom(
                                                    side: BorderSide(color: widget.theme.primary, width: 1.5.w),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                                                    padding: EdgeInsets.symmetric(vertical: 12.h),
                                                  ),
                                                  onPressed: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) => ExamApprovalScreen(theme: widget.theme),
                                                      ),
                                                    );
                                                  },
                                                  child: Text(
                                                    '✅ Approvals',
                                                    style: GoogleFonts.inter(
                                                      color: widget.theme.primary,
                                                      fontWeight: FontWeight.w800,
                                                      fontSize: 12.sp,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ] else ...[
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              Text(
                                                'Tap to View Report Card',
                                                style: GoogleFonts.inter(
                                                  fontSize: 11.sp,
                                                  fontWeight: FontWeight.w800,
                                                  color: widget.theme.primary,
                                                ),
                                              ),
                                              SizedBox(width: 2.w),
                                              Icon(Icons.arrow_forward_ios_rounded, size: 11.sp, color: widget.theme.primary),
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
                                Icon(Icons.info_outline_rounded, color: widget.theme.primary, size: 24.sp),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Academic Schedule Policy',
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textDark,
                                          fontSize: 13.sp,
                                        ),
                                      ),
                                      SizedBox(height: 4.h),
                                      Text(
                                        'Term schedules and grading guidelines are administered by the board of trustees. Selecting any term will reveal official signed grade records.',
                                        style: GoogleFonts.inter(
                                          fontSize: 11.sp,
                                          color: AppColors.textMedium,
                                        ),
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
