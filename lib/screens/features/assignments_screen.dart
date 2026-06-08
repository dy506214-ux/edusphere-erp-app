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
  String _selectedSubject = 'All';
  final List<String> _subjects = ['All', 'Hindi', 'English', 'Math', 'Science', 'Computer'];

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
      
      dev.log('📡 Subscribing to Supabase Realtime changes for Assignments Screen...', name: 'AssignmentsScreen');
      _assignmentsChannel = client.channel('public:assignments_screen_sync')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'Assignment',
          callback: (payload) {
            dev.log('🔥 Real-time assignment event payload: $payload', name: 'AssignmentsScreen');
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
            dev.log('🔥 Real-time submission event payload: $payload', name: 'AssignmentsScreen');
            if (mounted) {
              _loadAssignmentsData(showLoading: false);
            }
          },
        );
      
      _assignmentsChannel!.subscribe((status, [error]) {
        dev.log('📡 Supabase Realtime Assignments channel status: $status', name: 'AssignmentsScreen');
        if (error != null) {
          dev.log('❌ Supabase Realtime Assignments subscription error: $error', name: 'AssignmentsScreen');
        }
      });
    } catch (e) {
      dev.log('⚠️ Error connecting Supabase Realtime Assignments channel: $e', name: 'AssignmentsScreen');
    }
    
    // Polling fallback every 2 seconds for robust silent updates
    _assignmentsPollTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        _loadAssignmentsData(showLoading: false);
      }
    });
  }

  Future<void> _loadAssignmentsData({bool showLoading = true}) async {
    if (!mounted) return;
    if (showLoading) {
      setState(() { _isLoading = true; });
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('student_email') ?? prefs.getString('user_email');
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
        final bool isOverdue = !isSubmitted && due != null && DateTime(due.year, due.month, due.day).isBefore(today);

        String formattedDue = 'No due date';
        if (due != null) {
          formattedDue = intl.DateFormat('MMM d, yyyy').format(due);
        }

        String? formattedSub;
        if (sub != null) {
          final subAtStr = (sub['submittedAt'] ?? sub['submitted_at']) as String?;
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
          'score': (sub?['feedback'] ?? sub?['score'])?.toString() ?? 'Not Graded',
          'fileName': (sub?['filePath'] ?? sub?['fileName'] ?? sub?['file_name']) as String?,
        });
      }

      // Add mock English assignment to list to match user request / first image mockup
      final bool isMockSubmitted = prefs.getBool('mock_sub_chapter_1') ?? false;
      final String? mockFileName = prefs.getString('mock_file_chapter_1');
      final String? mockSubAt = prefs.getString('mock_date_chapter_1');

      tempAssignments.add({
        'id': 'mock-chapter-1-assignment-id',
        'title': 'Chapter 1 Assignment',
        'subject': 'English',
        'description': 'Complete exercises from Chapter 1',
        'due': 'Sep 30, 2024',
        'urgent': false,
        'isOverdue': !isMockSubmitted,
        'isSubmitted': isMockSubmitted,
        'submittedAt': mockSubAt ?? 'Recently',
        'grade': 'Pending',
        'score': 'Not Graded',
        'fileName': mockFileName,
      });

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
                Padding(
                  padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 16.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'My Assignments',
                              style: GoogleFonts.inter(
                                fontSize: 22.sp,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF0F2547),
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              'View and submit your classwork',
                              style: GoogleFonts.inter(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF6B7A90),
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: Container(
                          padding: EdgeInsets.all(10.r),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: const Color(0xFFE2EAF4), width: 1.5.w),
                          ),
                          child: Icon(Icons.filter_alt_outlined, color: const Color(0xFF2E7DF7), size: 20.sp),
                        ),
                        offset: Offset(0, 50.h),
                        onSelected: (String sub) {
                          setState(() {
                            _selectedSubject = sub;
                          });
                        },
                        itemBuilder: (BuildContext context) {
                          return _subjects.map((String sub) {
                            final bool isSelected = _selectedSubject == sub;
                            return PopupMenuItem<String>(
                              value: sub,
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                                    color: isSelected ? const Color(0xFF2E7DF7) : const Color(0xFF94A3B8),
                                    size: 18.sp,
                                  ),
                                  SizedBox(width: 8.w),
                                  Text(
                                    sub,
                                    style: GoogleFonts.inter(
                                      fontSize: 13.sp,
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      color: isSelected ? const Color(0xFF0F2547) : const Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ],
                  ),
                ),

                // Top Header Card
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: _buildHeaderCard(),
                ),
                SizedBox(height: 16.h),

                // Assignments List Content
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7DF7)))
                      : RefreshIndicator(
                          onRefresh: () => _loadAssignmentsData(showLoading: true),
                          color: const Color(0xFF2E7DF7),
                          child: filtered.isEmpty
                              ? _buildEmptyState()
                              : ListView.builder(
                                  padding: EdgeInsets.only(bottom: 100.h),
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    return _buildAssignmentCard(filtered[index]);
                                  },
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

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2EAF4), width: 1.5.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 10.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: Row(
        children: [
          // Circle notebook icon container
          Container(
            width: 40.w,
            height: 40.w,
            decoration: const BoxDecoration(
              color: Color(0xFFE8F1FB),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.menu_book_rounded, color: const Color(0xFF2E7DF7), size: 20.sp),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Academic Assignments',
                  style: GoogleFonts.inter(
                    fontSize: 14.5.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F2547),
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  'Click on an assignment to submit your work or view grades.',
                  style: GoogleFonts.inter(
                    fontSize: 11.5.sp,
                    color: const Color(0xFF6B7A90),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
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
                  border: Border.all(color: const Color(0xFFBFDBFE), width: 1.w),
                ),
                child: Text(
                  subject.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 9.5.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF2563EB),
                    letterSpacing: 0.5,
                  ),
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
                          : (isUrgent ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9))), // Soft yellow/grey
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  isSubmitted
                      ? "Submitted"
                      : (isOverdue
                          ? "Overdue"
                          : (isUrgent ? "Due Today" : "Pending")),
                  style: GoogleFonts.inter(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w800,
                    color: isSubmitted
                        ? const Color(0xFF059669) // Green text
                        : (isOverdue
                            ? const Color(0xFFEF4444) // Red text
                            : (isUrgent ? const Color(0xFFD97706) : const Color(0xFF475569))),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),

          // Assignment Title
          Text(
            a['title'] as String,
            style: GoogleFonts.inter(
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 4.h),

          // Assignment Description
          Text(
            a['description'] as String,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 12.5.sp,
              color: const Color(0xFF475569),
              height: 1.3,
            ),
          ),
          
          Divider(color: const Color(0xFFE2EAF4), height: 24.h, thickness: 1.h),

          // Meta Info Row
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 14.sp, color: const Color(0xFF64748B)),
              SizedBox(width: 6.w),
              Text(
                'Due: ${a['due']}',
                style: GoogleFonts.inter(
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
              const Spacer(),
              Icon(Icons.person_outline_rounded, size: 16.sp, color: const Color(0xFF94A3B8)),
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
                    Icon(Icons.access_time_rounded, color: const Color(0xFF2563EB), size: 16.sp),
                    SizedBox(width: 8.w),
                    Text(
                      'Awaiting Grade',
                      style: GoogleFonts.inter(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2563EB),
                      ),
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
                    Icon(Icons.check_circle_rounded, color: const Color(0xFF10B981), size: 16.sp),
                    SizedBox(width: 8.w),
                    Text(
                      'Graded: $grade (${a['score']})',
                      style: GoogleFonts.inter(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF10B981),
                      ),
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
                  color: isOverdue ? const Color(0xFFEF4444) : const Color(0xFF2E7DF7),
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(
                      color: (isOverdue ? const Color(0xFFEF4444) : const Color(0xFF2E7DF7)).withValues(alpha: 0.15),
                      blurRadius: 10.r,
                      offset: Offset(0, 3.h),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isOverdue ? Icons.upload_rounded : Icons.cloud_upload_outlined,
                      color: Colors.white,
                      size: 16.sp,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      isOverdue ? 'Submit Late' : 'Submit Assignment',
                      style: GoogleFonts.inter(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
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
    return Center(
      child: Container(
        margin: EdgeInsets.all(24.r),
        padding: EdgeInsets.symmetric(vertical: 48.h, horizontal: 24.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: const Color(0xFFE9F0F8), width: 1.5.w),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16.r),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.assignment_outlined,
                color: const Color(0xFF94A3B8),
                size: 44.sp,
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'No assignments found',
              style: GoogleFonts.inter(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'No tasks matched the selected subject filter.',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                color: const Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showAssignmentDetails(Map<String, dynamic> a) {
    PlatformFile? selectedFile;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final bool isSubmitted = a['isSubmitted'] as bool;
          final bool isUrgent = a['urgent'] as bool;

          return Container(
            padding: EdgeInsets.fromLTRB(24.r, 24.r, 24.r, 24.r + MediaQuery.of(context).viewInsets.bottom),
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
                    Expanded(
                      child: Text(
                        a['title'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        a['subject'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF2E7DF7),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'Due: ${a['due']}',
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: isUrgent ? const Color(0xFFE11D48) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20.h),
                
                Text(
                  'Instructions',
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 6.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    (a['description'] as String).isNotEmpty
                        ? a['description'] as String
                        : 'No specific instructions provided.',
                    style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      color: const Color(0xFF0F172A),
                      height: 1.4,
                    ),
                  ),
                ),
                SizedBox(height: 24.h),

                if (isSubmitted) ...[
                  Text(
                    'Your Submission',
                    style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Container(
                    padding: EdgeInsets.all(16.r),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: const Color(0xFFDCFCE7)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF15803D)),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a['fileName'] as String? ?? 'submission_file.pdf',
                                    style: GoogleFonts.inter(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF14532D),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    'Submitted on ${a['submittedAt']}',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.sp,
                                      color: const Color(0xFF166534),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (a['grade'] != 'Pending') ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(color: Color(0xFFDCFCE7), height: 1),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Grade & Score:',
                                style: GoogleFonts.inter(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF14532D),
                                ),
                              ),
                              Text(
                                '${a['score']} (${a['grade']})',
                                style: GoogleFonts.inter(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF15803D),
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
                    'Upload Submission',
                    style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  if (selectedFile == null)
                    GestureDetector(
                      onTap: () async {
                        try {
                          final result = await FilePicker.platform.pickFiles();
                          if (result != null && result.files.isNotEmpty) {
                            setModalState(() {
                              selectedFile = result.files.first;
                            });
                          }
                        } catch (e) {
                          if (context.mounted) {
                            showToast(context, 'Error picking file: $e');
                          }
                        }
                      },
                      child: CustomPaint(
                        painter: DashedRectPainter(
                          color: const Color(0xFFCBD5E1),
                          radius: 12.r,
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(vertical: 24.h),
                          child: Column(
                            children: [
                              Icon(
                                Icons.cloud_upload_outlined,
                                color: const Color(0xFF2E7DF7),
                                size: 32.sp,
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                'Tap to select a file',
                                style: GoogleFonts.inter(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF2E7DF7),
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                'PDF, DOC, ZIP up to 50MB',
                                style: GoogleFonts.inter(
                                  fontSize: 11.sp,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: EdgeInsets.all(12.r),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.insert_drive_file_outlined, color: const Color(0xFF2E7DF7), size: 24.sp),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                  Text(
                                    selectedFile!.name,
                                    style: GoogleFonts.inter(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                SizedBox(height: 2.h),
                                Text(
                                  '${(selectedFile!.size / 1024 / 1024).toStringAsFixed(2)} MB',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.sp,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setModalState(() {
                                selectedFile = null;
                              });
                            },
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(height: 24.h),
                  GestureDetector(
                    onTap: () async {
                      if (selectedFile == null || isSubmitting) return;
                      setModalState(() {
                        isSubmitting = true;
                      });
                      try {
                        if (a['id'] == 'mock-chapter-1-assignment-id') {
                          // Handle mock submission locally in SharedPreferences
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('mock_sub_chapter_1', true);
                          await prefs.setString('mock_file_chapter_1', selectedFile!.name);
                          await prefs.setString('mock_date_chapter_1', intl.DateFormat('MMM d, yyyy').format(DateTime.now()));
                          
                          if (context.mounted) {
                            showToast(context, 'Successfully submitted ${a['title']}!');
                            Navigator.pop(context);
                          }
                          _loadAssignmentsData(showLoading: true);
                          return;
                        }

                        await Supabase.instance.client
                            .from('AssignmentSubmission')
                            .upsert({
                              'assignmentId': a['id'],
                              'studentId': _studentIdStr,
                              'filePath': selectedFile!.name,
                              'status': 'SUBMITTED',
                              'grade': 'Pending',
                              'feedback': null,
                              'submittedAt': DateTime.now().toUtc().toIso8601String(),
                            }, onConflict: 'assignmentId,studentId');
                        
                        if (context.mounted) {
                          showToast(context, 'Successfully submitted ${a['title']}!');
                          Navigator.pop(context);
                        }
                        _loadAssignmentsData(showLoading: true);
                      } catch (e) {
                        if (context.mounted) {
                          showToast(context, 'Error submitting: $e');
                        }
                      } finally {
                        setModalState(() {
                          isSubmitting = false;
                        });
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      decoration: BoxDecoration(
                        color: selectedFile == null || isSubmitting ? Colors.grey.shade400 : const Color(0xFF2E7DF7),
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      child: Center(
                        child: Text(
                          isSubmitting ? 'Submitting...' : 'Submit Assignment',
                          style: GoogleFonts.inter(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
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
          pathMetric.extractPath(distance, isLast ? pathMetric.length : nextDistance),
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
