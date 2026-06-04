import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart' as intl;
import 'package:file_picker/file_picker.dart';
import '../../theme/colors.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Assignment Management Screen — matches the 2nd image design
// ══════════════════════════════════════════════════════════════════════════════
class AssignmentsScreen extends StatefulWidget {
  const AssignmentsScreen({super.key});

  @override
  State<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends State<AssignmentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── Form Controllers ──
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _marksCtrl = TextEditingController();
class _AssignmentsScreenState extends State<AssignmentsScreen> {
  bool _isLoading = true;

  // ── Form State ──
  String? _selectedSubject;
  String? _selectedClass;
  String _selectedSection = 'All Sections';
  String _assignmentType = 'Homework'; // Homework, Project, Quiz, Other
  DateTime _startDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  String? _selectedSubmissionType = 'File Upload';
  bool _allowLateSubmission = true;
  PlatformFile? _attachedFile;
  bool _isSubmitting = false;

  // ── Dropdown Options ──
  final List<String> _subjects = ['Physics', 'Maths', 'Chemistry', 'English', 'CS'];
  final List<String> _classes = [
    'Class 1', 'Class 2', 'Class 3', 'Class 4', 'Class 5',
    'Class 6', 'Class 7', 'Class 8', 'Class 9', 'Class 10'
  ];
  final List<String> _sections = ['All Sections', 'Section A', 'Section B', 'Section C'];
  final List<String> _submissionTypes = ['File Upload', 'Text Entry', 'URL Submission'];
  final List<Map<String, dynamic>> _assignments = [];

  // ── Submissions Tab State ──
  bool _isLoadingSubmissions = true;
  final List<Map<String, dynamic>> _submissionsList = [];
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSubmissionsData();
    _loadAssignmentsData();
    _connectRealTime();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _marksCtrl.dispose();
    _tabController.dispose();
    _assignmentsPollTimer?.cancel();
    if (_assignmentsChannel != null) {
      try {
        Supabase.instance.client.removeChannel(_assignmentsChannel!);
      } catch (_) {}
    }
    super.dispose();
  }

  // ═════════════════════════════════════════════════════════════════════════
  // DATABASE INTERACTIONS
  // ═════════════════════════════════════════════════════════════════════════

  Future<void> _loadSubmissionsData({bool showLoading = true}) async {
    if (!mounted) return;
    if (showLoading) {
      setState(() {
        _isLoadingSubmissions = true;
      });
    }
    try {
      final List<dynamic> submissionsRes = await _supabase
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
      dev.log('⚠️ Error loading submissions: $e', name: 'AssignmentsScreen');
      if (mounted) {
        setState(() {
          _isLoadingSubmissions = false;
        });
      }
    }
  }

