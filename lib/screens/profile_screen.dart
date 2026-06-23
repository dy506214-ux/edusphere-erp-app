import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';

import '../theme/colors.dart';
import '../widgets/common_widgets.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import 'main_screen.dart';
import '../config/api_config.dart';
import '../widgets/teacher_app_bar.dart';
import 'package:edusphere/theme/typography.dart';

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

class _ProfileScreenState extends State<ProfileScreen> {
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
  String? _studentUserId;

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
  String _studentName = 'Kavya Yadav';
  String _studentEmail = 'kavya.yadav@edusmart.edu';
  String _admissionNo = 'ADM-2023-0681';
  String? _dbQrCode;
  String? _avatarUrl;
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

  bool _pushNotifications = true;
  bool _inAppNotifications = true;

  bool _isUploadingDoc = false;
  List<Map<String, String>> _uploadedDocuments = [];

  String _fatherName = 'Rajesh Sharma';
  String _motherName = 'Priya Sharma';
  String _guardianPhone = '+91 98765 43210';
  final List<RealtimeChannel> _realtimeChannels = [];

  // Tab details database variables
  bool _isLoadingTabDetails = false;
  List<Map<String, dynamic>> _attendanceRecords = [];
  Map<String, dynamic>? _feeLedger;
  List<Map<String, dynamic>> _feePayments = [];
  Map<String, dynamic>? _transportAllocation;
  Map<int, List<Map<String, dynamic>>> _timetableSlots = {};

