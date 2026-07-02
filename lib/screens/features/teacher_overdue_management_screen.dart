import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import '../main_screen.dart';
import '../../widgets/teacher_app_bar.dart';
import '../../widgets/teacher_scaffold.dart';
import 'package:edusphere/theme/typography.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';

class TeacherOverdueManagementScreen extends StatefulWidget {
  final RoleTheme theme;
  const TeacherOverdueManagementScreen({super.key, required this.theme});

  @override
  State<TeacherOverdueManagementScreen> createState() =>
      _TeacherOverdueManagementScreenState();
}

class _TeacherOverdueManagementScreenState
    extends State<TeacherOverdueManagementScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _overdueIssues = [];

  @override
  void initState() {
    super.initState();
    _loadOverdueData();
    _connectRealtime();
  }

  void _connectRealtime() {
    try {
      SocketService().on('LIBRARY_BOOK_RETURNED', _handleLibraryUpdate);
      SocketService().on('LIBRARY_BOOK_ISSUED', _handleLibraryUpdate);
    } catch (e) {
      debugPrint('Error subscribing to overdue management realtime: $e');
    }
  }

  void _handleLibraryUpdate(dynamic data) {
    if (mounted) _loadOverdueData();
  }

  @override
  void dispose() {
    try {
      SocketService().off('LIBRARY_BOOK_RETURNED', _handleLibraryUpdate);
      SocketService().off('LIBRARY_BOOK_ISSUED', _handleLibraryUpdate);
    } catch (_) {}
    super.dispose();
  }

  Future<void> _loadOverdueData() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.instance.get('library/overdue');
      if (res['success'] == true && res['overdueBooks'] != null) {
        _overdueIssues = List<Map<String, dynamic>>.from(res['overdueBooks']);
      }
    } catch (e) {
      debugPrint('Error fetching overdue books: $e');
      if (mounted) {
        showToast(context, 'Failed to fetch overdue records', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int _calculateDaysOverdue(String dueDateStr) {
    if (dueDateStr.isEmpty) return 0;
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dueDate = DateTime.parse(dueDateStr);
      final dueNormalized = DateTime(dueDate.year, dueDate.month, dueDate.day);
      final diff = today.difference(dueNormalized).inDays;
      return diff > 0 ? diff : 0;
    } catch (_) {
      return 0;
    }
  }

  double _calculateFine(int days) => days * 2.0;

  double get _totalPendingFines {
    double total = 0;
    for (final issue in _overdueIssues) {
      final days = _calculateDaysOverdue(issue['dueDate'] ?? '');
      total += _calculateFine(days);
    }
    return total;
  }

  Future<void> _returnAndPayFine(Map<String, dynamic> issue) async {
    final dueDateStr = issue['dueDate'] ?? '';
    final daysOverdue = _calculateDaysOverdue(dueDateStr);
    final fineAmount = _calculateFine(daysOverdue);
    final book = issue['book'] as Map<String, dynamic>? ?? {};
    final student = issue['student'] as Map<String, dynamic>? ?? {};
    final title = book['title'] ?? 'Unknown Book';
    
    final user = (student['user'] ?? student['User']) as Map? ?? {};
    final firstName = user['firstName'] ?? user['first_name'] ?? '';
    final lastName = user['lastName'] ?? user['last_name'] ?? '';
    final studentName = '$firstName $lastName'.trim().isNotEmpty 
        ? '$firstName $lastName'.trim() 
        : (student['name'] ?? 'Unknown Student');

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Text(
          'Return & Pay Fine',
          style: AppTypography.bodyLarge.copyWith(color: AppColors.textDark),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Return "$title" for $studentName and settle the fine?',
              style: AppTypography.small.copyWith(color: AppColors.textMedium),
            ),
            SizedBox(height: 14.h),
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                children: [
                  Icon(Icons.monetization_on_rounded,
                      color: AppColors.error, size: 20.sp),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      'Fine: ₹${fineAmount.toStringAsFixed(2)} ($daysOverdue days overdue)',
                      style:
                          AppTypography.small.copyWith(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700, color: AppColors.textMedium)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r)),
            ),
            child: Text('Pay & Return',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final returnRes = await ApiService.instance.post('library/return', body: {
        'issueId': issue['id'],
        'conditionOnReturn': 'GOOD',
        'remarks': 'Returned and fine paid via teacher portal.',
      });

      if (returnRes['success'] == true) {
        if (mounted) {
          showToast(context, 'Fine paid & book returned successfully! 📚');
        }
        await _loadOverdueData();
      } else {
        throw Exception(returnRes['message'] ?? 'Failed to return book');
      }
    } catch (e) {
      debugPrint('Error returning book: $e');
      if (mounted) {
        showToast(context, 'Failed to process return. Please try again.',
            isError: true);
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final int criticalCount = _overdueIssues.length;
    final double totalFines = _totalPendingFines;

    return TeacherScaffold(
      title: 'Overdue Management',
      activeIndex: 0,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top bar ──────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Row(
                      children: [
                        Icon(Icons.arrow_back,
                            size: 20.sp, color: const Color(0xFF374151)),
                        SizedBox(width: 6.w),
                        Text(
                          'Back to Library',
                          style: AppTypography.caption
                              .copyWith(color: const Color(0xFF374151)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Title ────────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Overdue Management',
                    style: GoogleFonts.outfit(
                      fontSize: 26.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Monitor overdue returns and track penalty fines',
                    style: AppTypography.caption
                        .copyWith(color: const Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16.h),

            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: widget.theme.primary,
                        strokeWidth: 3.w,
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadOverdueData,
                      color: widget.theme.primary,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.symmetric(
                            horizontal: 16.w, vertical: 4.h),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Summary banner ──────────────────────────
                            _buildSummaryBanner(criticalCount, totalFines),
                            SizedBox(height: 16.h),

                            // ── Delinquent Returns card ─────────────────
                            _buildDelinquentReturnsCard(),
                            SizedBox(height: 40.h),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBanner(int criticalCount, double totalFines) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFFECACA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8.r,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(6.r),
            decoration: const BoxDecoration(
              color: Color(0xFFFEE2E2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.error_outline_rounded,
                color: AppColors.error, size: 20.sp),
          ),
          SizedBox(width: 12.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: AppTypography.small.copyWith(color: AppColors.error),
                  children: [
                    TextSpan(
                      text:
                          '$criticalCount book${criticalCount == 1 ? '' : 's'}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const TextSpan(
                      text: ' are critically overdue',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                'Total pending fines: ₹${totalFines.toStringAsFixed(0)}',
                style: AppTypography.caption.copyWith(color: AppColors.error),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDelinquentReturnsCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8.r,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delinquent Returns',
                  style: GoogleFonts.outfit(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Comprehensive list of books past their due date',
                  style: AppTypography.caption
                      .copyWith(color: const Color(0xFF6B7280)),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          // Content
          _overdueIssues.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.all(16.r),
                  itemCount: _overdueIssues.length,
                  separatorBuilder: (_, __) => SizedBox(height: 12.h),
                  itemBuilder: (context, index) =>
                      _buildOverdueCard(_overdueIssues[index]),
                ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 48.h),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72.w,
              height: 72.w,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.25), width: 2),
              ),
              child: Center(
                child: Icon(Icons.check_circle_outline_rounded,
                    color: AppColors.success, size: 36.sp),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              'All clear!',
              style: GoogleFonts.outfit(
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF111827),
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              'No overdue books found in the system.',
              style: AppTypography.caption
                  .copyWith(color: const Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverdueCard(Map<String, dynamic> issue) {
    final book = issue['book'] as Map<String, dynamic>? ?? {};
    final student = issue['student'] as Map<String, dynamic>? ?? {};
    final title = book['title'] ?? 'Unknown Book';
    final author = book['author'] ?? 'Unknown Author';
    final studentName = student['name'] ?? 'Unknown Student';
    final rollNo = student['roll_no']?.toString() ?? '';
    final dueDateStr = issue['dueDate'] ?? '';
    final issueDateStr = issue['issueDate'] ?? '';

    DateTime? issueDate;
    DateTime? dueDate;
    try {
      issueDate = DateTime.parse(issueDateStr);
    } catch (_) {}
    try {
      dueDate = DateTime.parse(dueDateStr);
    } catch (_) {}

    final daysOverdue = _calculateDaysOverdue(dueDateStr);
    final fine = _calculateFine(daysOverdue);

    String fmt(DateTime? d) => d != null
        ? '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}'
        : 'N/A';

    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBFB),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Book + badge row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44.w,
                height: 44.h,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(Icons.menu_book_rounded,
                    color: AppColors.error, size: 22.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.small
                          .copyWith(color: AppColors.textDark),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'by $author',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textMedium),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  '$daysOverdue days',
                  style: AppTypography.caption.copyWith(color: AppColors.error),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Divider(color: const Color(0xFFFECACA), height: 1.h),
          SizedBox(height: 10.h),

          // Student info
          Row(
            children: [
              Icon(Icons.person_rounded,
                  size: 13.sp, color: AppColors.textLight),
              SizedBox(width: 5.w),
              Expanded(
                child: Text(
                  '$studentName${rollNo.isNotEmpty ? '  •  Roll: $rollNo' : ''}',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textMedium),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),

          // Dates row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _dateCol('ISSUED', fmt(issueDate), AppColors.textDark),
              _dateCol('DUE DATE', fmt(dueDate), AppColors.error),
              _dateCol('OVERDUE', '$daysOverdue days', AppColors.error),
            ],
          ),
          SizedBox(height: 14.h),

          // Fine + action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PENDING FINE',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textLight),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    '₹${fine.toStringAsFixed(0)}',
                    style: GoogleFonts.outfit(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w900,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _returnAndPayFine(issue),
                icon: Icon(Icons.payment_rounded,
                    color: Colors.white, size: 15.sp),
                label: Text(
                  'Return & Pay',
                  style: AppTypography.caption.copyWith(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r)),
                  padding:
                      EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                  elevation: 2,
                  shadowColor: AppColors.error.withValues(alpha: 0.35),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateCol(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(color: AppColors.textLight),
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          style: AppTypography.caption.copyWith(color: valueColor),
        ),
      ],
    );
  }
}
