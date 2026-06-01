import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';

class ScannerLiveScreen extends StatefulWidget {
  final RoleTheme theme;
  final String scannerId;

  const ScannerLiveScreen({
    super.key,
    required this.theme,
    required this.scannerId,
  });

  @override
  State<ScannerLiveScreen> createState() => _ScannerLiveScreenState();
}

class _ScannerLiveScreenState extends State<ScannerLiveScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _scannerDetails;
  List<Map<String, dynamic>> _scanEvents = [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadLiveDashboard();
    
    // Set up active polling synchronization every 10 seconds for real-time monitoring
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _loadLiveFeed();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadLiveDashboard() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch QR Scanner details
      final scannerRes = await Supabase.instance.client
          .from('QRScanner')
          .select('*')
          .eq('id', widget.scannerId)
          .maybeSingle();

      if (scannerRes != null) {
        _scannerDetails = Map<String, dynamic>.from(scannerRes);
      }

      // 2. Fetch live scans list
      await _loadLiveFeed();
    } catch (e) {
      debugPrint('Error loading live dashboard details: $e');
      if (mounted) {
        showToast(context, 'Failed to load checkpoint dashboard', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadLiveFeed() async {
    try {
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      
      final recordsRes = await Supabase.instance.client
          .from('AttendanceRecord')
          .select('*, student:Student(*, user:User(*)), teacher:Teacher(*, user:User(*)), staff:Staff(*, user:User(*))')
          .eq('scannerId', widget.scannerId)
          .eq('date', todayStr)
          .order('createdAt', ascending: false)
          .limit(40);

      final records = List<Map<String, dynamic>>.from(recordsRes);

      // Decompose row check-in / check-out timestamps into distinct chronological scan events
      final List<Map<String, dynamic>> tempEvents = [];
      for (var rec in records) {
        final name = _getAttendeeName(rec);
        final status = (rec['status'] ?? 'PRESENT').toString();
        
        final checkInTimeStr = rec['checkInTime'];
        final checkOutTimeStr = rec['checkOutTime'];

        if (checkOutTimeStr != null) {
          tempEvents.add({
            'id': '${rec['id']}_out',
            'name': name,
            'time': checkOutTimeStr,
            'action': 'CHECK_OUT',
            'status': status,
            'type': (rec['attendeeType'] ?? 'STUDENT').toString(),
          });
        }
        if (checkInTimeStr != null) {
          tempEvents.add({
            'id': '${rec['id']}_in',
            'name': name,
            'time': checkInTimeStr,
            'action': 'CHECK_IN',
            'status': status,
            'type': (rec['attendeeType'] ?? 'STUDENT').toString(),
          });
        }
      }

      // Sort chronological decomposed events (newest first)
      tempEvents.sort((a, b) {
        final tA = DateTime.tryParse(a['time'] ?? '') ?? DateTime.now();
        final tB = DateTime.tryParse(b['time'] ?? '') ?? DateTime.now();
        return tB.compareTo(tA);
      });

      if (mounted) {
        setState(() {
          _scanEvents = tempEvents;
        });
      }
    } catch (e) {
      debugPrint('Error loading scan feeds: $e');
    }
  }

  String _getAttendeeName(Map<String, dynamic> record) {
    final type = (record['attendeeType'] ?? 'STUDENT').toString().toUpperCase();
    if (type == 'STUDENT' && record['student'] != null) {
      final user = record['student']['user'];
      if (user != null) {
        return '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
      }
    } else if (type == 'TEACHER' && record['teacher'] != null) {
      final user = record['teacher']['user'];
      if (user != null) {
        return '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
      }
    } else if (type == 'STAFF' && record['staff'] != null) {
      final user = record['staff']['user'];
      if (user != null) {
        return '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
      }
    }
    return 'Unknown User';
  }

  String _formatTime(String timeStr) {
    try {
      final dt = DateTime.parse(timeStr).toLocal();
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $ampm';
    } catch (_) {
      return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scannerName = _scannerDetails?['name'] ?? 'Loading Scanner...';
    final location = _scannerDetails?['location'] ?? '';
    final isActive = _scannerDetails?['isActive'] as bool? ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PageHeader(
            title: scannerName,
            subtitle: location,
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
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.all(16.r),
                    child: Column(
                      children: [
                        // ── SECTION 1: QR CODE DISPLAY CARD ──
                        _buildQRCodeCard(isActive),
                        SizedBox(height: 24.h),

                        // ── SECTION 2: LIVE SCANS FEED LIST ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const SectionTitle(title: 'Live Scan Feed'),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                              decoration: BoxDecoration(
                                color: widget.theme.light,
                                borderRadius: BorderRadius.circular(20.r),
                              ),
                              child: Text(
                                '${_scanEvents.length} scans today',
                                style: GoogleFonts.inter(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w800,
                                  color: widget.theme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12.h),

                        _scanEvents.isEmpty
                            ? _buildEmptyFeedState()
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _scanEvents.length,
                                itemBuilder: (context, index) {
                                  return _buildScanRow(_scanEvents[index]);
                                },
                              ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildQRCodeCard(bool isActive) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: Column(
        children: [
          // Dynamic active status tag banner
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.success.withValues(alpha: 0.08)
                  : AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8.w,
                  height: 8.h,
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.success : AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  isActive ? 'Scanner Active 🟢' : 'Scanner Inactive 🔴',
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w800,
                    color: isActive ? AppColors.success : AppColors.error,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24.h),

          // Generated QR Code Simulator Painter
          Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: CustomPaint(
              size: Size(180.w, 180.w),
              painter: QRSimulatorPainter(
                color: isActive ? AppColors.textDark : AppColors.textLight,
              ),
            ),
          ),
          SizedBox(height: 20.h),

          // Scanner ID label styled box
          Text(
            'SCANNER ID',
            style: GoogleFonts.inter(
              fontSize: 9.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.textLight,
            ),
          ),
          SizedBox(height: 4.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: AppColors.border),
            ),
            child: SelectableText(
              widget.scannerId,
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanRow(Map<String, dynamic> event) {
    final name = event['name'];
    final timeStr = event['time'];
    final action = event['action'];
    final status = event['status'];
    final type = event['type'];

    final isCheckIn = action == 'CHECK_IN';
    final formattedTime = _formatTime(timeStr);

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Action icon indicator (Green Check-in vs Red Check-out arrow)
          Container(
            width: 36.w,
            height: 36.h,
            decoration: BoxDecoration(
              color: isCheckIn
                  ? AppColors.success.withValues(alpha: 0.08)
                  : AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(
              isCheckIn ? Icons.login_rounded : Icons.logout_rounded,
              color: isCheckIn ? AppColors.success : AppColors.error,
              size: 18.sp,
            ),
          ),
          SizedBox(width: 14.w),

          // Core details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 3.h),
                Row(
                  children: [
                    // Action label text
                    Text(
                      isCheckIn ? 'Check-In' : 'Check-Out',
                      style: GoogleFonts.inter(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w800,
                        color: isCheckIn ? AppColors.success : AppColors.error,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    // Attendee type badge
                    Text(
                      '•  ${type.toUpperCase()}',
                      style: GoogleFonts.inter(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),

          // Status & Time details
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: status.toUpperCase() == 'LATE'
                      ? AppColors.warning.withValues(alpha: 0.08)
                      : AppColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 8.sp,
                    fontWeight: FontWeight.w900,
                    color: status.toUpperCase() == 'LATE' ? AppColors.warning : AppColors.success,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                formattedTime,
                style: GoogleFonts.inter(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMedium,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFeedState() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.history_toggle_off_rounded,
            size: 36.sp,
            color: AppColors.textLight,
          ),
          SizedBox(height: 10.h),
          Text(
            'No scans detected today',
            style: GoogleFonts.inter(
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'The attendance records lists will populate automatically when checkpoints are scanned.',
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.textMedium,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── CUSTOM QR SIMULATOR PAINTER ──
class QRSimulatorPainter extends CustomPainter {
  final Color color;
  QRSimulatorPainter({this.color = Colors.black});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final double px = size.width / 15; // 15x15 pixel grid simulation

    // Helper to draw finder corner square
    void drawFinder(double x, double y) {
      // Outer 5x5 px block
      canvas.drawRect(Rect.fromLTWH(x, y, px * 5, px * 5), paint);
      // Inner white 3x3 block
      canvas.drawRect(Rect.fromLTWH(x + px, y + px, px * 3, px * 3), Paint()..color = Colors.white);
      // Inner black 1x1 block
      canvas.drawRect(Rect.fromLTWH(x + px * 1.5, y + px * 1.5, px * 2, px * 2), paint);
    }

    // Draw three main finder corner blocks
    drawFinder(0, 0); // Top-left
    drawFinder(px * 10, 0); // Top-right
    drawFinder(0, px * 10); // Bottom-left

    // Draw random checkered data blocks
    for (int r = 0; r < 15; r++) {
      for (int c = 0; c < 15; c++) {
        // Skip corner finder block zones
        if (r < 6 && c < 6) continue;
        if (r < 6 && c >= 9) continue;
        if (r >= 9 && c < 6) continue;

        // Deterministic noise block generator
        final int val = (r * 7 + c * 13) % 5;
        if (val == 0 || val == 2) {
          canvas.drawRect(Rect.fromLTWH(c * px, r * px, px, px), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
