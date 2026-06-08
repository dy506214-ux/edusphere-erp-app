import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';

class FeePaymentScreen extends StatefulWidget {
  final RoleTheme theme;
  final double outstandingAmount;
  final String studentId;
  final String feeStructureId;
  final String ledgerId;
  final String academicYearId;

  const FeePaymentScreen({
    super.key,
    required this.theme,
    required this.outstandingAmount,
    required this.studentId,
    required this.feeStructureId,
    required this.ledgerId,
    required this.academicYearId,
  });

  @override
  State<FeePaymentScreen> createState() => _FeePaymentScreenState();
}

class _FeePaymentScreenState extends State<FeePaymentScreen> with TickerProviderStateMixin {
  String _selectedMethod = 'UPI';
  bool _processing = false;
  bool _paymentSuccess = false;
  late AnimationController _successAnimController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  final TextEditingController _upiIdController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  String _receiptNumber = '';
  String _transactionId = '';

  final List<Map<String, dynamic>> _paymentMethods = const [
    {'id': 'UPI', 'label': 'UPI', 'icon': Icons.qr_code_rounded, 'color': Color(0xFF7C3AED), 'desc': 'Pay via Google Pay, PhonePe, etc.'},
    {'id': 'Card', 'label': 'Debit / Credit Card', 'icon': Icons.credit_card_rounded, 'color': Color(0xFFEC4899), 'desc': 'Visa, MasterCard, Rupay'},
    {'id': 'Net Banking', 'label': 'Net Banking', 'icon': Icons.account_balance_rounded, 'color': Color(0xFF2563EB), 'desc': 'All major banks supported'},
  ];

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.outstandingAmount.toStringAsFixed(0);