  Future<void> _submitAssignmentForm(bool isDraft) async {
    if (_titleCtrl.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter an assignment title');
      return;
    }
    if (_selectedSubject == null) {
      _showErrorSnackBar('Please select a subject');
      return;
    }
    if (_selectedClass == null) {
      _showErrorSnackBar('Please select a class');
      return;
    }
    if (_descCtrl.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter assignment description');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Format final description by combining extra settings
      final formattedDesc = StringBuffer()
        ..writeln(_descCtrl.text.trim())
        ..writeln()
        ..writeln('--------------------------------')
        ..writeln('📋 Type: $_assignmentType')
        ..writeln('📅 Start Date: ${intl.DateFormat('dd-MM-yyyy').format(_startDate)}')
        ..writeln('💯 Total Marks: ${_marksCtrl.text.isEmpty ? "100" : _marksCtrl.text}')
        ..writeln('📥 Submission: $_selectedSubmissionType')
        ..writeln('⏰ Allow Late: ${_allowLateSubmission ? "Yes" : "No"}');

      if (_attachedFile != null) {
        formattedDesc.writeln('📎 Attachment: ${_attachedFile!.name}');
      }

      final dueDateStr = intl.DateFormat('yyyy-MM-dd').format(_dueDate);
      final dbClass = _selectedClass!;
      final sec = _selectedSection == 'All Sections' ? 'A' : _selectedSection.replaceAll('Section ', '');

      await _supabase.from('assignments').insert({
        'title': _titleCtrl.text.trim(),
        'subject': _selectedSubject,
        'description': formattedDesc.toString(),
        'due_date': dueDateStr,
        'class_name': dbClass,
        'section': sec,
      });
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  isDraft
                      ? 'Assignment saved as draft successfully!'
                      : 'Assignment created and published successfully!',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        _clearForm();
        _tabController.animateTo(1);
        _loadSubmissionsData();
      }
    } catch (e) {
      _showErrorSnackBar('Error: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _clearForm() {
    _titleCtrl.clear();
    _descCtrl.clear();
    _marksCtrl.clear();
    setState(() {
      _selectedSubject = null;
      _selectedClass = null;
      _selectedSection = 'All Sections';
      _assignmentType = 'Homework';
      _startDate = DateTime.now();
      _dueDate = DateTime.now().add(const Duration(days: 7));
      _selectedSubmissionType = 'File Upload';
      _allowLateSubmission = true;
      _attachedFile = null;
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _pickDate(bool isStartDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _dueDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2028),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.teacherPrimary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textDark,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _dueDate = picked;
        }
      });
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'zip'],
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() => _attachedFile = result.files.first);
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
      _showErrorSnackBar('Error picking file: $e');
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // BUILD SCREEN
  // ═════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabSwitcher(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildCreateAssignmentTab(),
                  _buildSubmissionsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── HEADER ──
  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
            onPressed: () => Navigator.pop(context),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assignment Management',
                  style: GoogleFonts.outfit(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Create and grade student assignments',
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          // Bell Icon with notification badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF0F172A), size: 26),
                onPressed: () {},
              ),
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E3A8A),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '3',
                    style: GoogleFonts.inter(
                      fontSize: 8.sp,
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── TAB SWITCHER ──
  Widget _buildTabSwitcher() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(bottom: 8.h),
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.teacherPrimary,
        unselectedLabelColor: const Color(0xFF64748B),
        indicatorColor: AppColors.teacherPrimary,
        indicatorWeight: 3,
        labelStyle: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w500),
        tabs: const [
          Tab(text: 'Create Assignment'),
          Tab(text: 'Submissions'),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // CREATE ASSIGNMENT TAB
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildCreateAssignmentTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.r),
      child: Column(
        children: [
          // Sub-header / Cancel button row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(6.r),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: const Icon(Icons.note_add_rounded, color: Color(0xFF2563EB), size: 20),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'Create New Assignment',
                    style: GoogleFonts.outfit(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: _clearForm,
                icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF2563EB)),
                label: Text(
                  'Cancel',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2563EB),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // Card 1: Assignment Details
          _buildDetailsCard(),
          SizedBox(height: 16.h),

          // Card 2: Assignment Settings
          _buildSettingsCard(),
          SizedBox(height: 16.h),

          // Card 3: Attachments
          _buildAttachmentsCard(),
          SizedBox(height: 24.h),

          // Bottom Bar Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : () => _submitAssignmentForm(true),
                  icon: const Icon(Icons.drafts_outlined, size: 18, color: Color(0xFF475569)),
                  label: Text(
                    'Save as Draft',
                    style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF475569),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : () => _submitAssignmentForm(false),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                  label: Text(
                    'Create Assignment',
                    style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0066cc),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 40.h),
        ],
      ),
    );
  }

  // ── DETAILS CARD ──
  Widget _buildDetailsCard() {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_outlined, color: Color(0xFF2563EB), size: 18),
              SizedBox(width: 8.w),
              Text(
                'Assignment Details',
                style: GoogleFonts.outfit(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // Title field
          _buildFieldLabel('Assignment Title *'),
          SizedBox(height: 6.h),
          TextField(
            controller: _titleCtrl,
            decoration: _inputDecoration('Enter assignment title'),
          ),
          SizedBox(height: 16.h),

          // Subject dropdown
          _buildFieldLabel('Subject *'),
          SizedBox(height: 6.h),
          _buildDropdownField(
            value: _selectedSubject,
            hint: 'Select subject',
            items: _subjects,
            onChanged: (val) => setState(() => _selectedSubject = val),
          ),
          SizedBox(height: 16.h),

          // Class / Section row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Class *'),
                    SizedBox(height: 6.h),
                    _buildDropdownField(
                      value: _selectedClass,
                      hint: 'Select class',
                      items: _classes,
                      onChanged: (val) => setState(() => _selectedClass = val),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Section (Optional)'),
                    SizedBox(height: 6.h),
                    _buildDropdownField(
                      value: _selectedSection,
                      items: _sections,
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedSection = val);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // Description field
          _buildFieldLabel('Description *'),
          SizedBox(height: 6.h),
          TextField(
            controller: _descCtrl,
            maxLines: 4,
            maxLength: 1000,
            decoration: _inputDecoration('Enter assignment description and instructions...'),
            buildCounter: (context, {required currentLength, required isFocused, maxLength}) {
              return Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  '$currentLength / $maxLength',
                  style: GoogleFonts.inter(fontSize: 10.sp, color: const Color(0xFF94A3B8)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── SETTINGS CARD ──
  Widget _buildSettingsCard() {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.settings_outlined, color: Color(0xFF2563EB), size: 18),
              SizedBox(width: 8.w),
              Text(
                'Assignment Settings',
                style: GoogleFonts.outfit(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // Assignment type radio buttons
          _buildFieldLabel('Assignment Type'),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 8.w,
            children: ['Homework', 'Project', 'Quiz', 'Other'].map((type) {
              final isSelected = _assignmentType == type;
              return GestureDetector(
                onTap: () => setState(() => _assignmentType = type),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Radio<String>(
                      value: type,
                      // ignore: deprecated_member_use
                      groupValue: _assignmentType,
                      // ignore: deprecated_member_use
                      activeColor: const Color(0xFF2563EB),
                      // ignore: deprecated_member_use
                      onChanged: (val) {
                        if (val != null) setState(() => _assignmentType = val);
                      },
                    ),
                    Text(
                      type,
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 16.h),

          // Start Date / Due Date row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Start Date *'),
                    SizedBox(height: 6.h),
                    InkWell(
                      onTap: () => _pickDate(true),
                      borderRadius: BorderRadius.circular(10.r),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF94A3B8)),
                            SizedBox(width: 8.w),
                            Text(
                              intl.DateFormat('dd/MM/yyyy').format(_startDate),
                              style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Due Date *'),
                    SizedBox(height: 6.h),
                    InkWell(
                      onTap: () => _pickDate(false),
                      borderRadius: BorderRadius.circular(10.r),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF94A3B8)),
                            SizedBox(width: 8.w),
                            Text(
                              intl.DateFormat('dd/MM/yyyy').format(_dueDate),
                              style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // Marks and Submission Type row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Total Marks *'),
                    SizedBox(height: 6.h),
                    TextField(
                      controller: _marksCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Enter total marks',
                        prefixIcon: const Icon(Icons.military_tech_outlined, color: Color(0xFF94A3B8)),
                        hintStyle: GoogleFonts.inter(fontSize: 13.sp, color: const Color(0xFF94A3B8)),
                        contentPadding: EdgeInsets.all(12.r),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                          borderSide: const BorderSide(color: Color(0xFF2563EB)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Submission Type'),
                    SizedBox(height: 6.h),
                    _buildDropdownField(
                      value: _selectedSubmissionType,
                      items: _submissionTypes,
                      onChanged: (val) => setState(() => _selectedSubmissionType = val),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // Switch: Allow Late Submission
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Allow Late Submission',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Accept submissions after due date',
                    style: GoogleFonts.inter(
                      fontSize: 10.sp,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              Switch(
                value: _allowLateSubmission,
                // ignore: deprecated_member_use
                activeColor: const Color(0xFF2563EB),
                onChanged: (val) => setState(() => _allowLateSubmission = val),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── ATTACHMENTS CARD ──
  Widget _buildAttachmentsCard() {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.attach_file_rounded, color: Color(0xFF2563EB), size: 18),
              SizedBox(width: 8.w),
              Text(
                'Attachments (Optional)',
                style: GoogleFonts.outfit(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // Dashed drag box
          GestureDetector(
            onTap: _pickFile,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(20.r),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: _attachedFile != null ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                  style: BorderStyle.solid, // dashed border alternative
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  const Icon(Icons.cloud_upload_outlined, size: 36, color: Color(0xFF94A3B8)),
                  SizedBox(height: 10.h),
                  Text(
                    _attachedFile == null
                        ? 'Drag & drop files here or click to browse'
                        : _attachedFile!.name,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF334155),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Supported files: PDF, DOC, DOCX, PPT, PPTX, ZIP (Max 20MB)',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 10.sp,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  ElevatedButton(
                    onPressed: _pickFile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF2563EB),
                      elevation: 0,
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                    ),
                    child: Text(
                      'Browse Files',
                      style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── HELPER WIDGETS ──
  Widget _buildFieldLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 12.sp,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF475569),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(fontSize: 13.sp, color: const Color(0xFF94A3B8)),
      contentPadding: EdgeInsets.all(12.r),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: const BorderSide(color: Color(0xFF2563EB)),
      ),
    );
  }

  Widget _buildDropdownField({
    required String? value,
    String? hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: hint != null
              ? Text(
                  hint,
                  style: GoogleFonts.inter(fontSize: 13.sp, color: const Color(0xFF94A3B8)),
                )
              : null,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF94A3B8)),
          style: GoogleFonts.inter(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
          items: items.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // SUBMISSIONS TAB
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildSubmissionsTab() {
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
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.description_outlined, color: Color(0xFF2563EB), size: 48),
              ),
              SizedBox(height: 16.h),
              Text(
                'No submissions found',
                style: GoogleFonts.inter(fontSize: 15.sp, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
              ),
              SizedBox(height: 4.h),
              Text(
                'When students submit files, they will appear here.',
                style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF94A3B8)),
              ),
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
            margin: EdgeInsets.only(bottom: 12.h),
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        sub['assignment_subject'],
                        style: GoogleFonts.inter(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                    ),
                    Text(
                      formattedDate,
                      style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                Text(
                  sub['assignment_title'],
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, color: Color(0xFF94A3B8), size: 14),
                    SizedBox(width: 4.w),
                    Text(
                      'Student: ${sub['student_name']}',
                      style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF475569)),
                    ),
                  ],
                ),
                if (sub['file_name'] != null) ...[
                  SizedBox(height: 10.h),
                  Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.attach_file_rounded, color: Color(0xFF2563EB), size: 14),
                        SizedBox(width: 6.w),
                        Expanded(
                          child: Text(
                            sub['file_name'],
                            style: GoogleFonts.inter(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: 12.h),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                SizedBox(height: 10.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          hasGrade ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                          color: hasGrade ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                          size: 16.sp,
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          hasGrade
                              ? 'Score: ${sub['score']} (${sub['grade']})'
                              : 'Pending Grade',
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w800,
                            color: hasGrade ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
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
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasGrade ? const Color(0xFFF1F5F9) : const Color(0xFF0066cc),
                        foregroundColor: hasGrade ? const Color(0xFF475569) : Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                      ),
                      icon: Icon(
                        hasGrade ? Icons.edit_note_rounded : Icons.rate_review_rounded,
                        size: 14.sp,
                      ),
                      label: Text(
                        hasGrade ? 'Change Grade' : 'Grade',
                        style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w800),
                      ),
                      onPressed: () => _showEvaluationDialog(sub),
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

  void _showEvaluationDialog(Map<String, dynamic> sub) {
    final scoreCtrl = TextEditingController(text: sub['score'] == 'Not Graded' ? '' : sub['score']);
    String selectedGrade = sub['grade'] == 'Pending' ? 'A' : sub['grade'];
    final grades = ['A+', 'A', 'B+', 'B', 'C', 'D', 'F'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          title: Text(
            'Grade Submission',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Student: ${sub['student_name']}',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: const Color(0xFF475569)),
              ),
              SizedBox(height: 12.h),
              _dialogLabel('SELECT GRADE'),
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
                    items: grades.map((g) {
                      return DropdownMenuItem(value: g, child: Text(g));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedGrade = val);
                      }
                    },
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              _dialogLabel('ENTER SCORE (e.g., 90/100)'),
              SizedBox(height: 6.h),
              TextField(
                controller: scoreCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. 95/100',
                  hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
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
                    borderSide: const BorderSide(color: Color(0xFF2563EB)),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0066cc),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              ),
              onPressed: () async {
                final scoreVal = scoreCtrl.text.trim().isEmpty ? 'Not Graded' : scoreCtrl.text.trim();
                Navigator.pop(ctx);

                final messenger = ScaffoldMessenger.of(context);
                try {
                  await _supabase.from('submissions').update({
                    'grade': selectedGrade,
                    'score': scoreVal,
                  }).eq('id', sub['id']);

                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Grade submitted successfully!',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        backgroundColor: const Color(0xFF10B981),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                  _loadSubmissionsData(showLoading: false);
                } catch (e) {
                  _showErrorSnackBar('Error submitting grade: $e');
                }
              },
              child: Text(
                'Submit',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 10.sp,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF64748B),
        letterSpacing: 0.5,
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
