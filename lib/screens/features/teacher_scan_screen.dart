import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../theme/colors.dart';
import '../profile_screen.dart';
import '../../widgets/teacher_app_bar.dart';
import '../main_screen.dart';
import 'package:edusphere/theme/typography.dart';

// ══════════════════════════════════════════════════════════════════════════════
// TeacherScanScreen – Camera QR scanner for marking student attendance
// On Windows/Web desktop → falls back to manual admission-number entry
// ══════════════════════════════════════════════════════════════════════════════

class TeacherScanScreen extends StatefulWidget {
  final RoleTheme theme;
  final bool showAppBar;
  final String scannerId;
  final DateTime sessionDate;
  final String sessionAction;

  const TeacherScanScreen({
    super.key,
    required this.theme,
    this.showAppBar = true,
    required this.scannerId,
    required this.sessionDate,
    required this.sessionAction,
  });

  @override
  State<TeacherScanScreen> createState() => _TeacherScanScreenState();
}

class _TeacherScanScreenState extends State<TeacherScanScreen>
    with SingleTickerProviderStateMixin {
  // ── Camera QR (mobile/web with camera) ──
  final MobileScannerController _qrController = MobileScannerController();

  // ── Manual entry (desktop / fallback) ──
  final TextEditingController _manualCtrl = TextEditingController();
  bool _useManual = false;

  // ── State ──
  bool _isProcessing = false;
  _ScanResult? _lastResult;

  // ── Success animation ──
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;

  // ── Recent scans ──
  final List<Map<String, dynamic>> _recentScans = [];

  // Detect desktop/web to use manual fallback instead of camera
  bool get _isDesktopOrWeb {
    if (kIsWeb) return true;
    try {
      // ignore: do_not_use_environment
      const platform =
          String.fromEnvironment('FLUTTER_PLATFORM', defaultValue: '');
      if (platform.isNotEmpty) return false;
    } catch (_) {}
    // Use defaultTargetPlatform for desktop detection (safe on all platforms)
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.elasticOut);
    // On desktop, always use manual mode
    if (_isDesktopOrWeb) _useManual = true;
  }

  @override
  void dispose() {
    _qrController.dispose();
    _manualCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _ensureScannerExists(String scannerId) async {
    debugPrint(
        '🔍 [QRScanner Lookup] Checking database for scannerId: $scannerId');
    try {
      final res = await Supabase.instance.client
          .from('QRScanner')
          .select('*')
          .eq('id', scannerId)
          .maybeSingle();

      debugPrint('🔍 [QRScanner Lookup Result] Lookup response: $res');
      if (res == null) {
        debugPrint(
            '🆕 [QRScanner Auto-create] Scanner $scannerId not found. Creating default QRScanner in DB...');
        final currentUser = Supabase.instance.client.auth.currentUser;
        final creatorId =
            currentUser?.id ?? 'e8f5de9c-114f-4ffd-9698-49f349208bfb';

        final newScanner = {
          'id': scannerId,
          'name': 'main gate scanner',
          'location': 'Main Gate',
          'scannerType': 'ENTRY',
          'isActive': true,
          'createdBy': creatorId,
          'updatedAt': DateTime.now().toIso8601String(),
        };
        debugPrint('🆕 [QRScanner Auto-create] Insert Payload: $newScanner');
        final insertRes = await Supabase.instance.client
            .from('QRScanner')
            .insert(newScanner)
            .select()
            .single();
        debugPrint(
            '🆕 [QRScanner Auto-create Result] Auto-creation response: $insertRes');
      }
    } catch (e) {
      debugPrint('⚠️ [QRScanner Auto-create Error] Error: $e');
    }
  }

  // ── Process QR payload (admission no) ──
  Future<void> _processQRData(String rawCode) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    // Pause camera while processing
    await _qrController.stop();

    debugPrint(
        '================================================================');
    debugPrint('📸 [QR SCAN INITIATED (TeacherScanScreen)]');
    debugPrint('📍 Current scannerId: ${widget.scannerId}');
    debugPrint('📦 QR payload: $rawCode');

    try {
      // QR data = admission number or teacher employee ID
      final admissionNo = rawCode.trim();

      // Check if it's a teacher employeeId first
      final teacherRes = await Supabase.instance.client
          .from('Teacher')
          .select('id, userId, employeeId, user:User(firstName, lastName)')
          .eq('employeeId', admissionNo)
          .maybeSingle();

      if (teacherRes != null) {
        final teacherId = teacherRes['id'].toString();
        final teacherUserId = teacherRes['userId']?.toString();
        final user = teacherRes['user'] as Map<String, dynamic>? ?? {};
        final teacherName =
            '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
        debugPrint(
            '👤 Teacher Identified - ID: $teacherId, Name: $teacherName, UserID: $teacherUserId');

        // Ensure scanner exists in DB
        await _ensureScannerExists(widget.scannerId);

        final today = DateTime.now().toIso8601String().substring(0, 10);

        // Check if already marked today
        final existing = await Supabase.instance.client
            .from('AttendanceRecord')
            .select('id, status')
            .eq('teacherId', teacherId)
            .eq('date', today)
            .eq('attendeeType', 'TEACHER')
            .maybeSingle();

        if (existing != null) {
          debugPrint(
              '⚠️ [QR SCAN ALREADY MARKED] teacherId $teacherId already marked today');
          _showResult(_ScanResult(
            success: false,
            message: 'Teacher $teacherName already marked today',
            icon: Icons.info_outline_rounded,
            color: Colors.orange,
          ));
          return;
        }

        final Map<String, dynamic> insertPayload = {
          'attendeeType': 'TEACHER',
          'teacherId': teacherId,
          'date': today,
          'status': 'PRESENT',
          'scannedByQR': true,
          'scannerId': widget.scannerId,
          'updatedAt': DateTime.now().toIso8601String(),
        };

        if (widget.sessionAction.toLowerCase() == 'check-in' ||
            widget.sessionAction.toLowerCase() == 'check_in') {
          insertPayload['checkInTime'] = DateTime.now().toIso8601String();
        } else {
          insertPayload['checkOutTime'] = DateTime.now().toIso8601String();
        }

        debugPrint('📤 Teacher Attendance insert payload: $insertPayload');

        final insertResponse = await Supabase.instance.client
            .from('AttendanceRecord')
            .insert(insertPayload)
            .select()
            .single();

        debugPrint('📥 Teacher Attendance insert response: $insertResponse');

        _showResult(_ScanResult(
          success: true,
          message: 'Teacher $teacherName marked PRESENT ✓',
          icon: Icons.check_circle_rounded,
          studentName: teacherName,
          admissionNo: admissionNo,
        ));

        // Add to recent scans
        setState(() {
          _recentScans.insert(0, {
            'name': teacherName,
            'admissionNo': admissionNo,
            'time': DateTime.now(),
            'status': 'PRESENT',
          });
          if (_recentScans.length > 10) _recentScans.removeLast();
        });

        if (mounted && teacherUserId != null) {
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(
                    role: 'teacher',
                    theme: widget.theme,
                    teacherId: teacherUserId,
                  ),
                ),
              );
            }
          });
        }
        return;
      }

      // 1. Look up student by admission no
      final studentRes = await Supabase.instance.client
          .from('Student')
          .select('id, admissionNumber, user:User(firstName, lastName)')
          .eq('admissionNumber', admissionNo)
          .maybeSingle();

      if (studentRes == null) {
        debugPrint(
            '❌ [QR SCAN ERROR] Student/Teacher not found for QR payload: $admissionNo');
        _showResult(_ScanResult(
          success: false,
          message: 'User not found for QR: $admissionNo',
          icon: Icons.error_outline_rounded,
        ));
        return;
      }

      final studentId = studentRes['id'].toString();
      final user = studentRes['user'] as Map<String, dynamic>? ?? {};
      final studentName =
          '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
      final today = DateTime.now().toIso8601String().substring(0, 10);

      debugPrint('👤 Student Identified - ID: $studentId, Name: $studentName');

      // Ensure scanner exists in DB
      await _ensureScannerExists(widget.scannerId);

      // 2. Check if already marked today
      final existing = await Supabase.instance.client
          .from('AttendanceRecord')
          .select('id, status')
          .eq('studentId', studentId)
          .eq('date', today)
          .eq('attendeeType', 'STUDENT')
          .maybeSingle();

      if (existing != null) {
        debugPrint(
            '⚠️ [QR SCAN ALREADY MARKED] studentId $studentId already marked today');
        _showResult(_ScanResult(
          success: false,
          message: '$studentName already marked today',
          icon: Icons.info_outline_rounded,
          color: Colors.orange,
        ));
        return;
      }

      final Map<String, dynamic> insertPayload = {
        'attendeeType': 'STUDENT',
        'studentId': studentId,
        'date': today,
        'status': 'PRESENT',
        'scannedByQR': true,
        'scannerId': widget.scannerId,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (widget.sessionAction.toLowerCase() == 'check-in' ||
          widget.sessionAction.toLowerCase() == 'check_in') {
        insertPayload['checkInTime'] = DateTime.now().toIso8601String();
      } else {
        insertPayload['checkOutTime'] = DateTime.now().toIso8601String();
      }

      debugPrint('📤 Attendance insert request payload: $insertPayload');

      // 3. Insert attendance record
      final insertResponse = await Supabase.instance.client
          .from('AttendanceRecord')
          .insert(insertPayload)
          .select()
          .single();

      debugPrint('📥 Attendance insert response: $insertResponse');

      _showResult(_ScanResult(
        success: true,
        message: '$studentName marked PRESENT ✓',
        icon: Icons.check_circle_rounded,
        studentName: studentName,
        admissionNo: admissionNo,
      ));

      // Add to recent scans
      setState(() {
        _recentScans.insert(0, {
          'name': studentName,
          'admissionNo': admissionNo,
          'time': DateTime.now(),
          'status': 'PRESENT',
        });
        if (_recentScans.length > 10) _recentScans.removeLast();
      });
    } catch (e) {
      debugPrint('❌ [QR SCAN EXCEPTION] Error: $e');
      _showResult(_ScanResult(
        success: false,
        message: 'Error: ${e.toString()}',
        icon: Icons.warning_amber_rounded,
        color: Colors.red,
      ));
    } finally {
      debugPrint(
          '================================================================');
      setState(() => _isProcessing = false);
    }
  }

  void _showResult(_ScanResult result) {
    setState(() => _lastResult = result);
    _animCtrl.forward(from: 0);

    // Auto-clear result and resume camera after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _lastResult = null);
        if (!_useManual && !_isDesktopOrWeb) {
          _qrController.start();
        }
      }
    });
  }

  Future<void> _submitManual() async {
    final code = _manualCtrl.text.trim();
    if (code.isEmpty) return;
    _manualCtrl.clear();
    await _processQRData(code);
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: widget.showAppBar
          ? const TeacherAppBar(title: 'QR Attendance Scanner')
          : null,
      bottomNavigationBar:
          widget.showAppBar ? const TeacherBottomNavBar(activeIndex: 5) : null,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            _buildHeader(),

            // ── Scanner area ──
            Expanded(
              child: _useManual || _isDesktopOrWeb
                  ? _buildManualEntry()
                  : _buildCameraScanner(size),
            ),

            // ── Recent scans ──
            if (_recentScans.isNotEmpty) _buildRecentScans(),

            SizedBox(height: 12.h),
          ],
        ),
      ),
    );
  }

  // ── Top header ──
  Widget _buildHeader() {
    return Container(
      margin: EdgeInsets.all(16.r),
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A6FDB), Color(0xFF0F2547)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A6FDB).withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Icon(
              Icons.qr_code_scanner_rounded,
              color: Colors.white,
              size: 28.sp,
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attendance Scanner (${widget.sessionAction.toUpperCase()})',
                  style: GoogleFonts.outfit(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Date: ${widget.sessionDate.day.toString().padLeft(2, '0')}/${widget.sessionDate.month.toString().padLeft(2, '0')}/${widget.sessionDate.year} • ${_isDesktopOrWeb ? 'Enter student admission number' : 'Point camera at student\'s QR'}',
                  style: AppTypography.caption
                      .copyWith(color: Colors.white.withValues(alpha: 0.75)),
                ),
              ],
            ),
          ),
          // Toggle button (mobile only)
          if (!_isDesktopOrWeb)
            GestureDetector(
              onTap: () {
                setState(() => _useManual = !_useManual);
                if (_useManual) {
                  _qrController.stop();
                } else {
                  _qrController.start();
                }
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  _useManual ? 'Camera' : 'Manual',
                  style: AppTypography.caption.copyWith(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Camera scanner ──
  Widget _buildCameraScanner(Size size) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // QR View
        ClipRRect(
          borderRadius: BorderRadius.circular(24.r),
          child: Stack(
            children: [
              MobileScanner(
                controller: _qrController,
                onDetect: (capture) async {
                  if (_isProcessing) return;
                  final barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty) {
                    final code = barcodes.first.rawValue?.trim() ?? '';
                    if (code.isEmpty) return;
                    await _processQRData(code);
                  }
                },
              ),
              Center(
                child: Container(
                  width: size.width * 0.65,
                  height: size.width * 0.65,
                  decoration: BoxDecoration(
                    border:
                        Border.all(color: const Color(0xFF1A6FDB), width: 4),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Processing overlay
        if (_isProcessing)
          Container(
            color: Colors.black.withValues(alpha: 0.6),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 12.h),
                  Text(
                    'Processing...',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Result overlay
        if (_lastResult != null) _buildResultOverlay(),
      ],
    );
  }

  // ── Manual entry mode (desktop) ──
  Widget _buildManualEntry() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        children: [
          // Entry card
          Container(
            padding: EdgeInsets.all(24.r),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24.r),
              border: Border.all(color: const Color(0xFFE2EAF4)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Animated icon
                Container(
                  width: 80.w,
                  height: 80.w,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE8F1FB), Color(0xFFC7DCFB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Icon(
                    Icons.qr_code_2_rounded,
                    size: 42.sp,
                    color: const Color(0xFF1A6FDB),
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'Enter Student Admission No.',
                  style: GoogleFonts.outfit(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F2547),
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  'Type the admission number printed on the student\'s QR card',
                  textAlign: TextAlign.center,
                  style: AppTypography.caption
                      .copyWith(color: const Color(0xFF868E96), height: 1.5),
                ),
                SizedBox(height: 20.h),

                // Input field
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(color: const Color(0xFFE2EAF4)),
                  ),
                  child: TextField(
                    controller: _manualCtrl,
                    style: AppTypography.small.copyWith(
                        color: const Color(0xFF0F2547), letterSpacing: 1.2),
                    decoration: InputDecoration(
                      hintText: 'e.g. ADM-2023-0681',
                      hintStyle: AppTypography.small
                          .copyWith(color: const Color(0xFFADB5BD)),
                      prefixIcon: Icon(
                        Icons.badge_outlined,
                        color: const Color(0xFF1A6FDB),
                        size: 20.sp,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 14.h,
                      ),
                    ),
                    onSubmitted: (_) => _submitManual(),
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
                SizedBox(height: 16.h),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _submitManual,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(Icons.qr_code_scanner_rounded,
                            size: 18.sp, color: Colors.white),
                    label: Text(
                      _isProcessing
                          ? 'Marking Attendance...'
                          : 'Mark Attendance',
                      style: AppTypography.small.copyWith(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A6FDB),
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 16.h),

          // Result card
          if (_lastResult != null) _buildResultCard(),
        ],
      ),
    );
  }

  // ── Camera result overlay ──
  Widget _buildResultOverlay() {
    final res = _lastResult!;
    return ScaleTransition(
      scale: _scaleAnim,
      child: Container(
        margin: EdgeInsets.all(32.r),
        padding: EdgeInsets.all(24.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 30,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              res.icon,
              size: 56.sp,
              color: res.color ?? (res.success ? Colors.green : Colors.red),
            ),
            SizedBox(height: 12.h),
            Text(
              res.message,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F2547),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Manual result card ──
  Widget _buildResultCard() {
    final res = _lastResult!;
    final color = res.color ??
        (res.success ? const Color(0xFF10B981) : const Color(0xFFEF4444));

    return ScaleTransition(
      scale: _scaleAnim,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(20.r),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(res.icon, color: color, size: 24.sp),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    res.success ? 'Attendance Marked!' : 'Could Not Mark',
                    style: GoogleFonts.outfit(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    res.message,
                    style: AppTypography.caption
                        .copyWith(color: color.withValues(alpha: 0.85)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Recent scans list ──
  Widget _buildRecentScans() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFE2EAF4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded,
                  size: 16.sp, color: const Color(0xFF1A6FDB)),
              SizedBox(width: 6.w),
              Text(
                'Recent Scans',
                style: GoogleFonts.outfit(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F2547),
                ),
              ),
              const Spacer(),
              Text(
                '${_recentScans.length} scanned',
                style: AppTypography.caption
                    .copyWith(color: const Color(0xFF868E96)),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          ...(_recentScans.take(4).map((s) => Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: Row(
                  children: [
                    Container(
                      width: 8.w,
                      height: 8.w,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        s['name'] as String,
                        style: AppTypography.caption
                            .copyWith(color: const Color(0xFF0F2547)),
                      ),
                    ),
                    Text(
                      _timeLabel(s['time'] as DateTime),
                      style: AppTypography.caption
                          .copyWith(color: const Color(0xFF868E96)),
                    ),
                    SizedBox(width: 8.w),
                    (() {
                      final status = s['status'] as String? ?? 'PRESENT';
                      final isCheckOut = status.toUpperCase() == 'CHECK-OUT';
                      return Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 8.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: isCheckOut
                              ? const Color(0xFFFEE2E2)
                              : const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          status,
                          style: AppTypography.caption.copyWith(
                              color: isCheckOut
                                  ? const Color(0xFF991B1B)
                                  : const Color(0xFF065F46)),
                        ),
                      );
                    })(),
                  ],
                ),
              ))),
        ],
      ),
    );
  }

  String _timeLabel(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ── Scan result model ──
class _ScanResult {
  final bool success;
  final String message;
  final IconData icon;
  final Color? color;
  final String? studentName;
  final String? admissionNo;

  const _ScanResult({
    required this.success,
    required this.message,
    required this.icon,
    this.color,
    this.studentName,
    this.admissionNo,
  });
}
