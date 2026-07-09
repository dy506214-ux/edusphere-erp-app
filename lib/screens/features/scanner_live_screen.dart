import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:dio/dio.dart';
import '../../widgets/common_widgets.dart';
import '../../theme/colors.dart';
import '../main_screen.dart';
import '../../widgets/teacher_app_bar.dart';
import '../../widgets/teacher_scaffold.dart';
import '../profile_screen.dart';
import 'package:edusphere/theme/typography.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/socket_service.dart';
import '../../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

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

class _ScannerLiveScreenState extends State<ScannerLiveScreen> with WidgetsBindingObserver {
  bool _isLoading = true;
  Map<String, dynamic>? _scannerDetails;
  List<Map<String, dynamic>> _scanEvents = [];
  Timer? _refreshTimer;
  String _teacherName = 'Vikram Yadav';
  final bool _showBotBubble = true;

  // Socket.IO event handler helper
  void _onAttendanceMarked(dynamic data) {
    debugPrint('⚡ [Socket Event] ATTENDANCE_MARKED: $data');
    if (mounted) {
      _loadLiveFeed();
    }
  }

  // QR Scanner State
  final MobileScannerController _qrController = MobileScannerController();
  bool _isProcessingQR = false;
  bool _cameraPermissionDenied = false;

  // GPS Tracking State
  Position? _currentPosition;
  StreamSubscription<Position>? _positionSubscription;
  String _gpsStatus = 'GPS Pending';

