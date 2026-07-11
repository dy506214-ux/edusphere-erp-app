import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import '../../services/api_service.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:edusphere/theme/typography.dart';
import '../../config/api_endpoints.dart';

class FeesScreen extends StatefulWidget {
  const FeesScreen({super.key});
  @override
  State<FeesScreen> createState() => _FeesScreenState();
}

class _FeesScreenState extends State<FeesScreen> {
  // 'overview' | 'qr' | 'verifying' | 'success'
  String _view = 'overview';

  bool _isLoading = true;
  String? _errorMsg;
  double _totalOutstanding = 0;
  List<Map<String, String>> _feeItems = [];
  List<Map<String, String>> _paymentHistory = [];
  String _studentId = '';
  String _feeStructureId = '';
  String _ledgerId = '';
  String _academicYearId = '';

  @override
  void initState() {
    super.initState();
    _loadFeeData();
  }

  Future<void> _loadFeeData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMsg = null;
      });
      final res = await ApiService.instance.get(ApiEndpoints.myFeeStatus);

      if (res['success'] == true) {
        final summary = res['summary'] as Map? ?? {};
        final outstanding = (summary['totalOutstanding'] ??
            summary['totalPending'] ??
            ((summary['totalFees'] ?? 0) - (summary['totalPaid'] ?? 0))) as num;

        _totalOutstanding = outstanding.toDouble();
        _studentId = res['studentId'] as String? ?? '';
        _feeStructureId = (res['feeStructureId'] ?? res['ledger']?['feeStructureId'] ?? '') as String;
        _ledgerId = (res['ledgerId'] ?? res['ledger']?['id'] ?? '') as String;
        _academicYearId = (res['academicYearId'] ?? res['ledger']?['academicYearId'] ?? '') as String;

        // Build fee breakdown items
        final feeComponents = res['feeComponents'] as List? ??
            res['components'] as List? ??
            res['breakdown'] as List? ?? [];

        if (feeComponents.isNotEmpty) {
          _feeItems = feeComponents.map<Map<String, String>>((c) {
            final name = (c['name'] ?? c['componentName'] ?? c['type'] ?? 'Fee').toString();
            final amt = (c['amount'] ?? c['originalAmount'] ?? 0) as num;
            return {'label': name, 'amount': '₹${amt.toInt()}'};
          }).toList();
        } else {
          // Show total only if breakdown not available
          _feeItems = [{'label': 'Total Fees Due', 'amount': '₹${_totalOutstanding.toInt()}'}];
        }

        // Build payment history
        final payments = res['payments'] as List? ??
            res['transactions'] as List? ?? [];
        _paymentHistory = payments.map<Map<String, String>>((p) {
          final desc = (p['description'] ?? p['term'] ?? p['remarks'] ?? 'Payment').toString();
          final amt = (p['amount'] ?? p['paidAmount'] ?? 0) as num;
          final dateStr = p['paidAt'] ?? p['createdAt'] ?? p['date'] ?? '';
          String formattedDate = dateStr.toString().split('T').first;
          return {
            'term': desc,
            'date': formattedDate,
            'amount': '₹${amt.toInt()}',
            'status': 'Paid',
          };
        }).toList();
      } else {
        _errorMsg = res['message'] as String? ?? 'Could not load fee data';
      }
    } catch (e) {
      dev.log('FeesScreen: Error loading fee data: $e', name: 'FeesScreen');
      _errorMsg = 'Unable to load fee information. Please check your connection.';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))),
      );
    }
    if (_errorMsg != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off_rounded, size: 60, color: Color(0xFFCBD5E1)),
                const SizedBox(height: 16),
                Text('Unable to load fees', style: AppTypography.h4.copyWith(color: const Color(0xFF0F172A))),
                const SizedBox(height: 8),
                Text(_errorMsg!, textAlign: TextAlign.center, style: AppTypography.small.copyWith(color: const Color(0xFF64748B))),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _loadFeeData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                ),
              ],
            ),
          ),
        ),
      );
    }
    switch (_view) {
      case 'qr':
        return _QRPaymentPage(onPaid: () => setState(() => _view = 'success'));
      case 'success':
        return _SuccessPage(onBack: () => Navigator.pop(context));
      default:
        return _OverviewPage(
          onPayNow: () => setState(() => _view = 'qr'),
          feeItems: _feeItems,
          paymentHistory: _paymentHistory,
          totalOutstanding: _totalOutstanding,
          onRefresh: _loadFeeData,
        );
    }
  }
}



