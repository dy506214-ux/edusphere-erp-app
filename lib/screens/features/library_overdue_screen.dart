import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';

class LibraryOverdueScreen extends StatefulWidget {
  final RoleTheme theme;
  const LibraryOverdueScreen({super.key, required this.theme});

  @override
  State<LibraryOverdueScreen> createState() => _LibraryOverdueScreenState();
}

class _LibraryOverdueScreenState extends State<LibraryOverdueScreen> {
  bool _isLoading = true;
  String _studentId = '';
  bool _isStudent = true; // Defaults to true, determined from session
  List<Map<String, dynamic>> _overdueIssues = [];

  @override
  void initState() {
    super.initState();
    _loadOverdueData();
  }

  Future<void> _loadOverdueData() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _studentId = prefs.getString('student_id') ?? Supabase.instance.client.auth.currentUser?.id ?? '';
      
      // Check if user is student or teacher/librarian from roles
      // In EduSphere, if studentId is present, the role is student.
      _isStudent = _studentId.isNotEmpty;

      // Query unreturned library issues
      var query = Supabase.instance.client
          .from('LibraryIssue')
          .select('*, book:Book(*), student:Student(*)')
          .isFilter('returnDate', null);

      // For students, filter only their own records
      if (_isStudent && _studentId.isNotEmpty) {
        query = query.eq('studentId', _studentId);
      }

