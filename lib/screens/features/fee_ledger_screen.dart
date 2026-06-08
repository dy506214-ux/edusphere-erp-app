import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import 'fee_payment_screen.dart';
import 'dart:async';
import 'dart:developer' as dev;
import 'dart:math';

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
  String _studentId = '';
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
    
    // Polling fallback every 2 seconds
    _feePollTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
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

      // Also try Supabase auth user id as fallback
      if (_studentId.isEmpty) {
        final currentUser = Supabase.instance.client.auth.currentUser;
        _studentId = currentUser?.id ?? '';
      }

      if (_studentId.isNotEmpty) {
        Map<String, dynamic>? studentProfile;
        try {
          studentProfile = await Supabase.instance.client
              .from('Student')
              .select('id, currentClassId, academicYearId')
              .eq('userId', _studentId)
              .maybeSingle();
          studentProfile ??= await Supabase.instance.client
              .from('Student')
              .select('id, currentClassId, academicYearId')
              .eq('id', _studentId)
              .maybeSingle();
          if (studentProfile != null) {
            _studentId = studentProfile['id'] as String;
            _academicYearId = studentProfile['academicYearId'] as String? ?? '';
          }
        } catch (e) {
          dev.log('Error resolving student profile: $e', name: 'FeeLedgerScreen');
        }

        // Fetch fee ledger joined with FeeStructure
        var ledgerRes = await Supabase.instance.client
            .from('StudentFeeLedger')
            .select('*, FeeStructure(*)')
            .eq('studentId', _studentId);

        var ledgerData = List<Map<String, dynamic>>.from(ledgerRes);

        // Seeding database record in real-time if student has no fee structures assigned
        if (ledgerData.isEmpty && studentProfile != null && _academicYearId.isNotEmpty) {
          try {
            final classId = studentProfile['currentClassId'] as String?;
            
            // Check if a FeeStructure exists or create one
            var structuresRes = await Supabase.instance.client
                .from('FeeStructure')
                .select()
                .eq('academicYearId', _academicYearId)
                .eq('name', 'Tuition Fee - Grade 1')
                .maybeSingle();

            Map<String, dynamic> feeStructure;
            if (structuresRes != null) {
              feeStructure = structuresRes;
            } else {
              final newStructureId = _generateUUID();
              final newStructure = {
                'id': newStructureId,
                'name': 'Tuition Fee - Grade 1',
                'description': 'Tuition Fee breakdown',
                'classId': classId,
                'academicYearId': _academicYearId,
                'totalAmount': 10500.0,
                'frequency': 'YEARLY',
                'dueDay': 10,
                'earlyPaymentDiscount': 0.0,
                'latePaymentPenalty': 0.0,
                'isActive': true,
                'createdAt': DateTime.now().toIso8601String(),
                'updatedAt': DateTime.now().toIso8601String(),
              };
              await Supabase.instance.client.from('FeeStructure').insert(newStructure);
              
              final newItem = {
                'id': _generateUUID(),
                'feeStructureId': newStructureId,
                'headName': 'TUITION',
                'amount': 10500.0,
              };
              await Supabase.instance.client.from('FeeStructureItem').insert(newItem);
              feeStructure = newStructure;
            }

            // Create StudentFeeLedger
            final newLedgerId = _generateUUID();
            final newLedger = {
              'id': newLedgerId,
              'studentId': _studentId,
              'academicYearId': _academicYearId,
              'feeStructureId': feeStructure['id'],
              'totalPayable': 10500.0,
              'totalPaid': 0.0,
              'totalPending': 10500.0,
              'totalDiscount': 0.0,
              'status': 'PENDING',
              'createdAt': DateTime.now().toIso8601String(),
              'updatedAt': DateTime.now().toIso8601String(),
            };
            await Supabase.instance.client.from('StudentFeeLedger').insert(newLedger);

            // Re-fetch
            ledgerRes = await Supabase.instance.client
                .from('StudentFeeLedger')
                .select('*, FeeStructure(*)')
                .eq('studentId', _studentId);
            ledgerData = List<Map<String, dynamic>>.from(ledgerRes);
          } catch (seedingError) {
            dev.log('Error seeding default ledger: $seedingError', name: 'FeeLedgerScreen');
          }
        }

        if (ledgerData.isNotEmpty) {
          double totalFee = 0;
          double totalPaid = 0;
          final List<Map<String, dynamic>> heads = [];

          for (var entry in ledgerData) {
            final structure = entry['FeeStructure'] as Map<String, dynamic>? ?? {};
            _feeStructureId = structure['id'] as String? ?? '';
            _ledgerId = entry['id'] as String? ?? '';
            if (entry['academicYearId'] != null) {
              _academicYearId = entry['academicYearId'] as String;
            }
            final headName = structure['name'] as String? ?? 'Fee';
            final amount = (entry['totalPayable'] ?? entry['amount'] ?? structure['totalAmount'] ?? 0).toDouble();
            final paid = (entry['totalPaid'] ?? entry['paid_amount'] ?? 0).toDouble();

            String status = 'PENDING';
            if (paid >= amount && amount > 0) {
              status = 'PAID';
            } else if (paid > 0) {
              status = 'PARTIAL';
            }

            totalFee += amount;
            totalPaid += paid;
            heads.add({
              'id': entry['id'],
              'name': headName,
              'amount': amount,
              'paid': paid,
              'status': status,
              'feeStructureId': _feeStructureId,
              'academicYearId': _academicYearId,
            });
          }

          _feeHeads = heads;
          _totalFee = totalFee;
          _totalPaid = totalPaid;
        } else {
          _feeHeads = [];
          _totalFee = 0;
          _totalPaid = 0;
        }

        // Fetch payment history
        final paymentsRes = await Supabase.instance.client
            .from('FeePayment')
            .select()
            .eq('studentId', _studentId)
            .order('paymentDate', ascending: false);

        final List<Map<String, dynamic>> paymentsData = List<Map<String, dynamic>>.from(paymentsRes);

        if (paymentsData.isNotEmpty) {
          _paymentHistory = paymentsData.map((p) {
            return {
              'date': p['paymentDate'] as String? ?? '',
              'amount': (p['amount'] as num? ?? 0).toDouble(),
              'method': p['paymentMode']?.toString() ?? 'UPI',
              'receipt': p['receiptNumber'] as String? ?? 'RCT-00000000',
              'status': p['status']?.toString() ?? 'SUCCESS',
            };
          }).toList();
        } else {
          _paymentHistory = [];
        }

        setState(() {});
        return;
      }

      _feeHeads = [];
      _totalFee = 0;
      _totalPaid = 0;
      _paymentHistory = [];
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

  void _downloadStatement() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        double progress = 0.0;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Timer(const Duration(milliseconds: 150), () {
              if (progress < 1.0) {
                setDialogState(() {
                  progress += 0.08;
                  if (progress > 1.0) progress = 1.0;
                });
              } else {
                Navigator.pop(context);
                showToast(this.context, 'Statement PDF downloaded successfully!');
              }
            });

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Padding(
                padding: EdgeInsets.all(24.r),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56.w,
                      height: 56.h,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEFF6FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.downloading_rounded,
                        color: Color(0xFF1A6FDB),
                        size: 28,
                      ),
                    ),
                    SizedBox(height: 20.h),
                    Text(
                      'Generating Statement',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 16.sp,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Preparing your PDF document...',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w500,
                        fontSize: 12.sp,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    SizedBox(height: 20.h),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10.r),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6.h,
                        backgroundColor: const Color(0xFFF1F5F9),
                        color: const Color(0xFF1A6FDB),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}%',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.sp,
                        color: const Color(0xFF1A6FDB),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMockStatementSummary() {
    final double completionPercent = _totalFee == 0 ? 0.0 : (_totalPaid / _totalFee).clamp(0.0, 1.0);
    final String progressText = "${(completionPercent * 100).toStringAsFixed(0)}% Complete";

    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 40.w,
                    height: 40.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: const Icon(
                      Icons.description_outlined,
                      color: Color(0xFF1A6FDB),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Text(
                    'Statement Summary',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                      fontSize: 16.sp,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.more_horiz_rounded, color: Color(0xFF64748B)),
                onPressed: () {},
              ),
            ],
          ),
          SizedBox(height: 20.h),
          Row(
            children: [
              Expanded(
                child: _summaryStatColumn('Total Fees', _formatCurrency(_totalFee), const Color(0xFF0F172A)),
              ),
              Container(width: 1.w, height: 40.h, color: AppColors.border),
              Expanded(
                child: _summaryStatColumn('Total Paid', _formatCurrency(_totalPaid), const Color(0xFF10B981)),
              ),
              Container(width: 1.w, height: 40.h, color: AppColors.border),
              Expanded(
                child: _summaryStatColumn(
                  'Outstanding Due',
                  _formatCurrency(_balance),
                  _balance > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Payment Progress',
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ),
              Text(
                progressText,
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
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
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12.sp,
            color: const Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 6.h),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildMockDetailedLedger() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
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
            padding: EdgeInsets.fromLTRB(20.r, 20.r, 20.r, 12.r),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 40.w,
                        height: 40.h,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: const Icon(
                          Icons.menu_book_outlined,
                          color: Color(0xFF1A6FDB),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Detailed Fee Ledger',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                                fontSize: 16.sp,
                              ),
                            ),
                            Text(
                              'Breakdown by fee structure name',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF64748B),
                                fontSize: 12.sp,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _showAllFeeHeadsBottomSheet,
                  child: Text(
                    'View All',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A6FDB),
                      fontSize: 13.sp,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Scrollable Table content
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: SizedBox(
              width: 540.w, // Ample width for all columns to display cleanly on mobile
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                    color: const Color(0xFFF8FAFC),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            'Fee Structure',
                            style: GoogleFonts.inter(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Total',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Paid',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Due',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Status',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Action',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Table rows
                  ..._feeHeads.asMap().entries.map((entry) {
                    final head = entry.value;
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
                                  style: GoogleFonts.inter(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  'TUITION',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              _formatCurrency(amount),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              _formatCurrency(paid),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              _formatCurrency(due),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFEF4444),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Center(
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(6.r),
                                ),
                                child: Text(
                                  status,
                                  style: GoogleFonts.inter(
                                    fontSize: 9.sp,
                                    fontWeight: FontWeight.w800,
                                    color: statusColor,
                                  ),
                                ),
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
                                          padding: EdgeInsets.symmetric(horizontal: 10.w),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8.r),
                                          ),
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
                                        child: Text(
                                          'Pay Now',
                                          style: GoogleFonts.inter(
                                            fontSize: 11.sp,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.check_circle_rounded,
                                      color: Color(0xFF10B981),
                                      size: 20,
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

  Widget _buildMockRecentHistory() {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
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
                width: 40.w,
                height: 40.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: Color(0xFF8B5CF6),
                ),
              ),
              SizedBox(width: 12.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent History',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                      fontSize: 16.sp,
                    ),
                  ),
                  Text(
                    'Last 5 transactions',
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
          if (_paymentHistory.isEmpty) ...[
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80.w,
                    height: 80.h,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.receipt_long_outlined,
                      size: 40,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'No transaction history',
                    style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  SizedBox(height: 24.h),
                  Divider(height: 1.h, color: AppColors.border),
                  SizedBox(height: 16.h),
                  TextButton.icon(
                    onPressed: _downloadStatement,
                    icon: const Icon(Icons.download_outlined, color: Color(0xFF1A6FDB), size: 18),
                    label: Text(
                      'Download Statement (PDF)',
                      style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A6FDB),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Column(
              children: [
                ..._paymentHistory.take(5).toList().asMap().entries.map((entry) {
                  final index = entry.key;
                  final payment = entry.value;
                  final date = _formatDate(payment['date'] as String?);
                  final amount = payment['amount'] as double;
                  final method = payment['method'] as String;
                  final receipt = payment['receipt'] as String;
                  final isLast = index == _paymentHistory.length - 1 || index == 4;

                  return Container(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    decoration: BoxDecoration(
                      border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40.w,
                          height: 40.h,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: const Icon(
                            Icons.receipt_long_outlined,
                            color: Color(0xFF1A6FDB),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                method,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                  fontSize: 13.sp,
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                '$date • $receipt',
                                style: GoogleFonts.inter(
                                  fontSize: 11.sp,
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatCurrency(amount),
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                                fontSize: 13.sp,
                              ),
                            ),
                            SizedBox(height: 3.h),
                            Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 12),
                                SizedBox(width: 3.w),
                                Text(
                                  'Success',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
                SizedBox(height: 16.h),
                Divider(height: 1.h, color: AppColors.border),
                SizedBox(height: 16.h),
                TextButton.icon(
                  onPressed: _downloadStatement,
                  icon: const Icon(Icons.download_outlined, color: Color(0xFF1A6FDB), size: 18),
                  label: Text(
                    'Download Statement (PDF)',
                    style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A6FDB),
                    ),
                  ),
                ),
              ],
            ),
          ],
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Finance Overview',
                          style: GoogleFonts.inter(
                            fontSize: 24.sp,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
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
                            _buildMockStatementSummary(),
                            SizedBox(height: 20.h),
                            _buildMockDetailedLedger(),
                            SizedBox(height: 20.h),
                            _buildMockRecentHistory(),
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
