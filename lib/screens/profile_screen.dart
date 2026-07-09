import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_saver/file_saver.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../utils/download_helper.dart';
import 'dart:typed_data';
import 'package:dio/dio.dart';





import '../services/cache_service.dart';
import '../services/student_service.dart';
import '../services/app_state_notifier.dart';

import '../theme/colors.dart';
import '../widgets/common_widgets.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../services/auth_service.dart';
import '../config/api_endpoints.dart';
import 'main_screen.dart';
import '../config/api_config.dart';
import '../widgets/teacher_app_bar.dart';
import '../widgets/teacher_scaffold.dart';
import 'package:edusphere/theme/typography.dart';
import '../widgets/navigation_widgets.dart';

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
      canvas.drawRect(Rect.fromLTWH(x, y, px * 5, px * 5), paint);
      canvas.drawRect(Rect.fromLTWH(x + px, y + px, px * 3, px * 3),
          Paint()..color = Colors.white);
      canvas.drawRect(
          Rect.fromLTWH(x + px * 1.5, y + px * 1.5, px * 2, px * 2), paint);
    }

    drawFinder(0, 0); // Top-left
    drawFinder(px * 10, 0); // Top-right
    drawFinder(0, px * 10); // Bottom-left

    for (int r = 0; r < 15; r++) {
      for (int c = 0; c < 15; c++) {
        if (r < 6 && c < 6) continue;
        if (r < 6 && c >= 9) continue;
        if (r >= 9 && c < 6) continue;

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

class ProfileScreen extends StatefulWidget {
  final String role;
  final RoleTheme theme;
  final VoidCallback? onBack;
  final bool showAppBar;
  final VoidCallback? onOpenDrawer;
  final String? studentId;
  final String? studentName;
  final String? studentEmail;
  final String? studentClass;
  final String? admissionNo;
  final String? teacherId;
  final Function(String)? onAvatarUpdated;

  const ProfileScreen({
    super.key,
    required this.role,
    required this.theme,
    this.onBack,
    this.showAppBar = true,
    this.onOpenDrawer,
    this.studentId,
    this.studentName,
    this.studentEmail,
    this.studentClass,
    this.admissionNo,
    this.teacherId,
    this.onAvatarUpdated,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _teacherScaffoldKey =
      GlobalKey<ScaffoldState>();
  bool _showLogout = false;

  // Teacher editing text controllers
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _designCtrl = TextEditingController();
  final TextEditingController _empIdCtrl = TextEditingController();
  final TextEditingController _deptCtrl = TextEditingController();
  final TextEditingController _expCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _dobCtrl =
      TextEditingController(); // Shared state fields
  String _userName = '';
  String _email = '';
  String _phone = '';
  String _gender = 'Not Specified';
  String _dob = 'Not set';
  String _bloodGroup = 'Not assigned';
  String _address = 'No location registered';
  bool _isProfileLoading = false;
  bool _hasProfileError = false;
  // ignore: unused_field
  // ignore: unused_field
  String? _studentUserId;
  String? _currentUserId;

  // Teacher specific fields
  String _employeeId = 'ID_PENDING';
  String _designation = 'TEACHER';
  String _department = 'CORE_SYSTEM';
  String _experience = 'N/A';

  // Student specific fields
  String _rollNumber = '24';
  String _className = 'Grade 12-A';
  String _admissionId = 'ADM-2026-024';

  // Summary configurations
  String _lastSession = 'Initial session';
  String _activityStatus = 'Offline';
  String _joinedDate = 'N/A';
  String _lastPasswordChange = 'Action Required';
  bool _pushEnabled = true;
  bool _inAppEnabled = true;

  // Desktop Tabs State
  String _selectedTab = 'Personal Details';
  final List<String> _tabs = [
    'Personal Details',
    'Academic',
    'Attendance',
    'Fees',
    'Time Table',
    'Transport',
    'Documents'
  ];

  // Student details state
  String? _currentStudentDbId;
  String _studentName = 'Kavya Yadav';
  String _studentEmail = 'kavya.yadav@edusmart.edu';
  String _admissionNo = 'ADM-2023-0681';
  String? _dbQrCode;
  String? _avatarUrl;
  bool _qrIssued = false;
  bool _isQrLoading = false;
  bool _qrError = false;
  String _userRole = 'TEACHER';
  String _studentClass = 'Grade 11';
  String _section = 'C';
  String _rollNo = '118';
  String _batch = '2024-25';
  String _medium = 'ENGLISH';
  String _studentJoinedDate = '4/16/2023';
  String _emergencyInfo = 'UNSET';

  String _studentGender = '—';
  String _studentDob = '—';
  String _studentBloodGroup = '—';
  String _religion = 'HINDU';
  String _casteGroup = 'GENERAL';
  String _nationality = 'INDIAN';

  String _studentStatus = 'ACTIVE';
  String _studentCity = '—';
  String _studentState = '—';
  String _studentPincode = '—';
  String _studentCountry = 'INDIA';
  String _emergencyContactName = '—';
  String _medicalConditions = 'No critical conditions logged';
  String _allergies = 'None reported';
  String _fatherPhone = '—';
  String _motherPhone = '—';

  bool _pushNotifications = true;
  bool _inAppNotifications = true;
  bool _emailNotifications = true;
  bool _smsNotifications = true;

  bool _isUploadingDoc = false;
  List<Map<String, String>> _uploadedDocuments = [];

  String _fatherName = 'Rajesh Sharma';
  String _motherName = 'Priya Sharma';
  String _guardianPhone = '+91 98765 43210';
  
  // Tab details database variables
  bool _isLoadingTabDetails = false;
  List<Map<String, dynamic>> _attendanceRecords = [];
  Map<String, dynamic>? _feeLedger;
  List<dynamic> _feeLedgersList = [];
  // ignore: unused_field
  // ignore: unused_field
  List<Map<String, dynamic>> _feePayments = [];
  // ignore: unused_field
  // ignore: unused_field
  Map<String, dynamic>? _transportAllocation;
  Map<int, List<Map<String, dynamic>>> _timetableSlots = {};

  bool get _isOwnProfile {
    return widget.role == 'student'
        ? (widget.studentId == null)
        : (widget.teacherId == null ||
            widget.teacherId == _currentUserId);
  }

  void _onGlobalPhotoUrlChanged() {
    if (mounted && _isOwnProfile) {
      setState(() {
        _avatarUrl = AppStateNotifier.userProfilePhotoUrl.value;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_isOwnProfile) {
      _avatarUrl = AppStateNotifier.userProfilePhotoUrl.value;
      if (_avatarUrl == null || _avatarUrl!.isEmpty) {
        final prefs = CacheService.instance.prefs;
        _avatarUrl = prefs.getString('${widget.role}_photo_url');
      }
    }
    AppStateNotifier.userProfilePhotoUrl.addListener(_onGlobalPhotoUrlChanged);
    _currentUserId = CacheService.instance.prefs.getString('user_id');
    if (widget.role == 'teacher') {
      _loadTeacherDataFromSupabase();
      _loadSessionData();
      _connectRealTimeSync();
    } else if (widget.role == 'student') {
      if (widget.studentName != null) {
        _studentName = widget.studentName!;
      }
      if (widget.studentEmail != null) {
        _studentEmail = widget.studentEmail!;
      }
      if (widget.admissionNo != null) {
        _admissionNo = widget.admissionNo!;
      }
      if (widget.studentClass != null) {
        final className = widget.studentClass!;
        if (className.contains(' - ')) {
          final parts = className.split(' - ');
          _studentClass = parts[0];
          _section = parts[1];
        } else {
          _studentClass = className;
        }
      }
      _loadStudentDataFromSupabase();
      _connectRealTimeSync();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppStateNotifier.userProfilePhotoUrl.removeListener(_onGlobalPhotoUrlChanged);
    _profilePollTimer?.cancel();
    _qrRefreshTimer?.cancel();
    _clearRealTimeSync();
    _nameCtrl.dispose();
    _designCtrl.dispose();
    _empIdCtrl.dispose();
    _deptCtrl.dispose();
    _expCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (widget.role == 'teacher') {
        _loadTeacherDataFromSupabase();
      }
    }
  }

  Future<void> _loadAllTabDetails(String studentId, String? sectionId) async {
    if (!mounted) return;
    setState(() {
      _isLoadingTabDetails = true;
    });

    // 1. Fetch Attendance Records
    try {
      final attRes =
          await ApiService.instance.get(ApiEndpoints.studentAttendance(studentId));
      if (attRes != null && attRes['success'] == true && mounted) {
        setState(() {
          _attendanceRecords =
              List<Map<String, dynamic>>.from(attRes['attendance'] ?? []);
        });
      }
    } catch (e) {
      debugPrint('Error fetching attendance details: $e');
    }

    // 2. Fetch Fee Ledger and Payments
    try {
      final feeRes =
          await ApiService.instance.get(ApiEndpoints.studentFeeStatus(studentId));
      if (feeRes != null && feeRes['hasLedger'] == true && mounted) {
        final ledgers = feeRes['ledgers'] as List<dynamic>? ?? [];
        final recentPayments = (feeRes['recentPayments'] ?? feeRes['payments'])
                as List<dynamic>? ??
            [];
        setState(() {
          _feeLedger =
              ledgers.isNotEmpty ? Map<String, dynamic>.from(ledgers[0]) : null;
          _feeLedgersList = ledgers;
          _feePayments = List<Map<String, dynamic>>.from(recentPayments);
        });
      }
    } catch (e) {
      debugPrint('Error fetching fee details: $e');
    }

    // 3. Fetch Timetable slots if sectionId is present
    if (sectionId != null) {
      try {
        final timetableRes =
            await ApiService.instance.get(ApiEndpoints.studentTimetable(sectionId));
        if (timetableRes != null &&
            timetableRes['success'] == true &&
            mounted) {
          final rawSchedule = timetableRes['schedule'] as List<dynamic>? ?? [];
          final Map<int, List<Map<String, dynamic>>> grouped = {};

          for (var slot in rawSchedule) {
            final sMap = slot as Map<String, dynamic>;
            final day = sMap['dayOfWeek'] as int? ?? 1;

            final teacherObj = sMap['teacher'] as Map<String, dynamic>?;
            final userObj = teacherObj?['user'] as Map<String, dynamic>?;
            final roomObj = sMap['room'] as Map<String, dynamic>?;

            final formattedSlot = {
              'dayOfWeek': day,
              'startTime': sMap['startTime'] ?? '—',
              'endTime': sMap['endTime'] ?? '—',
              'period': sMap['period'],
              'durationMinutes': sMap['durationMinutes'],
              'subject': sMap['subject'],
              'teacher': {
                'User': userObj,
              },
              'room': roomObj,
            };
            grouped.putIfAbsent(day, () => []).add(formattedSlot);
          }
          setState(() {
            _timetableSlots = grouped;
          });
        }
      } catch (e) {
        debugPrint('Error fetching timetable details: $e');
      }
    }

    // 4. Fetch Documents
    try {
      final docRes =
          await ApiService.instance.get(ApiEndpoints.studentDocuments(studentId));
      if (docRes != null && docRes['success'] == true && mounted) {
        final docsList = docRes['documents'] as List<dynamic>? ?? [];
        setState(() {
          _uploadedDocuments = docsList.map((d) {
            final dMap = d as Map<String, dynamic>;
            final String docName =
                dMap['documentName'] as String? ?? 'Document.pdf';
            final String? uploadDateStr = dMap['uploadedAt'] as String?;
            String dateStr = '—';
            if (uploadDateStr != null) {
              try {
                final parsed = DateTime.parse(uploadDateStr);
                dateStr = '${parsed.month}/${parsed.day}/${parsed.year}';
              } catch (_) {}
            }
            final int? size = dMap['fileSize'] as int?;
            final String sizeStr = size != null ? '${(size / 1024).toStringAsFixed(1)} KB' : '—';
            final String mime = dMap['mimeType']?.toString().split('/').last.toUpperCase() ?? 'FILE';
            
            String rawUrl = dMap['fileUrl']?.toString() ?? '';
            if (rawUrl.isNotEmpty && !rawUrl.startsWith('http') && !rawUrl.startsWith('data:')) {
              rawUrl = '${ApiConfig.serverBaseUrl}${rawUrl.startsWith('/') ? '' : '/'}$rawUrl';
            }
            return {
              'name': docName,
              'date': dateStr,
              'id': dMap['id']?.toString() ?? '',
              'url': rawUrl,
              'size': sizeStr,
              'type': mime,
              'docType': dMap['documentType']?.toString() ?? 'Document',
            };
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching documents: $e');
    }

    if (mounted) {
      setState(() {
        _isLoadingTabDetails = false;
      });
    }
  }

  void _resetProfileFields() {
    _studentName = '—';
    _studentEmail = '—';
    _admissionNo = '—';
    _studentClass = '—';
    _section = '—';
    _rollNo = '—';
    _batch = '—';
    _medium = '—';
    _studentJoinedDate = '—';
    _emergencyInfo = '—';
    _studentGender = '—';
    _studentDob = '—';
    _studentBloodGroup = '—';
    _religion = '—';
    _casteGroup = '—';
    _nationality = '—';
    _avatarUrl = null;
    _dbQrCode = null;

    _userName = '—';
    _email = '—';
    _phone = '—';
    _gender = '—';
    _dob = '—';
    _bloodGroup = '—';
    _address = '—';
    _rollNumber = '—';
    _className = '—';
    _admissionId = '—';
    _fatherName = '—';
    _motherName = '—';
    _guardianPhone = '—';
    _uploadedDocuments = [];
    _attendanceRecords = [];
    _feeLedger = null;
    _feeLedgersList = [];
    _feePayments = [];
    _timetableSlots = {};
    _transportAllocation = null;
  }

  @override
  void didUpdateWidget(ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.studentId != oldWidget.studentId) {
      if (widget.role == 'student') {
        _loadStudentDataFromSupabase();
      }
    }
  }

  Future<void> _loadStudentDataFromSupabase() async {
    if (!mounted) return;
    setState(() {
      _isProfileLoading = true;
      _hasProfileError = false;
      _isQrLoading = true;
      _qrError = false;
    });

    if (widget.studentId != null) {
      _resetProfileFields();
    }

    try {
      debugPrint(
          '🔍 API Student Profile request initiated. Student ID: ${widget.studentId}');

      final response = widget.studentId != null
          ? await ApiService.instance.get(ApiEndpoints.studentProfile(widget.studentId!))
          : await ApiService.instance.get(ApiEndpoints.studentsMe);

      if (response == null ||
          response['success'] != true ||
          response['student'] == null) {
        throw Exception(
            'API details fetch failed or returned invalid response format.');
      }

      final studentResMap = response['student'] as Map<String, dynamic>;
      debugPrint('✅ REST API student details successfully retrieved.');
      final userMap = studentResMap['user'] as Map<String, dynamic>? ?? {};
      final classMap =
          studentResMap['currentClass'] as Map<String, dynamic>? ?? {};
      final sectionMap =
          studentResMap['section'] as Map<String, dynamic>? ?? {};

      final String firstName = userMap['firstName'] as String? ?? '';
      final String lastName = userMap['lastName'] as String? ?? '';
      _studentUserId =
          studentResMap['userId']?.toString() ?? userMap['id']?.toString();

      // Fetch academic years to resolve the batch name if relation is missing
      Map<String, String> academicYearsMap = {};
      try {
        final yearsRes = await ApiService.instance.get('academic/years');
        if (yearsRes != null && yearsRes['success'] == true && yearsRes['academicYears'] != null) {
          final List<dynamic> yearsList = yearsRes['academicYears'];
          for (var yr in yearsList) {
            final id = yr['id']?.toString() ?? '';
            final name = yr['name']?.toString() ?? '';
            if (id.isNotEmpty && name.isNotEmpty) {
              academicYearsMap[id] = name;
            }
          }
        }
      } catch (e) {
        debugPrint('Error fetching academic years: $e');
      }

      final classAcademicYear = classMap['academicYear'] as Map? ??
          classMap['AcademicYear'] as Map? ?? {};
      final studentAcademicYear = studentResMap['academicYear'] as Map? ??
          studentResMap['AcademicYear'] as Map? ?? {};
      final prefs = CacheService.instance.prefs;
      final batchFromPrefs = prefs.getString('student_batch');
      
      final studentAcademicYearId = studentResMap['academicYearId']?.toString() ?? classMap['academicYearId']?.toString() ?? '';
      String batchValue = classAcademicYear['name'] as String? ??
          studentAcademicYear['name'] as String? ??
          (studentAcademicYearId.isNotEmpty ? academicYearsMap[studentAcademicYearId] : null) ??
          batchFromPrefs ??
          '—';
      if (batchValue.length == 9 && batchValue.contains('-')) {
        final parts = batchValue.split('-');
        if (parts.length == 2 && parts[1].length == 4) {
          batchValue = '${parts[0]}-${parts[1].substring(2)}';
        }
      }

      setState(() {
        _studentName = '$firstName $lastName'.trim();
        if (_studentName.isEmpty) _studentName = widget.studentName ?? '—';

        _studentEmail =
            userMap['email'] as String? ?? widget.studentEmail ?? '—';
        _admissionNo = studentResMap['admissionNumber'] as String? ??
            widget.admissionNo ??
            '—';
        _studentClass =
            classMap['name'] as String? ?? widget.studentClass ?? '—';
        _section = sectionMap['name'] as String? ?? '—';
        _rollNo = studentResMap['rollNumber']?.toString() ?? '—';
        _batch = batchValue;
        _medium = studentResMap['medium'] as String? ?? '—';

        final joinDateStr = studentResMap['joiningDate'] as String?;
        if (joinDateStr != null) {
          try {
            final parsed = DateTime.parse(joinDateStr);
            _studentJoinedDate = '${parsed.month}/${parsed.day}/${parsed.year}';
          } catch (_) {
            _studentJoinedDate = '—';
          }
        } else {
          _studentJoinedDate = '—';
        }

        _emergencyInfo = studentResMap['emergencyPhone'] as String? ?? '—';
        if (_emergencyInfo.isEmpty) _emergencyInfo = '—';

        final rawGender = userMap['gender'] as String? ?? '—';
        if (rawGender.toUpperCase() == 'MALE') {
          _studentGender = 'Male';
        } else if (rawGender.toUpperCase() == 'FEMALE') {
          _studentGender = 'Female';
        } else {
          _studentGender = rawGender;
        }

        final dobStr = userMap['dateOfBirth'] as String?;
        if (dobStr != null) {
          try {
            final parsed = DateTime.parse(dobStr);
            _studentDob =
                '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
          } catch (_) {
            _studentDob = dobStr;
          }
        } else {
          _studentDob = '—';
        }

        _studentBloodGroup = studentResMap['bloodGroup'] as String? ?? '—';
        _religion = studentResMap['religion'] as String? ?? '—';
        _casteGroup = studentResMap['caste'] as String? ?? '—';
        _nationality = studentResMap['nationality'] as String? ?? '—';
        _studentStatus = studentResMap['status'] as String? ?? 'ACTIVE';
        _studentCity = studentResMap['city'] as String? ?? '—';
        _studentState = studentResMap['state'] as String? ?? '—';
        _studentPincode = studentResMap['pincode'] as String? ?? '—';
        _studentCountry = studentResMap['country'] as String? ?? 'INDIA';
        _emergencyContactName = studentResMap['emergencyContact'] as String? ?? '—';
        _medicalConditions = studentResMap['medicalConditions'] as String? ?? 'No critical conditions logged';
        _allergies = studentResMap['allergies'] as String? ?? 'None reported';
        _dbQrCode = userMap['qrCode'] as String?;

        final rawAvatar = userMap['avatar'] ??
            userMap['photoUrl'] ??
            userMap['profileImage']?.toString() ??
            '';
        String? newAvatarUrl;
        if (rawAvatar.isNotEmpty) {
          newAvatarUrl = (rawAvatar.startsWith('http') ||
                  rawAvatar.startsWith('data:image'))
              ? rawAvatar
              : '${ApiConfig.serverBaseUrl}$rawAvatar';
        }

        if (_avatarUrl == null || !_avatarUrl!.startsWith('data:image')) {
          _avatarUrl = newAvatarUrl;
          final String? avatar = _avatarUrl;
          final prefs = CacheService.instance.prefs;
          if (avatar != null) {
            final String busterUrl = avatar.contains('?t=') 
                ? avatar 
                : '$avatar?t=${DateTime.now().millisecondsSinceEpoch}';
            prefs.setString('student_photo_url', busterUrl);
            _avatarUrl = busterUrl;
            if (_isOwnProfile) {
              AppStateNotifier.userProfilePhotoUrl.value = busterUrl;
            }
          } else {
            prefs.remove('student_photo_url');
            _avatarUrl = null;
            if (_isOwnProfile) {
              AppStateNotifier.userProfilePhotoUrl.value = null;
            }
          }
        }

        _userName = _studentName;
        _email = _studentEmail;
        _phone = userMap['phone'] as String? ?? '—';
        _gender = _studentGender;
        _dob = _studentDob;
        _bloodGroup = _studentBloodGroup;
        _address = userMap['address'] as String? ?? '—';
        _rollNumber = _rollNo;
        _className = sectionMap['name'] != null
            ? '$_studentClass - $_section'
            : _studentClass;
        _admissionId = _admissionNo;
        _currentStudentDbId = studentResMap['id']?.toString();
        
        final transportAlloc = studentResMap['transportAllocation'] as Map<String, dynamic>?;
        if (transportAlloc != null) {
          final routeMap = transportAlloc['route'] as Map<String, dynamic>?;
          final stopMap = transportAlloc['stop'] as Map<String, dynamic>?;
          _transportAllocation = {
            'status': transportAlloc['status'],
            'stop': stopMap,
            'route': routeMap,
          };
        } else {
          _transportAllocation = null;
        }
        
        _isProfileLoading = false;
      });

      if (userMap['id'] != null) {
        try {
          final qrRes =
              await ApiService.instance.get(ApiEndpoints.userQrCode(userMap['id']?.toString() ?? ''));
          if (qrRes != null &&
              qrRes['success'] == true &&
              qrRes['qrCode'] != null) {
            final qr = qrRes['qrCode'] as String?;
            if (qr != null && qr.isNotEmpty) {
              setState(() {
                _dbQrCode = qr;
                _qrError = false;
                _isQrLoading = false;
              });
              await prefs.setString('student_qrcode', qr);
            } else {
              setState(() {
                _isQrLoading = false;
                _qrError = _dbQrCode == null;
              });
            }
          } else {
            setState(() {
              _isQrLoading = false;
              _qrError = _dbQrCode == null;
            });
          }
        } catch (e) {
          debugPrint('Error fetching QR from API: $e');
          setState(() {
            _isQrLoading = false;
            _qrError = _dbQrCode == null;
          });
        }
      } else {
        setState(() {
          _isQrLoading = false;
        });
      }

      final studentId = studentResMap['id'] as String;
      await prefs.setString('student_id', studentId);
      final String? sectionId = studentResMap['sectionId'] as String?;
      if (sectionId != null) {
        await prefs.setString('student_section_id', sectionId);
      }
      final String? classId = studentResMap['currentClassId'] as String?;
      if (classId != null) {
        await prefs.setString('student_class_id', classId);
      }
      _loadAllTabDetails(studentId, sectionId);
      _connectRealTimeSync();
      _startQrRefreshTimer();

      try {
        final parentsList = studentResMap['parents'] as List<dynamic>? ?? [];
        if (parentsList.isNotEmpty) {
          String father = '—';
          String mother = '—';
          String fatherPhone = '—';
          String motherPhone = '—';
          String guardianPhone = '—';

          for (var sp in parentsList) {
            final spMap = sp as Map<String, dynamic>;
            final rel = spMap['relationship'] as String?;
            final parentObj = spMap['parent'] as Map<String, dynamic>?;

            if (parentObj != null) {
              final pFullName =
                  '${parentObj['firstName'] ?? ''} ${parentObj['lastName'] ?? ''}'
                      .trim();
              final pPhone = parentObj['phone'] as String? ?? '—';
              if (rel == 'FATHER') {
                father = pFullName;
                fatherPhone = pPhone;
                if (guardianPhone == '—') guardianPhone = pPhone;
              } else if (rel == 'MOTHER') {
                mother = pFullName;
                motherPhone = pPhone;
                if (guardianPhone == '—') guardianPhone = pPhone;
              } else {
                if (guardianPhone == '—') guardianPhone = pPhone;
              }
            }
          }

          setState(() {
            _fatherName = father;
            _motherName = mother;
            _fatherPhone = fatherPhone;
            _motherPhone = motherPhone;
            _guardianPhone = guardianPhone;
          });
        }
      } catch (e) {
        debugPrint('Error parsing parents: $e');
      }

      // Fetch documents list from API
      List<Map<String, String>> fetchedDocs = [];
      final targetStudentId = studentId;
      if (targetStudentId.isNotEmpty) {
        try {
          final docsRes = await ApiService.instance.get('students/$studentId/documents');
          if (docsRes != null && docsRes['success'] == true && docsRes['documents'] != null) {
            final docsList = docsRes['documents'] as List<dynamic>;
            fetchedDocs = docsList.map((d) {
              final m = d as Map<String, dynamic>;
              final int? size = m['fileSize'] as int?;
              final String sizeStr = size != null ? '${(size / 1024).toStringAsFixed(1)} KB' : '—';
              final String mime = m['mimeType']?.toString().split('/').last.toUpperCase() ?? 'FILE';
              
              String rawUrl = m['fileUrl']?.toString() ?? '';
              if (rawUrl.isNotEmpty && !rawUrl.startsWith('http') && !rawUrl.startsWith('data:')) {
                rawUrl = '${ApiConfig.serverBaseUrl}${rawUrl.startsWith('/') ? '' : '/'}$rawUrl';
              }
              
              return {
                'name': m['documentName'] as String? ?? 'Document.pdf',
                'date': m['uploadedAt'] != null 
                    ? (() {
                        try {
                          final parsed = DateTime.parse(m['uploadedAt'].toString());
                          return '${parsed.month}/${parsed.day}/${parsed.year}';
                        } catch (_) {
                          return '—';
                        }
                      })()
                    : '—',
                'id': m['id']?.toString() ?? '',
                'url': rawUrl,
                'size': sizeStr,
                'type': mime,
                'docType': m['documentType']?.toString() ?? 'Document',
              };
            }).toList();
          }
        } catch (e) {
          debugPrint('Error fetching documents: $e');
        }
      }

      setState(() {
        _uploadedDocuments = fetchedDocs;
      });

      // Merge local documents that might have failed to sync to the server
      if (widget.studentId == null) {
        try {
          final prefs = CacheService.instance.prefs;
          final localDocsJson = prefs.getString('student_uploaded_documents');
          if (localDocsJson != null) {
            final List<dynamic> localDocsList = json.decode(localDocsJson);
            final currentIds = _uploadedDocuments.map((e) => e['id']).toSet();
            
            bool modified = false;
            for (var ld in localDocsList) {
              final Map<String, String> localDocMap = Map<String, String>.from(ld);
              if (localDocMap['id'] != null && !currentIds.contains(localDocMap['id'])) {
                _uploadedDocuments.add(localDocMap);
                modified = true;
              }
            }
            if (modified && mounted) {
              setState(() {});
            }
          }
        } catch (e) {
          debugPrint('Error merging local docs: $e');
        }
      }

    } catch (e) {
      debugPrint(
          '🚨 REST Student Profile queries failed. Error: $e');
      if (widget.studentId != null) {
        setState(() {
          _isProfileLoading = false;
          _hasProfileError = true;
        });
      } else {
        await _loadProfileData();
        setState(() {
          _isProfileLoading = false;
        });
      }
    }
  }

  Timer? _profilePollTimer;
  Timer? _qrRefreshTimer;

  void _startQrRefreshTimer() {
    _qrRefreshTimer?.cancel();
    _qrRefreshTimer = Timer.periodic(const Duration(seconds: 20), (timer) async {
      final prefs = CacheService.instance.prefs;
      final userId = widget.role == 'teacher'
          ? (widget.teacherId ?? _currentUserId ?? prefs.getString('user_id'))
          : (_studentUserId ?? prefs.getString('user_id'));
      if (userId != null && mounted) {
        try {
          final qrRes = await ApiService.instance.get(ApiEndpoints.userQrCode(userId));
          if (qrRes != null && qrRes['success'] == true && qrRes['qrCode'] != null) {
            final qr = qrRes['qrCode'] as String?;
            if (qr != null && qr.isNotEmpty && mounted) {
              setState(() {
                _dbQrCode = qr;
                _qrError = false;
              });
              final prefKey = widget.role == 'teacher' ? 'teacher_qrcode' : 'student_qrcode';
              await prefs.setString(prefKey, qr);
            }
          }
        } catch (e) {
          if (mounted && _dbQrCode == null) {
            setState(() {
              _qrError = true;
            });
          }
        }
      }
    });
  }

  void _onStudentUpdated(dynamic data) {
    if (!mounted) return;
    try {
      final String? updatedStudentId =
          data?['id']?.toString() ?? data?['studentId']?.toString();
      debugPrint(
          '📡 Socket.IO STUDENT_UPDATED received. Updated Student ID: $updatedStudentId, Current Viewed ID: ${widget.studentId}');
      if (widget.studentId != null &&
          updatedStudentId == widget.studentId) {
        debugPrint(
            '🔄 Socket.IO student matches viewed student. Reloading...');
        _loadStudentDataFromSupabase();
      } else if (widget.studentId == null && widget.role == 'student') {
        _loadStudentDataFromSupabase();
      }
    } catch (e) {
      debugPrint('Error handling Socket.IO update: $e');
    }
  }

  void _onFeeUpdated(dynamic data) {
    if (!mounted) return;
    try {
      final String? updatedStudentId =
          data?['id']?.toString() ?? data?['studentId']?.toString();
      if (widget.role == 'student') {
        _loadStudentDataFromSupabase();
      } else if (widget.studentId != null &&
          updatedStudentId == widget.studentId) {
        _loadStudentDataFromSupabase();
      }
    } catch (e) {
      debugPrint('Error handling Socket.IO FEE_UPDATED: $e');
    }
  }

  void _clearRealTimeSync() {
    SocketService().off('STUDENT_UPDATED', _onStudentUpdated);
    SocketService().off('FEE_UPDATED', _onFeeUpdated);
  }

  void _connectRealTimeSync() {
    try {
      _profilePollTimer?.cancel();
      _profilePollTimer = Timer.periodic(const Duration(minutes: 5), (_) {
        if (mounted) {
          if (widget.role == 'student') {
            _loadStudentDataFromSupabase();
          } else if (widget.role == 'teacher') {
            _loadTeacherDataFromSupabase();
          }
        }
      });

      _clearRealTimeSync();

      // Socket.IO event updates
      SocketService().on('STUDENT_UPDATED', _onStudentUpdated);
      SocketService().on('FEE_UPDATED', _onFeeUpdated);
    } catch (e) {
      debugPrint('⚠️ Error connecting Realtime in ProfileScreen: $e');
    }
  }

  Future<void> _saveStudentDataToBackend() async {
    try {
      final nameParts = _studentName.trim().split(RegExp(r'\s+'));
      final String first = nameParts.isNotEmpty ? nameParts[0] : '';
      final String last = nameParts.length >= 2 ? nameParts.sublist(1).join(' ') : '';

      String? dbGender;
      if (_studentGender.toUpperCase().startsWith('M')) {
        dbGender = 'MALE';
      } else if (_studentGender.toUpperCase().startsWith('F')) {
        dbGender = 'FEMALE';
      }

      String? dbDob;
      if (_studentDob.isNotEmpty && _studentDob != '—') {
        try {
          if (_studentDob.contains('/')) {
            final dobParts = _studentDob.split('/');
            if (dobParts.length == 3) {
              dbDob = '${dobParts[2]}-${dobParts[1].padLeft(2, '0')}-${dobParts[0].padLeft(2, '0')}';
            }
          } else {
            dbDob = DateTime.parse(_studentDob).toIso8601String().split('T').first;
          }
        } catch (_) {
          dbDob = null;
        }
      }

      final updatePayload = {
        'firstName': first,
        'lastName': last,
        'phone': _phone,
        'address': _address,
        if (dbGender != null) 'gender': dbGender,
        if (dbDob != null) 'dateOfBirth': dbDob,
        'bloodGroup': _studentBloodGroup == '—' || _studentBloodGroup == 'N/A' ? null : _studentBloodGroup,
        'emergencyPhone': _emergencyInfo == '—' || _emergencyInfo == 'UNSET' ? null : _emergencyInfo,
        'religion': _religion == '—' ? null : _religion.toUpperCase(),
        'caste': _casteGroup == '—' ? null : _casteGroup.toUpperCase(),
        'nationality': _nationality == '—' ? null : _nationality.toUpperCase(),
      };

      if (widget.studentId != null) {
        await ApiService.instance.put(ApiEndpoints.studentProfile(widget.studentId!), body: updatePayload);
      } else {
        await ApiService.instance.put('users/me', body: updatePayload);
      }
      
      debugPrint('✅ Student profile successfully saved to backend.');
    } catch (e) {
      debugPrint('Error saving student profile to Backend: $e');
    }
  }

  // ignore: unused_element
  // ignore: unused_element
  Future<void> _loadStudentData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _studentName = prefs.getString('student_name') ??
          prefs.getString('user_name') ??
          'Kavya Yadav';
      _studentEmail = prefs.getString('student_email') ??
          prefs.getString('user_email') ??
          'kavya.yadav@edusmart.edu';
      _admissionNo = prefs.getString('student_admission_no') ?? 'ADM-2023-0681';
      _dbQrCode = prefs.getString('student_qrcode');
      _studentClass = prefs.getString('student_class') ?? 'Grade 11';
      _section = prefs.getString('student_section') ?? 'C';
      _rollNo = prefs.getString('student_roll') ?? '118';
      _batch = prefs.getString('student_batch') ?? '2024-25';
      _medium = prefs.getString('student_medium') ?? 'ENGLISH';
      _studentJoinedDate =
          prefs.getString('student_joined_date') ?? '4/16/2023';
      _emergencyInfo = prefs.getString('student_emergency_info') ?? 'UNSET';

      _studentGender = prefs.getString('student_gender') ?? '—';
      _studentDob = prefs.getString('student_dob') ?? '—';
      _studentBloodGroup = prefs.getString('student_blood_group') ?? '—';
      _religion = prefs.getString('student_religion') ?? 'HINDU';
      _casteGroup = prefs.getString('student_caste_group') ?? 'GENERAL';
      _nationality = prefs.getString('student_nationality') ?? 'INDIAN';

      _fatherName = prefs.getString('student_father') ?? 'Rajesh Sharma';
      _motherName = prefs.getString('student_mother') ?? 'Priya Sharma';
      _guardianPhone =
          prefs.getString('student_guardian_phone') ?? '+91 98765 43210';

      _pushNotifications = prefs.getBool('push_notifications_enabled') ?? true;
      _inAppNotifications =
          prefs.getBool('in_app_notifications_enabled') ?? true;
      _emailNotifications = prefs.getBool('email_notifications_enabled') ?? true;
      _smsNotifications = prefs.getBool('sms_notifications_enabled') ?? true;

      final docsJson = prefs.getString('student_uploaded_documents');
      if (docsJson != null) {
        final decoded = json.decode(docsJson) as List<dynamic>;
        _uploadedDocuments =
            decoded.map((e) => Map<String, String>.from(e as Map)).toList();
      } else {
        _uploadedDocuments = [];
      }
    });
  }

  Future<void> _saveStudentData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('student_name', _studentName);
    await prefs.setString('student_email', _studentEmail);
    await prefs.setString('student_admission_no', _admissionNo);
    if (_dbQrCode != null) {
      await prefs.setString('student_qrcode', _dbQrCode!);
    } else {
      await prefs.remove('student_qrcode');
    }
    await prefs.setString('student_class', _studentClass);
    await prefs.setString('student_section', _section);
    await prefs.setString('student_roll', _rollNo);
    await prefs.setString('student_batch', _batch);
    await prefs.setString('student_medium', _medium);
    await prefs.setString('student_joined_date', _studentJoinedDate);
    await prefs.setString('student_emergency_info', _emergencyInfo);

    await prefs.setString('student_gender', _studentGender);
    await prefs.setString('student_dob', _studentDob);
    await prefs.setString('student_blood_group', _studentBloodGroup);
    await prefs.setString('student_religion', _religion);
    await prefs.setString('student_caste_group', _casteGroup);
    await prefs.setString('student_nationality', _nationality);

    await prefs.setString('student_father', _fatherName);
    await prefs.setString('student_mother', _motherName);
    await prefs.setString('student_guardian_phone', _guardianPhone);

    await prefs.setBool('push_notifications_enabled', _pushNotifications);
    await prefs.setBool('in_app_notifications_enabled', _inAppNotifications);
    await prefs.setBool('email_notifications_enabled', _emailNotifications);
    await prefs.setBool('sms_notifications_enabled', _smsNotifications);

    final encoded = json.encode(_uploadedDocuments);
    await prefs.setString('student_uploaded_documents', encoded);
  }

  void _togglePushNotifications(bool val) async {
    setState(() {
      _pushNotifications = val;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('push_notifications_enabled', val);
    if (mounted) showToast(context, 'Notification preferences updated!');
  }

  void _toggleInAppNotifications(bool val) async {
    setState(() {
      _inAppNotifications = val;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('in_app_notifications_enabled', val);
    if (mounted) showToast(context, 'Notification preferences updated!');
  }

  void _toggleEmailNotifications(bool val) async {
    setState(() {
      _emailNotifications = val;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('email_notifications_enabled', val);
    if (mounted) showToast(context, 'Notification preferences updated!');
  }

  void _toggleSMSNotifications(bool val) async {
    setState(() {
      _smsNotifications = val;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sms_notifications_enabled', val);
    if (mounted) showToast(context, 'Notification preferences updated!');
  }

  Future<void> _removeDocumentSilently(int index) async {
    final docId = _uploadedDocuments[index]['id'];
    if (docId != null && docId.isNotEmpty) {
      try {
        await StudentService.instance.deleteStudentDocument(docId);
      } catch (_) {}
    }
    setState(() {
      _uploadedDocuments.removeAt(index);
    });
  }

  void _simulateDocumentUpload() async {
    final String? studentId = widget.studentId ?? _currentStudentDbId;
    if (studentId == null || studentId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text('Student details not fully loaded yet.', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        );
      }
      return;
    }

    setState(() {
      _isUploadingDoc = true;
    });

    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg'],
        withData: true,
      );

      if (result != null) {
        final platformFile = result.files.single;
        final String docName = platformFile.name;
        final int fileSize = platformFile.size;
        final String ext = platformFile.extension?.toUpperCase() ?? 'PDF';
        final fileBytes = platformFile.bytes;

        // Size check (5MB)
        if (fileSize > 5 * 1024 * 1024) {
          if (mounted) {
            showToast(context, 'File too large. Maximum allowed size is 5MB.');
          }
          setState(() {
            _isUploadingDoc = false;
          });
          return;
        }

        // Duplicate Check
        final existingIdx = _uploadedDocuments.indexWhere((doc) => doc['name'] == docName);
        if (existingIdx != -1) {
          final replace = await _showConfirmDialog(
            'Duplicate Document',
            'A document named "$docName" already exists. Would you like to replace it?'
          );
          if (replace != true) {
            setState(() {
              _isUploadingDoc = false;
            });
            return;
          }
          await _removeDocumentSilently(existingIdx);
        }

        if (fileBytes != null) {
          final response = await StudentService.instance.uploadStudentDocument(
            studentId: studentId,
            fileBytes: fileBytes,
            fileName: docName,
            documentType: ext,
            documentName: docName,
          );

          if (response['success'] == true) {
            await _loadStudentDataFromSupabase();
            if (mounted) {
              
              _saveStudentData();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF1A6FDB),
                  content: Text('Document "$docName" uploaded successfully!',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                ),
              );
            }
          } else {
            throw Exception(response['message'] ?? 'Upload failed');
          }
        } else {
          throw Exception('No bytes found in selected file.');
        }
      }
    } catch (e) {
      debugPrint('Error uploading file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text('Upload failed: $e', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingDoc = false;
        });
      }
    }
  }

  void _removeDocument(int index) async {
    final name = _uploadedDocuments[index]['name'];
    final docId = _uploadedDocuments[index]['id'];

    if (docId == null || docId.isEmpty) {
      setState(() {
        _uploadedDocuments.removeAt(index);
      });
      _saveStudentData();
      return;
    }

    try {
      final response = await StudentService.instance.deleteStudentDocument(docId);
      
      if (response['success'] == true) {
        await _loadStudentDataFromSupabase();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF1A6FDB),
              content: Text('Document "$name" deleted successfully!', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            ),
          );
        }
      } else {
        throw Exception(response['message'] ?? 'Delete failed');
      }
    } catch (e) {
      debugPrint('Error deleting document: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text('Delete failed: $e', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        );
      }
    }
  }

  void _showEditEmergencyInfoDialog() {
    final ctrl = TextEditingController(text: _emergencyInfo == '—' || _emergencyInfo == 'UNSET' ? '' : _emergencyInfo);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text('Edit Emergency Info', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            hintText: 'Enter emergency phone number',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
          ),

        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A6FDB),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
            ),
            onPressed: () async {
              final String val = ctrl.text.trim();
              setState(() {
                _emergencyInfo = val.isEmpty ? '—' : val;
              });
              
              await _saveStudentData();
              
              try {
                await _saveStudentDataToBackend();
                if (context.mounted) {
                  Navigator.pop(context);
                  showToast(context, 'Emergency contact updated!');
                }
              } catch (e) {
                if (context.mounted) {
                  showToast(context, 'Error updating contact');
                }
              }
            },
            child: Text('Save', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _openEditProfileSheet() {
    final nameCtrl = TextEditingController(text: _studentName);
    final admissionCtrl = TextEditingController(text: _admissionNo);
    final classCtrl = TextEditingController(text: _studentClass);
    final sectionCtrl = TextEditingController(text: _section);
    final rollCtrl = TextEditingController(text: _rollNo);
    final batchCtrl = TextEditingController(text: _batch);
    final dobCtrl = TextEditingController(text: _studentDob);
    final casteCtrl = TextEditingController(text: _casteGroup);
    final religionCtrl = TextEditingController(text: _religion);
    final nationalityCtrl = TextEditingController(text: _nationality);
    final emergencyCtrl = TextEditingController(text: _emergencyInfo);
    final genderCtrl = TextEditingController(text: _studentGender);
    final bloodCtrl = TextEditingController(text: _studentBloodGroup);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.only(
            left: 24.r,
            right: 24.r,
            top: 24.r,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24.r,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '✏️ Edit Profile Info',
                        style: GoogleFonts.outfit(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F2547),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF868E96)),
                        onPressed: () => Navigator.pop(ctx),
                      )
                    ],
                  ),
                  SizedBox(height: 16.h),
                  _buildEditTextField('Full Name', nameCtrl),
                  _buildEditTextField('Admission Number', admissionCtrl),
                  Row(
                    children: [
                      Expanded(child: _buildEditTextField('Class', classCtrl)),
                      SizedBox(width: 12.w),
                      Expanded(
                          child: _buildEditTextField('Section', sectionCtrl)),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: _buildEditTextField('Roll No', rollCtrl)),
                      SizedBox(width: 12.w),
                      Expanded(child: _buildEditTextField('Batch', batchCtrl)),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                          child: _buildEditTextField('Gender', genderCtrl)),
                      SizedBox(width: 12.w),
                      Expanded(
                          child: _buildEditTextField('Blood Group', bloodCtrl)),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                          child: _buildEditTextField('Date of Birth', dobCtrl)),
                      SizedBox(width: 12.w),
                      Expanded(
                          child: _buildEditTextField('Caste Group', casteCtrl)),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: _buildEditTextField('Religion', religionCtrl)),
                      SizedBox(width: 12.w),
                      Expanded(child: _buildEditTextField('Nationality', nationalityCtrl)),
                    ],
                  ),
                  _buildEditTextField('Emergency Info', emergencyCtrl),
                  SizedBox(height: 24.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A6FDB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r)),
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        setState(() {
                          _studentName = nameCtrl.text;
                          _admissionNo = admissionCtrl.text;
                          _studentClass = classCtrl.text;
                          _section = sectionCtrl.text;
                          _rollNo = rollCtrl.text;
                          _batch = batchCtrl.text;
                          _studentDob = dobCtrl.text;
                          _casteGroup = casteCtrl.text;
                          _religion = religionCtrl.text;
                          _nationality = nationalityCtrl.text;
                          _emergencyInfo = emergencyCtrl.text;
                          _studentGender = genderCtrl.text;
                          _studentBloodGroup = bloodCtrl.text;
                        });
                        await _saveStudentData();
                        await _saveStudentDataToBackend();
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFF10B981),
                              content: Text('Profile updated successfully!',
                                  style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700)),
                            ),
                          );
                        }
                      },
                      child: Text('Save Changes', style: AppTypography.small),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEditTextField(String label, TextEditingController ctrl) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTypography.caption
                  .copyWith(color: const Color(0xFF495057))),
          SizedBox(height: 6.h),
          TextFormField(
            controller: ctrl,
            style: AppTypography.small.copyWith(color: const Color(0xFF0F2547)),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(color: Color(0xFFE2EAF4))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(color: Color(0xFFE2EAF4))),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadSessionData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastSession = prefs.getString('app_last_session') ?? 'Initial session';
      _joinedDate = widget.role == 'teacher' ? '12/08/2021' : '04/04/2023';
    });
  }

  Future<void> _loadTeacherDataFromSupabase() async {
    try {
      final prefs = CacheService.instance.prefs;
      String? currentUserId = widget.teacherId ?? _currentUserId;
      if (currentUserId == null || currentUserId.isEmpty) {
        currentUserId = prefs.getString('user_id');
      }

      if (currentUserId == null || currentUserId.isEmpty) {
        await _loadProfileData();
        return;
      }

      if (mounted) {
        setState(() {
          _isQrLoading = true;
          _qrError = false;
        });
      }

      Map<String, dynamic>? teacherMap;
      final res = await ApiService.instance.get('teachers');
      if (res != null && res['success'] == true && res['teachers'] is List) {
        final teachersList = res['teachers'] as List;
        final match = teachersList.firstWhere(
          (t) => t['userId'] == currentUserId || t['id'] == currentUserId || (t['user'] != null && t['user']['id'] == currentUserId),
          orElse: () => null,
        );
        if (match != null) {
          teacherMap = Map<String, dynamic>.from(match as Map);
        }
      }

      if (teacherMap == null) {
        if (mounted) {
          setState(() {
            _isQrLoading = false;
            _qrError = true;
          });
        }
        await _loadProfileData();
        return;
      }

      final tMap = teacherMap;
      final userMap = tMap['user'] as Map<String, dynamic>? ?? {};
      currentUserId = userMap['id']?.toString() ?? currentUserId;

      // Fetch QR Code from Render API specifically
      String? qrCode;
      bool fetchQrSuccess = false;
      bool? qrIssuedFromApi;
      try {
        final qrRes = await ApiService.instance.get('users/$currentUserId/qr');
        if (qrRes != null &&
            qrRes['success'] == true &&
            qrRes['qrCode'] != null) {
          qrCode = qrRes['qrCode'] as String?;
          fetchQrSuccess = true;
          if (qrRes['qrIssued'] != null) {
            qrIssuedFromApi = qrRes['qrIssued'] as bool?;
          }
        }
      } catch (e) {
        // Handled via fetchQrSuccess flag
      }

      setState(() {
        final String firstName = userMap['firstName'] as String? ?? '';
        final String lastName = userMap['lastName'] as String? ?? '';
        _userName = '$firstName $lastName'.trim();
        if (_userName.isEmpty) _userName = 'Vikram Yadav';
        _email = userMap['email'] as String? ?? '';
        _phone = userMap['phone'] as String? ?? 'N/A';

        final rawAvatar = userMap['avatar']?.toString() ?? '';
        String? newAvatarUrl;
        if (rawAvatar.isNotEmpty) {
          newAvatarUrl = (rawAvatar.startsWith('http') ||
                  rawAvatar.startsWith('data:image'))
              ? rawAvatar
              : '${ApiConfig.serverBaseUrl}$rawAvatar';
        }
        
        if (_avatarUrl == null || !_avatarUrl!.startsWith('data:image')) {
          _avatarUrl = newAvatarUrl;
          final String? avatar = _avatarUrl;
          final prefs = CacheService.instance.prefs;
          if (avatar != null) {
            final String busterUrl = avatar.contains('?t=') 
                ? avatar 
                : '$avatar?t=${DateTime.now().millisecondsSinceEpoch}';
            prefs.setString('teacher_photo_url', busterUrl);
            _avatarUrl = busterUrl;
            if (_isOwnProfile) {
              AppStateNotifier.userProfilePhotoUrl.value = busterUrl;
            }
          } else {
            prefs.remove('teacher_photo_url');
            _avatarUrl = null;
            if (_isOwnProfile) {
              AppStateNotifier.userProfilePhotoUrl.value = null;
            }
          }
        }

        final rawGender = userMap['gender'] as String? ?? 'Not Specified';
        if (rawGender.toUpperCase() == 'MALE') {
          _gender = 'Male';
        } else if (rawGender.toUpperCase() == 'FEMALE') {
          _gender = 'Female';
        } else {
          _gender = rawGender;
        }

        final dobStr = userMap['dateOfBirth'] as String?;
        if (dobStr != null) {
          try {
            final parsed = DateTime.parse(dobStr);
            _dob =
                '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
          } catch (_) {
            _dob = dobStr;
          }
        } else {
          _dob = 'Not set';
        }

        _bloodGroup = userMap['bloodGroup'] as String? ?? 'Not assigned';
        _address = userMap['address'] as String? ?? 'No location registered';

        final lastPwdStr = userMap['lastPasswordChange'] as String?;
        if (lastPwdStr != null) {
          try {
            final parsed = DateTime.parse(lastPwdStr);
            _lastPasswordChange =
                '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
          } catch (_) {
            _lastPasswordChange = lastPwdStr;
          }
        }

        _dbQrCode = qrCode ?? userMap['qrCode'] as String?;
        _qrIssued = qrIssuedFromApi ?? userMap['qrIssued'] as bool? ?? false;
        _activityStatus = (userMap['isActive'] as bool? ?? true) ? 'Active' : 'Inactive';
        _userRole = userMap['role']?.toString() ?? 'TEACHER';

        _employeeId = 'ID_PENDING';
        _designation = 'TEACHER';
        _department = 'CORE_SYSTEM';

        final rawExp = tMap['experience']?.toString();
        _experience =
            (rawExp != null && rawExp.isNotEmpty) ? '$rawExp Years' : 'N/A';

        final joinDateStr = tMap['joiningDate'] as String?;
        if (joinDateStr != null) {
          try {
            final parsed = DateTime.parse(joinDateStr);
            _joinedDate =
                '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
          } catch (_) {
            _joinedDate = joinDateStr;
          }
        }

        // Sync local variables which are shared with the QR identity card
        _studentName = _userName;
        _admissionNo = _employeeId;
        
        _isQrLoading = false;
        _qrError = !fetchQrSuccess && _dbQrCode == null;
      });

      if (widget.teacherId == null || widget.teacherId == _currentUserId) {
        await prefs.setString('teacher_name', _userName);
        await prefs.setString('teacher_email', _email);
        await prefs.setString('teacher_mobile', _phone);
        await prefs.setString('teacher_gender', _gender);
        await prefs.setString('teacher_dob', _dob);
        await prefs.setString('teacher_blood', _bloodGroup);
        await prefs.setString('teacher_address', _address);
        await prefs.setString('teacher_emp_id', _employeeId);
        await prefs.setString('teacher_design', _designation);
        await prefs.setString('teacher_dept', _department);
        await prefs.setString('teacher_exp', _experience);
        await prefs.setString('teacher_activity', _activityStatus);
        await prefs.setString('teacher_last_pwd', _lastPasswordChange);
        if (_dbQrCode != null) {
          await prefs.setString('teacher_qrcode', _dbQrCode!);
        }
        _startQrRefreshTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isQrLoading = false;
          _qrError = true;
        });
      }
      await _loadProfileData();
    }
  }

  Future<void> _saveTeacherDataToBackend(Map<String, String> data) async {
    try {
      final Map<String, dynamic> userUpdates = {};
      if (data.containsKey('name')) {
        final parts = data['name']!.split(' ');
        userUpdates['firstName'] = parts.first;
        userUpdates['lastName'] = parts.skip(1).join(' ');
      }
      if (data.containsKey('phone')) userUpdates['phone'] = data['phone'];
      if (data.containsKey('gender')) {
        userUpdates['gender'] = data['gender']!.toUpperCase().startsWith('M') ? 'MALE' : 'FEMALE';
      }
      if (data.containsKey('dob')) {
        try {
          final parts = data['dob']!.split('/');
          if (parts.length == 3) {
            userUpdates['dateOfBirth'] =
                '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
          } else {
            userUpdates['dateOfBirth'] =
                DateTime.parse(data['dob']!).toIso8601String();
          }
        } catch (_) {
          userUpdates['dateOfBirth'] = data['dob'];
        }
      }
      if (data.containsKey('bloodGroup')) {
        userUpdates['bloodGroup'] = data['bloodGroup'];
      }
      if (data.containsKey('address')) userUpdates['address'] = data['address'];

      if (data.containsKey('designation')) {
        userUpdates['specialization'] = data['designation'];
      }
      if (data.containsKey('department')) {
        userUpdates['qualification'] = data['department'];
      }

      await ApiService.instance.put('users/me', body: userUpdates);
      debugPrint('✅ Teacher profile successfully saved to backend.');
    } catch (e) {
      debugPrint('Error saving teacher profile to Backend: $e');
    }
  }

  Future<void> _loadProfileData() async {
    final prefs = CacheService.instance.prefs;
    setState(() {
      if (widget.role == 'teacher') {
        if (widget.teacherId != null && widget.teacherId != _currentUserId) {
          _avatarUrl = null;
          _userName = 'Loading Teacher...';
          _email = '';
          _phone = 'N/A';
          _gender = 'Not Specified';
          _dob = 'Not set';
          _bloodGroup = 'Not assigned';
          _address = 'No location registered';
          _employeeId = 'ID_PENDING';
          _designation = 'TEACHER';
          _department = 'CORE_SYSTEM';
          _experience = 'N/A';
          _joinedDate = 'N/A';
          _activityStatus = 'Offline';
          _pushEnabled = true;
          _inAppEnabled = true;
          _lastPasswordChange = 'Action Required';
          _dbQrCode = null;
          _studentName = _userName;
          _admissionNo = _employeeId;
        } else {
          _avatarUrl = prefs.getString('teacher_photo_url');
          _userName = prefs.getString('teacher_name') ?? 'Vikram Yadav';
          _email =
              prefs.getString('teacher_email') ?? 'teacher1@demoschool.com';
          _phone = prefs.getString('teacher_mobile') ?? 'N/A';
          _gender = prefs.getString('teacher_gender') ?? 'Not Specified';
          _dob = prefs.getString('teacher_dob') ?? 'Not set';
          _bloodGroup = prefs.getString('teacher_blood') ?? 'Not assigned';
          _address =
              prefs.getString('teacher_address') ?? 'No location registered';
          _employeeId = 'ID_PENDING';
          _designation = 'TEACHER';
          _department = 'CORE_SYSTEM';
          _experience = prefs.getString('teacher_exp') ?? 'N/A';
          _activityStatus = prefs.getString('teacher_activity') ?? 'Offline';
          _pushEnabled = prefs.getBool('notifications_enabled') ?? true;
          _inAppEnabled = prefs.getBool('in_app_notifications') ?? true;
          _lastPasswordChange =
              prefs.getString('teacher_last_pwd') ?? 'Action Required';
          _dbQrCode = prefs.getString('teacher_qrcode');
          _studentName = _userName;
          _admissionNo = _employeeId;
        }
      } else {
        if (widget.studentId != null && widget.studentId != _currentUserId) {
          _avatarUrl = null;
          _userName = 'Loading Student...';
          _email = '';
          _phone = 'N/A';
          _gender = 'Not Specified';
          _dob = 'Not set';
          _bloodGroup = 'Not assigned';
          _address = 'No location registered';
          _rollNumber = '—';
          _className = '—';
          _admissionId = '—';
          _activityStatus = 'Offline';
          _pushEnabled = true;
          _inAppEnabled = true;
          _lastPasswordChange = 'Action Required';
        } else {
          _avatarUrl = prefs.getString('student_photo_url');
          _userName = prefs.getString('student_name') ?? '—';
          _email = prefs.getString('student_email') ?? '—';
          _phone = prefs.getString('student_phone') ?? 'N/A';
          _gender = prefs.getString('student_gender') ?? 'Not Specified';
          _dob = prefs.getString('student_dob') ?? 'Not set';
          _bloodGroup = prefs.getString('student_blood') ?? 'Not assigned';
          _address = prefs.getString('student_address') ?? 'No location registered';
          _rollNumber = prefs.getString('student_roll') ?? '—';
          _className = prefs.getString('student_class') ?? '—';
          _admissionId = prefs.getString('student_admission_id') ?? '—';
          _activityStatus = prefs.getString('student_activity') ?? 'Offline';
          _pushEnabled = prefs.getBool('notifications_enabled') ?? true;
          _inAppEnabled = prefs.getBool('in_app_notifications') ?? true;
          _lastPasswordChange = prefs.getString('student_last_pwd') ?? 'Action Required';
        }
      }
    });
  }

  Future<void> _saveProfileEdits(Map<String, String> data) async {
    final prefs = await SharedPreferences.getInstance();
    if (widget.role == 'teacher') {
      if (data.containsKey('name')) {
        await prefs.setString('teacher_name', data['name']!);
      }
      if (data.containsKey('email')) {
        await prefs.setString('teacher_email', data['email']!);
      }
      if (data.containsKey('phone')) {
        await prefs.setString('teacher_mobile', data['phone']!);
      }
      if (data.containsKey('gender')) {
        await prefs.setString('teacher_gender', data['gender']!);
      }
      if (data.containsKey('dob')) {
        await prefs.setString('teacher_dob', data['dob']!);
      }
      if (data.containsKey('bloodGroup')) {
        await prefs.setString('teacher_blood', data['bloodGroup']!);
      }
      if (data.containsKey('address')) {
        await prefs.setString('teacher_address', data['address']!);
      }
      if (data.containsKey('employeeId')) {
        await prefs.setString('teacher_emp_id', data['employeeId']!);
      }
      if (data.containsKey('designation')) {
        await prefs.setString('teacher_design', data['designation']!);
      }
      if (data.containsKey('department')) {
        await prefs.setString('teacher_dept', data['department']!);
      }
      if (data.containsKey('experience')) {
        await prefs.setString('teacher_exp', data['experience']!);
      }
      await _saveTeacherDataToBackend(data);
    } else {
      if (data.containsKey('name')) {
        await prefs.setString('student_name', data['name']!);
      }
      if (data.containsKey('email')) {
        await prefs.setString('student_email', data['email']!);
      }
      if (data.containsKey('phone')) {
        await prefs.setString('student_phone', data['phone']!);
      }
      if (data.containsKey('gender')) {
        await prefs.setString('student_gender', data['gender']!);
      }
      if (data.containsKey('dob')) {
        await prefs.setString('student_dob', data['dob']!);
      }
      if (data.containsKey('bloodGroup')) {
        await prefs.setString('student_blood', data['bloodGroup']!);
      }
      if (data.containsKey('address')) {
        await prefs.setString('student_address', data['address']!);
      }
      if (data.containsKey('rollNumber')) {
        await prefs.setString('student_roll', data['rollNumber']!);
      }
      if (data.containsKey('className')) {
        await prefs.setString('student_class', data['className']!);
      }
      if (data.containsKey('admissionId')) {
        await prefs.setString('student_admission_id', data['admissionId']!);
      }
    }
    await _loadTeacherDataFromSupabase(); // Reloads teacher data
    if (mounted) {
      showToast(context, 'Profile updated successfully!');
    }
  }

  // --- RESPONSIVE TABBED STUDENT PROFILE METHODS ---
  Widget _buildTabbedStudentProfile(bool isDesktop) {
    final double horizontalPadding = isDesktop ? 40.w : 16.w;
    final double verticalPadding = isDesktop ? 20.h : 12.h;

    Widget bodyContent;

    if (_isProfileLoading) {
      bodyContent = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF1A6FDB)),
            SizedBox(height: 16.h),
            Text(
              'Fetching student profile data...',
              style:
                  AppTypography.small.copyWith(color: const Color(0xFF64748B)),
            ),
          ],
        ),
      );
    } else if (_hasProfileError) {
      bodyContent = Center(
        child: Container(
          margin: EdgeInsets.all(24.r),
          padding: EdgeInsets.all(24.r),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: const Color(0xFFFECACA)),
            boxShadow: [
              BoxShadow(
                  color: Colors.red.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  color: const Color(0xFFEF4444), size: 48.sp),
              SizedBox(height: 16.h),
              Text(
                'Failed to load student details',
                style:
                    AppTypography.body.copyWith(color: const Color(0xFF0F2547)),
              ),
              SizedBox(height: 8.h),
              Text(
                'Please check your network connection and try again.',
                textAlign: TextAlign.center,
                style: AppTypography.caption
                    .copyWith(color: const Color(0xFF64748B)),
              ),
              SizedBox(height: 20.h),
              ElevatedButton.icon(
                onPressed: _loadStudentDataFromSupabase,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                label: Text('Retry',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A6FDB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r)),
                  padding:
                      EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                ),
              ),
              if (widget.onBack != null) ...[
                SizedBox(height: 12.h),
                TextButton(
                  onPressed: widget.onBack,
                  child: Text('Go Back',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A6FDB))),
                ),
              ],
            ],
          ),
        ),
      );
    } else {
      bodyContent = SingleChildScrollView(
        padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding, vertical: verticalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Back Button
            if (widget.onBack != null && widget.studentId != null)
              GestureDetector(
                onTap: widget.onBack,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back_ios_new_rounded, color: const Color(0xFF0F2547), size: 16.sp),
                    SizedBox(width: 8.w),
                    Text(
                      'Back to Students',
                      style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F2547),
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(height: 16.h),

            // Header Card
            _buildTabbedHeaderCard(isDesktop),
            SizedBox(height: 16.h),

            // Tabbed Navigation
            _buildTabbedNavigation(isDesktop),
            SizedBox(height: 16.h),

            // Tab Content
            _buildTabbedTabContent(isDesktop),
          ],
        ),
      );
    }

    final String? loggedInRole = CacheService.instance.prefs.getString('user_role');

    if (widget.studentId != null && loggedInRole == 'teacher') {
      return TeacherNavigationScaffold(
        title: 'EduSphere',
        activeIndex: 2,
        body: Stack(
          children: [
            // Basic background gradient
            Container(
              height: 250.h,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFE2EAF4), Color(0xFFF4F7FB)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            SafeArea(
              child: bodyContent,
            ),
            if (_showLogout) _buildLogoutDialog(),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Stack(
        children: [
          // Basic background gradient
          Container(
            height: 250.h,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE2EAF4), Color(0xFFF4F7FB)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: bodyContent,
          ),
          if (_showLogout) _buildLogoutDialog(),
        ],
      ),
    );
  }

  // --- NEW STUDENT PROFILE HELPER WIDGETS ---

  Widget _buildNewHeaderCard(bool isDesktop) {
    final List<String> parts = _studentName.trim().split(RegExp(r'\s+'));
    final String initials = parts.length >= 2 
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : (parts.isNotEmpty && parts[0].isNotEmpty ? parts[0][0].toUpperCase() : 'ST');

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: const Color(0xFFE2EAF4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 80.r,
                height: 80.r,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(24.r),
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: GoogleFonts.inter(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0284C7),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16.w),
              // Student Metadata
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _studentName,
                            style: GoogleFonts.inter(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 6.w),
                        GestureDetector(
                          onTap: _openEditProfileSheet,
                          child: Container(
                            padding: EdgeInsets.all(4.r),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.edit_rounded, size: 14.sp, color: AppColors.textDark),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Text(
                            _admissionNo,
                            style: GoogleFonts.inter(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF166534),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    Row(
                      children: [
                        Icon(Icons.school_rounded, size: 14.sp, color: AppColors.textLight),
                        SizedBox(width: 4.w),
                        Text(
                          'Class $_studentClass${_section != '—' && _section.isNotEmpty ? ' - $_section' : ''}',
                          style: GoogleFonts.inter(fontSize: 12.sp, color: AppColors.textMedium),
                        ),
                        SizedBox(width: 12.w),
                        Icon(Icons.badge_rounded, size: 14.sp, color: AppColors.textLight),
                        SizedBox(width: 4.w),
                        Text(
                          'Roll No. $_rollNo',
                          style: GoogleFonts.inter(fontSize: 12.sp, color: AppColors.textMedium),
                        ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    Row(
                      children: [
                        Container(
                          width: 8.r,
                          height: 8.r,
                          decoration: const BoxDecoration(
                            color: Color(0xFF22C55E),
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          'Active Profile',
                          style: GoogleFonts.inter(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF166534),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          // Upload Document Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isUploadingDoc ? null : _simulateDocumentUpload,
              icon: _isUploadingDoc 
                  ? SizedBox(
                      width: 16.r, 
                      height: 16.r, 
                      child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.textDark),
                    )
                  : const Icon(Icons.add, size: 18),
              label: Text(
                _isUploadingDoc ? 'Uploading...' : 'Upload Document',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF1F5F9),
                foregroundColor: AppColors.textDark,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                padding: EdgeInsets.symmetric(vertical: 12.h),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid(bool isDesktop) {
    return GridView.count(
      crossAxisCount: isDesktop ? 4 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12.h,
      crossAxisSpacing: 12.w,
      childAspectRatio: isDesktop ? 2.2 : 1.6,
      children: [
        _summaryCard('Batch', _batch, const Color(0xFFE0F2FE), Icons.calendar_today_rounded),
        _summaryCard('Medium', _medium, const Color(0xFFDCFCE7), Icons.language_rounded),
        _summaryCard('Joined', _studentJoinedDate, const Color(0xFFF3E8FF), Icons.event_available_rounded),
        GestureDetector(
          onTap: _showEditEmergencyInfoDialog,
          child: _summaryCard(
            'Emergency Info', 
            _emergencyInfo == 'UNSET' || _emergencyInfo == '—' ? 'TAP TO SET' : _emergencyInfo, 
            const Color(0xFFFEE2E2), 
            Icons.favorite_rounded,
            isEditable: true,
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(String title, String val, Color color, IconData icon, {bool isEditable = false}) => Container(
    padding: EdgeInsets.all(12.r),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20.r),
      border: Border.all(color: AppColors.border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.01),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w700, color: AppColors.textLight)),
            Container(
              padding: EdgeInsets.all(6.r),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, size: 12.sp, color: AppColors.textDark),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                val, 
                style: GoogleFonts.inter(
                  fontSize: 13.sp, 
                  fontWeight: FontWeight.w900, 
                  color: isEditable && (val == 'TAP TO SET' || val == '—') ? const Color(0xFFEF4444) : AppColors.textDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isEditable) ...[
              SizedBox(width: 4.w),
              Icon(Icons.edit_rounded, size: 12.sp, color: AppColors.textLight),
            ]
          ],
        ),
      ],
    ),
  );

  Widget _buildCoreIdentityCard(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4.w, bottom: 8.h),
          child: Text('👤 Core Identity', style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w900, color: AppColors.textDark)),
        ),
        Container(
          padding: EdgeInsets.all(20.r),
          decoration: BoxDecoration(
            color: Colors.white, 
            borderRadius: BorderRadius.circular(24.r), 
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _infoRow(Icons.person_outline_rounded, 'Gender', _studentGender),
              _divider(),
              _infoRow(Icons.cake_outlined, 'Date of Birth', _studentDob),
              _divider(),
              _infoRow(Icons.water_drop_outlined, 'Blood Group', _studentBloodGroup),
              _divider(),
              _infoRow(Icons.account_balance_rounded, 'Religion', _religion),
              _divider(),
              _infoRow(Icons.groups_outlined, 'Caste Group', _casteGroup),
              _divider(),
              _infoRow(Icons.public_rounded, 'Nationality', _nationality),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String k, String v) => Padding(
    padding: EdgeInsets.symmetric(vertical: 4.h),
    child: Row(
      children: [
        Icon(icon, size: 18.sp, color: AppColors.textLight),
        SizedBox(width: 12.w),
        Text(k, style: GoogleFonts.inter(fontSize: 13.sp, color: AppColors.textMedium)),
        const Spacer(),
        Text(v, style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w700, color: AppColors.textDark)),
      ],
    ),
  );

  Widget _divider() => Divider(height: 24.h, color: AppColors.border.withValues(alpha: 0.5));

  Widget _buildHealthProtocolCard(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4.w, bottom: 8.h),
          child: Text('❤️ Health Protocol', style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w900, color: AppColors.textDark)),
        ),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(20.r),
          decoration: BoxDecoration(
            color: Colors.white, 
            borderRadius: BorderRadius.circular(24.r), 
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _healthItem('MEDICAL NOTES', _medicalConditions),
              SizedBox(height: 16.h),
              _healthItem('ALLERGIES', _allergies),
              SizedBox(height: 16.h),
              _healthItem('EMERGENCY CONTACT', '$_emergencyContactName - $_emergencyInfo', color: const Color(0xFFEF4444)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _healthItem(String label, String val, {Color? color}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w900, color: AppColors.textLight, letterSpacing: 0.5)),
      SizedBox(height: 4.h),
      Text(val, style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w700, color: color ?? AppColors.textDark)),
    ],
  );

  Widget _buildGuardianDetailsCard(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4.w, bottom: 8.h),
          child: Text('👨‍👩‍👧 Guardian Details', style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w900, color: AppColors.textDark)),
        ),
        Container(
          padding: EdgeInsets.all(20.r),
          decoration: BoxDecoration(
            color: Colors.white, 
            borderRadius: BorderRadius.circular(24.r), 
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _guardianSection('Father', _fatherName, _fatherPhone),
              _divider(),
              _guardianSection('Mother', _motherName, _motherPhone),
            ],
          ),
        ),
      ],
    );
  }

  Widget _guardianSection(String role, String name, String phone) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(role, style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w900, color: AppColors.textLight)),
      SizedBox(height: 12.h),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Name', style: GoogleFonts.inter(fontSize: 13.sp, color: AppColors.textMedium)),
          Text(name, style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w700, color: AppColors.textDark)),
        ],
      ),
      SizedBox(height: 8.h),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Phone', style: GoogleFonts.inter(fontSize: 13.sp, color: AppColors.textMedium)),
          Text(phone, style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w700, color: AppColors.textDark)),
        ],
      ),
    ],
  );

  Widget _buildStudentNotificationPreferencesCard(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4.w, bottom: 8.h),
          child: Text('🔔 Notification Preferences', style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w900, color: AppColors.textDark)),
        ),
        Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.r),
            side: const BorderSide(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 10.h),
            child: Column(
              children: [
              SwitchListTile(
                value: _pushNotifications,
                onChanged: _togglePushNotifications,
                title: Text('Push Notifications', style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                subtitle: Text('Receive alerts about attendance & announcements', style: GoogleFonts.inter(fontSize: 11.sp, color: AppColors.textMedium)),
                activeThumbColor: const Color(0xFF1A6FDB),
              ),
              _divider(),
              SwitchListTile(
                value: _inAppNotifications,
                onChanged: _toggleInAppNotifications,
                title: Text('In-App Notifications', style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                subtitle: Text('Show popups and badge counts inside the app', style: GoogleFonts.inter(fontSize: 11.sp, color: AppColors.textMedium)),
                activeThumbColor: const Color(0xFF1A6FDB),
              ),
              _divider(),
              SwitchListTile(
                value: _emailNotifications,
                onChanged: _toggleEmailNotifications,
                title: Text('Email Notifications', style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                subtitle: Text('Receive daily summaries and fee invoices via email', style: GoogleFonts.inter(fontSize: 11.sp, color: AppColors.textMedium)),
                activeThumbColor: const Color(0xFF1A6FDB),
              ),
              _divider(),
              SwitchListTile(
                value: _smsNotifications,
                onChanged: _toggleSMSNotifications,
                title: Text('SMS Notifications', style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                subtitle: Text('Receive emergency alerts and attendance logs on phone', style: GoogleFonts.inter(fontSize: 11.sp, color: AppColors.textMedium)),
                activeThumbColor: const Color(0xFF1A6FDB),
              ),
            ],
          ),
        ),
      ),
      ],
    );
  }

  Future<void> _downloadDocumentFile(String url, String fileName) async {
    if (url.isEmpty) return;
    
    if (kIsWeb) {
      try {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document opened in a new tab.')));
        }
        return;
      } catch (e) {
        debugPrint('Web launch error: $e');
      }
    }

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Downloading document...')));
      }
      
      final response = await Dio().get(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      
      if (response.data == null) throw Exception('No data received');
      
      final bytes = Uint8List.fromList(List<int>.from(response.data as List));
      final extension = fileName.split('.').last.toLowerCase();
      await downloadFile(bytes, fileName, extension);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Download complete!')));
      }
    } catch (e) {
      debugPrint('Download error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed: $e')));
      }
    }
  }

  Widget _buildNewDocumentsVault(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4.w, bottom: 8.h),
          child: Text('📁 Documents Asset Vault', style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w900, color: AppColors.textDark)),
        ),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(20.r),
          decoration: BoxDecoration(
            color: Colors.white, 
            borderRadius: BorderRadius.circular(24.r), 
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_uploadedDocuments.isEmpty)
                Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.h),
                    child: Column(
                      children: [
                        Icon(Icons.insert_drive_file_outlined, size: 48.sp, color: AppColors.textLight),
                        SizedBox(height: 12.h),
                        Text('No documents uploaded yet', style: GoogleFonts.inter(fontSize: 13.sp, color: AppColors.textLight)),
                      ],
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _uploadedDocuments.length,
                  separatorBuilder: (context, idx) => SizedBox(height: 10.h),
                  itemBuilder: (context, idx) {
                    final doc = _uploadedDocuments[idx];
                    final String name = doc['name'] ?? 'Document';
                    final String date = doc['date'] ?? '—';
                    final String url = doc['url'] ?? '';
                    final bool isPdf = name.toLowerCase().endsWith('.pdf');
                    return GestureDetector(
                      onTap: () async {
                        if (url.isNotEmpty) {
                          try {
                            final uri = Uri.parse(url);
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Could not open document. Please check if a viewer is installed.')),
                              );
                            }
                          }
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Document link is unavailable.')),
                            );
                          }
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.all(12.r),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(color: const Color(0xFFE2EAF4)),
                        ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8.r),
                            decoration: BoxDecoration(
                              color: isPdf ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded, 
                              size: 20.sp, 
                              color: isPdf ? const Color(0xFFEF4444) : const Color(0xFF3B82F6),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name, 
                                  style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.bold, color: AppColors.textDark),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  'Uploaded on: $date • ${doc['size'] ?? '—'} • ${doc['type'] ?? 'FILE'}',
                                  style: GoogleFonts.inter(fontSize: 10.sp, color: AppColors.textLight),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.download_rounded, color: AppColors.studentPrimary, size: 18.sp),
                                onPressed: () => _downloadDocumentFile(url, name),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18.sp),
                                onPressed: () => _removeDocument(idx),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ));
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ignore: unused_element
  // ignore: unused_element
  Widget _buildTabbedHeaderCard(bool isDesktop) {
    final List<String> parts = _studentName.trim().split(RegExp(r'\s+'));
    final String initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : (parts.isNotEmpty && parts[0].isNotEmpty
            ? parts[0][0].toUpperCase()
            : 'ST');

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 24.r : 16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2EAF4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: isDesktop ? 64.w : 52.w,
                    height: isDesktop ? 64.w : 52.w,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F1FB),
                      shape: BoxShape.circle,
                    ),
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(isDesktop ? 32.r : 26.r),
                      child: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                          ? (_avatarUrl!.startsWith('data:image')
                              ? Image.memory(
                                  base64Decode(_avatarUrl!.split(',').last),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Center(
                                    child: Text(
                                      initials,
                                      style: GoogleFonts.inter(
                                        fontSize: isDesktop ? 22.sp : 18.sp,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF1A6FDB),
                                      ),
                                    ),
                                  ),
                                )
                              : Image.network(
                                  _avatarUrl!.contains('?') 
                                      ? _avatarUrl! 
                                      : '$_avatarUrl?t=${DateTime.now().millisecondsSinceEpoch}',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Center(
                                    child: Text(
                                      initials,
                                      style: GoogleFonts.inter(
                                        fontSize: isDesktop ? 22.sp : 18.sp,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF1A6FDB),
                                      ),
                                    ),
                                  ),
                                ))
                          : Center(
                              child: Text(
                                initials,
                                style: GoogleFonts.inter(
                                  fontSize: isDesktop ? 22.sp : 18.sp,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1A6FDB),
                                ),
                              ),
                            ),
                    ),
                  ),
                  if (widget.studentId == null)
                    GestureDetector(
                      onTap: _openEditProfileSheet,
                      child: Container(
                        padding: EdgeInsets.all(4.r),
                        decoration: const BoxDecoration(
                          color: Color(0xFF1A6FDB),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black12, blurRadius: 4)
                          ],
                        ),
                        child: Icon(Icons.edit_rounded,
                            size: 10.sp, color: Colors.white),
                      ),
                    ),
                ],
              ),
              SizedBox(width: isDesktop ? 24.w : 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _studentName,
                      style: GoogleFonts.inter(
                        fontSize: isDesktop ? 20.sp : 16.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F2547),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Admission No: $_admissionNo',
                      style: GoogleFonts.inter(
                        fontSize: isDesktop ? 12.sp : 10.5.sp,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  'ACTIVE',
                  style: GoogleFonts.inter(
                    fontSize: isDesktop ? 11.sp : 9.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isDesktop ? 24.h : 16.h),
          const Divider(color: Color(0xFFE2EAF4), height: 1),
          SizedBox(height: isDesktop ? 24.h : 16.h),
          if (isDesktop)
            Row(
              children: [
                Expanded(
                    child: _buildHeaderItem(
                        Icons.email_outlined, 'Email', _studentEmail)),
                SizedBox(width: 20.w),
                Expanded(
                    child: _buildHeaderItem(Icons.phone_outlined, 'Phone',
                        _phone.isNotEmpty && _phone != '—' ? _phone : 'N/A')),
                SizedBox(width: 20.w),
                Expanded(
                    child: _buildHeaderItem(
                        Icons.calendar_today_outlined,
                        'Date of Birth',
                        _studentDob != '—' ? _studentDob : 'N/A')),
                SizedBox(width: 20.w),
                Expanded(
                    child: _buildHeaderItem(Icons.menu_book_outlined, 'Class',
                        '$_studentClass - $_section')),
              ],
            )
          else
            Wrap(
              spacing: 16.w,
              runSpacing: 16.h,
              children: [
                SizedBox(
                  width: 145.w,
                  child: _buildHeaderItem(
                      Icons.email_outlined, 'Email', _studentEmail),
                ),
                SizedBox(
                  width: 145.w,
                  child: _buildHeaderItem(Icons.phone_outlined, 'Phone',
                      _phone.isNotEmpty && _phone != '—' ? _phone : 'N/A'),
                ),
                SizedBox(
                  width: 145.w,
                  child: _buildHeaderItem(
                      Icons.calendar_today_outlined,
                      'Date of Birth',
                      _studentDob != '—' ? _studentDob : 'N/A'),
                ),
                SizedBox(
                  width: 145.w,
                  child: _buildHeaderItem(Icons.menu_book_outlined, 'Class',
                      '$_studentClass - $_section'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderItem(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18.sp, color: const Color(0xFF64748B)),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.caption
                    .copyWith(color: const Color(0xFF64748B)),
              ),
              SizedBox(height: 2.h),
              Text(
                value,
                style: AppTypography.caption
                    .copyWith(color: const Color(0xFF0F2547)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ignore: unused_element
  // ignore: unused_element
  Widget _buildTabbedNavigation(bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF0F6),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: _tabs.map((tab) {
            final bool isActive = _selectedTab == tab;
            return GestureDetector(
              onTap: () => setState(() => _selectedTab = tab),
              child: Container(
                margin: EdgeInsets.only(right: 6.w),
                padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 20.w : 14.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color:
                      isActive ? const Color(0xFFDFEEFA) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  tab,
                  style: GoogleFonts.inter(
                    fontSize: isDesktop ? 13.sp : 12.sp,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                    color: isActive
                        ? const Color(0xFF0F2547)
                        : const Color(0xFF475569),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSummaryCards(bool isDesktop, double totalFee, double discount, double totalPaid, double totalDue) {
    final cards = [
      _buildFeeStatCard(
        'TOTAL FEE',
        '₹${totalFee.toStringAsFixed(0)}',
        const Color(0xFFF1F5F9), // Slate background
        const Color(0xFF0F172A), // Slate text
      ),
      _buildFeeStatCard(
        'DISCOUNT',
        '₹${discount.toStringAsFixed(0)}',
        const Color(0xFFFEF3C7), // Amber background
        const Color(0xFFD97706), // Amber text
      ),
      _buildFeeStatCard(
        'TOTAL PAID',
        '₹${totalPaid.toStringAsFixed(0)}',
        const Color(0xFFD1FAE5), // Green background
        const Color(0xFF059669), // Green text
      ),
      _buildFeeStatCard(
        'TOTAL DUE',
        '₹${totalDue.toStringAsFixed(0)}',
        const Color(0xFFFEE2E2), // Red background
        const Color(0xFFDC2626), // Red text
      ),
    ];

    if (isDesktop) {
      return Row(
        children: cards.map((c) => Expanded(child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: c,
        ))).toList(),
      );
    } else {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10.h,
        crossAxisSpacing: 10.w,
        childAspectRatio: 1.8,
        children: cards,
      );
    }
  }

  Widget _buildFeeStatCard(String label, String value, Color bgColor, Color valueColor) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2EAF4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 20.sp,
              fontWeight: FontWeight.w900,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadQRCodePDF() async {
    if (widget.role == 'teacher' && (_dbQrCode == null || _dbQrCode!.isEmpty)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Please wait until the QR code is loaded.',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        );
      }
      return;
    }

    try {
      final pdf = pw.Document();
      
      final qrData = widget.role == 'teacher'
          ? ((_dbQrCode != null && !_dbQrCode!.startsWith('data:image') && _dbQrCode!.isNotEmpty)
              ? _dbQrCode!
              : (_employeeId.isNotEmpty && _employeeId != 'ID_PENDING' ? _employeeId : 'TEACHER'))
          : _admissionNo;
      final userName = widget.role == 'teacher' ? _userName : _studentName;
      final userRole = widget.role == 'teacher' ? _userRole : widget.role;
      final userId = widget.role == 'teacher' ? _employeeId : (_studentUserId ?? _admissionNo);

      pw.MemoryImage? qrImageProvider;
      if (_dbQrCode != null && _dbQrCode!.startsWith('data:image')) {
        try {
          final base64Str = _dbQrCode!.split(',').last;
          final bytes = base64Decode(base64Str);
          qrImageProvider = pw.MemoryImage(bytes);
        } catch (_) {}
      }

      pw.MemoryImage? avatarImageProvider;
      if (_avatarUrl != null && _avatarUrl!.startsWith('data:image')) {
        try {
          final base64Str = _avatarUrl!.split(',').last;
          final bytes = base64Decode(base64Str);
          avatarImageProvider = pw.MemoryImage(bytes);
        } catch (_) {}
      }

      final issueDate = DateTime.now().toLocal().toString().split(' ').first;
      final genTime = DateTime.now().toLocal().toString().split(' ')[1].substring(0, 5);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Container(
                width: 360,
                padding: const pw.EdgeInsets.all(24),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.blue900, width: 2),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(16)),
                  color: PdfColors.white,
                ),
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'EDUSPHERE INTERNATIONAL SCHOOL',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'DIGITAL ATTENDANCE PASS',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                        letterSpacing: 1.0,
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Container(height: 1, color: PdfColors.grey300),
                    pw.SizedBox(height: 16),
                    if (avatarImageProvider != null) ...[
                      pw.ClipOval(
                        child: pw.Image(avatarImageProvider, width: 80, height: 80, fit: pw.BoxFit.cover),
                      ),
                      pw.SizedBox(height: 12),
                    ],
                    pw.Text(
                      userName,
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Role: ${userRole.toUpperCase()}',
                      style: pw.TextStyle(
                        fontSize: 11,
                        color: PdfColors.grey600,
                      ),
                    ),
                    pw.SizedBox(height: 16),
                    pw.Container(
                      width: 160,
                      height: 160,
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                      ),
                      child: qrImageProvider != null
                          ? pw.Image(qrImageProvider, fit: pw.BoxFit.contain)
                          : pw.BarcodeWidget(
                              barcode: pw.Barcode.qrCode(),
                              data: qrData,
                              drawText: false,
                            ),
                    ),
                    pw.SizedBox(height: 16),
                    pw.Table(
                      columnWidths: {
                        0: const pw.FixedColumnWidth(100),
                        1: const pw.FixedColumnWidth(180),
                      },
                      children: [
                        pw.TableRow(
                          children: [
                            pw.Text(widget.role == 'teacher' ? 'Employee ID:' : 'Admission No:', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                            pw.Text(widget.role == 'teacher' ? _employeeId : _admissionNo, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                        pw.TableRow(
                          children: [
                            pw.Text(widget.role == 'teacher' ? 'Department:' : 'Student ID:', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                            pw.Text(widget.role == 'teacher' ? _department : userId, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                        pw.TableRow(
                          children: [
                            pw.Text(widget.role == 'teacher' ? 'Designation:' : 'Class & Section:', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                            pw.Text(widget.role == 'teacher' ? _designation : '$_studentClass - $_section', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                        pw.TableRow(
                          children: [
                            pw.Text('Issue Date:', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                            pw.Text('$issueDate $genTime', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 16),
                    pw.Container(height: 1, color: PdfColors.grey300),
                    pw.SizedBox(height: 12),
                    pw.Text(
                      'VERIFICATION STATEMENT',
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'This QR Code is cryptographically signed and authorized for campus access verification.',
                      style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'SECURITY DISCLAIMER: DO NOT SHARE. For individual student use only. Screenshot reproduction is strictly prohibited and violates school policy.',
                      style: pw.TextStyle(fontSize: 7, color: PdfColors.red700, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 12),
                    pw.Text(
                      'EduSphere ERP Secure Digital Pass',
                      style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

      final pdfBytes = await pdf.save();
      final fileName = '${userName.replaceAll(' ', '_')}_Attendance_QR';
      
      await downloadFile(
        pdfBytes,
        fileName,
        'pdf',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text('Attendance QR Code PDF downloaded successfully!',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error generating QR PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Failed to download PDF: $e',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        );
      }
    }
  }

  Future<void> _downloadFeeStatement(String studentId, String admissionNo) async {
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
            Text('Downloading statement...', style: GoogleFonts.inter(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
        backgroundColor: const Color(0xFF1A6FDB),
        duration: const Duration(seconds: 10),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      final response = await ApiService.instance.dio.get<List<int>>(
        'fees/students/$studentId/statement',
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.data == null) {
        throw Exception('No data returned from server.');
      }

      final pdfBytes = Uint8List.fromList(response.data!);
      final fileName = 'FeeStatement_$admissionNo.pdf';

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      await downloadFile(
        pdfBytes,
        fileName.replaceAll('.pdf', ''),
        'pdf',
      );

      debugPrint('✅ Statement download completed');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Statement downloaded successfully',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('❌ PDF statement download error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to download statement: $e',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white)),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ignore: unused_element
  // ignore: unused_element
  Widget _buildTabbedTabContent(bool isDesktop) {
    if (_isLoadingTabDetails) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(40.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFFE2EAF4)),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF1A6FDB)),
        ),
      );
    }

    if (_selectedTab == 'Personal Details') {
      final personalCard = Container(
        padding: EdgeInsets.all(20.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFFE2EAF4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Personal Information',
                style: AppTypography.small
                    .copyWith(color: const Color(0xFF0F2547))),
            SizedBox(height: 20.h),
            _buildGridRow(
                'Gender',
                _studentGender != '—' ? _studentGender.toUpperCase() : 'N/A',
                'Blood Group',
                _studentBloodGroup != '—' ? _studentBloodGroup : 'N/A'),
            SizedBox(height: 16.h),
            _buildGridRow(
                'Roll Number', 
                _rollNo.isNotEmpty && _rollNo != '—' ? _rollNo : 'N/A',
                'Admission Number', 
                _admissionNo),
          ],
        ),
      );

      final coreIdentityCard = Container(
        padding: EdgeInsets.all(20.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFFE2EAF4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Core Identity',
                style: AppTypography.small
                    .copyWith(color: const Color(0xFF0F2547))),
            SizedBox(height: 20.h),
            _buildGridRow(
                'Caste Group',
                _casteGroup.isNotEmpty ? _casteGroup : 'N/A',
                'Religion',
                _religion.isNotEmpty ? _religion : 'N/A'),
            SizedBox(height: 16.h),
            _buildGridRow(
                'Nationality',
                _nationality.isNotEmpty ? _nationality : 'N/A',
                'Date of Birth',
                _studentDob != '—' ? _studentDob : 'N/A'),
          ],
        ),
      );

      final guardianCard = Container(
        padding: EdgeInsets.all(20.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFFE2EAF4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Guardian Details',
                style: AppTypography.small
                    .copyWith(color: const Color(0xFF0F2547))),
            SizedBox(height: 20.h),
            _buildGridRow(
                'Father Name',
                _fatherName.isNotEmpty ? _fatherName : 'N/A',
                'Mother Name',
                _motherName.isNotEmpty ? _motherName : 'N/A'),
            SizedBox(height: 16.h),
            _buildGridRow(
                'Father Phone',
                _fatherPhone.isNotEmpty ? _fatherPhone : 'N/A',
                'Mother Phone',
                _motherPhone.isNotEmpty ? _motherPhone : 'N/A'),
            SizedBox(height: 16.h),
            _buildGridRow(
                'Emergency Contact Name',
                _emergencyContactName.isNotEmpty ? _emergencyContactName : 'N/A',
                'Emergency Phone',
                _emergencyInfo != 'UNSET' ? _emergencyInfo : 'N/A'),
            SizedBox(height: 16.h),
            _buildGridRow(
                'Medical Notes',
                _medicalConditions.isNotEmpty ? _medicalConditions : 'N/A',
                'Allergies',
                _allergies.isNotEmpty ? _allergies : 'N/A'),
          ],
        ),
      );

      final addressCard = Container(
        padding: EdgeInsets.all(20.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFFE2EAF4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Address Info',
                style: AppTypography.small
                    .copyWith(color: const Color(0xFF0F2547))),
            SizedBox(height: 20.h),
            Text('Address',
                style: AppTypography.caption
                    .copyWith(color: const Color(0xFF64748B))),
            SizedBox(height: 4.h),
            Text(
                _address.isNotEmpty && _address != 'No location registered' ? _address : 'No registered address available',
                style: AppTypography.caption
                    .copyWith(color: const Color(0xFF0F2547))),
            SizedBox(height: 16.h),
            _buildGridRow(
                'City',
                _studentCity.isNotEmpty ? _studentCity : 'N/A',
                'State',
                _studentState.isNotEmpty ? _studentState : 'N/A'),
            SizedBox(height: 16.h),
            _buildGridRow(
                'Country',
                _studentCountry.isNotEmpty ? _studentCountry : 'N/A',
                'PIN Code',
                _studentPincode.isNotEmpty ? _studentPincode : 'N/A'),
          ],
        ),
      );

      if (isDesktop) {
        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: personalCard),
              ],
            ),
          ],
        );
      } else {
        return Column(
          children: [
            personalCard,
          ],
        );
      }
    }

    if (_selectedTab == 'Academic') {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(20.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFFE2EAF4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Academic Details',
                style: AppTypography.small
                    .copyWith(color: const Color(0xFF0F2547))),
            SizedBox(height: 20.h),
            _buildGridRow('Current Class', _studentClass, 'Section', _section),
            SizedBox(height: 16.h),
            _buildGridRow('Roll Number', _rollNo.isNotEmpty ? _rollNo : 'N/A',
                'Admission Number', _admissionNo),
            SizedBox(height: 16.h),
            _buildGridRow(
                'Academic Batch', _batch, 'Medium of Instruction', _medium),
            SizedBox(height: 16.h),
            _buildGridRow(
                'Enrollment Date', _studentJoinedDate, 'Status', 'ACTIVE'),
          ],
        ),
      );
    }

    if (_selectedTab == 'Attendance') {
      final int total = _attendanceRecords.length;
      final int present = _attendanceRecords
          .where((r) => r['status']?.toString().toUpperCase() == 'PRESENT')
          .length;
      final int late = _attendanceRecords
          .where((r) => r['status']?.toString().toUpperCase() == 'LATE')
          .length;
      final int absent = _attendanceRecords
          .where((r) => r['status']?.toString().toUpperCase() == 'ABSENT')
          .length;

      final double percentage =
          total > 0 ? (present + late) / total * 100 : 92.5;
      final int displayPresent = total > 0 ? present + late : 24;
      final int displayAbsent = total > 0 ? absent : 2;
      final int displayTotal = total > 0 ? total : 26;

      final qrCard = _buildDigitalIdentityCard(isDesktop,
          customTitle: 'Attendance Records');

      final logCard = Container(
        width: double.infinity,
        padding: EdgeInsets.all(20.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFFE2EAF4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recent Attendance Log',
                style: AppTypography.small
                    .copyWith(color: const Color(0xFF0F2547))),
            SizedBox(height: 16.h),
            if (_attendanceRecords.isEmpty)
              _buildMockAttendanceList()
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _attendanceRecords.length > 5
                    ? 5
                    : _attendanceRecords.length,
                itemBuilder: (ctx, idx) {
                  final r = _attendanceRecords[idx];
                  final dateStr = r['date']?.toString() ?? '—';
                  final status = r['status']?.toString() ?? 'PRESENT';
                  final remarks =
                      r['remarks']?.toString() ?? 'Scanned via QR Code';
                  return _buildAttendanceRow(dateStr, status, remarks);
                },
              ),
          ],
        ),
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          qrCard,
        ],
      );
    }

    if (_selectedTab == 'Fees') {
      if (_feeLedgersList.isEmpty) {
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(40.r),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: const Color(0xFFE2EAF4)),
          ),
          child: Center(
            child: Text(
              'No Fee Record Available',
              style: AppTypography.small.copyWith(color: const Color(0xFF64748B)),
            ),
          ),
        );
      }

      double totalFee = 0.0;
      double totalDiscount = 0.0;
      double totalPaid = 0.0;

      for (var ledger in _feeLedgersList) {
        totalFee += double.tryParse(ledger['totalPayable']?.toString() ?? '0') ?? 0.0;
        totalDiscount += double.tryParse(ledger['totalDiscount']?.toString() ?? '0') ?? 0.0;
        totalPaid += double.tryParse(ledger['totalPaid']?.toString() ?? '0') ?? 0.0;
      }
      double totalDue = totalFee - totalPaid;
      if (totalDue < 0) totalDue = 0;

      final headerCard = Container(
        padding: EdgeInsets.all(20.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFFE2EAF4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fee Status',
                    style: GoogleFonts.outfit(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F2547),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Current academic year fee details',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            ElevatedButton.icon(
              onPressed: () {
                final studentId = widget.studentId ?? _currentStudentDbId ?? '';
                _downloadFeeStatement(studentId, _admissionNo);
              },
              icon: Icon(Icons.description_outlined, size: 16.sp, color: const Color(0xFF0F2547)),
              label: Text(
                'Statement',
                style: GoogleFonts.inter(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F2547),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0F2547),
                side: const BorderSide(color: Color(0xFFE2EAF4)),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              ),
            ),
          ],
        ),
      );

      final tableCard = Container(
        width: double.infinity,
        padding: EdgeInsets.all(20.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFFE2EAF4)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: SizedBox(
            width: isDesktop ? (MediaQuery.of(context).size.width - (isDesktop ? 120.w : 72.w)) : 750.w,
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(4), // Fee Structure
                1: FlexColumnWidth(2), // Status
                2: FlexColumnWidth(2), // Total
                3: FlexColumnWidth(2), // Discount
                4: FlexColumnWidth(2), // Paid
                5: FlexColumnWidth(2), // Due
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                // Header Row
                TableRow(
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFFE2EAF4), width: 1.5)),
                  ),
                  children: [
                    Padding(
                      padding: EdgeInsets.only(bottom: 12.h, left: 8.w),
                      child: Text('Fee Structure', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                    ),
                    Padding(
                      padding: EdgeInsets.only(bottom: 12.h),
                      child: Center(child: Text('Status', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)))),
                    ),
                    Padding(
                      padding: EdgeInsets.only(bottom: 12.h),
                      child: Align(alignment: Alignment.centerRight, child: Text('Total', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)))),
                    ),
                    Padding(
                      padding: EdgeInsets.only(bottom: 12.h),
                      child: Align(alignment: Alignment.centerRight, child: Text('Discount', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)))),
                    ),
                    Padding(
                      padding: EdgeInsets.only(bottom: 12.h),
                      child: Align(alignment: Alignment.centerRight, child: Text('Paid', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)))),
                    ),
                    Padding(
                      padding: EdgeInsets.only(bottom: 12.h, right: 8.w),
                      child: Align(alignment: Alignment.centerRight, child: Text('Due', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)))),
                    ),
                  ],
                ),
                // Data Rows
                ..._feeLedgersList.map((ledger) {
                  final structure = ledger['feeStructure'] as Map<String, dynamic>? ?? {};
                  final headName = structure['name']?.toString() ?? 'Fee';
                  final amount = double.tryParse(ledger['totalPayable']?.toString() ?? '0') ?? 0.0;
                  final discount = double.tryParse(ledger['totalDiscount']?.toString() ?? '0') ?? 0.0;
                  final paid = double.tryParse(ledger['totalPaid']?.toString() ?? '0') ?? 0.0;
                  final due = amount - paid;
                  final status = ledger['status']?.toString() ?? 'PENDING';

                  Color statusColor = const Color(0xFFF59E0B);
                  Color statusBg = const Color(0xFFFFFBEB);
                  if (status.toUpperCase() == 'PAID') {
                    statusColor = const Color(0xFF10B981);
                    statusBg = const Color(0xFFECFDF5);
                  } else if (status.toUpperCase() == 'PARTIALLY_PAID') {
                    statusColor = const Color(0xFF1A6FDB);
                    statusBg = const Color(0xFFEFF6FF);
                  } else if (status.toUpperCase() == 'UNPAID' || status.toUpperCase() == 'PENDING') {
                    statusColor = const Color(0xFFEF4444);
                    statusBg = const Color(0xFFFEF2F2);
                  } else if (status.toUpperCase() == 'OVERDUE') {
                    statusColor = const Color(0xFFE11D48);
                    statusBg = const Color(0xFFFFF1F2);
                  }

                  return TableRow(
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
                    ),
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 8.w),
                        child: Text(headName, style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w700, color: const Color(0xFF0F2547))),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        child: Center(
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Text(
                              status.replaceAll('_', ' ').toUpperCase(),
                              style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w800, color: statusColor),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        child: Align(alignment: Alignment.centerRight, child: Text('₹${amount.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.bold, color: const Color(0xFF0F2547)))),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        child: Align(alignment: Alignment.centerRight, child: Text('₹${discount.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.bold, color: const Color(0xFFD97706)))),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        child: Align(alignment: Alignment.centerRight, child: Text('₹${paid.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)))),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 8.w),
                        child: Align(alignment: Alignment.centerRight, child: Text('₹${due.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.bold, color: const Color(0xFFEF4444)))),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          headerCard,
          SizedBox(height: 16.h),
          _buildSummaryCards(isDesktop, totalFee, totalDiscount, totalPaid, totalDue),
          SizedBox(height: 16.h),
          tableCard,
        ],
      );
    }

    if (_selectedTab == 'Time Table') {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(20.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(color: const Color(0xFFE2EAF4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.r),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.access_time_filled_rounded,
                      color: const Color(0xFF1A6FDB), size: 22.sp),
                ),
                SizedBox(width: 14.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Class Time Table',
                      style: GoogleFonts.outfit(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F2547),
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      'Weekly period distribution and timings',
                      style: AppTypography.caption
                          .copyWith(color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 24.h),
            _buildScrollableTable(),
          ],
        ),
      );
    }

    if (_selectedTab == 'Transport') {
      if (_transportAllocation == null || _transportAllocation!['route'] == null) {
        return CustomPaint(
          painter: DashedRectPainter(
            color: const Color(0xFFCBD5E1),
            borderRadius: 16.r,
            dashLength: 6.w,
            gap: 4.w,
            strokeWidth: 1.5,
          ),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 48.h, horizontal: 24.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(16.r),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.directions_bus_outlined,
                    color: const Color(0xFF94A3B8),
                    size: 36.sp,
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'No Transport Allocated',
                  style: GoogleFonts.outfit(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F2547),
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'This student is not currently enrolled in the school transport service.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      final String routeName = _transportAllocation!['route']?['name']?.toString() ?? '—';
      final String stopName = _transportAllocation!['stop']?['name']?.toString() ?? '—';
      final String startLoc = _transportAllocation!['route']?['startLocation']?.toString() ?? '—';
      final String endLoc = _transportAllocation!['route']?['endLocation']?.toString() ?? '—';
      final String vehicleNumber = _transportAllocation!['route']?['vehicleNumber']?.toString() ?? '—';
      final String driverName = _transportAllocation!['route']?['driverName']?.toString() ?? '—';
      final String driverPhone = _transportAllocation!['route']?['driverPhone']?.toString() ?? '—';
      final String pickupTime = _transportAllocation!['stop']?['pickupTime']?.toString() ?? '—';
      final String dropTime = _transportAllocation!['stop']?['dropTime']?.toString() ?? '—';
      final String fare = _transportAllocation!['stop']?['fare']?.toString() ?? '—';
      final String allocationId = _transportAllocation!['id']?.toString() ?? '—';
      final String transStatus = _transportAllocation!['status']?.toString() ?? 'ACTIVE';

      String driverInfo = '—';
      if (driverName != '—' || driverPhone != '—') {
        if (driverName != '—' && driverPhone != '—') {
          driverInfo = '$driverName ($driverPhone)';
        } else if (driverName != '—') {
          driverInfo = driverName;
        } else {
          driverInfo = driverPhone;
        }
      }

      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(20.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFFE2EAF4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Transport Bus Allocation',
                    style: AppTypography.small
                        .copyWith(color: const Color(0xFF0F2547))),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                      color: transStatus.toUpperCase() == 'ACTIVE'
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(6.r)),
                  child: Text(
                    transStatus.toUpperCase(),
                    style: AppTypography.caption
                        .copyWith(color: transStatus.toUpperCase() == 'ACTIVE'
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444)),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),
            _buildGridRow(
                'Assigned Route', routeName, 'Assigned Bus Stop', stopName),
            SizedBox(height: 16.h),
            _buildGridRow(
                'Route Start Location', startLoc, 'Route End Location', endLoc),
            SizedBox(height: 16.h),
            _buildGridRow(
                'Vehicle Number', vehicleNumber, 'Driver Info', driverInfo),
            SizedBox(height: 16.h),
            _buildGridRow(
                'Pickup Time', pickupTime, 'Drop Time', dropTime),
            SizedBox(height: 16.h),
            _buildGridRow(
                'Monthly Fare', fare != '—' ? '₹$fare' : '—', 'Allocation ID', allocationId),
            SizedBox(height: 20.h),
            Container(
              padding: EdgeInsets.all(14.r),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: const Color(0xFFE2EAF4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.directions_bus_filled_outlined,
                      color: const Color(0xFF1A6FDB), size: 20.sp),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      'Bus routes run on schedule every working day. Student scans RFID card upon entry and exit for real-time tracking.',
                      style: AppTypography.caption.copyWith(
                          color: const Color(0xFF64748B), height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_selectedTab == 'Documents') {
      return _buildDocumentsVault();
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(48.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2EAF4)),
      ),
      child: Center(
        child: Text(
          '$_selectedTab details coming soon...',
          style: AppTypography.small.copyWith(color: const Color(0xFF94A3B8)),
        ),
      ),
    );
  }

  Widget _buildGridRow(
      String label1, String value1, String label2, String value2) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label1,
                  style: AppTypography.caption
                      .copyWith(color: const Color(0xFF64748B))),
              SizedBox(height: 4.h),
              Text(value1,
                  style: AppTypography.caption
                      .copyWith(color: const Color(0xFF0F2547)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label2,
                  style: AppTypography.caption
                      .copyWith(color: const Color(0xFF64748B))),
              SizedBox(height: 4.h),
              Text(value2,
                  style: AppTypography.caption
                      .copyWith(color: const Color(0xFF0F2547)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  // ignore: unused_element
  // ignore: unused_element
  Widget _buildAttendanceStatCard(
      String label, String value, Color textColor, Color bgColor) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 12.w),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Column(
          children: [
            Text(label,
                style: AppTypography.caption
                    .copyWith(color: const Color(0xFF64748B)),
                textAlign: TextAlign.center),
            SizedBox(height: 6.h),
            Text(value, style: AppTypography.body.copyWith(color: textColor)),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  // ignore: unused_element
  Widget _buildAttendanceRow(String dateStr, String status, String remarks) {
    Color badgeBg;
    Color badgeText;
    if (status.toUpperCase() == 'PRESENT') {
      badgeBg = const Color(0xFFECFDF5);
      badgeText = const Color(0xFF10B981);
    } else if (status.toUpperCase() == 'ABSENT') {
      badgeBg = const Color(0xFFFEF2F2);
      badgeText = const Color(0xFFEF4444);
    } else {
      badgeBg = const Color(0xFFFFFBEB);
      badgeText = const Color(0xFFD97706);
    }

    String formattedDate = dateStr;
    try {
      final dateObj = DateTime.parse(dateStr);
      formattedDate = '${dateObj.day}/${dateObj.month}/${dateObj.year}';
    } catch (_) {}

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: const Color(0xFFE2EAF4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(formattedDate,
                  style: AppTypography.caption
                      .copyWith(color: const Color(0xFF0F2547))),
              SizedBox(height: 2.h),
              Text(remarks,
                  style: AppTypography.caption
                      .copyWith(color: const Color(0xFF868E96))),
            ],
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
                color: badgeBg, borderRadius: BorderRadius.circular(6.r)),
            child: Text(
              status.toUpperCase(),
              style: AppTypography.caption.copyWith(color: badgeText),
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  // ignore: unused_element
  Widget _buildMockAttendanceList() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20.h),
      alignment: Alignment.center,
      child: Text(
        'No attendance records found',
        style: AppTypography.caption.copyWith(color: const Color(0xFF868E96)),
      ),
    );
  }

  // ignore: unused_field
  // ignore: unused_field
  final List<String> _timetableDays = const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday'
  ];

  final List<Map<String, String>> _timetableColumns = const [
    {'title': 'PERIOD 1', 'time': '08:00 - 08:40', 'start': '08:00'},
    {'title': 'PERIOD 2', 'time': '08:40 - 09:20', 'start': '08:40'},
    {'title': 'PERIOD 3', 'time': '09:20 - 10:00', 'start': '09:20'},
    {'title': 'PERIOD 4', 'time': '10:00 - 10:40', 'start': '10:00'},
    {'title': 'PERIOD 5', 'time': '10:40 - 11:20', 'start': '10:40'},
    {'title': 'PERIOD 6', 'time': '11:20 - 12:00', 'start': '11:20'},
    {'title': 'LUNCH BREAK', 'time': '12:00 - 12:30', 'start': '12:00'},
    {'title': 'PERIOD 7', 'time': '12:30 - 13:10', 'start': '12:30'},
    {'title': 'PERIOD 8', 'time': '13:10 - 13:50', 'start': '13:10'},
    {'title': 'PERIOD 9', 'time': '13:50 - 14:30', 'start': '13:50'},
  ];

  String? _getSubjectForSlot(String day, String startPrefix) {
    final Map<String, int> dayToNum = {
      'Monday': 1,
      'Tuesday': 2,
      'Wednesday': 3,
      'Thursday': 4,
      'Friday': 5,
    };
    final int? dayNum = dayToNum[day];
    if (dayNum == null) return null;
    final slots = _timetableSlots[dayNum];
    if (slots == null) return null;
    for (var slot in slots) {
      String startTime = slot['startTime']?.toString() ?? '';
      List<String> parts = startTime.split(':');
      if (parts.length >= 2) {
        String hh = parts[0].padLeft(2, '0');
        String mm = parts[1].padLeft(2, '0');
        String normalizedStartTime = '$hh:$mm';

        if (normalizedStartTime == startPrefix) {
          final subject = slot['subject'];
          if (subject is Map) {
            return subject['name']?.toString() ?? subject['title']?.toString();
          } else if (subject is String) {
            return subject;
          }
        }
      }
    }
    return null;
  }

  Widget _buildScrollableTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE9F0F8), width: 1.5.w),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTableHeaderRow(),
              ..._timetableDays.map((day) => _buildDayRow(day)),
            ],
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  // ignore: unused_element
  Widget _buildTableHeaderRow() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Color(0xFFE9F0F8), width: 1)),
      ),
      child: Row(
        children: [
          _buildCell('DAY',
              width: 125.w, isHeader: true, alignment: Alignment.centerLeft),
          ..._timetableColumns
              .map((col) => _buildTimeCell(col['title']!, col['time']!)),
        ],
      ),
    );
  }

  // ignore: unused_element
  // ignore: unused_element
  Widget _buildDayRow(String day) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE9F0F8), width: 1)),
      ),
      child: Row(
        children: [
          _buildCell(day,
              width: 125.w, isDayLabel: true, alignment: Alignment.centerLeft),
          ..._timetableColumns.map((col) {
            if (col['title'] == 'LUNCH BREAK') {
              return _buildCell('Lunch Break',
                  width: 125.w,
                  isLunchBreak: true,
                  bgColor: const Color(0xFFFFF9F2));
            }
            final subject = _getSubjectForSlot(day, col['start']!);
            return _buildCell(subject ?? 'Unassigned',
                width: 125.w, isUnassigned: subject == null);
          }),
        ],
      ),
    );
  }

  Widget _buildTimeCell(String title, String time) {
    return Container(
      width: 125.w,
      padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 4.w),
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Color(0xFFE9F0F8), width: 1)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style:
                AppTypography.caption.copyWith(color: const Color(0xFF4A5568)),
          ),
          SizedBox(height: 6.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4.r),
              border: Border.all(color: const Color(0xFFE2EAF4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.access_time,
                    size: 10.sp, color: const Color(0xFFA0AEC0)),
                SizedBox(width: 4.w),
                Text(
                  time,
                  style: AppTypography.caption
                      .copyWith(color: const Color(0xFF718096)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCell(
    String text, {
    required double width,
    bool isHeader = false,
    bool isDayLabel = false,
    bool isUnassigned = false,
    bool isLunchBreak = false,
    Alignment alignment = Alignment.center,
    Color? bgColor,
  }) {
    return Container(
      width: width,
      padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 12.w),
      alignment: alignment,
      decoration: BoxDecoration(
        color: bgColor,
        border:
            const Border(right: BorderSide(color: Color(0xFFE9F0F8), width: 1)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: isHeader || isDayLabel ? 11.sp : 12.sp,
          fontWeight:
              isHeader || isDayLabel ? FontWeight.w800 : FontWeight.w600,
          fontStyle: isUnassigned || isLunchBreak
              ? FontStyle.italic
              : FontStyle.normal,
          color: isLunchBreak
              ? const Color(0xFFE87D3E)
              : isUnassigned
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF2D3748),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.role == 'teacher') {
      return _buildTeacherProfile();
    }

    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 800;

    return _buildTabbedStudentProfile(isDesktop);
  }

  Widget _buildDocumentsVault() {
    final bool isTeacherView = widget.studentId != null;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: const Color(0xFFE2EAF4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insert_drive_file_outlined,
                  size: 18.sp, color: const Color(0xFF1A6FDB)),
              SizedBox(width: 8.w),
              Text(
                isTeacherView ? 'Uploaded Documents' : 'Documents Asset Vault',
                style: GoogleFonts.outfit(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F2547),
                ),
              ),
            ],
          ),
          if (isTeacherView) ...[
            SizedBox(height: 4.h),
            Text(
              'Official documents and certificates for this student.',
              style: AppTypography.caption.copyWith(color: const Color(0xFF64748B)),
            ),
          ],
          SizedBox(height: 16.h),
          _uploadedDocuments.isEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.h),
                    child: Column(
                      children: [
                        Icon(Icons.insert_drive_file_outlined,
                            size: 36.sp, color: const Color(0xFF868E96)),
                        SizedBox(height: 12.h),
                        Text(
                          'No documents uploaded yet',
                          style: AppTypography.caption
                              .copyWith(color: const Color(0xFF868E96)),
                        ),
                        if (!isTeacherView) ...[
                          SizedBox(height: 16.h),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF1A6FDB),
                              side: const BorderSide(color: Color(0xFF1A6FDB)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r)),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16.w, vertical: 8.h),
                              elevation: 0,
                            ),
                            onPressed:
                                _isUploadingDoc ? null : _simulateDocumentUpload,
                            icon: _isUploadingDoc
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child:
                                        CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.upload_file, size: 14),
                            label: Text(
                              _isUploadingDoc
                                  ? 'Uploading...'
                                  : 'Upload Document',
                              style: AppTypography.caption,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _uploadedDocuments.length,
                      itemBuilder: (ctx, idx) {
                        final doc = _uploadedDocuments[idx];
                        final String docTitle = isTeacherView
                            ? (doc['docType'] ?? 'Document')
                            : (doc['name'] ?? '');
                        final String docSub = isTeacherView
                            ? (doc['name'] ?? '')
                            : 'Uploaded on: ${doc['date']}';
                        
                        return Container(
                          margin: EdgeInsets.only(bottom: 8.h),
                          padding: EdgeInsets.symmetric(
                              horizontal: 12.w, vertical: 10.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: const Color(0xFFE2EAF4)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.insert_drive_file_outlined,
                                  size: 18.sp, color: const Color(0xFF868E96)),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      docTitle,
                                      style: AppTypography.caption.copyWith(
                                          color: const Color(0xFF0F2547),
                                          fontWeight: isTeacherView
                                              ? FontWeight.bold
                                              : FontWeight.normal),
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      docSub,
                                      style: AppTypography.caption.copyWith(
                                          color: const Color(0xFF868E96)),
                                    ),
                                    if (isTeacherView) ...[
                                      SizedBox(height: 2.h),
                                      Text(
                                        'Uploaded on: ${doc['date']}',
                                        style: AppTypography.caption.copyWith(
                                            color: const Color(0xFF94A3B8),
                                            fontSize: 9.sp),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (isTeacherView)
                                IconButton(
                                  icon: const Icon(Icons.download_rounded,
                                      color: Color(0xFF1A6FDB), size: 18),
                                  onPressed: () => _downloadDocumentFile(
                                      doc['url'] ?? '', doc['name'] ?? ''),
                                )
                              else
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded,
                                      color: Color(0xFFE03131), size: 18),
                                  onPressed: () => _removeDocument(idx),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                    if (!isTeacherView) ...[
                      SizedBox(height: 12.h),
                      Center(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF1A6FDB),
                            side: const BorderSide(color: Color(0xFF1A6FDB)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r)),
                            padding: EdgeInsets.symmetric(
                                horizontal: 16.w, vertical: 8.h),
                            elevation: 0,
                          ),
                          onPressed:
                              _isUploadingDoc ? null : _simulateDocumentUpload,
                          icon: _isUploadingDoc
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.upload_file, size: 14),
                          label: Text(
                            _isUploadingDoc ? 'Uploading...' : 'Upload Document',
                            style: AppTypography.caption,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildDigitalIdentityCard(bool isDesktop, {String? customTitle}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: const Color(0xFFE2EAF4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.qr_code_2_rounded,
                  size: 18.sp, color: const Color(0xFF1A6FDB)),
              SizedBox(width: 8.w),
              Text(
                customTitle ?? 'Digital Identity & QR Attendance',
                style: GoogleFonts.outfit(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F2547),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 4, child: _buildQRCodeContainer()),
                SizedBox(width: 20.w),
                Expanded(flex: 6, child: _buildQRInfoContainer()),
              ],
            )
          else
            Column(
              children: [
                _buildQRCodeContainer(),
                SizedBox(height: 20.h),
                _buildQRInfoContainer(),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildQRCodeContainer() {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFE2EAF4)),
      ),
      child: Column(
        children: [
          Text(
            'ATTENDANCE QR CODE',
            style: AppTypography.caption
                .copyWith(color: const Color(0xFF868E96), letterSpacing: 0.5),
          ),
          SizedBox(height: 12.h),
          Container(
            width: 180.w,
            height: 180.w,
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: const Color(0xFFE2EAF4)),
            ),
            child: _isQrLoading && _dbQrCode == null
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF1A6FDB),
                    ),
                  )
                : _qrError && _dbQrCode == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 28),
                            SizedBox(height: 8.h),
                            Text(
                              'Failed to load QR',
                              style: AppTypography.caption.copyWith(color: Colors.red),
                            ),
                            TextButton(
                              onPressed: () {
                                _loadStudentDataFromSupabase();
                              },
                              child: Text(
                                'Retry',
                                style: AppTypography.caption.copyWith(color: const Color(0xFF1A6FDB)),
                              ),
                            ),
                          ],
                        ),
                      )
                    : (_dbQrCode != null && _dbQrCode!.startsWith('data:image')
                        ? (() {
                            try {
                              final base64Str = _dbQrCode!.split(',').last;
                              final bytes = base64Decode(base64Str);
                              return Image.memory(
                                bytes,
                                fit: BoxFit.contain,
                                errorBuilder: (cxt, err, stack) {
                                  return Center(
                                    child: Text(
                                      'QR Error',
                                      style: AppTypography.caption
                                          .copyWith(color: const Color(0xFF0F2547)),
                                    ),
                                  );
                                },
                              );
                            } catch (e) {
                              return Center(
                                child: Text(
                                  'QR Error',
                                  style: AppTypography.caption
                                      .copyWith(color: const Color(0xFF0F2547)),
                                ),
                              );
                            }
                          })()
                        : QrImageView(
                            data: (_dbQrCode != null && _dbQrCode!.isNotEmpty)
                                ? _dbQrCode!
                                : (_admissionNo.isNotEmpty ? _admissionNo : 'STUDENT'),
                            version: QrVersions.auto,
                            size: 156.w,
                            gapless: false,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Color(0xFF0F2547),
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Color(0xFF0F2547),
                            ),
                            errorStateBuilder: (cxt, err) {
                              return Center(
                                child: Text(
                                  'Error',
                                  style: GoogleFonts.inter(color: const Color(0xFF0F2547)),
                                ),
                              );
                            },
                          )),
          ),
          SizedBox(height: 12.h),
          Text(
            _studentName,
            style: GoogleFonts.outfit(
              fontSize: 14.sp,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F2547),
            ),
          ),
          SizedBox(height: 4.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F1FB),
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Text(
              widget.role == 'teacher' ? 'TEACHER' : 'STUDENT',
              style: AppTypography.caption
                  .copyWith(color: const Color(0xFF1A6FDB)),
            ),
          ),
          SizedBox(height: 16.h),
          GestureDetector(
            onTap: _downloadQRCodePDF,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.download_rounded,
                      color: Colors.white, size: 14.sp),
                  SizedBox(width: 6.w),
                  Text(
                    'Download',
                    style: AppTypography.caption.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 8.h),
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF1A6FDB),
                  content: Text(
                    widget.role == 'teacher'
                        ? 'Teacher ID: $_admissionNo'
                        : 'Student ID: $_admissionNo',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                ),
              );
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: const Color(0xFFE2EAF4),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Text(
                widget.role == 'teacher' ? 'TEACHER ID' : 'STUDENT ID',
                style: AppTypography.caption
                    .copyWith(color: const Color(0xFF495057)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQRInfoContainer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: EdgeInsets.only(top: 4.h),
              width: 5.w,
              height: 5.w,
              decoration: const BoxDecoration(
                  color: Color(0xFF1A6FDB), shape: BoxShape.circle),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                'This QR code is used for scanning attendance at QR scanner devices located throughout the campus.',
                style: AppTypography.caption
                    .copyWith(color: const Color(0xFF6B7A90), height: 1.3),
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: EdgeInsets.only(top: 4.h),
              width: 5.w,
              height: 5.w,
              decoration: const BoxDecoration(
                  color: Color(0xFF1A6FDB), shape: BoxShape.circle),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                'Each scan will update present/absent status in real-time to HMS account.',
                style: AppTypography.caption
                    .copyWith(color: const Color(0xFF6B7A90), height: 1.3),
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: EdgeInsets.only(top: 4.h),
              width: 5.w,
              height: 5.w,
              decoration: const BoxDecoration(
                  color: Color(0xFF1A6FDB), shape: BoxShape.circle),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                'Admins can regenerate the QR if it is lost or compromised.',
                style: AppTypography.caption
                    .copyWith(color: const Color(0xFF6B7A90), height: 1.3),
              ),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.shield_outlined,
                  color: const Color(0xFF10B981), size: 16.sp),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  'The QR is valid at any active scanner. The user\'s data is allowed on.',
                  style: AppTypography.caption
                      .copyWith(color: const Color(0xFF10B981)),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 10.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F8FC),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
                color: const Color(0xFF1A6FDB).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.location_on_outlined,
                  color: const Color(0xFF1A6FDB), size: 16.sp),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  'GPS geofencing is enforced by the scanner device, not the QR code itself.',
                  style: AppTypography.caption
                      .copyWith(color: const Color(0xFF1A6FDB)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickAndUploadAvatar() async {
    final prefs = CacheService.instance.prefs;
    final userId = _currentUserId ?? prefs.getString('user_id');

    if (userId == null) {
      if (mounted) showToast(context, 'Not logged in. Cannot upload avatar.');
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.all(16.r),
                child: Text('Update Profile Photo', style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              ),
              ListTile(
                leading: Icon(Icons.camera_alt_rounded, color: const Color(0xFF1A6FDB), size: 22.sp),
                title: Text('Take Photo', style: GoogleFonts.inter(fontSize: 14.sp, color: AppColors.textDark)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _processPickedImage(ImageSource.camera, userId);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library_rounded, color: const Color(0xFF1A6FDB), size: 22.sp),
                title: Text('Choose from Gallery', style: GoogleFonts.inter(fontSize: 14.sp, color: AppColors.textDark)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _processPickedImage(ImageSource.gallery, userId);
                },
              ),
              if (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                ListTile(
                  leading: Icon(Icons.delete_outline_rounded, color: Colors.red, size: 22.sp),
                  title: Text('Remove Photo', style: GoogleFonts.inter(fontSize: 14.sp, color: Colors.red)),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    final confirm = await _showConfirmDialog('Remove Photo', 'Are you sure you want to remove your profile photo?');
                    if (confirm == true) {
                      await _deleteAvatar(userId);
                    }
                  },
                ),
              ListTile(
                leading: Icon(Icons.close_rounded, color: Colors.grey, size: 22.sp),
                title: Text('Cancel', style: GoogleFonts.inter(fontSize: 14.sp, color: Colors.grey)),
                onTap: () => Navigator.pop(sheetCtx),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _processPickedImage(ImageSource source, String userId) async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 600,
        maxHeight: 600,
      );

      if (pickedFile == null) return;

      final bytes = await pickedFile.readAsBytes();
      final extension = pickedFile.path.split('.').last.toLowerCase();

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (dialogCtx) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
            title: Text('Preview Photo', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 150.r,
                  height: 150.r,
                  decoration: const BoxDecoration(shape: BoxShape.circle),
                  clipBehavior: Clip.antiAlias,
                  child: Image.memory(bytes, fit: BoxFit.cover),
                ),
                SizedBox(height: 12.h),
                Text('Do you want to upload this photo?', style: GoogleFonts.inter(fontSize: 12.sp, color: AppColors.textMedium)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A6FDB),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                ),
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  _uploadAvatarBytes(bytes, extension, userId);
                },
                child: Text('Upload', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      );
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) showToast(context, 'Error selecting image: $e');
    }
  }

  Future<void> _uploadAvatarBytes(List<int> bytes, String extension, String userId) async {
    if (mounted) showToast(context, 'Uploading avatar...');
    try {
      final res = await ApiService.instance.multipartRequest(
        'PATCH',
        'users/$userId/avatar',
        fileKey: 'avatar',
        fileBytes: bytes,
        fileName: '$userId.$extension',
      );

      if (res != null && res['success'] == true) {
        String? publicUrl = res['user']?['avatar'] as String?;
        final prefs = CacheService.instance.prefs;
        if (publicUrl != null) {
          if (!publicUrl.startsWith('http') && !publicUrl.startsWith('data:image')) {
            publicUrl = '${ApiConfig.serverBaseUrl}${publicUrl.startsWith('/') ? '' : '/'}$publicUrl';
          }
          final busterUrl = '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';
          await prefs.setString('${widget.role}_photo_url', busterUrl);
          final base64Str = base64Encode(bytes);
          final dataUrl = 'data:image/$extension;base64,$base64Str';
          
          if (widget.onAvatarUpdated != null) {
            widget.onAvatarUpdated!(dataUrl);
          }
          
          if (_isOwnProfile) {
            AppStateNotifier.userProfilePhotoUrl.value = dataUrl;
          }
          
          if (mounted) {
            setState(() {
              _avatarUrl = dataUrl;
            });
            showToast(context, 'Avatar updated successfully!');
          }
        }
      } else {
        throw Exception(res?['message'] ?? 'Upload failed');
      }
    } catch (e) {
      debugPrint('Avatar upload failed: $e');
      String errMsg = 'Upload failed: $e';
      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        if (statusCode != null) {
          final data = e.response?.data;
          if (data is Map && data['message'] != null) {
            errMsg = data['message'].toString();
          } else {
            switch (statusCode) {
              case 401: errMsg = 'Unauthorized. Please log in again.'; break;
              case 403: errMsg = 'Access denied.'; break;
              case 404: errMsg = 'Endpoint not found.'; break;
              case 413: errMsg = 'File size is too large.'; break;
              case 422: errMsg = 'Invalid image format.'; break;
              case 429: errMsg = 'Too many requests. Please try later.'; break;
              case 500: errMsg = 'Internal server error.'; break;
              default: errMsg = 'Server returned code $statusCode.';
            }
          }
        } else if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.sendTimeout || e.type == DioExceptionType.receiveTimeout) {
          errMsg = 'Connection timed out. Please check your internet.';
        } else if (e.type == DioExceptionType.connectionError) {
          errMsg = 'No internet connection detected.';
        }
      }
      if (mounted) showToast(context, errMsg);
    }
  }

  Future<void> _deleteAvatar(String userId) async {
    if (mounted) showToast(context, 'Removing avatar...');
    try {
      final res = await ApiService.instance.delete('users/$userId/avatar');
      
      if (res != null && res['success'] == true) {
        final prefs = CacheService.instance.prefs;
        await prefs.remove('${widget.role}_photo_url');
        if (widget.onAvatarUpdated != null) {
          widget.onAvatarUpdated!('');
        }
        if (_isOwnProfile) {
          AppStateNotifier.userProfilePhotoUrl.value = null;
        }
        if (mounted) {
          setState(() {
            _avatarUrl = null;
          });
          showToast(context, 'Avatar removed successfully!');
        }
      } else {
        throw Exception('Delete failed');
      }
    } catch (e) {
      debugPrint('Avatar removal failed: $e');
      String errMsg = 'Failed to remove avatar: $e';
      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        if (statusCode != null) {
          final data = e.response?.data;
          if (data is Map && data['message'] != null) {
            errMsg = data['message'].toString();
          }
        }
      }
      if (mounted) showToast(context, errMsg);
    }
  }

  Future<bool?> _showConfirmDialog(String title, String desc) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text(desc, style: GoogleFonts.inter(fontSize: 13.sp, color: AppColors.textMedium)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Confirm', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherProfile() {
    final bool isPushed = Navigator.canPop(context);
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 900;

    final bodyContent = SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
            isDesktop ? 32.r : 16.r, 20.r, isDesktop ? 32.r : 16.r, 120.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and Subtitle Header
            Text(
              'My Profile',
              style: GoogleFonts.outfit(
                fontSize: 24.sp,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0F2547),
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Manage your account and view your detailed information',
              style: AppTypography.caption
                  .copyWith(color: const Color(0xFF64748B), height: 1.4),
            ),
            SizedBox(height: 24.h),

            // Core Profile Card
            _buildCoreProfileCard(isDesktop),
            SizedBox(height: 20.h),

            // Summary Cards
            if (isDesktop)
              Row(
                children: [
                  Expanded(
                      child: _buildSummaryCard(
                          'Last Session',
                          _lastSession,
                          Icons.access_time_rounded,
                          const Color(0xFF3B82F6),
                          true)),
                  SizedBox(width: 16.w),
                  Expanded(
                      child: _buildSummaryCard(
                          'Activity Status',
                          _activityStatus,
                          Icons.check_circle_outline,
                          const Color(0xFF10B981),
                          false)),
                  SizedBox(width: 16.w),
                  Expanded(
                      child: _buildSummaryCard(
                          'Employment',
                          _designation,
                          Icons.business_center_outlined,
                          const Color(0xFF8B5CF6),
                          false,
                          true)),
                  SizedBox(width: 16.w),
                  Expanded(
                      child: _buildSummaryCard(
                          'Joined Date',
                          _joinedDate,
                          Icons.calendar_month_outlined,
                          const Color(0xFF06B6D4),
                          false)),
                ],
              )
            else
              Column(
                children: [
                  _buildSummaryCard('Last Session', _lastSession,
                      Icons.access_time_rounded, const Color(0xFF3B82F6), true),
                  SizedBox(height: 16.h),
                  _buildSummaryCard(
                      'Activity Status',
                      _activityStatus,
                      Icons.check_circle_outline,
                      const Color(0xFF10B981),
                      false),
                  SizedBox(height: 16.h),
                  _buildSummaryCard(
                      'Employment',
                      _designation,
                      Icons.business_center_outlined,
                      const Color(0xFF8B5CF6),
                      false,
                      true),
                  SizedBox(height: 16.h),
                  _buildSummaryCard(
                      'Joined Date',
                      _joinedDate,
                      Icons.calendar_month_outlined,
                      const Color(0xFF06B6D4),
                      false),
                ],
              ),
            SizedBox(height: 24.h),

            // Detail Cards Row 1: Personal Info & Professional Identity
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildPersonalInfoCard()),
                  SizedBox(width: 20.w),
                  Expanded(child: _buildIdentityInfoCard()),
                ],
              )
            else
              Column(
                children: [
                  _buildPersonalInfoCard(),
                  SizedBox(height: 16.h),
                  _buildIdentityInfoCard(),
                ],
              ),
            SizedBox(height: 20.h),

            // Detail Cards Row 2: Security Status & Notification Preferences
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildSecurityStatusCard()),
                  SizedBox(width: 20.w),
                  Expanded(child: _buildNotificationPreferencesCard()),
                ],
              )
            else
              Column(
                children: [
                  _buildSecurityStatusCard(),
                  SizedBox(height: 16.h),
                  _buildNotificationPreferencesCard(),
                ],
              ),
            SizedBox(height: 20.h),

            // Digital Identity & QR Attendance Card
            _buildTeacherDigitalIdentityCard(isDesktop),
          ],
        ),
      );

    final fab = (widget.role == 'teacher' &&
            widget.teacherId != null &&
            widget.teacherId != _currentUserId)
        ? null
        : FloatingActionButton(
            onPressed: _showEditProfileSheet,
            backgroundColor: const Color(0xFF0284C7),
            elevation: 4,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r)),
            child: const Icon(Icons.edit_note, color: Colors.white, size: 28),
          );

    if (widget.showAppBar) {
      return TeacherScaffold(
        scaffoldKey: _teacherScaffoldKey,
        title: 'EduSphere',
        activeIndex: 13,
        floatingActionButton: fab,
        body: bodyContent,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFEFF6FF),
      floatingActionButton: fab,
      body: bodyContent,
    );
  }

  Widget _buildSummaryCard(
      String title, String value, IconData icon, Color color, bool isTopBorder,
      [bool isUpperValue = false]) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -20.w,
            top: -24.h,
            bottom: -24.h,
            child: Container(
              width: 4.w,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16.r),
                  bottomLeft: Radius.circular(16.r),
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.caption
                        .copyWith(color: const Color(0xFF64748B)),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    isUpperValue ? value.toUpperCase() : value,
                    style: AppTypography.body
                        .copyWith(color: const Color(0xFF0F172A)),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 16.sp),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCoreProfileCard(bool isDesktop) {
    if (!isDesktop) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(24.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Initials circle avatar with edit overlays
            GestureDetector(
              onTap: _pickAndUploadAvatar,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 90.r,
                    height: 90.r,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: const Color(0xFFE2E8F0), width: 3),
                    ),
                    child: ClipOval(
                      child: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                          ? (_avatarUrl!.startsWith('data:image')
                              ? Image.memory(
                                  base64Decode(_avatarUrl!.split(',').last),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Image.asset(
                                    'assets/images/logo.png',
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Image.network(
                                  _avatarUrl!.contains('?') 
                                      ? _avatarUrl! 
                                      : '$_avatarUrl?t=${DateTime.now().millisecondsSinceEpoch}',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Image.asset(
                                    'assets/images/logo.png',
                                    fit: BoxFit.cover,
                                  ),
                                ))
                          : Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(6.r),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(Icons.camera_alt_outlined,
                        color: Colors.white, size: 12.sp),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),

            Text(
              _userName,
              style: AppTypography.h4.copyWith(color: const Color(0xFF0F2547)),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Text(
                widget.role.toUpperCase(),
                style: AppTypography.caption.copyWith(
                    color: const Color(0xFF2563EB), letterSpacing: 0.5),
              ),
            ),
            SizedBox(height: 12.h),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16.w,
              runSpacing: 8.h,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.email_outlined,
                        size: 16.sp, color: const Color(0xFF64748B)),
                    SizedBox(width: 6.w),
                    Text(
                      _email,
                      style: AppTypography.caption
                          .copyWith(color: const Color(0xFF475569)),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.phone_outlined,
                        size: 16.sp, color: const Color(0xFF64748B)),
                    SizedBox(width: 6.w),
                    Text(
                      _phone,
                      style: AppTypography.caption
                          .copyWith(color: const Color(0xFF475569)),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 24.h),

            // Update avatar action
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _pickAndUploadAvatar,
                icon: Icon(Icons.camera_alt_outlined,
                    size: 16.sp, color: const Color(0xFF0F172A)),
                label: Text(
                  'Update Avatar',
                  style: AppTypography.caption
                      .copyWith(color: const Color(0xFF0F172A)),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFFF8FAFC),
                  side: const BorderSide(color: Color(0xFFE2EAF4)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: _pickAndUploadAvatar,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 80.r,
                  height: 80.r,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 3),
                  ),
                  child: ClipOval(
                    child: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                        ? (_avatarUrl!.startsWith('data:image')
                            ? Image.memory(
                                base64Decode(_avatarUrl!.split(',').last),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Image.asset(
                                  'assets/images/logo.png',
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Image.network(
                                _avatarUrl!.contains('?') 
                                    ? _avatarUrl! 
                                    : '$_avatarUrl?t=${DateTime.now().millisecondsSinceEpoch}',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Image.asset(
                                  'assets/images/logo.png',
                                  fit: BoxFit.cover,
                                ),
                              ))
                        : Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(4.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Icon(Icons.camera_alt_outlined,
                      color: Colors.white, size: 10.sp),
                ),
              ],
            ),
          ),
          SizedBox(width: 24.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _userName,
                      style: AppTypography.h4
                          .copyWith(color: const Color(0xFF0F2547)),
                    ),
                    SizedBox(width: 12.w),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDBEAFE),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Text(
                        widget.role.toUpperCase(),
                        style: AppTypography.caption.copyWith(
                            color: const Color(0xFF2563EB), letterSpacing: 0.5),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Icon(Icons.email_outlined,
                        size: 16.sp, color: const Color(0xFF64748B)),
                    SizedBox(width: 6.w),
                    Text(
                      _email,
                      style: AppTypography.caption
                          .copyWith(color: const Color(0xFF475569)),
                    ),
                    SizedBox(width: 24.w),
                    Icon(Icons.phone_outlined,
                        size: 16.sp, color: const Color(0xFF64748B)),
                    SizedBox(width: 6.w),
                    Text(
                      _phone,
                      style: AppTypography.caption
                          .copyWith(color: const Color(0xFF475569)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: _pickAndUploadAvatar,
            icon: Icon(Icons.camera_alt_outlined,
                size: 16.sp, color: const Color(0xFF0F172A)),
            label: Text(
              'Update Avatar',
              style: AppTypography.caption
                  .copyWith(color: const Color(0xFF0F172A)),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xFFF8FAFC),
              side: const BorderSide(color: Color(0xFFE2EAF4)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListCard(
      String title, IconData titleIcon, List<Widget> children) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(20.r),
            child: Row(
              children: [
                Icon(titleIcon, color: const Color(0xFF0284C7), size: 20.sp),
                SizedBox(width: 8.w),
                Text(
                  title,
                  style: AppTypography.small
                      .copyWith(color: const Color(0xFF0F2547)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Padding(
            padding: EdgeInsets.all(20.r),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListItem(IconData icon, String label, String value,
      {bool isRedValue = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18.sp, color: const Color(0xFF64748B)),
                  SizedBox(width: 12.w),
                  Text(
                    label,
                    style: AppTypography.caption
                        .copyWith(color: const Color(0xFF475569)),
                  ),
                ],
              ),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: AppTypography.caption.copyWith(
                      color: isRedValue
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoCard() {
    return _buildListCard(
      'Personal Information',
      Icons.person_outline,
      [
        _buildListItem(Icons.person_outline, 'Gender', _gender),
        _buildListItem(Icons.calendar_today_outlined, 'Date of Birth', _dob),
        _buildListItem(Icons.favorite_border, 'Blood Group', _bloodGroup),
        _buildListItem(Icons.location_on_outlined, 'Address', _address),
      ],
    );
  }

  Widget _buildIdentityInfoCard() {
    return _buildListCard(
      'Professional Identity',
      Icons.military_tech_outlined,
      [
        _buildListItem(Icons.badge_outlined, 'Employee ID', _employeeId),
        _buildListItem(
            Icons.business_center_outlined, 'Designation', _designation),
        _buildListItem(Icons.domain, 'Department', _department),
      ],
    );
  }

  Widget _buildSecurityStatusCard() {
    final bool isOwnProfile = widget.role == 'student'
        ? (widget.studentId == null)
        : (widget.teacherId == null ||
            widget.teacherId == _currentUserId);

    return _buildListCard(
      'Security Status',
      Icons.lock_outline,
      [
        _buildListItem(
            Icons.access_time, 'Last Password Change', _lastPasswordChange,
            isRedValue: _lastPasswordChange.contains('Action')),
        if (isOwnProfile) ...[
          SizedBox(height: 4.h),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                _showChangePasswordSheet();
              },
              icon: Icon(Icons.vpn_key_outlined,
                  size: 16.sp, color: const Color(0xFF0F172A)),
              label: Text(
                'Change Password',
                style: AppTypography.caption
                    .copyWith(color: const Color(0xFF0F172A)),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFFF8FAFC),
                side: const BorderSide(color: Color(0xFFE2EAF4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
                padding: EdgeInsets.symmetric(vertical: 12.h),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNotificationPreferencesCard() {
    return _buildListCard(
      'Notification Preferences',
      Icons.notifications_outlined,
      [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Push Notifications',
                    style: AppTypography.caption
                        .copyWith(color: const Color(0xFF0F172A))),
                SizedBox(height: 2.h),
                Text('Receive browser push alerts',
                    style: AppTypography.caption
                        .copyWith(color: const Color(0xFF64748B))),
              ],
            ),
            Switch(
              value: _pushEnabled,
              onChanged: (val) {
                setState(() => _pushEnabled = val);
                SharedPreferences.getInstance()
                    .then((p) => p.setBool('notifications_enabled', val));
              },
              activeThumbColor: Colors.white,
              activeTrackColor: const Color(0xFF3B82F6),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        const Divider(height: 1, color: Color(0xFFF1F5F9)),
        SizedBox(height: 16.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('In-App Notifications',
                    style: AppTypography.caption
                        .copyWith(color: const Color(0xFF0F172A))),
                SizedBox(height: 2.h),
                Text('Show alerts inside dashboard',
                    style: AppTypography.caption
                        .copyWith(color: const Color(0xFF64748B))),
              ],
            ),
            Switch(
              value: _inAppEnabled,
              onChanged: (val) {
                setState(() => _inAppEnabled = val);
                SharedPreferences.getInstance()
                    .then((p) => p.setBool('in_app_notifications', val));
              },
              activeThumbColor: Colors.white,
              activeTrackColor: const Color(0xFF3B82F6),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTeacherDigitalIdentityCard(bool isDesktop) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(20.r),
            child: Row(
              children: [
                Icon(Icons.qr_code,
                    color: const Color(0xFF0284C7), size: 20.sp),
                SizedBox(width: 8.w),
                Text(
                  'Digital Identity & QR Attendance',
                  style: AppTypography.small
                      .copyWith(color: const Color(0xFF0F2547)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Padding(
            padding: EdgeInsets.all(20.r),
            child: isDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 4, child: _buildTeacherQRCodeBox()),
                      SizedBox(width: 24.w),
                      Expanded(flex: 6, child: _buildTeacherQRInfoBox()),
                    ],
                  )
                : Column(
                    children: [
                      _buildTeacherQRCodeBox(),
                      SizedBox(height: 24.h),
                      _buildTeacherQRInfoBox(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherQRCodeBox() {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.qr_code_2,
                  size: 16.sp, color: const Color(0xFF475569)),
              SizedBox(width: 6.w),
              Text(
                'ATTENDANCE QR CODE',
                style: AppTypography.caption.copyWith(
                    color: const Color(0xFF475569), letterSpacing: 0.5),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Container(
            width: 180.w,
            height: 180.w,
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: _isQrLoading && _dbQrCode == null
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF1A6FDB),
                    ),
                  )
                : _qrError && _dbQrCode == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 28),
                            SizedBox(height: 8.h),
                            Text(
                              'Failed to load QR',
                              style: AppTypography.caption.copyWith(color: Colors.red),
                            ),
                            TextButton(
                              onPressed: () {
                                _loadTeacherDataFromSupabase();
                              },
                              child: Text(
                                'Retry',
                                style: AppTypography.caption.copyWith(color: const Color(0xFF1A6FDB)),
                              ),
                            ),
                          ],
                        ),
                      )
                    : (_dbQrCode != null && _dbQrCode!.startsWith('data:image')
                        ? (() {
                            try {
                              final base64Str = _dbQrCode!.split(',').last;
                              final bytes = base64Decode(base64Str);
                              return Image.memory(
                                bytes,
                                fit: BoxFit.contain,
                                errorBuilder: (cxt, err, stack) {
                                  return Center(
                                    child: Text(
                                      'QR Error',
                                      style: AppTypography.caption
                                          .copyWith(color: const Color(0xFF0F172A)),
                                    ),
                                  );
                                },
                              );
                            } catch (e) {
                              return Center(
                                child: Text(
                                  'QR Error',
                                  style: AppTypography.caption
                                      .copyWith(color: const Color(0xFF0F172A)),
                                ),
                              );
                            }
                          })()
                        : QrImageView(
                            data: (_dbQrCode != null && _dbQrCode!.isNotEmpty)
                                ? _dbQrCode!
                                : (_employeeId.isNotEmpty ? _employeeId : 'TEACHER'),
                            version: QrVersions.auto,
                            size: 156.w,
                            gapless: false,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Color(0xFF0F172A),
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Color(0xFF0F172A),
                            ),
                            errorStateBuilder: (cxt, err) {
                              return Center(
                                child: Text(
                                  'Error',
                                  style: GoogleFonts.inter(color: const Color(0xFF0F172A)),
                                ),
                              );
                            },
                          )),
          ),
          SizedBox(height: 16.h),
          Text(
            _userName,
            style: AppTypography.small.copyWith(color: const Color(0xFF0F172A)),
          ),
          SizedBox(height: 4.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: const Color(0xFFDBEAFE),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Text(
              _userRole.toUpperCase(),
              style: AppTypography.caption
                  .copyWith(color: const Color(0xFF2563EB)),
            ),
          ),
          SizedBox(height: 20.h),
          ElevatedButton.icon(
            onPressed: _downloadQRCodePDF,
            icon: const Icon(Icons.file_download_outlined,
                size: 18, color: Colors.white),
            label: Text('Download', style: AppTypography.caption),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r)),
              minimumSize: Size(double.infinity, 44.h),
            ),
          ),
          SizedBox(height: 16.h),
          Center(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: _qrIssued ? const Color(0xFF0284C7) : const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text(
                _qrIssued ? 'ISSUED & LOCKED' : 'ACTIVE & UNLOCKED',
                style: AppTypography.caption
                    .copyWith(color: Colors.white, letterSpacing: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherQRInfoBox() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
                width: 8.r,
                height: 8.r,
                decoration: const BoxDecoration(
                    color: Color(0xFF10B981), shape: BoxShape.circle)),
            SizedBox(width: 8.w),
            Text(
              'QR Code Info',
              style:
                  AppTypography.small.copyWith(color: const Color(0xFF0F172A)),
            ),
            SizedBox(width: 6.w),
            Icon(Icons.lock_outline,
                size: 14.sp, color: const Color(0xFF64748B)),
          ],
        ),
        SizedBox(height: 8.h),
        Text(
          'This QR code is used for scanning attendance at QR scanner devices located throughout the campus.',
          style: AppTypography.caption
              .copyWith(color: const Color(0xFF64748B), height: 1.5),
        ),
        SizedBox(height: 16.h),
        _buildInfoBulletPoint(
            'Each user has a unique, permanent QR code tied to their account.'),
        SizedBox(height: 12.h),
        _buildInfoBulletPoint(
            'The QR is valid at any active scanner the user\'s role is allowed on.'),
        SizedBox(height: 12.h),
        _buildInfoBulletPoint(
            'Admins can regenerate the QR if it is lost or compromised.'),
        SizedBox(height: 12.h),
        _buildInfoBulletPoint(
            'GPS geofencing is enforced by the scanner device, not the QR code itself.'),
      ],
    );
  }

  Widget _buildInfoBulletPoint(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle_outline,
            color: const Color(0xFF0284C7), size: 18.sp),
        SizedBox(width: 10.w),
        Expanded(
          child: Text(
            text,
            style: AppTypography.caption
                .copyWith(color: const Color(0xFF475569), height: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoutDialog() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 40.w),
          padding: EdgeInsets.all(24.r),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Logout',
                  style: AppTypography.h4
                      .copyWith(color: const Color(0xFF0F172A))),
              SizedBox(height: 16.h),
              Text('Are you sure you want to log out?',
                  style: AppTypography.small
                      .copyWith(color: const Color(0xFF475569))),
              SizedBox(height: 24.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: () => setState(() => _showLogout = false),
                      child: Text('Cancel',
                          style: GoogleFonts.inter(
                              color: const Color(0xFF64748B)))),
                  SizedBox(width: 16.w),
                  ElevatedButton(
                    onPressed: () async {
                      setState(() => _showLogout = false);
                      await AuthService.logout(context);
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444)),
                    child: Text('Logout',
                        style: GoogleFonts.inter(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChangePasswordSheet() {
    final currentPasswordCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();
    bool showCurrent = false;
    bool showNew = false;
    bool showConfirm = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          padding: EdgeInsets.fromLTRB(20.r, 20.r, 20.r,
              MediaQuery.of(context).viewInsets.bottom + 20.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2.r))),
              ),
              SizedBox(height: 20.h),
              Text('Change Password',
                  style: AppTypography.bodyLarge
                      .copyWith(color: const Color(0xFF0F172A))),
              SizedBox(height: 20.h),
              _buildPasswordField('Current Password', currentPasswordCtrl,
                  showCurrent, (val) => setSheetState(() => showCurrent = val)),
              SizedBox(height: 12.h),
              _buildPasswordField('New Password', newPasswordCtrl, showNew,
                  (val) => setSheetState(() => showNew = val)),
              SizedBox(height: 12.h),
              _buildPasswordField('Confirm Password', confirmPasswordCtrl,
                  showConfirm, (val) => setSheetState(() => showConfirm = val)),
              SizedBox(height: 24.h),
              LoadingButton(
                label: 'Update Password',
                color: const Color(0xFF6366F1),
                onPressed: () async {
                  if (currentPasswordCtrl.text.isEmpty ||
                      newPasswordCtrl.text.isEmpty ||
                      confirmPasswordCtrl.text.isEmpty) {
                    showToast(context, 'All fields are required',
                        isError: true);
                    return;
                  }
                  if (newPasswordCtrl.text != confirmPasswordCtrl.text) {
                    showToast(context, 'Passwords do not match', isError: true);
                    return;
                  }
                  final prefs = await SharedPreferences.getInstance();
                  final dateStr =
                      '${DateTime.now().day} ${_getMonth(DateTime.now().month)} ${DateTime.now().year}';
                  if (widget.role == 'teacher') {
                    await prefs.setString('teacher_last_pwd', dateStr);
                  } else {
                    await prefs.setString('student_last_pwd', dateStr);
                  }
                  await _loadProfileData();
                  if (context.mounted) {
                    Navigator.pop(context);
                    showToast(context, 'Password updated successfully!');
                  }
                },
              ),
              SizedBox(height: 12.h),
            ],
          ),
        ),
      ),
    );
  }

  String _getMonth(int m) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[m - 1];
  }

  Widget _buildPasswordField(String label, TextEditingController ctrl,
      bool show, Function(bool) onToggle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                AppTypography.caption.copyWith(color: const Color(0xFF64748B))),
        SizedBox(height: 6.h),
        TextFormField(
          controller: ctrl,
          obscureText: !show,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide: BorderSide.none),
            prefixIcon: const Icon(Icons.lock_outline, size: 16),
            suffixIcon: IconButton(
              icon: Icon(
                  show
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 16),
              onPressed: () => onToggle(!show),
            ),
            contentPadding: EdgeInsets.all(12.r),
          ),
        ),
      ],
    );
  }

  void _showEditProfileSheet() {
    // Inline detail editor controllers
    final nameCtrl = TextEditingController(text: _userName);
    final emailCtrl = TextEditingController(text: _email);
    final phoneCtrl = TextEditingController(text: _phone);
    final genderCtrl = TextEditingController(text: _gender);
    final dobCtrl = TextEditingController(text: _dob);
    final bloodCtrl = TextEditingController(text: _bloodGroup);
    final addressCtrl = TextEditingController(text: _address);

    final empIdCtrl = TextEditingController(text: _employeeId);
    final designCtrl = TextEditingController(text: _designation);
    final deptCtrl = TextEditingController(text: _department);
    final expCtrl = TextEditingController(text: _experience);

    final rollCtrl = TextEditingController(text: _rollNumber);
    final classCtrl = TextEditingController(text: _className);
    final admissionCtrl = TextEditingController(text: _admissionId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        padding: EdgeInsets.fromLTRB(
            20.r, 20.r, 20.r, MediaQuery.of(context).viewInsets.bottom + 20.r),
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2.r))),
                ),
                SizedBox(height: 20.h),
                Text('Edit Profile Details',
                    style: AppTypography.bodyLarge
                        .copyWith(color: const Color(0xFF0F172A))),
                SizedBox(height: 20.h),
                _buildEditField('Full Name', nameCtrl),
                SizedBox(height: 12.h),
                _buildEditField('Email', emailCtrl),
                SizedBox(height: 12.h),
                _buildEditField('Phone', phoneCtrl),
                SizedBox(height: 12.h),
                _buildEditField('Gender', genderCtrl),
                SizedBox(height: 12.h),
                _buildEditField('Date of Birth', dobCtrl),
                SizedBox(height: 12.h),
                _buildEditField('Blood Group', bloodCtrl),
                SizedBox(height: 12.h),
                _buildEditField('Address', addressCtrl, maxLines: 2),
                SizedBox(height: 12.h),
                if (widget.role == 'teacher') ...[
                  _buildEditField('Employee ID', empIdCtrl),
                  SizedBox(height: 12.h),
                  _buildEditField('Designation', designCtrl),
                  SizedBox(height: 12.h),
                  _buildEditField('Department', deptCtrl),
                  SizedBox(height: 12.h),
                  _buildEditField('Experience', expCtrl),
                ] else ...[
                  _buildEditField('Roll Number', rollCtrl),
                  SizedBox(height: 12.h),
                  _buildEditField('Class & Section', classCtrl),
                  SizedBox(height: 12.h),
                  _buildEditField('Admission ID', admissionCtrl),
                ],
                SizedBox(height: 24.h),
                LoadingButton(
                  label: 'Save Changes',
                  color: widget.theme.primary,
                  onPressed: () async {
                    final data = {
                      'name': nameCtrl.text.trim(),
                      'email': emailCtrl.text.trim(),
                      'phone': phoneCtrl.text.trim(),
                      'gender': genderCtrl.text.trim(),
                      'dob': dobCtrl.text.trim(),
                      'bloodGroup': bloodCtrl.text.trim(),
                      'address': addressCtrl.text.trim(),
                      if (widget.role == 'teacher') ...{
                        'employeeId': empIdCtrl.text.trim(),
                        'designation': designCtrl.text.trim(),
                        'department': deptCtrl.text.trim(),
                        'experience': expCtrl.text.trim(),
                      } else ...{
                        'rollNumber': rollCtrl.text.trim(),
                        'className': classCtrl.text.trim(),
                        'admissionId': admissionCtrl.text.trim(),
                      }
                    };
                    Navigator.pop(context);
                    await _saveProfileEdits(data);
                  },
                ),
                SizedBox(height: 12.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditField(String label, TextEditingController ctrl,
      {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                AppTypography.caption.copyWith(color: const Color(0xFF64748B))),
        SizedBox(height: 6.h),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide: BorderSide.none),
            contentPadding: EdgeInsets.all(12.r),
          ),
        ),
      ],
    );
  }
}

