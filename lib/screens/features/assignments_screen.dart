import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
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
  String _studentNameStr = 'Alex Rivera';
  String _classNameStr = 'Grade 12';
  String _sectionStr = 'A';

  final List<Map<String, dynamic>> _assignments = [];

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
          table: 'assignments',
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
          table: 'submissions',
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
      final savedName = prefs.getString('student_name') ?? prefs.getString('user_name');
      if (savedEmail != null) {
        _studentEmailStr = savedEmail;
      }
      if (savedName != null) {
        _studentNameStr = savedName;
      }

      // 1. Fetch student info
      final studentRes = await Supabase.instance.client
          .from('students')
          .select()
          .eq('email', _studentEmailStr)
          .maybeSingle();

      if (studentRes != null) {
        _studentIdStr = studentRes['id'] as String;
        _classNameStr = studentRes['class_name'] as String? ?? 'Grade 12';
        _sectionStr = studentRes['section'] as String? ?? 'A';
        _studentNameStr = studentRes['name'] as String? ?? _studentNameStr;
      }

      // 2. Fetch assignments for this class & section
      final List<dynamic> assignmentsRes = await Supabase.instance.client
          .from('assignments')
          .select()
          .eq('class_name', _classNameStr)
          .eq('section', _sectionStr);

      // 3. Fetch submissions by this student
      final List<dynamic> submissionsRes = _studentIdStr.isNotEmpty
          ? await Supabase.instance.client
              .from('submissions')
              .select()
              .eq('student_id', _studentIdStr)
          : [];

      // Map submissions by assignment_id
      final Map<String, Map<String, dynamic>> submissionsMap = {};
      for (var sub in submissionsRes) {
        final assId = sub['assignment_id'] as String;
        submissionsMap[assId] = Map<String, dynamic>.from(sub);
      }

      final List<Map<String, dynamic>> tempAssignments = [];

      for (var ass in assignmentsRes) {
        final assId = ass['id'] as String;
        final title = ass['title'] as String? ?? 'Untitled';
        final subject = ass['subject'] as String? ?? 'General';
        final desc = ass['description'] as String? ?? '';
        final dueDateStr = ass['due_date'] as String?;
        
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

        String formattedDue = 'No due date';
        if (due != null) {
          formattedDue = intl.DateFormat('MMM d, yyyy').format(due);
        }

        final bool isSubmitted = submissionsMap.containsKey(assId);
        final sub = submissionsMap[assId];

        String? formattedSub;
        if (sub != null) {
          final subAtStr = sub['submitted_at'] as String?;
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
          'isSubmitted': isSubmitted,
          'submittedAt': formattedSub ?? 'Recently',
          'grade': sub?['grade'] as String? ?? 'Pending',
          'score': sub?['score'] as String? ?? 'Not Graded',
          'fileName': sub?['file_name'] as String?,
        });
      }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header matching React Client style
            Padding(
              padding: EdgeInsets.fromLTRB(24.r, 24.r, 24.r, 8.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Assignments',
                    style: GoogleFonts.inter(
                      fontSize: 28.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'View and submit your classwork',
                    style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.studentPrimary))
                  : RefreshIndicator(
                      onRefresh: () => _loadAssignmentsData(showLoading: true),
                      color: AppColors.studentPrimary,
                      child: ListView(
                        padding: EdgeInsets.all(24.r),
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(color: AppColors.border),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 16.r,
                                  offset: Offset(0, 4.h),
                                ),
                              ],
                            ),
                            padding: EdgeInsets.all(24.r),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Academic Assignments',
                                  style: GoogleFonts.inter(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  'Click on an assignment to submit your work or view grades.',
                                  style: GoogleFonts.inter(
                                    fontSize: 12.sp,
                                    color: AppColors.textMedium,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                SizedBox(height: 24.h),
                                
                                if (_assignments.isEmpty)
                                  CustomPaint(
                                    painter: DashedRectPainter(
                                      color: const Color(0xFFCBD5E1),
                                      radius: 12.r,
                                    ),
                                    child: Container(
                                      width: double.infinity,
                                      padding: EdgeInsets.symmetric(vertical: 48.h),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.description_outlined,
                                            color: const Color(0xFFCBD5E1),
                                            size: 48.r,
                                          ),
                                          SizedBox(height: 16.h),
                                          Text(
                                            'No assignments found for your class.',
                                            style: GoogleFonts.inter(
                                              fontSize: 14.sp,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textMedium,
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
                                    separatorBuilder: (_, __) => const Divider(height: 20, color: AppColors.border),
                                    itemBuilder: (_, index) {
                                      final a = _assignments[index];
                                      final bool isSubmitted = a['isSubmitted'] as bool;
                                      final bool isUrgent = a['urgent'] as bool;
                                      
                                      return ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Container(
                                          width: 44.r,
                                          height: 44.r,
                                          decoration: BoxDecoration(
                                            color: isSubmitted
                                                ? const Color(0xFFDCFCE7)
                                                : (isUrgent ? const Color(0xFFFFE4E6) : const Color(0xFFEFF6FF)),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.assignment_outlined,
                                            color: isSubmitted
                                                ? const Color(0xFF15803D)
                                                : (isUrgent ? const Color(0xFFE11D48) : const Color(0xFF1A6FDB)),
                                            size: 20.r,
                                          ),
                                        ),
                                        title: Text(
                                          a['title'] as String,
                                          style: GoogleFonts.inter(
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textDark,
                                          ),
                                        ),
                                        subtitle: Padding(
                                          padding: EdgeInsets.only(top: 4.h),
                                          child: Text(
                                            '${a['subject']} • ${isSubmitted ? 'Submitted' : 'Due: ${a['due']}'}',
                                            style: GoogleFonts.inter(
                                              fontSize: 12.sp,
                                              color: AppColors.textMedium,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        trailing: Container(
                                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                          decoration: BoxDecoration(
                                            color: isSubmitted 
                                                ? const Color(0xFFDCFCE7) 
                                                : (isUrgent ? const Color(0xFFFFE4E6) : const Color(0xFFF1F5F9)),
                                            borderRadius: BorderRadius.circular(12.r),
                                          ),
                                          child: Text(
                                            isSubmitted 
                                                ? (a['grade'] == 'Pending' ? 'Submitted' : a['grade'] as String)
                                                : (isUrgent ? 'Due Today' : 'Pending'),
                                            style: GoogleFonts.inter(
                                              fontSize: 11.sp,
                                              fontWeight: FontWeight.w700,
                                              color: isSubmitted 
                                                  ? const Color(0xFF15803D) 
                                                  : (isUrgent ? const Color(0xFFE11D48) : const Color(0xFF64748B)),
                                            ),
                                          ),
                                        ),
                                        onTap: () => _showAssignmentDetails(a),
                                      );
                                    },
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
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        a['title'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
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
                          color: AppColors.studentPrimary,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'Due: ${a['due']}',
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: isUrgent ? const Color(0xFFE11D48) : AppColors.textMedium,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20.h),
                
                // Description
                Text(
                  'Instructions',
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 6.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    (a['description'] as String).isNotEmpty
                        ? a['description'] as String
                        : 'No specific instructions provided.',
                    style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      color: AppColors.textDark,
                      height: 1.4,
                    ),
                  ),
                ),
                SizedBox(height: 24.h),

                // Submission Section
                if (isSubmitted) ...[
                  Text(
                    'Your Submission',
                    style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
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
                      color: AppColors.textDark,
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
                                color: AppColors.studentPrimary,
                                size: 32.sp,
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                'Tap to select a file',
                                style: GoogleFonts.inter(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.studentPrimary,
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                'PDF, DOC, ZIP up to 50MB',
                                style: GoogleFonts.inter(
                                  fontSize: 11.sp,
                                  color: AppColors.textLight,
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
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.insert_drive_file_outlined, color: AppColors.studentPrimary, size: 24.sp),
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
                                    color: AppColors.textDark,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  '${(selectedFile!.size / 1024 / 1024).toStringAsFixed(2)} MB',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.sp,
                                    color: AppColors.textMedium,
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
                  LoadingButton(
                    label: isSubmitting ? 'Submitting...' : 'Submit Assignment',
                    color: selectedFile == null || isSubmitting ? Colors.grey.shade400 : AppColors.studentPrimary,
                    onPressed: () async {
                      if (selectedFile == null || isSubmitting) return;
                      setModalState(() {
                        isSubmitting = true;
                      });
                      try {
                        await Supabase.instance.client
                            .from('submissions')
                            .upsert({
                              'assignment_id': a['id'],
                              'student_id': _studentIdStr,
                              'student_name': _studentNameStr,
                              'file_name': selectedFile!.name,
                              'grade': 'Pending',
                              'score': 'Not Graded',
                              'submitted_at': DateTime.now().toUtc().toIso8601String(),
                            }, onConflict: 'assignment_id, student_id');
                        
                        if (context.mounted) {
                          showToast(context, 'Successfully submitted ${a['title']}!');
                          Navigator.pop(context); // Close bottom sheet
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