    _successAnimController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _scaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _successAnimController, curve: Curves.elasticOut));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _successAnimController, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _successAnimController.dispose();
    _upiIdController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  String _generateUUID() {
    final random = Random();
    const hexDigits = '0123456789abcdef';
    String genHex(int len) => List.generate(len, (_) => hexDigits[random.nextInt(16)]).join();
    return '${genHex(8)}-${genHex(4)}-4${genHex(3)}-${hexDigits[8 + random.nextInt(4)]}${genHex(3)}-${genHex(12)}';
  }

  String _formatCurrency(double amount) {
    final str = amount.toStringAsFixed(0);
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

  String _generateReceiptNumber() {
    final rand = Random();
    final num = rand.nextInt(90000000) + 10000000;
    return 'RCT-$num';
  }

  String _generateTransactionId() {
    final rand = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final id = List.generate(12, (_) => chars[rand.nextInt(chars.length)]).join();
    return 'TXN$id';
  }

  Future<void> _processPayment() async {
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) {
      showToast(context, 'Please enter a valid amount', isError: true);
      return;
    }
    if (amount > widget.outstandingAmount) {
      showToast(context, 'Amount cannot exceed outstanding balance', isError: true);
      return;
    }
    if (_selectedMethod == 'UPI' && _upiIdController.text.trim().isEmpty) {
      showToast(context, 'Please enter your UPI ID', isError: true);
      return;
    }

    setState(() => _processing = true);

    _receiptNumber = _generateReceiptNumber();
    _transactionId = _generateTransactionId();

    // Simulate processing delay
    await Future.delayed(const Duration(seconds: 2));

    try {
      final paymentId = _generateUUID();
      final mode = _selectedMethod == 'UPI' ? 'UPI' : (_selectedMethod == 'Card' ? 'CARD' : 'NET_BANKING');
      
      // 1. Insert into FeePayment
      await Supabase.instance.client.from('FeePayment').insert({
        'id': paymentId,
        'receiptNumber': _receiptNumber,
        'studentId': widget.studentId,
        'feeStructureId': widget.feeStructureId,
        'ledgerId': widget.ledgerId,
        'academicYearId': widget.academicYearId,
        'amount': amount,
        'discount': 0.0,
        'penalty': 0.0,
        'totalAmount': amount,
        'paymentType': 'RECEIPT',
        'paymentDate': DateTime.now().toIso8601String(),
        'paymentMode': mode,
        'transactionId': _transactionId,
        'status': 'COMPLETED',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // 2. Fetch and update StudentFeeLedger
      final ledgerRes = await Supabase.instance.client
          .from('StudentFeeLedger')
          .select()
          .eq('id', widget.ledgerId)
          .maybeSingle();

      if (ledgerRes != null) {
        final double currentPaid = (ledgerRes['totalPaid'] ?? 0.0).toDouble();
        final double totalPayable = (ledgerRes['totalPayable'] ?? 0.0).toDouble();
        final double newPaid = currentPaid + amount;
        final double newPending = (totalPayable - newPaid).clamp(0.0, double.infinity);
        final String newStatus = newPending <= 0 ? 'PAID' : 'PARTIALLY_PAID';

        await Supabase.instance.client.from('StudentFeeLedger').update({
          'totalPaid': newPaid,
          'totalPending': newPending,
          'status': newStatus,
          'updatedAt': DateTime.now().toIso8601String(),
        }).eq('id', widget.ledgerId);
      }
    } catch (e) {
      debugPrint('Error recording payment: $e');
    }

    if (mounted) {
      setState(() {
        _processing = false;
        _paymentSuccess = true;
      });
      _successAnimController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_paymentSuccess) {
      return _buildSuccessScreen();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PageHeader(
            title: 'Fee Payment',
            subtitle: 'Secure Payment Gateway',
            theme: widget.theme,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── AMOUNT CARD ──
                  _buildAmountCard(),
                  SizedBox(height: 20.h),

                  // ── PAYMENT METHOD ──
                  const SectionTitle(title: '💳 Payment Method'),
                  SizedBox(height: 12.h),
                  ..._paymentMethods.map((m) => _buildMethodTile(m)),
                  SizedBox(height: 20.h),

                  // ── PAYMENT DETAILS ──
                  if (_selectedMethod == 'UPI') ...[
                    const SectionTitle(title: '🔗 UPI Details'),
                    SizedBox(height: 12.h),
                    _buildUpiInput(),
                    SizedBox(height: 20.h),
                  ],

                  // ── FEE BREAKDOWN ──
                  const SectionTitle(title: '📄 Payment Summary'),
                  SizedBox(height: 12.h),
                  _buildBreakdownCard(),
                  SizedBox(height: 28.h),

                  // ── PAY BUTTON ──
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.theme.primary,
                        padding: EdgeInsets.symmetric(vertical: 18.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.r)),
                        elevation: 6,
                        shadowColor: widget.theme.primary.withValues(alpha: 0.4),
                      ),
                      onPressed: _processing ? null : _processPayment,
                      child: _processing
                          ? SizedBox(
                              height: 22.h,
                              width: 22.w,
                              child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.lock_rounded, color: Colors.white, size: 20.sp),
                                SizedBox(width: 10.w),
                                Text(
                                  'Pay Securely',
                                  style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.w900, color: Colors.white),
                                ),
                              ],
                            ),
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Security badge
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shield_rounded, size: 14.sp, color: AppColors.textLight),
                        SizedBox(width: 6.w),
                        Text(
                          '256-bit SSL encrypted • PCI DSS Compliant',
                          style: GoogleFonts.inter(fontSize: 11.sp, color: AppColors.textLight, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 30.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [widget.theme.primary, widget.theme.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(color: widget.theme.primary.withValues(alpha: 0.3), blurRadius: 16.r, offset: Offset(0, 6.h)),
        ],
      ),
      child: Column(
        children: [
          Text('AMOUNT TO PAY', style: GoogleFonts.inter(fontSize: 11.sp, color: Colors.white70, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
          SizedBox(height: 8.h),
          Text(
            _formatCurrency(widget.outstandingAmount),
            style: GoogleFonts.inter(fontSize: 34.sp, fontWeight: FontWeight.w900, color: Colors.white),
          ),
          SizedBox(height: 12.h),

          // Editable amount field
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('₹', style: GoogleFonts.inter(fontSize: 16.sp, color: Colors.white, fontWeight: FontWeight.w800)),
                SizedBox(width: 6.w),
                SizedBox(
                  width: 100.w,
                  child: TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 18.sp, color: Colors.white, fontWeight: FontWeight.w900),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: '0',
                      hintStyle: GoogleFonts.inter(fontSize: 18.sp, color: Colors.white38),
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 6.h),
          Text('Edit amount if paying partially', style: GoogleFonts.inter(fontSize: 11.sp, color: Colors.white60, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildMethodTile(Map<String, dynamic> method) {
    final id = method['id'] as String;
    final isSelected = _selectedMethod == id;
    final color = method['color'] as Color;

    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        margin: EdgeInsets.only(bottom: 10.h),
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: isSelected ? color : AppColors.border, width: isSelected ? 2 : 1),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 10.r, offset: Offset(0, 3.h))]
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6.r)],
        ),
        child: Row(
          children: [
            Container(
              width: 46.w,
              height: 46.h,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Icon(method['icon'] as IconData, color: color, size: 24.sp),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(method['label'] as String, style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: AppColors.textDark, fontSize: 14.sp)),
                  SizedBox(height: 2.h),
                  Text(method['desc'] as String, style: GoogleFonts.inter(fontSize: 11.sp, color: AppColors.textLight, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 24.w,
              height: 24.h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? color : Colors.transparent,
                border: Border.all(color: isSelected ? color : AppColors.textLight, width: 2),
              ),
              child: isSelected ? Icon(Icons.check_rounded, color: Colors.white, size: 14.sp) : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpiInput() {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Enter UPI ID', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textDark, fontSize: 13.sp)),
          SizedBox(height: 10.h),
          TextField(
            controller: _upiIdController,
            style: GoogleFonts.inter(fontSize: 15.sp, fontWeight: FontWeight.w700, color: AppColors.textDark),
            decoration: InputDecoration(
              hintText: 'yourname@upi',
              hintStyle: GoogleFonts.inter(fontSize: 14.sp, color: AppColors.textLight),
              prefixIcon: Icon(Icons.alternate_email_rounded, color: const Color(0xFF7C3AED), size: 20.sp),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14.r), borderSide: BorderSide.none),
              contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
            ),
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              _quickUpiChip('Google Pay'),
              SizedBox(width: 8.w),
              _quickUpiChip('PhonePe'),
              SizedBox(width: 8.w),
              _quickUpiChip('Paytm'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickUpiChip(String name) {
    return GestureDetector(
      onTap: () {
        _upiIdController.text = '${name.toLowerCase().replaceAll(' ', '')}@upi';
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Text(name, style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w700, color: const Color(0xFF7C3AED))),
      ),
    );
  }

  Widget _buildBreakdownCard() {
    final amount = double.tryParse(_amountController.text) ?? widget.outstandingAmount;
    const convenienceFee = 0.0; // No extra fee
    final total = amount + convenienceFee;

    return Container(
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _breakdownRow('Fee Amount', _formatCurrency(amount), false),
          SizedBox(height: 10.h),
          _breakdownRow('Convenience Fee', 'FREE', false, isGreen: true),
          SizedBox(height: 10.h),
          Divider(color: AppColors.border, height: 1.h),
          SizedBox(height: 10.h),
          _breakdownRow('Total Payable', _formatCurrency(total), true),
        ],
      ),
    );
  }

  Widget _breakdownRow(String label, String value, bool isBold, {bool isGreen = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(
          fontSize: isBold ? 14.sp : 13.sp,
          fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
          color: isBold ? AppColors.textDark : AppColors.textMedium,
        )),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: isBold ? 16.sp : 13.sp,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
            color: isGreen ? const Color(0xFF10B981) : (isBold ? widget.theme.primary : AppColors.textDark),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: AnimatedBuilder(
            animation: _successAnimController,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnim.value,
                child: Transform.scale(
                  scale: _scaleAnim.value,
                  child: child,
                ),
              );
            },
            child: Padding(
              padding: EdgeInsets.all(32.r),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100.w,
                    height: 100.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check_circle_rounded, color: const Color(0xFF10B981), size: 60.sp),
                  ),
                  SizedBox(height: 28.h),
                  Text('Payment Successful!', style: GoogleFonts.inter(fontSize: 24.sp, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                  SizedBox(height: 8.h),
                  Text(
                    'Your fee payment has been processed',
                    style: GoogleFonts.inter(fontSize: 14.sp, color: AppColors.textMedium, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 32.h),

                  // Receipt card
                  Container(
                    padding: EdgeInsets.all(20.r),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        _receiptRow('Amount Paid', _formatCurrency(double.tryParse(_amountController.text) ?? widget.outstandingAmount)),
                        SizedBox(height: 12.h),
                        _receiptRow('Method', _selectedMethod),
                        SizedBox(height: 12.h),
                        _receiptRow('Receipt No', _receiptNumber),
                        SizedBox(height: 12.h),
                        _receiptRow('Transaction ID', _transactionId),
                        SizedBox(height: 12.h),
                        _receiptRow('Date', _formatTodayDate()),
                      ],
                    ),
                  ),
                  SizedBox(height: 32.h),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.theme.primary,
                        padding: EdgeInsets.symmetric(vertical: 18.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.r)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text('Back to Ledger', style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.w900, color: Colors.white)),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  TextButton(
                    onPressed: () {
                      showToast(context, 'Receipt downloaded');
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.download_rounded, size: 18.sp, color: widget.theme.primary),
                        SizedBox(width: 6.w),
                        Text('Download Receipt', style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w700, color: widget.theme.primary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _receiptRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 13.sp, color: AppColors.textLight, fontWeight: FontWeight.w600)),
        Text(value, style: GoogleFonts.inter(fontSize: 13.sp, color: AppColors.textDark, fontWeight: FontWeight.w800)),
      ],
    );
  }

  String _formatTodayDate() {
    final now = DateTime.now();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${now.day.toString().padLeft(2, '0')} ${months[now.month - 1]} ${now.year}';
  }
}