      final res = await query;
      final List<Map<String, dynamic>> allActiveIssues = List<Map<String, dynamic>>.from(res);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Filter client-side where dueDate < today (i.e. overdue)
      _overdueIssues = allActiveIssues.where((issue) {
        final dueDateStr = issue['dueDate'] ?? '';
        if (dueDateStr.isEmpty) return false;
        try {
          final dueDate = DateTime.parse(dueDateStr);
          final dueNormalized = DateTime(dueDate.year, dueDate.month, dueDate.day);
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
      if (mounted) {
        setState(() => _isLoading = false);
      }
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

  double _calculateFine(int days) {
    return days * 2.0; // Rs 2 per day overdue
  }

  Future<void> _returnAndPayFine(Map<String, dynamic> issue) async {
    final dueDateStr = issue['dueDate'] ?? '';
    final daysOverdue = _calculateDaysOverdue(dueDateStr);
    final fineAmount = _calculateFine(daysOverdue);
    final book = issue['book'] as Map<String, dynamic>? ?? {};
    final title = book['title'] ?? 'Unknown Book';

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Text(
          'Return & Pay Fine',
          style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18.sp, color: AppColors.textDark),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to return "$title" and settle the fine?',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14.sp, color: AppColors.textMedium),
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
                  Icon(Icons.monetization_on_rounded, color: AppColors.error, size: 20.sp),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      'Fine: ₹${fineAmount.toStringAsFixed(2)} ($daysOverdue days overdue)',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.sp,
                        color: AppColors.error,
                      ),
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
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textMedium),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
            child: Text(
              'Pay & Return',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white),
            ),
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

      // 1. Resolve or Create StudentFeeLedger details for fine insertion to avoid constraint violation
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
        // Find first active AcademicYear and FeeStructure
        final ayRes = await Supabase.instance.client.from('AcademicYear').select('id').limit(1);
        final fsRes = await Supabase.instance.client.from('FeeStructure').select('id').limit(1);

        if (ayRes.isNotEmpty) academicYearId = ayRes[0]['id'] ?? '';
        if (fsRes.isNotEmpty) feeStructureId = fsRes[0]['id'] ?? '';

        if (academicYearId.isNotEmpty && feeStructureId.isNotEmpty) {
          // Dynamic construction of a ledger record
          final newLedger = await Supabase.instance.client.from('StudentFeeLedger').insert({
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

      // 2. Perform FeePayment insertion
      if (ledgerId.isNotEmpty && academicYearId.isNotEmpty && feeStructureId.isNotEmpty) {
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

      // 3. Update LibraryIssue record
      await Supabase.instance.client.from('LibraryIssue').update({
        'returnDate': nowStr,
        'status': 'RETURNED',
        'fineAmount': fineAmount,
        'finePaid': true,
        'updatedAt': nowStr,
      }).eq('id', issue['id']);

      // 4. Increment availableCopies in Book table
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

      // Reload
      await _loadOverdueData();
    } catch (e) {
      debugPrint('Error returning book: $e');
      if (mounted) {
        showToast(context, 'Failed to process return. Please try again.', isError: true);
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header
          PageHeader(
            title: 'Overdue Fines',
            subtitle: _isStudent ? 'Settle pending fines and return books' : 'Manage school overdue books',
            theme: widget.theme,
          ),

          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: widget.theme.primary,
                      strokeWidth: 3.w,
                    ),
                  )
                : _overdueIssues.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadOverdueData,
                        color: widget.theme.primary,
                        child: ListView.builder(
                          padding: EdgeInsets.all(16.r),
                          itemCount: _overdueIssues.length,
                          itemBuilder: (context, index) {
                            return _buildOverdueCard(_overdueIssues[index]);
                          },
                        ),
                      ),
          ),
        ],
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

    final issueDateStr = issue['issueDate'] ?? '';
    final dueDateStr = issue['dueDate'] ?? '';

    DateTime? issueDate;
    DateTime? dueDate;
    try {
      issueDate = DateTime.parse(issueDateStr);
      dueDate = DateTime.parse(dueDateStr);
    } catch (_) {}

    final daysOverdue = _calculateDaysOverdue(dueDateStr);
    final fine = _calculateFine(daysOverdue);

    final String dateText = dueDate != null
        ? '${dueDate.day.toString().padLeft(2, '0')}/${dueDate.month.toString().padLeft(2, '0')}/${dueDate.year}'
        : 'N/A';

    final String issueText = issueDate != null
        ? '${issueDate.day.toString().padLeft(2, '0')}/${issueDate.month.toString().padLeft(2, '0')}/${issueDate.year}'
        : 'N/A';

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8.r,
            offset: Offset(0, 3.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48.w,
                height: 48.h,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  Icons.assignment_late_rounded, 
                  color: AppColors.error,
                  size: 24.sp,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'by $author',
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),

          // Details grid
          Divider(color: AppColors.border, height: 1.h),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ISSUED DATE',
                    style: GoogleFonts.inter(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textLight,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    issueText,
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DUE DATE',
                    style: GoogleFonts.inter(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textLight,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    dateText,
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'OVERDUE',
                    style: GoogleFonts.inter(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textLight,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    '$daysOverdue Days',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          if (!_isStudent) ...[
            SizedBox(height: 12.h),
            Divider(color: AppColors.border, height: 1.h),
            SizedBox(height: 10.h),
            Row(
              children: [
                Icon(Icons.person_rounded, size: 14.sp, color: AppColors.textLight),
                SizedBox(width: 6.w),
                Text(
                  'Student: $studentName (Roll: $rollNo)',
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMedium,
                  ),
                ),
              ],
            ),
          ],
          
          SizedBox(height: 16.h),

          // Fine & Pay CTA
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
                    style: GoogleFonts.inter(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w900,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () => _returnAndPayFine(issue),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  elevation: 2,
                  shadowColor: AppColors.error.withValues(alpha: 0.3),
                ),
                child: Row(
                  children: [
                    Icon(Icons.payment_rounded, color: Colors.white, size: 16.sp),
                    SizedBox(width: 8.w),
                    Text(
                      'Return & Pay',
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.r),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100.w,
              height: 100.w,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.check_circle_rounded, 
                  color: AppColors.success, 
                  size: 52.sp,
                ),
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              'No overdue books!',
              style: GoogleFonts.inter(
                fontSize: 18.sp,
                fontWeight: FontWeight.w900,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Great job 📚 Keep up the fantastic reading habits!',
              style: GoogleFonts.inter(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textMedium,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
