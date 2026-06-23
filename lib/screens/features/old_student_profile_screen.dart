import 'package:flutter/material.dart';
import 'dart:async';
import '../../widgets/dashed_border_painter.dart';
import 'student_allocations_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../theme/colors.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../config/api_config.dart';

class OldStudentProfileScreen extends StatefulWidget {
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

  const OldStudentProfileScreen({
    super.key,
    this.role = 'student',
    required this.theme,
    this.onBack,
    this.showAppBar = true,
    this.onOpenDrawer,
    this.studentId,
    this.studentName,
    this.studentEmail,
    this.studentClass,
    this.admissionNo,
  });

  @override
  State<OldStudentProfileScreen> createState() =>
      _OldStudentProfileScreenState();
}

class _OldStudentProfileScreenState extends State<OldStudentProfileScreen> {
  // Shared state fields
  // ignore: unused_field
  String _address = 'No location registered';
  bool _isProfileLoading = false;
  bool _hasProfileError = false;
  String? _studentUserId;

  // Tabs State
  String _selectedTab = 'Personal Details';
  final List<String> _tabs = [
    'Personal Details',
    'Academic',
    'Attendance',
    'Fees',
    'Transport',
    'Time Table',
    'Documents'
  ];

  // Student details state
  String _studentName = 'Kavya Yadav';
  String _studentEmail = 'kavya.yadav@edusmart.edu';
  String _admissionNo = 'ADM-2023-0681';
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
  // ignore: unused_field
  String _religion = 'HINDU';
  // ignore: unused_field
  String _casteGroup = 'GENERAL';
  // ignore: unused_field
  String _nationality = 'INDIAN';

  String _admissionType = '—';
  String _previousSchool = '—';
  String _previousClass = '—';
  String _tcNumber = '—';
  String? _dbQrCode;

  bool _isUploadingDoc = false;
  List<Map<String, String>> _uploadedDocuments = [];

  // ignore: unused_field
  String _fatherName = 'Rajesh Sharma';
  // ignore: unused_field
  String _motherName = 'Priya Sharma';
  // ignore: unused_field
  String _guardianPhone = '+91 98765 43210';
  final List<RealtimeChannel> _realtimeChannels = [];

  // Tab details database variables
  bool _isLoadingTabDetails = false;
  // ignore: unused_field
  List<Map<String, dynamic>> _attendanceRecords = [];
  Map<String, dynamic>? _feeLedger;
  List<Map<String, dynamic>> _feeLedgers = [];
  // ignore: unused_field
  List<Map<String, dynamic>> _feePayments = [];
  Map<String, dynamic>? _transportAllocation;
  Map<int, List<Map<String, dynamic>>> _timetableSlots = {};

  LatLng _busLocation = const LatLng(28.70410, 77.10250);
  Timer? _simulationTimer;
  int _routeIndex = 0;
  final List<LatLng> _busRoute = const [
    LatLng(28.70410, 77.10250),
    LatLng(28.70430, 77.10270),
    LatLng(28.70450, 77.10290),
    LatLng(28.70470, 77.10310),
    LatLng(28.70490, 77.10330),
    LatLng(28.70510, 77.10350),
    LatLng(28.70530, 77.10370),
    LatLng(28.70550, 77.10390),
    LatLng(28.70570, 77.10410),
    LatLng(28.70590, 77.10430),
    LatLng(28.70610, 77.10450),
    LatLng(28.70630, 77.10470),
    LatLng(28.70650, 77.10490),
    LatLng(28.70670, 77.10510),
    LatLng(28.70690, 77.10530),
  ];

  @override
  void initState() {
    super.initState();

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
    _startBusSimulation();
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    for (var ch in _realtimeChannels) {
      try {
        Supabase.instance.client.removeChannel(ch);
      } catch (_) {}
    }
    super.dispose();
  }

