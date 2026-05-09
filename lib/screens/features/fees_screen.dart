import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';

class FeesScreen extends StatefulWidget {
  const FeesScreen({super.key});
  @override
  State<FeesScreen> createState() => _FeesScreenState();
}

class _FeesScreenState extends State<FeesScreen> {
  // 'overview' | 'qr' | 'verifying' | 'success'
  String _view = 'overview';

  @override
  Widget build(BuildContext context) {
    switch (_view) {
      case 'qr':        return _QRPaymentPage(onPaid: () => setState(() => _view = 'success'));
      case 'success':   return _SuccessPage(onBack: () => Navigator.pop(context));
      default:          return _OverviewPage(onPayNow: () => setState(() => _view = 'qr'));
    }
  }
}

// ─── OVERVIEW PAGE ────────────────────────────────────────────────────────────
class _OverviewPage extends StatelessWidget {
  final VoidCallback onPayNow;
  const _OverviewPage({required this.onPayNow});

  @override
  Widget build(BuildContext context) {
    final items = [
      {'label': 'Tuition Fee',  'amount': '₹10,000'},
      {'label': 'Lab Fee',      'amount': '₹1,500'},
      {'label': 'Library Fee',  'amount': '₹500'},
      {'label': 'Sports Fee',   'amount': '₹500'},
    ];
    final history = [
      {'term': 'Term 1 Fee',    'date': 'Jan 5, 2026',  'amount': '₹12,500', 'status': 'Paid'},
      {'term': 'Admission Fee', 'date': 'Apr 10, 2025', 'amount': '₹5,000',  'status': 'Paid'},
    ];

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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Fee Summary Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text('Fee Summary', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppColors.textDark, fontSize: 16)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(20)),
                            child: Row(children: [
                              Icon(Icons.warning_amber_rounded, size: 14, color: Colors.amber.shade700),
                              const SizedBox(width: 4),
                              Text('Due', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.amber.shade700)),
                            ]),
                          ),
                        ]),
                        const SizedBox(height: 16),
                        ...items.map((f) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text(f['label']!, style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMedium)),
                            Text(f['amount']!, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                          ]),
                        )),
                        const Divider(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(color: AppColors.studentLight, borderRadius: BorderRadius.circular(16)),
                          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text('Total Due', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppColors.studentPrimary, fontSize: 16)),
                            Text('₹12,500', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.studentPrimary)),
                          ]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Pay Now Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onPayNow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.studentPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        elevation: 4,
                        shadowColor: AppColors.studentPrimary.withOpacity(0.4),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('Pay Now', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white)),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Payment History
                  Row(children: [
                    Text('PAYMENT HISTORY', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textDark, letterSpacing: 0.8)),
                  ]),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: history.asMap().entries.map((e) {
                        final p = e.value;
                        final isLast = e.key == history.length - 1;
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
                          ),
                          child: Row(children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF10B981), size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(p['term']!, style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: AppColors.textDark, fontSize: 14)),
                              Text(p['date']!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textLight)),
                            ])),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text(p['amount']!, style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppColors.textDark, fontSize: 14)),
                              const SizedBox(height: 3),
                              Row(children: [
                                const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 14),
                                const SizedBox(width: 3),
                                Text(p['status']!, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF10B981))),
                              ]),
                            ]),
                          ]),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
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

