import 'dart:async';
import 'dart:developer' as dev;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/common_widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart' as intl;
import '../../services/api_service.dart';
import '../main_screen.dart';
import 'package:edusphere/theme/typography.dart';

class CreateAssignmentScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  final bool showAppBar;

  const CreateAssignmentScreen({
    super.key,
    this.onOpenDrawer,
    this.showAppBar = true,
  });

  @override
  State<CreateAssignmentScreen> createState() => _CreateAssignmentScreenState();
}

class _CreateAssignmentScreenState extends State<CreateAssignmentScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isLoadingAssignments = true;
  bool _isLoadingSubmissions = false;
  bool _isSubmitting = false;

  String _teacherName = 'Teacher';
  final List<Map<String, dynamic>> _assignments = [];
  final List<Map<String, dynamic>> _submissionsList = [];
  Map<String, dynamic>? _selectedAssignment;

  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _sections = [];
  List<Map<String, dynamic>> _subjects = [];

  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadTeacherName();
    _loadAllData();
    _loadAcademicData();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _loadAllData(showLoading: false);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────
  // DATA LOADING
  // ─────────────────────────────────────────────────────

  Future<void> _loadTeacherName() async {
    final prefs = await SharedPreferences.getInstance();
    final name =
        prefs.getString('teacher_name') ?? prefs.getString('user_name');
    if (name != null && name.isNotEmpty && mounted) {
      setState(() => _teacherName = name);
    }
  }

  String _getInitials(String name) {
    try {
      final parts = name.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      if (parts.isNotEmpty && parts[0].isNotEmpty) {
        return parts[0][0].toUpperCase();
      }
    } catch (_) {}
    return 'T';
  }

  Future<void> _loadAcademicData() async {
    try {
      final results = await Future.wait([
        ApiService.instance.get('academic/classes'),
        ApiService.instance.get('academic/sections'),
        ApiService.instance.get('academic/subjects'),
      ]);
      if (mounted) {
        setState(() {
          _classes = List<Map<String, dynamic>>.from(
              (results[0]['classes'] ?? results[0]['data'] ?? []) as List);
          _sections = List<Map<String, dynamic>>.from(
              (results[1]['sections'] ?? results[1]['data'] ?? []) as List);
          _subjects = List<Map<String, dynamic>>.from(
              (results[2]['subjects'] ?? results[2]['data'] ?? []) as List);
        });
      }
    } catch (e) {
      dev.log('⚠️ Error loading academic data: $e',
          name: 'CreateAssignmentScreen');
    }
  }

  Future<void> _loadAllData({bool showLoading = true}) async {
    if (!mounted) return;
    if (showLoading) setState(() => _isLoadingAssignments = true);
    try {
      final res = await ApiService.instance.get('assignments/teacher');
      final List<dynamic> raw = res['assignments'] ?? [];
      final List<Map<String, dynamic>> temp = raw.map((row) {
        final subject = row['subject'] as Map<String, dynamic>?;
        final cls = row['class'] as Map<String, dynamic>?;
        final section = row['section'] as Map<String, dynamic>?;
        final count = row['_count']?['submissions'] ?? 0;
        return {
          'id': row['id'],
          'title': row['title'] ?? 'Untitled',
          'subject': subject?['name'] ?? 'General',
          'class_name': cls?['name'] ?? 'N/A',
          'section': section?['name'] ?? 'All',
          'due_date': row['dueDate'] != null
              ? _formatDueDate(row['dueDate'] as String)
              : 'No Due Date',
          'submissions_count': count,
          'description': row['description'] ?? '',
        };
      }).toList();

      if (mounted) {
        setState(() {
          _assignments.clear();
          _assignments.addAll(temp);
          _isLoadingAssignments = false;
          if (_selectedAssignment != null) {
            final still = _assignments
                .where((a) => a['id'] == _selectedAssignment!['id']);
            _selectedAssignment = still.isNotEmpty ? still.first : null;
          }
        });
      }
    } catch (e) {
      dev.log('⚠️ Error loading assignments: $e',
          name: 'CreateAssignmentScreen');
      if (mounted) setState(() => _isLoadingAssignments = false);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchSubmissions(
      String assignmentId) async {
    try {
      final res = await ApiService.instance.get('assignments/$assignmentId');
      final assignment = res['assignment'] as Map<String, dynamic>?;
      final rawSubs = assignment?['submissions'] as List<dynamic>? ?? [];
      return rawSubs.map((sub) {
        final student = sub['student'] as Map<String, dynamic>?;
        final user = student?['user'] as Map<String, dynamic>?;
        final fn = user?['firstName'] as String? ?? '';
        final ln = user?['lastName'] as String? ?? '';
        final name =
            '$fn $ln'.trim().isEmpty ? 'Unknown Student' : '$fn $ln'.trim();
        return {
          'id': sub['id'],
          'assignment_id': assignmentId,
          'student_id': sub['studentId'],
          'student_name': name,
          'submitted_at': sub['submittedAt'],
          'grade': sub['grade'] ?? 'Pending',
          'score': sub['feedback'] ?? 'Not Graded',
          'file_name': sub['filePath'] != null
              ? (sub['filePath'] as String).split('/').last
              : null,
          'status': sub['status'] ?? 'PENDING',
          'assignment_title': assignment?['title'] ?? 'Untitled',
        };
      }).toList();
    } catch (e) {
      dev.log('⚠️ Error fetching submissions: $e',
          name: 'CreateAssignmentScreen');
      return [];
    }
  }

  Future<void> _selectAssignment(Map<String, dynamic> assignment) async {
    setState(() {
      _selectedAssignment = assignment;
      _isLoadingSubmissions = true;
    });
    final subs = await _fetchSubmissions(assignment['id'] as String);
    if (mounted) {
      setState(() {
        _submissionsList.clear();
        _submissionsList.addAll(subs);
        _isLoadingSubmissions = false;
      });
    }
  }

  Future<void> _deleteAssignment(String assignmentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text('Delete Assignment', style: AppTypography.body),
        content: Text(
            'Are you sure you want to delete this assignment? This cannot be undone.',
            style:
                AppTypography.caption.copyWith(color: const Color(0xFF64748B))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r)),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService.instance.delete('assignments/$assignmentId');
      if (mounted) {
        showToast(context, 'Assignment deleted successfully');
        if (_selectedAssignment != null &&
            _selectedAssignment!['id'] == assignmentId) {
          setState(() {
            _selectedAssignment = null;
            _submissionsList.clear();
          });
        }
        _loadAllData(showLoading: false);
      }
    } catch (e) {
      if (mounted) showToast(context, 'Error deleting: $e', isError: true);
    }
  }

  String _formatDueDate(String raw) {
    try {
      return intl.DateFormat('MMM d, yyyy')
          .format(DateTime.parse(raw).toLocal());
    } catch (_) {
      return raw;
    }
  }

  // ─────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: widget.showAppBar
          ? const EduSphereDrawer(role: 'teacher', activeLabel: 'Assignments')
          : null,
      bottomNavigationBar:
          widget.showAppBar ? const TeacherBottomNavBar(activeIndex: 6) : null,
      backgroundColor: const Color(0xFFF3F8FC),
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
              leading: IconButton(
                icon: Icon(Icons.menu, size: 26.sp),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.notifications_none_rounded,
                      size: 26.sp, color: const Color(0xFF0F172A)),
                  onPressed: () {},
                ),
                Padding(
                  padding: EdgeInsets.only(right: 16.w),
                  child: CircleAvatar(
                    radius: 16.r,
                    backgroundColor: const Color(0xFFDCF0FF),
                    child: Text(_getInitials(_teacherName),
                        style: AppTypography.caption
                            .copyWith(color: const Color(0xFF0284C7))),
                  ),
                ),
              ],
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => _loadAllData(showLoading: true),
        color: const Color(0xFF1976D2),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(18.w, 20.h, 18.w, 120.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page header
              Text('Assignment Management',
                  style: AppTypography.h4.copyWith(
                      color: const Color(0xFF0F172A), letterSpacing: -0.5)),
              SizedBox(height: 3.h),
              Text('Create and grade student assignments',
                  style: AppTypography.caption
                      .copyWith(color: const Color(0xFF64748B))),
              SizedBox(height: 16.h),

              // New Assignment button
              ElevatedButton.icon(
                onPressed: () => _showCreateAssignmentDialog(context),
                icon: Icon(Icons.add, color: Colors.white, size: 18.sp),
                label: Text('New Assignment',
                    style: AppTypography.caption.copyWith(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r)),
                  padding:
                      EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                ),
              ),
              SizedBox(height: 20.h),

              _buildMyAssignmentsCard(),
              SizedBox(height: 20.h),
              _buildSubmissionTrackerCard(),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // MY ASSIGNMENTS — TABLE
  // ─────────────────────────────────────────────────────

  Widget _buildMyAssignmentsCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(18.w, 18.h, 18.w, 0),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('My Assignments',
                  style: AppTypography.small
                      .copyWith(color: const Color(0xFF0F172A))),
              SizedBox(height: 2.h),
              Text('All assignments created by you.',
                  style: AppTypography.caption
                      .copyWith(color: const Color(0xFF64748B))),
            ]),
          ),
          SizedBox(height: 14.h),
          if (_isLoadingAssignments)
            const Center(
                child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(color: Color(0xFF1976D2))))
          else if (_assignments.isEmpty)
            _buildEmptyAssignments()
          else
            _buildAssignmentsTable(),
          SizedBox(height: 4.h),
        ],
      ),
    );
  }

  Widget _buildAssignmentsTable() {
    return Column(children: [
      // Header row
      Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        decoration: const BoxDecoration(
            border: Border(
                top: BorderSide(color: Color(0xFFF1F5F9)),
                bottom: BorderSide(color: Color(0xFFE2E8F0)))),
        child: Row(children: [
          Expanded(
              flex: 3,
              child: Text('Assignment',
                  style: AppTypography.caption
                      .copyWith(color: const Color(0xFF64748B)))),
          Expanded(
              flex: 3,
              child: Text('Class/\nSubject',
                  style: AppTypography.caption
                      .copyWith(color: const Color(0xFF64748B)))),
          Expanded(
              flex: 2,
              child: Text('Due\nDate',
                  style: AppTypography.caption
                      .copyWith(color: const Color(0xFF1976D2)))),
          SizedBox(
              width: 60.w,
              child: Text('Submissions',
                  style: AppTypography.caption
                      .copyWith(color: const Color(0xFF64748B)),
                  textAlign: TextAlign.center)),
          SizedBox(
              width: 75.w,
              child: Text('Actions',
                  style: AppTypography.caption
                      .copyWith(color: const Color(0xFF64748B)),
                  textAlign: TextAlign.center)),
        ]),
      ),
      // Data rows
      ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _assignments.length,
        separatorBuilder: (_, __) => const Divider(
            height: 1, color: Color(0xFFF1F5F9), indent: 14, endIndent: 14),
        itemBuilder: (context, index) {
          final a = _assignments[index];
          final isSelected = _selectedAssignment != null &&
              _selectedAssignment!['id'] == a['id'];
          final count = a['submissions_count'] as int? ?? 0;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            color: isSelected
                ? const Color(0xFFF0F9FF)
                : (index.isEven ? Colors.white : const Color(0xFFFAFCFF)),
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
            child: Row(children: [
              Expanded(
                  flex: 3,
                  child: Text(a['title'] as String? ?? 'Untitled',
                      style: AppTypography.caption
                          .copyWith(color: const Color(0xFF0F172A)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis)),
              Expanded(
                  flex: 3,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a['class_name'] as String? ?? 'N/A',
                            style: AppTypography.caption
                                .copyWith(color: const Color(0xFF0F172A))),
                        Text(a['subject'] as String? ?? 'General',
                            style: AppTypography.caption
                                .copyWith(color: const Color(0xFF64748B))),
                      ])),
              Expanded(
                  flex: 2,
                  child: Text(a['due_date'] as String? ?? '—',
                      style: AppTypography.caption.copyWith(
                          color: const Color(0xFF334155), height: 1.4))),
              SizedBox(
                  width: 60.w,
                  child: Center(
                      child: Container(
                    width: 26.r,
                    height: 26.r,
                    decoration: const BoxDecoration(
                        color: Color(0xFFE8F4FD), shape: BoxShape.circle),
                    child: Center(
                        child: Text('$count',
                            style: AppTypography.caption
                                .copyWith(color: const Color(0xFF1976D2)))),
                  ))),
              SizedBox(
                  width: 75.w,
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () => _selectAssignment(a),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8.w, vertical: 5.h),
                            decoration: BoxDecoration(
                                border:
                                    Border.all(color: const Color(0xFFCBD5E1)),
                                borderRadius: BorderRadius.circular(6.r),
                                color: Colors.white),
                            child: Text('View',
                                style: AppTypography.caption
                                    .copyWith(color: const Color(0xFF334155))),
                          ),
                        ),
                        SizedBox(width: 6.w),
                        GestureDetector(
                          onTap: () => _deleteAssignment(a['id'] as String),
                          child: Icon(Icons.delete_outline_rounded,
                              size: 18.sp, color: const Color(0xFFEF4444)),
                        ),
                      ])),
            ]),
          );
        },
      ),
    ]);
  }

  Widget _buildEmptyAssignments() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      child: CustomPaint(
        painter:
            DashedRectPainter(color: const Color(0xFFCBD5E1), radius: 12.r),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 40.h),
          child: Column(children: [
            Icon(Icons.description_outlined,
                color: const Color(0xFFCBD5E1), size: 44.r),
            SizedBox(height: 12.h),
            Text('No assignments created yet.',
                style: AppTypography.caption
                    .copyWith(color: const Color(0xFF64748B))),
          ]),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // SUBMISSION TRACKER
  // ─────────────────────────────────────────────────────

  Widget _buildSubmissionTrackerCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF4FA),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFDDE7F2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_selectedAssignment != null) ...[
          Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Submission Tracker',
                      style: AppTypography.small
                          .copyWith(color: const Color(0xFF0F172A))),
                  SizedBox(height: 2.h),
                  Text('Submissions for: ${_selectedAssignment!['title']}',
                      style: AppTypography.caption
                          .copyWith(color: const Color(0xFF64748B))),
                ])),
            GestureDetector(
              onTap: () => setState(() {
                _selectedAssignment = null;
                _submissionsList.clear();
              }),
              child: Icon(Icons.close_rounded,
                  size: 20.sp, color: const Color(0xFF94A3B8)),
            ),
          ]),
          SizedBox(height: 16.h),
          if (_isLoadingSubmissions)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(30),
                    child: CircularProgressIndicator(color: Color(0xFF1976D2))))
          else
            _buildSubmissionsList(),
        ] else
          _buildTrackerEmpty(),
      ]),
    );
  }

  Widget _buildTrackerEmpty() {
    return CustomPaint(
      painter: DashedRectPainter(color: const Color(0xFFAEC6DC), radius: 12.r),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 40.h, horizontal: 20.w),
        child: Column(children: [
          Icon(Icons.access_time_rounded,
              color: const Color(0xFFAEC6DC), size: 44.r),
          SizedBox(height: 12.h),
          Text('Submission Tracker',
              style:
                  AppTypography.small.copyWith(color: const Color(0xFF64748B))),
          SizedBox(height: 4.h),
          Text('Select an assignment to view and\ngrade student work.',
              style: AppTypography.caption
                  .copyWith(color: const Color(0xFF94A3B8), height: 1.5),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _buildSubmissionsList() {
    if (_submissionsList.isEmpty) {
      return CustomPaint(
        painter:
            DashedRectPainter(color: const Color(0xFFAEC6DC), radius: 12.r),
        child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 32.h),
            child: Column(children: [
              Icon(Icons.folder_open_outlined,
                  color: const Color(0xFFAEC6DC), size: 40.r),
              SizedBox(height: 10.h),
              Text('No submissions received yet.',
                  style: AppTypography.caption
                      .copyWith(color: const Color(0xFF64748B))),
            ])),
      );
    }
    return Column(children: [
      // Submission table header
      Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(10.r)),
            border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Row(children: [
          Expanded(
              flex: 3,
              child: Text('Student',
                  style: AppTypography.caption
                      .copyWith(color: const Color(0xFF64748B)))),
          Expanded(
              flex: 2,
              child: Text('Submitted',
                  style: AppTypography.caption
                      .copyWith(color: const Color(0xFF64748B)))),
          SizedBox(
              width: 55.w,
              child: Text('Grade',
                  style: AppTypography.caption
                      .copyWith(color: const Color(0xFF64748B)),
                  textAlign: TextAlign.center)),
          SizedBox(
              width: 80.w,
              child: Text('Action',
                  style: AppTypography.caption
                      .copyWith(color: const Color(0xFF64748B)),
                  textAlign: TextAlign.center)),
        ]),
      ),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(10.r)),
          border: const Border(
              left: BorderSide(color: Color(0xFFE2E8F0)),
              right: BorderSide(color: Color(0xFFE2E8F0)),
              bottom: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _submissionsList.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
          itemBuilder: (context, index) {
            final sub = _submissionsList[index];
            final hasGrade = sub['grade'] != null && sub['grade'] != 'Pending';
            DateTime? subDate;
            try {
              subDate = DateTime.parse(sub['submitted_at']).toLocal();
            } catch (_) {}
            final dateStr = subDate != null
                ? intl.DateFormat('MMM d, yy').format(subDate)
                : 'Recent';
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              child: Row(children: [
                Expanded(
                    flex: 3,
                    child: Row(children: [
                      CircleAvatar(
                          radius: 14.r,
                          backgroundColor: const Color(0xFFE0F2FE),
                          child: Text(
                              _getInitials(
                                  sub['student_name'] as String? ?? 'S'),
                              style: AppTypography.caption
                                  .copyWith(color: const Color(0xFF0284C7)))),
                      SizedBox(width: 8.w),
                      Expanded(
                          child: Text(
                              sub['student_name'] as String? ?? 'Student',
                              style: AppTypography.caption
                                  .copyWith(color: const Color(0xFF0F172A)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis)),
                    ])),
                Expanded(
                    flex: 2,
                    child: Text(dateStr,
                        style: AppTypography.caption
                            .copyWith(color: const Color(0xFF64748B)))),
                SizedBox(
                    width: 55.w,
                    child: Center(
                        child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                      decoration: BoxDecoration(
                          color: hasGrade
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(6.r)),
                      child: Text(hasGrade ? sub['grade'] as String : 'Pending',
                          style: AppTypography.caption.copyWith(
                              color: hasGrade
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFD97706)),
                          textAlign: TextAlign.center),
                    ))),
                SizedBox(
                    width: 80.w,
                    child: Center(
                        child: GestureDetector(
                      onTap: () => _showEvaluationDialog(context, sub),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 8.w, vertical: 6.h),
                        decoration: BoxDecoration(
                            color: hasGrade
                                ? const Color(0xFFF1F5F9)
                                : const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(7.r)),
                        child: Text(hasGrade ? 'Re-grade' : 'Grade',
                            style: AppTypography.caption.copyWith(
                                color: hasGrade
                                    ? const Color(0xFF475569)
                                    : const Color(0xFF0284C7))),
                      ),
                    ))),
              ]),
            );
          },
        ),
      ),
      SizedBox(height: 8.h),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        Icon(Icons.people_outline_rounded,
            size: 14.sp, color: const Color(0xFF64748B)),
        SizedBox(width: 4.w),
        Text('${_submissionsList.length} submission(s)',
            style:
                AppTypography.caption.copyWith(color: const Color(0xFF64748B))),
      ]),
    ]);
  }

  // ─────────────────────────────────────────────────────
  // CREATE ASSIGNMENT DIALOG — matches reference image
  // ─────────────────────────────────────────────────────

  void _showCreateAssignmentDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    DateTime? tempDueDate;
    Map<String, dynamic>? chosenClass;
    Map<String, dynamic>? chosenSection;
    Map<String, dynamic>? chosenSubject;
    String? refFileName;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // Shared dropdown decoration
          InputDecoration dropDeco(String hint) => InputDecoration(
                hintText: hint,
                hintStyle: AppTypography.caption
                    .copyWith(color: const Color(0xFF94A3B8)),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    borderSide:
                        const BorderSide(color: Color(0xFF1976D2), width: 1.5)),
              );

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding:
                EdgeInsets.symmetric(horizontal: 16.w, vertical: 30.h),
            child: Container(
              decoration: BoxDecoration(
                  color: const Color(0xFFF0F6FC),
                  borderRadius: BorderRadius.circular(16.r)),
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(ctx).viewInsets.bottom),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Dialog Title Bar ──
                      Padding(
                        padding: EdgeInsets.fromLTRB(20.w, 18.h, 12.w, 14.h),
                        child: Row(children: [
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text('Create New Assignment',
                                    style: AppTypography.body.copyWith(
                                        color: const Color(0xFF0F172A))),
                                SizedBox(height: 3.h),
                                Text(
                                    'Fill in the details to assign work to students.',
                                    style: AppTypography.caption.copyWith(
                                        color: const Color(0xFF64748B))),
                              ])),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: Icon(Icons.close_rounded,
                                size: 20.sp, color: const Color(0xFF64748B)),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ]),
                      ),

                      // ── Form Card ──
                      Container(
                        margin: EdgeInsets.symmetric(horizontal: 16.w),
                        padding: EdgeInsets.all(16.r),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title
                              _fLabel('Title'),
                              SizedBox(height: 6.h),
                              TextFormField(
                                controller: titleCtrl,
                                style: AppTypography.caption
                                    .copyWith(color: const Color(0xFF0F172A)),
                                decoration: InputDecoration(
                                  hintText:
                                      'e.g., Mathematics Chapter 1 Homework',
                                  hintStyle: AppTypography.caption
                                      .copyWith(color: const Color(0xFF94A3B8)),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FCFF),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 14.w, vertical: 12.h),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8.r),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFCBD5E1))),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8.r),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFCBD5E1))),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8.r),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF1976D2),
                                          width: 1.5)),
                                ),
                              ),
                              SizedBox(height: 14.h),

                              // Description
                              _fLabel('Description (Optional)'),
                              SizedBox(height: 6.h),
                              TextFormField(
                                controller: descCtrl,
                                maxLines: 3,
                                style: AppTypography.caption
                                    .copyWith(color: const Color(0xFF0F172A)),
                                decoration: InputDecoration(
                                  hintText: 'Instructions for students...',
                                  hintStyle: AppTypography.caption
                                      .copyWith(color: const Color(0xFF94A3B8)),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FCFF),
                                  contentPadding: EdgeInsets.all(12.r),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8.r),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFCBD5E1))),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8.r),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFCBD5E1))),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8.r),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF1976D2),
                                          width: 1.5)),
                                ),
                              ),
                              SizedBox(height: 14.h),

                              // Class + Section
                              Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          _fLabel('Class'),
                                          SizedBox(height: 6.h),
                                          DropdownButtonFormField<
                                              Map<String, dynamic>>(
                                            initialValue: chosenClass,
                                            decoration:
                                                dropDeco('Select Class'),
                                            style: AppTypography.caption
                                                .copyWith(
                                                    color: const Color(
                                                        0xFF0F172A)),
                                            isExpanded: true,
                                            items: _classes
                                                .map((cls) => DropdownMenuItem(
                                                      value: cls,
                                                      child: Text(
                                                          cls['name']
                                                                  as String? ??
                                                              '',
                                                          style: AppTypography
                                                              .caption
                                                              .copyWith(
                                                                  color: const Color(
                                                                      0xFF0F172A))),
                                                    ))
                                                .toList(),
                                            onChanged: (val) =>
                                                setDialogState(() {
                                              chosenClass = val;
                                              chosenSection = null;
                                            }),
                                          ),
                                        ])),
                                    SizedBox(width: 12.w),
                                    Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          _fLabel('Section (Optional)'),
                                          SizedBox(height: 6.h),
                                          DropdownButtonFormField<
                                              Map<String, dynamic>?>(
                                            initialValue: chosenSection,
                                            decoration:
                                                dropDeco('All Sections'),
                                            style: AppTypography.caption
                                                .copyWith(
                                                    color: const Color(
                                                        0xFF0F172A)),
                                            isExpanded: true,
                                            items: [
                                              DropdownMenuItem<
                                                  Map<String, dynamic>?>(
                                                value: null,
                                                child: Text('All Sections',
                                                    style: AppTypography.caption
                                                        .copyWith(
                                                            color: const Color(
                                                                0xFF94A3B8))),
                                              ),
                                              ..._sections.map((sec) =>
                                                  DropdownMenuItem<
                                                      Map<String, dynamic>?>(
                                                    value: sec,
                                                    child: Text(
                                                        sec['name']
                                                                as String? ??
                                                            '',
                                                        style: AppTypography
                                                            .caption
                                                            .copyWith(
                                                                color: const Color(
                                                                    0xFF0F172A))),
                                                  )),
                                            ],
                                            onChanged: (val) => setDialogState(
                                                () => chosenSection = val),
                                          ),
                                        ])),
                                  ]),
                              SizedBox(height: 14.h),

                              // Subject + Due Date
                              Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          _fLabel('Subject'),
                                          SizedBox(height: 6.h),
                                          DropdownButtonFormField<
                                              Map<String, dynamic>>(
                                            initialValue: chosenSubject,
                                            decoration:
                                                dropDeco('Select Subject'),
                                            style: AppTypography.caption
                                                .copyWith(
                                                    color: const Color(
                                                        0xFF0F172A)),
                                            isExpanded: true,
                                            items: _subjects
                                                .map((s) => DropdownMenuItem(
                                                      value: s,
                                                      child: Text(
                                                          s['name']
                                                                  as String? ??
                                                              '',
                                                          style: AppTypography
                                                              .caption
                                                              .copyWith(
                                                                  color: const Color(
                                                                      0xFF0F172A))),
                                                    ))
                                                .toList(),
                                            onChanged: (val) => setDialogState(
                                                () => chosenSubject = val),
                                          ),
                                        ])),
                                    SizedBox(width: 12.w),
                                    Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          _fLabel('Due Date'),
                                          SizedBox(height: 6.h),
                                          GestureDetector(
                                            onTap: () async {
                                              final picked =
                                                  await showDatePicker(
                                                context: ctx,
                                                initialDate: tempDueDate ??
                                                    DateTime.now().add(
                                                        const Duration(
                                                            days: 1)),
                                                firstDate: DateTime.now(),
                                                lastDate: DateTime(
                                                    DateTime.now().year + 5),
                                                builder: (context, child) =>
                                                    Theme(
                                                  data: Theme.of(context).copyWith(
                                                      colorScheme:
                                                          const ColorScheme
                                                              .light(
                                                              primary: Color(
                                                                  0xFF1976D2))),
                                                  child: child!,
                                                ),
                                              );
                                              if (picked != null) {
                                                setDialogState(
                                                    () => tempDueDate = picked);
                                              }
                                            },
                                            child: Container(
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: 12.w,
                                                  vertical: 11.h),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(8.r),
                                                border: Border.all(
                                                    color: const Color(
                                                        0xFFCBD5E1)),
                                              ),
                                              child: Row(children: [
                                                Expanded(
                                                    child: Text(
                                                  tempDueDate == null
                                                      ? 'dd-mm-yyyy'
                                                      : intl.DateFormat(
                                                              'dd-MM-yyyy')
                                                          .format(tempDueDate!),
                                                  style: AppTypography.caption
                                                      .copyWith(
                                                          color: tempDueDate ==
                                                                  null
                                                              ? const Color(
                                                                  0xFF94A3B8)
                                                              : const Color(
                                                                  0xFF0F172A)),
                                                )),
                                                Icon(
                                                    Icons
                                                        .calendar_today_rounded,
                                                    size: 14.sp,
                                                    color: const Color(
                                                        0xFF64748B)),
                                              ]),
                                            ),
                                          ),
                                        ])),
                                  ]),
                              SizedBox(height: 14.h),

                              // Reference File
                              Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _fLabel('Reference File (Optional)'),
                                    GestureDetector(
                                      onTap: () => showToast(ctx,
                                          'Smart Assistant coming soon! 🤖'),
                                      child: Row(children: [
                                        Icon(Icons.auto_awesome_rounded,
                                            size: 13.sp,
                                            color: const Color(0xFF1976D2)),
                                        SizedBox(width: 4.w),
                                        Text('Smart Assistant (AI)',
                                            style: AppTypography.caption
                                                .copyWith(
                                                    color: const Color(
                                                        0xFF1976D2))),
                                      ]),
                                    ),
                                  ]),
                              SizedBox(height: 6.h),
                              GestureDetector(
                                onTap: () async {
                                  try {
                                    final result = await FilePicker.platform
                                        .pickFiles(
                                            type: FileType.any,
                                            allowMultiple: false);
                                    if (result != null &&
                                        result.files.isNotEmpty) {
                                      setDialogState(() => refFileName =
                                          result.files.first.name);
                                    }
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      showToast(ctx, 'Could not pick file: $e',
                                          isError: true);
                                    }
                                  }
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 12.w, vertical: 11.h),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8.r),
                                    border: Border.all(
                                        color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: Row(children: [
                                    Icon(Icons.attach_file_rounded,
                                        size: 16.sp,
                                        color: const Color(0xFF64748B)),
                                    SizedBox(width: 8.w),
                                    Expanded(
                                        child: Text(
                                      refFileName == null
                                          ? 'Choose file   No file chosen'
                                          : refFileName!,
                                      style: AppTypography.caption.copyWith(
                                          color: refFileName == null
                                              ? const Color(0xFF94A3B8)
                                              : const Color(0xFF0F172A)),
                                      overflow: TextOverflow.ellipsis,
                                    )),
                                  ]),
                                ),
                              ),
                            ]),
                      ),

                      // ── Action Buttons ──
                      Padding(
                        padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 18.h),
                        child: Row(children: [
                          // Cancel
                          Expanded(
                              child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.r)),
                              padding: EdgeInsets.symmetric(vertical: 13.h),
                            ),
                            child: Text('Cancel',
                                style: AppTypography.caption
                                    .copyWith(color: const Color(0xFF475569))),
                          )),
                          SizedBox(width: 12.w),
                          // Create Assignment
                          Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1976D2),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10.r)),
                                  padding: EdgeInsets.symmetric(vertical: 13.h),
                                ),
                                onPressed: _isSubmitting
                                    ? null
                                    : () async {
                                        if (titleCtrl.text.trim().isEmpty) {
                                          showToast(ctx, 'Please enter a title',
                                              isError: true);
                                          return;
                                        }
                                        if (chosenSubject == null) {
                                          showToast(
                                              ctx, 'Please select a subject',
                                              isError: true);
                                          return;
                                        }
                                        if (chosenClass == null) {
                                          showToast(
                                              ctx, 'Please select a class',
                                              isError: true);
                                          return;
                                        }
                                        setDialogState(
                                            () => _isSubmitting = true);
                                        setState(() => _isSubmitting = true);
                                        try {
                                          final fmtDue = intl.DateFormat(
                                                  "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'")
                                              .format((tempDueDate ??
                                                      DateTime.now().add(
                                                          const Duration(
                                                              days: 1)))
                                                  .toUtc());
                                          final result = await ApiService
                                              .instance
                                              .post('assignments', body: {
                                            'title': titleCtrl.text.trim(),
                                            'description': descCtrl.text.trim(),
                                            'dueDate': fmtDue,
                                            'subjectId': chosenSubject!['id'],
                                            'classId': chosenClass!['id'],
                                            if (chosenSection != null)
                                              'sectionId': chosenSection!['id'],
                                          });
                                          if (ctx.mounted) {
                                            if (result['assignment'] != null ||
                                                result['success'] == true) {
                                              showToast(ctx,
                                                  '✅ Assignment created successfully!');
                                              Navigator.pop(ctx);
                                              _loadAllData(showLoading: true);
                                            } else {
                                              showToast(
                                                  ctx,
                                                  result['message'] ??
                                                      result['error'] ??
                                                      'Failed to create',
                                                  isError: true);
                                            }
                                          }
                                        } catch (e) {
                                          if (ctx.mounted) {
                                            showToast(ctx, 'Error: $e',
                                                isError: true);
                                          }
                                        } finally {
                                          setDialogState(
                                              () => _isSubmitting = false);
                                          if (mounted) {
                                            setState(
                                                () => _isSubmitting = false);
                                          }
                                        }
                                      },
                                child: _isSubmitting
                                    ? SizedBox(
                                        height: 18.r,
                                        width: 18.r,
                                        child: const CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2))
                                    : Text('Create Assignment',
                                        style: AppTypography.caption
                                            .copyWith(color: Colors.white)),
                              )),
                        ]),
                      ),
                    ]),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // EVALUATION DIALOG
  // ─────────────────────────────────────────────────────

  void _showEvaluationDialog(BuildContext context, Map<String, dynamic> sub) {
    String selectedGrade =
        sub['grade'] == 'Pending' || sub['grade'] == null ? 'A+' : sub['grade'];
    final feedbackCtrl = TextEditingController(
        text: sub['score'] == 'Not Graded' ? '' : sub['score']);
    final gradesList = ['A+', 'A', 'B+', 'B', 'C', 'D', 'F'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          title: Text('Evaluate Submission',
              style:
                  AppTypography.body.copyWith(color: const Color(0xFF0F172A))),
          content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Student: ${sub['student_name']}',
                    style: AppTypography.caption
                        .copyWith(color: const Color(0xFF475569))),
                SizedBox(height: 4.h),
                Text('Assignment: ${sub['assignment_title']}',
                    style: AppTypography.caption
                        .copyWith(color: const Color(0xFF64748B))),
                SizedBox(height: 16.h),
                _buildDialogLabel('SELECT GRADE'),
                SizedBox(height: 6.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(color: const Color(0xFFE2E8F0))),
                  child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                    value: selectedGrade,
                    isExpanded: true,
                    items: gradesList
                        .map((g) => DropdownMenuItem(
                            value: g,
                            child: Text(g,
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0F172A)))))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedGrade = val);
                      }
                    },
                  )),
                ),
                SizedBox(height: 16.h),
                _buildDialogLabel('FEEDBACK / COMMENTS'),
                SizedBox(height: 6.h),
                TextField(
                  controller: feedbackCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Optional feedback for the student...',
                    hintStyle: AppTypography.caption
                        .copyWith(color: const Color(0xFF94A3B8)),
                    contentPadding: EdgeInsets.all(12.r),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r),
                        borderSide: const BorderSide(color: Color(0xFF1976D2))),
                  ),
                ),
              ]),
          actionsPadding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r)),
                  padding:
                      EdgeInsets.symmetric(horizontal: 18.w, vertical: 10.h),
                  elevation: 0),
              onPressed: () async {
                final feedback = feedbackCtrl.text.trim();
                final submissionId = sub['id'] as String?;
                Navigator.pop(ctx);
                if (submissionId == null) {
                  showToast(context, 'Submission ID not found', isError: true);
                  return;
                }
                showToast(context, 'Saving evaluation...');
                try {
                  final result = await ApiService.instance.put(
                      'assignments/submissions/$submissionId/grade',
                      body: {
                        'grade': selectedGrade,
                        'feedback': feedback.isEmpty ? null : feedback
                      });
                  if (context.mounted) {
                    if (result['success'] == true ||
                        result['submission'] != null) {
                      showToast(context, 'Submission evaluated successfully!');
                      if (_selectedAssignment != null) {
                        await _selectAssignment(_selectedAssignment!);
                      }
                    } else {
                      showToast(
                          context,
                          result['message'] ??
                              result['error'] ??
                              'Failed to save grade',
                          isError: true);
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    showToast(context, 'Error saving grade: $e', isError: true);
                  }
                }
              },
              child: Text('Submit Grade',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────

  Widget _fLabel(String text) => Text(text,
      style: AppTypography.caption.copyWith(color: const Color(0xFF334155)));

  Widget _buildDialogLabel(String text) => Text(text,
      style: AppTypography.caption
          .copyWith(color: const Color(0xFF64748B), letterSpacing: 0.5));
}

// ── DASHED RECTANGLE PAINTER ──
class DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double dashLength;
  final double radius;

  const DashedRectPainter({
    this.color = const Color(0xFFCBD5E1),
    this.strokeWidth = 1.2,
    this.gap = 4.0,
    this.dashLength = 6.0,
    this.radius = 12.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(radius)));
    final dashPath = Path();
    double distance = 0.0;
    for (final metric in path.computeMetrics()) {
      while (distance < metric.length) {
        final next = distance + dashLength;
        final isLast = next >= metric.length;
        dashPath.addPath(
            metric.extractPath(distance, isLast ? metric.length : next),
            Offset.zero);
        distance = next + gap;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant DashedRectPainter old) => false;
}
