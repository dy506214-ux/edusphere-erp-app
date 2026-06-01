import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import 'fee_payment_screen.dart';

class FeeLedgerScreen extends StatefulWidget {
  final RoleTheme theme;
  const FeeLedgerScreen({super.key, required this.theme});

  @override
  State<FeeLedgerScreen> createState() => _FeeLedgerScreenState();
}

class _FeeLedgerScreenState extends State<FeeLedgerScreen> {
  bool _loading = false;

  // Summary values
  double _totalFee = 0;
  double _totalPaid = 0;
  double get _balance => _totalFee - _totalPaid;

  // Fee heads list
  List<Map<String, dynamic>> _feeHeads = [];

  // Payment history list
  List<Map<String, dynamic>> _paymentHistory = [];

  // Student info
  String _studentName = 'Alex Rivera';
  String _studentId = '';

  // Mock fee heads
  final List<Map<String, dynamic>> _mockFeeHeads = [
    {'name': 'Tuition Fee', 'amount': 45000.0, 'paid': 45000.0, 'status': 'PAID'},
    {'name': 'Laboratory Fee', 'amount': 8000.0, 'paid': 8000.0, 'status': 'PAID'},
    {'name': 'Library & Digital Access', 'amount': 3500.0, 'paid': 2000.0, 'status': 'PARTIAL'},
    {'name': 'Sports & Activities', 'amount': 5000.0, 'paid': 0.0, 'status': 'UNPAID'},
    {'name': 'Technology Fee', 'amount': 4000.0, 'paid': 4000.0, 'status': 'PAID'},
    {'name': 'Annual Development Fund', 'amount': 6500.0, 'paid': 0.0, 'status': 'UNPAID'},
  ];

  // Mock payment history
  final List<Map<String, dynamic>> _mockPaymentHistory = [
    {'date': '2026-05-15', 'amount': 25000.0, 'method': 'UPI', 'receipt': 'RCT-78451290', 'status': 'SUCCESS'},
    {'date': '2026-04-10', 'amount': 20000.0, 'method': 'Net Banking', 'receipt': 'RCT-65320148', 'status': 'SUCCESS'},
    {'date': '2026-03-05', 'amount': 14000.0, 'method': 'Card', 'receipt': 'RCT-42198756', 'status': 'SUCCESS'},
  ];

  @override
  void initState() {
    super.initState();
    _loadLedgerData();
  }