// ─── OVERVIEW PAGE ────────────────────────────────────────────────────────────
class _OverviewPage extends StatelessWidget {
  final VoidCallback onPayNow;
  final List<Map<String, String>> feeItems;
  final List<Map<String, String>> paymentHistory;
  final double totalOutstanding;
  final RefreshCallback onRefresh;

  const _OverviewPage({
    required this.onPayNow,
    required this.feeItems,
    required this.paymentHistory,
    required this.totalOutstanding,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final items = feeItems;
    final history = paymentHistory;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PageHeader(
            title: 'Fee Payment',
            subtitle: 'Academic Year 2025-26',
            theme: roleThemes['student']!,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: onRefresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(16.r),
                child: Column(
                  children: [
                  // Fee Summary Card
                  Container(
                    padding: EdgeInsets.all(20.r),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24.r),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4))
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Fee Summary',
                                  style: AppTypography.body
                                      .copyWith(color: AppColors.textDark)),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 10.w, vertical: 4.h),
                                decoration: BoxDecoration(
                                    color: Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(20.r)),
                                child: Row(children: [
                                  Icon(Icons.warning_amber_rounded,
                                      size: 14.sp,
                                      color: Colors.amber.shade700),
                                  SizedBox(width: 4.w),
                                  Text('Due',
                                      style: AppTypography.caption.copyWith(
                                          color: Colors.amber.shade700)),
                                ]),
                              ),
                            ]),
                        SizedBox(height: 16.h),
                        ...items.map((f) => Padding(
                              padding: EdgeInsets.only(bottom: 12.h),
                              child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(f['label']!,
                                        style: AppTypography.small.copyWith(
                                            color: AppColors.textMedium)),
                                    Text(f['amount']!,
                                        style: AppTypography.small.copyWith(
                                            color: AppColors.textDark)),
                                  ]),
                            )),
                        Divider(height: 20.h),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 16.w, vertical: 14.h),
                          decoration: BoxDecoration(
                              color: AppColors.studentLight,
                              borderRadius: BorderRadius.circular(16.r)),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Total Due',
                                    style: AppTypography.body.copyWith(
                                        color: AppColors.studentPrimary)),
                                Text('₹${totalOutstanding.toInt()}',
                                    style: AppTypography.h4.copyWith(
                                        color: AppColors.studentPrimary)),
                              ]),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Pay Now Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onPayNow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.studentPrimary,
                        padding: EdgeInsets.symmetric(vertical: 18.h),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18.r)),
                        elevation: 4,
                        shadowColor:
                            AppColors.studentPrimary.withValues(alpha: 0.4),
                      ),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Pay Now',
                                style: AppTypography.body
                                    .copyWith(color: Colors.white)),
                            SizedBox(width: 8.w),
                            Icon(Icons.arrow_forward_rounded,
                                color: Colors.white, size: 20.sp),
                          ]),
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // Payment History
                  Row(children: [
                    Text('PAYMENT HISTORY',
                        style: AppTypography.caption.copyWith(
                            color: AppColors.textDark, letterSpacing: 0.8)),
                  ]),
                  SizedBox(height: 12.h),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: history.asMap().entries.map((e) {
                        final p = e.value;
                        final isLast = e.key == history.length - 1;
                        return Container(
                          padding: EdgeInsets.all(16.r),
                          decoration: BoxDecoration(
                            border: isLast
                                ? null
                                : Border(
                                    bottom: BorderSide(
                                        color: AppColors.border, width: 0.5.w)),
                          ),
                          child: Row(children: [
                            Container(
                              width: 44.w,
                              height: 44.h,
                              decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(12.r)),
                              child: Icon(Icons.receipt_long_rounded,
                                  color: const Color(0xFF10B981), size: 22.sp),
                            ),
                            SizedBox(width: 14.w),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(p['term']!,
                                      style: AppTypography.small
                                          .copyWith(color: AppColors.textDark)),
                                  Text(p['date']!,
                                      style: AppTypography.caption.copyWith(
                                          color: AppColors.textLight)),
                                ])),
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(p['amount']!,
                                      style: AppTypography.small
                                          .copyWith(color: AppColors.textDark)),
                                  SizedBox(height: 3.h),
                                  Row(children: [
                                    Icon(Icons.check_circle_rounded,
                                        color: const Color(0xFF10B981),
                                        size: 14.sp),
                                    SizedBox(width: 3.w),
                                    Text(p['status']!,
                                        style: AppTypography.caption.copyWith(
                                            color: const Color(0xFF10B981))),
                                  ]),
                                ]),
                          ]),
                        );
                      }).toList(),
                    ),
                  ),
                  SizedBox(height: 80.h),
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