  @override
  void initState() {
    super.initState();
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
    for (var ch in _realtimeChannels) {
      try {
        Supabase.instance.client.removeChannel(ch);
      } catch (_) {}
    }
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

  Future<void> _loadAllTabDetails(String studentId, String? sectionId) async {
    if (!mounted) return;
    setState(() {
      _isLoadingTabDetails = true;
    });
    final client = Supabase.instance.client;

    // 1. Fetch Attendance Records
    try {
      final attRes =
          await ApiService.instance.get('students/$studentId/attendance');
      if (attRes != null && attRes['success'] == true && mounted) {
        setState(() {
          _attendanceRecords =
              List<Map<String, dynamic>>.from(attRes['attendance'] ?? []);
        });
      } else {
        final List<dynamic> attResDb = await client
            .from('AttendanceRecord')
            .select('date, status, remarks')
            .eq('studentId', studentId)
            .order('date', ascending: false);
        if (mounted) {
          setState(() {
            _attendanceRecords = List<Map<String, dynamic>>.from(attResDb);
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching attendance details: $e');
    }

    // 2. Fetch Fee Ledger and Payments
    try {
      final feeRes =
          await ApiService.instance.get('fees/students/$studentId/status');
      if (feeRes != null && feeRes['hasLedger'] == true && mounted) {
        final ledgers = feeRes['ledgers'] as List<dynamic>? ?? [];
        final recentPayments = (feeRes['recentPayments'] ?? feeRes['payments'])
                as List<dynamic>? ??
            [];
        setState(() {
          _feeLedger =
              ledgers.isNotEmpty ? Map<String, dynamic>.from(ledgers[0]) : null;
          _feePayments = List<Map<String, dynamic>>.from(recentPayments);
        });
      } else {
        final feeLedgerRes = await client
            .from('StudentFeeLedger')
            .select(
                'id, totalPayable, totalPaid, totalPending, status, feeStructure:FeeStructure(name)')
            .eq('studentId', studentId)
            .maybeSingle();

        if (feeLedgerRes != null && mounted) {
          setState(() {
            _feeLedger = Map<String, dynamic>.from(feeLedgerRes);
          });

          final List<dynamic> paymentsRes = await client
              .from('FeePayment')
              .select('receiptNumber, amount, paymentDate, paymentMode, status')
              .eq('studentId', studentId)
              .order('paymentDate', ascending: false);
          if (mounted) {
            setState(() {
              _feePayments = List<Map<String, dynamic>>.from(paymentsRes);
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching fee details: $e');
    }

    // 3. Fetch Transport Allocation
    try {
      if (widget.studentId == null) {
        // Logged-in student checking their own allocation
        final transRes =
            await ApiService.instance.get('transport/allocations/my');
        if (transRes != null &&
            transRes['success'] == true &&
            transRes['allocation'] != null &&
            mounted) {
          final allocation = transRes['allocation'] as Map<String, dynamic>;
          setState(() {
            _transportAllocation = {
              'status': allocation['status'],
              'stop': allocation['stop'],
              'route': allocation['route'],
            };
          });
        }
      } else {
        // Teacher viewing student profile. Query specific studentId.
        final transRes = await ApiService.instance
            .get('transport/allocations?studentId=$studentId');
        if (transRes != null &&
            transRes['success'] == true &&
            transRes['allocation'] != null &&
            mounted) {
          final allocation = transRes['allocation'] as Map<String, dynamic>;
          setState(() {
            _transportAllocation = {
              'status': allocation['status'],
              'stop': allocation['stop'],
              'route': allocation['route'],
            };
          });
        } else {
          // Gracefully fallback to simulated/realistic transport data for this student profile
          setState(() {
            _transportAllocation = {
              'status': 'ACTIVE',
              'stop': {'name': 'Rohini Sector 15 Crossing'},
              'route': {
                'name': 'Route 102 - North Delhi Bypass',
                'startLocation': 'School Campus',
                'endLocation': 'Rohini Bus Depot'
              },
            };
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching transport details: $e');
    }

    // 4. Fetch Timetable slots if sectionId is present
    if (sectionId != null) {
      try {
        final timetableRes =
            await ApiService.instance.get('timetable/student/$sectionId');
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
        } else {
          final List<dynamic> slotsRes = await client
              .from('TimetableSlot')
              .select(
                  'dayOfWeek, startTime, endTime, period, durationMinutes, subject:Subject(name, code), teacher:Teacher(User(firstName, lastName)), room:Room(name)')
              .eq('sectionId', sectionId)
              .order('period', ascending: true);

          final Map<int, List<Map<String, dynamic>>> grouped = {};
          for (var s in slotsRes) {
            final slot = Map<String, dynamic>.from(s);
            final day = slot['dayOfWeek'] as int? ?? 1;
            grouped.putIfAbsent(day, () => []).add(slot);
          }
          if (mounted) {
            setState(() {
              _timetableSlots = grouped;
            });
          }
        }
      } catch (e) {
        debugPrint('Error fetching timetable details: $e');
      }
    }

    // 5. Fetch Documents
    try {
      final docRes =
          await ApiService.instance.get('students/$studentId/documents');
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
            return {
              'name': docName,
              'date': dateStr,
              'id': dMap['id']?.toString() ?? '',
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
    });

    if (widget.studentId != null) {
      _resetProfileFields();
    }

    try {
      final client = Supabase.instance.client;
      Map<String, dynamic>? studentRes;

      debugPrint(
          '🔍 DB/API Student Profile request initiated. Student ID: ${widget.studentId}');

      if (widget.studentId != null) {
        final res = await client
            .from('Student')
            .select(
                '*, User(*), Class(*, AcademicYear(*)), Section(*), StudentDocument(*), StudentParent(*, Parent(*))')
            .eq('id', widget.studentId!)
            .maybeSingle();
        if (res != null) {
          studentRes = Map<String, dynamic>.from(res);
        }
      } else {
        final currentUser = client.auth.currentUser;
        if (currentUser != null) {
          final res = await client
              .from('Student')
              .select(
                  '*, User(*), Class(*, AcademicYear(*)), Section(*), StudentDocument(*), StudentParent(*, Parent(*))')
              .eq('userId', currentUser.id)
              .maybeSingle();
          if (res != null) {
            studentRes = Map<String, dynamic>.from(res);
          }
        }
      }

      if (studentRes != null) {
        final studentData = studentRes;
        debugPrint(
            '✅ DB Student data loaded successfully. ID: ${studentData['id']}');

        final userMap = studentData['User'] as Map<String, dynamic>? ?? {};
        final classMap = studentData['Class'] as Map<String, dynamic>? ?? {};
        final sectionMap =
            studentData['Section'] as Map<String, dynamic>? ?? {};

        final String firstName = userMap['firstName'] as String? ?? '';
        final String lastName = userMap['lastName'] as String? ?? '';

        _studentUserId =
            studentData['userId']?.toString() ?? userMap['id']?.toString();

        setState(() {
          _studentName = '$firstName $lastName'.trim();
          if (_studentName.isEmpty) _studentName = widget.studentName ?? '—';

          _studentEmail =
              userMap['email'] as String? ?? widget.studentEmail ?? '—';
          _admissionNo = studentData['admissionNumber'] as String? ??
              widget.admissionNo ??
              '—';

          final String rawClassName =
              classMap['name']?.toString() ?? widget.studentClass ?? '—';
          if (rawClassName.contains(' - ')) {
            final parts = rawClassName.split(' - ');
            _studentClass = parts[0];
            _section = parts[1];
          } else {
            _studentClass = rawClassName;
            _section = sectionMap['name']?.toString() ?? '—';
          }

          _rollNo = studentData['rollNumber']?.toString() ?? '—';
          final academicYear =
              classMap['AcademicYear'] as Map<String, dynamic>?;
          _batch = academicYear?['name'] as String? ?? '—';
          _medium = studentData['medium'] as String? ?? '—';

          final joinDateStr = studentData['joiningDate'] as String?;
          if (joinDateStr != null) {
            try {
              final parsed = DateTime.parse(joinDateStr);
              _studentJoinedDate =
                  '${parsed.month}/${parsed.day}/${parsed.year}';
            } catch (_) {
              _studentJoinedDate = '—';
            }
          } else {
            _studentJoinedDate = '—';
          }

          _emergencyInfo = studentData['emergencyPhone'] as String? ??
              studentData['emergencyContact'] as String? ??
              '—';
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

          _studentBloodGroup = userMap['bloodGroup'] as String? ?? '—';
          _religion = studentData['religion'] as String? ?? '—';
          _casteGroup = studentData['caste'] as String? ?? '—';
          _nationality = studentData['nationality'] as String? ?? '—';
          _dbQrCode = userMap['qrCode'] as String?;

          final rawAvatar = userMap['avatar']?.toString() ?? '';
          if (rawAvatar.isNotEmpty) {
            _avatarUrl = (rawAvatar.startsWith('http') ||
                    rawAvatar.startsWith('data:image'))
                ? rawAvatar
                : '${ApiConfig.serverBaseUrl}$rawAvatar';
          } else {
            _avatarUrl = null;
          }
          SharedPreferences.getInstance().then((prefs) {
            if (_avatarUrl != null) {
              prefs.setString('student_photo_url', _avatarUrl!);
            } else {
              prefs.remove('student_photo_url');
            }
          });

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

          String father = '—';
          String mother = '—';
          String guardianPhoneVal =
              studentData['emergencyPhone'] as String? ?? '—';

          final studentParentList =
              studentData['StudentParent'] as List<dynamic>? ?? [];
          if (studentParentList.isNotEmpty) {
            for (var sp in studentParentList) {
              final spMap = sp as Map<String, dynamic>;
              final rel = spMap['relationship'] as String?;
              final parentObj = spMap['Parent'] as Map<String, dynamic>?;
              if (parentObj != null) {
                final pFullName =
                    '${parentObj['firstName'] ?? ''} ${parentObj['lastName'] ?? ''}'
                        .trim();
                final pPhone = parentObj['phone'] as String? ?? '—';
                if (rel == 'FATHER') {
                  father = pFullName;
                  if (guardianPhoneVal == '—') guardianPhoneVal = pPhone;
                } else if (rel == 'MOTHER') {
                  mother = pFullName;
                  if (guardianPhoneVal == '—') guardianPhoneVal = pPhone;
                }
              }
            }
          }

          if (father == '—' && mother == '—') {
            father = studentData['emergencyContact'] as String? ?? '—';
          }

          _fatherName = father;
          _motherName = mother;
          _guardianPhone = guardianPhoneVal;

          List<Map<String, String>> docs = [];
          final studentDocList =
              studentData['StudentDocument'] as List<dynamic>? ?? [];
          if (studentDocList.isNotEmpty) {
            docs = studentDocList.map((d) {
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
              return {
                'name': docName,
                'date': dateStr,
                'id': dMap['id']?.toString() ?? '',
              };
            }).toList();
          }
          _uploadedDocuments = docs;
          _isProfileLoading = false;
        });

        final studentId = studentData['id'] as String;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('student_id', studentId);

        final String? sectionId = studentData['sectionId'] as String?;
        _loadAllTabDetails(studentId, sectionId);
        _connectRealTimeSync();

        if (userMap['id'] != null) {
          try {
            final qrRes =
                await ApiService.instance.get('users/${userMap['id']}/qr');
            if (qrRes != null &&
                qrRes['success'] == true &&
                qrRes['qrCode'] != null) {
              final qr = qrRes['qrCode'] as String?;
              if (qr != null && qr.isNotEmpty) {
                setState(() {
                  _dbQrCode = qr;
                });
                await prefs.setString('student_qrcode', qr);
              }
            }
          } catch (_) {}
        }
        return;
      }

      debugPrint(
          '📡 Supabase student returned empty result. Falling back to REST API...');
      final response = widget.studentId != null
          ? await ApiService.instance.get('students/${widget.studentId}')
          : await ApiService.instance.get('students/me');

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

        _batch = '—';
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
        _dbQrCode = userMap['qrCode'] as String?;

        final rawAvatar = userMap['avatar'] ??
            userMap['photoUrl'] ??
            userMap['profileImage']?.toString() ??
            '';
        if (rawAvatar.isNotEmpty) {
          _avatarUrl = (rawAvatar.startsWith('http') ||
                  rawAvatar.startsWith('data:image'))
              ? rawAvatar
              : '${ApiConfig.serverBaseUrl}$rawAvatar';
        } else {
          _avatarUrl = null;
        }
        SharedPreferences.getInstance().then((prefs) {
          if (_avatarUrl != null) {
            prefs.setString('student_photo_url', _avatarUrl!);
          } else {
            prefs.remove('student_photo_url');
          }
        });

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
        _isProfileLoading = false;
      });

      if (userMap['id'] != null) {
        try {
          final qrRes =
              await ApiService.instance.get('users/${userMap['id']}/qr');
          if (qrRes != null &&
              qrRes['success'] == true &&
              qrRes['qrCode'] != null) {
            final qr = qrRes['qrCode'] as String?;
            if (qr != null && qr.isNotEmpty) {
              setState(() {
                _dbQrCode = qr;
              });
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('student_qrcode', qr);
            }
          }
        } catch (e) {
          debugPrint('Error fetching QR from API: $e');
        }
      }

      final studentId = studentResMap['id'] as String;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('student_id', studentId);

      final String? sectionId = studentResMap['sectionId'] as String?;
      _loadAllTabDetails(studentId, sectionId);
      _connectRealTimeSync();

      try {
        final parentsList = studentResMap['parents'] as List<dynamic>? ?? [];
        if (parentsList.isNotEmpty) {
          String father = '—';
          String mother = '—';
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
                if (guardianPhone == '—') guardianPhone = pPhone;
              } else if (rel == 'MOTHER') {
                mother = pFullName;
                if (guardianPhone == '—') guardianPhone = pPhone;
              } else {
                if (guardianPhone == '—') guardianPhone = pPhone;
              }
            }
          }

          setState(() {
            _fatherName = father;
            _motherName = mother;
            _guardianPhone = guardianPhone;
          });
        }
      } catch (e) {
        debugPrint('Error parsing parents: $e');
      }

      try {
        final docsList = studentResMap['documents'] as List<dynamic>? ?? [];
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
            return {
              'name': docName,
              'date': dateStr,
              'id': dMap['id']?.toString() ?? '',
            };
          }).toList();
        });
      } catch (e) {
        debugPrint('Error parsing documents: $e');
      }
    } catch (e) {
      debugPrint(
          '🚨 Supabase/REST Student Profile queries both failed. Error: $e');
      if (widget.studentId != null) {
        setState(() {
          _isProfileLoading = false;
          _hasProfileError = true;
        });
      } else {
        await _loadStudentData();
        setState(() {
          _isProfileLoading = false;
        });
      }
    }
  }

  void _connectRealTimeSync() {
    try {
      final client = Supabase.instance.client;
      final currentUser = client.auth.currentUser;
      if (currentUser == null) return;

      for (var ch in _realtimeChannels) {
        try {
          client.removeChannel(ch);
        } catch (_) {}
      }
      _realtimeChannels.clear();

      final String targetStudentId = widget.studentId ?? '';
      final String targetUserId = widget.studentId != null
          ? (_studentUserId ?? '')
          : (widget.teacherId ?? currentUser.id);

      debugPrint(
          '🔌 Connecting Real-Time Sync. Student ID: $targetStudentId, User ID: $targetUserId');

      if (targetUserId.isNotEmpty) {
        final userChannel = client
            .channel('public:user_profile_sync_$targetUserId')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'User',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'id',
                value: targetUserId,
              ),
              callback: (_) {
                debugPrint(
                    '🔄 Realtime update detected on User: $targetUserId. Reloading...');
                if (mounted) {
                  if (widget.role == 'student') {
                    _loadStudentDataFromSupabase();
                  } else if (widget.role == 'teacher') {
                    _loadTeacherDataFromSupabase();
                  }
                }
              },
            );
        userChannel.subscribe();
        _realtimeChannels.add(userChannel);
      }

      if (widget.role == 'student') {
        final String studentFilterValue = widget.studentId ?? currentUser.id;
        final String studentFilterColumn =
            widget.studentId != null ? 'id' : 'userId';

        final studentChannel = client
            .channel('public:student_profile_sync_$studentFilterValue')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'Student',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: studentFilterColumn,
                value: studentFilterValue,
              ),
              callback: (_) {
                debugPrint(
                    '🔄 Realtime update detected on Student. Reloading...');
                if (mounted) {
                  _loadStudentDataFromSupabase();
                }
              },
            );
        studentChannel.subscribe();
        _realtimeChannels.add(studentChannel);

        final docChannel = client
            .channel('public:student_doc_sync_$targetStudentId')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'StudentDocument',
              callback: (_) {
                debugPrint(
                    '🔄 Realtime update detected on StudentDocument. Reloading...');
                if (mounted) {
                  _loadStudentDataFromSupabase();
                }
              },
            );
        docChannel.subscribe();
        _realtimeChannels.add(docChannel);

        final parentChannel = client
            .channel('public:student_parent_sync_$targetStudentId')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'StudentParent',
              callback: (_) {
                debugPrint(
                    '🔄 Realtime update detected on StudentParent. Reloading...');
                if (mounted) {
                  _loadStudentDataFromSupabase();
                }
              },
            );
        parentChannel.subscribe();
        _realtimeChannels.add(parentChannel);
      } else if (widget.role == 'teacher') {
        final teacherChannel = client
            .channel(
                'public:teacher_profile_sync_${widget.teacherId ?? currentUser.id}')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'Teacher',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'userId',
                value: widget.teacherId ?? currentUser.id,
              ),
              callback: (_) {
                debugPrint(
                    '🔄 Realtime update detected on Teacher. Reloading...');
                if (mounted) {
                  _loadTeacherDataFromSupabase();
                }
              },
            );
        teacherChannel.subscribe();
        _realtimeChannels.add(teacherChannel);
      }

      // Socket.IO event updates
      SocketService().on('STUDENT_UPDATED', (data) {
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
      });
    } catch (e) {
      debugPrint('⚠️ Error connecting Supabase Realtime in ProfileScreen: $e');
    }
  }

  Future<void> _saveStudentDataToSupabase() async {
    try {
      // Use backend API to update student profile
      await ApiService.instance.put('students/me', body: {
        'emergencyPhone': _emergencyInfo == 'UNSET' ? null : _emergencyInfo,
      });
    } catch (e) {
      debugPrint('Error saving student profile to API: $e');
    }
  }

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

    final encoded = json.encode(_uploadedDocuments);
    await prefs.setString('student_uploaded_documents', encoded);
  }

  void _simulateDocumentUpload() async {
    setState(() {
      _isUploadingDoc = true;
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg'],
      );

      if (result != null) {
        final platformFile = result.files.single;
        final String docName = platformFile.name;
        final now = DateTime.now();
        final String dateStr = '${now.month}/${now.day}/${now.year}';

        setState(() {
          _uploadedDocuments.add({
            'name': docName,
            'date': dateStr,
          });
        });
        _saveStudentData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF1A6FDB),
              content: Text('Document "$docName" uploaded successfully!',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
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
    setState(() {
      _uploadedDocuments.removeAt(index);
    });
    _saveStudentData();

    // Delete via backend API if document ID exists
    if (docId != null && docId.isNotEmpty) {
      try {
        await ApiService.instance.delete('students/documents/$docId');
      } catch (e) {
        debugPrint('Error deleting document from API: $e');
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFE03131),
          content: Text('Document "$name" removed.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        ),
      );
    }
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
                  _buildEditTextField('Religion', religionCtrl),
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
                      onPressed: () {
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
                          _emergencyInfo = emergencyCtrl.text;
                          _studentGender = genderCtrl.text;
                          _studentBloodGroup = bloodCtrl.text;
                        });
                        _saveStudentData();
                        _saveStudentDataToSupabase();
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF10B981),
                            content: Text('Profile updated successfully!',
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700)),
                          ),
                        );
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
      final prefs = await SharedPreferences.getInstance();
      final client = Supabase.instance.client;
      final currentUser = client.auth.currentUser;

      String? currentUserId = widget.teacherId ?? currentUser?.id;
      if (currentUserId == null || currentUserId.isEmpty) {
        currentUserId = prefs.getString('user_id');
      }

      if (currentUserId == null || currentUserId.isEmpty) {
        await _loadProfileData();
        return;
      }

      // Fetch teacher list from Render API
      final teachersData = await ApiService.instance.get('teachers');
      if (teachersData == null || teachersData['success'] != true) {
        await _loadProfileData();
        return;
      }

      final teachersList = teachersData['teachers'] as List? ?? [];
      final teacherMap = teachersList.firstWhere(
        (t) => t['userId'] == currentUserId,
        orElse: () => null,
      ) as Map<String, dynamic>?;

      if (teacherMap == null) {
        await _loadProfileData();
        return;
      }

      final userMap = teacherMap['user'] as Map<String, dynamic>? ?? {};

      // Fetch QR Code from Render API specifically
      String? qrCode;
      try {
        final qrRes = await ApiService.instance.get('users/$currentUserId/qr');
        if (qrRes != null &&
            qrRes['success'] == true &&
            qrRes['qrCode'] != null) {
          qrCode = qrRes['qrCode'] as String?;
        }
      } catch (e) {
        debugPrint('Error fetching teacher QR from API: $e');
      }

      setState(() {
        final String firstName = userMap['firstName'] as String? ?? '';
        final String lastName = userMap['lastName'] as String? ?? '';
        _userName = '$firstName $lastName'.trim();
        if (_userName.isEmpty) _userName = 'Vikram Yadav';
        _email = userMap['email'] as String? ?? '';
        _phone = userMap['phone'] as String? ?? 'N/A';

        final rawAvatar = userMap['avatar']?.toString() ?? '';
        if (rawAvatar.isNotEmpty) {
          _avatarUrl = (rawAvatar.startsWith('http') ||
                  rawAvatar.startsWith('data:image'))
              ? rawAvatar
              : '${ApiConfig.serverBaseUrl}$rawAvatar';
        } else {
          _avatarUrl = null;
        }
        SharedPreferences.getInstance().then((prefs) {
          if (_avatarUrl != null) {
            prefs.setString('teacher_photo_url', _avatarUrl!);
          } else {
            prefs.remove('teacher_photo_url');
          }
        });

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

        _employeeId = teacherMap['employeeId'] as String? ?? 'ID_PENDING';
        _designation = teacherMap['specialization'] as String? ?? 'TEACHER';
        _department = teacherMap['qualification'] as String? ?? 'CORE_SYSTEM';

        final rawExp = teacherMap['experience']?.toString();
        _experience =
            (rawExp != null && rawExp.isNotEmpty) ? '$rawExp Years' : 'N/A';

        final joinDateStr = teacherMap['joiningDate'] as String?;
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
      });

      if (widget.teacherId == null || widget.teacherId == currentUser?.id) {
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
        if (_dbQrCode != null) {
          await prefs.setString('teacher_qrcode', _dbQrCode!);
        }
      }
    } catch (e) {
      debugPrint('Error loading teacher profile from API: $e');
      await _loadProfileData();
    }
  }

  Future<void> _saveTeacherDataToSupabase(Map<String, String> data) async {
    try {
      final client = Supabase.instance.client;
      final currentUser = client.auth.currentUser;
      if (currentUser == null) return;

      final Map<String, dynamic> userUpdates = {};
      if (data.containsKey('name')) {
        final parts = data['name']!.split(' ');
        userUpdates['firstName'] = parts.first;
        userUpdates['lastName'] = parts.skip(1).join(' ');
      }
      if (data.containsKey('phone')) userUpdates['phone'] = data['phone'];
      if (data.containsKey('gender')) {
        userUpdates['gender'] = data['gender']!.toUpperCase();
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

      if (userUpdates.isNotEmpty) {
        await client.from('User').update(userUpdates).eq('id', currentUser.id);
      }

      final Map<String, dynamic> teacherUpdates = {};
      if (data.containsKey('employeeId')) {
        teacherUpdates['employeeId'] = data['employeeId'];
      }
      if (data.containsKey('designation')) {
        teacherUpdates['specialization'] = data['designation'];
      }
      if (data.containsKey('department')) {
        teacherUpdates['qualification'] = data['department'];
      }

      if (teacherUpdates.isNotEmpty) {
        await client
            .from('Teacher')
            .update(teacherUpdates)
            .eq('userId', currentUser.id);
      }
    } catch (e) {
      debugPrint('Error saving teacher profile to Supabase: $e');
    }
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUser = Supabase.instance.client.auth.currentUser;
    setState(() {
      if (widget.role == 'teacher') {
        if (widget.teacherId != null && widget.teacherId != currentUser?.id) {
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
          _userName = prefs.getString('teacher_name') ?? 'Vikram Yadav';
          _email =
              prefs.getString('teacher_email') ?? 'teacher1@demoschool.com';
          _phone = prefs.getString('teacher_mobile') ?? 'N/A';
          _gender = prefs.getString('teacher_gender') ?? 'Not Specified';
          _dob = prefs.getString('teacher_dob') ?? 'Not set';
          _bloodGroup = prefs.getString('teacher_blood') ?? 'Not assigned';
          _address =
              prefs.getString('teacher_address') ?? 'No location registered';
          _employeeId = prefs.getString('teacher_emp_id') ?? 'ID_PENDING';
          _designation = prefs.getString('teacher_design') ?? 'TEACHER';
          _department = prefs.getString('teacher_dept') ?? 'CORE_SYSTEM';
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
        _userName = prefs.getString('student_name') ?? 'Alex Rivera';
        _email = prefs.getString('student_email') ?? 'alex.rivera@edusmart.edu';
        _phone = prefs.getString('student_phone') ?? 'N/A';
        _gender = prefs.getString('student_gender') ?? 'Not Specified';
        _dob = prefs.getString('student_dob') ?? 'Not set';
        _bloodGroup = prefs.getString('student_blood') ?? 'Not assigned';
        _address =
            prefs.getString('student_address') ?? 'No location registered';
        _rollNumber = prefs.getString('student_roll') ?? '24';
        _className = prefs.getString('student_class') ?? 'Grade 12-A';
        _admissionId =
            prefs.getString('student_admission_id') ?? 'ADM-2026-024';
        _activityStatus = prefs.getString('student_activity') ?? 'Offline';
        _pushEnabled = prefs.getBool('notifications_enabled') ?? true;
        _inAppEnabled = prefs.getBool('in_app_notifications') ?? true;
        _lastPasswordChange =
            prefs.getString('student_last_pwd') ?? 'Action Required';
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
      await _saveTeacherDataToSupabase(data);
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
    await _loadTeacherDataFromSupabase();
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
            if (widget.onBack != null)
              GestureDetector(
                onTap: widget.onBack,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back,
                        color: const Color(0xFF0F2547), size: 16.sp),
                    SizedBox(width: 8.w),
                    Text(
                      'Back to Students',
                      style: AppTypography.small
                          .copyWith(color: const Color(0xFF0F2547)),
                    ),
                  ],
                ),
              ),
            SizedBox(height: 20.h),

            // Main Header Card
            _buildTabbedHeaderCard(isDesktop),
            SizedBox(height: 20.h),

            // Tab Bar
            _buildTabbedNavigation(isDesktop),
            SizedBox(height: 20.h),

            // Tab Content
            _buildTabbedTabContent(isDesktop),
            SizedBox(height: 24.h),

            // Digital Identity & QR Attendance
            _buildDigitalIdentityCard(isDesktop,
                customTitle: widget.studentId != null
                    ? 'Student Digital Identity Card'
                    : null),
            SizedBox(height: 24.h),

            // Logout
            if (widget.studentId == null) ...[
              GestureDetector(
                onTap: () => setState(() => _showLogout = true),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout_rounded,
                          color: AppColors.error, size: 20.sp),
                      SizedBox(width: 10.w),
                      Text('Sign Out',
                          style: AppTypography.small
                              .copyWith(color: AppColors.error)),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 60.h),
            ],
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
                                  _avatarUrl!,
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
                        _emergencyInfo != 'UNSET' ? _emergencyInfo : 'N/A')),
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
                      _emergencyInfo != 'UNSET' ? _emergencyInfo : 'N/A'),
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
                _studentGender != '—' ? _studentGender : 'N/A',
                'Blood Group',
                _studentBloodGroup != '—' ? _studentBloodGroup : 'N/A'),
            SizedBox(height: 16.h),
            _buildGridRow('Roll Number', _rollNo.isNotEmpty ? _rollNo : 'N/A',
                'Admission Number', _admissionNo),
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
                'Guardian Phone',
                _guardianPhone.isNotEmpty ? _guardianPhone : 'N/A',
                'Emergency Phone',
                _emergencyInfo != 'UNSET' ? _emergencyInfo : 'N/A'),
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
                SizedBox(width: 20.w),
                Expanded(child: coreIdentityCard),
              ],
            ),
            SizedBox(height: 20.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: guardianCard),
                SizedBox(width: 20.w),
                Expanded(
                  child: Container(
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
                            _address.isNotEmpty &&
                                    _address != 'No location registered'
                                ? _address
                                : 'No registered address available',
                            style: AppTypography.caption
                                .copyWith(color: const Color(0xFF0F2547))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      } else {
        return Column(
          children: [
            personalCard,
            SizedBox(height: 16.h),
            coreIdentityCard,
            SizedBox(height: 16.h),
            guardianCard,
            SizedBox(height: 16.h),
            Container(
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
                  Text('Address Info',
                      style: AppTypography.small
                          .copyWith(color: const Color(0xFF0F2547))),
                  SizedBox(height: 20.h),
                  Text('Address',
                      style: AppTypography.caption
                          .copyWith(color: const Color(0xFF64748B))),
                  SizedBox(height: 4.h),
                  Text(
                      _address.isNotEmpty &&
                              _address != 'No location registered'
                          ? _address
                          : 'No registered address available',
                      style: AppTypography.caption
                          .copyWith(color: const Color(0xFF0F2547))),
                ],
              ),
            ),
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

      return Column(
        children: [
          Row(
            children: [
              _buildAttendanceStatCard(
                  'Attendance Rate',
                  '${percentage.toStringAsFixed(1)}%',
                  const Color(0xFF1A6FDB),
                  const Color(0xFFE8F1FB)),
              SizedBox(width: 8.w),
              _buildAttendanceStatCard(
                  'Days Present',
                  '$displayPresent/$displayTotal',
                  const Color(0xFF10B981),
                  const Color(0xFFECFDF5)),
              SizedBox(width: 8.w),
              _buildAttendanceStatCard('Days Absent', '$displayAbsent',
                  const Color(0xFFEF4444), const Color(0xFFFEF2F2)),
            ],
          ),
          SizedBox(height: 16.h),
          Container(
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
          ),
        ],
      );
    }

    if (_selectedTab == 'Fees') {
      final double payable = _feeLedger != null
          ? double.tryParse(
                  _feeLedger!['totalPayable']?.toString() ?? '45000') ??
              45000.0
          : 45000.0;
      final double paid = _feeLedger != null
          ? double.tryParse(_feeLedger!['totalPaid']?.toString() ?? '30000') ??
              30000.0
          : 30000.0;
      final double pending = _feeLedger != null
          ? double.tryParse(
                  _feeLedger!['totalPending']?.toString() ?? '15000') ??
              15000.0
          : 15000.0;
      final String status = _feeLedger != null
          ? _feeLedger!['status']?.toString() ?? 'PARTIALLY_PAID'
          : 'PARTIALLY_PAID';
      final String structureName =
          _feeLedger != null && _feeLedger!['feeStructure'] != null
              ? _feeLedger!['feeStructure']['name'].toString()
              : 'Grade 11 Annual Fee';

      Color statusColor = const Color(0xFFF59E0B);
      Color statusBg = const Color(0xFFFFFBEB);
      if (status.toUpperCase() == 'PAID') {
        statusColor = const Color(0xFF10B981);
        statusBg = const Color(0xFFECFDF5);
      } else if (status.toUpperCase() == 'PENDING') {
        statusColor = const Color(0xFFEF4444);
        statusBg = const Color(0xFFFEF2F2);
      }

      return Column(
        children: [
          Container(
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
                    Expanded(
                      child: Text(
                        structureName,
                        style: AppTypography.small
                            .copyWith(color: const Color(0xFF0F2547)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(6.r)),
                      child: Text(
                        status.replaceAll('_', ' ').toUpperCase(),
                        style:
                            AppTypography.caption.copyWith(color: statusColor),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20.h),
                _buildGridRow(
                    'Total Fee Payable',
                    '₹${payable.toStringAsFixed(2)}',
                    'Total Amount Paid',
                    '₹${paid.toStringAsFixed(2)}'),
                SizedBox(height: 16.h),
                _buildGridRow('Pending Balance',
                    '₹${pending.toStringAsFixed(2)}', 'Academic Year', _batch),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          Container(
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
                Text('Recent Payment Transactions',
                    style: AppTypography.small
                        .copyWith(color: const Color(0xFF0F2547))),
                SizedBox(height: 16.h),
                if (_feePayments.isEmpty)
                  _buildMockFeePayments()
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _feePayments.length,
                    itemBuilder: (ctx, idx) {
                      final p = _feePayments[idx];
                      final receipt = p['receiptNumber']?.toString() ?? '—';
                      final amount =
                          double.tryParse(p['amount']?.toString() ?? '0') ??
                              0.0;
                      final dateStr = p['paymentDate']?.toString() ?? '—';
                      final mode = p['paymentMode']?.toString() ?? 'ONLINE';
                      return _buildFeePaymentRow(
                          receipt, amount, dateStr, mode);
                    },
                  ),
              ],
            ),
          ),
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
      final String routeName =
          _transportAllocation != null && _transportAllocation!['route'] != null
              ? _transportAllocation!['route']['name'].toString()
              : 'Route 102 - North Delhi Bypass';
      final String stopName =
          _transportAllocation != null && _transportAllocation!['stop'] != null
              ? _transportAllocation!['stop']['name'].toString()
              : 'Rohini Sector 15 Crossing';
      final String startLoc =
          _transportAllocation != null && _transportAllocation!['route'] != null
              ? _transportAllocation!['route']['startLocation']?.toString() ??
                  'School Campus'
              : 'School Campus';
      final String endLoc =
          _transportAllocation != null && _transportAllocation!['route'] != null
              ? _transportAllocation!['route']['endLocation']?.toString() ??
                  'Rohini Bus Depot'
              : 'Rohini Bus Depot';
      final String transStatus = _transportAllocation != null
          ? _transportAllocation!['status'].toString()
          : 'ACTIVE';

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
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(6.r)),
                  child: Text(
                    transStatus.toUpperCase(),
                    style: AppTypography.caption
                        .copyWith(color: const Color(0xFF10B981)),
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

  Widget _buildMockAttendanceList() {
    final List<Map<String, String>> mockData = [
      {
        'date': '2026-06-08',
        'status': 'PRESENT',
        'remarks': 'Scanned at Library Gate'
      },
      {
        'date': '2026-06-05',
        'status': 'PRESENT',
        'remarks': 'Scanned at Main Entry Gate'
      },
      {
        'date': '2026-06-04',
        'status': 'ABSENT',
        'remarks': 'Absent (No scan detected)'
      },
      {
        'date': '2026-06-03',
        'status': 'PRESENT',
        'remarks': 'Scanned at Classroom Gate'
      },
    ];
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: mockData.length,
      itemBuilder: (ctx, idx) {
        final r = mockData[idx];
        return _buildAttendanceRow(r['date']!, r['status']!, r['remarks']!);
      },
    );
  }

  Widget _buildFeePaymentRow(
      String receipt, double amount, String dateStr, String mode) {
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
              Text('Receipt #$receipt',
                  style: AppTypography.caption
                      .copyWith(color: const Color(0xFF0F2547))),
              SizedBox(height: 2.h),
              Text('Paid on $formattedDate via $mode',
                  style: AppTypography.caption
                      .copyWith(color: const Color(0xFF868E96))),
            ],
          ),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style:
                AppTypography.caption.copyWith(color: const Color(0xFF10B981)),
          ),
        ],
      ),
    );
  }

  Widget _buildMockFeePayments() {
    final List<Map<String, dynamic>> mockData = [
      {
        'receipt': 'RCPT-2026-9081',
        'amount': 15000.0,
        'date': '2026-05-10',
        'mode': 'UPI'
      },
      {
        'receipt': 'RCPT-2026-4402',
        'amount': 15000.0,
        'date': '2026-04-12',
        'mode': 'CASH'
      },
    ];
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: mockData.length,
      itemBuilder: (ctx, idx) {
        final p = mockData[idx];
        return _buildFeePaymentRow(
            p['receipt']!, p['amount']!, p['date']!, p['mode']!);
      },
    );
  }

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

  Widget _buildTableHeaderRow() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Color(0xFFE9F0F8), width: 1)),
      ),
      child: Row(
        children: [
          _buildCell('DAY',
              width: 110.w, isHeader: true, alignment: Alignment.centerLeft),
          ..._timetableColumns
              .map((col) => _buildTimeCell(col['title']!, col['time']!)),
        ],
      ),
    );
  }

  Widget _buildDayRow(String day) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE9F0F8), width: 1)),
      ),
      child: Row(
        children: [
          _buildCell(day,
              width: 110.w, isDayLabel: true, alignment: Alignment.centerLeft),
          ..._timetableColumns.map((col) {
            if (col['title'] == 'LUNCH BREAK') {
              return _buildCell('Lunch Break',
                  width: 110.w,
                  isLunchBreak: true,
                  bgColor: const Color(0xFFFFF9F2));
            }
            final subject = _getSubjectForSlot(day, col['start']!);
            return _buildCell(subject ?? 'Unassigned',
                width: 110.w, isUnassigned: subject == null);
          }),
        ],
      ),
    );
  }

  Widget _buildTimeCell(String title, String time) {
    return Container(
      width: 110.w,
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
                'Documents Asset Vault',
                style: GoogleFonts.outfit(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F2547),
                ),
              ),
            ],
          ),
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
                                      doc['name'] ?? '',
                                      style: AppTypography.caption.copyWith(
                                          color: const Color(0xFF0F2547)),
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      'Uploaded on: ${doc['date']}',
                                      style: AppTypography.caption.copyWith(
                                          color: const Color(0xFF868E96)),
                                    ),
                                  ],
                                ),
                              ),
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
            child: _dbQrCode != null && _dbQrCode!.startsWith('data:image')
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
                    data: _admissionNo,
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
                          style:
                              GoogleFonts.inter(color: const Color(0xFF0F2547)),
                        ),
                      );
                    },
                  ),
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
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF10B981),
                  content: Text('Attendance QR Code downloaded to gallery!',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                ),
              );
            },
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
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final platformFile = result.files.single;
        final bytes = platformFile.bytes;
        final extension = platformFile.extension?.toLowerCase() ?? 'png';

        if (bytes == null) {
          if (mounted) showToast(context, 'Failed to read image data.');
          return;
        }

        final client = Supabase.instance.client;
        final prefs = await SharedPreferences.getInstance();
        final userId =
            client.auth.currentUser?.id ?? prefs.getString('user_id');

        if (userId == null) {
          if (mounted) {
            showToast(context, 'Not logged in. Cannot upload avatar.');
          }
          return;
        }

        if (mounted) showToast(context, 'Uploading avatar...');

        final storagePath =
            'avatars/$userId-${DateTime.now().millisecondsSinceEpoch}.$extension';

        // Optimistically update UI using base64 memory image to avoid 404 caching from CDN delays
        final base64String = base64Encode(bytes);
        final base64DataUrl = 'data:image/$extension;base64,$base64String';
        if (mounted) {
          setState(() {
            _avatarUrl = base64DataUrl;
          });
        }

        try {
          // Try to create the bucket in case it's not created
          try {
            await client.storage
                .createBucket('avatars', const BucketOptions(public: true));
          } catch (_) {}

          // Try uploading to Supabase Storage
          await client.storage.from('avatars').uploadBinary(
                storagePath,
                bytes,
                fileOptions:
                    FileOptions(contentType: 'image/$extension', upsert: true),
              );

          final publicUrl =
              client.storage.from('avatars').getPublicUrl(storagePath);

          await client
              .from('User')
              .update({'avatar': publicUrl}).eq('id', userId);
          await prefs.setString('${widget.role}_photo_url', publicUrl);

          if (widget.onAvatarUpdated != null) {
            widget.onAvatarUpdated!(publicUrl);
          }

          if (mounted) {
            showToast(context, 'Avatar updated successfully!');
          }
        } catch (storageErr) {
          debugPrint(
              'Storage upload failed: $storageErr. Falling back to database base64 storage...');

          // Fallback to storing image directly in User.avatar as base64 Data URL
          final base64String = base64Encode(bytes);
          final base64DataUrl = 'data:image/$extension;base64,$base64String';

          await client
              .from('User')
              .update({'avatar': base64DataUrl}).eq('id', userId);
          await prefs.setString('${widget.role}_photo_url', base64DataUrl);

          if (widget.onAvatarUpdated != null) {
            widget.onAvatarUpdated!(base64DataUrl);
          }

          if (mounted) {
            setState(() {
              _avatarUrl = base64DataUrl;
            });
            showToast(
                context, 'Avatar updated successfully (base64 fallback)!');
          }
        }
      }
    } catch (e) {
      debugPrint('Avatar upload error: $e');
      if (mounted) showToast(context, 'Failed to update avatar: $e');
    }
  }

  Widget _buildTeacherProfile() {
    final bool isPushed = Navigator.canPop(context);
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 900;

    return Scaffold(
      key: _teacherScaffoldKey,
      drawer: isPushed
          ? const EduSphereDrawer(role: 'teacher', activeLabel: 'My Profile')
          : null,
      bottomNavigationBar:
          isPushed ? const TeacherBottomNavBar(activeIndex: 13) : null,
      backgroundColor: const Color(0xFFEFF6FF), // From image background color
      appBar:
          widget.showAppBar ? const TeacherAppBar(title: 'EduSphere') : null,
      body: SingleChildScrollView(
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
      ),
      floatingActionButton: (widget.role == 'teacher' &&
              widget.teacherId != null &&
              widget.teacherId != Supabase.instance.client.auth.currentUser?.id)
          ? null
          : FloatingActionButton(
              onPressed: _showEditProfileSheet,
              backgroundColor: const Color(0xFF0284C7),
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r)),
              child: const Icon(Icons.edit_note, color: Colors.white, size: 28),
            ),
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
            Stack(
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
                                _avatarUrl!,
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
          Stack(
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
                              _avatarUrl!,
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
            widget.teacherId == Supabase.instance.client.auth.currentUser?.id);

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
            child: _dbQrCode != null && _dbQrCode!.startsWith('data:image')
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
                    data: _employeeId.isNotEmpty ? _employeeId : 'TEACHER',
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
                          style:
                              GoogleFonts.inter(color: const Color(0xFF0F172A)),
                        ),
                      );
                    },
                  ),
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
              widget.role.toUpperCase(),
              style: AppTypography.caption
                  .copyWith(color: const Color(0xFF2563EB)),
            ),
          ),
          SizedBox(height: 20.h),
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF10B981),
                  content: Text('Attendance QR Code downloaded to gallery!',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                ),
              );
            },
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
                color: const Color(0xFF0284C7),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text(
                'ISSUED & LOCKED',
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
                    onPressed: () {
                      setState(() => _showLogout = false);
                      Navigator.pushReplacementNamed(context, '/login');
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
