import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/common_widgets.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart' as intl;
import 'package:edusphere/theme/typography.dart';

class AssignmentsScreen extends StatefulWidget {
  const AssignmentsScreen({super.key});
  @override
  State<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends State<AssignmentsScreen> {
  bool _isLoading = true;

  String _studentEmailStr = 'alex.rivera@edusmart.edu';
  String _studentIdStr = '';
  String _classNameStr = 'Grade 12';
  String _sectionStr = 'A';

  final List<Map<String, dynamic>> _assignments = [];
  final String _selectedSubject = 'All';

  RealtimeChannel? _assignmentsChannel;
  Timer? _assignmentsPollTimer;

  @override
  void initState() {
    super.initState();
    _loadAssignmentsData();
    _connectRealTime();
  }

  @override
  void dispose() {
    _assignmentsPollTimer?.cancel();
    if (_assignmentsChannel != null) {
      try {
        Supabase.instance.client.removeChannel(_assignmentsChannel!);
      } catch (_) {}
    }
    super.dispose();
  }

  void _connectRealTime() {
    try {
      final client = Supabase.instance.client;

      if (_assignmentsChannel != null) {
        client.removeChannel(_assignmentsChannel!);
      }

      dev.log(
          '📡 Subscribing to Supabase Realtime changes for Assignments Screen...',
          name: 'AssignmentsScreen');
      _assignmentsChannel = client
          .channel('public:assignments_screen_sync')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'Assignment',
            callback: (payload) {
              dev.log('🔥 Real-time assignment event payload: $payload',
                  name: 'AssignmentsScreen');
              if (mounted) {
                _loadAssignmentsData(showLoading: false);
              }
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'AssignmentSubmission',
            callback: (payload) {
              dev.log('🔥 Real-time submission event payload: $payload',
                  name: 'AssignmentsScreen');
              if (mounted) {
                _loadAssignmentsData(showLoading: false);
              }
            },
          );

      _assignmentsChannel!.subscribe((status, [error]) {
        dev.log('📡 Supabase Realtime Assignments channel status: $status',
            name: 'AssignmentsScreen');
        if (error != null) {
          dev.log('❌ Supabase Realtime Assignments subscription error: $error',
              name: 'AssignmentsScreen');
        }
      });
    } catch (e) {
      dev.log('⚠️ Error connecting Supabase Realtime Assignments channel: $e',
          name: 'AssignmentsScreen');
    }

    // Polling fallback every 2 seconds for robust real-time updates
    _assignmentsPollTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        _loadAssignmentsData(showLoading: false);
      }
    });
  }

  Future<void> _loadAssignmentsData({bool showLoading = true}) async {
    if (!mounted) return;
    if (showLoading) {
      setState(() {
        _isLoading = true;
      });
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail =
          prefs.getString('student_email') ?? prefs.getString('user_email');
      if (savedEmail != null) {
        _studentEmailStr = savedEmail;
      }

      // 1. Fetch student info
      final userRes = await Supabase.instance.client
          .from('User')
          .select()
          .eq('email', _studentEmailStr)
          .maybeSingle();

      if (userRes != null) {
        final userId = userRes['id'] as String;

        final studentRes = await Supabase.instance.client
            .from('Student')
            .select()
            .eq('userId', userId)
            .maybeSingle();

        if (studentRes != null) {
          _studentIdStr = studentRes['id'] as String;
          _classNameStr = studentRes['currentClassId'] as String? ?? '';
          _sectionStr = studentRes['sectionId'] as String? ?? '';
        }
      }

      // 2. Fetch assignments for this class & section
      final List<dynamic> assignmentsRes = _classNameStr.isNotEmpty
          ? await Supabase.instance.client
              .from('Assignment')
              .select()
              .eq('classId', _classNameStr)
          : [];

      final List<dynamic> filteredAssignments = assignmentsRes.where((a) {
        final aSecId = a['sectionId'];
        return aSecId == null || _sectionStr.isEmpty || aSecId == _sectionStr;
      }).toList();

      // 3. Fetch submissions by this student
      final List<dynamic> submissionsRes = _studentIdStr.isNotEmpty
          ? await Supabase.instance.client
              .from('AssignmentSubmission')
              .select()
              .eq('studentId', _studentIdStr)
          : [];

      // Map submissions by assignmentId
      final Map<String, Map<String, dynamic>> submissionsMap = {};
      for (var sub in submissionsRes) {
        final assId = (sub['assignmentId'] ?? sub['assignment_id']) as String;
        submissionsMap[assId] = Map<String, dynamic>.from(sub);
      }

      final List<Map<String, dynamic>> tempAssignments = [];

      for (var ass in filteredAssignments) {
        final assId = ass['id'] as String;
        final title = ass['title'] as String? ?? 'Untitled';
        final desc = ass['description'] as String? ?? '';
        final dueDateStr = (ass['dueDate'] ?? ass['due_date']) as String?;

        // Fetch subject name dynamically
        String subject = 'General';
        final subId = ass['subjectId'] as String?;
        if (subId != null && subId.isNotEmpty) {
          try {
            final subRes = await Supabase.instance.client
                .from('Subject')
                .select('name')
                .eq('id', subId)
                .maybeSingle();
            if (subRes != null) {
              subject = subRes['name'] as String? ?? 'General';
            }
          } catch (_) {}
        }

        DateTime? due;
        if (dueDateStr != null) {
          try {
            due = DateTime.parse(dueDateStr);
          } catch (_) {}
        }

        final isUrgent = due != null &&
            due.year == DateTime.now().year &&
            due.month == DateTime.now().month &&
            due.day == DateTime.now().day;

        final bool isSubmitted = submissionsMap.containsKey(assId);
        final sub = submissionsMap[assId];

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final bool isOverdue = !isSubmitted &&
            due != null &&
            DateTime(due.year, due.month, due.day).isBefore(today);

        String formattedDue = 'No due date';
        if (due != null) {
          formattedDue = intl.DateFormat('MMM d, yyyy').format(due);
        }

        String? formattedSub;
        if (sub != null) {
          final subAtStr =
              (sub['submittedAt'] ?? sub['submitted_at']) as String?;
          if (subAtStr != null) {
            try {
              final subAt = DateTime.parse(subAtStr);
              formattedSub = intl.DateFormat('MMM d, yyyy').format(subAt);
            } catch (_) {}
          }
        }

        tempAssignments.add({
          'id': assId,
          'title': title,
          'subject': subject,
          'description': desc,
          'due': formattedDue,
          'urgent': isUrgent,
          'isOverdue': isOverdue,
          'isSubmitted': isSubmitted,
          'submittedAt': formattedSub ?? 'Recently',
          'grade': sub?['grade'] as String? ?? 'Pending',
          'score':
              (sub?['feedback'] ?? sub?['score'])?.toString() ?? 'Not Graded',
          'fileName': (sub?['filePath'] ??
              sub?['fileName'] ??
              sub?['file_name']) as String?,
        });
      }

      // Mock assignment removed to match real-time empty state matching target design.
      if (mounted) {
        setState(() {
          _assignments.clear();
          _assignments.addAll(tempAssignments);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _getFilteredAssignments() {
    return _assignments.where((a) {
      if (_selectedSubject == 'All') return true;
      final String sub = (a['subject'] as String).toLowerCase();
      final String sel = _selectedSubject.toLowerCase();
      if (sel == 'math') {
        return sub.contains('math');
      }
      return sub.contains(sel);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredAssignments();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F8FC),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Page Title Row with Filter Icon
                // Page Title
                Padding(
                  padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 16.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Assignments',
                        style: AppTypography.h4
                            .copyWith(color: const Color(0xFF0066CC)),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'View and submit your classwork',
                        style: AppTypography.caption
                            .copyWith(color: const Color(0xFF6B7A90)),
                      ),
                    ],
                  ),
                ),

                // Main Content Card
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 24.h),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(20.r),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                            color: const Color(0xFFE2EAF4), width: 1.5.w),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.01),
                            blurRadius: 10.r,
                            offset: Offset(0, 4.h),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Academic Assignments',
                            style: AppTypography.small
                                .copyWith(color: const Color(0xFF0F2547)),
                          ),
                          SizedBox(height: 3.h),
                          Text(
                            'Click on an assignment to submit your work or view grades.',
                            style: AppTypography.caption.copyWith(
                                color: const Color(0xFF6B7A90), height: 1.3),
                          ),
                          SizedBox(height: 24.h),
                          Expanded(
                            child: _isLoading
                                ? const Center(
                                    child: CircularProgressIndicator(
                                        color: Color(0xFF2E7DF7)))
                                : RefreshIndicator(
                                    onRefresh: () =>
                                        _loadAssignmentsData(showLoading: true),
                                    color: const Color(0xFF2E7DF7),
                                    child: filtered.isEmpty
                                        ? _buildEmptyState()
                                        : ListView.builder(
                                            physics:
                                                const AlwaysScrollableScrollPhysics(),
                                            itemCount: filtered.length,
                                            itemBuilder: (context, index) {
                                              return _buildAssignmentCard(
                                                  filtered[index]);
                                            },
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
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentCard(Map<String, dynamic> a) {
    final bool isSubmitted = a['isSubmitted'] as bool;
    final bool isOverdue = a['isOverdue'] as bool? ?? false;
    final bool isUrgent = a['urgent'] as bool;
    final String subject = a['subject'] as String? ?? 'General';
    final String grade = a['grade'] as String? ?? 'Pending';

    return Container(
      margin: EdgeInsets.only(bottom: 16.h, left: 24.w, right: 24.w),
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFE9F0F8), width: 1.5.w),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE2EAF4).withValues(alpha: 0.3),
            blurRadius: 16.r,
            offset: Offset(0, 6.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tags Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Subject Capsule Tag - Outline
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF), // soft blue background
                  borderRadius: BorderRadius.circular(20.r), // capsule
                  border:
                      Border.all(color: const Color(0xFFBFDBFE), width: 1.w),
                ),
                child: Text(
                  subject.toUpperCase(),
                  style: AppTypography.caption.copyWith(
                      color: const Color(0xFF2563EB), letterSpacing: 0.5),
                ),
              ),

              // Submission Status Capsule Tag
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: isSubmitted
                      ? const Color(0xFFD1FAE5) // Soft green for submitted
                      : (isOverdue
                          ? const Color(0xFFFEE2E2) // Soft red for overdue
                          : (isUrgent
                              ? const Color(0xFFFEF3C7)
                              : const Color(0xFFF1F5F9))), // Soft yellow/grey
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  isSubmitted
                      ? "Submitted"
                      : (isOverdue
                          ? "Overdue"
                          : (isUrgent ? "Due Today" : "Pending")),
                  style: AppTypography.caption.copyWith(
                      color: isSubmitted
                          ? const Color(0xFF059669) // Green text
                          : (isOverdue
                              ? const Color(0xFFEF4444) // Red text
                              : (isUrgent
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFF475569)))),
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),

          // Assignment Title
          Text(
            a['title'] as String,
            style: AppTypography.small.copyWith(color: const Color(0xFF0F172A)),
          ),
          SizedBox(height: 4.h),

          // Assignment Description
          Text(
            a['description'] as String,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption
                .copyWith(color: const Color(0xFF475569), height: 1.3),
          ),

          Divider(color: const Color(0xFFE2EAF4), height: 24.h, thickness: 1.h),

          // Meta Info Row
          Row(
            children: [
              Icon(Icons.calendar_today_outlined,
                  size: 14.sp, color: const Color(0xFF64748B)),
              SizedBox(width: 6.w),
              Text(
                'Due: ${a['due']}',
                style: AppTypography.caption
                    .copyWith(color: const Color(0xFF64748B)),
              ),
              const Spacer(),
              Icon(Icons.person_outline_rounded,
                  size: 16.sp, color: const Color(0xFF94A3B8)),
            ],
          ),
          SizedBox(height: 18.h),

          // Bottom Action/Status Bar
          if (isSubmitted) ...[
            if (grade == 'Pending')
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.access_time_rounded,
                        color: const Color(0xFF2563EB), size: 16.sp),
                    SizedBox(width: 8.w),
                    Text(
                      'Awaiting Grade',
                      style: AppTypography.caption
                          .copyWith(color: const Color(0xFF2563EB)),
                    ),
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: const Color(0xFF10B981), size: 16.sp),
                    SizedBox(width: 8.w),
                    Text(
                      'Graded: $grade (${a['score']})',
                      style: AppTypography.caption
                          .copyWith(color: const Color(0xFF10B981)),
                    ),
                  ],
                ),
              )
          ] else
            GestureDetector(
              onTap: () => _showAssignmentDetails(a),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                decoration: BoxDecoration(
                  color: isOverdue
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF2E7DF7),
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(
                      color: (isOverdue
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF2E7DF7))
                          .withValues(alpha: 0.15),
                      blurRadius: 10.r,
                      offset: Offset(0, 3.h),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isOverdue
                          ? Icons.upload_rounded
                          : Icons.cloud_upload_outlined,
                      color: Colors.white,
                      size: 16.sp,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      isOverdue ? 'Submit Late' : 'Submit Assignment',
                      style:
                          AppTypography.caption.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: CustomPaint(
        painter: _DashedBorderPainter(),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 80.h, horizontal: 24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.description_outlined,
                color: const Color(0xFFCBD5E1),
                size: 48.sp,
              ),
              SizedBox(height: 16.h),
              Text(
                'No assignments found for your class.',
                style: AppTypography.caption
                    .copyWith(color: const Color(0xFF475569)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAssignmentDetails(Map<String, dynamic> a) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AdvancedAssignmentModal(
        assignment: a,
        studentIdStr: _studentIdStr,
        onSubmitted: () => _loadAssignmentsData(showLoading: true),
      ),
    );
  }
}

