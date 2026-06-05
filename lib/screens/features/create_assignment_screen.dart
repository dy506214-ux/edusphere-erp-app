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
  // Loading states
  bool _isLoadingAssignments = true;
  bool _isLoadingSubmissions = true;
  bool _isSubmitting = false;

  // Local state data
  String _teacherName = 'Vikram Yadav';
  final List<Map<String, dynamic>> _assignments = [];
  final List<Map<String, dynamic>> _submissionsList = [];
  Map<String, dynamic>? _selectedAssignment;

  // Syncing
  RealtimeChannel? _realtimeChannel;
  Timer? _pollTimer;

  // Chatbot overlay
  final bool _showBotBubble = true;

  @override
  void initState() {
    super.initState();
    _loadTeacherName();
    _loadAllData();
    _connectRealTime();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    if (_realtimeChannel != null) {
      try {
        Supabase.instance.client.removeChannel(_realtimeChannel!);
      } catch (_) {}
    }
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
    return 'VY';
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
      final List<dynamic> assignmentsRes = await Supabase.instance.client
          .from('assignments')
          .select()
          .order('id', ascending: false);

      final List<Map<String, dynamic>> tempAssignments = [];
      for (var row in assignmentsRes) {
        tempAssignments.add(Map<String, dynamic>.from(row));
      }

      // 2. Fetch all submissions
      final List<dynamic> submissionsRes = await Supabase.instance.client
          .from('submissions')
          .select('*, assignments(title, subject)')
          .order('submitted_at', ascending: false);

      final List<Map<String, dynamic>> tempSubmissions = [];
      for (var row in submissionsRes) {
        final ass = row['assignments'] as Map<String, dynamic>?;
        final assTitle = ass?['title'] as String? ?? 'Untitled Assignment';
        final assSubject = ass?['subject'] as String? ?? 'General';

        tempSubmissions.add({
          'id': row['id'],
          'assignment_id': row['assignment_id'],
          'student_id': row['student_id'],
          'student_name': row['student_name'] ?? 'Unknown Student',
          'submitted_at': row['submitted_at'],
          'grade': row['grade'] ?? 'Pending',
          'score': row['score'] ?? 'Not Graded',
          'file_name': row['file_name'],
          'assignment_title': assTitle,
          'assignment_subject': assSubject,
        });
      }

      if (mounted) {
        setState(() {
          _assignments.clear();
          _assignments.addAll(tempAssignments);
          _isLoadingAssignments = false;

          _submissionsList.clear();
          _submissionsList.addAll(tempSubmissions);
          _isLoadingSubmissions = false;

          // Maintain selected assignment reference or select first one by default if none selected
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
      dev.log('⚠️ Error loading dashboard data: $e', name: 'CreateAssignmentScreen');
      if (mounted) {
        setState(() {
          _isLoadingAssignments = false;
          _isLoadingSubmissions = false;
        });
      }
    }
  }

  void _connectRealTime() {
    try {
      final client = Supabase.instance.client;

      if (_realtimeChannel != null) {
        client.removeChannel(_realtimeChannel!);
      }

      dev.log('📡 Subscribing to Supabase Realtime changes for Assignment Dashboard...', name: 'CreateAssignmentScreen');
      _realtimeChannel = client.channel('public:assignment_dashboard_sync')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'assignments',
            callback: (payload) {
              dev.log('🔥 Real-time assignments change payload: $payload', name: 'CreateAssignmentScreen');
              if (mounted) {
                _loadAllData(showLoading: false);
              }
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'submissions',
            callback: (payload) {
              dev.log('🔥 Real-time submissions change payload: $payload', name: 'CreateAssignmentScreen');
              if (mounted) {
                _loadAllData(showLoading: false);
              }
            },
          );

      _realtimeChannel!.subscribe((status, [error]) {
        dev.log('📡 Supabase Realtime status: $status', name: 'CreateAssignmentScreen');
        if (error != null) {
          dev.log('❌ Supabase Realtime subscription error: $error', name: 'CreateAssignmentScreen');
        }
      });
    } catch (e) {
      dev.log('⚠️ Error connecting Supabase Realtime channel: $e', name: 'CreateAssignmentScreen');
    }

    // Polling fallback every 2 seconds for robust UI updates
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        _loadAllData(showLoading: false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(_teacherName);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
              leading: Navigator.canPop(context)
                  ? const BackButton(color: Color(0xFF0F172A))
                  : IconButton(
                      icon: Icon(Icons.menu, size: 28.sp),
                      onPressed: widget.onOpenDrawer,
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
                // Styled profile avatar badge
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

          // Speech Bubble for bot greeting
          if (_showBotBubble)
            Positioned(
              bottom: 96.h,
              right: 24.w,
              child: _buildBotBubble(),
            ),

          // AI Helper chatbot floating action button
          Positioned(
            bottom: 84.h,
            right: 20.w,
            child: FloatingActionButton(
              heroTag: 'assignment_chatbot_fab',
              onPressed: _showChatbotDialog,
              backgroundColor: const Color(0xFF0284C7),
              child: const Icon(Icons.auto_awesome, color: Colors.white),
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
                  onTap: () {
                    setState(() {
                      _selectedAssignment = a;
                    });
                  },
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
                                '${a['subject']} • Target: Class ${a['class_name'] ?? 'N/A'} (${a['section'] ?? 'N/A'})',
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
            _buildFilteredSubmissionsList(),
        ],
      ),
    );
  }

  Widget _buildFilteredSubmissionsList() {
    final list = _submissionsList
        .where((s) => s['assignment_id']?.toString() == _selectedAssignment!['id']?.toString())
        .toList();

    if (list.isEmpty) {
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
      itemCount: list.length,
      separatorBuilder: (_, __) => const Divider(height: 20, color: Color(0xFFF1F5F9)),
      itemBuilder: (context, index) {
        final sub = list[index];
        final hasGrade = sub['grade'] != 'Pending';

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
                    'File: ${sub['file_name'] ?? 'submission.pdf'} • $formattedDate',
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
                            ? 'Score: ${sub['score']} (${sub['grade']})'
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
    String selectedSubject = 'Physics';
    DateTime? tempDueDate;
    PlatformFile? attachedFile;
    String? chosenClass;
    final List<String> chosenSections = [];

    final subjects = ['Physics', 'Maths', 'Chemistry', 'English', 'CS'];

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
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
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

                  // Subject selection
                  _buildSheetLabel('Subject'),
                  SizedBox(height: 8.h),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: subjects.map((s) => GestureDetector(
                      onTap: () => setSheetState(() => selectedSubject = s),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          color: selectedSubject == s ? const Color(0xFF0284C7) : Colors.white,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: selectedSubject == s ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Text(
                          s,
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                            color: selectedSubject == s ? Colors.white : const Color(0xFF64748B),
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

                  // Attach Reference File
                  _buildSheetLabel('Attach Reference File'),
                  SizedBox(height: 6.h),
                  GestureDetector(
                    onTap: () async {
                      try {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['pdf', 'doc', 'docx', 'zip'],
                        );
                        if (result != null && result.files.isNotEmpty) {
                          setSheetState(() => attachedFile = result.files.first);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          showToast(context, 'Error picking file: $e');
                        }
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.all(14.r),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: attachedFile == null
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.cloud_upload_outlined, color: Color(0xFF0284C7), size: 20),
                                SizedBox(width: 8.w),
                                Text(
                                  'Tap to select a file (PDF, DOC, ZIP)',
                                  style: GoogleFonts.inter(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0284C7),
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                const Icon(Icons.description, color: Color(0xFF0284C7), size: 20),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: Text(
                                    attachedFile!.name,
                                    style: GoogleFonts.inter(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF334155),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => setSheetState(() => attachedFile = null),
                                  icon: const Icon(Icons.close, color: Colors.redAccent, size: 18),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Assign To (Class & Section)
                  _buildSheetLabel('Assign To'),
                  SizedBox(height: 6.h),
                  GestureDetector(
                    onTap: () {
                      _showTargetSelectionSheet(
                        context,
                        chosenClass,
                        chosenSections,
                        (cls, secs) {
                          setSheetState(() {
                            chosenClass = cls;
                            chosenSections.clear();
                            chosenSections.addAll(secs);
                          });
                        },
                      );
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
                          const Icon(Icons.people_alt_outlined, color: Color(0xFF0284C7), size: 18),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Text(
                              chosenClass != null && chosenSections.isNotEmpty
                                  ? 'Class $chosenClass (${chosenSections.join(', ')})'
                                  : 'Select Class & Section',
                              style: GoogleFonts.inter(
                                color: chosenClass != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                fontWeight: chosenClass != null ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13.sp,
                              ),
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Color(0xFF64748B), size: 18),
                        ],
                      ),
                    ),
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
                      if (chosenClass == null || chosenSections.isEmpty) {
                        showToast(context, 'Please select a target class & section', isError: true);
                        return;
                      }

                      setSheetState(() => _isSubmitting = true);
                      setState(() => _isSubmitting = true);

                      try {
                        final formattedDue = intl.DateFormat('yyyy-MM-dd').format(
                          tempDueDate ?? DateTime.now().add(const Duration(days: 1)),
                        );

                        // Save assignment record for each selected section
                        for (var sec in chosenSections) {
                          await Supabase.instance.client
                              .from('assignments')
                              .insert({
                                'title': titleCtrl.text.trim(),
                                'subject': selectedSubject,
                                'description': descCtrl.text.trim(),
                                'due_date': formattedDue,
                                'class_name': 'Grade $chosenClass',
                                'section': sec,
                              });
                        }

                        if (context.mounted) {
                          showToast(context, 'Assignment published successfully!');
                          Navigator.pop(context);
                        }
                        _loadAllData(showLoading: true);
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

  void _showTargetSelectionSheet(
    BuildContext context,
    String? initialClass,
    List<String> initialSections,
    Function(String?, List<String>) onConfirm,
  ) {
    String? activeClass = initialClass;
    final List<String> activeSections = List<String>.from(initialSections);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.all(20.r),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Target',
                    style: GoogleFonts.inter(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              SizedBox(height: 20.h),
              Text(
                'CHOOSE CLASS',
                style: GoogleFonts.inter(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF94A3B8),
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 10.h),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(12, (i) {
                  final clsStr = '${i + 1}';
                  final isSelected = activeClass == clsStr;
                  return GestureDetector(
                    onTap: () => setModalState(() => activeClass = clsStr),
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
                        clsStr,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : const Color(0xFF475569),
                          fontSize: 12.sp,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              SizedBox(height: 20.h),
              Text(
                'CHOOSE SECTION (MULTIPLE)',
                style: GoogleFonts.inter(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF94A3B8),
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 10.h),
              Row(
                children: ['A', 'B', 'C', 'D'].map((s) {
                  final isSelected = activeSections.contains(s);
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setModalState(() {
                          if (isSelected) {
                            activeSections.remove(s);
                          } else {
                            activeSections.add(s);
                          }
                        });
                      },
                      child: Container(
                        margin: EdgeInsets.only(right: s != 'D' ? 8.w : 0),
                        height: 38.h,
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            s,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : const Color(0xFF475569),
                              fontSize: 12.sp,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: 24.h),
              ElevatedButton(
                onPressed: () {
                  if (activeClass == null) {
                    showToast(context, 'Please select a class', isError: true);
                    return;
                  }
                  if (activeSections.isEmpty) {
                    showToast(context, 'Please select at least one section', isError: true);
                    return;
                  }
                  onConfirm(activeClass, activeSections);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 44.h),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                ),
                child: Text('Confirm Selection', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEvaluationDialog(BuildContext context, Map<String, dynamic> sub) {
    final scoreCtrl = TextEditingController(text: sub['score'] == 'Not Graded' ? '' : sub['score']);
    String selectedGrade = sub['grade'] == 'Pending' ? 'A+' : sub['grade'];
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
              _buildDialogLabel('ENTER SCORE (e.g. 92/100)'),
              SizedBox(height: 6.h),
              TextField(
                controller: scoreCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. 92/100',
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
                final score = scoreCtrl.text.trim().isEmpty ? 'Not Graded' : scoreCtrl.text.trim();
                Navigator.pop(ctx);

                showToast(context, 'Saving evaluation...');

                try {
                  await Supabase.instance.client
                      .from('submissions')
                      .update({
                        'grade': selectedGrade,
                        'score': score,
                      })
                      .eq('id', sub['id']);

                  if (context.mounted) {
                    showToast(context, 'Submission evaluated successfully!');
                  }
                  _loadAllData(showLoading: false);
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

  Widget _buildBotBubble() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Text(
        'HI\n${_teacherName.split(" ").first.toUpperCase()}!\nHOW\nCAN I\nHELP?',
        style: GoogleFonts.inter(
          fontSize: 10.sp,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF0284C7),
          height: 1.2,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  void _showChatbotDialog() {
    final messageCtrl = TextEditingController();
    final List<Map<String, String>> chatMessages = [
      {
        'sender': 'bot',
        'text': 'Hello $_teacherName! I am your EduSphere Helper. How can I assist you with assignment management or grading student work today?'
      }
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          title: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Color(0xFF0284C7)),
              SizedBox(width: 8.w),
              Text('AI Assistant Chat', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16.sp)),
            ],
          ),
          content: SizedBox(
            width: 320.w,
            height: 350.h,
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: chatMessages.length,
                    itemBuilder: (context, index) {
                      final msg = chatMessages[index];
                      final isBot = msg['sender'] == 'bot';
                      return Align(
                        alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
                        child: Container(
                          margin: EdgeInsets.symmetric(vertical: 4.h),
                          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                          decoration: BoxDecoration(
                            color: isBot ? const Color(0xFFF1F5F9) : const Color(0xFF0284C7),
                            borderRadius: BorderRadius.circular(16.r).copyWith(
                              topLeft: isBot ? Radius.zero : Radius.circular(16.r),
                              topRight: isBot ? Radius.circular(16.r) : Radius.zero,
                            ),
                          ),
                          child: Text(
                            msg['text']!,
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              color: isBot ? const Color(0xFF1E293B) : Colors.white,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: messageCtrl,
                        decoration: InputDecoration(
                          hintText: 'Ask helper...',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none),
                          contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                        ),
                        onFieldSubmitted: (val) {
                          if (val.trim().isEmpty) return;
                          setDialogState(() {
                            chatMessages.add({'sender': 'user', 'text': val});
                            final reply = _getBotReply(val);
                            chatMessages.add({'sender': 'bot', 'text': reply});
                          });
                          messageCtrl.clear();
                        },
                      ),
                    ),
                    SizedBox(width: 8.w),
                    IconButton(
                      icon: const Icon(Icons.send, color: Color(0xFF0284C7)),
                      onPressed: () {
                        final val = messageCtrl.text;
                        if (val.trim().isEmpty) return;
                        setDialogState(() {
                          chatMessages.add({'sender': 'user', 'text': val});
                          final reply = _getBotReply(val);
                          chatMessages.add({'sender': 'bot', 'text': reply});
                        });
                        messageCtrl.clear();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            )
          ],
        ),
      ),
    );
  }

  String _getBotReply(String query) {
    query = query.toLowerCase();
    if (query.contains('create') || query.contains('new assignment')) {
      return 'You can create a new assignment by clicking the blue "+ New Assignment" button at the top of the dashboard.';
    }
    if (query.contains('grade') || query.contains('evaluation') || query.contains('approve')) {
      return 'To grade student submissions, select an assignment from the "My Assignments" list, scroll to the "Submission Tracker" section, and click "Grade & Approve" on the student submission.';
    }
    if (query.contains('realtime') || query.contains('update')) {
      return 'The dashboard automatically syncs with the server using Supabase Realtime databases. Any changes by students or grading will appear instantly.';
    }
    return 'I am here to help you grade work, create assignments, and view classes! Let me know what you need.';
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
