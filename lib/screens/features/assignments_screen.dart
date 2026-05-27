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

class _AssignmentsScreenState extends State<AssignmentsScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  bool _isLoading = true;

  String _studentEmailStr = 'alex.rivera@edusmart.edu';
  String _studentIdStr = '';
  String _studentNameStr = 'Alex Rivera';
  String _classNameStr = 'Grade 12';
  String _sectionStr = 'A';

  final List<Map<String, dynamic>> _pending = [];
  final List<Map<String, dynamic>> _submitted = [];

  RealtimeChannel? _assignmentsChannel;
  Timer? _assignmentsPollTimer;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
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
    _tab.dispose();
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

      final List<Map<String, dynamic>> tempPending = [];
      final List<Map<String, dynamic>> tempSubmitted = [];

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

        if (submissionsMap.containsKey(assId)) {
          final sub = submissionsMap[assId]!;
          final subAtStr = sub['submitted_at'] as String?;
          String formattedSub = 'Recently';
          if (subAtStr != null) {
            try {
              final subAt = DateTime.parse(subAtStr);
              formattedSub = intl.DateFormat('MMM d').format(subAt);
            } catch (_) {}
          }
          tempSubmitted.add({
            'id': assId,
            'title': title,
            'subject': subject,
            'submitted': formattedSub,
            'grade': sub['grade'] as String? ?? 'Pending',
            'score': sub['score'] as String? ?? 'Not Graded',
          });
        } else {
          tempPending.add({
            'id': assId,
            'title': title,
            'subject': subject,
            'description': desc,
            'due': formattedDue,
            'urgent': isUrgent,
          });
        }
      }

      if (mounted) {
        setState(() {
          _pending.clear();
          _pending.addAll(tempPending);
          _submitted.clear();
          _submitted.addAll(tempSubmitted);
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
      body: Column(
        children: [
          PageHeader(
            title: 'Assignments', 
            subtitle: '${_pending.length} pending • ${_submitted.length} submitted', 
            theme: roleThemes['student']!
          ),
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tab,
              labelColor: AppColors.studentPrimary,
              unselectedLabelColor: AppColors.textLight,
              indicatorColor: AppColors.studentPrimary,
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13.sp),
              tabs: [
                Tab(text: '📋 Pending (${_pending.length})'), 
                Tab(text: '✅ Submitted (${_submitted.length})')
              ],
            ),
          ),
          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.studentPrimary))
              : TabBarView(
                  controller: _tab,
                  children: [
                    // Pending list
                    _pending.isEmpty
                      ? Center(child: Text('No pending assignments! 🎉', style: GoogleFonts.inter(color: AppColors.textMedium, fontSize: 14.sp)))
                      : RefreshIndicator(
                          onRefresh: () => _loadAssignmentsData(showLoading: true),
                          color: AppColors.studentPrimary,
                          child: ListView.builder(
                            padding: EdgeInsets.all(16.r),
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: _pending.length,
                            itemBuilder: (_, i) {
                              final a = _pending[i];
                              return Container(
                                margin: EdgeInsets.only(bottom: 14.h),
                                padding: EdgeInsets.all(18.r),
                                decoration: BoxDecoration(
                                  color: Colors.white, 
                                  borderRadius: BorderRadius.circular(20.r),
                                  border: Border.all(
                                    color: a['urgent'] == true ? Colors.red.shade200 : AppColors.border, 
                                    width: a['urgent'] == true ? 2 : 1
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start, 
                                  children: [
                                    if (a['urgent'] == true)
                                      Row(children: [
                                        Icon(Icons.warning_rounded, color: Colors.red, size: 14.sp),
                                        SizedBox(width: 4.w),
                                        Text('DUE TODAY!', style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w900, color: Colors.red)),
                                      ]),
                                    if (a['urgent'] == true) SizedBox(height: 8.h),
                                    Text(a['title'] as String, style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppColors.textDark, fontSize: 14.sp)),
                                    SizedBox(height: 4.h),
                                    Text(a['subject'] as String, style: GoogleFonts.inter(fontSize: 12.sp, color: AppColors.textMedium)),
                                    SizedBox(height: 4.h),
                                    Text('📅 Due: ${a['due']}', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: a['urgent'] == true ? Colors.red : AppColors.textLight)),
                                    SizedBox(height: 14.h),
                                    LoadingButton(
                                      label: '📤 Upload Submission',
                                      color: AppColors.studentPrimary,
                                      onPressed: () async {
                                        final result = await FilePicker.platform.pickFiles();
                                        if (!context.mounted) return;
                                        if (result != null && result.files.isNotEmpty) {
                                          final fileName = result.files.first.name;
                                          setState(() { _isLoading = true; });
                                          try {
                                            await Supabase.instance.client
                                                .from('submissions')
                                                .upsert({
                                                  'assignment_id': a['id'],
                                                  'student_id': _studentIdStr,
                                                  'student_name': _studentNameStr,
                                                  'file_name': fileName,
                                                  'grade': 'Pending',
                                                  'score': 'Not Graded',
                                                  'submitted_at': DateTime.now().toUtc().toIso8601String(),
                                                }, onConflict: 'assignment_id, student_id');
                                                
                                            if (context.mounted) {
                                              showToast(context, 'Successfully submitted ${a['title']}!');
                                            }
                                            await _loadAssignmentsData(showLoading: true);
                                            if (context.mounted) {
                                              _tab.animateTo(1); // Switch to Submitted tab
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              showToast(context, 'Error submitting: $e');
                                            }
                                          } finally {
                                            setState(() { _isLoading = false; });
                                          }
                                        } else {
                                          showToast(context, 'No file selected');
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                    // Submitted list
                    _submitted.isEmpty
                      ? Center(child: Text('No submissions yet.', style: GoogleFonts.inter(color: AppColors.textMedium, fontSize: 14.sp)))
                      : RefreshIndicator(
                          onRefresh: () => _loadAssignmentsData(showLoading: true),
                          color: AppColors.studentPrimary,
                          child: ListView.builder(
                            padding: EdgeInsets.all(16.r),
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: _submitted.length,
                            itemBuilder: (_, i) {
                              final a = _submitted[i];
                              return Container(
                                margin: EdgeInsets.only(bottom: 14.h),
                                padding: EdgeInsets.all(18.r),
                                decoration: BoxDecoration(
                                  color: Colors.white, 
                                  borderRadius: BorderRadius.circular(20.r), 
                                  border: Border.all(color: AppColors.border)
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start, 
                                        children: [
                                          Text(a['title']!, style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppColors.textDark, fontSize: 14.sp)),
                                          Text('${a['subject']} • Submitted ${a['submitted']}', style: GoogleFonts.inter(fontSize: 12.sp, color: AppColors.textMedium)),
                                          SizedBox(height: 8.h),
                                          Row(children: [
                                            Icon(Icons.check_circle_rounded, color: const Color(0xFF10B981), size: 16.sp),
                                            SizedBox(width: 4.w),
                                            Text('Score: ${a['score']}', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: const Color(0xFF10B981))),
                                          ]),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                                      decoration: BoxDecoration(
                                        color: AppColors.studentLight, 
                                        borderRadius: BorderRadius.circular(12.r)
                                      ),
                                      child: Text(a['grade']!, style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.w900, color: AppColors.studentPrimary)),
                                    ),
                                  ],
                                ),
                              );
                            },
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
