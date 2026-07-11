import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edusphere/services/api_service.dart';
import 'dart:developer' as dev;
import 'package:edusphere/theme/typography.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:edusphere/config/api_config.dart';
import 'package:edusphere/widgets/teacher_scaffold.dart';

class ClassReviewScreen extends StatefulWidget {
  final String examId;
  final String examName;

  const ClassReviewScreen({
    super.key,
    required this.examId,
    required this.examName,
  });

  @override
  State<ClassReviewScreen> createState() => _ClassReviewScreenState();
}

class _ClassReviewScreenState extends State<ClassReviewScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoading = true;
  bool _isChatOpen = false;

  Map<String, dynamic>? _examData;
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _examResults = [];
  List<Map<String, dynamic>> _examMarks = [];

  // Table selection state
  Set<String> _selectedStudentIds = {};

  // Teacher info
  String _teacherFirstName = 'KARAN';

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadTeacherName();
  }

  Future<void> _loadTeacherName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString('teacher_name') ?? prefs.getString('user_name') ?? 'KARAN';
      final firstWord = savedName.trim().split(' ').first;
      if (mounted) {
        setState(() {
          _teacherFirstName = firstWord.toUpperCase();
        });
      }
    } catch (_) {}
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final res = await ApiService.instance.get('exams/${widget.examId}/consolidated');
      final reportCardsRes = await ApiService.instance.get('report-cards', queryParams: {'examId': widget.examId});

      final List<dynamic> reportCardsList = (reportCardsRes != null && reportCardsRes['reportCards'] != null)
          ? reportCardsRes['reportCards'] as List<dynamic>
          : [];

      if (res != null && res['success'] == true) {
        final examObj = res['exam'] as Map<String, dynamic>;
        _examData = {
          'id': examObj['id'],
          'name': examObj['name'],
          'status': examObj['status'],
          'isFrozen': examObj['isFrozen'],
          'Class': {
            'name': examObj['className'],
          },
          'AcademicYear': {
            'name': examObj['academicYear'],
          }
        };

        final subjectProgressList = res['subjectProgress'] as List? ?? [];
        _subjects = subjectProgressList.map<Map<String, dynamic>>((sp) {
          return {
            'id': sp['subjectId'],
            'name': sp['subjectName'],
            'code': sp['subjectCode'],
            'totalMarks': sp['totalMarks'] ?? 100,
          };
        }).toList();

        final resultsList = res['results'] as List? ?? [];
        _students = resultsList.map<Map<String, dynamic>>((r) {
          final name = r['studentName']?.toString() ?? '';
          return {
            'id': r['studentId'],
            'name': name,
            'User': {
              'firstName': name,
              'lastName': '',
            }
          };
        }).toList();

        _examResults = [];
        _examMarks = [];
        for (var r in resultsList) {
          final studentId = r['studentId'] as String;

          final reportCard = reportCardsList.firstWhere(
            (rc) => rc['studentId'] == studentId,
            orElse: () => null,
          );

          final resId = reportCard != null ? reportCard['id']?.toString() ?? '' : '';
          final isPublished = reportCard != null && (reportCard['status'] == 'PUBLISHED');

          _examResults.add({
            'id': resId,
            'studentId': studentId,
            'percentage': r['percentage'],
            'obtainedMarks': r['obtainedMarks'],
            'result': r['result'],
            'isPublished': isPublished,
          });
          if (r['marks'] != null) {
            for (var mk in r['marks']) {
              _examMarks.add({
                'id': mk['id']?.toString() ?? '',
                'examResultId': resId,
                'studentId': studentId,
                'subjectName': mk['subjectName'],
                'obtainedMarks': mk['obtainedMarks'],
                'isAbsent': mk['isAbsent'] ?? false,
                'absenceType': mk['absenceType'],
              });
            }
          }
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      dev.log('Error loading class review data: $e', name: 'ClassReviewScreen');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitForApproval() async {
    try {
      final response = await ApiService.instance.put(
        'exams/${widget.examId}',
        body: {'status': 'PENDING'},
      );
      if (response != null && response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Exam submitted for approval successfully!'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ));
        }
      } else {
        throw Exception(response?['message'] ?? 'Failed to submit exam');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to submit for approval: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _generateReportCards() async {
    if (_selectedStudentIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select at least one student to generate report cards.'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.instance.post(
        'report-cards/generate',
        body: {
          'examId': widget.examId,
          'studentIds': _selectedStudentIds.toList(),
        },
      );
      if (response != null && response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Report cards generated successfully!'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ));
        }
        await _loadData();
      } else {
        throw Exception(response?['message'] ?? 'Failed to generate report cards');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to generate report cards: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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

  String getSubjectHeader(Map<String, dynamic> subject) {
    final name = subject['name'] as String? ?? '';
    final code = subject['code']?.toString().toUpperCase() ?? '';
    final headerName = code.isNotEmpty ? code : abbreviateSubject(name).toUpperCase();
    final totalMarks = (subject['totalMarks'] as num? ?? 100).toInt().toString();
    return '$headerName ($totalMarks)';
  }

  bool get _isAllSelected =>
      _selectedStudentIds.length == _students.length && _students.isNotEmpty;

  void _toggleSelectAll() {
    setState(() {
      if (_isAllSelected) {
        _selectedStudentIds.clear();
      } else {
        _selectedStudentIds = _students.map((s) => s['id'] as String).toSet();
      }
    });
  }

  void _toggleSelectStudent(String studentId) {
    setState(() {
      if (_selectedStudentIds.contains(studentId)) {
        _selectedStudentIds.remove(studentId);
      } else {
        _selectedStudentIds.add(studentId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isWide = MediaQuery.of(context).size.width > 800;

    String className = 'Grade 8';
    String ayName = '2024-2025';
    if (_examData != null) {
      className = (_examData!['Class']?['name']?.toString() ?? 'Class')
          .replaceAll('Class', 'Grade');
      ayName = _examData!['AcademicYear']?['name']?.toString() ?? '2024-2025';
    }

    // Stats calculations
    final totalStudents = _students.length;
    final passedCount = _examResults.where((r) => r['result'] == 'PASS').length;
    final failedCount = totalStudents - passedCount;
    final generatedRc = _examResults.where((r) => (r['id'] as String).isNotEmpty).length;

    return TeacherScaffold(
      scaffoldKey: _scaffoldKey,
      activeIndex: 8,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB)))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding:
                    EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Navigation / Header Actions Row
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 16.w,
                      runSpacing: 12.h,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.arrow_back_rounded,
                                  size: 20.sp,
                                  color: const Color(0xFF475569)),
                              SizedBox(width: 8.w),
                              Text(
                                'Back to Exam',
                                style: AppTypography.small.copyWith(
                                    color: const Color(0xFF475569)),
                              ),
                            ],
                          ),
                        ),
                        Wrap(
                          spacing: 12.w,
                          runSpacing: 8.h,
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white,
                                side: const BorderSide(
                                    color: Color(0xFFE2E8F0)),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(8.r)),
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16.w, vertical: 10.h),
                              ),
                              icon: Icon(Icons.description_outlined,
                                  size: 16.sp,
                                  color: const Color(0xFF475569)),
                              label: Text(
                                'Generate',
                                style: AppTypography.caption.copyWith(
                                    color: const Color(0xFF475569)),
                              ),
                              onPressed: _generateReportCards,
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(8.r)),
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16.w, vertical: 10.h),
                                elevation: 0,
                              ),
                              icon: Icon(Icons.send_rounded,
                                  size: 16.sp, color: Colors.white),
                              label: Text(
                                'Submit for Approval',
                                style: AppTypography.caption
                                    .copyWith(color: Colors.white),
                              ),
                              onPressed: _submitForApproval,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // Stats and Subject Progress Row/Column
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildClassReviewCard(
                              className,
                              ayName,
                              totalStudents,
                              passedCount,
                              failedCount,
                              generatedRc),
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          flex: 2,
                          child: _buildSubjectProgressCard(),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        _buildClassReviewCard(
                            className,
                            ayName,
                            totalStudents,
                            passedCount,
                            failedCount,
                            generatedRc),
                        SizedBox(height: 16.h),
                        _buildSubjectProgressCard(),
                      ],
                    ),
                  SizedBox(height: 24.h),

                  // Consolidated Marksheet Card
                  _buildConsolidatedMarksheetCard(),
                  SizedBox(height: 100.h),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildClassReviewCard(
    String className,
    String ayName,
    int total,
    int passed,
    int failed,
    int generatedRc,
  ) {
    return Container(
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
            'Class Review: ${widget.examName}',
            style: GoogleFonts.outfit(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            '$className • $ayName',
            style:
                AppTypography.caption.copyWith(color: const Color(0xFF64748B)),
          ),
          SizedBox(height: 24.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatBlock('Total Students', '$total'),
              _buildStatBlock('Passed', '$passed',
                  valueColor: const Color(0xFF16A34A)),
              _buildStatBlock('Failed', '$failed',
                  valueColor: const Color(0xFFDC2626)),
              _buildStatBlock('Generated RC', '$generatedRc'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBlock(String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(color: const Color(0xFF64748B)),
        ),
        SizedBox(height: 8.h),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 22.sp,
            fontWeight: FontWeight.w800,
            color: valueColor ?? const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectProgressCard() {
    return Container(
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
            'Subject Progress',
            style: GoogleFonts.outfit(
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 16.h),
          if (_subjects.isEmpty)
            Text(
              'No subjects available',
              style: AppTypography.caption
                  .copyWith(color: const Color(0xFF64748B)),
            )
          else
            Column(
              children: _subjects.map((sub) {
                final subName = sub['name'] as String;
                int enteredCount = 0;
                for (var student in _students) {
                  final studentId = student['id'] as String;
                  final hasMark = _examMarks.any((m) =>
                      m['studentId'] == studentId &&
                      m['subjectName'].toString().toLowerCase() ==
                          subName.toLowerCase());
                  if (hasMark) {
                    enteredCount++;
                  }
                }
                return _buildSubjectProgressItem(
                  subName,
                  '$enteredCount/${_students.length}',
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildSubjectProgressItem(String name, String progress) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            name,
            style:
                AppTypography.caption.copyWith(color: const Color(0xFF1E293B)),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Text(
              progress,
              style: AppTypography.caption
                  .copyWith(color: const Color(0xFF15803D)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsolidatedMarksheetCard() {
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
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16.w,
              runSpacing: 12.h,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Consolidated Marksheet',
                      style: GoogleFonts.outfit(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Full subject-wise breakdown for all students',
                      style: AppTypography.caption
                          .copyWith(color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
                // Legend row
                Wrap(
                  spacing: 16.w,
                  runSpacing: 8.h,
                  children: [
                    _buildLegendItem(const Color(0xFFEF4444), 'AB: Absent'),
                    _buildLegendItem(const Color(0xFFF59E0B), 'M: Medical'),
                    _buildLegendItem(const Color(0xFF94A3B8), '-: Not Entered'),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 24.h),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _buildMarksheetTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8.r,
          height: 8.r,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 6.w),
        Text(
          text,
          style: AppTypography.caption.copyWith(color: const Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _tableCell(Widget child, double width,
      {bool hasBottomBorder = true, Alignment alignment = Alignment.centerLeft}) {
    return Container(
      width: width,
      height: 52.h,
      alignment: alignment,
      padding: EdgeInsets.symmetric(horizontal: 8.w),
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

  Widget _headerCell(Widget child, double width, {Alignment alignment = Alignment.centerLeft}) {
    return Container(
      width: width,
      height: 40.h,
      alignment: alignment,
      padding: EdgeInsets.symmetric(horizontal: 8.w),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: child,
    );
  }

  Widget _buildMarksheetTable() {
    final bool isLandscape = MediaQuery.of(context).size.width > 500;

    final List<Map<String, dynamic>> activeSubjects = _subjects;

    final double checkboxWidth = 40.w;
    final double rankWidth = 40.w;
    final double studentWidth = 160.w;
    final double subjectWidth = 100.w;
    final double totalWidth = 80.w;
    final double pctWidth = 80.w;
    final double resultWidth = 90.w;
    final double rcStatusWidth = 160.w;

    final double tableWidth = checkboxWidth +
        rankWidth +
        studentWidth +
        (activeSubjects.length * subjectWidth) +
        totalWidth +
        pctWidth +
        resultWidth +
        rcStatusWidth +
        10.w;

    // Precompute ranks based on obtained marks descending
    final List<Map<String, dynamic>> resultsCopy = List.from(_examResults);
    resultsCopy.sort((a, b) {
      final obtA = (a['obtainedMarks'] as num? ?? 0).toDouble();
      final obtB = (b['obtainedMarks'] as num? ?? 0).toDouble();
      return obtB.compareTo(obtA);
    });
    final Map<String, int> computedRanks = {};
    for (int i = 0; i < resultsCopy.length; i++) {
      final studentId = resultsCopy[i]['studentId'] as String;
      computedRanks[studentId] = i + 1;
    }

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
          // Header Row
          Row(
            children: [
              _headerCell(
                GestureDetector(
                  onTap: _toggleSelectAll,
                  child: Icon(
                    _isAllSelected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 20.sp,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                checkboxWidth,
              ),
              _headerCell(
                Text(
                  '#',
                  style: AppTypography.caption
                      .copyWith(color: const Color(0xFF64748B)),
                ),
                rankWidth,
              ),
              _headerCell(
                Text(
                  'Student',
                  style: AppTypography.caption
                      .copyWith(color: const Color(0xFF64748B)),
                ),
                studentWidth,
              ),
              ...activeSubjects.map((s) {
                return _headerCell(
                  Center(
                    child: Text(
                      getSubjectHeader(s),
                      style: AppTypography.caption
                          .copyWith(color: const Color(0xFF64748B)),
                    ),
                  ),
                  subjectWidth,
                );
              }),
              _headerCell(
                Center(
                  child: Text(
                    'Total',
                    style: AppTypography.caption
                        .copyWith(color: const Color(0xFF64748B)),
                  ),
                ),
                totalWidth,
              ),
              _headerCell(
                Center(
                  child: Text(
                    '%',
                    style: AppTypography.caption
                        .copyWith(color: const Color(0xFF64748B)),
                  ),
                ),
                pctWidth,
              ),
              _headerCell(
                Center(
                  child: Text(
                    'Result',
                    style: AppTypography.caption
                        .copyWith(color: const Color(0xFF64748B)),
                  ),
                ),
                resultWidth,
              ),
              _headerCell(
                Center(
                  child: Text(
                    'RC Status',
                    style: AppTypography.caption
                        .copyWith(color: const Color(0xFF64748B)),
                  ),
                ),
                rcStatusWidth,
              ),
            ],
          ),

          // Data Rows
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

              final userData = student['User'] as Map?;
              final firstName = userData?['firstName'] ?? '';
              final lastName = userData?['lastName'] ?? '';
              final studentName = '$firstName $lastName'.trim().isNotEmpty
                  ? '$firstName $lastName'
                  : (student['name'] ?? 'Student');

              // Find the student's result
              final res = _examResults.firstWhere(
                (r) => r['studentId'] == studentId,
                orElse: () => <String, dynamic>{},
              );

              final isSelected = _selectedStudentIds.contains(studentId);

              final serialNo = (idx + 1).toString();
              final pctDouble = res.isNotEmpty
                  ? (res['percentage'] as num? ?? 0.0).toDouble()
                  : null;
              final totalObtained = res.isNotEmpty
                  ? (res['obtainedMarks']?.toString() ?? '0')
                  : '0';

              final String resultText = res.isNotEmpty
                  ? (res['result']?.toString() ?? 'FAIL')
                  : 'FAIL';

              final studentMarks = _examMarks
                  .where((m) => m['studentId'] == studentId)
                  .toList();

              final isRcGenerated = res.isNotEmpty &&
                  res['id'] != null &&
                  res['id'].toString().isNotEmpty;
              final isRcPublished = isRcGenerated &&
                  (res['isPublished'] == true ||
                      res['isPublished'].toString().toLowerCase() == 'true');

              return Row(
                children: [
                  _tableCell(
                    GestureDetector(
                      onTap: () => _toggleSelectStudent(studentId),
                      child: Icon(
                        isSelected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 20.sp,
                        color: isSelected
                            ? const Color(0xFF2563EB)
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                    checkboxWidth,
                    hasBottomBorder: !isLast,
                  ),
                  _tableCell(
                    Text(
                      serialNo,
                      style: AppTypography.caption
                          .copyWith(color: const Color(0xFF0F172A)),
                    ),
                    rankWidth,
                    hasBottomBorder: !isLast,
                  ),
                  _tableCell(
                    Text(
                      studentName,
                      style: AppTypography.caption
                          .copyWith(color: const Color(0xFF0F172A)),
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
                    final absenceType = mark.isNotEmpty ? mark['absenceType']?.toString() ?? '' : '';

                    String displayMark = '-';
                    Color markColor = const Color(0xFF64748B);
                    FontWeight markWeight = FontWeight.normal;

                    if (mark.isNotEmpty) {
                      if (isMarkAbsent) {
                        if (absenceType == 'MEDICAL') {
                          displayMark = 'M';
                          markColor = const Color(0xFFF59E0B);
                          markWeight = FontWeight.bold;
                        } else if (absenceType == 'EXEMPTED') {
                          displayMark = 'EX';
                          markColor = const Color(0xFF64748B);
                          markWeight = FontWeight.bold;
                        } else {
                          displayMark = 'AB';
                          markColor = const Color(0xFFEF4444);
                          markWeight = FontWeight.bold;
                        }
                      } else {
                        displayMark = mark['obtainedMarks']?.toString() ?? '0';
                        markColor = const Color(0xFF0F172A);
                        markWeight = FontWeight.bold;
                      }
                    } else {
                      displayMark = '0';
                    }
                    return _tableCell(
                      Center(
                        child: Text(
                          displayMark,
                          style: AppTypography.caption.copyWith(
                              color: markColor, fontWeight: markWeight),
                        ),
                      ),
                      subjectWidth,
                      alignment: Alignment.center,
                      hasBottomBorder: !isLast,
                    );
                  }),
                  _tableCell(
                    Center(
                      child: Text(
                        totalObtained,
                        style: AppTypography.caption.copyWith(
                            color: const Color(0xFF0F172A),
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    totalWidth,
                    alignment: Alignment.center,
                    hasBottomBorder: !isLast,
                  ),
                  _tableCell(
                    Center(
                      child: Text(
                        pctDouble != null ? '${pctDouble.round()}%' : '0%',
                        style: AppTypography.caption.copyWith(
                            color: const Color(0xFF334155),
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    pctWidth,
                    alignment: Alignment.center,
                    hasBottomBorder: !isLast,
                  ),
                  _tableCell(
                    Center(
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: resultText == 'PASS'
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Text(
                          resultText,
                          style: AppTypography.caption.copyWith(
                              color: resultText == 'PASS'
                                  ? const Color(0xFF15803D)
                                  : const Color(0xFFB91C1C),
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    resultWidth,
                    alignment: Alignment.center,
                    hasBottomBorder: !isLast,
                  ),
                  _tableCell(
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 10.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: isRcGenerated
                                ? (isRcPublished
                                    ? const Color(0xFFDCFCE7)
                                    : const Color(0xFFF1F5F9))
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: Text(
                            isRcGenerated
                                ? (isRcPublished ? 'Published' : 'Pending')
                                : 'Not Generated',
                            style: AppTypography.caption.copyWith(
                                color: isRcPublished
                                    ? const Color(0xFF15803D)
                                    : const Color(0xFF475569),
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (isRcGenerated) ...[
                          SizedBox(width: 8.w),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: Icon(
                              Icons.download_rounded,
                              size: 16.sp,
                              color: const Color(0xFF64748B),
                            ),
                            onPressed: () async {
                              final url = '${ApiConfig.liveBaseUrl}/api/v1/report-cards/${res['id']}/pdf';
                              final uri = Uri.parse(url);
                              try {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              } catch (e) {
                                dev.log('Error launching pdf: $e', name: 'ClassReviewScreen');
                              }
                            },
                          ),
                        ],
                      ],
                    ),
                    rcStatusWidth,
                    alignment: Alignment.center,
                    hasBottomBorder: !isLast,
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }
}
