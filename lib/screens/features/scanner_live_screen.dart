import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import '../../theme/colors.dart';
import '../main_screen.dart';

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
  List<Map<String, dynamic>> _availableStudents = [];
  String _teacherName = 'Vikram Yadav';
  final bool _showBotBubble = true;
  bool _isSimulating = false;
  
  // QR Scanner State
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? _qrController;
  bool _isProcessingQR = false;

  bool get _isDesktopOrWeb {
    if (kIsWeb) return true;
    try {
      const platform = String.fromEnvironment('FLUTTER_PLATFORM', defaultValue: '');
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
    _qrController?.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      _qrController = controller;
    });
    controller.scannedDataStream.listen((scanData) async {
      if (_isProcessingQR) return;
      final code = scanData.code?.trim() ?? '';
      if (code.isEmpty) return;
      await _processQRData(code);
    });
  }

  Future<void> _processQRData(String rawCode) async {
    if (_isProcessingQR) return;
    setState(() => _isProcessingQR = true);
    await _qrController?.pauseCamera();

    try {
      final admissionNo = rawCode.trim();
      final studentRes = await Supabase.instance.client
          .from('Student')
          .select('id, user:User(firstName, lastName)')
          .eq('admissionNumber', admissionNo)
          .maybeSingle();

      if (studentRes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Student not found for QR: $admissionNo'), backgroundColor: AppColors.error),
          );
        }
        return;
      }

      final studentId = studentRes['id'].toString();
      final user = studentRes['user'] as Map<String, dynamic>? ?? {};
      final studentName = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
      
      final dateStr = widget.sessionDate != null
          ? widget.sessionDate!.toIso8601String().substring(0, 10)
          : DateTime.now().toIso8601String().substring(0, 10);
          
      final isCheckIn = widget.sessionAction?.toLowerCase() == 'check-in' || widget.sessionAction?.toLowerCase() == 'check_in';
      
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

      await Supabase.instance.client.from('AttendanceRecord').insert(scanData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully scanned: $studentName'), backgroundColor: AppColors.success),
        );
      }
      await _loadLiveFeed();
    } catch (e) {
      debugPrint('Error processing QR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error marking attendance: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingQR = false);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && !_isDesktopOrWeb) {
            _qrController?.resumeCamera();
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

      // 3. Pre-fetch available students for simulation
      await _loadAvailableStudents();
    } catch (e) {
      debugPrint('Error loading live dashboard details: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadAvailableStudents() async {
    try {
      final res = await Supabase.instance.client
          .from('Student')
          .select('id, user:User(firstName, lastName)');
      _availableStudents = List<Map<String, dynamic>>.from(res);
        } catch (e) {
      debugPrint('Error loading students for simulation: $e');
    }
  }

  Future<void> _loadLiveFeed() async {
    try {
      final dateStr = widget.sessionDate != null
          ? widget.sessionDate!.toIso8601String().substring(0, 10)
          : DateTime.now().toIso8601String().substring(0, 10);
      
      final recordsRes = await Supabase.instance.client
          .from('AttendanceRecord')
          .select('*, student:Student(*, user:User(*)), teacher:Teacher(*, user:User(*)), staff:Staff(*, user:User(*))')
          .eq('scannerId', widget.scannerId)
          .eq('date', dateStr)
          .order('createdAt', ascending: false)
          .limit(40);

      final records = List<Map<String, dynamic>>.from(recordsRes);
      final actionFilter = widget.sessionAction?.toUpperCase().replaceAll('-', '_');

      // Decompose row check-in / check-out timestamps into distinct chronological scan events
      final List<Map<String, dynamic>> tempEvents = [];
      for (var rec in records) {
        final name = _getAttendeeName(rec);
        final status = (rec['status'] ?? 'PRESENT').toString();
        
        final checkInTimeStr = rec['checkInTime'];
        final checkOutTimeStr = rec['checkOutTime'];

        if (checkOutTimeStr != null && (actionFilter == null || actionFilter == 'CHECK_OUT')) {
          tempEvents.add({
            'id': '${rec['id']}_out',
            'name': name,
            'time': checkOutTimeStr,
            'action': 'CHECK_OUT',
            'status': status,
            'type': (rec['attendeeType'] ?? 'STUDENT').toString(),
          });
        }
        if (checkInTimeStr != null && (actionFilter == null || actionFilter == 'CHECK_IN')) {
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

  Future<void> _simulateScan() async {
    if (_isSimulating) return;
    setState(() => _isSimulating = true);

    try {
      if (_availableStudents.isEmpty) {
        await _loadAvailableStudents();
      }

      if (_availableStudents.isNotEmpty) {
        final student = _availableStudents[Random().nextInt(_availableStudents.length)];
        
        final dateStr = widget.sessionDate != null
            ? widget.sessionDate!.toIso8601String().substring(0, 10)
            : DateTime.now().toIso8601String().substring(0, 10);
            
        final isCheckIn = widget.sessionAction?.toLowerCase() == 'check-in' || widget.sessionAction?.toLowerCase() == 'check_in';
        
        final Map<String, dynamic> scanData = {
          'attendeeType': 'STUDENT',
          'studentId': student['id'],
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

        await Supabase.instance.client
            .from('AttendanceRecord')
            .insert(scanData);

        final studentName = student['user'] != null
            ? '${student['user']['firstName'] ?? ''} ${student['user']['lastName'] ?? ''}'.trim()
            : 'Student';

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully scanned QR for $studentName'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        await _loadLiveFeed();
      } else {
        // Fallback: Mock in-memory scan if no students found in DB
        final mockName = 'Test Student ${Random().nextInt(100) + 1}';
        final mockEvent = {
          'id': 'mock_${DateTime.now().millisecondsSinceEpoch}',
          'name': mockName,
          'time': DateTime.now().toIso8601String(),
          'action': widget.sessionAction?.toUpperCase().replaceAll('-', '_') ?? 'CHECK_IN',
          'status': 'PRESENT',
          'type': 'STUDENT',
        };
        setState(() {
          _scanEvents.insert(0, mockEvent);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully simulated scan for $mockName (local mode)'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error simulating scan: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to simulate scan record: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSimulating = false);
      }
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

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final scannerName = _scannerDetails?['name'] ?? 'main gate scanner';
    final type = _scannerDetails?['scannerType'] ?? 'ENTRY';
    final scannerCode = widget.scannerId.length >= 8 ? widget.scannerId.substring(0, 8) : 'abcdefgh';
    final dateStr = widget.sessionDate != null ? _formatDate(widget.sessionDate!) : _formatDate(DateTime.now());
    final isCheckIn = widget.sessionAction?.toLowerCase() == 'check-in' || widget.sessionAction?.toLowerCase() == 'check_in';
    
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 800;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        leading: IconButton(
          icon: Icon(Icons.menu, size: 28),
          onPressed: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
            MainScreen.openDrawer();
          },
        ),
        title: Text(
          'EduSphere',
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_none_rounded, size: 28),
            onPressed: () {},
          ),
          SizedBox(width: 8),
        ],
      ),

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
                        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
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
                      icon: Icon(Icons.arrow_back_rounded, color: const Color(0xFF1E293B), size: 22.sp),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    SizedBox(width: 8.w),
                    Flexible(
                      child: Text(
                        name,
                        style: GoogleFonts.inter(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF5FF),
                        borderRadius: BorderRadius.circular(4.r),
                        border: Border.all(color: const Color(0xFFE9D5FF)),
                      ),
                      child: Text(
                        type.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF7E22CE),
                        ),
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      code,
                      style: GoogleFonts.inter(
                        fontSize: 10.sp,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
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
                          style: GoogleFonts.inter(
                            fontSize: 10.sp,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
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
                              style: GoogleFonts.inter(
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFD97706),
                              ),
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
                icon: Icon(Icons.arrow_back_rounded, color: const Color(0xFF1E293B), size: 22.sp),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              SizedBox(width: 12.w),
              Flexible(
                child: Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
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
                  style: GoogleFonts.inter(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF7E22CE),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Text(
                code,
                style: GoogleFonts.inter(
                  fontSize: 11.sp,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
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
                      style: GoogleFonts.inter(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 16.w),
              Text(
                'Scanning: STUDENT, TEACHER, STAFF',
                style: GoogleFonts.inter(
                  fontSize: 11.sp,
                  color: const Color(0xFF475569),
                  fontWeight: FontWeight.w700,
                ),
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
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF14532D),
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  '$dateStr - Ready for Scans',
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    color: const Color(0xFF166534),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Text(
              'Change Params',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF475569),
                decoration: TextDecoration.underline,
              ),
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
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Text(
                    'Camera scanning is not supported on this device/browser.\nPlease use the simulate button below for testing.',
                    style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 24.h),
                _buildSimulateButton(),
              ],
            )
          : Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16.r),
                  child: QRView(
                    key: qrKey,
                    onQRViewCreated: _onQRViewCreated,
                    overlay: QrScannerOverlayShape(
                      borderColor: widget.theme.primary,
                      borderRadius: 16,
                      borderLength: 30,
                      borderWidth: 6,
                      cutOutSize: 250.w,
                    ),
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
                Positioned(
                  bottom: 20.h,
                  child: _buildSimulateButton(),
                ),
              ],
            ),
    );
  }

  Widget _buildSimulateButton() {
    return ElevatedButton.icon(
      onPressed: _simulateScan,
      icon: _isSimulating
          ? SizedBox(
              width: 16.w,
              height: 16.w,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.w,
              ),
            )
          : Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 18.sp),
      label: Text(
        _isSimulating ? 'Simulating Scan...' : 'Simulate Scan (Test Mode)',
        style: GoogleFonts.inter(
          fontSize: 12.sp,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: widget.theme.primary,
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.r),
        ),
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
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            'Scans will appear here in real-time',
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
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
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 3.h),
                Row(
                  children: [
                    Text(
                      isCheckIn ? 'Check-In' : 'Check-Out',
                      style: GoogleFonts.inter(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w800,
                        color: isCheckIn ? AppColors.success : AppColors.error,
                      ),
                    ),
                    SizedBox(width: 8.w),
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
            style: GoogleFonts.inter(
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Scanned cards will appear here in real-time.',
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
        style: GoogleFonts.inter(
          fontSize: 10.sp,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF0284C7),
          height: 1.2,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  void _showChatbotDialog() {
    final messageCtrl = TextEditingController();
    final List<Map<String, String>> chatMessages = [
      {
        'sender': 'bot',
        'text': 'Hello $_teacherName! I am your EduSphere Scanner Helper. How can I assist you with scanning sessions or attendance logs today?'
      }
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          title: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Color(0xFF0284C7)),
              SizedBox(width: 8.w),
              Text('AI Scanning Assistant', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16.sp)),
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
                        alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
                        child: Container(
                          margin: EdgeInsets.symmetric(vertical: 4.h),
                          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                          decoration: BoxDecoration(
                            color: isBot ? const Color(0xFFF1F5F9) : const Color(0xFF0284C7),
                            borderRadius: BorderRadius.circular(16.r).copyWith(
                              topLeft: isBot ? Radius.zero : Radius.circular(16.r),
                              topRight: isBot ? Radius.circular(16.r) : Radius.zero,
                            ),
                          ),
                          child: Text(
                            msg['text']!,
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              color: isBot ? const Color(0xFF1E293B) : Colors.white,
                            ),
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
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none),
                          contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
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
    if (query.contains('check-in') || query.contains('checkin') || query.contains('entry')) {
      return 'The scanner session is in CHECK-IN mode. All successful scans mark matching students as present for Entry.';
    }
    if (query.contains('check-out') || query.contains('checkout') || query.contains('exit')) {
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
