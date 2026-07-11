import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import 'dart:developer' as dev;
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_saver/file_saver.dart';
import '../../utils/download_helper.dart';
import '../../widgets/teacher_app_bar.dart';
import '../../widgets/teacher_scaffold.dart';
import '../main_screen.dart';
import 'class_review_screen.dart';
import 'package:edusphere/theme/typography.dart';
import '../../services/api_service.dart';
import 'dart:async';

class ExamDetailScreen extends StatefulWidget {
  final String examName;
  final String examId;

  const ExamDetailScreen(
      {super.key, required this.examName, required this.examId});

  @override
  State<ExamDetailScreen> createState() => _ExamDetailScreenState();
}

class _ExamDetailScreenState extends State<ExamDetailScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _activeTabIndex =
      0; // 0=Schedule, 1=Marks Entry, 2=Bulk Upload, 3=Overview
  bool _isChatOpen = false;
  bool _isLoading = true;

  final List<String> _tabs = [
    'Schedule',
    'Marks Entry',
    'Bulk Upload',
    'Overview',
  ];

  Map<String, dynamic>? _examData;
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _examResults = [];
  List<Map<String, dynamic>> _examMarks = [];

  // For Marks Entry Tab
  String? _selectedSubjectId;
  final Map<String, TextEditingController> _theoryControllers = {};
  final Map<String, TextEditingController> _pracControllers = {};
  final Map<String, TextEditingController> _intControllers = {};
  final Map<String, bool> _absentStatus = {};
  final Map<String, String> _absenceTypes = {};
  bool _isSavingMarks = false;
  bool _showSuccessBanner = false;

  // For Bulk Upload Tab
  String _uploadedFileName = 'No file chosen';
  bool _isUploading = false;

  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _pollingTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (mounted) {
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    for (var c in _theoryControllers.values) {
      c.dispose();
    }
    for (var c in _pracControllers.values) {
      c.dispose();
    }
    for (var c in _intControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final response = await ApiService.instance.get('exams/${widget.examId}');
      
      if (response != null && response['exam'] != null) {
        _examData = response['exam'];
        final classId = _examData!['classId'];

        final examSubjects = _examData!['examSubjects'] as List<dynamic>? ?? [];
        _subjects = examSubjects.map<Map<String, dynamic>>((es) {
          final sub = es['subject'] as Map<String, dynamic>? ?? {};
          return {
            'id': es['subjectId'] ?? sub['id'],
            'name': sub['name'] ?? 'Subject',
            'code': sub['code'] ?? '',
            'totalMarks': es['totalMarks'] ?? 100,
            'passMarks': es['passMarks'] ?? 33,
            'theoryMaxMarks': es['theoryMaxMarks'] ?? 100,
            'practicalMaxMarks': es['practicalMaxMarks'] ?? 0,
            'internalMaxMarks': es['internalMaxMarks'] ?? 0,
          };
        }).toList();

        final studentsResponse = await ApiService.instance.get('students', queryParams: {
          'classId': classId,
          'status': 'ACTIVE',
          'limit': '100',
        });
        
        if (studentsResponse != null && studentsResponse['students'] != null) {
          _students = List<Map<String, dynamic>>.from(studentsResponse['students']);
          
          _students.sort((a, b) {
            final userA = a['user'] ?? a['User'] as Map?;
            final nameA = '${userA?['firstName'] ?? ''} ${userA?['lastName'] ?? ''}'
                .trim()
                .toLowerCase();

            final userB = b['user'] ?? b['User'] as Map?;
            final nameB = '${userB?['firstName'] ?? ''} ${userB?['lastName'] ?? ''}'
                .trim()
                .toLowerCase();

            return nameA.compareTo(nameB);
          });
        }

        if (_subjects.isNotEmpty && _selectedSubjectId == null) {
          _selectedSubjectId = _subjects[0]['id'] as String;
        }

        // Fetch live consolidated results from production server
        List<dynamic> resultsList = [];
        try {
          final consolidatedResponse =
              await ApiService.instance.get('exams/${widget.examId}/consolidated');
          if (consolidatedResponse != null && consolidatedResponse['results'] != null) {
            resultsList = consolidatedResponse['results'] as List<dynamic>;
          } else {
            resultsList = _examData!['examResults'] as List<dynamic>? ?? [];
          }
        } catch (e) {
          dev.log('Error loading consolidated results, falling back to main: $e', name: 'ExamDetailScreen');
          resultsList = _examData!['examResults'] as List<dynamic>? ?? [];
        }

        _examResults = List<Map<String, dynamic>>.from(resultsList);

        // Fallback for students list from consolidated results if empty
        if (_students.isEmpty && resultsList.isNotEmpty) {
          _students = resultsList.map<Map<String, dynamic>>((r) {
            final String sName = r['studentName']?.toString() ?? 'Student';
            final parts = sName.split(' ');
            return {
              'id': r['studentId']?.toString() ?? '',
              'name': sName,
              'user': {
                'firstName': parts.isNotEmpty ? parts.first : sName,
                'lastName': parts.length > 1 ? parts.sublist(1).join(' ') : '',
              }
            };
          }).toList();
        }

        // Sort students by Rank in increasing order, fallback to alphabetical
        _students.sort((a, b) {
          final studentIdA = a['id'] as String;
          final studentIdB = b['id'] as String;

          final resA = _examResults.firstWhere(
            (r) => r['studentId'] == studentIdA,
            orElse: () => <String, dynamic>{},
          );
          final resB = _examResults.firstWhere(
            (r) => r['studentId'] == studentIdB,
            orElse: () => <String, dynamic>{},
          );

          final rankValA = resA.isNotEmpty ? resA['rank'] : null;
          final rankValB = resB.isNotEmpty ? resB['rank'] : null;

          final double rankA = (rankValA is num)
              ? rankValA.toDouble()
              : double.tryParse(rankValA?.toString() ?? '') ?? 9999.0;
          final double rankB = (rankValB is num)
              ? rankValB.toDouble()
              : double.tryParse(rankValB?.toString() ?? '') ?? 9999.0;

          if (rankA != rankB) {
            return rankA.compareTo(rankB);
          }

          final userA = a['user'] ?? a['User'] as Map?;
          final nameA = '${userA?['firstName'] ?? ''} ${userA?['lastName'] ?? ''}'
              .trim()
              .toLowerCase();
          final userB = b['user'] ?? b['User'] as Map?;
          final nameB = '${userB?['firstName'] ?? ''} ${userB?['lastName'] ?? ''}'
              .trim()
              .toLowerCase();
          return nameA.compareTo(nameB);
        });

        final List<Map<String, dynamic>> consolidatedMarks = [];
        for (var res in _examResults) {
          final studentId = res['studentId']?.toString() ?? '';
          if (studentId.isEmpty) continue;
          final marksList = res['marks'] as List<dynamic>? ?? [];
          for (var m in marksList) {
            consolidatedMarks.add({
              ...m as Map<String, dynamic>,
              'studentId': studentId,
            });
          }
        }
        _examMarks = consolidatedMarks;

        _initializeMarksControllers();
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      dev.log('Error loading exam details data via REST: $e', name: 'ExamDetailScreen');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _initializeMarksControllers() {
    if (_selectedSubjectId == null || _subjects.isEmpty) return;
    final selectedSubject = _subjects.firstWhere(
      (s) => s['id'] == _selectedSubjectId,
      orElse: () => _subjects[0],
    );
    final subjectName = selectedSubject['name'] as String;

    for (var student in _students) {
      final studentId = student['id'] as String;

      final result = _examResults.firstWhere(
        (r) => r['studentId'] == studentId,
        orElse: () => <String, dynamic>{},
      );

      Map<String, dynamic>? existingMark;
      existingMark = _examMarks.firstWhere(
        (m) =>
            m['studentId'] == studentId &&
            m['subjectName'].toString().toLowerCase() ==
                subjectName.toLowerCase(),
        orElse: () => <String, dynamic>{},
      );

      final String theoryVal = existingMark != null && existingMark.isNotEmpty
          ? (existingMark['theoryObtained']?.toString() ?? '0')
          : '0';
      final String pracVal = existingMark != null && existingMark.isNotEmpty
          ? (existingMark['practicalObtained']?.toString() ?? '0')
          : '0';
      final String intVal = existingMark != null && existingMark.isNotEmpty
          ? (existingMark['internalObtained']?.toString() ?? '0')
          : '0';
      final bool absentVal = existingMark != null &&
          existingMark.isNotEmpty &&
          (existingMark['isAbsent'] == true ||
              existingMark['isAbsent'].toString().toLowerCase() == 'true');
      final String absenceTypeVal = existingMark != null &&
              existingMark.isNotEmpty &&
              existingMark['absenceType'] != null
          ? existingMark['absenceType'].toString()
          : 'ABSENT';

      if (_theoryControllers.containsKey(studentId)) {
        _theoryControllers[studentId]!.text = theoryVal;
        _pracControllers[studentId]!.text = pracVal;
        _intControllers[studentId]!.text = intVal;
        _absentStatus[studentId] = absentVal;
        _absenceTypes[studentId] = absenceTypeVal;
      } else {
        _theoryControllers[studentId] = TextEditingController(text: theoryVal);
        _pracControllers[studentId] = TextEditingController(text: pracVal);
        _intControllers[studentId] = TextEditingController(text: intVal);
        _absentStatus[studentId] = absentVal;
        _absenceTypes[studentId] = absenceTypeVal;
      }
    }
  }

  String _computeGrade(num pct) {
    if (pct >= 90) return 'A+';
    if (pct >= 80) return 'A';
    if (pct >= 70) return 'B+';
    if (pct >= 60) return 'B';
    if (pct >= 50) return 'C';
    if (pct >= 33) return 'D';
    return 'F';
  }

  Future<void> _saveMarks() async {
    if (_selectedSubjectId == null || _isSavingMarks || _subjects.isEmpty) {
      return;
    }
    setState(() => _isSavingMarks = true);

    try {
      final List<Map<String, dynamic>> marksList = [];

      for (var student in _students) {
        final studentId = student['id'] as String;
        final isAbsent = _absentStatus[studentId] ?? false;

        final theory = isAbsent
            ? 0
            : (int.tryParse(_theoryControllers[studentId]?.text ?? '0') ?? 0);
        final practical = isAbsent
            ? 0
            : (int.tryParse(_pracControllers[studentId]?.text ?? '0') ?? 0);
        final internal = isAbsent
            ? 0
            : (int.tryParse(_intControllers[studentId]?.text ?? '0') ?? 0);

        final String? absenceType = isAbsent
            ? (_absenceTypes[studentId] ?? 'ABSENT')
            : null;

        marksList.add({
          'studentId': studentId,
          'theoryObtained': theory,
          'practicalObtained': practical,
          'internalObtained': internal,
          'isAbsent': isAbsent,
          'absenceType': absenceType,
        });
      }

      final body = {
        'subjectId': _selectedSubjectId,
        'marks': marksList,
      };

      final response = await ApiService.instance.post('exams/${widget.examId}/marks', body: body);

      if (response != null && response['success'] == true) {
        await _loadData();
        if (mounted) {
          setState(() {
            _showSuccessBanner = true;
          });
          Future.delayed(const Duration(seconds: 4), () {
            if (mounted) {
              setState(() {
                _showSuccessBanner = false;
              });
            }
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(response?['message'] ?? 'Failed to save marks', style: GoogleFonts.inter()),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } catch (e) {
      dev.log('Error saving marks via REST API: $e', name: 'ExamDetailScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error saving marks: $e', style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingMarks = false);
      }
    }
  }

  Future<void> _downloadTemplate() async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];

      final List<CellValue> headerParts = [
        TextCellValue('Admission Number'),
        TextCellValue('Student Name'),
        TextCellValue('Roll Number')
      ];
      for (var s in _subjects) {
        final name = s['name'] as String;
        headerParts.add(TextCellValue('$name Theory'));
        headerParts.add(TextCellValue('$name Practical'));
        headerParts.add(TextCellValue('$name Internal'));
        headerParts.add(TextCellValue('$name Absent(Y/N)'));
      }
      sheet.appendRow(headerParts);

      for (var student in _students) {
        final userData = student['User'] as Map?;
        final firstName = userData?['firstName'] ?? '';
        final lastName = userData?['lastName'] ?? '';
        final studentName = '$firstName $lastName'.trim().isNotEmpty
            ? '$firstName $lastName'
            : (student['name'] ?? 'Student');
        final admissionNumber = student['admissionNumber'] ?? '';
        final rollNumber = student['rollNumber'] ?? student['roll_no'] ?? '';

        final List<CellValue> rowParts = [
          TextCellValue(admissionNumber),
          TextCellValue(studentName),
          TextCellValue(rollNumber.toString()),
        ];

        for (var s in _subjects) {
          final name = s['name'] as String;
          final result = _examResults.firstWhere(
            (r) => r['studentId'] == student['id'],
            orElse: () => <String, dynamic>{},
          );
          Map<String, dynamic>? existingMark;
          if (result.isNotEmpty) {
            existingMark = _examMarks.firstWhere(
              (m) =>
                  m['examResultId'] == result['id'] &&
                  m['subjectName'].toString().toLowerCase() ==
                      name.toLowerCase(),
              orElse: () => <String, dynamic>{},
            );
          }

          if (existingMark != null && existingMark.isNotEmpty) {
            rowParts.add(TextCellValue(
                existingMark['theoryObtained']?.toString() ?? '0'));
            rowParts.add(TextCellValue(
                existingMark['practicalObtained']?.toString() ?? '0'));
            rowParts.add(TextCellValue(
                existingMark['internalObtained']?.toString() ?? '0'));
            rowParts.add(
                TextCellValue(existingMark['isAbsent'] == true ? 'Y' : 'N'));
          } else {
            rowParts.add(TextCellValue('0'));
            rowParts.add(TextCellValue('0'));
            rowParts.add(TextCellValue('0'));
            rowParts.add(TextCellValue('N'));
          }
        }
        sheet.appendRow(rowParts);
      }

      final fileBytes = excel.save();
      if (fileBytes != null) {
        final fileName = '${widget.examName.replaceAll(' ', '_')}_template';
        await downloadFile(
          Uint8List.fromList(fileBytes),
          fileName,
          'xlsx',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Template saved: $fileName.xlsx',
                style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFF2563EB),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
          ));
        }
      }
    } catch (e) {
      dev.log('Error downloading template: $e', name: 'ExamDetailScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('Error saving template: $e', style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _pickAndUploadFile() async {
    setState(() => _isUploading = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        withData: true,
        allowedExtensions: ['csv', 'xlsx'],
      );

      if (result != null && result.files.isNotEmpty) {
        final platformFile = result.files.single;
        final extension = platformFile.extension?.toLowerCase() ?? '';

        setState(() {
          _uploadedFileName = platformFile.name;
        });

        if (extension == 'xlsx') {
          final bytes = kIsWeb
              ? platformFile.bytes!
              : await File(platformFile.path!).readAsBytes();
          final excel = Excel.decodeBytes(bytes);
          final sheetName = excel.tables.keys.first;
          final table = excel.tables[sheetName];
          if (table == null) throw 'Empty Excel file';

          final List<String> csvRows = [];
          for (var row in table.rows) {
            final rowStrings = row.map((c) {
              var val = c?.value?.toString() ?? '';
              return val.replaceAll(',', ' ');
            }).join(',');
            csvRows.add(rowStrings);
          }
          await _parseAndSaveCSV(csvRows.join('\n'));
        } else {
          final content = kIsWeb
              ? String.fromCharCodes(platformFile.bytes!)
              : await File(platformFile.path!).readAsString();
          await _parseAndSaveCSV(content);
        }
      } else {
        setState(() {
          _isUploading = false;
        });
      }
    } catch (e) {
      dev.log('Error picking/uploading file: $e', name: 'ExamDetailScreen');
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error uploading file: $e', style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _parseAndSaveCSV(String content) async {
    try {
      final lines = content
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      if (lines.length < 2) {
        throw 'The CSV file is empty or missing data rows.';
      }

      final headerParts = lines[0].split(',');
      if (headerParts.length < 3) {
        throw 'Invalid CSV header format.';
      }

      final Map<String, int> subjectTheoryIdx = {};
      final Map<String, int> subjectPracIdx = {};
      final Map<String, int> subjectIntIdx = {};
      final Map<String, int> subjectAbsentIdx = {};

      for (var s in _subjects) {
        final sName = s['name'] as String;
        subjectTheoryIdx[sName] = headerParts.indexWhere(
            (h) => h.toLowerCase() == '$sName theory'.toLowerCase());
        subjectPracIdx[sName] = headerParts.indexWhere(
            (h) => h.toLowerCase() == '$sName practical'.toLowerCase());
        subjectIntIdx[sName] = headerParts.indexWhere(
            (h) => h.toLowerCase() == '$sName internal'.toLowerCase());
        subjectAbsentIdx[sName] = headerParts.indexWhere(
            (h) => h.toLowerCase() == '$sName absent(y/n)'.toLowerCase());
      }

      for (var s in _subjects) {
        final sName = s['name'] as String;
        final sId = s['id'] as String;

        final tIdx = subjectTheoryIdx[sName] ?? -1;
        final pIdx = subjectPracIdx[sName] ?? -1;
        final iIdx = subjectIntIdx[sName] ?? -1;
        final abIdx = subjectAbsentIdx[sName] ?? -1;

        final List<Map<String, dynamic>> subjectMarksToSubmit = [];

        for (int i = 1; i < lines.length; i++) {
          final rowParts = lines[i].split(',');
          if (rowParts.length < 3) continue;

          final admissionNumber = rowParts[0].trim();
          final student = _students.firstWhere(
            (s) =>
                s['admissionNumber']?.toString().trim().toLowerCase() ==
                admissionNumber.toLowerCase(),
            orElse: () => <String, dynamic>{},
          );

          if (student.isEmpty) continue;
          final studentId = student['id'] as String;

          final isAbsent = abIdx != -1 &&
              abIdx < rowParts.length &&
              rowParts[abIdx].trim().toUpperCase() == 'Y';

          final theory = (!isAbsent && tIdx != -1 && tIdx < rowParts.length)
              ? (int.tryParse(rowParts[tIdx].trim()) ?? 0)
              : 0;
          final practical = (!isAbsent && pIdx != -1 && pIdx < rowParts.length)
              ? (int.tryParse(rowParts[pIdx].trim()) ?? 0)
              : 0;
          final internal = (!isAbsent && iIdx != -1 && iIdx < rowParts.length)
              ? (int.tryParse(rowParts[iIdx].trim()) ?? 0)
              : 0;

          subjectMarksToSubmit.add({
            'studentId': studentId,
            'theoryObtained': theory,
            'practicalObtained': practical,
            'internalObtained': internal,
            'isAbsent': isAbsent,
          });
        }

        if (subjectMarksToSubmit.isNotEmpty) {
          final body = {
            'subjectId': sId,
            'marks': subjectMarksToSubmit,
          };
          await ApiService.instance.post('exams/${widget.examId}/marks', body: body);
        }
      }

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Marks imported and processed successfully!',
              style: GoogleFonts.inter()),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      dev.log('Error parsing/saving CSV: $e', name: 'ExamDetailScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error parsing CSV: $e', style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _toggleChat() {
    setState(() {
      _isChatOpen = !_isChatOpen;
    });
  }

  String abbreviateSubject(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('social')) return 'Soc';
    if (lower.contains('science') || lower.contains('sci')) return 'Sci';
    if (lower.contains('math')) return 'Mat';
    if (lower.contains('english') || lower.contains('eng')) return 'Eng';
    if (lower.contains('hindi') || lower.contains('hin')) return 'Hin';
    return name.length > 3 ? name.substring(0, 3) : name;
  }

  String formatPct(double pct) {
    if (pct == pct.toInt()) {
      return '${pct.toInt()}%';
    }
    return '${pct.toString()}%';
  }

  @override
  Widget build(BuildContext context) {
    String subtitle = 'Class Schedule';
    if (_examData != null) {
      final classData = _examData!['class'] ?? _examData!['Class'];
      final ayData = _examData!['academicYear'] ?? _examData!['AcademicYear'];
      final className = (classData?['name']?.toString() ?? 'Class')
          .replaceAll('Class', 'Grade');
      final ayName =
          ayData?['name']?.toString() ?? '2024-2025';
      subtitle = '$className • $ayName';
    }

    final bodyContent = _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB)))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding:
                    EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: EdgeInsets.all(4.r),
                            child: Icon(Icons.arrow_back_rounded,
                                size: 24.sp,
                                color: const Color(0xFF0F172A)),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.examName,
                                style: GoogleFonts.outfit(
                                  fontSize: 22.sp,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                subtitle,
                                style: AppTypography.caption.copyWith(
                                    color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 14.h),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFFEFF6FF),
                        side: const BorderSide(color: Color(0xFFDBEAFE)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r)),
                        padding: EdgeInsets.symmetric(
                            horizontal: 16.w, vertical: 10.h),
                      ),
                      icon: Icon(Icons.assignment_outlined,
                          size: 16.sp, color: const Color(0xFF1E40AF)),
                      label: Text(
                        'Class Review',
                        style: AppTypography.caption
                            .copyWith(color: const Color(0xFF1E40AF)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ClassReviewScreen(
                              examId: widget.examId,
                              examName: widget.examName,
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 18.h),
                    _buildTabs(),
                    SizedBox(height: 18.h),
                    if (_activeTabIndex == 0) _buildScheduleTab(),
                    if (_activeTabIndex == 1) _buildMarksEntryTab(),
                    if (_activeTabIndex == 2) _buildBulkUploadTab(),
                    if (_activeTabIndex == 3) _buildOverviewTab(),
                    SizedBox(height: 100.h),
                  ],
                ),
              ),
            );

    return TeacherScaffold(
      scaffoldKey: _scaffoldKey,
      title: 'EduSphere',
      activeIndex: 8,
      body: bodyContent,
    );
  }



  Widget _buildTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: EdgeInsets.all(4.r),
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(24.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: _tabs.asMap().entries.map((entry) {
            final idx = entry.key;
            final label = entry.value;
            final isActive = idx == _activeTabIndex;

            return GestureDetector(
              onTap: () {
                setState(() => _activeTabIndex = idx);
                if (idx == 3) {
                  _loadData();
                }
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: isActive ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(20.r),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Text(
                  label,
                  style: AppTypography.caption.copyWith(
                      color: isActive
                          ? const Color(0xFF0F172A)
                          : const Color(0xFF475569)),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildScheduleTab() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: EdgeInsets.all(24.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Subject Schedule',
            style: GoogleFonts.outfit(
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 24.h),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _buildScheduleTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 800.w,
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
          child: Row(
            children: [
              Expanded(flex: 3, child: Text('Subject', style: _headerStyle())),
              Expanded(flex: 2, child: Text('Date', style: _headerStyle())),
              Expanded(flex: 2, child: Text('Time', style: _headerStyle())),
              Expanded(flex: 2, child: Text('Theory', style: _headerStyle())),
              Expanded(
                  flex: 2, child: Text('Practical', style: _headerStyle())),
              Expanded(flex: 2, child: Text('Internal', style: _headerStyle())),
              Expanded(flex: 2, child: Text('Total', style: _headerStyle())),
            ],
          ),
        ),
        if (_subjects.isEmpty)
          Container(
            width: 800.w,
            padding: EdgeInsets.symmetric(vertical: 32.h),
            child: Center(
              child: Text(
                'No subjects configured for this class.',
                style: AppTypography.caption
                    .copyWith(color: const Color(0xFF64748B)),
              ),
            ),
          )
        else
          ..._subjects.asMap().entries.map((entry) {
            final idx = entry.key;
            final s = entry.value;
            final isLast = idx == _subjects.length - 1;

            final subjectName = s['name'] as String? ?? 'Subject';

            final startDateStr = _examData?['startDate']?.toString();
            String displayDate = '10/09/2024';
            String displayTime = '09:00';
            if (startDateStr != null) {
              try {
                final parsedDate = DateTime.parse(startDateStr)
                    .toLocal()
                    .add(Duration(days: idx));
                displayDate = intl.DateFormat('dd/MM/yyyy').format(parsedDate);
                displayTime = intl.DateFormat('HH:mm').format(parsedDate);
              } catch (_) {}
            }

            final totalMarks = (s['totalMarks'] as num? ?? 100).toInt();
            final theory = (totalMarks * 0.8).toInt();
            final internal = (totalMarks * 0.2).toInt();
            const practical = 0;

            return Container(
              width: 800.w,
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 16.h),
              decoration: BoxDecoration(
                color: Colors.white,
                border: isLast
                    ? null
                    : const Border(
                        bottom: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      subjectName,
                      style: AppTypography.caption
                          .copyWith(color: const Color(0xFF0F172A)),
                    ),
                  ),
                  Expanded(
                      flex: 2, child: Text(displayDate, style: _cellStyle())),
                  Expanded(
                      flex: 2, child: Text(displayTime, style: _cellStyle())),
                  Expanded(
                      flex: 2, child: Text('$theory', style: _cellStyle())),
                  Expanded(
                      flex: 2, child: Text('$practical', style: _cellStyle())),
                  Expanded(
                      flex: 2, child: Text('$internal', style: _cellStyle())),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '$totalMarks',
                      style: AppTypography.caption
                          .copyWith(color: const Color(0xFF0F172A)),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  TextStyle _headerStyle() {
    return AppTypography.caption.copyWith(color: const Color(0xFF64748B));
  }

  TextStyle _cellStyle() {
    return AppTypography.caption.copyWith(color: const Color(0xFF334155));
  }

  Widget _buildOverviewTab() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: EdgeInsets.all(24.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Consolidated View',
            style: GoogleFonts.outfit(
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 24.h),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _buildOverviewTable(),
          ),
        ],
      ),
    );
  }

  Widget _tableCell(Widget child, double width,
      {bool hasBottomBorder = true,
      Alignment alignment = Alignment.centerLeft}) {
    return Container(
      width: width,
      constraints: BoxConstraints(minHeight: 52.h),
      alignment: alignment,
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
      decoration: BoxDecoration(
        border: Border(
          bottom: hasBottomBorder
              ? const BorderSide(color: Color(0xFFE2E8F0))
              : BorderSide.none,
        ),
      ),
      child: child,
    );
  }

  Widget _headerCell(String text, double width,
      {Alignment alignment = Alignment.centerLeft}) {
    return Container(
      width: width,
      height: 40.h,
      alignment: alignment,
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Text(
        text,
        style: _headerStyle(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildOverviewTable() {
    final bool isLandscape = MediaQuery.of(context).size.width > 500;

    final List<Map<String, dynamic>> activeSubjects = _subjects;

    final double rankWidth = 50.w;
    final double studentWidth = 160.w;
    final double subjectWidth = 70.w;
    final double totalWidth = 70.w;
    final double pctWidth = 70.w;
    final double gradeWidth = 70.w;

    final double tableWidth = rankWidth +
        studentWidth +
        (activeSubjects.length * subjectWidth) +
        totalWidth +
        pctWidth +
        gradeWidth +
        6.w;

    return Container(
      width: tableWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          // Header row
          Row(
            children: [
              _headerCell('Rank', rankWidth, alignment: Alignment.center),
              _headerCell('Student', studentWidth),
              ...activeSubjects.map((s) {
                return _headerCell(
                    abbreviateSubject(s['name'] as String), subjectWidth,
                    alignment: Alignment.center);
              }),
              _headerCell('Total', totalWidth, alignment: Alignment.center),
              _headerCell('%', pctWidth, alignment: Alignment.center),
              _headerCell('Grade', gradeWidth, alignment: Alignment.center),
            ],
          ),

          // Data rows
          if (_students.isEmpty)
            Container(
              width: tableWidth,
              padding: EdgeInsets.symmetric(vertical: 32.h),
              child: Center(
                child: Text(
                  'No active students in this class.',
                  style: AppTypography.caption
                      .copyWith(color: const Color(0xFF64748B)),
                ),
              ),
            )
          else
            ..._students.asMap().entries.map((entry) {
              final idx = entry.key;
              final student = entry.value;
              final studentId = student['id'] as String;
              final isLast = idx == _students.length - 1;

              // Find the student's result
              final res = _examResults.firstWhere(
                (r) => r['studentId'] == studentId,
                orElse: () => <String, dynamic>{},
              );

              final userData = (student['user'] ?? student['User']) as Map?;
              final firstName = userData?['firstName'] ?? '';
              final lastName = userData?['lastName'] ?? '';
              final studentName = res.isNotEmpty && res['studentName'] != null
                  ? res['studentName']
                  : ('$firstName $lastName'.trim().isNotEmpty
                      ? '$firstName $lastName'
                      : (student['name'] ?? 'Student'));

              final rank =
                  res.isNotEmpty ? (res['rank']?.toString() ?? '-') : '-';
              final pctDouble = res.isNotEmpty
                  ? (res['percentage'] as num? ?? 0.0).toDouble()
                  : null;
              final totalObtained = res.isNotEmpty
                  ? (res['obtainedMarks']?.toString() ?? '-')
                  : '-';
              final grade =
                  res.isNotEmpty ? (res['grade']?.toString() ?? '-') : '-';

              final studentMarks = _examMarks
                  .where((m) => m['studentId'] == studentId)
                  .toList();

              return Row(
                children: [
                  _tableCell(
                    Text(
                      rank,
                      style: AppTypography.caption.copyWith(
                        color: const Color(0xFF0F172A),
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    rankWidth,
                    hasBottomBorder: !isLast,
                    alignment: Alignment.center,
                  ),
                  _tableCell(
                    Text(
                      studentName,
                      style: AppTypography.caption
                          .copyWith(color: const Color(0xFF334155)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    studentWidth,
                    hasBottomBorder: !isLast,
                  ),
                  ...activeSubjects.map((s) {
                    final subjectId = s['id']?.toString() ?? '';
                    final name = s['name'] as String;
                    final mark = studentMarks.firstWhere(
                      (m) =>
                          m['subjectId']?.toString() == subjectId ||
                          m['subjectName'].toString().toLowerCase() ==
                              name.toLowerCase(),
                      orElse: () => <String, dynamic>{},
                    );
                    final isMarkAbsent = mark.isNotEmpty &&
                        (mark['isAbsent'] == true ||
                            mark['isAbsent'].toString().toLowerCase() ==
                                'true');
                    final displayMark = mark.isNotEmpty
                        ? (isMarkAbsent
                            ? 'AB'
                            : mark['obtainedMarks']?.toString() ?? '-')
                        : '-';
                    return _tableCell(
                      Text(
                        displayMark,
                        style: _cellStyle().copyWith(
                          color: isMarkAbsent
                              ? const Color(0xFF64748B)
                              : const Color(0xFF0F172A),
                          fontWeight:
                              isMarkAbsent ? FontWeight.normal : FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subjectWidth,
                      hasBottomBorder: !isLast,
                      alignment: Alignment.center,
                    );
                  }),
                  _tableCell(
                    Text(
                      totalObtained,
                      style: AppTypography.caption.copyWith(
                        color: const Color(0xFF0F172A),
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    totalWidth,
                    hasBottomBorder: !isLast,
                    alignment: Alignment.center,
                  ),
                  _tableCell(
                    Text(
                      pctDouble != null ? formatPct(pctDouble) : '-',
                      style: _cellStyle(),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                    ),
                    pctWidth,
                    hasBottomBorder: !isLast,
                    alignment: Alignment.center,
                  ),
                  _tableCell(
                    Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 8.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Text(
                          grade,
                          style: AppTypography.caption.copyWith(
                            color: const Color(0xFF334155),
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    gradeWidth,
                    hasBottomBorder: !isLast,
                    alignment: Alignment.center,
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }
  Widget _buildMarksEntryTab() {
    if (_subjects.isEmpty) {
      return const Center(
          child: Text('No subjects configured for this class.'));
    }

    final selectedSubject = _subjects.firstWhere(
      (s) => s['id'] == _selectedSubjectId,
      orElse: () => _subjects[0],
    );
    final theoryMax =
        (selectedSubject['theoryMaxMarks'] as num? ?? 100).toInt();
    final practicalMax =
        (selectedSubject['practicalMaxMarks'] as num? ?? 0).toInt();
    final internalMax =
        (selectedSubject['internalMaxMarks'] as num? ?? 0).toInt();

    final double studentWidth = 200.w;
    final double theoryWidth = 100.w;
    final double pracWidth = 100.w;
    final double intWidth = 100.w;
    final double totalWidth = 80.w;
    final double statusWidth = 160.w;

    final double tableWidth = studentWidth +
        theoryWidth +
        pracWidth +
        intWidth +
        totalWidth +
        statusWidth +
        6.w;

    // Check for any validation errors to disable Save button
    bool hasValidationError = false;
    for (var student in _students) {
      final studentId = student['id'] as String;
      final isAbsent = _absentStatus[studentId] ?? false;
      if (!isAbsent) {
        final theory =
            int.tryParse(_theoryControllers[studentId]?.text ?? '') ?? 0;
        final practical =
            int.tryParse(_pracControllers[studentId]?.text ?? '') ?? 0;
        final internal =
            int.tryParse(_intControllers[studentId]?.text ?? '') ?? 0;

        if (theoryMax > 0 && theory > theoryMax) {
          hasValidationError = true;
        }
        if (practicalMax > 0 && practical > practicalMax) {
          hasValidationError = true;
        }
        if (internalMax > 0 && internal > internalMax) {
          hasValidationError = true;
        }
      }
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: EdgeInsets.all(20.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(builder: (context, headerConstraints) {
            final isMobile = headerConstraints.maxWidth < 600;
            final children = [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manual Marks Entry',
                    style: GoogleFonts.outfit(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Enter student marks for the selected subject.',
                    style: AppTypography.caption
                        .copyWith(color: const Color(0xFF64748B)),
                  ),
                ],
              ),
              if (isMobile) SizedBox(height: 16.h) else const Spacer(),
              Row(
                mainAxisAlignment: isMobile
                    ? MainAxisAlignment.spaceBetween
                    : MainAxisAlignment.end,
                children: [
                  isMobile
                      ? Expanded(
                          child: SizedBox(
                            height: 42.h,
                            child: DropdownButtonHideUnderline(
                              child: DropdownButtonFormField<String>(
                                value: _selectedSubjectId,
                                isDense: true,
                                style: AppTypography.caption
                                    .copyWith(color: const Color(0xFF0F172A)),
                                decoration: InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10.w, vertical: 6.h),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.r),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFE2E8F0)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.r),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFE2E8F0)),
                                  ),
                                ),
                                items: _subjects.map((s) {
                                  return DropdownMenuItem(
                                    value: s['id'] as String,
                                    child: Text(
                                      s['name'] as String,
                                      style: AppTypography.caption,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedSubjectId = val;
                                    _initializeMarksControllers();
                                  });
                                },
                              ),
                            ),
                          ),
                        )
                      : SizedBox(
                          width: 160.w,
                          height: 42.h,
                          child: DropdownButtonHideUnderline(
                            child: DropdownButtonFormField<String>(
                              value: _selectedSubjectId,
                              isDense: true,
                              style: AppTypography.caption
                                  .copyWith(color: const Color(0xFF0F172A)),
                              decoration: InputDecoration(
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10.w, vertical: 8.h),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFE2E8F0)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFE2E8F0)),
                                ),
                              ),
                              items: _subjects.map((s) {
                                return DropdownMenuItem(
                                  value: s['id'] as String,
                                  child: Text(
                                    s['name'] as String,
                                    style: AppTypography.caption,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                    _selectedSubjectId = val;
                                    _initializeMarksControllers();
                                });
                              },
                            ),
                          ),
                        ),
                  SizedBox(width: 12.w),
                  GestureDetector(
                    onTap: (hasValidationError || _isSavingMarks)
                        ? null
                        : _saveMarks,
                    child: Container(
                      height: 42.h,
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      decoration: BoxDecoration(
                        color: hasValidationError
                            ? const Color(0xFF93C5FD)
                            : const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      alignment: Alignment.center,
                      child: _isSavingMarks
                          ? SizedBox(
                              width: 16.w,
                              height: 16.w,
                              child: const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Row(
                              children: [
                                Icon(Icons.save_rounded,
                                    color: Colors.white, size: 16.sp),
                                SizedBox(width: 6.w),
                                Text(
                                  'Save All',
                                  style: AppTypography.small
                                      .copyWith(color: Colors.white),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ];

            return isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: children,
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: children,
                  );
          }),
          SizedBox(height: 24.h),
          if (_showSuccessBanner) ...[
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              margin: EdgeInsets.only(bottom: 16.h),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: const Color(0xFFDCFCE7)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_box_outlined,
                    color: const Color(0xFF15803D),
                    size: 18.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'Marks saved successfully',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF15803D),
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              width: tableWidth,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              clipBehavior: Clip.hardEdge,
              child: Column(
                children: [
                  Row(
                    children: [
                      _headerCell('Student', studentWidth),
                      _headerCell('Theory ($theoryMax)', theoryWidth,
                          alignment: Alignment.center),
                      _headerCell('Prac ($practicalMax)', pracWidth,
                          alignment: Alignment.center),
                      _headerCell('Int ($internalMax)', intWidth,
                          alignment: Alignment.center),
                      _headerCell('Total', totalWidth,
                          alignment: Alignment.center),
                      _headerCell('Status', statusWidth),
                    ],
                  ),
                  if (_students.isEmpty)
                    Container(
                      width: tableWidth,
                      padding: EdgeInsets.symmetric(vertical: 32.h),
                      child: Center(
                        child: Text(
                          'No active students in this class.',
                          style: AppTypography.caption
                              .copyWith(color: const Color(0xFF64748B)),
                        ),
                      ),
                    )
                  else
                    ..._students.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final student = entry.value;
                      final studentId = student['id'] as String;
                      final isLast = idx == _students.length - 1;
                      final isAbsent = _absentStatus[studentId] ?? false;

                      final userData =
                          (student['user'] ?? student['User']) as Map?;
                      final firstName = userData?['firstName'] ?? '';
                      final lastName = userData?['lastName'] ?? '';
                      final studentName =
                          '$firstName $lastName'.trim().isNotEmpty
                              ? '$firstName $lastName'
                              : (student['name'] ?? 'Student');
                      final admissionNumber = student['admissionNumber'] ??
                          student['admissionNo'] ??
                          '';

                      final theoryObtained = isAbsent
                          ? 0
                          : (int.tryParse(
                                  _theoryControllers[studentId]?.text ?? '') ??
                              0);
                      final pracObtained = isAbsent
                          ? 0
                          : (int.tryParse(
                                  _pracControllers[studentId]?.text ?? '') ??
                              0);
                      final intObtained = isAbsent
                          ? 0
                          : (int.tryParse(
                                  _intControllers[studentId]?.text ?? '') ??
                              0);
                      final totalObtained =
                          theoryObtained + pracObtained + intObtained;

                      final isTheoryInvalid =
                          !isAbsent && theoryMax > 0 && theoryObtained > theoryMax;
                      final isPracInvalid =
                          !isAbsent && practicalMax > 0 && pracObtained > practicalMax;
                      final isIntInvalid =
                          !isAbsent && internalMax > 0 && intObtained > internalMax;

                      return Row(
                        children: [
                          _tableCell(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  studentName,
                                  style: AppTypography.caption.copyWith(
                                    color: const Color(0xFF0F172A),
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (admissionNumber.toString().isNotEmpty) ...[
                                  SizedBox(height: 2.h),
                                  Text(
                                    admissionNumber.toString(),
                                    style: AppTypography.caption.copyWith(
                                      color: const Color(0xFF64748B),
                                      fontSize: 10.sp,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            studentWidth,
                            hasBottomBorder: !isLast,
                          ),
                          _tableCell(
                            Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 4.w, vertical: 4.h),
                              child: TextField(
                                controller: _theoryControllers[studentId],
                                keyboardType: TextInputType.number,
                                enabled: !isAbsent,
                                style: AppTypography.caption,
                                textAlign: TextAlign.center,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 6.w, vertical: 6.h),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6.r),
                                    borderSide: BorderSide(
                                        color: isTheoryInvalid
                                            ? const Color(0xFFEF4444)
                                            : const Color(0xFFCBD5E1)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6.r),
                                    borderSide: BorderSide(
                                        color: isTheoryInvalid
                                            ? const Color(0xFFEF4444)
                                            : const Color(0xFFE2E8F0)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6.r),
                                    borderSide: BorderSide(
                                        color: isTheoryInvalid
                                            ? const Color(0xFFEF4444)
                                            : const Color(0xFF2563EB),
                                        width: 2),
                                  ),
                                  fillColor: isAbsent
                                      ? const Color(0xFFF1F5F9)
                                      : Colors.white,
                                  filled: true,
                                  errorText: isTheoryInvalid
                                      ? 'Max $theoryMax'
                                      : null,
                                  errorStyle: TextStyle(
                                    color: const Color(0xFFEF4444),
                                    fontSize: 9.sp,
                                    height: 0.8,
                                  ),
                                ),
                              ),
                            ),
                            theoryWidth,
                            hasBottomBorder: !isLast,
                            alignment: Alignment.center,
                          ),
                          _tableCell(
                            Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 4.w, vertical: 4.h),
                              child: TextField(
                                controller: _pracControllers[studentId],
                                keyboardType: TextInputType.number,
                                enabled: !isAbsent,
                                style: AppTypography.caption,
                                textAlign: TextAlign.center,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 6.w, vertical: 6.h),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6.r),
                                    borderSide: BorderSide(
                                        color: isPracInvalid
                                            ? const Color(0xFFEF4444)
                                            : const Color(0xFFCBD5E1)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6.r),
                                    borderSide: BorderSide(
                                        color: isPracInvalid
                                            ? const Color(0xFFEF4444)
                                            : const Color(0xFFE2E8F0)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6.r),
                                    borderSide: BorderSide(
                                        color: isPracInvalid
                                            ? const Color(0xFFEF4444)
                                            : const Color(0xFF2563EB),
                                        width: 2),
                                  ),
                                  fillColor: isAbsent
                                      ? const Color(0xFFF1F5F9)
                                      : Colors.white,
                                  filled: true,
                                  errorText:
                                      isPracInvalid ? 'Max $practicalMax' : null,
                                  errorStyle: TextStyle(
                                    color: const Color(0xFFEF4444),
                                    fontSize: 9.sp,
                                    height: 0.8,
                                  ),
                                ),
                              ),
                            ),
                            pracWidth,
                            hasBottomBorder: !isLast,
                            alignment: Alignment.center,
                          ),
                          _tableCell(
                            Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 4.w, vertical: 4.h),
                              child: TextField(
                                controller: _intControllers[studentId],
                                keyboardType: TextInputType.number,
                                enabled: !isAbsent,
                                style: AppTypography.caption,
                                textAlign: TextAlign.center,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 6.w, vertical: 6.h),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6.r),
                                    borderSide: BorderSide(
                                        color: isIntInvalid
                                            ? const Color(0xFFEF4444)
                                            : const Color(0xFFCBD5E1)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6.r),
                                    borderSide: BorderSide(
                                        color: isIntInvalid
                                            ? const Color(0xFFEF4444)
                                            : const Color(0xFFE2E8F0)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6.r),
                                    borderSide: BorderSide(
                                        color: isIntInvalid
                                            ? const Color(0xFFEF4444)
                                            : const Color(0xFF2563EB),
                                        width: 2),
                                  ),
                                  fillColor: isAbsent
                                      ? const Color(0xFFF1F5F9)
                                      : Colors.white,
                                  filled: true,
                                  errorText:
                                      isIntInvalid ? 'Max $internalMax' : null,
                                  errorStyle: TextStyle(
                                    color: const Color(0xFFEF4444),
                                    fontSize: 9.sp,
                                    height: 0.8,
                                  ),
                                ),
                              ),
                            ),
                            intWidth,
                            hasBottomBorder: !isLast,
                            alignment: Alignment.center,
                          ),
                           _tableCell(
                            Builder(
                              builder: (context) {
                                final String totalDisplay =
                                    isAbsent ? 'AB' : '$totalObtained';
                                return Text(
                                  totalDisplay,
                                  style: AppTypography.caption.copyWith(
                                    color: const Color(0xFF0F172A),
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              }
                            ),
                            totalWidth,
                            hasBottomBorder: !isLast,
                            alignment: Alignment.center,
                          ),
                          _tableCell(
                            Row(
                              children: [
                                Checkbox(
                                  value: isAbsent,
                                  activeColor: const Color(0xFF2563EB),
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  onChanged: (val) {
                                    setState(() {
                                      _absentStatus[studentId] = val ?? false;
                                      if (val == true &&
                                          (_absenceTypes[studentId] == null ||
                                              _absenceTypes[studentId]!.isEmpty)) {
                                        _absenceTypes[studentId] = 'ABSENT';
                                      }
                                    });
                                  },
                                ),
                                SizedBox(width: 4.w),
                                isAbsent
                                    ? Container(
                                        height: 28.h,
                                        padding:
                                            EdgeInsets.symmetric(horizontal: 4.w),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                              color: const Color(0xFFCBD5E1)),
                                          borderRadius:
                                              BorderRadius.circular(4.r),
                                          color: Colors.white,
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: _absenceTypes[studentId] ??
                                                'ABSENT',
                                            isDense: true,
                                            style:
                                                AppTypography.caption.copyWith(
                                              color: const Color(0xFF0F172A),
                                              fontSize: 11.sp,
                                            ),
                                            items: const [
                                              DropdownMenuItem(
                                                value: 'ABSENT',
                                                child: Text('Absent'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'MEDICAL',
                                                child: Text('Medical'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'EXEMPTED',
                                                child: Text('Exempt'),
                                              ),
                                            ],
                                            onChanged: (val) {
                                              if (val != null) {
                                                setState(() {
                                                  _absenceTypes[studentId] =
                                                      val;
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                      )
                                    : Text(
                                        'Mark Absent',
                                        style: AppTypography.caption.copyWith(
                                          color: const Color(0xFF334155),
                                          fontSize: 11.sp,
                                        ),
                                      ),
                              ],
                            ),
                            statusWidth,
                            hasBottomBorder: !isLast,
                          ),
                        ],
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

  Widget _buildBulkUploadTab() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(24.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Excel Bulk Upload',
            style: GoogleFonts.outfit(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Upload marks using Excel',
            style:
                AppTypography.caption.copyWith(color: const Color(0xFF64748B)),
          ),
          SizedBox(height: 24.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.download_rounded,
                        size: 20.sp, color: const Color(0xFF0F172A)),
                    SizedBox(width: 8.w),
                    Text(
                      '1. Download Template',
                      style: AppTypography.small
                          .copyWith(color: const Color(0xFF0F172A)),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEFF6FF), // light blue
                    elevation: 0,
                    side: const BorderSide(color: Color(0xFFDBEAFE)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r)),
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                  ),
                  onPressed: _downloadTemplate,
                  child: Text(
                    'Download XLSX',
                    style: AppTypography.caption
                        .copyWith(color: const Color(0xFF1E40AF)),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 18.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.upload_rounded,
                        size: 20.sp, color: const Color(0xFF0F172A)),
                    SizedBox(width: 8.w),
                    Text(
                      '2. Upload File',
                      style: AppTypography.small
                          .copyWith(color: const Color(0xFF0F172A)),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                _isUploading
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: Color(0xFF2563EB)))
                    : Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                            horizontal: 12.w, vertical: 10.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                elevation: 0,
                                side:
                                    const BorderSide(color: Color(0xFFCBD5E1)),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6.r)),
                                padding: EdgeInsets.symmetric(
                                    horizontal: 12.w, vertical: 8.h),
                              ),
                              onPressed: _pickAndUploadFile,
                              child: Text(
                                'Choose file',
                                style: AppTypography.caption
                                    .copyWith(color: const Color(0xFF475569)),
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Text(
                                _uploadedFileName,
                                style: AppTypography.caption
                                    .copyWith(color: const Color(0xFF475569)),
                                overflow: TextOverflow.ellipsis,
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
}