  Future<void> _loadLedgerData() async {
    setState(() {
      _loading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      _studentName = prefs.getString('student_name') ?? 'Alex Rivera';
      _studentId = prefs.getString('student_id') ?? '';

      // Also try Supabase auth user id as fallback
      if (_studentId.isEmpty) {
        final currentUser = Supabase.instance.client.auth.currentUser;
        _studentId = currentUser?.id ?? '';
      }

      if (_studentId.isNotEmpty) {
        // 1. Fetch fee ledger joined with fee_structures
        final ledgerRes = await Supabase.instance.client
            .from('fee_ledgers')
            .select('*, fee_structures(*)')
            .eq('student_id', _studentId);

        final List<Map<String, dynamic>> ledgerData = List<Map<String, dynamic>>.from(ledgerRes);

        if (ledgerData.isNotEmpty) {
          double totalFee = 0;
          double totalPaid = 0;
          final List<Map<String, dynamic>> heads = [];

          for (var entry in ledgerData) {
            final structure = entry['fee_structures'] as Map<String, dynamic>? ?? {};
            final headName = structure['name'] as String? ?? entry['fee_head'] as String? ?? 'Fee';
            final amount = (entry['amount'] as num? ?? structure['amount'] as num? ?? 0).toDouble();
            final paid = (entry['paid_amount'] as num? ?? 0).toDouble();

            String status = 'UNPAID';
            if (paid >= amount && amount > 0) {
              status = 'PAID';
            } else if (paid > 0) {
              status = 'PARTIAL';
            }

            totalFee += amount;
            totalPaid += paid;
            heads.add({'name': headName, 'amount': amount, 'paid': paid, 'status': status});
          }

          _feeHeads = heads;
          _totalFee = totalFee;
          _totalPaid = totalPaid;
        } else {
          _loadMockFeeHeads();
        }

        // 2. Fetch payment history
        final paymentsRes = await Supabase.instance.client
            .from('fee_payments')
            .select()
            .eq('student_id', _studentId)
            .order('payment_date', ascending: false);

        final List<Map<String, dynamic>> paymentsData = List<Map<String, dynamic>>.from(paymentsRes);

        if (paymentsData.isNotEmpty) {
          _paymentHistory = paymentsData.map((p) {
            return {
              'date': p['payment_date'] as String? ?? '',
              'amount': (p['amount'] as num? ?? 0).toDouble(),
              'method': p['payment_method'] as String? ?? 'UPI',
              'receipt': p['receipt_number'] as String? ?? 'RCT-00000000',
              'status': p['status'] as String? ?? 'SUCCESS',
            };
          }).toList();
        } else {
          _paymentHistory = _mockPaymentHistory;
        }

        setState(() {});
        return;
      }

      // No student ID available → load mock
      _loadMockFeeHeads();
      _paymentHistory = _mockPaymentHistory;
    } catch (e) {
      _loadMockFeeHeads();
      _paymentHistory = _mockPaymentHistory;
      debugPrint('Error loading fee ledger: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _loadMockFeeHeads() {
    _feeHeads = _mockFeeHeads;
    _totalFee = 0;
    _totalPaid = 0;
    for (var h in _feeHeads) {
      _totalFee += h['amount'] as double;
      _totalPaid += h['paid'] as double;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final parsed = DateTime.parse(dateStr);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${parsed.day.toString().padLeft(2, '0')} ${months[parsed.month - 1]} ${parsed.year}';
    } catch (e) {
      return dateStr;
    }
  }

  String _formatCurrency(double amount) {
    if (amount >= 100000) {
      return '₹${(amount / 1000).toStringAsFixed(1)}K';
    }
    final str = amount.toStringAsFixed(0);
    // Add commas for Indian numbering
    final parts = <String>[];
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      parts.insert(0, str[i]);
      count++;
      if (count == 3 && i > 0) {
        parts.insert(0, ',');
        count = 0;
      }
    }
    return '₹${parts.join('')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PageHeader(
            title: 'Fee Ledger',
            subtitle: 'Academic Year 2025-26',
            theme: widget.theme,
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.studentPrimary))
                : RefreshIndicator(
                    onRefresh: _loadLedgerData,
                    color: widget.theme.primary,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(16.r),
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── TOP SUMMARY CARD ──
                          _buildSummaryCard(),
                          SizedBox(height: 20.h),

                          // ── FEE HEADS ──
                          const SectionTitle(title: '📋 Fee Breakdown'),
                          SizedBox(height: 12.h),
                          _buildFeeHeadsList(),
                          SizedBox(height: 24.h),

                          // ── PAYMENT HISTORY ──
                          const SectionTitle(title: '💳 Payment History'),
                          SizedBox(height: 12.h),
                          _buildPaymentHistoryList(),
                          SizedBox(height: 24.h),

                          // ── PAY NOW BUTTON ──
                          if (_balance > 0) ...[
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: widget.theme.primary,
                                  padding: EdgeInsets.symmetric(vertical: 18.h),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.r)),
                                  elevation: 4,
                                  shadowColor: widget.theme.primary.withValues(alpha: 0.4),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => FeePaymentScreen(
                                        theme: widget.theme,
                                        outstandingAmount: _balance,
                                      ),
                                    ),
                                  ).then((_) => _loadLedgerData());
                                },
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.payment_rounded, color: Colors.white, size: 22.sp),
                                    SizedBox(width: 10.w),
                                    Text(
                                      'Pay Now • ${_formatCurrency(_balance)}',
                                      style: GoogleFonts.inter(fontSize: 17.sp, fontWeight: FontWeight.w900, color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ] else ...[
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(18.r),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(18.r),
                                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_rounded, color: const Color(0xFF10B981), size: 22.sp),
                                  SizedBox(width: 10.w),
                                  Text(
                                    'All Fees Cleared! No Balance Due',
                                    style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w800, color: const Color(0xFF10B981)),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          SizedBox(height: 40.h),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final hasBalance = _balance > 0;
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12.r, offset: Offset(0, 4.h)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Fee Summary', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppColors.textDark, fontSize: 16.sp)),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: hasBalance ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Row(
                  children: [
                    Icon(
                      hasBalance ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                      size: 14.sp,
                      color: hasBalance ? AppColors.error : const Color(0xFF10B981),
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      hasBalance ? 'Balance Due' : 'Cleared',
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                        color: hasBalance ? AppColors.error : const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            _studentName,
            style: GoogleFonts.inter(fontSize: 13.sp, color: AppColors.textMedium, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 16.h),

          // Three column summary
          Row(
            children: [
              Expanded(child: _summaryColumn('Total Fee', _formatCurrency(_totalFee), widget.theme.primary)),
              Container(width: 1.w, height: 50.h, color: AppColors.border),
              Expanded(child: _summaryColumn('Paid', _formatCurrency(_totalPaid), const Color(0xFF10B981))),
              Container(width: 1.w, height: 50.h, color: AppColors.border),
              Expanded(
                child: _summaryColumn(
                  'Balance',
                  _formatCurrency(_balance),
                  _balance > 0 ? AppColors.error : const Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryColumn(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(label.toUpperCase(), style: GoogleFonts.inter(fontSize: 9.sp, color: AppColors.textLight, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        SizedBox(height: 6.h),
        Text(value, style: GoogleFonts.inter(fontSize: 18.sp, fontWeight: FontWeight.w900, color: valueColor)),
      ],
    );
  }

  Widget _buildFeeHeadsList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10.r, offset: Offset(0, 4.h)),
        ],
      ),
      child: Column(
        children: [
          // Table header
          Container(
            padding: EdgeInsets.all(14.r),
            decoration: BoxDecoration(
              color: widget.theme.primary,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
            ),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('Fee Head', style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w900, color: Colors.white))),
                Expanded(flex: 2, child: Text('Amount', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w900, color: Colors.white))),
                Expanded(flex: 2, child: Text('Paid', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w900, color: Colors.white))),
                Expanded(flex: 2, child: Text('Status', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w900, color: Colors.white))),
              ],
            ),
          ),

          // Fee head rows
          ..._feeHeads.asMap().entries.map((entry) {
            final index = entry.key;
            final head = entry.value;
            final name = head['name'] as String;
            final amount = head['amount'] as double;
            final paid = head['paid'] as double;
            final status = head['status'] as String;

            Color statusColor = AppColors.error;
            Color statusBg = const Color(0xFFFEF2F2);
            if (status == 'PAID') {
              statusColor = const Color(0xFF10B981);
              statusBg = const Color(0xFFECFDF5);
            } else if (status == 'PARTIAL') {
              statusColor = AppColors.warning;
              statusBg = const Color(0xFFFFFBEB);
            }

            return Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: index.isEven ? Colors.white : AppColors.background,
                border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5.w)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(name, style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(_formatCurrency(amount), textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12.sp, color: AppColors.textMedium, fontWeight: FontWeight.w600)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(_formatCurrency(paid), textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12.sp, color: AppColors.textDark, fontWeight: FontWeight.w700)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6.r)),
                        child: Text(status, style: GoogleFonts.inter(fontSize: 9.sp, fontWeight: FontWeight.w900, color: statusColor)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPaymentHistoryList() {
    if (_paymentHistory.isEmpty) {
      return Container(
        padding: EdgeInsets.all(24.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.receipt_long_rounded, size: 36.sp, color: AppColors.textLight),
              SizedBox(height: 8.h),
              Text('No payment history found', style: GoogleFonts.inter(fontSize: 13.sp, color: AppColors.textMedium, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: _paymentHistory.asMap().entries.map((entry) {
          final index = entry.key;
          final payment = entry.value;
          final date = _formatDate(payment['date'] as String?);
          final amount = payment['amount'] as double;
          final method = payment['method'] as String;
          final receipt = payment['receipt'] as String;
          final isLast = index == _paymentHistory.length - 1;

          IconData methodIcon = Icons.account_balance_wallet_rounded;
          Color methodColor = const Color(0xFF7C3AED);
          if (method == 'UPI') {
            methodIcon = Icons.qr_code_rounded;
            methodColor = const Color(0xFF7C3AED);
          } else if (method == 'Net Banking') {
            methodIcon = Icons.account_balance_rounded;
            methodColor = const Color(0xFF2563EB);
          } else if (method == 'Card') {
            methodIcon = Icons.credit_card_rounded;
            methodColor = const Color(0xFFEC4899);
          }

          return Container(
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              border: isLast ? null : Border(bottom: BorderSide(color: AppColors.border, width: 0.5.w)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44.w,
                  height: 44.h,
                  decoration: BoxDecoration(
                    color: methodColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(methodIcon, color: methodColor, size: 22.sp),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(method, style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: AppColors.textDark, fontSize: 14.sp)),
                      SizedBox(height: 2.h),
                      Text('$date • $receipt', style: GoogleFonts.inter(fontSize: 11.sp, color: AppColors.textLight, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_formatCurrency(amount), style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppColors.textDark, fontSize: 14.sp)),
                    SizedBox(height: 3.h),
                    Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: const Color(0xFF10B981), size: 14.sp),
                        SizedBox(width: 3.w),
                        Text('Success', style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w700, color: const Color(0xFF10B981))),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
