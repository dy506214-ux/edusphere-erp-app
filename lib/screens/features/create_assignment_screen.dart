import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/common_widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart' as intl;
import '../../services/api_service.dart';
import '../main_screen.dart';


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
  // Loading states
  bool _isLoadingAssignments = true;
  bool _isLoadingSubmissions = true;
  bool _isSubmitting = false;

  // Local state data
  String _teacherName = 'Teacher';
  final List<Map<String, dynamic>> _assignments = [];
  final List<Map<String, dynamic>> _submissionsList = [];
  Map<String, dynamic>? _selectedAssignment;

  // Academic data (fetched from backend for create form)
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _sections = [];
  List<Map<String, dynamic>> _subjects = [];

  // Polling timer
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadTeacherName();
    _loadAllData();
    _loadAcademicData();
    // Poll every 30 seconds for new submissions
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadAllData(showLoading: false);
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTeacherName() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('teacher_name') ?? prefs.getString('user_name');
    if (savedName != null && savedName.isNotEmpty) {
      setState(() {
        _teacherName = savedName;
      });
    }
  }

  String _getInitials(String name) {
    try {
      final parts = name.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
        return parts[0][0].toUpperCase();
      }
    } catch (_) {}
    return 'T';
  }

  /// Fetch classes, sections, subjects from backend for the create form
  Future<void> _loadAcademicData() async {
    try {
      final results = await Future.wait([
        ApiService.instance.get('academic/classes'),
        ApiService.instance.get('academic/sections'),
        ApiService.instance.get('academic/subjects'),
      ]);

      final classesData = results[0];
      final sectionsData = results[1];
      final subjectsData = results[2];

      if (mounted) {
        setState(() {
          _classes = List<Map<String, dynamic>>.from(
            (classesData['classes'] ?? classesData['data'] ?? []) as List,
          );
          _sections = List<Map<String, dynamic>>.from(
            (sectionsData['sections'] ?? sectionsData['data'] ?? []) as List,
          );
          _subjects = List<Map<String, dynamic>>.from(
            (subjectsData['subjects'] ?? subjectsData['data'] ?? []) as List,
          );
        });
      }
    } catch (e) {
      dev.log('⚠️ Error loading academic data: $e', name: 'CreateAssignmentScreen');
    }
  }

  Future<void> _loadAllData({bool showLoading = true}) async {
    if (!mounted) return;
    if (showLoading) {
      setState(() {
        _isLoadingAssignments = true;
        _isLoadingSubmissions = true;
      });
    }

    try {
      // 1. Fetch all assignments created by teacher
      final assignmentsRes = await ApiService.instance.get('assignments/teacher');
      final List<dynamic> rawAssignments = assignmentsRes['assignments'] ?? [];

      final List<Map<String, dynamic>> tempAssignments = rawAssignments.map((row) {
        final subject = row['subject'] as Map<String, dynamic>?;
        final cls = row['class'] as Map<String, dynamic>?;
        final section = row['section'] as Map<String, dynamic>?;
        final submissionsCount = row['_count']?['submissions'] ?? 0;

        return {
          'id': row['id'],
          'title': row['title'] ?? 'Untitled Assignment',
          'subject': subject?['name'] ?? 'General',
          'class_name': cls?['name'] ?? 'N/A',
          'section': section?['name'] ?? 'All',
          'due_date': row['dueDate'] != null
              ? _formatDueDate(row['dueDate'] as String)
              : 'No Due Date',
          'submissions_count': submissionsCount,
          'description': row['description'],
        };
      }).toList();

      // 2. Fetch submissions for currently selected assignment (or first one)
      List<Map<String, dynamic>> tempSubmissions = [];
      final String? targetId = _selectedAssignment?['id'] as String? ??
          (tempAssignments.isNotEmpty ? tempAssignments.first['id'] as String? : null);

      if (targetId != null) {
        tempSubmissions = await _fetchSubmissionsForAssignment(targetId);
      }

      if (mounted) {
        setState(() {
          _assignments.clear();
          _assignments.addAll(tempAssignments);
          _isLoadingAssignments = false;

          _submissionsList.clear();
          _submissionsList.addAll(tempSubmissions);
          _isLoadingSubmissions = false;

          // Maintain selected assignment reference
          if (_selectedAssignment != null) {
            final exists = _assignments.any((a) => a['id'] == _selectedAssignment!['id']);
            if (exists) {
              _selectedAssignment = _assignments.firstWhere((a) => a['id'] == _selectedAssignment!['id']);
            } else {
              _selectedAssignment = null;
            }
          }
          if (_selectedAssignment == null && _assignments.isNotEmpty) {
            _selectedAssignment = _assignments.first;
          }
        });
      }
    } catch (e) {
      dev.log('⚠️ Error loading assignment data: $e', name: 'CreateAssignmentScreen');
      if (mounted) {
        setState(() {
          _isLoadingAssignments = false;
          _isLoadingSubmissions = false;
        });
      }
    }
  }

  /// Fetch submissions for a specific assignment via GET /assignments/:id
  Future<List<Map<String, dynamic>>> _fetchSubmissionsForAssignment(String assignmentId) async {
    try {
      final res = await ApiService.instance.get('assignments/$assignmentId');
      final assignment = res['assignment'] as Map<String, dynamic>?;
      final rawSubs = assignment?['submissions'] as List<dynamic>? ?? [];

      return rawSubs.map((sub) {
        final student = sub['student'] as Map<String, dynamic>?;
        final userInfo = student?['user'] as Map<String, dynamic>?;
        final firstName = userInfo?['firstName'] as String? ?? '';
        final lastName = userInfo?['lastName'] as String? ?? '';
        final studentName = '${firstName} ${lastName}'.trim().isEmpty
            ? 'Unknown Student'
            : '${firstName} ${lastName}'.trim();

        return {
          'id': sub['id'],
          'assignment_id': assignmentId,
          'student_id': sub['studentId'],
          'student_name': studentName,
          'submitted_at': sub['submittedAt'],
          'grade': sub['grade'] ?? 'Pending',
          'score': sub['feedback'] ?? 'Not Graded',
          'file_name': sub['filePath'] != null
              ? (sub['filePath'] as String).split('/').last
              : null,
          'status': sub['status'] ?? 'PENDING',
          'assignment_title': assignment?['title'] ?? 'Untitled',
          'assignment_subject': (assignment?['subject'] as Map?)?.values.first ?? 'General',
        };
      }).toList();
    } catch (e) {
      dev.log('⚠️ Error fetching submissions for $assignmentId: $e', name: 'CreateAssignmentScreen');
      return [];
    }
  }

  String _formatDueDate(String rawDate) {
    try {
      final dt = DateTime.parse(rawDate).toLocal();
      return intl.DateFormat('MMM d, yyyy').format(dt);
    } catch (_) {
      return rawDate;
    }
  }

  /// When user selects an assignment, load its submissions
  Future<void> _selectAssignment(Map<String, dynamic> assignment) async {
    setState(() {
      _selectedAssignment = assignment;
      _isLoadingSubmissions = true;
    });
    final subs = await _fetchSubmissionsForAssignment(assignment['id'] as String);
    if (mounted) {
      setState(() {
        _submissionsList.clear();
        _submissionsList.addAll(subs);
        _isLoadingSubmissions = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(_teacherName);

    return Scaffold(
      key: _scaffoldKey,
      drawer: widget.showAppBar ? const EduSphereDrawer(role: 'teacher', activeLabel: 'Assignments') : null,
      bottomNavigationBar: widget.showAppBar ? const TeacherBottomNavBar(activeIndex: 6) : null,
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
              leading: IconButton(
                icon: Icon(Icons.menu, size: 28.sp),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              title: Text(
                'EduSphere',
                style: GoogleFonts.outfit(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.notifications_none_rounded, size: 28.sp),
                  onPressed: () {},
                ),
                Padding(
                  padding: EdgeInsets.only(right: 16.w, left: 4.w),
                  child: Center(
                    child: CircleAvatar(
                      radius: 16.r,
                      backgroundColor: const Color(0xFFE0F2FE),
                      child: Text(
                        initials,
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0284C7),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : null,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => _loadAllData(showLoading: true),
            color: const Color(0xFF0284C7),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20.r, 20.r, 20.r, 120.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Page Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Assignment Management',
                              style: GoogleFonts.inter(
                                fontSize: 24.sp,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              'Create and grade student assignments',
                              style: GoogleFonts.inter(
                                fontSize: 13.sp,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8.w),
                      ElevatedButton.icon(
                        onPressed: () => _showCreateAssignmentSheet(context),
                        icon: Icon(Icons.add, color: Colors.white, size: 16.sp),
                        label: Text(
                          'New Assignment',
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),

                  // Card 1: My Assignments
                  _buildMyAssignmentsCard(),
                  SizedBox(height: 20.h),

                  // Card 2: Submission Tracker
                  _buildSubmissionTrackerCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyAssignmentsCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.r),
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
          Text(
            'My Assignments',
            style: GoogleFonts.inter(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            'All assignments created by you',
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              color: const Color(0xFF64748B),
            ),
          ),
          SizedBox(height: 20.h),
          if (_isLoadingAssignments)
            const Center(child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(color: Color(0xFF0284C7)),
            ))
          else if (_assignments.isEmpty)
            CustomPaint(
              painter: DashedRectPainter(
                color: const Color(0xFFCBD5E1),
                radius: 12.r,
              ),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 40.h),
                child: Column(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      color: const Color(0xFFCBD5E1),
                      size: 44.r,
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      'No assignments created yet.',
                      style: GoogleFonts.inter(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _assignments.length,
              separatorBuilder: (_, __) => SizedBox(height: 12.h),
              itemBuilder: (context, index) {
                final a = _assignments[index];
                final isSelected = _selectedAssignment != null && _selectedAssignment!['id'] == a['id'];

                return InkWell(
                  onTap: () => _selectAssignment(a),
                  borderRadius: BorderRadius.circular(12.r),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.all(14.r),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFF0F9FF) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36.r,
                          height: 36.r,
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFBAE6FD) : const Color(0xFFE2E8F0),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              (a['subject'] as String? ?? 'G').substring(0, 1).toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? const Color(0xFF0369A1) : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 14.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a['title'] as String? ?? 'Untitled Assignment',
                                style: GoogleFonts.inter(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                '${a['subject']} • Class ${a['class_name']} (${a['section']})',
                                style: GoogleFonts.inter(
                                  fontSize: 11.sp,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Due Date',
                              style: GoogleFonts.inter(
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF94A3B8),
                                letterSpacing: 0.3,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              a['due_date'] as String? ?? 'No Due Date',
                              style: GoogleFonts.inter(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSubmissionTrackerCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.r),
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
          Text(
            'Submission Tracker',
            style: GoogleFonts.inter(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            _selectedAssignment != null
                ? 'Submissions for: ${_selectedAssignment!['title']}'
                : 'Select an assignment to view and grade student work',
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              color: const Color(0xFF64748B),
            ),
          ),
          SizedBox(height: 20.h),
          if (_isLoadingSubmissions)
            const Center(child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(color: Color(0xFF0284C7)),
            ))
          else if (_selectedAssignment == null)
            CustomPaint(
              painter: DashedRectPainter(
                color: const Color(0xFFCBD5E1),
                radius: 12.r,
              ),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 40.h),
                child: Column(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      color: const Color(0xFFCBD5E1),
                      size: 44.r,
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      'Submission Tracker',
                      style: GoogleFonts.inter(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Select an assignment to view and grade student work.',
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        color: const Color(0xFF94A3B8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            _buildSubmissionsList(),
        ],
      ),
    );
  }

  Widget _buildSubmissionsList() {
    if (_submissionsList.isEmpty) {
      return CustomPaint(
        painter: DashedRectPainter(
          color: const Color(0xFFCBD5E1),
          radius: 12.r,
        ),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 40.h),
          child: Column(
            children: [
              Icon(
                Icons.folder_open_outlined,
                color: const Color(0xFFCBD5E1),
                size: 44.r,
              ),
              SizedBox(height: 12.h),
              Text(
                'No submissions received yet.',
                style: GoogleFonts.inter(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _submissionsList.length,
      separatorBuilder: (_, __) => const Divider(height: 20, color: Color(0xFFF1F5F9)),
      itemBuilder: (context, index) {
        final sub = _submissionsList[index];
        final hasGrade = sub['grade'] != null && sub['grade'] != 'Pending';
        final status = sub['status'] as String? ?? 'PENDING';

        DateTime? subDate;
        if (sub['submitted_at'] != null) {
          try {
            subDate = DateTime.parse(sub['submitted_at']).toLocal();
          } catch (_) {}
        }
        final formattedDate = subDate != null
            ? intl.DateFormat('MMM d, yyyy • h:mm a').format(subDate)
            : 'Recent';

        return Row(
          children: [
            CircleAvatar(
              radius: 20.r,
              backgroundColor: const Color(0xFFF1F5F9),
              child: Text(
                _getInitials(sub['student_name'] as String? ?? 'Student'),
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF475569),
                ),
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sub['student_name'] as String? ?? 'Unknown Student',
                    style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'File: ${sub['file_name'] ?? 'submission'} • $formattedDate',
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      color: const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Icon(
                        hasGrade ? Icons.check_circle_rounded : Icons.pending_rounded,
                        color: hasGrade ? const Color(0xFF10B981) : Colors.orange,
                        size: 14.sp,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        hasGrade
                            ? 'Grade: ${sub['grade']} (${status})'
                            : 'Evaluation Pending',
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w800,
                          color: hasGrade ? const Color(0xFF10B981) : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: 12.w),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: hasGrade ? const Color(0xFFF1F5F9) : const Color(0xFFE0F2FE),
                foregroundColor: hasGrade ? const Color(0xFF475569) : const Color(0xFF0369A1),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              ),
              onPressed: () => _showEvaluationDialog(context, sub),
              child: Text(
                hasGrade ? 'Re-evaluate' : 'Grade & Approve',
                style: GoogleFonts.inter(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showCreateAssignmentSheet(BuildContext context) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    DateTime? tempDueDate;
    Map<String, dynamic>? chosenClass;
    Map<String, dynamic>? chosenSection;
    Map<String, dynamic>? chosenSubject;

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
          padding: EdgeInsets.fromLTRB(20.r, 20.r, 20.r, MediaQuery.of(context).viewInsets.bottom + 20.r),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.80),
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
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    'Create Assignment',
                    style: GoogleFonts.inter(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 20.h),

                  // Title
                  _buildSheetLabel('Title'),
                  SizedBox(height: 6.h),
                  TextFormField(
                    controller: titleCtrl,
                    decoration: _buildInputDecoration('e.g. Quantum Physics Lab Report'),
                  ),
                  SizedBox(height: 16.h),

                  // Subject selection (from backend)
                  _buildSheetLabel('Subject'),
                  SizedBox(height: 8.h),
                  _subjects.isEmpty
                      ? Text('Loading subjects...', style: GoogleFonts.inter(fontSize: 12.sp, color: const Color(0xFF94A3B8)))
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _subjects.map((s) => GestureDetector(
                            onTap: () => setSheetState(() => chosenSubject = s),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                              decoration: BoxDecoration(
                                color: chosenSubject?['id'] == s['id'] ? const Color(0xFF0284C7) : Colors.white,
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(
                                  color: chosenSubject?['id'] == s['id'] ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Text(
                                s['name'] as String? ?? '',
                                style: GoogleFonts.inter(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.bold,
                                  color: chosenSubject?['id'] == s['id'] ? Colors.white : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          )).toList(),
                        ),
                  SizedBox(height: 16.h),

                  // Instructions
                  _buildSheetLabel('Instructions'),
                  SizedBox(height: 6.h),
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: _buildInputDecoration('Describe the assignment requirements...'),
                  ),
                  SizedBox(height: 16.h),

                  // Due Date
                  _buildSheetLabel('Due Date'),
                  SizedBox(height: 6.h),
                  GestureDetector(
                    onTap: () async {
                      final selected = await showDatePicker(
                        context: context,
                        initialDate: tempDueDate ?? DateTime.now().add(const Duration(days: 1)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(DateTime.now().year + 5),
                      );
                      if (selected != null) {
                        setSheetState(() => tempDueDate = selected);
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.all(14.r),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, color: Color(0xFF64748B), size: 18),
                          SizedBox(width: 12.w),
                          Text(
                            tempDueDate == null
                                ? 'Select due date'
                                : intl.DateFormat('MMM d, yyyy').format(tempDueDate!),
                            style: GoogleFonts.inter(
                              color: tempDueDate == null ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                              fontWeight: tempDueDate == null ? FontWeight.normal : FontWeight.bold,
                              fontSize: 13.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Assign To — Class
                  _buildSheetLabel('Assign To — Class'),
                  SizedBox(height: 8.h),
                  _classes.isEmpty
                      ? Text('Loading classes...', style: GoogleFonts.inter(fontSize: 12.sp, color: const Color(0xFF94A3B8)))
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _classes.map((cls) {
                            final isSelected = chosenClass?['id'] == cls['id'];
                            return GestureDetector(
                              onTap: () => setSheetState(() {
                                chosenClass = cls;
                                chosenSection = null; // reset section when class changes
                              }),
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8.r),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Text(
                                  cls['name'] as String? ?? '',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : const Color(0xFF475569),
                                    fontSize: 12.sp,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                  SizedBox(height: 16.h),

                  // Section selection
                  _buildSheetLabel('Section'),
                  SizedBox(height: 8.h),
                  _sections.isEmpty
                      ? Text('Loading sections...', style: GoogleFonts.inter(fontSize: 12.sp, color: const Color(0xFF94A3B8)))
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _sections.map((sec) {
                            final isSelected = chosenSection?['id'] == sec['id'];
                            return GestureDetector(
                              onTap: () => setSheetState(() => chosenSection = sec),
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8.r),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Text(
                                  sec['name'] as String? ?? '',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : const Color(0xFF475569),
                                    fontSize: 12.sp,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                  SizedBox(height: 24.h),

                  // Submit button
                  LoadingButton(
                    label: _isSubmitting ? 'Publishing...' : 'Publish Assignment',
                    color: const Color(0xFF0284C7),
                    onPressed: () async {
                      if (_isSubmitting) return;
                      if (titleCtrl.text.trim().isEmpty) {
                        showToast(context, 'Please enter a title', isError: true);
                        return;
                      }
                      if (chosenSubject == null) {
                        showToast(context, 'Please select a subject', isError: true);
                        return;
                      }
                      if (chosenClass == null) {
                        showToast(context, 'Please select a class', isError: true);
                        return;
                      }

                      setSheetState(() => _isSubmitting = true);
                      setState(() => _isSubmitting = true);

                      try {
                        final formattedDue = intl.DateFormat("yyyy-MM-dd'T'HH:mm:ss.mmm'Z'").format(
                          (tempDueDate ?? DateTime.now().add(const Duration(days: 1))).toUtc(),
                        );

                        final result = await ApiService.instance.post('assignments', body: {
                          'title': titleCtrl.text.trim(),
                          'description': descCtrl.text.trim(),
                          'dueDate': formattedDue,
                          'subjectId': chosenSubject!['id'],
                          'classId': chosenClass!['id'],
                          if (chosenSection != null) 'sectionId': chosenSection!['id'],
                        });

                        if (context.mounted) {
                          if (result['assignment'] != null || result['message'] != null) {
                            showToast(context, 'Assignment published successfully!');
                            Navigator.pop(context);
                            _loadAllData(showLoading: true);
                          } else {
                            final errMsg = result['message'] ?? result['error'] ?? 'Failed to publish';
                            showToast(context, errMsg, isError: true);
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          showToast(context, 'Error publishing: $e', isError: true);
                        }
                      } finally {
                        setSheetState(() => _isSubmitting = false);
                        if (mounted) {
                          setState(() => _isSubmitting = false);
                        }
                      }
                    },
                  ),
                  SizedBox(height: 12.h),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEvaluationDialog(BuildContext context, Map<String, dynamic> sub) {
    String selectedGrade = sub['grade'] == 'Pending' || sub['grade'] == null ? 'A+' : sub['grade'];
    final feedbackCtrl = TextEditingController(text: sub['score'] == 'Not Graded' ? '' : sub['score']);
    final gradesList = ['A+', 'A', 'B+', 'B', 'C', 'D', 'F'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          title: Text(
            'Evaluate Submission',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
              fontSize: 16.sp,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Student: ${sub['student_name']}',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF475569),
                  fontSize: 13.sp,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'Assignment: ${sub['assignment_title']}',
                style: GoogleFonts.inter(
                  color: const Color(0xFF64748B),
                  fontSize: 12.sp,
                ),
              ),
              SizedBox(height: 16.h),
              _buildDialogLabel('SELECT GRADE'),
              SizedBox(height: 6.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedGrade,
                    isExpanded: true,
                    items: gradesList.map((g) => DropdownMenuItem(
                      value: g,
                      child: Text(
                        g,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    )).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedGrade = val;
                        });
                      }
                    },
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              _buildDialogLabel('FEEDBACK / COMMENTS'),
              SizedBox(height: 6.h),
              TextField(
                controller: feedbackCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Optional feedback for the student...',
                  hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13.sp),
                  contentPadding: EdgeInsets.all(12.r),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide: const BorderSide(color: Color(0xFF0284C7)),
                  ),
                ),
              ),
            ],
          ),
          actionsPadding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 10.h),
                elevation: 0,
              ),
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
                  // PUT /assignments/submissions/:submissionId/grade
                  final result = await ApiService.instance.put(
                    'assignments/submissions/$submissionId/grade',
                    body: {
                      'grade': selectedGrade,
                      'feedback': feedback.isEmpty ? null : feedback,
                    },
                  );

                  if (context.mounted) {
                    if (result['success'] == true || result['submission'] != null) {
                      showToast(context, 'Submission evaluated successfully!');
                      // Refresh submissions for the selected assignment
                      if (_selectedAssignment != null) {
                        await _selectAssignment(_selectedAssignment!);
                      }
                    } else {
                      final errMsg = result['message'] ?? result['error'] ?? 'Failed to save grade';
                      showToast(context, errMsg, isError: true);
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    showToast(context, 'Error saving grade: $e', isError: true);
                  }
                }
              },
              child: Text(
                'Submit Grade',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 10.sp,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF64748B),
        letterSpacing: 0.5,
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13.sp),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: BorderSide.none,
      ),
      contentPadding: EdgeInsets.all(12.r),
    );
  }

  Widget _buildDialogLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 9.sp,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF64748B),
        letterSpacing: 0.5,
      ),
    );
  }
}

// ── CUSTOM DASHED RECTANGLE PAINTER ──
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
          pathMetric.extractPath(distance, isLast ? pathMetric.length : nextDistance),
          Offset.zero,
        );

        distance = nextDistance + gap;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant DashedRectPainter oldDelegate) => false;
}
