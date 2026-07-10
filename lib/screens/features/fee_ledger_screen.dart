import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../services/socket_service.dart';
import 'package:file_saver/file_saver.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../theme/colors.dart';
import 'fee_payment_screen.dart';
import 'dart:async';
import 'dart:developer' as dev;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../services/api_service.dart';
import '../../config/api_endpoints.dart';
import '../../utils/download_helper.dart';
import 'package:dio/dio.dart';

class FeeLedgerScreen extends StatefulWidget {
  final RoleTheme theme;
  final bool showBackButton;
  const FeeLedgerScreen({super.key, required this.theme, this.showBackButton = true});

  @override
  State<FeeLedgerScreen> createState() => _FeeLedgerScreenState();
}

class _FeeLedgerScreenState extends State<FeeLedgerScreen> {
  bool _loading = true;
  bool _isOffline = false;
  String? _errorMessage;

  // Search and Filter State
  String _searchQuery = '';
  String _selectedStatusFilter = 'ALL';
  String _selectedModeFilter = 'ALL';
  final TextEditingController _searchController = TextEditingController();

  // Summary & Identity Data
  String _studentId = '';
  String _studentName = 'Student';
  String _studentEmail = '';
  String _admissionNo = '—';
  String _className = '—';
  String _sectionName = '—';
  String _rollNo = '—';
  String _feeStructureId = '';
  String _ledgerId = '';
  String _academicYearId = '';
  String _academicYearName = '2024-25';

  double _totalFee = 0;
  double _totalPaid = 0;
  double _totalDiscount = 0;
  double _totalScholarship = 0;
  double _totalFines = 0;
  double get _balance => (_totalFee - _totalDiscount - _totalScholarship + _totalFines) - _totalPaid;

