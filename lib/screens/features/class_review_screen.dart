import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as dev;
import 'package:edusphere/theme/typography.dart';

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
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user != null) {
        final res = await client
            .from('User')
            .select('firstName')
            .eq('id', user.id)
            .maybeSingle();
        if (res != null && mounted) {
          setState(() {
            _teacherFirstName =
                (res['firstName'] as String? ?? 'KARAN').toUpperCase();
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final client = Supabase.instance.client;

      // 1. Fetch Exam details
      final examRes = await client
          .from('Exam')
          .select('*, Class(*), AcademicYear(*)')
          .eq('id', widget.examId)
          .single();

      _examData = examRes;
      final classId = examRes['classId'];

      // 2. Fetch Subjects for the class
      final subjectsRes =
          await client.from('Subject').select('*').eq('classId', classId);

      _subjects = List<Map<String, dynamic>>.from(subjectsRes);

      // 3. Fetch Students for the class
      final studentsRes = await client
          .from('Student')
          .select('*, User(*)')
          .eq('currentClassId', classId)
          .eq('status', 'ACTIVE');

      _students = List<Map<String, dynamic>>.from(studentsRes);

      // Sort alphabetically by Student Name
      _students.sort((a, b) {
        final userA = a['User'] as Map?;
        final nameA = '${userA?['firstName'] ?? ''} ${userA?['lastName'] ?? ''}'
            .trim()
            .toLowerCase();

        final userB = b['User'] as Map?;
        final nameB = '${userB?['firstName'] ?? ''} ${userB?['lastName'] ?? ''}'
            .trim()
            .toLowerCase();

        return nameA.compareTo(nameB);
      });

      // 4. Fetch ExamResults for the exam
      final resultsRes = await client
          .from('ExamResult')
          .select('*, Student(*, User(*))')
          .eq('examId', widget.examId);

      _examResults = List<Map<String, dynamic>>.from(resultsRes);

      // 5. Fetch ExamMarks for the exam (via ExamResult inner join)
      if (_examResults.isNotEmpty) {
        final marksRes = await client
            .from('ExamMark')
            .select('*, ExamResult!inner(id, examId)')
            .eq('ExamResult.examId', widget.examId);

        _examMarks = List<Map<String, dynamic>>.from(marksRes);
      } else {
        _examMarks = [];
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
      final client = Supabase.instance.client;
      await client
          .from('Exam')
          .update({'status': 'PENDING'}).eq('id', widget.examId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Exam submitted for approval successfully!'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ));
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
    final code = subject['code']?.toString().toUpperCase() ?? '';
    if (code.isNotEmpty) return code;

    final name = subject['name'] as String? ?? '';
    final abbreviated = abbreviateSubject(name).toUpperCase();
    final className = _examData?['Class']?['name']?.toString() ?? '';
    final regExp = RegExp(r'\d+');
    final match = regExp.firstMatch(className);
    final gradeNum = match != null ? match.group(0) : '';
    if (gradeNum != null && gradeNum.isNotEmpty) {
      return '$abbreviated-$gradeNum';
    }
    return abbreviated;
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
    final generatedRc = _examResults.length;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF1F5F9),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB)))
          : Stack(
              children: [
                Positioned.fill(
                  child: SingleChildScrollView(
                    padding:
                        EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
                    physics: const BouncingScrollPhysics(),
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
                                    onPressed: () {},
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

                // Chatbot Assistant Overlay
                if (_isChatOpen)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: _toggleChat,
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.1),
                      ),
                    ),
                  ),

                if (_isChatOpen)
                  Positioned(
                    bottom: 80.h,
                    right: 16.w,
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        width: 280.w,
                        height: 360.h,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: EdgeInsets.all(16.r),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB),
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(16.r)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.assistant,
                                      color: Colors.white, size: 20.sp),
                                  SizedBox(width: 8.w),
                                  Text(
                                    'EduSphere Assistant',
                                    style: GoogleFonts.outfit(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const Spacer(),
                                  GestureDetector(
                                    onTap: _toggleChat,
                                    child: Icon(Icons.close,
                                        color: Colors.white, size: 20.sp),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  'How can I help you?',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                if (!_isChatOpen)
                  Positioned(
                    bottom: 80.h,
                    right: 16.w,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 16.w, vertical: 12.h),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16.r),
                          topRight: Radius.circular(16.r),
                          bottomLeft: Radius.circular(16.r),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'HI $_teacherFirstName!',
                            style: AppTypography.caption.copyWith(
                                color: const Color(0xFF0F172A),
                                letterSpacing: 0.5),
                          ),
                          Text(
                            'HOW CAN I\nHELP?',
                            style: AppTypography.caption.copyWith(
                                color: const Color(0xFF2563EB),
                                letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'class_review_chatbot_fab',
        backgroundColor: const Color(0xFF0284C7),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.r)),
        onPressed: _toggleChat,
        child: Icon(
          _isChatOpen ? Icons.close_rounded : Icons.assistant_navigation,
          color: Colors.white,
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
                for (var res in _examResults) {
                  final resultId = res['id'];
                  final hasMark = _examMarks.any((m) =>
                      m['examResultId'] == resultId &&
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

  Widget _tableCell(Widget child, double width, {bool hasBottomBorder = true}) {
    return Container(
      width: width,
      height: 52.h,
      alignment: Alignment.centerLeft,
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

  Widget _headerCell(Widget child, double width) {
    return Container(
      width: width,
      height: 40.h,
      alignment: Alignment.centerLeft,
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
    final double studentWidth = isLandscape ? 160.w : 120.w;
    final double subjectWidth = 75.w;
    final double totalWidth = 60.w;
    final double pctWidth = 60.w;
    final double resultWidth = 80.w;
    final double rcStatusWidth = 140.w;

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
                  Text(
                    getSubjectHeader(s),
                    style: AppTypography.caption
                        .copyWith(color: const Color(0xFF64748B)),
                  ),
                  subjectWidth,
                );
              }),
              _headerCell(
                Text(
                  'Total',
                  style: AppTypography.caption
                      .copyWith(color: const Color(0xFF64748B)),
                ),
                totalWidth,
              ),
              _headerCell(
                Text(
                  '%',
                  style: AppTypography.caption
                      .copyWith(color: const Color(0xFF64748B)),
                ),
                pctWidth,
              ),
              _headerCell(
                Text(
                  'Result',
                  style: AppTypography.caption
                      .copyWith(color: const Color(0xFF64748B)),
                ),
                resultWidth,
              ),
              _headerCell(
                Text(
                  'RC Status',
                  style: AppTypography.caption
                      .copyWith(color: const Color(0xFF64748B)),
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

              final rank = computedRanks[studentId]?.toString() ?? '-';
              final pctDouble = res.isNotEmpty
                  ? (res['percentage'] as num? ?? 0.0).toDouble()
                  : null;
              final totalObtained = res.isNotEmpty
                  ? (res['obtainedMarks']?.toString() ?? '0')
                  : '0';

              final String resultText = res.isNotEmpty
                  ? (res['result']?.toString() ?? 'FAIL')
                  : 'FAIL';

              final studentMarks = res.isNotEmpty
                  ? _examMarks
                      .where((m) => m['examResultId'] == res['id'])
                      .toList()
                  : [];

              final isRcPublished = res.isNotEmpty &&
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
                      rank,
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
                    final name = s['name'] as String;
                    final mark = studentMarks.firstWhere(
                      (m) =>
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
                            : mark['obtainedMarks']?.toString() ?? '0')
                        : '0';

                    return _tableCell(
                      Text(
                        displayMark,
                        style: AppTypography.caption.copyWith(
                            color: isMarkAbsent
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF334155)),
                      ),
                      subjectWidth,
                      hasBottomBorder: !isLast,
                    );
                  }),
                  _tableCell(
                    Text(
                      totalObtained,
                      style: AppTypography.caption
                          .copyWith(color: const Color(0xFF0F172A)),
                    ),
                    totalWidth,
                    hasBottomBorder: !isLast,
                  ),
                  _tableCell(
                    Text(
                      pctDouble != null ? '${pctDouble.round()}%' : '0%',
                      style: AppTypography.caption
                          .copyWith(color: const Color(0xFF334155)),
                    ),
                    pctWidth,
                    hasBottomBorder: !isLast,
                  ),
                  _tableCell(
                    Container(
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
                                : const Color(0xFFB91C1C)),
                      ),
                    ),
                    resultWidth,
                    hasBottomBorder: !isLast,
                  ),
                  _tableCell(
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 10.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: isRcPublished
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: Text(
                            isRcPublished ? 'Published' : 'Pending',
                            style: AppTypography.caption.copyWith(
                                color: isRcPublished
                                    ? const Color(0xFF15803D)
                                    : const Color(0xFF475569)),
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            Icons.download_rounded,
                            size: 16.sp,
                            color: const Color(0xFF64748B),
                          ),
                          onPressed: () {},
                        ),
                      ],
                    ),
                    rcStatusWidth,
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