// ── CUSTOM STYLIZED QR CODE WIDGET ──
class StylizedQrCode extends StatelessWidget {
  final double size;
  final Color color;

  const StylizedQrCode({super.key, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: Colors.white,
      padding: EdgeInsets.all(8.r),
      child: CustomPaint(
        size: Size(size - 16.r, size - 16.r),
        painter: QrPainter(color: color),
      ),
    );
  }
}

class QrPainter extends CustomPainter {
  final Color color;

  QrPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final double width = size.width;
    const int modulesCount = 19; // 19x19 grid
    final double moduleSize = width / modulesCount;

    // Draw locator patterns (7x7 modules)
    void drawLocator(double dx, double dy) {
      // Outer 7x7 module square
      canvas.drawRect(
          Rect.fromLTWH(dx, dy, moduleSize * 7, moduleSize * 7), paint);
      // Inner 5x5 module white square
      final whitePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawRect(
          Rect.fromLTWH(
              dx + moduleSize, dy + moduleSize, moduleSize * 5, moduleSize * 5),
          whitePaint);
      // Center 3x3 module square
      canvas.drawRect(
          Rect.fromLTWH(dx + moduleSize * 2, dy + moduleSize * 2,
              moduleSize * 3, moduleSize * 3),
          paint);
    }