class AdvancedAssignmentModal extends StatefulWidget {
  final Map<String, dynamic> assignment;
  final String studentIdStr;
  final VoidCallback onSubmitted;

  const AdvancedAssignmentModal({
    super.key,
    required this.assignment,
    required this.studentIdStr,
    required this.onSubmitted,
  });

  @override
  State<AdvancedAssignmentModal> createState() =>
      _AdvancedAssignmentModalState();
}

class _AdvancedAssignmentModalState extends State<AdvancedAssignmentModal>
    with SingleTickerProviderStateMixin {
  PlatformFile? selectedFile;
  bool isSubmitting = false;
  double uploadProgress = 0.0;
  bool isSuccess = false;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleUpload() async {
    if (selectedFile == null || isSubmitting) return;

    setState(() {
      isSubmitting = true;
      uploadProgress = 0.0;
    });

    // Simulate real-time progress for UX
    for (int i = 1; i <= 100; i += 2) {
      await Future.delayed(const Duration(milliseconds: 20));
      if (mounted) {
        setState(() {
          uploadProgress = i / 100.0;
        });
      }
    }

    try {
      if (widget.assignment['id'] == 'mock-chapter-1-assignment-id') {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('mock_sub_chapter_1', true);
        await prefs.setString('mock_file_chapter_1', selectedFile!.name);
        await prefs.setString('mock_date_chapter_1',
            intl.DateFormat('MMM d, yyyy').format(DateTime.now()));
      } else {
        await Supabase.instance.client.from('AssignmentSubmission').upsert({
          'assignmentId': widget.assignment['id'],
          'studentId': widget.studentIdStr,
          'filePath': selectedFile!.name,
          'status': 'SUBMITTED',
          'grade': 'Pending',
          'feedback': null,
          'submittedAt': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'assignmentId,studentId');
      }

      if (mounted) {
        setState(() {
          uploadProgress = 1.0;
          isSuccess = true;
        });
      }

      await Future.delayed(const Duration(seconds: 1)); // Show success state

      if (mounted) {
        showToast(
            context, 'Successfully submitted ${widget.assignment['title']}!');
        Navigator.pop(context);
        widget.onSubmitted();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isSubmitting = false;
          uploadProgress = 0.0;
        });
        showToast(context, 'Error submitting: $e');
      }
    }
  }

  IconData _getFileIcon(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'zip':
      case 'rar':
        return Icons.folder_zip_rounded;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _getFileColor(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return const Color(0xFFE11D48);
      case 'doc':
      case 'docx':
        return const Color(0xFF2563EB);
      case 'zip':
      case 'rar':
        return const Color(0xFFD97706);
      case 'jpg':
      case 'jpeg':
      case 'png':
        return const Color(0xFF059669);
      default:
        return const Color(0xFF2E7DF7);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isSubmitted = widget.assignment['isSubmitted'] as bool;
    final bool isUrgent = widget.assignment['urgent'] as bool;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        padding: EdgeInsets.fromLTRB(
            24.r, 16.r, 24.r, 24.r + MediaQuery.of(context).viewInsets.bottom),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20.r,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
            ),
            SizedBox(height: 20.h),

            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(10.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(Icons.assignment_rounded,
                      color: const Color(0xFF4F46E5), size: 24.sp),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.assignment['title'] as String,
                        style: GoogleFonts.outfit(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Text(
                              widget.assignment['subject'] as String,
                              style: AppTypography.caption
                                  .copyWith(color: const Color(0xFF2563EB)),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Icon(Icons.access_time_rounded,
                              size: 12.sp,
                              color: isUrgent
                                  ? const Color(0xFFE11D48)
                                  : const Color(0xFF64748B)),
                          SizedBox(width: 4.w),
                          Text(
                            'Due ${widget.assignment['due']}',
                            style: AppTypography.caption.copyWith(
                                color: isUrgent
                                    ? const Color(0xFFE11D48)
                                    : const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon:
                      const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            SizedBox(height: 24.h),

            // Instructions
            Text(
              'Instructions',
              style: GoogleFonts.outfit(
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
            SizedBox(height: 8.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.r),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                (widget.assignment['description'] as String).isNotEmpty
                    ? widget.assignment['description'] as String
                    : 'No specific instructions provided.',
                style: AppTypography.caption
                    .copyWith(color: const Color(0xFF334155), height: 1.5),
              ),
            ),
            SizedBox(height: 24.h),

            // Upload Section
            if (isSubmitted) ...[
              Text(
                'Your Submission',
                style: GoogleFonts.outfit(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
              SizedBox(height: 8.h),
              Container(
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8.r),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_circle_rounded,
                              color: Color(0xFF16A34A), size: 24),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.assignment['fileName'] as String? ??
                                    'submission_file.pdf',
                                style: AppTypography.small
                                    .copyWith(color: const Color(0xFF14532D)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                'Submitted on ${widget.assignment['submittedAt']}',
                                style: AppTypography.caption
                                    .copyWith(color: const Color(0xFF166534)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (widget.assignment['grade'] != 'Pending') ...[
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        child: Divider(
                            color:
                                const Color(0xFF86EFAC).withValues(alpha: 0.5),
                            height: 1),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Grade & Score:',
                            style: AppTypography.caption
                                .copyWith(color: const Color(0xFF14532D)),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 10.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            child: Text(
                              '${widget.assignment['score']} (${widget.assignment['grade']})',
                              style: GoogleFonts.outfit(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF16A34A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ] else ...[
              Text(
                'Upload Work',
                style: GoogleFonts.outfit(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
              SizedBox(height: 8.h),
              if (selectedFile == null)
                GestureDetector(
                  onTap: () async {
                    try {
                      final result = await FilePicker.platform.pickFiles();
                      if (result != null && result.files.isNotEmpty) {
                        setState(() {
                          selectedFile = result.files.first;
                        });
                      }
                    } catch (e) {
                      if (!context.mounted) return;
                      showToast(context, 'Error picking file');
                    }
                  },
                  child: CustomPaint(
                    painter: DashedRectPainter(
                      color: const Color(0xFF94A3B8),
                      radius: 16.r,
                      strokeWidth: 1.5,
                      dashLength: 8,
                      gap: 6,
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 32.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC).withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: EdgeInsets.all(12.r),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF2E7DF7)
                                      .withValues(alpha: 0.1),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(Icons.cloud_upload_rounded,
                                color: const Color(0xFF2E7DF7), size: 28.sp),
                          ),
                          SizedBox(height: 12.h),
                          Text(
                            'Tap to browse files',
                            style: AppTypography.small
                                .copyWith(color: const Color(0xFF1E293B)),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'PDF, DOCX, ZIP, PNG (Max 50MB)',
                            style: AppTypography.caption
                                .copyWith(color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                Container(
                  padding: EdgeInsets.all(16.r),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10.r),
                        decoration: BoxDecoration(
                          color: _getFileColor(selectedFile!.extension ?? '')
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Icon(
                          _getFileIcon(selectedFile!.extension ?? ''),
                          color: _getFileColor(selectedFile!.extension ?? ''),
                          size: 24.sp,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedFile!.name,
                              style: AppTypography.caption
                                  .copyWith(color: const Color(0xFF1E293B)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              '${(selectedFile!.size / 1024 / 1024).toStringAsFixed(2)} MB',
                              style: AppTypography.caption
                                  .copyWith(color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      if (!isSubmitting && !isSuccess)
                        IconButton(
                          onPressed: () {
                            setState(() {
                              selectedFile = null;
                            });
                          },
                          icon: Container(
                            padding: EdgeInsets.all(6.r),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFEF2F2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded,
                                color: Color(0xFFEF4444), size: 16),
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      if (isSuccess)
                        const Icon(Icons.check_circle_rounded,
                            color: Color(0xFF10B981), size: 24),
                    ],
                  ),
                ),

              SizedBox(height: 24.h),

              // Animated Submit Button
              GestureDetector(
                onTap: _handleUpload,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: double.infinity,
                  height: 54.h,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isSuccess
                          ? [const Color(0xFF10B981), const Color(0xFF059669)]
                          : (selectedFile == null || isSubmitting
                              ? [
                                  const Color(0xFF94A3B8),
                                  const Color(0xFF64748B)
                                ]
                              : [
                                  const Color(0xFF3B82F6),
                                  const Color(0xFF2563EB)
                                ]),
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16.r),
                    boxShadow: [
                      if (selectedFile != null && !isSubmitting && !isSuccess)
                        BoxShadow(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (isSubmitting) ...[
                        // Progress Background
                        Align(
                          alignment: Alignment.centerLeft,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 100),
                            width: MediaQuery.of(context).size.width *
                                uploadProgress,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                          ),
                        ),
                        Text(
                          'Uploading... ${(uploadProgress * 100).toInt()}%',
                          style: GoogleFonts.outfit(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ] else if (isSuccess) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_outline_rounded,
                                color: Colors.white),
                            SizedBox(width: 8.w),
                            Text(
                              'Submitted Successfully',
                              style: GoogleFonts.outfit(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Text(
                          'Submit Assignment',
                          style: GoogleFonts.outfit(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double dashLength;
  final double radius;

  DashedRectPainter({
    this.color = const Color(0xFFCBD5E1),
    this.strokeWidth = 1.0,
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
        Radius.circular(radius),
      ));

    final dashPath = Path();
    double distance = 0.0;
    for (final pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        final len = dashLength;
        final nextDistance = distance + len;
        final isLast = nextDistance >= pathMetric.length;

        dashPath.addPath(
          pathMetric.extractPath(
              distance, isLast ? pathMetric.length : nextDistance),
          Offset.zero,
        );

        distance = nextDistance + gap;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(DashedRectPainter oldDelegate) => false;
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE2EAF4)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          const Radius.circular(12)));

    final dashPath = Path();
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        dashPath.addPath(
            metric.extractPath(distance, distance + 6), Offset.zero);
        distance += 12;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
