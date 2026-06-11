import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import '../main_screen.dart';

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
  }

  Future<void> _loadOverdueData() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client
          .from('LibraryIssue')
          .select('*, book:Book(*), student:Student(*)')
          .isFilter('returnDate', null);

      final List<Map<String, dynamic>> allActiveIssues =
          List<Map<String, dynamic>>.from(res);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      _overdueIssues = allActiveIssues.where((issue) {
        final dueDateStr = issue['dueDate'] ?? '';
        if (dueDateStr.isEmpty) return false;
        try {
          final dueDate = DateTime.parse(dueDateStr);
          final dueNormalized =
              DateTime(dueDate.year, dueDate.month, dueDate.day);
          return dueNormalized.isBefore(today);
        } catch (_) {
          return false;
        }
      }).toList();
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
      final dueNormalized =
          DateTime(dueDate.year, dueDate.month, dueDate.day);
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
    final studentName = student['name'] ?? 'Unknown Student';

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r)),
        title: Text(
          'Return & Pay Fine',
          style: GoogleFonts.inter(
              fontWeight: FontWeight.w900,
              fontSize: 18.sp,
              color: AppColors.textDark),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Return "$title" for $studentName and settle the fine?',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w500,
                  fontSize: 14.sp,
                  color: AppColors.textMedium),
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
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.sp,
                          color: AppColors.error),
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
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMedium)),
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
      final now = DateTime.now();
      final nowStr = now.toIso8601String();
      final studentId = issue['studentId'] ?? '';

      // 1. Resolve or create StudentFeeLedger
      String ledgerId = '';
      String academicYearId = '';
      String feeStructureId = '';

      final ledgerRes = await Supabase.instance.client
          .from('StudentFeeLedger')
          .select('*')
          .eq('studentId', studentId)
          .limit(1);

      if (ledgerRes.isNotEmpty) {
        ledgerId = ledgerRes[0]['id'] ?? '';
        academicYearId = ledgerRes[0]['academicYearId'] ?? '';
        feeStructureId = ledgerRes[0]['feeStructureId'] ?? '';
      } else {
        final ayRes = await Supabase.instance.client
            .from('AcademicYear')
            .select('id')
            .limit(1);
        final fsRes = await Supabase.instance.client
            .from('FeeStructure')
            .select('id')
            .limit(1);
        if (ayRes.isNotEmpty) academicYearId = ayRes[0]['id'] ?? '';
        if (fsRes.isNotEmpty) feeStructureId = fsRes[0]['id'] ?? '';

        if (academicYearId.isNotEmpty && feeStructureId.isNotEmpty) {
          final newLedger = await Supabase.instance.client
              .from('StudentFeeLedger')
              .insert({
            'studentId': studentId,
            'academicYearId': academicYearId,
            'feeStructureId': feeStructureId,
            'totalPayable': 0.0,
            'totalPaid': 0.0,
            'totalPending': 0.0,
            'totalDiscount': 0.0,
            'status': 'PENDING',
            'createdAt': nowStr,
            'updatedAt': nowStr,
          }).select('id').single();
          ledgerId = newLedger['id'] ?? '';
        }
      }

      // 2. Insert FeePayment for fine
      if (ledgerId.isNotEmpty &&
          academicYearId.isNotEmpty &&
          feeStructureId.isNotEmpty) {
        final receiptNo = 'RCPT-FINE-${now.millisecondsSinceEpoch}';
        final txnId = 'TXN-FINE-${now.millisecondsSinceEpoch}';
        await Supabase.instance.client.from('FeePayment').insert({
          'receiptNumber': receiptNo,
          'studentId': studentId,
          'feeStructureId': feeStructureId,
          'ledgerId': ledgerId,
          'academicYearId': academicYearId,
          'amount': fineAmount,
          'discount': 0.0,
          'penalty': 0.0,
          'totalAmount': fineAmount,
          'paymentType': 'RECEIPT',
          'paymentDate': nowStr,
          'paymentMode': 'ONLINE',
          'status': 'COMPLETED',
          'transactionId': txnId,
          'createdAt': nowStr,
          'updatedAt': nowStr,
        });
      }

      // 3. Update LibraryIssue
      await Supabase.instance.client.from('LibraryIssue').update({
        'returnDate': nowStr,
        'status': 'RETURNED',
        'fineAmount': fineAmount,
        'finePaid': true,
        'updatedAt': nowStr,
      }).eq('id', issue['id']);

      // 4. Increment availableCopies
      final currentAvailable = book['availableCopies'] as int? ?? 0;
      final currentTotal = book['totalCopies'] as int? ?? 1;
      final newAvailable = (currentAvailable + 1).clamp(0, currentTotal);
      await Supabase.instance.client.from('Book').update({
        'availableCopies': newAvailable,
        'status': 'AVAILABLE',
        'updatedAt': nowStr,
      }).eq('id', book['id']);

      if (mounted) {
        showToast(context, 'Fine paid & book returned successfully! 📚');
      }
      await _loadOverdueData();
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

    return Scaffold(
      bottomNavigationBar: const TeacherBottomNavBar(activeIndex: 0),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        leading: IconButton(
          icon: Icon(Icons.menu, size: 28),
          onPressed: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
            MainScreen.openDrawer();
          },
        ),
        title: Text(
          'EduSphere',
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_none_rounded, size: 28),
            onPressed: () {},
          ),
          SizedBox(width: 8),
        ],
      ),

      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top bar ──────────────────────────────────────────────────
            Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
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
                          style: GoogleFonts.inter(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF374151),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Title ────────────────────────────────────────────────────
            Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: 20.w),
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
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF6B7280),
                    ),
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
                            _buildSummaryBanner(
                                criticalCount, totalFines),
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
                  style: GoogleFonts.inter(
                      fontSize: 14.sp, color: AppColors.error),
                  children: [
                    TextSpan(
                      text: '$criticalCount book${criticalCount == 1 ? '' : 's'}',
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
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.error,
                ),
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
            padding:
                EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
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
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF6B7280),
                  ),
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
                    color: AppColors.success.withValues(alpha: 0.25),
                    width: 2),
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
              style: GoogleFonts.inter(
                fontSize: 13.sp,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF6B7280),
              ),
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
                      style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'by $author',
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  '$daysOverdue days',
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.error,
                  ),
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
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMedium,
                  ),
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
                    style: GoogleFonts.inter(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textLight,
                    ),
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
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r)),
                  padding: EdgeInsets.symmetric(
                      horizontal: 14.w, vertical: 10.h),
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
          style: GoogleFonts.inter(
            fontSize: 9.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textLight,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