    // Top-left locator
    drawLocator(0, 0);
    // Top-right locator
    drawLocator((modulesCount - 7) * moduleSize, 0);
    // Bottom-left locator
    drawLocator(0, (modulesCount - 7) * moduleSize);

    // Draw pseudo-random noise for the rest of the QR grid (seeded to keep it static per paint run)
    final random = Random(12345);
    for (int r = 0; r < modulesCount; r++) {
      for (int c = 0; c < modulesCount; c++) {
        // Skip locator pattern regions (7x7 zones in corners)
        if ((r < 8 && c < 8) ||
            (r < 8 && c >= modulesCount - 8) ||
            (r >= modulesCount - 8 && c < 8)) {
          continue;
        }
        // Draw random module block with 50% probability
        if (random.nextBool()) {
          canvas.drawRect(
            Rect.fromLTWH(
                c * moduleSize, r * moduleSize, moduleSize, moduleSize),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double dashLength;
  final double borderRadius;

  DashedRectPainter({
    this.color = const Color(0xFFCBD5E1),
    this.strokeWidth = 1.0,
    this.gap = 4.0,
    this.dashLength = 6.0,
    this.borderRadius = 16.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    ));

    final dashedPath = Path();
    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      bool draw = true;
      while (distance < metric.length) {
        final length = draw ? dashLength : gap;
        if (draw) {
          dashedPath.addPath(
            metric.extractPath(distance, min(distance + length, metric.length)),
            Offset.zero,
          );
        }
        distance += length;
        draw = !draw;
      }
    }

    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant DashedRectPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.gap != gap ||
        oldDelegate.dashLength != dashLength ||
        oldDelegate.borderRadius != borderRadius;
  }
}
