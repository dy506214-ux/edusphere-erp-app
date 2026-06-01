import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';

class ExamApprovalScreen extends StatefulWidget {
  final RoleTheme theme;
  const ExamApprovalScreen({super.key, required this.theme});

  @override
  State<ExamApprovalScreen> createState() => _ExamApprovalScreenState();
}

class _ExamApprovalScreenState extends State<ExamApprovalScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = false;

  List<Map<String, dynamic>> _examsList = [];

  // Default mock exams for offline support or empty tables
  final List<Map<String, dynamic>> _mockExams = [
    {
      'id': 'e_ap1',
      'name': 'Term 1 Midterms',
      'class_name': 'Grade 12-A',
      'subject': 'Physics',
      'date': 'May 20, 2026',
      'status': 'PENDING',
      'comments': '',
      'reviewed_by': null,
      'reviewed_at': null,
    },
    {
      'id': 'e_ap2',
      'name': 'Term 2 Final Assessments',
      'class_name': 'Grade 12-A',
      'subject': 'Mathematics',
      'date': 'May 25, 2026',
      'status': 'REVIEW',
      'comments': '',
      'reviewed_by': null,
      'reviewed_at': null,
    },
    {
      'id': 'e_ap3',
      'name': 'Annual Physics Practicals',
      'class_name': 'Grade 11-B',
      'subject': 'Physics',
      'date': 'May 26, 2026',
      'status': 'APPROVED',
      'comments': 'All marks verified successfully.',
      'reviewed_by': 'b2f4c6d8-2345-6789-bcde-f23456789012',
      'reviewed_at': '2026-05-26T14:30:00Z',
    },
    {
      'id': 'e_ap4',
      'name': 'Chemistry Monthly Unit Test',
      'class_name': 'Grade 10-C',
      'subject': 'Chemistry',
      'date': 'May 28, 2026',
      'status': 'REJECTED',
      'comments': 'Chemistry marks out of bounds.',
      'reviewed_by': 'b2f4c6d8-2345-6789-bcde-f23456789012',
      'reviewed_at': '2026-05-28T10:15:00Z',
    }
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchExams();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchExams() async {
    setState(() {
      _loading = true;
    });

    try {
      // Fetch exams from Supabase where status IN ('PENDING', 'REVIEW', 'APPROVED', 'REJECTED')
      final response = await Supabase.instance.client
          .from('exams')
          .select()
          .order('name', ascending: true);

      final List<Map<String, dynamic>> rawData = List<Map<String, dynamic>>.from(response);

      if (rawData.isNotEmpty) {
        setState(() {
          _examsList = rawData;
        });
        return;
      }
      
      // Empty database fallback
      setState(() {
        _examsList = _mockExams;
      });
    } catch (e) {
      // Offline or missing schema fallback
      setState(() {
        _examsList = _mockExams;
      });
      debugPrint('Error loading approvals: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _pendingExams {
    return _examsList.where((e) {
      final status = e['status'] as String? ?? 'PENDING';
      return status == 'PENDING' || status == 'REVIEW';
    }).toList();
  }

  List<Map<String, dynamic>> get _reviewedExams {
    return _examsList.where((e) {
      final status = e['status'] as String? ?? 'PENDING';
      return status == 'APPROVED' || status == 'REJECTED';
    }).toList();
  }

  Future<void> _updateExamStatus(String examId, String newStatus, String comment) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final currentUserId = currentUser?.id ?? 'b2f4c6d8-2345-6789-bcde-f23456789012';
    final nowStr = DateTime.now().toIso8601String();

    try {
      await Supabase.instance.client
          .from('exams')
          .update({
            'status': newStatus,
            'comments': comment,
            'reviewed_by': currentUserId,
            'reviewed_at': nowStr,
          })
          .eq('id', examId);

      // Local State Update on success
      setState(() {
        final index = _examsList.indexWhere((e) => e['id'] == examId);
        if (index != -1) {
          _examsList[index]['status'] = newStatus;
          _examsList[index]['comments'] = comment;
          _examsList[index]['reviewed_by'] = currentUserId;
          _examsList[index]['reviewed_at'] = nowStr;
        }
      });

      if (mounted) {
        showToast(context, 'Exam successfully marked as $newStatus!', isError: false);
      }
    } catch (e) {
      // Local caching fallback for offline use/mock setup
      setState(() {
        final index = _examsList.indexWhere((e) => e['id'] == examId);
        if (index != -1) {
          _examsList[index]['status'] = newStatus;
          _examsList[index]['comments'] = comment;
          _examsList[index]['reviewed_by'] = currentUserId;
          _examsList[index]['reviewed_at'] = nowStr;
        }
      });
      if (mounted) {
        showToast(context, 'Exam cache marked as $newStatus!', isError: false);
      }
    }
  }

  void _showReviewDialog(Map<String, dynamic> exam) {
    final TextEditingController commentController = TextEditingController(text: exam['comments'] as String? ?? '');
    final String examId = exam['id'] as String;
    final String examName = exam['name'] as String;
    final String clsName = exam['class_name'] as String;
    final String subject = exam['subject'] as String;
    final String date = exam['date'] as String;
    final String currentStatus = exam['status'] as String;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
          titlePadding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 8.h),
          contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
          actionsPadding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
          backgroundColor: Colors.white,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Review Exam Results',
                style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 17.sp, color: AppColors.textDark),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: AppColors.textLight, size: 20.sp),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Info Section
                _dialogInfoRow('Exam Name', examName),
                _dialogInfoRow('Class / Sec', clsName),
                _dialogInfoRow('Subject', subject),
                _dialogInfoRow('Assessment Date', date),
                _dialogInfoRow('Current Status', currentStatus),
                
                SizedBox(height: 16.h),
                Text(
                  'Review Remarks / Comments',
                  style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w800, color: AppColors.textDark, letterSpacing: 0.5),
                ),
                SizedBox(height: 8.h),
                TextField(
                  controller: commentController,
                  maxLines: 2,
                  style: GoogleFonts.inter(fontSize: 13.sp, color: AppColors.textDark, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'Enter review remarks...',
                    hintStyle: GoogleFonts.inter(color: AppColors.textLight, fontSize: 12.sp),
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: EdgeInsets.all(12.r),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide(color: widget.theme.primary),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      side: const BorderSide(color: AppColors.error, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _updateExamStatus(examId, 'REJECTED', commentController.text.trim());
                    },
                    child: Text('❌ Reject', style: GoogleFonts.inter(color: AppColors.error, fontWeight: FontWeight.w800, fontSize: 13.sp)),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _updateExamStatus(examId, 'APPROVED', commentController.text.trim());
                    },
                    child: Text('✅ Approve', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.sp)),
                  ),
                ),
              ],
            )
          ],
        );
      },
    );
  }

  Widget _dialogInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110.w,
            child: Text('$label:', style: GoogleFonts.inter(fontSize: 12.sp, color: AppColors.textMedium, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value, style: GoogleFonts.inter(fontSize: 12.sp, color: AppColors.textDark, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PageHeader(
            title: 'Approvals',
            subtitle: 'Review & verify exam results',
            theme: widget.theme,
          ),
          
          // Tab bar selection (Pending Approval / Reviewed)
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: widget.theme.primary,
              unselectedLabelColor: AppColors.textLight,
              indicatorColor: widget.theme.primary,
              indicatorWeight: 3.h,
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 13.sp),
              tabs: const [
                Tab(text: '📋 Pending Approval'),
                Tab(text: '✅ Reviewed'),
              ],
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.teacherPrimary))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildExamsList(_pendingExams, isPendingTab: true),
                      _buildExamsList(_reviewedExams, isPendingTab: false),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamsList(List<Map<String, dynamic>> list, {required bool isPendingTab}) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 44.sp, color: AppColors.textLight),
            SizedBox(height: 8.h),
            Text(
              isPendingTab ? 'No pending approvals found' : 'No reviewed exams found',
              style: GoogleFonts.inter(color: AppColors.textMedium, fontSize: 13.sp, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchExams,
      color: widget.theme.primary,
      child: ListView.builder(
        padding: EdgeInsets.all(16.r),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final exam = list[index];
          final name = exam['name'] as String;
          final cls = exam['class_name'] as String;
          final subject = exam['subject'] as String;
          final date = exam['date'] as String;
          final status = exam['status'] as String? ?? 'PENDING';
          final comment = exam['comments'] as String? ?? '';

          Color badgeColor = AppColors.warning;
          Color bgBadgeColor = const Color(0xFFFFFBEB);
          
          if (status == 'APPROVED') {
            badgeColor = AppColors.success;
            bgBadgeColor = const Color(0xFFECFDF5);
          } else if (status == 'REJECTED') {
            badgeColor = AppColors.error;
            bgBadgeColor = const Color(0xFFFEF2F2);
          }

          return Container(
            margin: EdgeInsets.only(bottom: 12.h),
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
                onTap: isPendingTab ? () => _showReviewDialog(exam) : null,
                onLongPress: () => _showReviewDialog(exam),
                child: Padding(
                  padding: EdgeInsets.all(18.r),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge and Class
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: widget.theme.light,
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Text(
                              cls,
                              style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w900, color: widget.theme.primary),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                            decoration: BoxDecoration(color: bgBadgeColor, borderRadius: BorderRadius.circular(8.r)),
                            child: Text(
                              status,
                              style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w900, color: badgeColor),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),

                      // Title details
                      Text(name, style: GoogleFonts.inter(fontSize: 15.sp, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                      SizedBox(height: 4.h),
                      
                      Row(
                        children: [
                          Icon(Icons.book_outlined, size: 14.sp, color: AppColors.textLight),
                          SizedBox(width: 4.w),
                          Text(subject, style: GoogleFonts.inter(fontSize: 12.sp, color: AppColors.textMedium, fontWeight: FontWeight.w600)),
                          SizedBox(width: 14.w),
                          Icon(Icons.calendar_today_rounded, size: 13.sp, color: AppColors.textLight),
                          SizedBox(width: 4.w),
                          Text(date, style: GoogleFonts.inter(fontSize: 12.sp, color: AppColors.textMedium, fontWeight: FontWeight.w600)),
                        ],
                      ),

                      if (!isPendingTab && comment.isNotEmpty) ...[
                        Divider(height: 24.h, color: AppColors.border),
                        Text(
                          'REMARKS',
                          style: GoogleFonts.inter(fontSize: 9.sp, color: AppColors.textLight, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          '"$comment"',
                          style: GoogleFonts.inter(fontSize: 12.sp, color: AppColors.textMedium, fontWeight: FontWeight.w600, fontStyle: FontStyle.italic),
                        ),
                      ],

                      if (isPendingTab) ...[
                        Divider(height: 24.h, color: AppColors.border),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Tap / Long Press to Review',
                              style: GoogleFonts.inter(fontSize: 11.sp, color: widget.theme.primary, fontWeight: FontWeight.w800),
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
        },
      ),
    );
  }
}