class _QRPaymentPageState extends State<_QRPaymentPage> with SingleTickerProviderStateMixin {
  bool _verifying = false;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.95, end: 1.05).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _pulseCtrl.dispose(); super.dispose(); }

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
            decoration: BoxDecoration(gradient: roleThemes['student']!.gradient),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Scan & Pay', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                    Text('UPI / PhonePe / GPay / Paytm', style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(0.7))),
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
          const SizedBox(height: 20),

          // Amount chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.studentLight,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppColors.studentPrimary.withOpacity(0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.currency_rupee_rounded, color: AppColors.studentPrimary, size: 18),
              Text('12,500', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.studentPrimary)),
              const SizedBox(width: 8),
              Text('Term 2 Fee', style: GoogleFonts.inter(fontSize: 13, color: AppColors.studentPrimary, fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(height: 8),
          Text('EduSphere School • Academic 2025-26', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textLight)),
          const SizedBox(height: 24),

          // QR Code with pulse animation
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ScaleTransition(
              scale: _pulse,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.studentPrimary.withOpacity(0.3), width: 2),
                  boxShadow: [
                    BoxShadow(color: AppColors.studentPrimary.withOpacity(0.15), blurRadius: 30, spreadRadius: 2),
                    BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20),
                  ],
                ),
                child: Column(
                  children: [
                    // Bank info row
                    Row(children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A6FDB),
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: const Color(0xFF1A6FDB).withOpacity(0.3), blurRadius: 8)],
                        ),
                        child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('State Bank of India', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: AppColors.textDark, fontSize: 13)),
                        Text('EduSphere School Account', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textLight)),
                      ]),
                    ]),
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 14),

                    // QR Image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/images/qr_payment.png',
                        width: double.infinity,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          width: double.infinity,
                          height: 220,
                          color: Colors.grey.shade100,
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(Icons.qr_code_2_rounded, size: 80, color: Colors.black87),
                            const SizedBox(height: 8),
                            Text('QR Code', style: GoogleFonts.inter(color: AppColors.textMedium)),
                          ]),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Scan instruction
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.qr_code_scanner_rounded, size: 16, color: AppColors.studentPrimary),
                        const SizedBox(width: 6),
                        Text('Scan with any UPI app to pay', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMedium)),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // "I have paid" button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _onPaymentDone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  shadowColor: const Color(0xFF10B981).withOpacity(0.4),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Text('I Have Paid', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Security note
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.lock_rounded, size: 13, color: AppColors.textLight),
              const SizedBox(width: 5),
              Text('256-bit SSL encrypted • Secure payment', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textLight)),
            ]),
          ),
          const SizedBox(height: 32),
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
            width: 100, height: 100,
            decoration: BoxDecoration(
              color: AppColors.studentLight,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppColors.studentPrimary.withOpacity(0.2), blurRadius: 30)],
            ),
            child: const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: AppColors.studentPrimary, strokeWidth: 4),
            ),
          ),
          const SizedBox(height: 24),
          Text('Verifying Payment...', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textDark)),
          const SizedBox(height: 8),
          Text('Please wait while we confirm\nyour transaction', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMedium, height: 1.5), textAlign: TextAlign.center),
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

class _SuccessPageState extends State<_SuccessPage> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _scale = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _fade  = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final txnId = 'TXN${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: FadeTransition(
            opacity: _fade,
            child: Column(
              children: [
                const SizedBox(height: 32),

                // Success icon with animation
                ScaleTransition(
                  scale: _scale,
                  child: Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.4), blurRadius: 30, spreadRadius: 4)],
                    ),
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 60),
                  ),
                ),
                const SizedBox(height: 28),

                Text('Payment Successful! 🎉', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textDark), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text('Your fee has been paid successfully', style: GoogleFonts.inter(fontSize: 15, color: AppColors.textMedium), textAlign: TextAlign.center),
                const SizedBox(height: 32),

                // Receipt card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20)],
                  ),
                  child: Column(
                    children: [
                      // Receipt header
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Payment Receipt', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppColors.textDark, fontSize: 16)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(20)),
                          child: Row(children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 14),
                            const SizedBox(width: 4),
                            Text('Paid', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF10B981))),
                          ]),
                        ),
                      ]),
                      const SizedBox(height: 20),
                      const Divider(height: 1),
                      const SizedBox(height: 16),

                      _receiptRow('Amount Paid',    '₹12,500',                    isAmount: true),
                      _receiptRow('Payment Method', 'UPI / QR Code'),
                      _receiptRow('Transaction ID', txnId),
                      _receiptRow('Date & Time',    _formatDate()),
                      _receiptRow('Student Name',   'Alex Rivera'),
                      _receiptRow('Class',          'Grade 12-A • Roll #24'),
                      _receiptRow('Fee Type',       'Term 2 Tuition Fee'),
                      _receiptRow('Academic Year',  '2025-26'),

                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),

                      // School info
                      Row(children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: AppColors.studentLight, borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.school_rounded, color: AppColors.studentPrimary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('EduSphere School', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: AppColors.textDark, fontSize: 13)),
                          Text('Powered by EduSphere ERP', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textLight)),
                        ]),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Download receipt button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => showToast(context, 'Receipt downloaded!'),
                    icon: const Icon(Icons.download_rounded, size: 20),
                    label: Text('Download Receipt', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.studentPrimary,
                      side: const BorderSide(color: AppColors.studentPrimary, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Back to dashboard
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: widget.onBack,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.studentPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                      shadowColor: AppColors.studentPrimary.withOpacity(0.4),
                    ),
                    child: Text('Back to Dashboard', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _receiptRow(String key, String value, {bool isAmount = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(key, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMedium)),
          Text(value, style: GoogleFonts.inter(
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
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${now.day} ${months[now.month-1]} ${now.year}, ${now.hour}:${now.minute.toString().padLeft(2,'0')} ${now.hour >= 12 ? 'PM' : 'AM'}';
  }
}