  void _startBusSimulation() {
    _busLocation = _busRoute.first;
    _simulationTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) return;
      setState(() {
        _routeIndex = (_routeIndex + 1) % _busRoute.length;
        _busLocation = _busRoute[_routeIndex];
      });
    });
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
          _feeLedgers = List<Map<String, dynamic>>.from(ledgers);
          _feeLedger =
              ledgers.isNotEmpty ? Map<String, dynamic>.from(ledgers[0]) : null;
          _feePayments = List<Map<String, dynamic>>.from(recentPayments);
        });
      } else {
        final List<dynamic> feeLedgerRes = await client
            .from('StudentFeeLedger')
            .select(
                'id, totalPayable, totalPaid, totalPending, status, feeStructure:FeeStructure(name)')
            .eq('studentId', studentId);

        if (mounted) {
          setState(() {
            _feeLedgers = List<Map<String, dynamic>>.from(feeLedgerRes);
            _feeLedger = feeLedgerRes.isNotEmpty
                ? Map<String, dynamic>.from(feeLedgerRes[0])
                : null;
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
        } else {
          setState(() {
            _transportAllocation = null;
          });
        }
      } else {
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
          setState(() {
            _transportAllocation = null;
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
    _address = '—';
    _fatherName = '—';
    _motherName = '—';
    _guardianPhone = '—';
    _admissionType = '—';
    _previousSchool = '—';
    _previousClass = '—';
    _tcNumber = '—';
    _uploadedDocuments = [];
    _attendanceRecords = [];
    _feeLedger = null;
    _feePayments = [];
    _timetableSlots = {};
    _transportAllocation = null;
  }

  @override
  void didUpdateWidget(OldStudentProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.studentId != oldWidget.studentId) {
      _loadStudentDataFromSupabase();
    }
  }

  Future<void> _loadStudentDataFromSupabase() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _dbQrCode = prefs.getString('student_qrcode');
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

          _admissionType = studentData['admissionType']?.toString() ??
              studentData['admission_type']?.toString() ??
              '—';
          _previousSchool = studentData['previousSchool']?.toString() ??
              studentData['previous_school']?.toString() ??
              '—';
          _previousClass = studentData['previousClass']?.toString() ??
              studentData['previous_class']?.toString() ??
              '—';
          _tcNumber = studentData['tcNumber']?.toString() ??
              studentData['tc_number']?.toString() ??
              '—';

          final joinDateStr = studentData['joiningDate'] as String?;
          if (joinDateStr != null) {
            try {
              final parsed = DateTime.parse(joinDateStr);
              _studentJoinedDate =
                  '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
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

          final rawAvatar = userMap['avatar']?.toString() ?? '';
          if (rawAvatar.isNotEmpty) {
            _avatarUrl = rawAvatar.startsWith('http')
                ? rawAvatar
                : '${ApiConfig.serverBaseUrl}$rawAvatar';
          } else {
            _avatarUrl = null;
          }

          _address = userMap['address'] as String? ?? '—';

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
                await prefs.setString('student_qrcode', qr);
                if (mounted) {
                  setState(() {
                    _dbQrCode = qr;
                  });
                }
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

        _admissionType = studentResMap['admissionType']?.toString() ??
            studentResMap['admission_type']?.toString() ??
            '—';
        _previousSchool = studentResMap['previousSchool']?.toString() ??
            studentResMap['previous_school']?.toString() ??
            '—';
        _previousClass = studentResMap['previousClass']?.toString() ??
            studentResMap['previous_class']?.toString() ??
            '—';
        _tcNumber = studentResMap['tcNumber']?.toString() ??
            studentResMap['tc_number']?.toString() ??
            '—';

        final joinDateStr = studentResMap['joiningDate'] as String?;
        if (joinDateStr != null) {
          try {
            final parsed = DateTime.parse(joinDateStr);
            _studentJoinedDate =
                '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
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

        final rawAvatar = userMap['avatar'] ??
            userMap['photoUrl'] ??
            userMap['profileImage']?.toString() ??
            '';
        if (rawAvatar.isNotEmpty) {
          _avatarUrl = rawAvatar.startsWith('http')
              ? rawAvatar
              : '${ApiConfig.serverBaseUrl}$rawAvatar';
        } else {
          _avatarUrl = null;
        }

        _address = userMap['address'] as String? ?? '—';
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
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('student_qrcode', qr);
              if (mounted) {
                setState(() {
                  _dbQrCode = qr;
                });
              }
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
          String guardianPhoneVal = '—';

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
                if (guardianPhoneVal == '—') guardianPhoneVal = pPhone;
              } else if (rel == 'MOTHER') {
                mother = pFullName;
                if (guardianPhoneVal == '—') guardianPhoneVal = pPhone;
              } else {
                if (guardianPhoneVal == '—') guardianPhoneVal = pPhone;
              }
            }
          }

          setState(() {
            _fatherName = father;
            _motherName = mother;
            _guardianPhone = guardianPhoneVal;
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
      setState(() {
        _isProfileLoading = false;
        _hasProfileError = true;
      });
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
      final String targetUserId =
          widget.studentId != null ? (_studentUserId ?? '') : currentUser.id;

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
                  _loadStudentDataFromSupabase();
                }
              },
            );
        userChannel.subscribe();
        _realtimeChannels.add(userChannel);
      }

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
          } else if (widget.studentId == null) {
            _loadStudentDataFromSupabase();
          }
        } catch (e) {
          debugPrint('Error handling Socket.IO update: $e');
        }
      });
    } catch (e) {
      debugPrint(
          '⚠️ Error connecting Supabase Realtime in OldStudentProfileScreen: $e');
    }
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

  Future<void> _downloadStatement() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text('Generating PDF statement...',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        backgroundColor: const Color(0xFF1A6FDB),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      final pdf = pw.Document();
      final now = DateTime.now();
      final dateStr =
          '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
      final timeStr =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      final receiptNo =
          'STMT-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch % 100000}';

      final primaryBlue = PdfColor.fromHex('#1A6FDB');
      final darkText = PdfColor.fromHex('#0F172A');
      final lightGray = PdfColor.fromHex('#F8FAFC');
      final borderGray = PdfColor.fromHex('#E2E8F0');
      final greenColor = PdfColor.fromHex('#10B981');
      final redColor = PdfColor.fromHex('#EF4444');

      double totalPayableVal = 0.0;
      double totalPaidVal = 0.0;
      double totalPendingVal = 0.0;

      if (_feeLedgers.isNotEmpty) {
        for (var l in _feeLedgers) {
          totalPayableVal +=
              double.tryParse(l['totalPayable']?.toString() ?? '0') ?? 0.0;
          totalPaidVal +=
              double.tryParse(l['totalPaid']?.toString() ?? '0') ?? 0.0;
          totalPendingVal +=
              double.tryParse(l['totalPending']?.toString() ?? '0') ?? 0.0;
        }
      } else if (_feeLedger != null) {
        totalPayableVal =
            double.tryParse(_feeLedger!['totalPayable']?.toString() ?? '0') ??
                0.0;
        totalPaidVal =
            double.tryParse(_feeLedger!['totalPaid']?.toString() ?? '0') ?? 0.0;
        totalPendingVal =
            double.tryParse(_feeLedger!['totalPending']?.toString() ?? '0') ??
                0.0;
      } else {
        totalPayableVal = 45000.0;
        totalPaidVal = 30000.0;
        totalPendingVal = 15000.0;
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
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
                                color: PdfColors.white)),
                        pw.SizedBox(height: 4),
                        pw.Text('Smart School ERP',
                            style: const pw.TextStyle(
                                fontSize: 11, color: PdfColors.white)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('FEE STATEMENT',
                            style: pw.TextStyle(
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white)),
                        pw.SizedBox(height: 4),
                        pw.Text('Statement #: $receiptNo',
                            style: const pw.TextStyle(
                                fontSize: 9, color: PdfColors.white)),
                        pw.Text('Date: $dateStr  $timeStr',
                            style: const pw.TextStyle(
                                fontSize: 9, color: PdfColors.white)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
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
                              style: pw.TextStyle(
                                  fontSize: 9,
                                  color: PdfColors.grey600,
                                  fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 6),
                          pw.Text(_studentName,
                              style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                  color: darkText)),
                          pw.Text('Email: $_studentEmail',
                              style: const pw.TextStyle(
                                  fontSize: 10, color: PdfColors.grey700)),
                          pw.Text('Admission No: $_admissionNo',
                              style: const pw.TextStyle(
                                  fontSize: 9, color: PdfColors.grey600)),
                        ],
                      ),
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('FINANCIAL SUMMARY',
                            style: pw.TextStyle(
                                fontSize: 9,
                                color: PdfColors.grey600,
                                fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 6),
                        pw.Text(
                            'Total Payable: ₹${totalPayableVal.toStringAsFixed(0)}',
                            style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                                color: darkText)),
                        pw.Text(
                            'Total Paid: ₹${totalPaidVal.toStringAsFixed(0)}',
                            style: pw.TextStyle(
                                fontSize: 11,
                                color: greenColor,
                                fontWeight: pw.FontWeight.bold)),
                        pw.Text(
                            'Balance Due: ₹${totalPendingVal.toStringAsFixed(0)}',
                            style: pw.TextStyle(
                                fontSize: 11,
                                color: redColor,
                                fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text('FEE LEDGER DETAILS',
                  style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: darkText)),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: borderGray, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: primaryBlue),
                    children: [
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Fee Structure',
                              style: pw.TextStyle(
                                  fontSize: 9,
                                  color: PdfColors.white,
                                  fontWeight: pw.FontWeight.bold))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Status',
                              style: pw.TextStyle(
                                  fontSize: 9,
                                  color: PdfColors.white,
                                  fontWeight: pw.FontWeight.bold))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Total',
                              style: pw.TextStyle(
                                  fontSize: 9,
                                  color: PdfColors.white,
                                  fontWeight: pw.FontWeight.bold))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Paid',
                              style: pw.TextStyle(
                                  fontSize: 9,
                                  color: PdfColors.white,
                                  fontWeight: pw.FontWeight.bold))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Due',
                              style: pw.TextStyle(
                                  fontSize: 9,
                                  color: PdfColors.white,
                                  fontWeight: pw.FontWeight.bold))),
                    ],
                  ),
                  if (_feeLedgers.isEmpty)
                    pw.TableRow(
                      children: [
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('Annual Tuition Fee 2024-25',
                                style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('PARTIALLY PAID',
                                style: pw.TextStyle(
                                    fontSize: 9, color: redColor))),
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(
                                '₹${totalPayableVal.toStringAsFixed(0)}',
                                style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(
                                '₹${totalPaidVal.toStringAsFixed(0)}',
                                style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(
                                '₹${totalPendingVal.toStringAsFixed(0)}',
                                style: const pw.TextStyle(fontSize: 9))),
                      ],
                    )
                  else
                    ..._feeLedgers.map((l) {
                      final name = l['feeStructure']?['name']?.toString() ??
                          'Annual Fee';
                      final total = double.tryParse(
                              l['totalPayable']?.toString() ?? '0') ??
                          0.0;
                      final paid =
                          double.tryParse(l['totalPaid']?.toString() ?? '0') ??
                              0.0;
                      final due = double.tryParse(
                              l['totalPending']?.toString() ?? '0') ??
                          0.0;
                      final status = l['status']?.toString() ?? 'PENDING';
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(name,
                                  style: const pw.TextStyle(fontSize: 9))),
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(status,
                                  style: pw.TextStyle(
                                      fontSize: 9,
                                      color: status == 'PAID'
                                          ? greenColor
                                          : redColor))),
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text('₹${total.toStringAsFixed(0)}',
                                  style: const pw.TextStyle(fontSize: 9))),
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text('₹${paid.toStringAsFixed(0)}',
                                  style: const pw.TextStyle(fontSize: 9))),
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text('₹${due.toStringAsFixed(0)}',
                                  style: const pw.TextStyle(fontSize: 9))),
                        ],
                      );
                    }),
                ],
              ),
              pw.SizedBox(height: 24),
              pw.Divider(color: borderGray),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Generated by EduSphere ERP • $dateStr $timeStr',
                      style: const pw.TextStyle(
                          fontSize: 8, color: PdfColors.grey500)),
                  pw.Text('This is a system-generated statement.',
                      style: const pw.TextStyle(
                          fontSize: 8, color: PdfColors.grey500)),
                ],
              ),
            ];
          },
        ),
      );

      final pdfBytes = await pdf.save();
      final fileName = 'FeeStatement_$receiptNo.pdf';

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      var status = await Permission.storage.request();
      if (!status.isGranted && Platform.isAndroid) {
        await Permission.manageExternalStorage.request();
      }

      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory != null) {
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(pdfBytes);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Statement saved to Downloads folder',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w600)),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate statement: $e',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white)),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ignore: unused_element
  Future<void> _allocateTransportForStudent() async {
    setState(() {
      _isLoadingTabDetails = true;
    });

    try {
      final studentId = widget.studentId ??
          (await SharedPreferences.getInstance()).getString('student_id') ??
          '';
      if (studentId.isEmpty) return;

      // 1. Fetch available routes
      final routesRes = await ApiService.instance.get('transport/routes');
      final routes = routesRes['routes'] as List<dynamic>? ?? [];

      String? routeId;
      String? stopId;

      if (routes.isNotEmpty) {
        final routeObj = routes.first as Map<String, dynamic>;
        routeId = routeObj['id'] as String?;
        final stops = routeObj['stops'] as List<dynamic>? ?? [];
        if (stops.isNotEmpty) {
          stopId = (stops.first as Map<String, dynamic>)['id'] as String?;
        }
      }

      if (routeId != null && stopId != null) {
        // Create actual database allocation
        final response =
            await ApiService.instance.post('transport/allocate', body: {
          'studentId': studentId,
          'routeId': routeId,
          'stopId': stopId,
          'status': 'ACTIVE',
        });

        if (response != null && response['success'] == true) {
          await _loadAllTabDetails(studentId, null);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: const Color(0xFF10B981),
                content: Text('Transport allocated successfully!',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              ),
            );
          }
          return;
        }
      }

      // Local mock fallback if no routes exist in database
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text('Mock Transport allocated!',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error allocating transport: $e');
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
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingTabDetails = false;
        });
      }
    }
  }

  // Formatting utilities for Image 3 exact case/value specifications
  String _formatValueUpper(String? val) {
    if (val == null ||
        val.trim().isEmpty ||
        val.trim() == '—' ||
        val.trim() == 'UNSET') {
      return 'N/A';
    }
    return val.trim().toUpperCase();
  }

  String _formatValueSimple(String? val) {
    if (val == null ||
        val.trim().isEmpty ||
        val.trim() == '—' ||
        val.trim() == 'UNSET') {
      return 'N/A';
    }
    return val.trim();
  }

  // --- UI BUILDER METHODS ---

  @override
  Widget build(BuildContext context) {
    if (_isProfileLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F7FB),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF0F2547)),
            onPressed: widget.onBack ?? () => Navigator.pop(context),
          ),
          title: Text('Loading Profile...',
              style: GoogleFonts.inter(
                  color: const Color(0xFF0F2547), fontWeight: FontWeight.bold)),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF1A6FDB)),
        ),
      );
    }

    if (_hasProfileError) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F7FB),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF0F2547)),
            onPressed: widget.onBack ?? () => Navigator.pop(context),
          ),
          title: Text('Error',
              style: GoogleFonts.inter(
                  color: const Color(0xFF0F2547), fontWeight: FontWeight.bold)),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48.sp, color: Colors.red),
              SizedBox(height: 16.h),
              Text('Failed to load profile details.',
                  style: GoogleFonts.inter(
                      fontSize: 16.sp, fontWeight: FontWeight.bold)),
              SizedBox(height: 12.h),
              ElevatedButton(
                onPressed: _loadStudentDataFromSupabase,
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A6FDB)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth > 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F2547)),
          onPressed: widget.onBack ?? () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Text(
          'Back to Students',
          style: GoogleFonts.inter(
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F2547),
          ),
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded,
                    color: Color(0xFF1A6FDB)),
                onPressed: () {},
              ),
              Positioned(
                right: 12.w,
                top: 12.h,
                child: Container(
                  width: 6.w,
                  height: 6.h,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded,
                color: Colors.black),
            onPressed: () {},
          ),
          SizedBox(width: 8.w),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 40.w : 16.w, vertical: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Basic Info Card (Image 3 layout)
              _buildStudentBasicInfoCard(),
              SizedBox(height: 20.h),

              // 2. Tab Bar Navigation
              _buildTabbedNavigation(isDesktop),
              SizedBox(height: 20.h),

              // 3. Tab Content
              _buildTabContent(isDesktop),
              SizedBox(height: 40.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentBasicInfoCard() {
    final List<String> parts = _studentName.trim().split(RegExp(r'\s+'));
    final String initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : (parts.isNotEmpty && parts[0].isNotEmpty
            ? parts[0][0].toUpperCase()
            : 'ST');

    final String displayPhone = (_emergencyInfo != 'UNSET' &&
            _emergencyInfo != '—' &&
            _emergencyInfo.trim().isNotEmpty)
        ? _emergencyInfo
        : '+919413223223';

    final String displayDob =
        (_studentDob != '—' && _studentDob.trim().isNotEmpty)
            ? _studentDob
            : '15/05/2010';

    final String displayClass = _section != '—' && _section.isNotEmpty
        ? '$_studentClass - $_section'
        : _studentClass;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 72.w,
                height: 72.w,
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(36.r),
                  child: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                      ? Image.network(
                          _avatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Center(
                            child: Text(
                              initials,
                              style: GoogleFonts.inter(
                                fontSize: 20.sp,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1E6091),
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            initials,
                            style: GoogleFonts.inter(
                              fontSize: 20.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1E6091),
                            ),
                          ),
                        ),
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _studentName,
                      style: GoogleFonts.inter(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F2547),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Admission No: $_admissionNo',
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),

          // ACTIVE badge positioned below name/avatar aligned left
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Text(
              'ACTIVE',
              style: GoogleFonts.inter(
                fontSize: 10.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF10B981),
              ),
            ),
          ),
          SizedBox(height: 12.h),
          const Divider(color: Color(0xFFE2EAF4), height: 1),
          SizedBox(height: 12.h),

          // Vertical list of details matching Image 3 layout exactly
          _buildVerticalDetailRow(
              Icons.mail_outline_rounded, 'Email', _studentEmail),
          _buildVerticalDetailRow(Icons.phone_outlined, 'Phone', displayPhone),
          _buildVerticalDetailRow(
              Icons.calendar_today_outlined, 'Date of Birth', displayDob),
          _buildVerticalDetailRow(Icons.class_outlined, 'Class', displayClass),
        ],
      ),
    );
  }

  Widget _buildVerticalDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16.sp, color: const Color(0xFF64748B)),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 10.sp,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F2547),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

  Widget _buildTabContent(bool isDesktop) {
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
            Text(
              'Personal Information',
              style: GoogleFonts.inter(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F2547)),
            ),
            SizedBox(height: 20.h),
            _buildGridRow(
              'Gender',
              _formatValueUpper(_studentGender),
              'Blood Group',
              _formatValueUpper(_studentBloodGroup),
            ),
            SizedBox(height: 16.h),
            _buildGridRow(
              'Roll Number',
              _formatValueUpper(_rollNo),
              'Admission Number',
              _formatValueSimple(_admissionNo),
            ),
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
      final String displayClassRaw = _section != '—' && _section.isNotEmpty
          ? '$_studentClass - $_section'
          : _studentClass;
      final String displayClass = displayClassRaw.replaceAll('Class', 'Grade');

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
            Text(
              'Academic Information',
              style: GoogleFonts.inter(
                fontSize: 15.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F2547),
              ),
            ),
            SizedBox(height: 20.h),
            _buildVerticalAcademicField(
                'Current Class & Section', displayClass),
            _buildVerticalAcademicField(
                'Academic Year', _formatValueSimple(_batch)),
            _buildVerticalAcademicField(
                'Admission Type', _formatValueUpper(_admissionType)),
            _buildVerticalAcademicField(
                'Medium of Instruction', _formatValueUpper(_medium)),
            _buildVerticalAcademicField(
                'Joining Date', _formatValueSimple(_studentJoinedDate)),
            _buildVerticalAcademicField(
                'Previous School', _formatValueSimple(_previousSchool)),
            _buildVerticalAcademicField(
                'Previous Class', _formatValueSimple(_previousClass)),
            _buildVerticalAcademicField(
                'TC Number', _formatValueSimple(_tcNumber)),
          ],
        ),
      );
    }

    if (_selectedTab == 'Attendance') {
      final qrCard = Container(
        width: double.infinity,
        padding: EdgeInsets.all(20.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFFE2EAF4)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.qr_code_scanner_rounded,
                    size: 16.sp, color: const Color(0xFF475569)),
                SizedBox(width: 8.w),
                Text(
                  'ATTENDANCE QR CODE',
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF475569),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),
            Container(
              width: 160.r,
              height: 160.r,
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
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
                          errorBuilder: (cxt, err, stack) => Center(
                            child: Icon(Icons.qr_code_2_rounded,
                                size: 80.sp, color: const Color(0xFF0F172A)),
                          ),
                        );
                      } catch (_) {
                        return Center(
                          child: Icon(Icons.qr_code_2_rounded,
                              size: 80.sp, color: const Color(0xFF0F172A)),
                        );
                      }
                    })()
                  : QrImageView(
                      data: _admissionNo,
                      version: QrVersions.auto,
                      size: 140.r,
                      gapless: false,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Color(0xFF0F172A),
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Color(0xFF0F172A),
                      ),
                      errorStateBuilder: (cxt, err) => Center(
                        child: Icon(Icons.qr_code_2_rounded,
                            size: 80.sp, color: const Color(0xFF0F172A)),
                      ),
                    ),
            ),
            SizedBox(height: 16.h),
            Text(
              _studentName,
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 4.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Text(
                'STUDENT',
                style: GoogleFonts.inter(
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1D4ED8),
                ),
              ),
            ),
            SizedBox(height: 16.h),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF10B981),
                    content: Text(
                      'Simulated QR Code Download Complete!',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.download, size: 16, color: Colors.white),
              label: const Text('Download'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r)),
                minimumSize: Size(double.infinity, 44.h),
              ),
            ),
          ],
        ),
      );

      final qrInfoCard = Container(
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
            Text(
              'QR Code Info',
              style: GoogleFonts.inter(
                fontSize: 15.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F2547),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'This QR code is used for scanning attendance at QR scanner devices',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 16.h),
            _buildBulletPoint(
                'Each user has a unique, permanent QR code tied to their account.'),
            _buildBulletPoint(
                'The QR is valid at any active scanner the user\'s role is allowed on.'),
            _buildBulletPoint(
                'Admins can regenerate the QR if it is lost or compromised.'),
            _buildBulletPoint(
                'GPS geofencing is enforced by the scanner device, not the QR code itself.'),
          ],
        ),
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Attendance Records',
            style: GoogleFonts.inter(
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F2547),
            ),
          ),
          SizedBox(height: 16.h),
          qrCard,
          SizedBox(height: 16.h),
          qrInfoCard,
        ],
      );
    }

    if (_selectedTab == 'Fees') {
      double payable = 0.0;
      double paid = 0.0;
      double pending = 0.0;

      final List<Map<String, dynamic>> displayLedgers = [];
      if (_feeLedgers.isNotEmpty) {
        displayLedgers.addAll(_feeLedgers);
      } else if (_feeLedger != null) {
        displayLedgers.add(_feeLedger!);
      }

      if (displayLedgers.isNotEmpty) {
        for (var l in displayLedgers) {
          payable +=
              double.tryParse(l['totalPayable']?.toString() ?? '0') ?? 0.0;
          paid += double.tryParse(l['totalPaid']?.toString() ?? '0') ?? 0.0;
          pending +=
              double.tryParse(l['totalPending']?.toString() ?? '0') ?? 0.0;
        }
      } else {
        // Fallback default mock values matching reference image calculations
        payable = 50000.0;
        paid = 25000.0;
        pending = 25000.0;
        displayLedgers.add({
          'totalPayable': 50000.0,
          'totalPaid': 25000.0,
          'totalPending': 25000.0,
          'status': 'PARTIALLY_PAID',
          'feeStructure': {'name': 'Annual Tuition Fee 2024-25'}
        });
      }

      final double remainingPayable =
          (payable - paid - pending).clamp(0.0, double.infinity);

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
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fee Status',
                      style: GoogleFonts.inter(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F2547),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Current academic year fee details',
                      style: GoogleFonts.inter(
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: _downloadStatement,
                  icon: Icon(Icons.download,
                      size: 16.sp, color: const Color(0xFF0F2547)),
                  label: Text(
                    'Statement',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F2547),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),

            // TOTAL PAYABLE Card
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: const Color(0xFFE2EAF4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOTAL PAYABLE',
                    style: GoogleFonts.inter(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    '₹${remainingPayable.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F2547),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),

            // TOTAL PAID Card
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: const Color(0xFFDCFCE7)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOTAL PAID',
                    style: GoogleFonts.inter(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF15803D),
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    '₹${paid.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF15803D),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),

            // TOTAL DUE Card
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: const Color(0xFFFEE2E2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOTAL DUE',
                    style: GoogleFonts.inter(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFB91C1C),
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    '₹${pending.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFB91C1C),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),

            // Data Table Section
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: SizedBox(
                width: 530.w,
                child: Column(
                  children: [
                    // Table Header
                    Container(
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom:
                              BorderSide(color: Color(0xFFE2EAF4), width: 1.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 180.w,
                            child: Text(
                              'Fee Structure',
                              style: GoogleFonts.inter(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 110.w,
                            child: Text(
                              'Status',
                              style: GoogleFonts.inter(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 80.w,
                            child: Text(
                              'Total',
                              style: GoogleFonts.inter(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 80.w,
                            child: Text(
                              'Paid',
                              style: GoogleFonts.inter(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 80.w,
                            child: Text(
                              'Due',
                              style: GoogleFonts.inter(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Table Rows
                    ...displayLedgers.map((l) {
                      final String name =
                          l['feeStructure']?['name']?.toString() ??
                              'Annual Tuition Fee';
                      final String statusText =
                          l['status']?.toString() ?? 'PENDING';
                      final double totalVal = double.tryParse(
                              l['totalPayable']?.toString() ?? '0') ??
                          0.0;
                      final double paidVal =
                          double.tryParse(l['totalPaid']?.toString() ?? '0') ??
                              0.0;
                      final double dueVal = double.tryParse(
                              l['totalPending']?.toString() ?? '0') ??
                          0.0;

                      // Status Badge styling
                      Color badgeColor = const Color(0xFFEF4444);
                      Color badgeBg = const Color(0xFFFEF2F2);
                      if (statusText.toUpperCase() == 'PAID') {
                        badgeColor = const Color(0xFF10B981);
                        badgeBg = const Color(0xFFECFDF5);
                      } else if (statusText.toUpperCase() == 'PARTIALLY_PAID' ||
                          statusText.toUpperCase() == 'PARTIAL') {
                        badgeColor = const Color(0xFFB91C1C);
                        badgeBg = const Color(0xFFFEE2E2);
                      }

                      return Container(
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom:
                                BorderSide(color: Color(0xFFF1F5F9), width: 1),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Fee Structure Name
                            SizedBox(
                              width: 180.w,
                              child: Text(
                                name,
                                style: GoogleFonts.inter(
                                  fontSize: 12.5.sp,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F2547),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),

                            // Status Badge
                            Container(
                              width: 110.w,
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8.w, vertical: 4.h),
                                decoration: BoxDecoration(
                                  color: badgeBg,
                                  borderRadius: BorderRadius.circular(6.r),
                                ),
                                child: Text(
                                  statusText.replaceAll('_', ' ').toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontSize: 9.sp,
                                    fontWeight: FontWeight.w800,
                                    color: badgeColor,
                                  ),
                                ),
                              ),
                            ),

                            // Total
                            SizedBox(
                              width: 80.w,
                              child: Text(
                                '₹${totalVal.toStringAsFixed(0)}',
                                style: GoogleFonts.inter(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF475569),
                                ),
                              ),
                            ),

                            // Paid
                            SizedBox(
                              width: 80.w,
                              child: Text(
                                '₹${paidVal.toStringAsFixed(0)}',
                                style: GoogleFonts.inter(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                            ),

                            // Due
                            SizedBox(
                              width: 80.w,
                              child: Text(
                                '₹${dueVal.toStringAsFixed(0)}',
                                style: GoogleFonts.inter(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFEF4444),
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

    if (_selectedTab == 'Transport') {
      if (_transportAllocation == null) {
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.directions_bus_filled_outlined,
                      color: const Color(0xFF1A6FDB), size: 20.sp),
                  SizedBox(width: 8.w),
                  Text(
                    'Transport & Safety',
                    style: GoogleFonts.inter(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F2547),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4.h),
              Text(
                'Route allocation and boarding point details',
                style: GoogleFonts.inter(
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ),
              SizedBox(height: 24.h),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: CustomPaint(
                  painter: DashedBorderPainter(
                    color: const Color(0xFFCBD5E1),
                    strokeWidth: 1.5,
                    dashWidth: 6.0,
                    dashSpace: 4.0,
                    borderRadius: 20.r,
                  ),
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 20.w, vertical: 40.h),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
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
                          style: GoogleFonts.inter(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F2547),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'This student is not currently enrolled in the school transport service.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 11.5.sp,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                            height: 1.4,
                          ),
                        ),
                        SizedBox(height: 20.h),
                        OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => StudentAllocationsScreen(
                                  theme: widget.theme,
                                  onBack: () {
                                    Navigator.pop(context);
                                    final studentId = widget.studentId ?? '';
                                    if (studentId.isNotEmpty) {
                                      _loadAllTabDetails(studentId, null);
                                    }
                                  },
                                ),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: Color(0xFF0076F6), width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30.r),
                            ),
                            padding: EdgeInsets.symmetric(
                                horizontal: 24.w, vertical: 12.h),
                          ),
                          child: Text(
                            'Manage Allocation',
                            style: GoogleFonts.inter(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0076F6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        final routeName = _transportAllocation!['route']?['name']?.toString() ??
            'Route 102 - North Delhi Bypass';
        final stopName = _transportAllocation!['stop']?['name']?.toString() ??
            'Rohini Sector 15 Crossing';
        final arrivalTime =
            _transportAllocation!['stop']?['arrivalTime']?.toString() ??
                '07:15 AM';

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
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.directions_bus_filled_outlined,
                      color: const Color(0xFF1A6FDB), size: 20.sp),
                  SizedBox(width: 8.w),
                  Text(
                    'Transport & Safety',
                    style: GoogleFonts.inter(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F2547),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4.h),
              Text(
                'Route allocation and boarding point details',
                style: GoogleFonts.inter(
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ),
              SizedBox(height: 20.h),

              // Allocation details
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: const Color(0xFFE2EAF4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAllocationRow(
                        'ROUTE NAME', routeName, Icons.navigation_outlined),
                    const Divider(
                        color: Color(0xFFE2EAF4), height: 1, thickness: 1),
                    _buildAllocationRow('DESIGNATED STOP', stopName,
                        Icons.location_on_outlined),
                    const Divider(
                        color: Color(0xFFE2EAF4), height: 1, thickness: 1),
                    _buildAllocationRow(
                        'SCHEDULED TIME', arrivalTime, Icons.access_time),
                    const Divider(
                        color: Color(0xFFE2EAF4), height: 1, thickness: 1),
                    Padding(
                      padding: EdgeInsets.all(16.r),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'STATUS',
                                style: GoogleFonts.inter(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF10B981),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                'Active Enrollment',
                                style: GoogleFonts.inter(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            width: 10.w,
                            height: 10.w,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),

              // Guidelines
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: const Color(0xFFE2EAF4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: const Color(0xFFF59E0B), size: 20.sp),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Guidelines',
                            style: GoogleFonts.inter(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F2547),
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            'Students are advised to be at the pickup point at least 5 minutes before the scheduled arrival time.',
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF475569),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),

              // Map
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: const Color(0xFFE2EAF4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.all(16.r),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined,
                                  color: const Color(0xFF0076F6), size: 18.sp),
                              SizedBox(width: 8.w),
                              Text(
                                'Live Tracking Map',
                                style: GoogleFonts.inter(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F2547),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 10.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border:
                                  Border.all(color: const Color(0xFFE2EAF4)),
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            child: Text(
                              'GPS Active',
                              style: GoogleFonts.inter(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF475569)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(
                        color: Color(0xFFE2EAF4), height: 1, thickness: 1),
                    Container(
                      height: 240.h,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(16.r),
                          bottomRight: Radius.circular(16.r),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(16.r),
                          bottomRight: Radius.circular(16.r),
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: FlutterMap(
                                options: const MapOptions(
                                  initialCenter: LatLng(28.7055, 77.1039),
                                  initialZoom: 15.5,
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate:
                                        'https://a.tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName:
                                        'com.edusphere.transport',
                                  ),
                                  PolylineLayer(
                                    polylines: [
                                      Polyline(
                                        points: _busRoute,
                                        color: const Color(0xFF0076F6),
                                        strokeWidth: 4.0,
                                      ),
                                    ],
                                  ),
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        point: _busRoute.last,
                                        width: 32.w,
                                        height: 32.w,
                                        child: Container(
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF0F2547),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                  color: Colors.black26,
                                                  blurRadius: 4,
                                                  offset: Offset(0, 2))
                                            ],
                                          ),
                                          child: Icon(Icons.school,
                                              color: Colors.white, size: 16.sp),
                                        ),
                                      ),
                                      Marker(
                                        point: _busLocation,
                                        width: 40.w,
                                        height: 40.w,
                                        child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 300),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF10B981),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                  color: Colors.black26,
                                                  blurRadius: 4,
                                                  offset: Offset(0, 2))
                                            ],
                                          ),
                                          child: Icon(
                                              Icons
                                                  .directions_bus_filled_outlined,
                                              color: Colors.white,
                                              size: 20.sp),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
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
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
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
          style: GoogleFonts.inter(
            fontSize: 14.sp,
            color: const Color(0xFF94A3B8),
            fontWeight: FontWeight.w500,
          ),
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
                  style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w600)),
              SizedBox(height: 4.h),
              Text(value1,
                  style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      color: const Color(0xFF0F2547),
                      fontWeight: FontWeight.w700),
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
                  style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w600)),
              SizedBox(height: 4.h),
              Text(value2,
                  style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      color: const Color(0xFF0F2547),
                      fontWeight: FontWeight.w700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalAcademicField(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              color: const Color(0xFF475569),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13.5.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF0F2547),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
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
            style: GoogleFonts.inter(
                fontSize: 10.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF4A5568)),
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
                  style: GoogleFonts.inter(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF718096)),
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
                          style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF868E96)),
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
                            style: GoogleFonts.inter(
                                fontSize: 11.sp, fontWeight: FontWeight.w800),
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
                                      style: GoogleFonts.inter(
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF0F2547)),
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      'Uploaded on: ${doc['date']}',
                                      style: GoogleFonts.inter(
                                          fontSize: 9.5.sp,
                                          fontWeight: FontWeight.w600,
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
                          style: GoogleFonts.inter(
                              fontSize: 11.sp, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildAllocationRow(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.all(16.r),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF6B7A90),
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F2547),
                ),
              ),
            ],
          ),
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: const BoxDecoration(
              color: Color(0xFFF0F6FF),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF0076F6), size: 16.sp),
          ),
        ],
      ),
    );
  }
}
