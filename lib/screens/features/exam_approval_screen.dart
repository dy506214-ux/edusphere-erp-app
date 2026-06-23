import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart' as intl;
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import '../main_screen.dart';
import '../../widgets/teacher_app_bar.dart';
import 'package:edusphere/theme/typography.dart';

class ExamApprovalScreen extends StatefulWidget {
  final RoleTheme theme;
  const ExamApprovalScreen({super.key, required this.theme});

  @override
  State<ExamApprovalScreen> createState() => _ExamApprovalScreenState();
}

class _ExamApprovalScreenState extends State<ExamApprovalScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late TabController _tabController;
  bool _loading = false;

  List<Map<String, dynamic>> _examsList = [];

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
          .from('Exam')
          .select('*, Class(*)')
          .order('name', ascending: true);

      final List<Map<String, dynamic>> rawData =
          List<Map<String, dynamic>>.from(response);
      final List<Map<String, dynamic>> mappedData = [];
      for (var exam in rawData) {
        final name = exam['name'] as String? ?? 'Exam';
        final cls = exam['Class']?['name']?.toString() ?? 'Grade 8';
        const subject = 'All Subjects';
        final dateStr = exam['startDate']?.toString();
        String date = '—';
        if (dateStr != null) {
          try {
            date = intl.DateFormat('MMM d, yyyy')
                .format(DateTime.parse(dateStr).toLocal());
          } catch (_) {}
        }

        mappedData.add({
          ...exam,
          'name': name,
          'class_name': cls,
          'subject': subject,
          'date': date,
        });
      }

      setState(() {
        _examsList = mappedData;
      });
    } catch (e) {
      setState(() {
        _examsList = [];
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

  Future<void> _updateExamStatus(
      String examId, String newStatus, String comment) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final currentUserId =
        currentUser?.id ?? 'b2f4c6d8-2345-6789-bcde-f23456789012';
    final nowStr = DateTime.now().toIso8601String();

    try {
      await Supabase.instance.client.from('Exam').update({
        'status': newStatus,
        'comments': comment,
        'reviewed_by': currentUserId,
        'reviewed_at': nowStr,
      }).eq('id', examId);

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
        showToast(context, 'Exam successfully marked as $newStatus!',
            isError: false);
      }
    } catch (e) {
      if (mounted) {
        showToast(context, 'Error updating exam status: $e', isError: true);
      }
    }
  }

  void _showReviewDialog(Map<String, dynamic> exam) {
    final TextEditingController commentController =
        TextEditingController(text: exam['comments'] as String? ?? '');
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
          titlePadding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 8.h),
          contentPadding:
              EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
          actionsPadding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
          backgroundColor: Colors.white,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Review Exam Results',
                style: AppTypography.body.copyWith(color: AppColors.textDark),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded,
                    color: AppColors.textLight, size: 20.sp),
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
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textDark, letterSpacing: 0.5),
                ),
                SizedBox(height: 8.h),
                TextField(
                  controller: commentController,
                  maxLines: 2,
                  style:
                      AppTypography.caption.copyWith(color: AppColors.textDark),
                  decoration: InputDecoration(
                    hintText: 'Enter review remarks...',
                    hintStyle: AppTypography.caption
                        .copyWith(color: AppColors.textLight),
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
                      side:
                          const BorderSide(color: AppColors.error, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _updateExamStatus(
                          examId, 'REJECTED', commentController.text.trim());
                    },
                    child: Text('❌ Reject',
                        style: AppTypography.caption
                            .copyWith(color: AppColors.error)),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _updateExamStatus(
                          examId, 'APPROVED', commentController.text.trim());
                    },
                    child: Text('✅ Approve',
                        style: AppTypography.caption
                            .copyWith(color: Colors.white)),
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
            child: Text('$label:',
                style: AppTypography.caption
                    .copyWith(color: AppColors.textMedium)),
          ),
          Expanded(
            child: Text(value,
                style:
                    AppTypography.caption.copyWith(color: AppColors.textDark)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isPushed = Navigator.canPop(context);
    final bool isTeacher = widget.theme.label.toLowerCase() == 'teacher';

    return Scaffold(
      key: _scaffoldKey,
      drawer: (isPushed && isTeacher)
          ? const EduSphereDrawer(role: 'teacher', activeLabel: 'Academic')
          : null,
      backgroundColor: AppColors.background,
      appBar: isTeacher ? const TeacherAppBar(title: 'Approvals') : null,
      bottomNavigationBar: (isPushed && isTeacher)
          ? const TeacherBottomNavBar(activeIndex: 7)
          : null,
      body: Column(
        children: [
          PageHeader(
            title: 'Approvals',
            subtitle: 'Review & verify exam results',
            theme: widget.theme,
            leading: (isPushed && isTeacher)
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

          // Tab bar selection (Pending Approval / Reviewed)
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: widget.theme.primary,
              unselectedLabelColor: AppColors.textLight,
              indicatorColor: widget.theme.primary,
              indicatorWeight: 3.h,
              labelStyle: AppTypography.caption,
              tabs: const [
                Tab(text: '📋 Pending Approval'),
                Tab(text: '✅ Reviewed'),
              ],
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.teacherPrimary))
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

  Widget _buildExamsList(List<Map<String, dynamic>> list,
      {required bool isPendingTab}) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline_rounded,
                size: 44.sp, color: AppColors.textLight),
            SizedBox(height: 8.h),
            Text(
              isPendingTab
                  ? 'No pending approvals found'
                  : 'No reviewed exams found',
              style:
                  AppTypography.caption.copyWith(color: AppColors.textMedium),
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
                            padding: EdgeInsets.symmetric(
                                horizontal: 10.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: widget.theme.light,
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Text(
                              cls,
                              style: AppTypography.caption
                                  .copyWith(color: widget.theme.primary),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 10.w, vertical: 4.h),
                            decoration: BoxDecoration(
                                color: bgBadgeColor,
                                borderRadius: BorderRadius.circular(8.r)),
                            child: Text(
                              status,
                              style: AppTypography.caption
                                  .copyWith(color: badgeColor),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),

                      // Title details
                      Text(name,
                          style: AppTypography.small
                              .copyWith(color: AppColors.textDark)),
                      SizedBox(height: 4.h),

                      Row(
                        children: [
                          Icon(Icons.book_outlined,
                              size: 14.sp, color: AppColors.textLight),
                          SizedBox(width: 4.w),
                          Text(subject,
                              style: AppTypography.caption
                                  .copyWith(color: AppColors.textMedium)),
                          SizedBox(width: 14.w),
                          Icon(Icons.calendar_today_rounded,
                              size: 13.sp, color: AppColors.textLight),
                          SizedBox(width: 4.w),
                          Text(date,
                              style: AppTypography.caption
                                  .copyWith(color: AppColors.textMedium)),
                        ],
                      ),

                      if (!isPendingTab && comment.isNotEmpty) ...[
                        Divider(height: 24.h, color: AppColors.border),
                        Text(
                          'REMARKS',
                          style: AppTypography.caption.copyWith(
                              color: AppColors.textLight, letterSpacing: 0.5),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          '"$comment"',
                          style: AppTypography.caption.copyWith(
                              color: AppColors.textMedium,
                              fontStyle: FontStyle.italic),
                        ),
                      ],

                      if (isPendingTab) ...[
                        Divider(height: 24.h, color: AppColors.border),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Tap / Long Press to Review',
                              style: AppTypography.caption
                                  .copyWith(color: widget.theme.primary),
                            ),
                            SizedBox(width: 2.w),
                            Icon(Icons.arrow_forward_ios_rounded,
                                size: 11.sp, color: widget.theme.primary),
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
