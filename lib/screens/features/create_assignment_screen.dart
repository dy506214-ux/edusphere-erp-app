import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart' as intl;

class CreateAssignmentScreen extends StatefulWidget {
  const CreateAssignmentScreen({super.key});
  @override
  State<CreateAssignmentScreen> createState() => _CreateAssignmentScreenState();
}

class _CreateAssignmentScreenState extends State<CreateAssignmentScreen> with SingleTickerProviderStateMixin {
  final _titleCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();
  String _subject = 'Physics';
  bool _published = false;
  PlatformFile? _attachedFile;
  DateTime? _dueDate;
  bool _isSubmitting = false;

  final _subjects = ['Physics', 'Maths', 'Chemistry', 'English', 'CS'];
  String? _selectedClass;
  final List<String> _selectedSections = [];

  bool get _isTargetSelected => _selectedClass != null && _selectedSections.isNotEmpty;
  String get _targetText => _isTargetSelected 
      ? 'Class $_selectedClass (${_selectedSections.join(', ')})' 
      : 'Select Class & Section';

  String _getDbClassName(String val) {
    final numStr = val.replaceAll(RegExp(r'[^0-9]'), '');
    return 'Grade $numStr';
  }

  late TabController _tabController;
  bool _isLoadingSubmissions = true;
  final List<Map<String, dynamic>> _submissionsList = [];
  RealtimeChannel? _submissionsChannel;
  Timer? _submissionsPollTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSubmissionsData();
    _connectRealTime();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _tabController.dispose();
    _submissionsPollTimer?.cancel();
    if (_submissionsChannel != null) {
      try {
        Supabase.instance.client.removeChannel(_submissionsChannel!);
      } catch (_) {}
    }
    super.dispose();
  }

  Future<void> _loadSubmissionsData({bool showLoading = true}) async {
    if (!mounted) return;
    if (showLoading) {
      setState(() { _isLoadingSubmissions = true; });
    }
    try {
      final List<dynamic> submissionsRes = await Supabase.instance.client
          .from('submissions')
          .select('*, assignments(title, subject)')
          .order('submitted_at', ascending: false);
      
      final List<Map<String, dynamic>> temp = [];
      for (var row in submissionsRes) {
        final ass = row['assignments'] as Map<String, dynamic>?;
        final assTitle = ass?['title'] as String? ?? 'Untitled Assignment';
        final assSubject = ass?['subject'] as String? ?? 'General';
        
        temp.add({
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
          _submissionsList.clear();
          _submissionsList.addAll(temp);
          _isLoadingSubmissions = false;
        });
      }
    } catch (e) {
      dev.log('⚠️ Error loading submissions: $e', name: 'CreateAssignmentScreen');
      if (mounted) {
        setState(() { _isLoadingSubmissions = false; });
      }
    }
  }

  void _connectRealTime() {
    try {
      final client = Supabase.instance.client;
      
      if (_submissionsChannel != null) {
        client.removeChannel(_submissionsChannel!);
      }
      
      dev.log('📡 Subscribing to Supabase Realtime changes for Submissions...', name: 'CreateAssignmentScreen');
      _submissionsChannel = client.channel('public:submissions_sync')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'submissions',
          callback: (payload) {
            dev.log('🔥 Real-time submissions change payload: $payload', name: 'CreateAssignmentScreen');
            if (mounted) {
              _loadSubmissionsData(showLoading: false);
            }
          },
        );
      
      _submissionsChannel!.subscribe((status, [error]) {
        dev.log('📡 Supabase Realtime Submissions status: $status', name: 'CreateAssignmentScreen');
        if (error != null) {
          dev.log('❌ Supabase Realtime Submissions subscription error: $error', name: 'CreateAssignmentScreen');
        }
      });
    } catch (e) {
      dev.log('⚠️ Error connecting Supabase Realtime Submissions channel: $e', name: 'CreateAssignmentScreen');
    }
    
    // Polling fallback every 2 seconds for robust real-time updates
    _submissionsPollTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        _loadSubmissionsData(showLoading: false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_published) return _buildSuccess(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PageHeader(
            title: 'Manage Assignments', 
            subtitle: 'Create & approve assignments', 
            theme: roleThemes['teacher']!
          ),
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.teacherPrimary,
              unselectedLabelColor: AppColors.textLight,
              indicatorColor: AppColors.teacherPrimary,
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13.sp),
              tabs: const [
                Tab(text: '📝 Create Assignment'),
                Tab(text: '✅ Approve Submissions'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Create Assignment Form
                SingleChildScrollView(
                  padding: EdgeInsets.all(16.r),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Title'),
                      SizedBox(height: 6.h),
                      TextField(controller: _titleCtrl, decoration: _dec('e.g. Quantum Physics Lab Report')),
                      SizedBox(height: 16.h),
                      _label('Subject'),
                      SizedBox(height: 8.h),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: _subjects.map((s) => GestureDetector(
                          onTap: () => setState(() => _subject = s),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                            decoration: BoxDecoration(
                              color: _subject == s ? AppColors.teacherPrimary : Colors.white,
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(color: _subject == s ? AppColors.teacherPrimary : AppColors.border),
                            ),
                            child: Text(s, style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w700, color: _subject == s ? Colors.white : AppColors.textMedium)),
                          ),
                        )).toList(),
                      ),
                      SizedBox(height: 16.h),
                      _label('Instructions'),
                      SizedBox(height: 6.h),
                      TextField(controller: _descCtrl, maxLines: 4, decoration: _dec('Describe the assignment requirements...')),
                      SizedBox(height: 16.h),
                      _label('Due Date'),
                      SizedBox(height: 6.h),
                      GestureDetector(
                        onTap: () async {
                          final selected = await showDatePicker(
                            context: context, 
                            initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 1)), 
                            firstDate: DateTime.now(), 
                            lastDate: DateTime(DateTime.now().year + 5)
                          );
                          if (selected != null) {
                            setState(() { _dueDate = selected; });
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.all(16.r),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.r), border: Border.all(color: AppColors.border)),
                          child: Row(children: [
                            Icon(Icons.calendar_today_rounded, color: AppColors.textLight, size: 20.sp),
                            SizedBox(width: 12.w),
                            Text(
                              _dueDate == null 
                                ? 'Select due date' 
                                : intl.DateFormat('MMM d, yyyy').format(_dueDate!), 
                              style: GoogleFonts.inter(
                                color: _dueDate == null ? AppColors.textLight : AppColors.textDark,
                                fontWeight: _dueDate == null ? FontWeight.normal : FontWeight.w700
                              )
                            ),
                          ]),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      _label('Attach File'),
                      SizedBox(height: 6.h),
                      GestureDetector(
                        onTap: () async {
                          try {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: ['pdf', 'doc', 'docx', 'zip'],
                            );
                            if (!context.mounted) return;
                            if (result != null && result.files.isNotEmpty) {
                              setState(() => _attachedFile = result.files.first);
                              showToast(context, 'File attached successfully');
                            }
                          } catch (e) {
                            if (!context.mounted) return;
                            showToast(context, 'Error picking file: $e');
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: EdgeInsets.all(16.r),
                          decoration: BoxDecoration(
                            color: _attachedFile != null ? AppColors.teacherPrimary.withValues(alpha: 0.02) : Colors.white, 
                            borderRadius: BorderRadius.circular(16.r), 
                            border: Border.all(
                              color: _attachedFile != null ? AppColors.teacherPrimary : AppColors.border, 
                              width: _attachedFile != null ? 2 : 1
                            ),
                            boxShadow: [
                              if (_attachedFile != null)
                                BoxShadow(color: AppColors.teacherPrimary.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))
                              else
                                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))
                            ],
                          ),
                          child: _attachedFile == null 
                            ? Column(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(12.r),
                                    decoration: const BoxDecoration(
                                      color: AppColors.background,
                                      shape: BoxShape.circle
                                    ),
                                    child: Icon(Icons.upload_file_rounded, color: AppColors.teacherPrimary, size: 28.sp),
                                  ),
                                  SizedBox(height: 12.h),
                                  Text('Tap to attach reference file', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textDark, fontSize: 14.sp)),
                                  SizedBox(height: 4.h),
                                  Text('PDF, DOC, ZIP up to 50MB', style: GoogleFonts.inter(fontSize: 12.sp, color: AppColors.textLight)),
                                ],
                              )
                            : Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(12.r),
                                    decoration: BoxDecoration(
                                      color: AppColors.teacherPrimary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12.r),
                                    ),
                                    child: Icon(Icons.description_rounded, color: AppColors.teacherPrimary, size: 26.sp),
                                  ),
                                  SizedBox(width: 16.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text('FILE ATTACHED', style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w800, color: AppColors.teacherPrimary, letterSpacing: 0.5)),
                                            SizedBox(width: 6.w),
                                            Icon(Icons.check_circle_rounded, color: AppColors.teacherPrimary, size: 12.sp),
                                          ],
                                        ),
                                        SizedBox(height: 2.h),
                                        Text(_attachedFile!.name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textDark, fontSize: 14.sp), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        Text('${(_attachedFile!.size / 1024 / 1024).toStringAsFixed(2)} MB', style: GoogleFonts.inter(fontSize: 11.sp, color: AppColors.textLight)),
                                      ],
                                    ),
                                  ),
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => setState(() => _attachedFile = null),
                                      borderRadius: BorderRadius.circular(20.r),
                                      child: Container(
                                        padding: EdgeInsets.all(8.r),
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent.withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.close_rounded, color: Colors.redAccent, size: 20.sp),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                        ),
                      ),
                      SizedBox(height: 16.r),
                      _label('Assign To'),
                      SizedBox(height: 6.h),
                      GestureDetector(
                        onTap: () => _showTargetSelection(context),
                        child: Container(
                          padding: EdgeInsets.all(16.r),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.r), border: Border.all(color: AppColors.border)),
                          child: Row(children: [
                            Icon(Icons.people_rounded, color: AppColors.teacherPrimary, size: 20.sp),
                            SizedBox(width: 12.w),
                            Expanded(child: Text(_targetText, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textDark))),
                            Icon(_isTargetSelected ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded, color: AppColors.teacherPrimary, size: 20.sp),
                          ]),
                        ),
                      ),
                      SizedBox(height: 24.h),
                      LoadingButton(
                        label: _isSubmitting ? 'Publishing...' : 'Publish Assignment',
                        color: AppColors.teacherPrimary,
                        onPressed: () async {
                          if (_isSubmitting) return;
                          if (!_isTargetSelected) {
                            showToast(context, 'Please select a class & section');
                            return;
                          }
                          if (_titleCtrl.text.trim().isEmpty) {
                            showToast(context, 'Please enter an assignment title');
                            return;
                          }

                          setState(() { _isSubmitting = true; });

                          try {
                            final dbClass = _getDbClassName(_selectedClass!);
                            final selectedDue = _dueDate ?? DateTime.now().add(const Duration(days: 1));
                            final formattedDue = intl.DateFormat('yyyy-MM-dd').format(selectedDue);

                            // Save assignment record into Supabase for each selected section
                            for (var sec in _selectedSections) {
                              await Supabase.instance.client
                                  .from('assignments')
                                  .insert({
                                    'title': _titleCtrl.text.trim(),
                                    'subject': _subject,
                                    'description': _descCtrl.text.trim(),
                                    'due_date': formattedDue,
                                    'class_name': dbClass,
                                    'section': sec,
                                  });
                            }

                            if (context.mounted) {
                              showToast(context, 'Assignment published successfully!');
                            }
                            if (context.mounted) setState(() => _published = true);
                          } catch (e) {
                            if (context.mounted) {
                              showToast(context, 'Error publishing assignment: $e');
                            }
                          } finally {
                            if (mounted) setState(() { _isSubmitting = false; });
                          }
                        },
                      ),
                      SizedBox(height: 80.h),
                    ],
                  ),
                ),

                // Tab 2: Approve Submissions List
                _buildSubmissionsTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmissionsTab(BuildContext context) {
    if (_isLoadingSubmissions) {
      return const Center(child: CircularProgressIndicator(color: AppColors.teacherPrimary));
    }
    
    if (_submissionsList.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.r),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(24.r),
                decoration: BoxDecoration(color: AppColors.teacherPrimary.withValues(alpha: 0.05), shape: BoxShape.circle),
                child: Icon(Icons.description_outlined, color: AppColors.teacherPrimary, size: 50.sp),
              ),
              SizedBox(height: 16.h),
              Text('No submissions found', style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.w900, color: AppColors.textDark)),
              SizedBox(height: 6.h),
              Text('When students upload assignments, they will appear here.', style: GoogleFonts.inter(fontSize: 12.sp, color: AppColors.textMedium), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: () => _loadSubmissionsData(showLoading: true),
      color: AppColors.teacherPrimary,
      child: ListView.builder(
        padding: EdgeInsets.all(16.r),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _submissionsList.length,
        itemBuilder: (ctx, i) {
          final sub = _submissionsList[i];
          final hasGrade = sub['grade'] != 'Pending';
          
          DateTime? subDate;
          if (sub['submitted_at'] != null) {
            try {
              subDate = DateTime.parse(sub['submitted_at']).toLocal();
            } catch (_) {}
          }
          
          final formattedDate = subDate != null 
              ? intl.DateFormat('MMM d, h:mm a').format(subDate)
              : 'Recent';

          return Container(
            margin: EdgeInsets.only(bottom: 14.h),
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: AppColors.border),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: AppColors.teacherPrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        sub['assignment_subject'],
                        style: GoogleFonts.inter(
                          fontSize: 10.sp, 
                          fontWeight: FontWeight.w800, 
                          color: AppColors.teacherPrimary,
                        ),
                      ),
                    ),
                    Text(
                      formattedDate,
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                Text(
                  sub['assignment_title'],
                  style: GoogleFonts.inter(
                    fontSize: 15.sp, 
                    fontWeight: FontWeight.w900, 
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 6.h),
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded, color: AppColors.textLight, size: 16.sp),
                    SizedBox(width: 6.w),
                    Text(
                      'Submitted by: ',
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        color: AppColors.textMedium,
                      ),
                    ),
                    Text(
                      sub['student_name'],
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
                if (sub['file_name'] != null) ...[
                  SizedBox(height: 10.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(color: AppColors.border, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.attach_file_rounded, color: AppColors.teacherPrimary, size: 16.sp),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            sub['file_name'],
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              color: AppColors.textDark,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: 16.h),
                const Divider(height: 1, color: AppColors.border),
                SizedBox(height: 12.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          hasGrade ? Icons.check_circle_rounded : Icons.pending_rounded,
                          color: hasGrade ? const Color(0xFF10B981) : Colors.orange,
                          size: 18.sp,
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          hasGrade 
                            ? 'Score: ${sub['score']} (${sub['grade']})' 
                            : 'Evaluation Pending',
                          style: GoogleFonts.inter(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w800,
                            color: hasGrade ? const Color(0xFF10B981) : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasGrade ? Colors.grey.shade100 : AppColors.teacherPrimary,
                        foregroundColor: hasGrade ? AppColors.textDark : Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          side: hasGrade ? const BorderSide(color: AppColors.border) : BorderSide.none,
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                      ),
                      icon: Icon(
                        hasGrade ? Icons.edit_note_rounded : Icons.gavel_rounded,
                        size: 16.sp,
                      ),
                      label: Text(
                        hasGrade ? 'Re-evaluate' : 'Grade & Approve',
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onPressed: () => _showEvaluationDialog(context, sub),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
          title: Text('Evaluate Submission', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppColors.textDark)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Student: ${sub['student_name']}', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textMedium)),
              SizedBox(height: 4.h),
              Text('Assignment: ${sub['assignment_title']}', style: GoogleFonts.inter(color: AppColors.textLight, fontSize: 12.sp)),
              SizedBox(height: 16.h),
              _dialogLabel('SELECT GRADE'),
              SizedBox(height: 8.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedGrade,
                    isExpanded: true,
                    items: gradesList.map((g) => DropdownMenuItem(
                      value: g,
                      child: Text(g, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textDark)),
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
              _dialogLabel('ENTER SCORE (e.g. 95/100)'),
              SizedBox(height: 8.h),
              TextField(
                controller: scoreCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. 92/100',
                  hintStyle: GoogleFonts.inter(color: AppColors.textLight),
                  contentPadding: EdgeInsets.all(12.r),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: AppColors.teacherPrimary)),
                ),
              ),
            ],
          ),
          actionsPadding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textMedium)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.teacherPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
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
                  _loadSubmissionsData(showLoading: false);
                } catch (e) {
                  if (context.mounted) {
                    showToast(context, 'Error saving grade: $e');
                  }
                }
              },
              child: Text('Submit Grade', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogLabel(String text) => Text(text, style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w800, color: AppColors.textLight, letterSpacing: 0.5));

  void _showTargetSelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.all(24.r),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32.r))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Select Target', style: GoogleFonts.inter(fontSize: 18.sp, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ]),
              SizedBox(height: 20.h),
              Text('CHOOSE CLASS', style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w700, color: AppColors.textLight, letterSpacing: 1)),
              SizedBox(height: 12.h),
              Wrap(
                spacing: 10, runSpacing: 10,
                children: List.generate(12, (i) {
                  final suffix = i == 0 ? 'st' : i == 1 ? 'nd' : i == 2 ? 'rd' : 'th';
                  final name = '${i + 1}$suffix';
                  final isSelected = _selectedClass == name;
                  return GestureDetector(
                    onTap: () => setModalState(() => setState(() => _selectedClass = name)),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.teacherPrimary : AppColors.background,
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(color: isSelected ? AppColors.teacherPrimary : AppColors.border),
                      ),
                      child: Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: isSelected ? Colors.white : AppColors.textMedium)),
                    ),
                  );
                }),
              ),
              SizedBox(height: 24.h),
              Text('CHOOSE SECTION (MULTIPLE)', style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w700, color: AppColors.textLight, letterSpacing: 1)),
              SizedBox(height: 12.h),
              Row(
                children: ['A', 'B', 'C', 'D'].map((s) {
                  final isSelected = _selectedSections.contains(s);
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setModalState(() => setState(() {
                        if (isSelected) {
                          _selectedSections.remove(s);
                        } else {
                          _selectedSections.add(s);
                        }
                      })),
                      child: Container(
                        margin: EdgeInsets.only(right: s != 'D' ? 10 : 0),
                        height: 45.h,
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.teacherPrimary : AppColors.background,
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(color: isSelected ? AppColors.teacherPrimary : AppColors.border),
                        ),
                        child: Center(child: Text(s, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: isSelected ? Colors.white : AppColors.textMedium))),
                      ),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: 32.h),
              LoadingButton(
                label: 'Confirm Selection',
                color: AppColors.teacherPrimary,
                onPressed: () async {
                  if (_isTargetSelected) Navigator.pop(context);
                },
              ),
              SizedBox(height: 12.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Text(t.toUpperCase(), style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w700, color: AppColors.textLight, letterSpacing: 0.8));

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint, hintStyle: GoogleFonts.inter(color: AppColors.textLight),
    filled: true, fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r), borderSide: const BorderSide(color: AppColors.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r), borderSide: const BorderSide(color: AppColors.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r), borderSide: BorderSide(color: AppColors.teacherPrimary, width: 2.w)),
    contentPadding: EdgeInsets.all(16.r),
  );

  Widget _buildSuccess(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: Center(
      child: Padding(
        padding: EdgeInsets.all(32.r),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 100.w, height: 100.h, decoration: const BoxDecoration(color: AppColors.studentLight, shape: BoxShape.circle),
            child: Icon(Icons.check_circle_rounded, color: AppColors.studentPrimary, size: 50.sp)),
          SizedBox(height: 24.h),
          Text('Assignment Published!', style: GoogleFonts.inter(fontSize: 24.sp, fontWeight: FontWeight.w900, color: AppColors.textDark)),
          SizedBox(height: 8.h),
          Text('Sent successfully to $_targetText', style: GoogleFonts.inter(fontSize: 14.sp, color: AppColors.textMedium)),
          SizedBox(height: 32.h),
          LoadingButton(label: 'Back to Dashboard', color: AppColors.teacherPrimary, onPressed: () async { Navigator.pop(context); }),
        ]),
      ),
    ),
  );
}