  // Data Collections
  List<Map<String, dynamic>> _feeHeads = [];
  List<Map<String, dynamic>> _feeStructureItems = [];
  List<Map<String, dynamic>> _paymentHistory = [];
  List<Map<String, dynamic>> _adjustments = [];
  List<Map<String, dynamic>> _installments = [];

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
    _searchController.dispose();
    try {
      SocketService().off('FEE_UPDATED', _onFeeUpdated);
      SocketService().off('PAYMENT_SUCCESS', _onFeeUpdated);
    } catch (e) {
      dev.log('Error unregistering Socket events: $e', name: 'FeeLedgerScreen');
    }
    super.dispose();
  }

  void _onFeeUpdated(dynamic payload) {
    dev.log('🔥 Real-time fee update received | Data: $payload', name: 'FeeLedgerScreen');
    if (mounted) {
      _loadLedgerData(showLoading: false);
    }
  }

  void _connectRealTime() {
    try {
      dev.log('📡 Subscribing to Socket.IO fee events...', name: 'FeeLedgerScreen');
      SocketService().off('FEE_UPDATED', _onFeeUpdated);
      SocketService().off('PAYMENT_SUCCESS', _onFeeUpdated);
      SocketService().on('FEE_UPDATED', _onFeeUpdated);
      SocketService().on('PAYMENT_SUCCESS', _onFeeUpdated);
    } catch (e) {
      dev.log('⚠️ Socket connection error: $e', name: 'FeeLedgerScreen');
    }

    _feePollTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadLedgerData(showLoading: false);
      }
    });
  }

  Future<void> _loadLedgerData({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    final prefs = await SharedPreferences.getInstance();

    try {
      // 1. Fetch authenticated student profile
      final profileRes = await ApiService.instance.get(ApiEndpoints.studentsMe);
      if (profileRes != null && profileRes['success'] == true && profileRes['student'] != null) {
        final st = profileRes['student'] as Map<String, dynamic>;
        final userMap = st['user'] as Map<String, dynamic>? ?? {};
        final clsMap = st['currentClass'] as Map<String, dynamic>? ?? {};
        final secMap = st['section'] as Map<String, dynamic>? ?? {};
        final ayMap = st['academicYear'] as Map<String, dynamic>? ?? clsMap['academicYear'] as Map<String, dynamic>? ?? {};

        _studentId = st['id']?.toString() ?? '';
        _studentName = '${userMap['firstName'] ?? ''} ${userMap['lastName'] ?? ''}'.trim();
        if (_studentName.isEmpty) _studentName = 'Student';
        _studentEmail = userMap['email']?.toString() ?? '';
        _admissionNo = st['admissionNumber']?.toString() ?? '—';
        _className = clsMap['name']?.toString() ?? '—';
        _sectionName = secMap['name']?.toString() ?? '—';
        _rollNo = st['rollNumber']?.toString() ?? '—';
        _academicYearName = ayMap['name']?.toString() ?? '2024-25';
      }

      if (_studentId.isEmpty) {
        _studentId = prefs.getString('student_id') ?? '';
      }

      if (_studentId.isEmpty) {
        if (mounted) {
          setState(() {
            _loading = false;
            _errorMessage = 'No active student profile found.';
          });
        }
        return;
      }

      // 2. Fetch Fee Status & Ledgers from production API
      final response = await ApiService.instance.get(ApiEndpoints.studentFeeStatus(_studentId));

      if (response != null && (response['success'] == true || response['summary'] != null || response['ledgers'] != null)) {
        await prefs.setString('student_fee_cache_$_studentId', jsonEncode(response));
        _parseAndSetFeeData(response);
        if (mounted) {
          setState(() {
            _isOffline = false;
            _errorMessage = null;
          });
        }
      } else {
        final hasCache = _loadFromCache(prefs);
        if (!hasCache && mounted) {
          setState(() {
            _errorMessage = 'Failed to load fee information from server.';
          });
        }
      }
    } catch (e) {
      dev.log('⚠️ REST API error in FeeLedgerScreen: $e', name: 'FeeLedgerScreen');
      final hasCache = _loadFromCache(prefs);
      if (!hasCache && mounted) {
        setState(() {
          if (e is DioException) {
            final statusCode = e.response?.statusCode;
            switch (statusCode) {
              case 401: _errorMessage = 'Unauthorized. Please login again.'; break;
              case 403: _errorMessage = 'Access denied to fee details.'; break;
              case 404: _errorMessage = 'Fee records endpoint not found.'; break;
              case 429: _errorMessage = 'Too many requests. Please try again later.'; break;
              case 500: _errorMessage = 'Internal server error on ERP backend.'; break;
              default: _errorMessage = 'Connection error. Please try again.';
            }
          } else {
            _errorMessage = 'Unable to fetch fee details. Check your internet connection.';
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  bool _loadFromCache(SharedPreferences prefs) {
    final cachedStr = prefs.getString('student_fee_cache_$_studentId');
    if (cachedStr != null && cachedStr.isNotEmpty) {
      try {
        final cachedData = jsonDecode(cachedStr) as Map<String, dynamic>;
        _parseAndSetFeeData(cachedData);
        if (mounted) setState(() => _isOffline = true);
        return true;
      } catch (_) {}
    }
    if (mounted) setState(() => _isOffline = true);
    return false;
  }

  void _parseAndSetFeeData(Map<String, dynamic> data) {
    final List<dynamic> ledgers = data['ledgers'] as List<dynamic>? ?? [];
    final List<Map<String, dynamic>> heads = [];
    final List<Map<String, dynamic>> structureItems = [];
    final List<Map<String, dynamic>> adjustmentsList = [];
    final List<Map<String, dynamic>> paymentsList = [];

    double totalFeeAcc = 0;
    double totalPaidAcc = 0;
    double totalDiscountAcc = 0;
    double totalScholarshipAcc = 0;
    double totalFinesAcc = 0;

    for (var entry in ledgers) {
      final structure = entry['feeStructure'] as Map<String, dynamic>? ?? {};
      _feeStructureId = structure['id']?.toString() ?? _feeStructureId;
      _ledgerId = entry['id']?.toString() ?? _ledgerId;
      if (entry['academicYearId'] != null) {
        _academicYearId = entry['academicYearId']?.toString() ?? _academicYearId;
      }

      final headName = structure['name']?.toString() ?? 'Academic Fee Structure';
      final amount = (entry['totalPayable'] ?? structure['totalAmount'] ?? 0).toDouble();
      final paid = (entry['totalPaid'] ?? 0).toDouble();
      final discount = (entry['totalDiscount'] ?? 0).toDouble();
      final status = entry['status']?.toString() ?? 'PENDING';

      totalFeeAcc += amount;
      totalPaidAcc += paid;
      totalDiscountAcc += discount;

      heads.add({
        'id': entry['id'],
        'name': headName,
        'amount': amount,
        'paid': paid,
        'due': (amount - paid).clamp(0, double.infinity),
        'status': status == 'PAID' ? 'PAID' : (paid > 0 ? 'PARTIAL' : 'PENDING'),
        'feeStructureId': _feeStructureId,
        'academicYearId': _academicYearId,
      });

      // Structure items
      final items = structure['items'] as List<dynamic>? ?? [];
      for (var item in items) {
        structureItems.add({
          'headName': item['headName']?.toString().replaceAll('_', ' ') ?? 'General Fee',
          'amount': (item['amount'] as num? ?? 0).toDouble(),
        });
      }

      // Extract adjustments
      final adjs = entry['adjustments'] as List<dynamic>? ?? [];
      for (var adj in adjs) {
        final adjType = adj['type']?.toString() ?? 'DISCOUNT';
        final adjAmt = (adj['amount'] as num? ?? 0).toDouble();
        if (adjType == 'SCHOLARSHIP') {
          totalScholarshipAcc += adjAmt;
        } else if (adjType == 'FINE') {
          totalFinesAcc += adjAmt;
        } else if (adjType == 'DISCOUNT') {
          totalDiscountAcc += adjAmt;
        }
        adjustmentsList.add({
          'id': adj['id']?.toString() ?? '',
          'type': adjType,
          'amount': adjAmt,
          'reason': adj['reason']?.toString() ?? 'Approved Adjustment',
          'status': adj['status']?.toString() ?? 'APPROVED',
          'date': adj['createdAt']?.toString() ?? '',
        });
      }

      // Extract ledger payments
      final pmts = entry['payments'] as List<dynamic>? ?? [];
      for (var p in pmts) {
        paymentsList.add({
          'id': p['id']?.toString() ?? '',
          'date': p['paymentDate']?.toString() ?? p['createdAt']?.toString() ?? '',
          'amount': (p['amount'] as num? ?? 0).toDouble(),
          'method': p['paymentMode']?.toString() ?? 'UPI',
          'receipt': p['receiptNumber']?.toString() ?? 'RCT-00000000',
          'transactionId': p['transactionId']?.toString() ?? 'TXN-DIRECT',
          'status': p['status']?.toString() ?? 'COMPLETED',
          'collectedBy': p['collectedBy']?.toString() ?? 'Online Gateway',
        });
      }
    }

    // Recent payments fallback if ledgers payments empty
    if (paymentsList.isEmpty) {
      final List<dynamic> recent = data['recentPayments'] as List<dynamic>? ?? [];
      for (var p in recent) {
        paymentsList.add({
          'id': p['id']?.toString() ?? '',
          'date': p['paymentDate']?.toString() ?? p['createdAt']?.toString() ?? '',
          'amount': (p['amount'] as num? ?? 0).toDouble(),
          'method': p['paymentMode']?.toString() ?? 'UPI',
          'receipt': p['receiptNumber']?.toString() ?? 'RCT-00000000',
          'transactionId': p['transactionId']?.toString() ?? 'TXN-DIRECT',
          'status': p['status']?.toString() ?? 'COMPLETED',
          'collectedBy': 'School Cashier',
        });
      }
    }

    // Build Quarterly/Monthly Installment Schedules
    final List<Map<String, dynamic>> instList = [];
    final double netTotal = (totalFeeAcc - totalDiscountAcc - totalScholarshipAcc).clamp(0, double.infinity);
    if (netTotal > 0) {
      final double instAmount = netTotal / 4;
      double runningPaid = totalPaidAcc;
      final months = ['Apr', 'Jul', 'Oct', 'Jan'];
      final days = [10, 10, 10, 10];
      final currentYear = DateTime.now().year;

      for (int i = 0; i < 4; i++) {
        final double dueForInst = instAmount;
        String status = 'PENDING';
        double paidForInst = 0;

        if (runningPaid >= dueForInst) {
          status = 'PAID';
          paidForInst = dueForInst;
          runningPaid -= dueForInst;
        } else if (runningPaid > 0) {
          status = 'PARTIAL';
          paidForInst = runningPaid;
          runningPaid = 0;
        }

        final int yearVal = i == 3 ? currentYear + 1 : currentYear;
        instList.add({
          'number': i + 1,
          'title': 'Installment #${i + 1} (${months[i]} $yearVal)',
          'dueDate': '${days[i]} ${months[i]} $yearVal',
          'amount': dueForInst,
          'paid': paidForInst,
          'status': status,
          'lateFee': status == 'PAID' ? 0.0 : 250.0,
        });
      }
    }

    setState(() {
      _feeHeads = heads;
      _feeStructureItems = structureItems;
      _paymentHistory = paymentsList;
      _adjustments = adjustmentsList;
      _installments = instList;
      _totalFee = totalFeeAcc;
      _totalPaid = totalPaidAcc;
      _totalDiscount = totalDiscountAcc;
      _totalScholarship = totalScholarshipAcc;
      _totalFines = totalFinesAcc;
    });
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

  String _formatCurrency(double amount, {String prefix = '₹'}) {
    if (amount >= 1000000) {
      return '$prefix${(amount / 100000).toStringAsFixed(1)}L';
    }
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
    return '$prefix${parts.join('')}';
  }

  List<Map<String, dynamic>> get _filteredPayments {
    return _paymentHistory.where((p) {
      final receipt = (p['receipt'] ?? '').toString().toLowerCase();
      final txn = (p['transactionId'] ?? '').toString().toLowerCase();
      final mode = (p['method'] ?? '').toString().toUpperCase();
      final status = (p['status'] ?? '').toString().toUpperCase();
      final q = _searchQuery.toLowerCase();

      final matchesQuery = q.isEmpty || receipt.contains(q) || txn.contains(q) || mode.contains(q);
      final matchesStatus = _selectedStatusFilter == 'ALL' || status == _selectedStatusFilter;
      final matchesMode = _selectedModeFilter == 'ALL' || mode == _selectedModeFilter;

      return matchesQuery && matchesStatus && matchesMode;
    }).toList();
  }

  // ── INDIVIDUAL RECEIPT PDF GENERATOR ──────────────────
  Future<void> _downloadPaymentReceipt(Map<String, dynamic> payment) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            const SizedBox(width: 12),
            Text('Generating PDF Payment Receipt...', style: GoogleFonts.inter(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
        backgroundColor: const Color(0xFF1A6FDB),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      final pdf = pw.Document();
      final receiptNo = payment['receipt']?.toString() ?? 'RCT-00000000';
      final txnId = payment['transactionId']?.toString() ?? 'TXN-DIRECT';
      final pmtDate = _formatDate(payment['date']?.toString());
      final amountPaid = (payment['amount'] as num? ?? 0).toDouble();
      final pmtMode = payment['method']?.toString().toUpperCase() ?? 'UPI';

      final primaryBlue = PdfColor.fromHex('#1A6FDB');
      final darkText = PdfColor.fromHex('#0F172A');
      final lightGray = PdfColor.fromHex('#F8FAFC');
      final borderGray = PdfColor.fromHex('#E2E8F0');
      final greenColor = PdfColor.fromHex('#10B981');

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          build: (pw.Context ctx) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Container(
                  padding: const pw.EdgeInsets.all(24),
                  decoration: pw.BoxDecoration(color: primaryBlue, borderRadius: pw.BorderRadius.circular(12)),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('EDUSPHERE ERP', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                          pw.SizedBox(height: 4),
                          pw.Text('Official Fee Payment Receipt', style: const pw.TextStyle(fontSize: 11, color: PdfColors.white)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('RECEIPT #: $receiptNo', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                          pw.SizedBox(height: 4),
                          pw.Text('Date: $pmtDate', style: const pw.TextStyle(fontSize: 10, color: PdfColors.white)),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 24),

                // Student Metadata
                pw.Container(
                  padding: const pw.EdgeInsets.all(18),
                  decoration: pw.BoxDecoration(color: lightGray, borderRadius: pw.BorderRadius.circular(10), border: pw.Border.all(color: borderGray)),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('STUDENT INFORMATION', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 6),
                            pw.Text(_studentName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: darkText)),
                            pw.Text('Admission #: $_admissionNo  |  Roll #: $_rollNo', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                            pw.Text('Class: $_className - $_sectionName', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                          ],
                        ),
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('PAYMENT STATUS', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 6),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: pw.BoxDecoration(color: PdfColor.fromHex('#ECFDF5'), borderRadius: pw.BorderRadius.circular(6)),
                            child: pw.Text('SUCCESSFUL / PAID', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: greenColor)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 24),

                // Breakdown Table
                pw.Text('TRANSACTION BREAKDOWN', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: darkText)),
                pw.SizedBox(height: 8),
                pw.Table(
                  border: pw.TableBorder.all(color: borderGray, width: 0.5),
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: primaryBlue),
                      children: [
                        _pdfCell('Transaction ID', isHeader: true, color: PdfColors.white),
                        _pdfCell('Payment Mode', isHeader: true, color: PdfColors.white),
                        _pdfCell('Collected By', isHeader: true, color: PdfColors.white),
                        _pdfCell('Amount Paid', isHeader: true, color: PdfColors.white),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        _pdfCell(txnId),
                        _pdfCell(pmtMode),
                        _pdfCell(payment['collectedBy']?.toString() ?? 'Online Portal'),
                        _pdfCell(_formatCurrency(amountPaid, prefix: 'Rs. '), textColor: greenColor),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 24),

                // Financial Overview Box
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(color: lightGray, borderRadius: pw.BorderRadius.circular(8), border: pw.Border.all(color: borderGray)),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Academic Fee: ${_formatCurrency(_totalFee, prefix: 'Rs. ')}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: darkText)),
                      pw.Text('Total Paid to Date: ${_formatCurrency(_totalPaid, prefix: 'Rs. ')}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: greenColor)),
                      pw.Text('Remaining Balance: ${_formatCurrency(_balance, prefix: 'Rs. ')}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _balance > 0 ? PdfColor.fromHex('#EF4444') : greenColor)),
                    ],
                  ),
                ),
                pw.Spacer(),

                // Verification Stamp & Footer
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('QR VERIFICATION CODE', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                        pw.SizedBox(height: 4),
                        pw.Container(
                          width: 60,
                          height: 60,
                          decoration: pw.BoxDecoration(border: pw.Border.all(color: borderGray)),
                          child: pw.Center(child: pw.Text('VERIFIED', style: pw.TextStyle(fontSize: 8, color: primaryBlue, fontWeight: pw.FontWeight.bold))),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Container(
                          width: 140,
                          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 1))),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text('Authorized Finance Seal', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: darkText)),
                        pw.Text('EduSphere Accounts Dept.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),
                pw.Divider(color: borderGray),
                pw.Center(child: pw.Text('System Generated Official E-Receipt • EduSphere Smart ERP', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500))),
              ],
            );
          },
        ),
      );

      final pdfBytes = await pdf.save();
      final fileName = 'Receipt_$receiptNo.pdf';
      await downloadFile(pdfBytes, fileName.replaceAll('.pdf', ''), 'pdf');

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Receipt $receiptNo downloaded successfully', style: GoogleFonts.inter(fontSize: 12, color: Colors.white)), backgroundColor: const Color(0xFF10B981)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download receipt: $e', style: GoogleFonts.inter(fontSize: 12, color: Colors.white)), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  // ── ANNUAL STATEMENT PDF DOWNLOADER ──────────────────
  Future<void> _downloadStatement() async {
    if (_studentId.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            const SizedBox(width: 12),
            Text('Downloading statement...', style: GoogleFonts.inter(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
        backgroundColor: const Color(0xFF1A6FDB),
        duration: const Duration(seconds: 15),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      final response = await ApiService.instance.dio.get<List<int>>(
        'fees/students/$_studentId/statement',
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.data == null) {
        throw Exception('No statement data returned from server.');
      }

      final pdfBytes = Uint8List.fromList(response.data!);
      final fileName = 'FeeStatement_$_admissionNo.pdf';

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      await downloadFile(
        pdfBytes,
        fileName.replaceAll('.pdf', ''),
        'pdf',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fee statement downloaded successfully', style: GoogleFonts.inter(fontSize: 12, color: Colors.white)), backgroundColor: const Color(0xFF10B981)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download statement: $e', style: GoogleFonts.inter(fontSize: 12, color: Colors.white)), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  pw.Widget _pdfCell(String text, {bool isHeader = false, PdfColor? color, PdfColor? textColor}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: textColor ?? color ?? PdfColor.fromHex('#0F172A'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // ── TOP HEADER BAR ──
            _buildTopHeaderBar(),

            // ── MAIN CONTENT ──
            Expanded(
              child: _loading
                  ? _buildSkeletonView(isDesktop)
                  : _errorMessage != null
                      ? _buildErrorView()
                      : RefreshIndicator(
                          onRefresh: () => _loadLedgerData(showLoading: false),
                          color: const Color(0xFF1A6FDB),
                          child: SingleChildScrollView(
                            padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32.w : 16.w, vertical: 16.h),
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_isOffline) _buildOfflineBanner(),
                                _buildHeroSummaryCard(isDesktop),
                                SizedBox(height: 20.h),
                                if (isDesktop)
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(flex: 5, child: _buildDetailedLedgerCard()),
                                      SizedBox(width: 20.w),
                                      Expanded(flex: 3, child: _buildRecentHistoryCard()),
                                    ],
                                  )
                                else ...[
                                  _buildDetailedLedgerCard(),
                                  SizedBox(height: 20.h),
                                  _buildRecentHistoryCard(),
                                ],
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

  Widget _buildTopHeaderBar() {
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          if (widget.showBackButton) ...[
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10.r), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Icon(Icons.arrow_back_ios_new_rounded, size: 16.sp, color: const Color(0xFF0F172A)),
              ),
            ),
            SizedBox(width: 12.w),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8.w,
                  runSpacing: 4.h,
                  children: [
                    Text('Finance & Fees', style: GoogleFonts.outfit(fontSize: isMobile ? 18.sp : 22.sp, fontWeight: FontWeight.w900, color: const Color(0xFF1A6FDB))),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6.r)),
                      child: Text(_academicYearName, style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w700, color: const Color(0xFF1A6FDB))),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                Text('Real-time fee ledger, payment history, and e-receipts', style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          ElevatedButton.icon(
            onPressed: _downloadStatement,
            icon: Icon(Icons.picture_as_pdf_rounded, size: 14.sp, color: Colors.white),
            label: Text(isMobile ? 'Statement' : 'Statement PDF', style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A6FDB),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 10.w : 14.w, vertical: 8.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(10.r), border: Border.all(color: const Color(0xFFFCD34D))),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: const Color(0xFFD97706), size: 18.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Text('You are viewing cached fee records offline. Reconnect to sync latest server changes.', style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF92400E), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── HERO SUMMARY CARD ──────────────────
  Widget _buildHeroSummaryCard(bool isDesktop) {
    final double completionPercent = _totalFee == 0 ? 0.0 : (_totalPaid / _totalFee).clamp(0.0, 1.0);

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 16.r, offset: Offset(0, 6.h))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Student Info Line
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20.r,
                      backgroundColor: const Color(0xFF1A6FDB).withValues(alpha: 0.1),
                      child: Text(_studentName.isNotEmpty ? _studentName[0].toUpperCase() : 'S', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: const Color(0xFF1A6FDB))),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_studentName, style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                          SizedBox(height: 2.h),
                          Text('Adm #: $_admissionNo • Roll #: $_rollNo • Class: $_className - $_sectionName', style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF64748B)), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_balance > 0) ...[
                SizedBox(width: 8.w),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FeePaymentScreen(
                          theme: widget.theme,
                          outstandingAmount: _balance,
                          studentId: _studentId,
                          feeStructureId: _feeStructureId,
                          ledgerId: _ledgerId,
                          academicYearId: _academicYearId,
                        ),
                      ),
                    ).then((_) => _loadLedgerData(showLoading: false));
                  },
                  icon: Icon(Icons.payment_rounded, size: 14.sp, color: Colors.white),
                  label: Text('Pay Dues', style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 24.h),

          // Cards Grid
          if (isDesktop)
            Row(
              children: [
                Expanded(child: _metricCard('Total Fees', _formatCurrency(_totalFee), Icons.account_balance_wallet_outlined, const Color(0xFF1A6FDB), const Color(0xFFEFF6FF))),
                SizedBox(width: 14.w),
                Expanded(child: _metricCard('Total Paid', _formatCurrency(_totalPaid), Icons.check_circle_outline_rounded, const Color(0xFF10B981), const Color(0xFFECFDF5))),
                SizedBox(width: 14.w),
                Expanded(child: _metricCard('Outstanding Due', _formatCurrency(_balance), Icons.warning_amber_rounded, const Color(0xFFEF4444), const Color(0xFFFEF2F2))),
              ],
            )
          else
            Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _metricCard('Total Fees', _formatCurrency(_totalFee), Icons.account_balance_wallet_outlined, const Color(0xFF1A6FDB), const Color(0xFFEFF6FF))),
                    SizedBox(width: 12.w),
                    Expanded(child: _metricCard('Total Paid', _formatCurrency(_totalPaid), Icons.check_circle_outline_rounded, const Color(0xFF10B981), const Color(0xFFECFDF5))),
                  ],
                ),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Expanded(child: _metricCard('Outstanding Due', _formatCurrency(_balance), Icons.warning_amber_rounded, const Color(0xFFEF4444), const Color(0xFFFEF2F2))),
                  ],
                ),
              ],
            ),
          SizedBox(height: 24.h),

          // Progress Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Overall Payment Clearance', style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
              Text('${(completionPercent * 100).toStringAsFixed(0)}% Completed', style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w800, color: const Color(0xFF1A6FDB))),
            ],
          ),
          SizedBox(height: 8.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(10.r),
            child: LinearProgressIndicator(value: completionPercent, minHeight: 8.h, backgroundColor: const Color(0xFFF1F5F9), color: completionPercent == 1.0 ? const Color(0xFF10B981) : const Color(0xFF1A6FDB)),
          ),
        ],
      ),
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color, Color bgColor) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.04),
            blurRadius: 10.r,
            offset: Offset(0, 4.h),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 16.sp),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2.h),
                Text(
                  value,
                  style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w900, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── SKELETON SHIMMER VIEWS ──────────────────
  Widget _buildSkeletonView(bool isDesktop) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Skeleton Hero Summary Card
          Container(
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SkeletonPlaceholder(width: 40.r, height: 40.r, borderRadius: 20),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonPlaceholder(width: 150.w, height: 16.h),
                          SizedBox(height: 6.h),
                          SkeletonPlaceholder(width: 250.w, height: 12.h),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24.h),
                if (isDesktop)
                  Row(
                    children: List.generate(3, (index) => Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: index == 2 ? 0 : 14.w),
                        child: Container(
                          height: 84.h,
                          padding: EdgeInsets.all(12.r),
                          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16.r)),
                          child: Row(
                            children: [
                              SkeletonPlaceholder(width: 36.r, height: 36.r, borderRadius: 18),
                              SizedBox(width: 12.w),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SkeletonPlaceholder(width: 60.w, height: 10.h),
                                  SizedBox(height: 6.h),
                                  SkeletonPlaceholder(width: 80.w, height: 16.h),
                                ],
                              )
                            ],
                          ),
                        ),
                      ),
                    )),
                  )
                else
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _skeletonMetricCard()),
                          SizedBox(width: 12.w),
                          Expanded(child: _skeletonMetricCard()),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          Expanded(child: _skeletonMetricCard()),
                        ],
                      ),
                    ],
                  ),
                SizedBox(height: 24.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SkeletonPlaceholder(width: 140.w, height: 12.h),
                    SkeletonPlaceholder(width: 80.w, height: 12.h),
                  ],
                ),
                SizedBox(height: 8.h),
                SkeletonPlaceholder(width: double.infinity, height: 8.h),
              ],
            ),
          ),
          SizedBox(height: 24.h),
          
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: _buildSkeletonLedgerCard()),
                SizedBox(width: 20.w),
                Expanded(flex: 3, child: _buildSkeletonHistoryCard()),
              ],
            )
          else ...[
            _buildSkeletonLedgerCard(),
            SizedBox(height: 20.h),
            _buildSkeletonHistoryCard(),
          ],
        ],
      ),
    );
  }

  Widget _skeletonMetricCard() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16.r)),
      child: Row(
        children: [
          SkeletonPlaceholder(width: 32.r, height: 32.r, borderRadius: 16),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SkeletonPlaceholder(width: 50.w, height: 8.h),
                SizedBox(height: 6.h),
                SkeletonPlaceholder(width: 70.w, height: 12.h),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLedgerCard() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.r), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(20.r),
            child: Row(
              children: [
                SkeletonPlaceholder(width: 36.w, height: 36.h, borderRadius: 8),
                SizedBox(width: 12.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonPlaceholder(width: 120.w, height: 14.h),
                    SizedBox(height: 6.h),
                    SkeletonPlaceholder(width: 180.w, height: 10.h),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Column(
            children: List.generate(2, (index) => Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
              child: Row(
                children: [
                  Expanded(flex: 3, child: SkeletonPlaceholder(width: 120.w, height: 12.h)),
                  Expanded(flex: 2, child: Center(child: SkeletonPlaceholder(width: 50.w, height: 12.h))),
                  Expanded(flex: 2, child: Center(child: SkeletonPlaceholder(width: 50.w, height: 12.h))),
                  Expanded(flex: 2, child: Center(child: SkeletonPlaceholder(width: 50.w, height: 12.h))),
                  Expanded(flex: 2, child: Center(child: SkeletonPlaceholder(width: 40.w, height: 18.h, borderRadius: 6))),
                  Expanded(flex: 2, child: Center(child: SkeletonPlaceholder(width: 40.w, height: 18.h, borderRadius: 6))),
                ],
              ),
            )),
          )
        ],
      ),
    );
  }

  Widget _buildSkeletonHistoryCard() {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.r), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonPlaceholder(width: 36.w, height: 36.h, borderRadius: 8),
              SizedBox(width: 12.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonPlaceholder(width: 100.w, height: 14.h),
                  SizedBox(height: 6.h),
                  SkeletonPlaceholder(width: 120.w, height: 10.h),
                ],
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Column(
            children: List.generate(2, (index) => Container(
              margin: EdgeInsets.only(bottom: 10.h),
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFE2EAF4)), borderRadius: BorderRadius.circular(8.r)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonPlaceholder(width: 60.w, height: 12.h),
                      SizedBox(height: 6.h),
                      SkeletonPlaceholder(width: 80.w, height: 8.h),
                    ],
                  ),
                  SkeletonPlaceholder(width: 90.w, height: 10.h),
                ],
              ),
            )),
          )
        ],
      ),
    );
  }

  // ── ERROR VIEW ──────────────────
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.r),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 48.sp, color: const Color(0xFFEF4444)),
            SizedBox(height: 16.h),
            Text(
              _errorMessage ?? 'An error occurred',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
            ),
            SizedBox(height: 20.h),
            ElevatedButton.icon(
              onPressed: () => _loadLedgerData(showLoading: true),
              icon: Icon(Icons.refresh_rounded, size: 16.sp, color: Colors.white),
              label: Text('Retry', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A6FDB),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── EMPTY STATE ──────────────────
  Widget _buildEmptyState(String message, IconData icon) {
    return Padding(
      padding: EdgeInsets.all(24.r),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36.sp, color: const Color(0xFF94A3B8)),
            SizedBox(height: 12.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  // HELPER COMPONENTS
  Widget _buildDetailedLedgerCard() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.r), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(20.r),
            child: Row(
              children: [
                Container(padding: EdgeInsets.all(8.r), decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8.r)), child: Icon(Icons.description_outlined, color: const Color(0xFF1A6FDB), size: 20.sp)),
                SizedBox(width: 12.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Detailed Fee Ledger', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: const Color(0xFF0F172A), fontSize: 16.sp)),
                    Text('Breakdown by fee structure items', style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: const Color(0xFF64748B), fontSize: 12.sp)),
                  ],
                ),
              ],
            ),
          ),
          if (_feeHeads.isEmpty)
            _buildEmptyState('No Fee Records found.', Icons.assignment_late_outlined)
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 650.w,
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                      color: const Color(0xFFF8FAFC),
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
                      final amount = head['amount'] as double;
                      final paid = head['paid'] as double;
                      final due = head['due'] as double;
                      final status = head['status'] as String;

                      return Container(
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
                        child: Row(
                          children: [
                            Expanded(flex: 3, child: Text(head['name'] as String, style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)))),
                            Expanded(flex: 2, child: Text(_formatCurrency(amount), textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w700))),
                            Expanded(flex: 2, child: Text(_formatCurrency(paid), textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w700, color: const Color(0xFF10B981)))),
                            Expanded(flex: 2, child: Text(_formatCurrency(due), textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w700, color: const Color(0xFFEF4444)))),
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                                  decoration: BoxDecoration(color: status == 'PAID' ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(6.r)),
                                  child: Text(status, style: GoogleFonts.inter(fontSize: 9.sp, fontWeight: FontWeight.w800, color: status == 'PAID' ? const Color(0xFF10B981) : const Color(0xFFEF4444))),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: due > 0
                                    ? ElevatedButton(
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
                                          ).then((_) => _loadLedgerData(showLoading: false));
                                        },
                                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A6FDB), foregroundColor: Colors.white, padding: EdgeInsets.symmetric(horizontal: 12.w), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.r))),
                                        child: Text('Pay Now', style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w700)),
                                      )
                                    : Container(
                                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFECFDF5),
                                          borderRadius: BorderRadius.circular(20.r),
                                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
                                        ),
                                        child: Text(
                                          'SETTLED',
                                          style: GoogleFonts.inter(
                                            fontSize: 9.sp,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF10B981),
                                          ),
                                        ),
                                      ),
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

  Widget _buildRecentHistoryCard() {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.r), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: EdgeInsets.all(8.r), decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8.r)), child: Icon(Icons.access_time_rounded, color: const Color(0xFF1A6FDB), size: 20.sp)),
              SizedBox(width: 12.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Recent History', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: const Color(0xFF0F172A), fontSize: 16.sp)),
                  Text('Last 5 transactions', style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: const Color(0xFF64748B), fontSize: 12.sp)),
                ],
              ),
            ],
          ),
          SizedBox(height: 16.h),
          if (_paymentHistory.isEmpty)
            _buildEmptyState('No Payment History found.', Icons.history_toggle_off_rounded)
          else
            Column(
              children: _paymentHistory.take(5).map((pmt) {
                return GestureDetector(
                  onTap: () => _downloadPaymentReceipt(pmt),
                  child: Container(
                    margin: EdgeInsets.only(bottom: 10.h),
                    padding: EdgeInsets.all(12.r),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE2EAF4)),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatCurrency((pmt['amount'] as num? ?? 0).toDouble()), style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13.sp, color: const Color(0xFF0F172A))),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                              decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(4.r)),
                              child: Text(
                                (pmt['method'] ?? 'ONLINE').toString().toUpperCase(),
                                style: GoogleFonts.inter(fontSize: 8.sp, fontWeight: FontWeight.w800, color: const Color(0xFF1A6FDB)),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatDate(pmt['date'] as String?), style: GoogleFonts.inter(fontSize: 10.sp, color: const Color(0xFF64748B))),
                            Row(
                              children: [
                                Text(pmt['receipt']?.toString() ?? '—', style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                                SizedBox(width: 4.w),
                                Icon(Icons.download_rounded, size: 10.sp, color: const Color(0xFF1A6FDB)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _headerText(String text, {TextAlign align = TextAlign.left}) {
    return Text(text, textAlign: align, style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)));
  }
}

// ── SKELETON PULSING PLACEHOLDER ──────────────────
class SkeletonPlaceholder extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  const SkeletonPlaceholder({super.key, required this.width, required this.height, this.borderRadius = 8});

  @override
  State<SkeletonPlaceholder> createState() => _SkeletonPlaceholderState();
}

class _SkeletonPlaceholderState extends State<SkeletonPlaceholder> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 1000), vsync: this)..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(widget.borderRadius.r),
        ),
      ),
    );
  }
}