// ─── QR PAYMENT PAGE ──────────────────────────────────────────────────────────
class _QRPaymentPage extends StatefulWidget {
  final VoidCallback onPaid;
  const _QRPaymentPage({required this.onPaid});
  @override
  State<_QRPaymentPage> createState() => _QRPaymentPageState();
}

class _QRPaymentPageState extends State<_QRPaymentPage>
    with SingleTickerProviderStateMixin {
  bool _verifying = false;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.95, end: 1.05)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _onPaymentDone() async {
    setState(() => _verifying = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) widget.onPaid();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header
          Container(
            decoration:
                BoxDecoration(gradient: roleThemes['student']!.gradient),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 20.h),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40.w,
                      height: 40.h,
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12.r)),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 18.sp),
                    ),
                  ),
                  SizedBox(width: 14.w),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Scan & Pay',
                            style: AppTypography.bodyLarge
                                .copyWith(color: Colors.white)),
                        Text('UPI / PhonePe / GPay / Paytm',
                            style: AppTypography.caption.copyWith(
                                color: Colors.white.withValues(alpha: 0.7))),
                      ]),
                ]),
              ),
            ),
          ),

          Expanded(
            child: _verifying ? _buildVerifying() : _buildQRContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildQRContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(height: 20.h),

          // Amount chip
          Container(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: AppColors.studentLight,
              borderRadius: BorderRadius.circular(30.r),
              border: Border.all(
                  color: AppColors.studentPrimary.withValues(alpha: 0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.currency_rupee_rounded,
                  color: AppColors.studentPrimary, size: 18.sp),
              Text('12,500',
                  style: AppTypography.h4
                      .copyWith(color: AppColors.studentPrimary)),
              SizedBox(width: 8.w),
              Text('Term 2 Fee',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.studentPrimary)),
            ]),
          ),
          SizedBox(height: 8.h),
          Text('EduSphere School • Academic 2025-26',
              style:
                  AppTypography.caption.copyWith(color: AppColors.textLight)),
          SizedBox(height: 24.h),

          // QR Code with pulse animation
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.w),
            child: ScaleTransition(
              scale: _pulse,
              child: Container(
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24.r),
                  border: Border.all(
                      color: AppColors.studentPrimary.withValues(alpha: 0.3),
                      width: 2.w),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.studentPrimary.withValues(alpha: 0.15),
                        blurRadius: 30,
                        spreadRadius: 2),
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 20),
                  ],
                ),
                child: Column(
                  children: [
                    // Bank info row
                    Row(children: [
                      Container(
                        width: 36.w,
                        height: 36.h,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A6FDB),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: const Color(0xFF1A6FDB)
                                    .withValues(alpha: 0.3),
                                blurRadius: 8)
                          ],
                        ),
                        child: Icon(Icons.account_balance_rounded,
                            color: Colors.white, size: 18.sp),
                      ),
                      SizedBox(width: 10.w),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('State Bank of India',
                                style: AppTypography.caption
                                    .copyWith(color: AppColors.textDark)),
                            Text('EduSphere School Account',
                                style: AppTypography.caption
                                    .copyWith(color: AppColors.textLight)),
                          ]),
                    ]),
                    SizedBox(height: 14.h),
                    Divider(height: 1.h),
                    SizedBox(height: 14.h),

                    // QR Image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12.r),
                      child: Image.asset(
                        'assets/images/qr_payment.png',
                        width: double.infinity,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          width: double.infinity,
                          height: 220.h,
                          color: Colors.grey.shade100,
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.qr_code_2_rounded,
                                    size: 80.sp, color: Colors.black87),
                                SizedBox(height: 8.h),
                                Text('QR Code',
                                    style: GoogleFonts.inter(
                                        color: AppColors.textMedium)),
                              ]),
                        ),
                      ),
                    ),
                    SizedBox(height: 14.h),

                    // Scan instruction
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                      decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10.r)),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.qr_code_scanner_rounded,
                                size: 16.sp, color: AppColors.studentPrimary),
                            SizedBox(width: 6.w),
                            Text('Scan with any UPI app to pay',
                                style: AppTypography.caption
                                    .copyWith(color: AppColors.textMedium)),
                          ]),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 24.h),

          // "I have paid" button
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.w),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _onPaymentDone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r)),
                  elevation: 4,
                  shadowColor: const Color(0xFF10B981).withValues(alpha: 0.4),
                ),
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.check_circle_rounded,
                      color: Colors.white, size: 22.sp),
                  SizedBox(width: 10.w),
                  Text('I Have Paid',
                      style: AppTypography.body.copyWith(color: Colors.white)),
                ]),
              ),
            ),
          ),
          SizedBox(height: 12.h),

          // Security note
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.w),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.lock_rounded, size: 13.sp, color: AppColors.textLight),
              SizedBox(width: 5.w),
              Text('256-bit SSL encrypted • Secure payment',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textLight)),
            ]),
          ),
          SizedBox(height: 32.h),
        ],
      ),
    );
  }

  Widget _buildVerifying() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100.w,
            height: 100.h,
            decoration: BoxDecoration(
              color: AppColors.studentLight,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: AppColors.studentPrimary.withValues(alpha: 0.2),
                    blurRadius: 30)
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(24.r),
              child: const CircularProgressIndicator(
                  color: AppColors.studentPrimary, strokeWidth: 4),
            ),
          ),
          SizedBox(height: 24.h),
          Text('Verifying Payment...',
              style: AppTypography.h4.copyWith(color: AppColors.textDark)),
          SizedBox(height: 8.h),
          Text('Please wait while we confirm\nyour transaction',
              style: AppTypography.small
                  .copyWith(color: AppColors.textMedium, height: 1.5.h),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ─── SUCCESS PAGE ─────────────────────────────────────────────────────────────
class _SuccessPage extends StatefulWidget {
  final VoidCallback onBack;
  const _SuccessPage({required this.onBack});
  @override
  State<_SuccessPage> createState() => _SuccessPageState();
}

class _SuccessPageState extends State<_SuccessPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _scale = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _fade = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txnId =
        'TXN${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(28.r),
          child: FadeTransition(
            opacity: _fade,
            child: Column(
              children: [
                SizedBox(height: 32.h),

                // Success icon with animation
                ScaleTransition(
                  scale: _scale,
                  child: Container(
                    width: 120.w,
                    height: 120.h,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color:
                                const Color(0xFF10B981).withValues(alpha: 0.4),
                            blurRadius: 30,
                            spreadRadius: 4)
                      ],
                    ),
                    child: Icon(Icons.check_rounded,
                        color: Colors.white, size: 60.sp),
                  ),
                ),
                SizedBox(height: 28.h),

                Text('Payment Successful! 🎉',
                    style: AppTypography.h3.copyWith(color: AppColors.textDark),
                    textAlign: TextAlign.center),
                SizedBox(height: 8.h),
                Text('Your fee has been paid successfully',
                    style: AppTypography.small
                        .copyWith(color: AppColors.textMedium),
                    textAlign: TextAlign.center),
                SizedBox(height: 32.h),

                // Receipt card
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(24.r),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24.r),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 20)
                    ],
                  ),
                  child: Column(
                    children: [
                      // Receipt header
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Payment Receipt',
                                style: AppTypography.body
                                    .copyWith(color: AppColors.textDark)),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 10.w, vertical: 4.h),
                              decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(20.r)),
                              child: Row(children: [
                                Icon(Icons.check_circle_rounded,
                                    color: const Color(0xFF10B981),
                                    size: 14.sp),
                                SizedBox(width: 4.w),
                                Text('Paid',
                                    style: AppTypography.caption.copyWith(
                                        color: const Color(0xFF10B981))),
                              ]),
                            ),
                          ]),
                      SizedBox(height: 20.h),
                      Divider(height: 1.h),
                      SizedBox(height: 16.h),

                      _receiptRow('Amount Paid', '₹12,500', isAmount: true),
                      _receiptRow('Payment Method', 'UPI / QR Code'),
                      _receiptRow('Transaction ID', txnId),
                      _receiptRow('Date & Time', _formatDate()),
                      _receiptRow('Student Name', 'Alex Rivera'),
                      _receiptRow('Class', 'Grade 12-A • Roll #24'),
                      _receiptRow('Fee Type', 'Term 2 Tuition Fee'),
                      _receiptRow('Academic Year', '2025-26'),

                      SizedBox(height: 16.h),
                      Divider(height: 1.h),
                      SizedBox(height: 16.h),

                      // School info
                      Row(children: [
                        Container(
                          width: 40.w,
                          height: 40.h,
                          decoration: BoxDecoration(
                              color: AppColors.studentLight,
                              borderRadius: BorderRadius.circular(10.r)),
                          child: Icon(Icons.school_rounded,
                              color: AppColors.studentPrimary, size: 20.sp),
                        ),
                        SizedBox(width: 12.w),
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('EduSphere School',
                                  style: AppTypography.caption
                                      .copyWith(color: AppColors.textDark)),
                              Text('Powered by EduSphere ERP',
                                  style: AppTypography.caption
                                      .copyWith(color: AppColors.textLight)),
                            ]),
                      ]),
                    ],
                  ),
                ),
                SizedBox(height: 24.h),

                // Download receipt button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => showToast(context, 'Receipt downloaded!'),
                    icon: Icon(Icons.download_rounded, size: 20.sp),
                    label: Text('Download Receipt', style: AppTypography.small),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.studentPrimary,
                      side: BorderSide(
                          color: AppColors.studentPrimary, width: 2.w),
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r)),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),

                // Back to dashboard
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: widget.onBack,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.studentPrimary,
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r)),
                      elevation: 4,
                      shadowColor:
                          AppColors.studentPrimary.withValues(alpha: 0.4),
                    ),
                    child: Text('Back to Dashboard',
                        style:
                            AppTypography.body.copyWith(color: Colors.white)),
                  ),
                ),
                SizedBox(height: 32.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _receiptRow(String key, String value, {bool isAmount = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(key,
              style:
                  AppTypography.caption.copyWith(color: AppColors.textMedium)),
          Text(value,
              style: GoogleFonts.inter(
                fontSize: isAmount ? 18 : 13,
                fontWeight: isAmount ? FontWeight.w900 : FontWeight.w700,
                color: isAmount ? const Color(0xFF10B981) : AppColors.textDark,
              )),
        ],
      ),
    );
  }

  String _formatDate() {
    final now = DateTime.now();
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
    return '${now.day} ${months[now.month - 1]} ${now.year}, ${now.hour}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';
  }
}
