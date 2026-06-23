import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../config/supabase_config.dart';
import '../../theme/colors.dart';
import '../main_screen.dart';
import '../../widgets/teacher_app_bar.dart';
import '../profile_screen.dart';
import 'package:edusphere/theme/typography.dart';

class ScannerLiveScreen extends StatefulWidget {
  final RoleTheme theme;
  final String scannerId;
  final DateTime? sessionDate;
  final String? sessionAction;

  const ScannerLiveScreen({
    super.key,
    required this.theme,
    required this.scannerId,
    this.sessionDate,
    this.sessionAction,
  });

  @override
  State<ScannerLiveScreen> createState() => _ScannerLiveScreenState();
}

class _ScannerLiveScreenState extends State<ScannerLiveScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _scannerDetails;
  List<Map<String, dynamic>> _scanEvents = [];
  Timer? _refreshTimer;
  String _teacherName = 'Vikram Yadav';
  final bool _showBotBubble = true;
  RealtimeChannel? _realtimeChannel;

  // QR Scanner State
  final MobileScannerController _qrController = MobileScannerController();
  bool _isProcessingQR = false;

  // Manual scanner entry for desktop/fallback
  final TextEditingController _manualScanCtrl = TextEditingController();

  bool get _isDesktopOrWeb {
    if (kIsWeb) return true;
    try {
      const platform =
          String.fromEnvironment('FLUTTER_PLATFORM', defaultValue: '');
      if (platform.isNotEmpty) return false;
    } catch (_) {}
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  @override
  void initState() {
    super.initState();
    _loadLiveDashboard();
    _loadTeacherName();
    _setupRealtimeSubscription();

    // Set up active polling synchronization every 10 seconds for real-time monitoring
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _loadLiveFeed();
      }
    });
  }

  void _setupRealtimeSubscription() {
    try {
      const supabaseUrl = SupabaseConfig.supabaseUrl;
      debugPrint(
          '⚡ [Realtime Subscription Status] Subscribing to AttendanceRecord realtime changes. URL: $supabaseUrl');

      _realtimeChannel = Supabase.instance.client
          .channel('public:AttendanceRecord')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'AttendanceRecord',
            callback: (payload) {
              debugPrint(
                  '⚡ [Realtime Change Received] Event: ${payload.eventType}, Payload: ${payload.newRecord}');
              if (mounted) {
                _loadLiveFeed();
              }
            },
          );
      _realtimeChannel!.subscribe((status, [error]) {
        debugPrint(
            '⚡ [Realtime Subscription Status] Connection state: $status ${error != null ? "- Error: $error" : ""}');
      });
    } catch (e) {
      debugPrint('⚡ [Realtime Subscription Error] Failed to subscribe: $e');
    }
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

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _qrController.dispose();
    _manualScanCtrl.dispose();
    if (_realtimeChannel != null) {
      try {
        Supabase.instance.client.removeChannel(_realtimeChannel!);
      } catch (e) {
        debugPrint('⚠️ [Realtime Dispose Error] Failed to remove channel: $e');
      }
    }
    super.dispose();
  }

  Future<void> _processQRData(String rawCode) async {
    if (_isProcessingQR) return;
    setState(() => _isProcessingQR = true);
    await _qrController.stop();

    debugPrint(
        '================================================================');
    debugPrint('📸 [QR SCAN INITIATED]');
    debugPrint('📍 Current scannerId: ${widget.scannerId}');
    debugPrint('📦 QR payload: $rawCode');

    try {
      final codeTrimmed = rawCode.trim();

      // Check if it's a teacher employeeId first
      final teacherRes = await Supabase.instance.client
          .from('Teacher')
          .select('id, userId, employeeId, user:User(firstName, lastName)')
          .eq('employeeId', codeTrimmed)
          .maybeSingle();

      if (teacherRes != null) {
        final teacherId = teacherRes['id'].toString();
        final teacherUserId = teacherRes['userId']?.toString();
        final user = teacherRes['user'] as Map<String, dynamic>? ?? {};
        final teacherName =
            '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
        debugPrint(
            '👤 Teacher Identified - ID: $teacherId, Name: $teacherName, UserID: $teacherUserId');

        // Ensure the scanner exists in the database
        await _ensureScannerExists(widget.scannerId);

        final dateStr = widget.sessionDate != null
            ? widget.sessionDate!.toIso8601String().substring(0, 10)
            : DateTime.now().toIso8601String().substring(0, 10);

        final isCheckIn = widget.sessionAction?.toLowerCase() == 'check-in' ||
            widget.sessionAction?.toLowerCase() == 'check_in';

        final Map<String, dynamic> scanData = {
          'attendeeType': 'TEACHER',
          'teacherId': teacherId,
          'date': dateStr,
          'status': 'PRESENT',
          'scannedByQR': true,
          'scannerId': widget.scannerId,
          'updatedAt': DateTime.now().toIso8601String(),
        };

        if (isCheckIn) {
          scanData['checkInTime'] = DateTime.now().toIso8601String();
        } else {
          scanData['checkOutTime'] = DateTime.now().toIso8601String();
        }

        debugPrint('📤 Teacher Attendance insert payload: $scanData');

        final insertResponse = await Supabase.instance.client
            .from('AttendanceRecord')
            .insert(scanData)
            .select()
            .single();

        debugPrint('📥 Teacher Attendance insert response: $insertResponse');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Successfully scanned Teacher: $teacherName'),
                backgroundColor: AppColors.success),
          );
          if (teacherUserId != null) {
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
        }
        await _loadLiveFeed();
        return;
      }

      // Check if it's a student admission number
      final studentRes = await Supabase.instance.client
          .from('Student')
          .select('id, user:User(firstName, lastName)')
          .eq('admissionNumber', codeTrimmed)
          .maybeSingle();

      if (studentRes == null) {
        debugPrint(
            '❌ [QR SCAN ERROR] Student/Teacher not found for QR payload: $codeTrimmed');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Student/Teacher not found for QR: $codeTrimmed'),
                backgroundColor: AppColors.error),
          );
        }
        return;
      }

      final studentId = studentRes['id'].toString();
      final user = studentRes['user'] as Map<String, dynamic>? ?? {};
      final studentName =
          '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();

      debugPrint('👤 Student Identified - ID: $studentId, Name: $studentName');

      // Ensure the scanner exists in the database
      await _ensureScannerExists(widget.scannerId);

      final dateStr = widget.sessionDate != null
          ? widget.sessionDate!.toIso8601String().substring(0, 10)
          : DateTime.now().toIso8601String().substring(0, 10);

      final isCheckIn = widget.sessionAction?.toLowerCase() == 'check-in' ||
          widget.sessionAction?.toLowerCase() == 'check_in';

      final Map<String, dynamic> scanData = {
        'attendeeType': 'STUDENT',
        'studentId': studentId,
        'date': dateStr,
        'status': 'PRESENT',
        'scannedByQR': true,
        'scannerId': widget.scannerId,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (isCheckIn) {
        scanData['checkInTime'] = DateTime.now().toIso8601String();
      } else {
        scanData['checkOutTime'] = DateTime.now().toIso8601String();
      }

      debugPrint('📤 Attendance insert request payload: $scanData');

      final insertResponse = await Supabase.instance.client
          .from('AttendanceRecord')
          .insert(scanData)
          .select()
          .single();

      debugPrint('📥 Attendance insert response: $insertResponse');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Successfully scanned: $studentName'),
              backgroundColor: AppColors.success),
        );
      }
      await _loadLiveFeed();
    } catch (e) {
      debugPrint('❌ [QR SCAN EXCEPTION] Error processing QR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error marking attendance: $e'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      debugPrint(
          '================================================================');
      if (mounted) {
        setState(() => _isProcessingQR = false);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && !_isDesktopOrWeb) {
            _qrController.start();
          }
        });
      }
    }
  }

  Future<void> _loadTeacherName() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final profileRes = await Supabase.instance.client
            .from('User')
            .select('firstName, lastName')
            .eq('id', user.id)
            .maybeSingle();
        if (profileRes != null && mounted) {
          final pFName = profileRes['firstName'] as String? ?? '';
          final pLName = profileRes['lastName'] as String? ?? '';
          setState(() {
            _teacherName = '$pFName $pLName'.trim();
          });
        }
      } catch (e) {
        debugPrint('Error loading teacher profile name: $e');
      }
    }
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
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadLiveFeed() async {
    try {
      final dateStr = widget.sessionDate != null
          ? widget.sessionDate!.toIso8601String().substring(0, 10)
          : DateTime.now().toIso8601String().substring(0, 10);

      final recordsRes = await Supabase.instance.client
          .from('AttendanceRecord')
          .select(
              '*, student:Student(*, user:User(*)), teacher:Teacher(*, user:User(*)), staff:Staff(*, user:User(*))')
          .eq('scannerId', widget.scannerId)
          .eq('date', dateStr)
          .order('createdAt', ascending: false)
          .limit(40);

      final records = List<Map<String, dynamic>>.from(recordsRes);
      final actionFilter =
          widget.sessionAction?.toUpperCase().replaceAll('-', '_');

      // Decompose row check-in / check-out timestamps into distinct chronological scan events
      final List<Map<String, dynamic>> tempEvents = [];
      for (var rec in records) {
        final name = _getAttendeeName(rec);
        final status = (rec['status'] ?? 'PRESENT').toString();

        final checkInTimeStr = rec['checkInTime'];
        final checkOutTimeStr = rec['checkOutTime'];

        if (checkOutTimeStr != null &&
            (actionFilter == null || actionFilter == 'CHECK_OUT')) {
          tempEvents.add({
            'id': '${rec['id']}_out',
            'name': name,
            'time': checkOutTimeStr,
            'action': 'CHECK_OUT',
            'status': status,
            'type': (rec['attendeeType'] ?? 'STUDENT').toString(),
          });
        }
        if (checkInTimeStr != null &&
            (actionFilter == null || actionFilter == 'CHECK_IN')) {
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

  Future<void> _submitManualScan() async {
    final code = _manualScanCtrl.text.trim();
    if (code.isEmpty) return;
    _manualScanCtrl.clear();
    await _processQRData(code);
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

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final scannerName = _scannerDetails?['name'] ?? 'main gate scanner';
    final type = _scannerDetails?['scannerType'] ?? 'ENTRY';
    final scannerCode = widget.scannerId.length >= 8
        ? widget.scannerId.substring(0, 8)
        : 'abcdefgh';
    final dateStr = widget.sessionDate != null
        ? _formatDate(widget.sessionDate!)
        : _formatDate(DateTime.now());
    final isCheckIn = widget.sessionAction?.toLowerCase() == 'check-in' ||
        widget.sessionAction?.toLowerCase() == 'check_in';

    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 800;

    return Scaffold(
      appBar: const TeacherAppBar(title: 'EduSphere'),
      backgroundColor: const Color(0xFFF8FAFC),
      bottomNavigationBar: const TeacherBottomNavBar(activeIndex: 5),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: widget.theme.primary,
                strokeWidth: 3.w,
              ),
            )
          : Stack(
              children: [
                Column(
                  children: [
                    // Top Bar Header
                    _buildTopBar(scannerName, type, scannerCode),

                    // Body Area
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.symmetric(
                            horizontal: 24.w, vertical: 16.h),
                        child: Center(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 1200),
                            child: Column(
                              children: [
                                _buildGreenBanner(dateStr, isCheckIn),
                                SizedBox(height: 20.h),
                                _buildMainLayout(isDesktop),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Speech Bubble for bot greeting
                if (_showBotBubble)
                  Positioned(
                    bottom: 96.h,
                    right: 24.w,
                    child: _buildBotBubble(),
                  ),

                // AI Helper chatbot floating action button
                Positioned(
                  bottom: 30.h,
                  right: 20.w,
                  child: FloatingActionButton(
                    heroTag: 'scanner_chatbot_fab',
                    onPressed: _showChatbotDialog,
                    backgroundColor: const Color(0xFF0284C7),
                    child: const Icon(Icons.auto_awesome, color: Colors.white),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTopBar(String name, String type, String code) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isNarrow = constraints.maxWidth < 800;

        if (isNarrow) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_rounded,
                          color: const Color(0xFF1E293B), size: 22.sp),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    SizedBox(width: 8.w),
                    Flexible(
                      child: Text(
                        name,
                        style: AppTypography.small
                            .copyWith(color: const Color(0xFF0F172A)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF5FF),
                        borderRadius: BorderRadius.circular(4.r),
                        border: Border.all(color: const Color(0xFFE9D5FF)),
                      ),
                      child: Text(
                        type.toUpperCase(),
                        style: AppTypography.caption
                            .copyWith(color: const Color(0xFF7E22CE)),
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      code,
                      style: AppTypography.caption
                          .copyWith(color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
                SizedBox(height: 6.h),
                Padding(
                  padding: EdgeInsets.only(left: 30.w),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Scanning: STUDENT, TEACHER, STAFF',
                          style: AppTypography.caption
                              .copyWith(color: const Color(0xFF64748B)),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(4.r),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_off_rounded,
                              size: 11.sp,
                              color: const Color(0xFFD97706),
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              'GPS Pending',
                              style: AppTypography.caption
                                  .copyWith(color: const Color(0xFFD97706)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // Desktop Layout
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded,
                    color: const Color(0xFF1E293B), size: 22.sp),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              SizedBox(width: 12.w),
              Flexible(
                child: Text(
                  name,
                  style: AppTypography.small
                      .copyWith(color: const Color(0xFF0F172A)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 10.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF5FF),
                  borderRadius: BorderRadius.circular(6.r),
                  border: Border.all(color: const Color(0xFFE9D5FF)),
                ),
                child: Text(
                  type.toUpperCase(),
                  style: AppTypography.caption
                      .copyWith(color: const Color(0xFF7E22CE)),
                ),
              ),
              SizedBox(width: 10.w),
              Text(
                code,
                style: AppTypography.caption
                    .copyWith(color: const Color(0xFF64748B)),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6.r),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_off_rounded,
                      size: 13.sp,
                      color: const Color(0xFFD97706),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      'GPS Pending',
                      style: AppTypography.caption
                          .copyWith(color: const Color(0xFFD97706)),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 16.w),
              Text(
                'Scanning: STUDENT, TEACHER, STAFF',
                style: AppTypography.caption
                    .copyWith(color: const Color(0xFF475569)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGreenBanner(String dateStr, bool isCheckIn) {
    final modeText = isCheckIn ? 'CHECKIN MODE ACTIVE' : 'CHECKOUT MODE ACTIVE';
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFDCFCE7), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 32.w,
            height: 32.h,
            decoration: const BoxDecoration(
              color: Color(0xFFDCFCE7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_add_alt_1_rounded,
              color: Color(0xFF16A34A),
              size: 16,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  modeText,
                  style: AppTypography.caption
                      .copyWith(color: const Color(0xFF14532D)),
                ),
                SizedBox(height: 2.h),
                Text(
                  '$dateStr - Ready for Scans',
                  style: AppTypography.caption
                      .copyWith(color: const Color(0xFF166534)),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Text(
              'Change Params',
              style: AppTypography.caption.copyWith(
                  color: const Color(0xFF475569),
                  decoration: TextDecoration.underline),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainLayout(bool isDesktop) {
    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 6,
            child: _buildCameraPanel(),
          ),
          SizedBox(width: 20.w),
          Expanded(
            flex: 4,
            child: _buildLiveFeedPanel(),
          ),
        ],
      );
    } else {
      return Column(
        children: [
          _buildCameraPanel(),
          SizedBox(height: 20.h),
          _buildLiveFeedPanel(),
        ],
      );
    }
  }

  Widget _buildCameraPanel() {
    return Container(
      width: double.infinity,
      height: 420.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: _isDesktopOrWeb
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.desktop_windows_rounded,
                  size: 48.sp,
                  color: const Color(0xFF94A3B8),
                ),
                SizedBox(height: 12.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: Text(
                    'Camera scanning is not supported on this device/browser. Please type student QR payload below to verify & scan.',
                    style: AppTypography.caption
                        .copyWith(color: const Color(0xFF64748B)),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 20.h),
                _buildManualEntryField(),
              ],
            )
          : Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16.r),
                  child: Stack(
                    children: [
                      MobileScanner(
                        controller: _qrController,
                        onDetect: (capture) async {
                          if (_isProcessingQR) return;
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
                          width: 250.w,
                          height: 250.w,
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: widget.theme.primary, width: 6),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isProcessingQR)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(16.r),
                    ),
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
              ],
            ),
    );
  }

  Widget _buildManualEntryField() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              controller: _manualScanCtrl,
              style:
                  AppTypography.small.copyWith(color: const Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: 'Enter Student QR Payload (e.g. ADM-2023-0681)',
                hintStyle: AppTypography.caption
                    .copyWith(color: const Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.qr_code_2_rounded,
                    color: Color(0xFF64748B)),
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              ),
              onSubmitted: (_) => _submitManualScan(),
            ),
          ),
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submitManualScan,
              icon: const Icon(Icons.search, color: Colors.white, size: 18),
              label: Text(
                'Verify & Scan',
                style: AppTypography.caption.copyWith(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.theme.primary,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveFeedPanel() {
    return Container(
      width: double.infinity,
      height: 420.h,
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Live Feed',
            style: AppTypography.small.copyWith(color: const Color(0xFF0F172A)),
          ),
          SizedBox(height: 2.h),
          Text(
            'Scans will appear here in real-time',
            style:
                AppTypography.caption.copyWith(color: const Color(0xFF64748B)),
          ),
          SizedBox(height: 16.h),
          Expanded(
            child: _scanEvents.isEmpty
                ? _buildEmptyFeedState()
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: _scanEvents.length,
                    itemBuilder: (context, index) {
                      return _buildScanRow(_scanEvents[index]);
                    },
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
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
                  style:
                      AppTypography.caption.copyWith(color: AppColors.textDark),
                ),
                SizedBox(height: 3.h),
                Row(
                  children: [
                    Text(
                      isCheckIn ? 'Check-In' : 'Check-Out',
                      style: AppTypography.caption.copyWith(
                          color:
                              isCheckIn ? AppColors.success : AppColors.error),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      '•  ${type.toUpperCase()}',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textLight),
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
                  style: AppTypography.caption.copyWith(
                      color: status.toUpperCase() == 'LATE'
                          ? AppColors.warning
                          : AppColors.success,
                      letterSpacing: 0.5),
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                formattedTime,
                style:
                    AppTypography.caption.copyWith(color: AppColors.textMedium),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_toggle_off_rounded,
            size: 36.sp,
            color: AppColors.textLight,
          ),
          SizedBox(height: 10.h),
          Text(
            'No scans detected today',
            style: AppTypography.caption.copyWith(color: AppColors.textDark),
          ),
          SizedBox(height: 4.h),
          Text(
            'Scanned cards will appear here in real-time.',
            style: AppTypography.caption.copyWith(color: AppColors.textMedium),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBotBubble() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Text(
        'HI\n${_teacherName.split(" ").first.toUpperCase()}!\nHOW\nCAN I\nHELP?',
        style: AppTypography.caption
            .copyWith(color: const Color(0xFF0284C7), height: 1.2),
        textAlign: TextAlign.center,
      ),
    );
  }

  void _showChatbotDialog() {
    final messageCtrl = TextEditingController();
    final List<Map<String, String>> chatMessages = [
      {
        'sender': 'bot',
        'text':
            'Hello $_teacherName! I am your EduSphere Scanner Helper. How can I assist you with scanning sessions or attendance logs today?'
      }
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          title: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Color(0xFF0284C7)),
              SizedBox(width: 8.w),
              Text('AI Scanning Assistant', style: AppTypography.body),
            ],
          ),
          content: SizedBox(
            width: 320.w,
            height: 350.h,
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: chatMessages.length,
                    itemBuilder: (context, index) {
                      final msg = chatMessages[index];
                      final isBot = msg['sender'] == 'bot';
                      return Align(
                        alignment: isBot
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        child: Container(
                          margin: EdgeInsets.symmetric(vertical: 4.h),
                          padding: EdgeInsets.symmetric(
                              horizontal: 14.w, vertical: 10.h),
                          decoration: BoxDecoration(
                            color: isBot
                                ? const Color(0xFFF1F5F9)
                                : const Color(0xFF0284C7),
                            borderRadius: BorderRadius.circular(16.r).copyWith(
                                topLeft:
                                    isBot ? Radius.zero : Radius.circular(16.r),
                                topRight: isBot
                                    ? Radius.circular(16.r)
                                    : Radius.zero),
                          ),
                          child: Text(
                            msg['text']!,
                            style: AppTypography.caption.copyWith(
                                color: isBot
                                    ? const Color(0xFF1E293B)
                                    : Colors.white),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: messageCtrl,
                        decoration: InputDecoration(
                          hintText: 'Ask helper...',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: BorderSide.none),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 14.w, vertical: 10.h),
                        ),
                        onFieldSubmitted: (val) {
                          if (val.trim().isEmpty) return;
                          setDialogState(() {
                            chatMessages.add({'sender': 'user', 'text': val});
                            final reply = _getBotReply(val);
                            chatMessages.add({'sender': 'bot', 'text': reply});
                          });
                          messageCtrl.clear();
                        },
                      ),
                    ),
                    SizedBox(width: 8.w),
                    IconButton(
                      icon: const Icon(Icons.send, color: Color(0xFF0284C7)),
                      onPressed: () {
                        final val = messageCtrl.text;
                        if (val.trim().isEmpty) return;
                        setDialogState(() {
                          chatMessages.add({'sender': 'user', 'text': val});
                          final reply = _getBotReply(val);
                          chatMessages.add({'sender': 'bot', 'text': reply});
                        });
                        messageCtrl.clear();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            )
          ],
        ),
      ),
    );
  }

  String _getBotReply(String query) {
    query = query.toLowerCase();
    final name = _scannerDetails?['name'] ?? 'main gate scanner';
    final loc = _scannerDetails?['location'] ?? 'Main Gate';

    if (query.contains('scanner') || query.contains('device')) {
      return 'You are currently using "$name" located at "$loc".';
    }
    if (query.contains('check-in') ||
        query.contains('checkin') ||
        query.contains('entry')) {
      return 'The scanner session is in CHECK-IN mode. All successful scans mark matching students as present for Entry.';
    }
    if (query.contains('check-out') ||
        query.contains('checkout') ||
        query.contains('exit')) {
      return 'To toggle Check-Out logging, tap "Change Params" in the green active banner to configure variables.';
    }
    if (query.contains('gps') || query.contains('location')) {
      return 'The coordinate verification check is "GPS Pending" while calibrating alignment criteria.';
    }
    if (query.contains('clear') || query.contains('reset')) {
      return 'Logs are synced immediately to the Supabase database and cannot be cleared from this screen interface.';
    }
    return 'I can assist you with active scanner modes, real-time feed listings, and database logging. What would you like to know?';
  }
}
