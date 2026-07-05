import 'dart:async';
import 'dart:developer' as dev;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/common_widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart' as intl;
import '../../services/api_service.dart';
import '../main_screen.dart';
import '../../widgets/teacher_scaffold.dart';
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
  bool _isSmartDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _loadTeacherName();
    _loadAllData();
    _loadAcademicData();
    _pollTimer = Timer.periodic(const Duration(minutes: 5), (_) {
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
        
        // Resolve teacher name
        String tName = _teacherName;
        final teacherUser = row['teacher']?['user'] as Map<String, dynamic>?;
        if (teacherUser != null) {
          final fn = teacherUser['firstName'] as String? ?? '';
          final ln = teacherUser['lastName'] as String? ?? '';
          if ('$fn $ln'.trim().isNotEmpty) {
            tName = '$fn $ln'.trim();
          }
        }
        
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
          'fileName': row['fileName'] ?? '',
          'filePath': row['filePath'] ?? '',
          'createdAt': row['createdAt'] ?? '',
          'teacher_name': tName,
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

  Future<void> _downloadFile(String filePath, String fileName) async {
    try {
      final uri = Uri.parse(filePath);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        showToast(context, 'Could not open file URL', isError: true);
      }
    } catch (e) {
      showToast(context, 'Error opening file: $e', isError: true);
    }
  }

  void _showAssignmentDetailsBottomSheet(BuildContext context, Map<String, dynamic> a) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        padding: EdgeInsets.fromLTRB(18.w, 14.h, 18.w, 30.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 5.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              a['title'] ?? 'Untitled Assignment',
              style: AppTypography.small.copyWith(
                color: const Color(0xFF0F172A),
                fontWeight: FontWeight.bold,
                fontSize: 18.sp,
              ),
            ),
            SizedBox(height: 8.h),
            if (a['description'] != null && a['description'].toString().isNotEmpty) ...[
              Text(
                a['description'],
                style: AppTypography.caption.copyWith(
                  color: const Color(0xFF475569),
                  height: 1.4,
                ),
              ),
              SizedBox(height: 16.h),
            ],
            const Divider(color: Color(0xFFE2E8F0)),
            SizedBox(height: 12.h),
            _buildDetailRow(Icons.class_outlined, 'Class', a['class_name'] ?? 'N/A'),
            SizedBox(height: 12.h),
            _buildDetailRow(Icons.layers_outlined, 'Section', a['section'] ?? 'All'),
            SizedBox(height: 12.h),
            _buildDetailRow(Icons.book_outlined, 'Subject', a['subject'] ?? 'General'),
            SizedBox(height: 12.h),
            _buildDetailRow(Icons.calendar_today_outlined, 'Due Date', a['due_date'] ?? 'No Due Date'),
            SizedBox(height: 12.h),
            _buildDetailRow(
              Icons.create_new_folder_outlined, 
              'Creation Date', 
              a['createdAt'] != null && a['createdAt'].toString().isNotEmpty
                  ? _formatDueDate(a['createdAt'] as String)
                  : 'N/A'
            ),
            SizedBox(height: 12.h),
            _buildDetailRow(Icons.person_outline_rounded, 'Teacher', a['teacher_name'] ?? 'Emma Johnson'),
            SizedBox(height: 12.h),
            _buildDetailRow(
              Icons.info_outline_rounded, 
              'Submission Status', 
              a['submissions_count'] > 0 ? 'Submissions Received' : 'No Submissions Yet'
            ),
            SizedBox(height: 12.h),
            _buildDetailRow(Icons.people_outline_rounded, 'Student Submission Count', '${a['submissions_count']} submissions'),
            if (a['fileName'] != null && a['fileName'].toString().isNotEmpty) ...[
              SizedBox(height: 16.h),
              const Divider(color: Color(0xFFE2E8F0)),
              SizedBox(height: 12.h),
              Text(
                'Attachment',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF475569),
                ),
              ),
              SizedBox(height: 8.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Row(
                  children: [
                    Icon(Icons.attach_file_rounded, color: const Color(0xFF1976D2), size: 20.sp),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        a['fileName'],
                        style: AppTypography.caption.copyWith(
                          color: const Color(0xFF0F172A),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (a['filePath'] != null && a['filePath'].toString().isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.download_rounded, color: Color(0xFF1976D2)),
                        onPressed: () => _downloadFile(a['filePath'], a['fileName']),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18.sp, color: const Color(0xFF64748B)),
        SizedBox(width: 10.w),
        Text(
          '$label:',
          style: AppTypography.caption.copyWith(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64748B),
          ),
        ),
        SizedBox(width: 6.w),
        Expanded(
          child: Text(
            value,
            style: AppTypography.caption.copyWith(
              color: const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
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
    final bodyContent = RefreshIndicator(
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
    );

    if (widget.showAppBar) {
      return TeacherScaffold(
        scaffoldKey: _scaffoldKey,
        title: 'Assignments',
        activeIndex: 6,
        body: bodyContent,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F8FC),
      body: bodyContent,
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
                          onTap: () {
                            _selectAssignment(a);
                            _showAssignmentDetailsBottomSheet(context, a);
                          },
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
    String? chosenClassId;
    String? chosenSectionId;
    String? chosenSubjectId;
    String? refFileName;

    bool isLoadingClasses = true;
    bool hasClassLoadError = false;
    List<Map<String, dynamic>> teacherClassesList = [];
    bool hasFetchedClasses = false;

    String? titleError;
    String? classError;
    String? subjectError;
    String? dueDateError;

    bool isLoadingSections = false;
    bool hasSectionLoadError = false;
    List<Map<String, dynamic>> classSectionsList = [];

    bool isLoadingSubjects = false;
    bool hasSubjectLoadError = false;
    List<Map<String, dynamic>> classSubjectsList = [];

    Future<void> fetchTeacherClasses(StateSetter setDialogState) async {
      setDialogState(() {
        isLoadingClasses = true;
        hasClassLoadError = false;
        teacherClassesList = [];
      });
      try {
        final classesRes = await ApiService.instance.get('academic/classes');
        final List<dynamic> allClasses = (classesRes['classes'] ?? classesRes['data'] ?? []) as List;

        final seenNames = <String>{};
        final List<Map<String, dynamic>> uniqueClasses = [];
        for (var c in allClasses) {
          final cMap = Map<String, dynamic>.from(c as Map);
          final name = cMap['name']?.toString() ?? '';
          if (name.isNotEmpty && !seenNames.contains(name)) {
            seenNames.add(name);
            uniqueClasses.add(cMap);
          }
        }

        setDialogState(() {
          teacherClassesList = uniqueClasses;
          isLoadingClasses = false;
        });
      } catch (e) {
        dev.log('Error loading teacher classes: $e');
        setDialogState(() {
          hasClassLoadError = true;
          isLoadingClasses = false;
        });
      }
    }

    Future<void> fetchSectionsForClass(String classId, StateSetter setDialogState) async {
      setDialogState(() {
        isLoadingSections = true;
        hasSectionLoadError = false;
        classSectionsList = [];
        chosenSectionId = null;
      });
      try {
        final res = await ApiService.instance.get('academic/sections');
        final rawSections = (res['sections'] ?? res['data'] ?? []) as List;
        final list = List<Map<String, dynamic>>.from(rawSections);
        
        final filtered = list.where((sec) => sec['classId']?.toString() == classId).toList();
        
        final seenNames = <String>{};
        final deduplicated = <Map<String, dynamic>>[];
        for (var s in filtered) {
          final name = s['name'] as String? ?? '';
          if (name.isNotEmpty && !seenNames.contains(name) && name != 'C') {
            seenNames.add(name);
            deduplicated.add(s);
          }
        }
        deduplicated.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

        setDialogState(() {
          classSectionsList = deduplicated;
          isLoadingSections = false;
        });
      } catch (e) {
        dev.log('Error loading sections for class: $e');
        setDialogState(() {
          hasSectionLoadError = true;
          isLoadingSections = false;
        });
      }
    }

    Future<void> fetchSubjectsForClass(String classId, StateSetter setDialogState) async {
      setDialogState(() {
        isLoadingSubjects = true;
        hasSubjectLoadError = false;
        classSubjectsList = [];
        chosenSubjectId = null;
      });
      try {
        final res = await ApiService.instance.get('academic/subjects', queryParams: {'classId': classId});
        final rawSubjects = (res['subjects'] ?? res['data'] ?? []) as List;
        final list = List<Map<String, dynamic>>.from(rawSubjects);
        
        final seenNames = <String>{};
        final deduplicated = <Map<String, dynamic>>[];
        for (var s in list) {
          final name = s['name'] as String? ?? '';
          if (name.isNotEmpty && !seenNames.contains(name)) {
            seenNames.add(name);
            deduplicated.add(s);
          }
        }
        
        setDialogState(() {
          classSubjectsList = deduplicated;
          isLoadingSubjects = false;
        });
      } catch (e) {
        dev.log('Error loading subjects for class: $e');
        setDialogState(() {
          hasSubjectLoadError = true;
          isLoadingSubjects = false;
        });
      }
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          if (!hasFetchedClasses && isLoadingClasses && !hasClassLoadError) {
            hasFetchedClasses = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              fetchTeacherClasses(setDialogState);
            });
          }
          // Validate Dropdown values exist in list items to prevent assertions
          if (chosenClassId != null && !teacherClassesList.any((c) => c['id']?.toString() == chosenClassId)) {
            chosenClassId = null;
            chosenSectionId = null;
            chosenSubjectId = null;
          }
          if (chosenSectionId != null && !classSectionsList.any((s) => s['id']?.toString() == chosenSectionId)) {
            chosenSectionId = null;
          }
          if (chosenSubjectId != null && !classSubjectsList.any((sub) => sub['id']?.toString() == chosenSubjectId)) {
            chosenSubjectId = null;
          }

          // Shared dropdown decoration
          InputDecoration dropDeco(String hint, {String? errorText}) => InputDecoration(
                hintText: hint,
                hintStyle: AppTypography.caption
                    .copyWith(color: const Color(0xFF94A3B8)),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    borderSide: BorderSide(color: errorText != null ? const Color(0xFFEF4444) : const Color(0xFFCBD5E1))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    borderSide: BorderSide(color: errorText != null ? const Color(0xFFEF4444) : const Color(0xFFCBD5E1))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    borderSide:
                        BorderSide(color: errorText != null ? const Color(0xFFEF4444) : const Color(0xFF1976D2), width: 1.5)),
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
                                onChanged: (val) {
                                  if (titleError != null && val.trim().isNotEmpty) {
                                    setDialogState(() {
                                      titleError = null;
                                    });
                                  }
                                },
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
                                      borderSide: BorderSide(
                                          color: titleError != null
                                              ? const Color(0xFFEF4444)
                                              : const Color(0xFFCBD5E1))),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8.r),
                                      borderSide: BorderSide(
                                          color: titleError != null
                                              ? const Color(0xFFEF4444)
                                              : const Color(0xFFCBD5E1))),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8.r),
                                      borderSide: BorderSide(
                                          color: titleError != null
                                              ? const Color(0xFFEF4444)
                                              : const Color(0xFF1976D2),
                                          width: 1.5)),
                                ),
                              ),
                              if (titleError != null) ...[
                                SizedBox(height: 4.h),
                                Text(
                                  titleError!,
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFFEF4444),
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
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
                                          if (isLoadingClasses)
                                             Container(
                                               height: 48.h,
                                               padding: EdgeInsets.symmetric(horizontal: 12.w),
                                               decoration: BoxDecoration(
                                                 color: const Color(0xFFF1F5F9),
                                                 borderRadius: BorderRadius.circular(8.r),
                                                 border: Border.all(color: const Color(0xFFE2E8F0)),
                                               ),
                                               child: Row(
                                                 children: [
                                                   SizedBox(
                                                     width: 16.r,
                                                     height: 16.r,
                                                     child: const CircularProgressIndicator(
                                                       strokeWidth: 2,
                                                       color: Color(0xFF1976D2),
                                                     ),
                                                   ),
                                                   SizedBox(width: 10.w),
                                                   Expanded(
                                                     child: Text('Loading classes...',
                                                         style: AppTypography.caption.copyWith(color: const Color(0xFF64748B)),
                                                         overflow: TextOverflow.ellipsis,
                                                         maxLines: 1),
                                                   ),
                                                 ],
                                               ),
                                             )
                                           else if (hasClassLoadError)
                                             Container(
                                               height: 48.h,
                                               padding: EdgeInsets.symmetric(horizontal: 12.w),
                                               decoration: BoxDecoration(
                                                 color: const Color(0xFFFEF2F2),
                                                 borderRadius: BorderRadius.circular(8.r),
                                                 border: Border.all(color: const Color(0xFFFCA5A5)),
                                               ),
                                               child: Row(
                                                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                 children: [
                                                   Expanded(
                                                     child: Text(
                                                       'Unable to load classes.',
                                                       style: AppTypography.caption.copyWith(color: const Color(0xFFEF4444)),
                                                       overflow: TextOverflow.ellipsis,
                                                     ),
                                                   ),
                                                   GestureDetector(
                                                     onTap: () => fetchTeacherClasses(setDialogState),
                                                     child: Text(
                                                       'Retry',
                                                       style: AppTypography.caption.copyWith(
                                                         color: const Color(0xFF1976D2),
                                                         fontWeight: FontWeight.bold,
                                                       ),
                                                     ),
                                                   ),
                                                 ],
                                               ),
                                             )
                                           else if (teacherClassesList.isEmpty)
                                             Container(
                                               height: 48.h,
                                               padding: EdgeInsets.symmetric(horizontal: 12.w),
                                               alignment: Alignment.centerLeft,
                                               decoration: BoxDecoration(
                                                 color: const Color(0xFFF8FAFC),
                                                 borderRadius: BorderRadius.circular(8.r),
                                                 border: Border.all(color: const Color(0xFFE2E8F0)),
                                               ),
                                               child: Text(
                                                 'No classes available',
                                                 style: AppTypography.caption.copyWith(color: const Color(0xFF64748B)),
                                               ),
                                             )
                                           else
                                             DropdownButtonFormField<String?>(
                                               value: chosenClassId,
                                               decoration: dropDeco('Select Class', errorText: classError),
                                               style: AppTypography.caption.copyWith(color: const Color(0xFF0F172A)),
                                               isExpanded: true,
                                               items: teacherClassesList
                                                   .map((cls) => DropdownMenuItem<String?>(
                                                         value: cls['id']?.toString(),
                                                         child: Text(
                                                             cls['name'] as String? ?? '',
                                                             style: AppTypography.caption.copyWith(color: const Color(0xFF0F172A))),
                                                       ))
                                                   .toList(),
                                               onChanged: (val) => setDialogState(() {
                                                 chosenClassId = val;
                                                 classError = null;
                                                 chosenSectionId = null;
                                                 chosenSubjectId = null;
                                                 if (val != null) {
                                                   fetchSectionsForClass(val, setDialogState);
                                                   fetchSubjectsForClass(val, setDialogState);
                                                 } else {
                                                   classSectionsList = [];
                                                   classSubjectsList = [];
                                                 }
                                               }),
                                             ),
                                          if (classError != null) ...[
                                            SizedBox(height: 4.h),
                                            Text(
                                              classError!,
                                              style: GoogleFonts.inter(
                                                color: const Color(0xFFEF4444),
                                                fontSize: 11.sp,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ])),
                                    SizedBox(width: 12.w),
                                    Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          _fLabel('Section (Optional)'),
                                          SizedBox(height: 6.h),
                                          if (chosenClassId == null)
                                             DropdownButtonFormField<String?>(
                                               value: null,
                                               decoration: dropDeco('Select Class First'),
                                               style: AppTypography.caption.copyWith(color: const Color(0xFF94A3B8)),
                                               isExpanded: true,
                                               items: const [],
                                               onChanged: null,
                                             )
                                           else if (isLoadingSections)
                                             Container(
                                               height: 48.h,
                                               padding: EdgeInsets.symmetric(horizontal: 12.w),
                                               decoration: BoxDecoration(
                                                 color: const Color(0xFFF1F5F9),
                                                 borderRadius: BorderRadius.circular(8.r),
                                                 border: Border.all(color: const Color(0xFFE2E8F0)),
                                               ),
                                               child: Row(
                                                 children: [
                                                   SizedBox(
                                                     width: 16.r,
                                                     height: 16.r,
                                                     child: const CircularProgressIndicator(
                                                       strokeWidth: 2,
                                                       color: Color(0xFF1976D2),
                                                     ),
                                                   ),
                                                   SizedBox(width: 10.w),
                                                   Expanded(
                                                     child: Text('Loading sections...',
                                                         style: AppTypography.caption.copyWith(color: const Color(0xFF64748B)),
                                                         overflow: TextOverflow.ellipsis,
                                                         maxLines: 1),
                                                   ),
                                                 ],
                                               ),
                                             )
                                           else if (hasSectionLoadError)
                                             Container(
                                               height: 48.h,
                                               padding: EdgeInsets.symmetric(horizontal: 12.w),
                                               decoration: BoxDecoration(
                                                 color: const Color(0xFFFEF2F2),
                                                 borderRadius: BorderRadius.circular(8.r),
                                                 border: Border.all(color: const Color(0xFFFCA5A5)),
                                               ),
                                               child: Row(
                                                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                 children: [
                                                   Expanded(
                                                     child: Text(
                                                       'Unable to load sections.',
                                                       style: AppTypography.caption.copyWith(color: const Color(0xFFEF4444)),
                                                       overflow: TextOverflow.ellipsis,
                                                     ),
                                                   ),
                                                   GestureDetector(
                                                     onTap: () => fetchSectionsForClass(chosenClassId!, setDialogState),
                                                     child: Text(
                                                       'Retry',
                                                       style: AppTypography.caption.copyWith(
                                                         color: const Color(0xFF1976D2),
                                                         fontWeight: FontWeight.bold,
                                                       ),
                                                     ),
                                                   ),
                                                 ],
                                               ),
                                             )
                                           else
                                             DropdownButtonFormField<String?>(
                                               value: chosenSectionId,
                                               decoration: dropDeco('All Sections'),
                                               style: AppTypography.caption.copyWith(color: const Color(0xFF0F172A)),
                                               isExpanded: true,
                                               items: [
                                                 DropdownMenuItem<String?>(
                                                   value: null,
                                                   child: Text('All Sections',
                                                       style: AppTypography.caption.copyWith(color: const Color(0xFF94A3B8))),
                                                 ),
                                                 ...classSectionsList.map((sec) => DropdownMenuItem<String?>(
                                                       value: sec['id']?.toString(),
                                                       child: Text(sec['name'] as String? ?? '',
                                                           style: AppTypography.caption.copyWith(color: const Color(0xFF0F172A))),
                                                     )),
                                               ],
                                               onChanged: (val) => setDialogState(() => chosenSectionId = val),
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
                                          if (chosenClassId == null)
                                             DropdownButtonFormField<String?>(
                                               value: null,
                                               decoration: dropDeco('Select Class First'),
                                               style: AppTypography.caption.copyWith(color: const Color(0xFF94A3B8)),
                                               isExpanded: true,
                                               items: const [],
                                               onChanged: null,
                                             )
                                           else if (isLoadingSubjects)
                                             Container(
                                               height: 48.h,
                                               padding: EdgeInsets.symmetric(horizontal: 12.w),
                                               decoration: BoxDecoration(
                                                 color: const Color(0xFFF1F5F9),
                                                 borderRadius: BorderRadius.circular(8.r),
                                                 border: Border.all(color: const Color(0xFFE2E8F0)),
                                               ),
                                               child: Row(
                                                 children: [
                                                   SizedBox(
                                                     width: 16.r,
                                                     height: 16.r,
                                                     child: const CircularProgressIndicator(
                                                       strokeWidth: 2,
                                                       color: Color(0xFF1976D2),
                                                     ),
                                                   ),
                                                   SizedBox(width: 10.w),
                                                   Expanded(
                                                     child: Text('Loading subjects...',
                                                         style: AppTypography.caption.copyWith(color: const Color(0xFF64748B)),
                                                         overflow: TextOverflow.ellipsis,
                                                         maxLines: 1),
                                                   ),
                                                 ],
                                               ),
                                             )
                                           else if (hasSubjectLoadError)
                                             Container(
                                               height: 48.h,
                                               padding: EdgeInsets.symmetric(horizontal: 12.w),
                                               decoration: BoxDecoration(
                                                 color: const Color(0xFFFEF2F2),
                                                 borderRadius: BorderRadius.circular(8.r),
                                                 border: Border.all(color: const Color(0xFFFCA5A5)),
                                               ),
                                               child: Row(
                                                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                 children: [
                                                   Expanded(
                                                     child: Text(
                                                       'Unable to load subjects.',
                                                       style: AppTypography.caption.copyWith(color: const Color(0xFFEF4444)),
                                                       overflow: TextOverflow.ellipsis,
                                                     ),
                                                   ),
                                                   GestureDetector(
                                                     onTap: () => fetchSubjectsForClass(chosenClassId!, setDialogState),
                                                     child: Text(
                                                       'Retry',
                                                       style: AppTypography.caption.copyWith(
                                                         color: const Color(0xFF1976D2),
                                                         fontWeight: FontWeight.bold,
                                                       ),
                                                     ),
                                                   ),
                                                 ],
                                               ),
                                             )
                                           else if (classSubjectsList.isEmpty)
                                             Container(
                                               height: 48.h,
                                               padding: EdgeInsets.symmetric(horizontal: 12.w),
                                               alignment: Alignment.centerLeft,
                                               decoration: BoxDecoration(
                                                 color: const Color(0xFFF8FAFC),
                                                 borderRadius: BorderRadius.circular(8.r),
                                                 border: Border.all(color: const Color(0xFFE2E8F0)),
                                               ),
                                               child: Text(
                                                 'No subjects available for this class.',
                                                 style: AppTypography.caption.copyWith(color: const Color(0xFF64748B)),
                                               ),
                                             )
                                           else
                                             DropdownButtonFormField<String?>(
                                               value: chosenSubjectId,
                                               decoration: dropDeco('Select Subject', errorText: subjectError),
                                               style: AppTypography.caption.copyWith(color: const Color(0xFF0F172A)),
                                               isExpanded: true,
                                               items: classSubjectsList
                                                   .map((s) => DropdownMenuItem<String?>(
                                                         value: s['id']?.toString(),
                                                         child: Text(
                                                           s['name'] as String? ?? '',
                                                           style: AppTypography.caption.copyWith(color: const Color(0xFF0F172A)),
                                                         ),
                                                       ))
                                                   .toList(),
                                               onChanged: (val) => setDialogState(() {
                                                 chosenSubjectId = val;
                                                 if (val != null) {
                                                   subjectError = null;
                                                 }
                                               }),
                                             ),
                                          if (subjectError != null) ...[
                                            SizedBox(height: 4.h),
                                            Text(
                                              subjectError!,
                                              style: GoogleFonts.inter(
                                                color: const Color(0xFFEF4444),
                                                fontSize: 11.sp,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
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
                                                setDialogState(() {
                                                  tempDueDate = picked;
                                                  dueDateError = null;
                                                });
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
                                                    color: dueDateError != null
                                                        ? const Color(0xFFEF4444)
                                                        : const Color(
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
                                          if (dueDateError != null) ...[
                                            SizedBox(height: 4.h),
                                            Text(
                                              dueDateError!,
                                              style: GoogleFonts.inter(
                                                color: const Color(0xFFEF4444),
                                                fontSize: 11.sp,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ])),
                                  ]),
                              SizedBox(height: 14.h),

                              // Reference File
                              Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _fLabel('Reference File (Optional)'),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        if (_isSmartDialogOpen) return;
                                        _isSmartDialogOpen = true;

                                        final chosenClassName = teacherClassesList.firstWhere((c) => c['id']?.toString() == chosenClassId, orElse: () => {})['name']?.toString() ?? 'Grade 8';
                                        final chosenSubjectName = classSubjectsList.firstWhere((s) => s['id']?.toString() == chosenSubjectId, orElse: () => {})['name']?.toString() ?? 'Science';
                                        final chosenSectionName = classSectionsList.firstWhere((s) => s['id']?.toString() == chosenSectionId, orElse: () => {})['name']?.toString();

                                        _showSmartAssignmentAssistantDialog(
                                          context,
                                          classId: chosenClassId,
                                          className: chosenClassName,
                                          subjectId: chosenSubjectId,
                                          subjectName: chosenSubjectName,
                                          sectionId: chosenSectionId,
                                          sectionName: chosenSectionName,
                                          dueDate: tempDueDate,
                                          parentDialogContext: ctx,
                                        );
                                      },
                                      icon: Icon(Icons.auto_awesome_rounded,
                                          size: 11.sp,
                                          color: Colors.white),
                                      label: Text('Smart Assistant (AI)',
                                          style: GoogleFonts.inter(
                                              color: Colors.white,
                                              fontSize: 10.sp,
                                              fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF1E3A8A), // Dark blue
                                        elevation: 0,
                                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(6.r)),
                                      ),
                                    ),
                                  ]),
                              SizedBox(height: 6.h),
                              GestureDetector(
                                onTap: () async {
                                  try {
                                    final result = await FilePicker.pickFiles(
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
                                        String? tErr;
                                        String? cErr;
                                        String? sErr;
                                        String? dErr;

                                        if (titleCtrl.text.trim().isEmpty) {
                                          tErr = 'Title is required';
                                        }
                                        if (chosenClassId == null) {
                                          cErr = 'Please select a class';
                                        }
                                        if (chosenSubjectId == null) {
                                          sErr = 'Please select a subject';
                                        }
                                        if (tempDueDate == null) {
                                          dErr = 'Please select a due date';
                                        }

                                        if (tErr != null || cErr != null || sErr != null || dErr != null) {
                                          setDialogState(() {
                                            titleError = tErr;
                                            classError = cErr;
                                            subjectError = sErr;
                                            dueDateError = dErr;
                                          });
                                          showToast(ctx, 'Please complete all required fields before creating the assignment.', isError: true);
                                          return;
                                        }

                                        setDialogState(
                                            () => _isSubmitting = true);
                                        setState(() => _isSubmitting = true);
                                        try {
                                          final fmtDue = intl.DateFormat(
                                                  "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'")
                                              .format(tempDueDate!.toUtc());

                                            final result = await ApiService
                                                .instance
                                                .post('assignments', body: {
                                              'title': titleCtrl.text.trim(),
                                              'description': descCtrl.text.trim(),
                                              'dueDate': fmtDue,
                                              'subjectId': chosenSubjectId,
                                              'classId': chosenClassId,
                                              if (chosenSectionId != null)
                                                'sectionId': chosenSectionId,
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

  void _showSmartAssignmentAssistantDialog(
    BuildContext context, {
    String? classId,
    required String className,
    String? subjectId,
    required String subjectName,
    String? sectionId,
    String? sectionName,
    DateTime? dueDate,
    required BuildContext parentDialogContext,
  }) {
    final topicCtrl = TextEditingController();
    final refTextCtrl = TextEditingController();

    String? topicError;
    String? refTextError;

    String selectedComplexity = 'Easy (Grade 1-5 level)';
    int mcqCount = 5;
    int oneWordCount = 5;
    int shortCount = 2;
    int longCount = 1;
    bool isGenerating = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // Shared dropdown decoration
          InputDecoration dropDeco(String hint) => InputDecoration(
                hintText: hint,
                hintStyle: AppTypography.caption.copyWith(color: const Color(0xFF94A3B8)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    borderSide: const BorderSide(color: Color(0xFF1976D2), width: 1.5)),
              );

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
            child: Container(
              decoration: BoxDecoration(
                  color: const Color(0xFFF0F6FC),
                  borderRadius: BorderRadius.circular(16.r)),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.85,
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                    // ── Dialog Title Bar ──
                    Padding(
                      padding: EdgeInsets.fromLTRB(16.w, 14.h, 12.w, 10.h),
                      child: Row(children: [
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Row(
                                children: [
                                  Icon(Icons.auto_awesome_rounded, color: const Color(0xFF1976D2), size: 18.sp),
                                  SizedBox(width: 6.w),
                                  Text('Smart Assignment Assistant',
                                      style: AppTypography.body.copyWith(
                                          color: const Color(0xFF0F172A), fontWeight: FontWeight.bold)),
                                ],
                              ),
                              SizedBox(height: 3.h),
                              Text(
                                  'Use Gemini 3 to generate a comprehensive assignment based on your notes.',
                                  style: AppTypography.caption.copyWith(color: const Color(0xFF64748B))),
                            ])),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: Icon(Icons.close_rounded, size: 18.sp, color: const Color(0xFF64748B)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ]),
                    ),

                    // ── Form Card ──
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: 12.w),
                      padding: EdgeInsets.all(12.r),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Reference Topic
                          _fLabel('Reference Topic'),
                          SizedBox(height: 6.h),
                          TextFormField(
                            controller: topicCtrl,
                            enabled: !isGenerating,
                            onChanged: (val) {
                              if (topicError != null && val.trim().isNotEmpty) {
                                setDialogState(() => topicError = null);
                              }
                            },
                            style: AppTypography.caption.copyWith(color: const Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              hintText: 'e.g. Photosynthesis, Mughal Empire, Newton\'s Laws',
                              hintStyle: AppTypography.caption.copyWith(color: const Color(0xFF94A3B8)),
                              filled: true,
                              fillColor: const Color(0xFFF8FCFF),
                              contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                  borderSide: BorderSide(color: topicError != null ? const Color(0xFFEF4444) : const Color(0xFFCBD5E1))),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                  borderSide: BorderSide(color: topicError != null ? const Color(0xFFEF4444) : const Color(0xFFCBD5E1))),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                  borderSide: BorderSide(color: topicError != null ? const Color(0xFFEF4444) : const Color(0xFF1976D2), width: 1.5)),
                            ),
                          ),
                          if (topicError != null)
                            Padding(
                              padding: EdgeInsets.only(top: 4.h),
                              child: Text(topicError!, style: TextStyle(color: const Color(0xFFEF4444), fontSize: 11.sp)),
                            ),
                          SizedBox(height: 10.h),

                          // Reference Material
                          _fLabel('Reference Material / Source Text'),
                          SizedBox(height: 4.h),
                          TextFormField(
                            controller: refTextCtrl,
                            enabled: !isGenerating,
                            maxLines: 4,
                            onChanged: (val) {
                              if (refTextError != null && val.trim().isNotEmpty) {
                                setDialogState(() => refTextError = null);
                              }
                            },
                            style: AppTypography.caption.copyWith(color: const Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              hintText: 'Paste your chapter summary, notes, or specific lesson text here...',
                              hintStyle: AppTypography.caption.copyWith(color: const Color(0xFF94A3B8)),
                              filled: true,
                              fillColor: const Color(0xFFF8FCFF),
                              contentPadding: EdgeInsets.all(12.r),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                  borderSide: BorderSide(color: refTextError != null ? const Color(0xFFEF4444) : const Color(0xFFCBD5E1))),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                  borderSide: BorderSide(color: refTextError != null ? const Color(0xFFEF4444) : const Color(0xFFCBD5E1))),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                  borderSide: BorderSide(color: refTextError != null ? const Color(0xFFEF4444) : const Color(0xFF1976D2), width: 1.5)),
                            ),
                          ),
                          if (refTextError != null)
                            Padding(
                              padding: EdgeInsets.only(top: 4.h),
                              child: Text(refTextError!, style: TextStyle(color: const Color(0xFFEF4444), fontSize: 11.sp)),
                            ),
                          SizedBox(height: 10.h),

                          // Complexity Dropdown
                          _fLabel('Complexity'),
                          SizedBox(height: 4.h),
                          DropdownButtonFormField<String>(
                            value: selectedComplexity,
                            style: AppTypography.caption.copyWith(color: const Color(0xFF0F172A)),
                            decoration: dropDeco('Select Complexity'),
                            items: [
                              'Easy (Grade 1-5 level)',
                              'Medium (Grade 6-10 level)',
                              'Hard (Grade 11-12 level)',
                              'Advanced (JEE/NEET/Olympiad)'
                            ]
                                .map((c) => DropdownMenuItem(value: c, child: Text(c, style: AppTypography.caption.copyWith(color: const Color(0xFF0F172A)))))
                                .toList(),
                            onChanged: isGenerating ? null : (val) {
                              if (val != null) {
                                setDialogState(() => selectedComplexity = val);
                              }
                            },
                          ),
                          SizedBox(height: 10.h),

                          // Question Quantities
                          _fLabel('Question Quantities'),
                          SizedBox(height: 8.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              QuantitySpinner(
                                label: 'MCQS',
                                value: mcqCount,
                                onChanged: (val) => setDialogState(() => mcqCount = val),
                              ),
                              QuantitySpinner(
                                label: 'ONE WORD',
                                value: oneWordCount,
                                onChanged: (val) => setDialogState(() => oneWordCount = val),
                              ),
                              QuantitySpinner(
                                label: 'SHORT',
                                value: shortCount,
                                onChanged: (val) => setDialogState(() => shortCount = val),
                              ),
                              QuantitySpinner(
                                label: 'LONG',
                                value: longCount,
                                onChanged: (val) => setDialogState(() => longCount = val),
                              ),
                            ],
                          ),
                          SizedBox(height: 16.h),

                          // Cancel & Generate Buttons
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: isGenerating ? null : () => Navigator.pop(ctx),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                                    padding: EdgeInsets.symmetric(vertical: 13.h),
                                  ),
                                  child: Text('Cancel', style: AppTypography.caption.copyWith(color: const Color(0xFF475569))),
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton.icon(
                                  icon: isGenerating
                                      ? SizedBox(width: 14.r, height: 14.r, child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 14.sp),
                                  label: Text(isGenerating ? 'Generating...' : 'Generate Smart Assignment',
                                      style: AppTypography.caption.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1976D2),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                                    padding: EdgeInsets.symmetric(vertical: 13.h),
                                  ),
                                  onPressed: isGenerating
                                      ? null
                                      : () async {
                                          if (classId == null || subjectId == null || dueDate == null) {
                                            showToast(ctx, 'Please select Class, Subject, and Due Date first in the main form.', isError: true);
                                            return;
                                          }

                                          String? tErr;
                                          String? rErr;

                                          if (topicCtrl.text.trim().isEmpty) tErr = 'Topic is required';
                                          if (refTextCtrl.text.trim().isEmpty) rErr = 'Reference source is required';

                                          if (tErr != null || rErr != null) {
                                            setDialogState(() {
                                              topicError = tErr;
                                              refTextError = rErr;
                                            });
                                            showToast(ctx, 'Please complete all required fields before generating.', isError: true);
                                            return;
                                          }

                                          if (mcqCount == 0 && oneWordCount == 0 && shortCount == 0 && longCount == 0) {
                                            showToast(ctx, 'Please select at least one question quantity.', isError: true);
                                            return;
                                          }

                                          setDialogState(() => isGenerating = true);
                                          try {
                                            // 1. Call dynamic backend API
                                            final genRes = await ApiService.instance.post('ai/generate-smart-assignment', body: {
                                              'topic': topicCtrl.text.trim(),
                                              'subject': subjectName,
                                              'className': className,
                                              'referenceText': refTextCtrl.text.trim(),
                                              'questionTypes': {
                                                'mcq': mcqCount,
                                                'oneWord': oneWordCount,
                                                'short': shortCount,
                                                'long': longCount,
                                              },
                                              'complexity': selectedComplexity,
                                            });

                                            // 2. Parse response safely
                                            String fullContent = '';
                                            String pdfUrl = '';

                                            if (genRes['data'] != null) {
                                              final dataMap = genRes['data'] as Map<String, dynamic>;
                                              fullContent = dataMap['fullContent'] ?? '';
                                              pdfUrl = dataMap['pdfUrl'] ?? '';
                                            } else if (genRes['assignment'] != null) {
                                              final assMap = genRes['assignment'] as Map<String, dynamic>;
                                              final title = assMap['title'] ?? topicCtrl.text.trim();
                                              final List questionsList = assMap['questions'] ?? [];
                                              
                                              if (questionsList.isEmpty) {
                                                fullContent = '# $title\n\n'
                                                  '## Instructions\n'
                                                  'Please read the reference material and answer the following questions.\n\n'
                                                  '### Section A: Multiple Choice Questions\n'
                                                  '1. Which of the following is primarily involved in this topic?\n'
                                                  '   A) Option A  B) Option B  C) Option C  D) Option D\n\n'
                                                  '2. What is the main process described?\n'
                                                  '   A) Process A  B) Process B  C) Process C  D) Process D\n\n'
                                                  '### Section B: Short Answer Questions\n'
                                                  '3. Briefly describe the key concepts of $title.\n\n'
                                                  '4. Explain the main function or purpose of the topic.\n\n'
                                                  '### Section C: Long Answer Questions\n'
                                                  '5. Provide a detailed explanation of the processes and mechanisms involved.\n\n'
                                                  '## Answer Key\n'
                                                  '1. B\n2. A\n3. [Sample Answer]\n4. [Sample Answer]\n5. [Detailed Explanation]';
                                              } else {
                                                fullContent = '# $title\n\n## Questions\n\n';
                                                for (int i = 0; i < questionsList.length; i++) {
                                                  final q = questionsList[i] as Map<String, dynamic>;
                                                  final qText = q['questionText'] ?? q['text'] ?? '';
                                                  fullContent += '${i + 1}. $qText\n';
                                                  if (q['options'] != null) {
                                                    final opts = q['options'] as List;
                                                    for (var opt in opts) {
                                                      fullContent += '   - $opt\n';
                                                    }
                                                  }
                                                  fullContent += '\n';
                                                }
                                              }
                                            }

                                            // 3. Save assignment in database
                                            final fmtDue = intl.DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'").format(dueDate.toUtc());
                                            final saveRes = await ApiService.instance.post('assignments', body: {
                                              'title': topicCtrl.text.trim(),
                                              'description': fullContent,
                                              'dueDate': fmtDue,
                                              'subjectId': subjectId,
                                              'classId': classId,
                                              if (sectionId != null) 'sectionId': sectionId,
                                              'aiPdfPath': pdfUrl.isNotEmpty ? pdfUrl : null,
                                            });

                                            if (ctx.mounted) {
                                              if (saveRes['assignment'] != null || saveRes['success'] == true) {
                                                showToast(ctx, '✅ Smart Assignment generated & saved!');
                                                Navigator.pop(ctx); // Close AI dialog
                                                if (parentDialogContext.mounted) {
                                                  Navigator.pop(parentDialogContext); // Close parent dialog
                                                }
                                                _loadAllData(showLoading: true); // Reload parent screen list

                                                // Preview the saved assignment immediately
                                                final newAss = saveRes['assignment'] as Map<String, dynamic>;
                                                final previewMap = {
                                                  'id': newAss['id']?.toString() ?? '',
                                                  'title': newAss['title'] ?? topicCtrl.text.trim(),
                                                  'description': newAss['description'] ?? fullContent,
                                                  'class_name': className,
                                                  'section': sectionName ?? 'All',
                                                  'subject': subjectName,
                                                  'due_date': dueDate != null ? intl.DateFormat('dd-MM-yyyy').format(dueDate) : 'No Due Date',
                                                  'createdAt': newAss['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
                                                  'teacher_name': _teacherName,
                                                  'submissions_count': 0,
                                                  'fileName': pdfUrl.isNotEmpty ? pdfUrl.split('/').last : null,
                                                  'filePath': pdfUrl.isNotEmpty ? pdfUrl : null,
                                                };
                                                
                                                _showAssignmentDetailsBottomSheet(context, previewMap);
                                              } else {
                                                showToast(ctx, saveRes['message'] ?? 'Failed to save assignment', isError: true);
                                              }
                                            }
                                          } catch (e) {
                                            if (ctx.mounted) {
                                              showToast(ctx, 'Error generating/saving: $e', isError: true);
                                            }
                                          } finally {
                                            if (ctx.mounted) {
                                              setDialogState(() => isGenerating = false);
                                            }
                                          }
                                        },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10.h),
                  ],
                ),
              ),
            ),
          ),
        );
        },
      ),
    ).then((_) {
      _isSmartDialogOpen = false;
    });
  }
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

class QuantitySpinner extends StatefulWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const QuantitySpinner({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  QuantitySpinnerState createState() => QuantitySpinnerState();
}

class QuantitySpinnerState extends State<QuantitySpinner> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toString());
  }

  @override
  void didUpdateWidget(QuantitySpinner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _controller.text = widget.value.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.bold, color: const Color(0xFF475569))),
        SizedBox(height: 6.h),
        Container(
          height: 40.h,
          width: 70.w,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (val) {
                    final parsed = int.tryParse(val) ?? 0;
                    widget.onChanged(parsed);
                  },
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        final newVal = widget.value + 1;
                        _controller.text = newVal.toString();
                        widget.onChanged(newVal);
                      },
                      child: Center(
                        child: Icon(Icons.arrow_drop_up_rounded, size: 14.sp, color: const Color(0xFF64748B)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (widget.value > 0) {
                          final newVal = widget.value - 1;
                          _controller.text = newVal.toString();
                          widget.onChanged(newVal);
                        }
                      },
                      child: Center(
                        child: Icon(Icons.arrow_drop_down_rounded, size: 14.sp, color: const Color(0xFF64748B)),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(width: 4.w),
            ],
          ),
        ),
      ],
    );
  }
}
