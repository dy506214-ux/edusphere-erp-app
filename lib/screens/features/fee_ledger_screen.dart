import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/colors.dart';
import 'fee_payment_screen.dart';
import 'dart:async';
import 'dart:developer' as dev;
import 'dart:math';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../services/api_service.dart';

class FeeLedgerScreen extends StatefulWidget {
  final RoleTheme theme;
  final bool showBackButton;
  const FeeLedgerScreen({super.key, required this.theme, this.showBackButton = true});

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
  String _studentId = '';
  String _studentName = 'Student';
  String _studentEmail = '';
  String _feeStructureId = '';
  String _ledgerId = '';
  String _academicYearId = '';

  RealtimeChannel? _feeChannel;
  Timer? _feePollTimer;

  @override
  void initState() {
    super.initState();
    _loadLedgerData(showLoading: true);
    _connectRealTime();
  }

  @override
  void dispose() {
    _feePollTimer?.cancel();
    if (_feeChannel != null) {
      try {
        Supabase.instance.client.removeChannel(_feeChannel!);
      } catch (_) {}
    }
    super.dispose();
  }

  void _connectRealTime() {
    try {
      final client = Supabase.instance.client;
      if (_feeChannel != null) {
        client.removeChannel(_feeChannel!);
      }
      
      dev.log('📡 Subscribing to Supabase Realtime changes for Fees Screen...', name: 'FeeLedgerScreen');
      _feeChannel = client.channel('public:fee_ledger_screen_sync')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'StudentFeeLedger',
          callback: (payload) {
            dev.log('🔥 Real-time ledger event payload: $payload', name: 'FeeLedgerScreen');
            if (mounted) {
              _loadLedgerData(showLoading: false);
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'FeePayment',
          callback: (payload) {
            dev.log('🔥 Real-time fee payment event payload: $payload', name: 'FeeLedgerScreen');
            if (mounted) {
              _loadLedgerData(showLoading: false);
            }
          },
        );
      
      _feeChannel!.subscribe((status, [error]) {
        dev.log('📡 Supabase Realtime Fees channel status: $status', name: 'FeeLedgerScreen');
        if (error != null) {
          dev.log('❌ Supabase Realtime Fees subscription error: $error', name: 'FeeLedgerScreen');
        }
      });
    } catch (e) {
      dev.log('⚠️ Error connecting Supabase Realtime Fees channel: $e', name: 'FeeLedgerScreen');
    }
    
    // Polling fallback
    _feePollTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadLedgerData(showLoading: false);
      }
    });
  }

  String _generateUUID() {
    final random = Random();
    const hexDigits = '0123456789abcdef';
    String genHex(int len) => List.generate(len, (_) => hexDigits[random.nextInt(16)]).join();
    return '${genHex(8)}-${genHex(4)}-4${genHex(3)}-${hexDigits[8 + random.nextInt(4)]}${genHex(3)}-${genHex(12)}';
  }

  Future<void> _loadLedgerData({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _loading = true;
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      _studentId = prefs.getString('student_id') ?? '';
      _studentName = prefs.getString('student_name') ?? prefs.getString('user_name') ?? 'Student';
      _studentEmail = prefs.getString('student_email') ?? prefs.getString('user_email') ?? '';

      // Call the backend endpoint to get student fee status
      final feeRes = await ApiService.instance.get('fees/students/me/status');

      if (feeRes != null && feeRes['success'] == true) {
        // Resolve student basic details
        if (feeRes['student'] != null) {
          final sObj = feeRes['student'];
          _studentId = sObj['id'] as String? ?? _studentId;
          if (sObj['user'] != null) {
            final uObj = sObj['user'];
            _studentName = '${uObj['firstName'] ?? ''} ${uObj['lastName'] ?? ''}'.trim();
            _studentEmail = uObj['email'] as String? ?? _studentEmail;
          }
        }

        // Process summary
        if (feeRes['summary'] != null) {
          final summary = feeRes['summary'];
          _totalFee = (summary['totalFees'] ?? 0).toDouble();
          _totalPaid = (summary['totalPaid'] ?? 0).toDouble();
        }

        // Process ledgers
        final List<dynamic> ledgers = feeRes['ledgers'] ?? [];
        final List<Map<String, dynamic>> heads = [];

        for (var entry in ledgers) {
          final structure = entry['feeStructure'] as Map<String, dynamic>? ?? {};
          _feeStructureId = structure['id'] as String? ?? '';
          _ledgerId = entry['id'] as String? ?? '';
          if (entry['academicYearId'] != null) {
            _academicYearId = entry['academicYearId'] as String;
          }
          final headName = structure['name'] as String? ?? 'Fee';
          final amount = (entry['totalPayable'] ?? structure['totalAmount'] ?? 0).toDouble();
          final paid = (entry['totalPaid'] ?? 0).toDouble();
          final status = entry['status']?.toString() ?? 'PENDING';

          heads.add({
            'id': entry['id'],
            'name': headName,
            'amount': amount,
            'paid': paid,
            'status': status == 'PAID' ? 'PAID' : (paid > 0 ? 'PARTIAL' : 'PENDING'),
            'feeStructureId': _feeStructureId,
            'academicYearId': _academicYearId,
          });
        }
        _feeHeads = heads;

        // Process recent payments
        final List<dynamic> payments = feeRes['recentPayments'] ?? [];
        _paymentHistory = payments.map((p) {
          return {
            'date': p['paymentDate'] as String? ?? '',
            'amount': (p['amount'] as num? ?? 0).toDouble(),
            'method': p['paymentMode']?.toString() ?? 'UPI',
            'receipt': p['receiptNumber'] as String? ?? 'RCT-00000000',
            'status': p['status']?.toString() ?? 'SUCCESS',
          };
        }).toList();
      } else {
        _feeHeads = [];
        _totalFee = 0;
        _totalPaid = 0;
        _paymentHistory = [];
      }
    } catch (e) {
      _feeHeads = [];
      _totalFee = 0;
      _totalPaid = 0;
      _paymentHistory = [];
      debugPrint('Error loading fee ledger: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
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

  void _showAllFeeHeadsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          ),
          padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 40.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2EAF4),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 24.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Detailed Fee Ledger',
                    style: GoogleFonts.inter(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 20.h),
              if (_feeHeads.isEmpty)
                Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40.h),
                    child: Text(
                      'No fee structures found',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF64748B),
                        fontSize: 14.sp,
                      ),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _feeHeads.length,
                  separatorBuilder: (_, __) => SizedBox(height: 16.h),
                  itemBuilder: (context, index) {
                    final head = _feeHeads[index];
                    final name = head['name'] as String;
                    final amount = head['amount'] as double;
                    final paid = head['paid'] as double;
                    final due = amount - paid;
                    final status = head['status'] as String;

                    Color statusColor = const Color(0xFFEF4444);
                    Color statusBg = const Color(0xFFFEF2F2);
                    if (status == 'PAID') {
                      statusColor = const Color(0xFF10B981);
                      statusBg = const Color(0xFFECFDF5);
                    } else if (status == 'PARTIAL') {
                      statusColor = const Color(0xFFF59E0B);
                      statusBg = const Color(0xFFFFFBEB);
                    }

                    return Container(
                      padding: EdgeInsets.all(16.r),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: const Color(0xFFEFF2F6)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14.sp,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(6.r),
                                ),
                                child: Text(
                                  status,
                                  style: GoogleFonts.inter(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w800,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _bottomSheetStat('Total Amount', _formatCurrency(amount)),
                              _bottomSheetStat('Amount Paid', _formatCurrency(paid), valueColor: const Color(0xFF10B981)),
                              _bottomSheetStat('Amount Due', _formatCurrency(due), valueColor: due > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981)),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _bottomSheetStat(String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.sp,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF64748B),
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
            color: valueColor ?? const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Future<void> _downloadStatement() async {
    // Show a loading snackbar
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text('Generating PDF receipt...', style: GoogleFonts.inter(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
        backgroundColor: const Color(0xFF1A6FDB),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      final pdf = pw.Document();
      final now = DateTime.now();
      final dateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      final receiptNo = 'STMT-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch % 100000}';

      // Colors
      final primaryBlue = PdfColor.fromHex('#1A6FDB');
      final darkText = PdfColor.fromHex('#0F172A');
      final lightGray = PdfColor.fromHex('#F8FAFC');
      final borderGray = PdfColor.fromHex('#E2E8F0');
      final greenColor = PdfColor.fromHex('#10B981');
      final redColor = PdfColor.fromHex('#EF4444');

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              // ── Header ──────────────────────────────────────────
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: primaryBlue,
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('EDUSPHERE',
                            style: pw.TextStyle(
                              fontSize: 22,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            )),
                        pw.SizedBox(height: 4),
                        pw.Text('Smart School ERP',
                             style: const pw.TextStyle(fontSize: 11, color: PdfColors.white)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('FEE STATEMENT',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            )),
                        pw.SizedBox(height: 4),
                        pw.Text('Receipt #: $receiptNo',
                            style: const pw.TextStyle(fontSize: 9, color: PdfColors.white)),
                        pw.Text('Date: $dateStr  $timeStr',
                            style: const pw.TextStyle(fontSize: 9, color: PdfColors.white)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // ── Student Info ──────────────────────────────────
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: lightGray,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: borderGray),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('STUDENT DETAILS',
                              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 6),
                          pw.Text(_studentName.isNotEmpty ? _studentName : 'Student',
                              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: darkText)),
                          if (_studentEmail.isNotEmpty)
                            pw.Text(_studentEmail, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                          pw.Text('Student ID: $_studentId',
                              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                        ],
                      ),
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('FINANCIAL SUMMARY',
                            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 6),
                        pw.Text('Total Fee: ${_formatCurrency(_totalFee)}',
                            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: darkText)),
                        pw.Text('Total Paid: ${_formatCurrency(_totalPaid)}',
                            style: pw.TextStyle(fontSize: 11, color: greenColor, fontWeight: pw.FontWeight.bold)),
                        pw.Text(
                            'Balance Due: ${_formatCurrency(_balance)}',
                            style: pw.TextStyle(
                              fontSize: 11,
                              color: _balance > 0 ? redColor : greenColor,
                              fontWeight: pw.FontWeight.bold,
                            )),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // ── Fee Breakdown Table ──────────────────────────
              if (_feeHeads.isNotEmpty) ...[
                pw.Text('FEE BREAKDOWN',
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: darkText)),
                pw.SizedBox(height: 8),
                pw.Table(
                  border: pw.TableBorder.all(color: borderGray, width: 0.5),
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: primaryBlue),
                      children: [
                        _pdfCell('Fee Head', isHeader: true, color: PdfColors.white),
                        _pdfCell('Total Amount', isHeader: true, color: PdfColors.white),
                        _pdfCell('Paid', isHeader: true, color: PdfColors.white),
                        _pdfCell('Due', isHeader: true, color: PdfColors.white),
                        _pdfCell('Status', isHeader: true, color: PdfColors.white),
                      ],
                    ),
                    ..._feeHeads.map((head) {
                      final amount = head['amount'] as double;
                      final paid = head['paid'] as double;
                      final due = amount - paid;
                      final status = head['status'] as String;
                      return pw.TableRow(
                        children: [
                          _pdfCell(head['name'] as String),
                          _pdfCell(_formatCurrency(amount)),
                          _pdfCell(_formatCurrency(paid), textColor: greenColor),
                          _pdfCell(_formatCurrency(due), textColor: due > 0 ? redColor : greenColor),
                          _pdfCell(status,
                              textColor: status == 'PAID' ? greenColor : status == 'PARTIAL' ? PdfColor.fromHex('#F59E0B') : redColor),
                        ],
                      );
                    }),
                  ],
                ),
                pw.SizedBox(height: 20),
              ],

              // ── Payment History Table ────────────────────────
              pw.Text('PAYMENT HISTORY',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: darkText)),
              pw.SizedBox(height: 8),
              if (_paymentHistory.isEmpty)
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: lightGray,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: borderGray),
                  ),
                  child: pw.Center(
                    child: pw.Text('No payment records found.',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                  ),
                )
              else
                pw.Table(
                  border: pw.TableBorder.all(color: borderGray, width: 0.5),
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: primaryBlue),
                      children: [
                        _pdfCell('Date', isHeader: true, color: PdfColors.white),
                        _pdfCell('Method', isHeader: true, color: PdfColors.white),
                        _pdfCell('Receipt No.', isHeader: true, color: PdfColors.white),
                        _pdfCell('Amount', isHeader: true, color: PdfColors.white),
                        _pdfCell('Status', isHeader: true, color: PdfColors.white),
                      ],
                    ),
                    ..._paymentHistory.map((p) {
                      final status = (p['status'] as String? ?? 'SUCCESS').toUpperCase();
                      return pw.TableRow(
                        children: [
                          _pdfCell(_formatDate(p['date'] as String?)),
                          _pdfCell(p['method'] as String? ?? 'UPI'),
                          _pdfCell(p['receipt'] as String? ?? '—'),
                          _pdfCell(_formatCurrency(p['amount'] as double),
                              textColor: greenColor),
                          _pdfCell(status,
                              textColor: status == 'SUCCESS' ? greenColor : redColor),
                        ],
                      );
                    }),
                  ],
                ),
              pw.SizedBox(height: 24),

              // ── Footer ──────────────────────────────────────
              pw.Divider(color: borderGray),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Generated by EduSphere • $dateStr $timeStr',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                  pw.Text('This is a system-generated statement.',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                ],
              ),
            ];
          },
        ),
      );

      // Generate PDF bytes
      final pdfBytes = await pdf.save();
      final fileName = 'FeeStatement_$receiptNo.pdf';

      dev.log('✅ PDF generated: $fileName', name: 'FeeLedgerScreen');

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Open native share/save dialog — user can save to Files, WhatsApp, Drive, etc.
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: fileName,
      );

    } catch (e) {
      dev.log('❌ PDF generation error: $e', name: 'FeeLedgerScreen');
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate PDF: $e',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white)),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Helper: create a PDF table cell
  pw.Widget _pdfCell(String text, {bool isHeader = false, PdfColor? color, PdfColor? textColor}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 9 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: textColor ?? color ?? PdfColor.fromHex('#0F172A'),
        ),
      ),
    );
  }

  Widget _buildStatementSummary() {
    final double completionPercent = _totalFee == 0 ? 0.0 : (_totalPaid / _totalFee).clamp(0.0, 1.0);
    final String progressText = "${(completionPercent * 100).toStringAsFixed(0)}% Completed";

    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10.r,
            offset: Offset(0, 4.h),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  Icons.currency_rupee_rounded,
                  color: const Color(0xFF1A6FDB),
                  size: 20.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Text(
                'Statement Summary',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                  fontSize: 16.sp,
                ),
              ),
            ],
          ),
          SizedBox(height: 24.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _summaryStatColumn('Total Fees (Year)', _formatCurrency(_totalFee), const Color(0xFF0F172A)),
              _summaryStatColumn('Total Paid', _formatCurrency(_totalPaid), const Color(0xFF10B981)),
              _summaryStatColumn('Outstanding Due', _formatCurrency(_balance), const Color(0xFFEF4444)),
            ],
          ),
          SizedBox(height: 24.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Payment Progress',
                style: GoogleFonts.inter(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
              Text(
                progressText,
                style: GoogleFonts.inter(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A6FDB),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(10.r),
            child: LinearProgressIndicator(
              value: completionPercent,
              minHeight: 6.h,
              backgroundColor: const Color(0xFFF1F5F9),
              color: const Color(0xFF1A6FDB),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryStatColumn(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.sp,
            color: const Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 6.h),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 18.sp,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedLedger() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10.r,
            offset: Offset(0, 4.h),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20.r, 20.r, 20.r, 16.r),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(
                    Icons.description_outlined,
                    color: const Color(0xFF1A6FDB),
                    size: 20.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detailed Fee Ledger',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        fontSize: 16.sp,
                      ),
                    ),
                    Text(
                      'Breakdown by fee structure items',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: SizedBox(
              width: 600.w,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      border: Border(
                        top: BorderSide(color: Color(0xFFF1F5F9)),
                        bottom: BorderSide(color: Color(0xFFF1F5F9)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(flex: 3, child: _headerText('Fee Structure')),
                        Expanded(flex: 2, child: _headerText('Total', align: TextAlign.center)),
                        Expanded(flex: 2, child: _headerText('Paid', align: TextAlign.center)),
                        Expanded(flex: 2, child: _headerText('Due', align: TextAlign.center)),
                        Expanded(flex: 2, child: _headerText('Status', align: TextAlign.center)),
                        Expanded(flex: 2, child: _headerText('Action', align: TextAlign.center)),
                      ],
                    ),
                  ),
                  ..._feeHeads.map((head) {
                    final name = head['name'] as String;
                    final amount = head['amount'] as double;
                    final paid = head['paid'] as double;
                    final due = amount - paid;
                    final status = head['status'] as String;

                    Color statusColor = const Color(0xFFEF4444);
                    Color statusBg = const Color(0xFFFEF2F2);
                    if (status == 'PAID') {
                      statusColor = const Color(0xFF10B981);
                      statusBg = const Color(0xFFECFDF5);
                    } else if (status == 'PARTIAL') {
                      statusColor = const Color(0xFFF59E0B);
                      statusBg = const Color(0xFFFFFBEB);
                    }

                    return Container(
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  'TUITION',
                                  style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          ),
                          Expanded(flex: 2, child: Text(_formatCurrency(amount), textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)))),
                          Expanded(flex: 2, child: Text(_formatCurrency(paid), textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w700, color: const Color(0xFF10B981)))),
                          Expanded(flex: 2, child: Text(_formatCurrency(due), textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w700, color: const Color(0xFFEF4444)))),
                          Expanded(
                            flex: 2,
                            child: Center(
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6.r)),
                                child: Text(status, style: GoogleFonts.inter(fontSize: 9.sp, fontWeight: FontWeight.w800, color: statusColor)),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Center(
                              child: due > 0
                                  ? SizedBox(
                                      height: 32.h,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF1A6FDB),
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                                        ),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => FeePaymentScreen(
                                                theme: widget.theme,
                                                outstandingAmount: due,
                                                studentId: _studentId,
                                                feeStructureId: _feeStructureId,
                                                ledgerId: _ledgerId,
                                                academicYearId: _academicYearId,
                                              ),
                                            ),
                                          ).then((_) => _loadLedgerData());
                                        },
                                        child: Text('Pay Now', style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w700)),
                                      ),
                                    )
                                  : const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerText(String text, {TextAlign align = TextAlign.left}) {
    return Text(
      text,
      textAlign: align,
      style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
    );
  }

  Widget _buildRecentHistory() {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10.r,
            offset: Offset(0, 4.h),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  Icons.access_time_rounded,
                  color: const Color(0xFF1A6FDB),
                  size: 20.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent History',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      fontSize: 16.sp,
                    ),
                  ),
                  Text(
                    'Last 3 transactions',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 24.h),
          if (_paymentHistory.isEmpty)
            Center(
              child: Text(
                'No transaction history',
                style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
              ),
            )
          else
            Column(
              children: [
                ..._paymentHistory.take(3).map((payment) {
                  final date = _formatDate(payment['date'] as String?);
                  final amount = payment['amount'] as double;
                  final receipt = payment['receipt'] as String;

                  return Container(
                    padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 16.w),
                    margin: EdgeInsets.only(bottom: 12.h),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE2EAF4)),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatCurrency(amount),
                              style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: const Color(0xFF0F172A), fontSize: 14.sp),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              date,
                              style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              child: Text(
                                'PAID',
                                style: GoogleFonts.inter(fontSize: 9.sp, fontWeight: FontWeight.w800, color: const Color(0xFF10B981)),
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              'REF: $receipt',
                              style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
                SizedBox(height: 16.h),
                Center(
                  child: TextButton.icon(
                    onPressed: _downloadStatement,
                    icon: Icon(Icons.picture_as_pdf_outlined, color: const Color(0xFF1A6FDB), size: 18.sp),
                    label: Text(
                      'Download Statement (PDF)',
                      style: GoogleFonts.inter(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A6FDB),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
              child: Row(
                children: [
                  if (widget.showBackButton) ...[
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: EdgeInsets.all(8.r),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 4.r,
                            )
                          ],
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 16.sp,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    SizedBox(width: 16.w),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Finance Overview',
                          style: GoogleFonts.inter(
                            fontSize: 24.sp,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF1A6FDB),
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'Manage your school fee payments and receipts',
                          style: GoogleFonts.inter(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.studentPrimary))
                  : RefreshIndicator(
                      onRefresh: () => _loadLedgerData(showLoading: true),
                      color: widget.theme.primary,
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(horizontal: 24.w),
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildStatementSummary(),
                            SizedBox(height: 20.h),
                            _buildDetailedLedger(),
                            SizedBox(height: 20.h),
                            _buildRecentHistory(),
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
}