  bool get _isDesktopPlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  bool get _isDesktopOrWeb {
    if (kIsWeb) return false; // Enable camera access on Web browser
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
    WidgetsBinding.instance.addObserver(this);
    _requestCameraPermission();
    _initGPSTracking();
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

  Future<void> _requestCameraPermission() async {
    try {
      final status = await Permission.camera.request();
      debugPrint('📷 [Camera Permission Status] $status');
      if (mounted) {
        setState(() {
          _cameraPermissionDenied = status.isDenied || status.isPermanentlyDenied;
        });
      }
    } catch (e) {
      debugPrint('⚠️ [Camera Permission Error] Failed to request permission: $e');
    }
  }

  Future<void> _initGPSTracking() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _gpsStatus = 'GPS Error';
          });
        }
        return;
      }

      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _gpsStatus = 'GPS Error';
          });
        }
        return;
      }

      final Position initialPos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) {
        setState(() {
          _currentPosition = initialPos;
          _gpsStatus = 'GPS Ready';
        });
      }

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen(
        (Position pos) {
          if (mounted) {
            setState(() {
              _currentPosition = pos;
              _gpsStatus = 'GPS Ready';
            });
          }
        },
        onError: (err) {
          debugPrint('⚠️ [Geolocator Stream Error] $err');
          if (mounted) {
            setState(() {
              _gpsStatus = 'GPS Error';
            });
          }
        },
      );
    } catch (e) {
      debugPrint('⚠️ [Geolocator Init Error] $e');
      if (mounted) {
        setState(() {
          _gpsStatus = 'GPS Error';
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_cameraPermissionDenied && !_isDesktopOrWeb) {
        try {
          _qrController.start();
        } catch (e) {
          debugPrint('Error starting camera: $e');
        }
      }
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      try {
        _qrController.stop();
      } catch (e) {
        debugPrint('Error stopping camera: $e');
      }
    }
  }

  void _setupRealtimeSubscription() {
    try {
      debugPrint('⚡ [Socket.IO Subscription] Listening to ATTENDANCE_MARKED events');
      SocketService().on('ATTENDANCE_MARKED', _onAttendanceMarked);
    } catch (e) {
      debugPrint('⚡ [Socket.IO Subscription Error] Failed to subscribe: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _qrController.dispose();
    _positionSubscription?.cancel();
    try {
      SocketService().off('ATTENDANCE_MARKED', _onAttendanceMarked);
    } catch (e) {
      debugPrint('⚠️ [Socket.IO Dispose Error] Failed to remove listener: $e');
    }
    super.dispose();
  }

  Future<void> _processQRData(String rawCode) async {
    if (_isProcessingQR) return;
    setState(() => _isProcessingQR = true);
    await _qrController.stop();

    debugPrint(
        '================================================================');
    debugPrint('📸 [QR SCAN INITIATED (REST API)]');
    debugPrint('📍 Current scannerId: ${widget.scannerId}');
    debugPrint('📦 QR payload: $rawCode');

    try {
      final isCheckIn = widget.sessionAction?.toLowerCase() == 'check-in' ||
          widget.sessionAction?.toLowerCase() == 'check_in';
      final actionParam = isCheckIn ? 'checkin' : 'checkout';

      final dateStr = widget.sessionDate != null
          ? _formatDate(widget.sessionDate!)
          : _formatDate(DateTime.now());

      final response = await ApiService.instance.post('attendance/qr-scan', body: {
        'qrPayload': rawCode.trim(),
        'scannerId': widget.scannerId,
        'action': actionParam,
        'date': dateStr,
        'scanLat': _currentPosition?.latitude,
        'scanLng': _currentPosition?.longitude,
      });

      if (response != null && response['success'] == true) {
        final user = response['user'] as Map<String, dynamic>? ?? {};
        final attendeeName = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
        final action = response['action'] as String?;
        final isCheckout = action == 'checkout';

        if (mounted) {
          showToast(
            context,
            isCheckout ? 'Successfully checked out: $attendeeName' : 'Successfully scanned: $attendeeName',
          );
          final String role = user['role']?.toString().toLowerCase() ?? '';
          if (role == 'teacher' && user['id'] != null) {
            final teacherUserId = user['id'].toString();
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
        await _refreshDashboardData();
      } else {
        final errorMsg = response != null ? (response['error'] ?? response['message']) : 'Failed to mark attendance';
        if (mounted) {
          showToast(context, 'Error: $errorMsg', isError: true);
        }
      }
    } catch (e) {
      debugPrint('❌ [QR SCAN EXCEPTION] Error processing QR: $e');
      if (mounted) {
        String errorMsg = 'Error marking attendance. Please try again.';
        if (e is DioException) {
          final res = e.response;
          if (res != null) {
            if (res.data is Map) {
              errorMsg = res.data['message'] ?? res.data['error'] ?? errorMsg;
            } else if (res.statusCode == 404) {
              errorMsg = 'Scanner or student profile not found on the server.';
            } else if (res.statusCode == 403) {
              errorMsg = 'Access denied. Check scanner geofence or role configuration.';
            } else if (res.statusCode == 400) {
              errorMsg = 'Invalid QR Code or already marked.';
            }
          } else {
            errorMsg = 'Unable to connect to the server. Please check your internet connection.';
          }
        } else if (e.toString().contains('404')) {
          errorMsg = 'Scanner or student profile not found on the server.';
        } else if (e.toString().contains('403')) {
          errorMsg = 'Access denied. Check scanner geofence or role configuration.';
        } else if (e.toString().contains('400')) {
          errorMsg = 'Invalid QR Code or already marked.';
        }
        showToast(context, errorMsg, isError: true);
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
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString('teacher_name') ?? '';
      if (savedName.isNotEmpty && mounted) {
        setState(() {
          _teacherName = savedName;
        });
      }
    } catch (e) {
      debugPrint('Error loading teacher profile name from prefs: $e');
    }
  }

  Future<void> _loadLiveDashboard() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.instance.get('scanners/${widget.scannerId}');
      if (response != null && response['success'] == true && response['scanner'] != null) {
        _scannerDetails = Map<String, dynamic>.from(response['scanner']);
        final records = List<Map<String, dynamic>>.from(_scannerDetails?['attendanceRecords'] ?? []);
        _processLiveFeedRecords(records);
      }
    } catch (e) {
      debugPrint('Error loading live dashboard details: $e');
      if (mounted) {
        setState(() {
          _scannerDetails = {
            'id': widget.scannerId,
            'name': 'Main Gate Scanner',
            'location': 'Main Entrance',
            'scannerType': 'ENTRY',
            'latitude': 28.6139,
            'longitude': 77.2090,
            'geofenceRadius': 50,
            'allowedRoles': ['STUDENT', 'TEACHER', 'STAFF'],
            'isActive': true,
            'attendanceRecords': [],
            '_count': { 'attendanceRecords': 0 }
          };
          _processLiveFeedRecords([]);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _refreshDashboardData() async {
    try {
      final response = await ApiService.instance.get('scanners/${widget.scannerId}');
      if (response != null && response['success'] == true && response['scanner'] != null) {
        if (mounted) {
          setState(() {
            _scannerDetails = Map<String, dynamic>.from(response['scanner']);
            final records = List<Map<String, dynamic>>.from(_scannerDetails?['attendanceRecords'] ?? []);
            _processLiveFeedRecords(records);
          });
        }
      }
    } catch (e) {
      debugPrint('Error silent refreshing dashboard: $e');
    }
  }

  Future<void> _loadLiveFeed() async {
    await _refreshDashboardData();
  }

  void _processLiveFeedRecords(List<Map<String, dynamic>> records) {
    final actionFilter = widget.sessionAction?.toUpperCase().replaceAll('-', '_');
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

    final bodyContent = _isLoading
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


            ],
          );

    return TeacherScaffold(
      title: 'EduSphere',
      activeIndex: 5,
      body: bodyContent,
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
                      _buildGPSBadge(true),
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
              _buildGPSBadge(false),
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

  Widget _buildGPSBadge(bool isNarrow) {
    Color bgColor;
    Color borderColor;
    Color textColor;
    IconData icon;
    String text;

    if (_gpsStatus == 'GPS Ready') {
      bgColor = const Color(0xFFDCFCE7);
      borderColor = const Color(0xFFBBF7D0);
      textColor = const Color(0xFF15803D);
      icon = Icons.wifi_rounded;
      text = 'GPS Ready';
    } else if (_gpsStatus == 'GPS Error') {
      bgColor = const Color(0xFFFEE2E2);
      borderColor = const Color(0xFFFCA5A5);
      textColor = const Color(0xFFB91C1C);
      icon = Icons.location_off_rounded;
      text = 'GPS Error';
    } else {
      bgColor = const Color(0xFFFEF3C7);
      borderColor = const Color(0xFFFDE68A);
      textColor = const Color(0xFFB45309);
      icon = Icons.wifi_off_rounded;
      text = 'GPS Pending';
    }

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isNarrow ? 8.w : 10.w, vertical: isNarrow ? 3.h : 4.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(isNarrow ? 4.r : 6.r),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: isNarrow ? 11.sp : 13.sp,
            color: textColor,
          ),
          SizedBox(width: isNarrow ? 4.w : 6.w),
          Text(
            text,
            style: AppTypography.caption.copyWith(color: textColor),
          ),
        ],
      ),
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
      child: _cameraPermissionDenied
          ? Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.videocam_off_rounded,
                      size: 48.sp,
                      color: const Color(0xFFEF4444),
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      'Camera access denied — check app camera permissions',
                      style: AppTypography.caption
                          .copyWith(color: const Color(0xFFEF4444)),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16.h),
                    ElevatedButton(
                      onPressed: () {
                        openAppSettings();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.theme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      child: Text(
                        'Open Settings',
                        style: AppTypography.caption.copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(16.r),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12.r),
                      child: Stack(
                        alignment: Alignment.center,
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
                              width: 200.w,
                              height: 200.w,
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: widget.theme.primary, width: 4),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                          ),
                          if (_isProcessingQR)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
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
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(bottom: 16.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8.w,
                        height: 8.w,
                        decoration: const BoxDecoration(
                          color: Color(0xFF22C55E),
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'Camera active — point at QR code',
                        style: AppTypography.caption.copyWith(
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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
