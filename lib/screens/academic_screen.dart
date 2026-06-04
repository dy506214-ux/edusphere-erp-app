import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart' as intl;
import '../theme/colors.dart';
import 'features/exam_schedule_screen.dart';
import 'features/exam_terms_screen.dart';
import 'features/exam_report_card_screen.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Academic Management Screen — supports Classes, Subjects, Sections, and Exams
// ══════════════════════════════════════════════════════════════════════════════
class AcademicScreen extends StatefulWidget {
  final RoleTheme theme;
  final VoidCallback? onBack;

  const AcademicScreen({
    super.key,
    required this.theme,
    this.onBack,
  });

  @override
  State<AcademicScreen> createState() => _AcademicScreenState();
}

class _AcademicScreenState extends State<AcademicScreen> {

  int _activeTab = 0; // 0 = Classes, 1 = Subjects, 2 = Sections, 3 = Exams & Results

  // ── Database Lists ──
  List<Map<String, dynamic>> _classesList = [];
  List<Map<String, dynamic>> _subjectsList = [];
  List<Map<String, dynamic>> _sectionsList = [];

  @override
  void initState() {
    super.initState();
    _loadLocalData();
  }

  // ═════════════════════════════════════════════════════════════════════════
  // LOCAL DATA PERSISTENCE
  // ═════════════════════════════════════════════════════════════════════════
  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() { _isLoading = true; });

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      studentName = prefs.getString('student_name') ??
          prefs.getString('user_name') ??
          'Student';
    });

  Future<void> _loadLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final classesJson = prefs.getString('academic_classes_list');
      if (classesJson != null) {
        _classesList = List<Map<String, dynamic>>.from(json.decode(classesJson));
      }
      
      final subjectsJson = prefs.getString('academic_subjects_list');
      if (subjectsJson != null) {
        _subjectsList = List<Map<String, dynamic>>.from(json.decode(subjectsJson));
      }

      final sectionsJson = prefs.getString('academic_sections_list');
      if (sectionsJson != null) {
        _sectionsList = List<Map<String, dynamic>>.from(json.decode(sectionsJson));
      }

      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _saveLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('academic_classes_list', json.encode(_classesList));
      await prefs.setString('academic_subjects_list', json.encode(_subjectsList));
      await prefs.setString('academic_sections_list', json.encode(_sectionsList));
    } catch (_) {}
  }

  // ═════════════════════════════════════════════════════════════════════════
  // DIALOGS TO CREATE ITEMS
  // ═════════════════════════════════════════════════════════════════════════

  void _showAddClassDialog() {
    final nameCtrl = TextEditingController();
    final levelCtrl = TextEditingController();
    final yearCtrl = TextEditingController(text: '2026-2027');
    final teacherCtrl = TextEditingController();
    final studentsCtrl = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text('Create Class', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogField(nameCtrl, 'Class Name', 'e.g. Class 10 - A'),
              SizedBox(height: 12.h),
              _buildDialogField(levelCtrl, 'Level', 'e.g. Secondary'),
              SizedBox(height: 12.h),
              _buildDialogField(yearCtrl, 'Academic Year', 'e.g. 2026-2027'),
              SizedBox(height: 12.h),
              _buildDialogField(teacherCtrl, 'Class Teacher', 'e.g. Mr. John Doe'),
              SizedBox(height: 12.h),
              _buildDialogField(studentsCtrl, 'Students Count', 'e.g. 40', keyboardType: TextInputType.number),
            ],
          ),
      final savedEmail = prefs.getString('student_email') ??
          prefs.getString('user_email') ??
          'alex.rivera@edusmart.edu';

      final studentRes = await Supabase.instance.client
          .from('students')
          .select()
          .eq('email', savedEmail)
          .maybeSingle();

      if (studentRes != null) {
        final studentId = studentRes['id'] as String;
        final className = studentRes['class_name'] as String? ?? 'Grade 12';
        final section = studentRes['section'] as String? ?? 'A';

        if (mounted) {
          setState(() {
            _className = className;
            _section = section;
          });
        }

        // Attendance rate
        final attendanceRes = await Supabase.instance.client
            .from('attendance')
            .select()
            .eq('student_id', studentId);

        double rate = 0.0;
        if (attendanceRes.isNotEmpty) {
          int present = 0;
          for (var r in attendanceRes) {
            final s = r['status'] as String? ?? '';
            if (s == 'P' || s == 'Present' || s == 'L' || s == 'Late' || s == 'Leave') {
              present++;
            }
          }
          rate = (present / attendanceRes.length) * 100;
        }

        // Fetch recent attendance records for Attendance History
        final List<dynamic> attendanceHistoryRes = await Supabase.instance.client
            .from('attendance')
            .select()
            .eq('student_id', studentId)
            .order('date', ascending: false)
            .limit(5);

        final List<Map<String, dynamic>> tempHistory = [];
        for (var att in attendanceHistoryRes) {
          final rawDate = att['date'] as String;
          final status = att['status'] as String? ?? 'Present';
          
          DateTime? date;
          try {
            date = DateTime.parse(rawDate);
          } catch (_) {}

          String formattedDate = rawDate;
          if (date != null) {
            formattedDate = intl.DateFormat('MMMM d, yyyy').format(date);
          }

          tempHistory.add({
            'date': formattedDate,
            'status': status,
          });
        }

        if (mounted) {
          setState(() {
            attendanceRate = rate;
            _attendanceHistory.clear();
            _attendanceHistory.addAll(tempHistory);
          });
        }
      }
    } catch (e) {
      dev.log('Error loading academic data: $e');
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Custom clean header matching React Client style
            Padding(
              padding: EdgeInsets.fromLTRB(24.r, 24.r, 24.r, 8.r),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (canPop || widget.onBack != null) ...[
                        GestureDetector(
                          onTap: () {
                            if (canPop) {
                              Navigator.pop(context);
                            } else if (widget.onBack != null) {
                              widget.onBack!();
                            }
                          },
                          child: Container(
                            width: 40.w,
                            height: 40.w,
                            margin: EdgeInsets.only(right: 12.w),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Icon(Icons.arrow_back_ios_new_rounded,
                                size: 18.sp, color: AppColors.textDark),
                          ),
                        ),
                      ],
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Academic Overview',
                            style: GoogleFonts.inter(
                              fontSize: 26.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'Manage your academic journey',
                            style: GoogleFonts.inter(
                              fontSize: 14.sp,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  _buildRefreshButton(),
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.studentPrimary))
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      color: widget.theme.primary,
                      child: ListView(
                        padding: EdgeInsets.all(24.r),
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          if (isDesktop) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: _buildCurrentSubjectsCard(),
                                ),
                                SizedBox(width: 24.w),
                                Expanded(
                                  flex: 2,
                                  child: _buildTimetablesCard(),
                                ),
                              ],
                            ),
                          ] else ...[
                            _buildCurrentSubjectsCard(),
                            SizedBox(height: 24.h),
                            _buildTimetablesCard(),
                          ],
                          SizedBox(height: 24.h),
                          _buildAcademicStatusCard(),
                          SizedBox(height: 24.h),
                          _buildAttendanceHistoryCard(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: widget.theme.primary),
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              setState(() {
                _classesList.add({
                  'name': nameCtrl.text.trim(),
                  'level': levelCtrl.text.trim(),
                  'academic_year': yearCtrl.text.trim(),
                  'class_teacher': teacherCtrl.text.trim(),
                  'students': int.tryParse(studentsCtrl.text.trim()) ?? 0,
                });
              });
              _saveLocalData();
              Navigator.pop(ctx);
            },
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddSubjectDialog() {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final classCtrl = TextEditingController();
    final teacherCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text('Create Subject', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogField(nameCtrl, 'Subject Name', 'e.g. Physics'),
              SizedBox(height: 12.h),
              _buildDialogField(codeCtrl, 'Subject Code', 'e.g. PHY101'),
              SizedBox(height: 12.h),
              _buildDialogField(classCtrl, 'Class/Grade', 'e.g. Class 10'),
              SizedBox(height: 12.h),
              _buildDialogField(teacherCtrl, 'Subject Teacher', 'e.g. Dr. Emily Green'),
              SizedBox(height: 12.h),
              _buildDialogField(descCtrl, 'Description', 'e.g. Intro to Mechanics'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: widget.theme.primary),
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              setState(() {
                _subjectsList.add({
                  'name': nameCtrl.text.trim(),
                  'code': codeCtrl.text.trim(),
                  'class': classCtrl.text.trim(),
                  'teacher': teacherCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                });
              });
              _saveLocalData();
              Navigator.pop(ctx);
            },
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddSectionDialog() {
    final nameCtrl = TextEditingController();
    final classCtrl = TextEditingController();
    final maxCtrl = TextEditingController(text: '40');
    final studentsCtrl = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text('Create Section', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogField(nameCtrl, 'Section Name', 'e.g. Section A'),
              SizedBox(height: 12.h),
              _buildDialogField(classCtrl, 'Class', 'e.g. Class 10'),
              SizedBox(height: 12.h),
              _buildDialogField(maxCtrl, 'Max Students', 'e.g. 40', keyboardType: TextInputType.number),
              SizedBox(height: 12.h),
              _buildDialogField(studentsCtrl, 'Current Students', 'e.g. 35', keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: widget.theme.primary),
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              setState(() {
                _sectionsList.add({
                  'name': nameCtrl.text.trim(),
                  'class': classCtrl.text.trim(),
                  'max_students': int.tryParse(maxCtrl.text.trim()) ?? 40,
                  'students': int.tryParse(studentsCtrl.text.trim()) ?? 0,
                });
              });
              _saveLocalData();
              Navigator.pop(ctx);
            },
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogField(
    TextEditingController ctrl,
    String label,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.inter(fontSize: 12.sp),
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // BUILD METHODS
  // ═════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabs(),
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                child: _buildActiveTabContent(),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _activeTab < 3
          ? FloatingActionButton(
              onPressed: _activeTab == 0
                  ? _showAddClassDialog
                  : _activeTab == 1
                      ? _showAddSubjectDialog
                      : _showAddSectionDialog,
              backgroundColor: widget.theme.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
            onPressed: widget.onBack ?? () => Navigator.pop(context),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Academic Management',
                  style: GoogleFonts.outfit(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Manage classes, subjects, and sections',
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF0F172A)),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        child: Row(
          children: [
            _buildTabSelector(0, 'Classes'),
            SizedBox(width: 6.w),
            _buildTabSelector(1, 'Subjects'),
            SizedBox(width: 6.w),
            _buildTabSelector(2, 'Sections'),
            SizedBox(width: 6.w),
            _buildTabSelector(3, 'Exams & Results'),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector(int index, String label) {
    final isSelected = _activeTab == index;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = index),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isSelected ? const Color(0xFFBFDBFE) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          style: GoogleFonts.inter(
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTabContent() {
    switch (_activeTab) {
      case 0:
        return _buildClassesTab();
      case 1:
        return _buildSubjectsTab();
      case 2:
        return _buildSectionsTab();
      case 3:
        return _buildExamsTab();
      default:
        return const SizedBox.shrink();
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // CLASSES TAB
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildClassesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Classes', style: GoogleFonts.outfit(fontSize: 16.sp, fontWeight: FontWeight.w800)),
        Text('Manage class/grade levels', style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF64748B))),
        SizedBox(height: 16.h),
        _classesList.isEmpty
            ? _buildEmptyState('No classes found. Create one to get started.', _showAddClassDialog)
            : _buildClassesTable(),
      ],
    );
  }

  Widget _buildClassesTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
          columns: const [
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Level')),
            DataColumn(label: Text('Academic Year')),
            DataColumn(label: Text('Class Teacher')),
            DataColumn(label: Text('Students')),
          ],
          rows: _classesList.map((c) {
            return DataRow(cells: [
              DataCell(Text(c['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(Text(c['level']?.toString() ?? '')),
              DataCell(Text(c['academic_year']?.toString() ?? '')),
              DataCell(Text(c['class_teacher']?.toString() ?? '')),
              DataCell(Text(c['students']?.toString() ?? '0')),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // SUBJECTS TAB
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildSubjectsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Subjects', style: GoogleFonts.outfit(fontSize: 16.sp, fontWeight: FontWeight.w800)),
        Text('Manage academic subjects', style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF64748B))),
        SizedBox(height: 16.h),
        _subjectsList.isEmpty
            ? _buildEmptyState('No subjects found. Create one to get started.', _showAddSubjectDialog)
            : _buildSubjectsTable(),
      ],
    );
  }

  Widget _buildSubjectsTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
          columns: const [
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Code')),
            DataColumn(label: Text('Class')),
            DataColumn(label: Text('Teacher')),
            DataColumn(label: Text('Description')),
          ],
          rows: _subjectsList.map((s) {
            return DataRow(cells: [
              DataCell(Text(s['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(Text(s['code']?.toString() ?? '')),
              DataCell(Text(s['class']?.toString() ?? '')),
              DataCell(Text(s['teacher']?.toString() ?? '')),
              DataCell(Text(s['description']?.toString() ?? '', overflow: TextOverflow.ellipsis)),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // SECTIONS TAB
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildSectionsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sections', style: GoogleFonts.outfit(fontSize: 16.sp, fontWeight: FontWeight.w800)),
        Text('Manage class sections/divisions', style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF64748B))),
        SizedBox(height: 16.h),
        _sectionsList.isEmpty
            ? _buildEmptyState('No sections found. Create one to get started.', _showAddSectionDialog)
            : _buildSectionsTable(),
      ],
    );
  }

  Widget _buildSectionsTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
          columns: const [
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Class')),
            DataColumn(label: Text('Max Students')),
            DataColumn(label: Text('Students')),
          ],
          rows: _sectionsList.map((s) {
            return DataRow(cells: [
              DataCell(Text(s['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(Text(s['class']?.toString() ?? '')),
              DataCell(Text(s['max_students']?.toString() ?? '40')),
              DataCell(Text(s['students']?.toString() ?? '0')),
            ]);
          }).toList(),
  Widget _buildRefreshButton() {
    return TextButton.icon(
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
        backgroundColor: Colors.white,
      ),
      onPressed: _loadData,
      icon: Icon(Icons.refresh_rounded, size: 16.sp, color: const Color(0xFF0F172A)),
      label: Text(
        'Refresh',
        style: GoogleFonts.inter(
          fontSize: 13.sp,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF0F172A),
        ),
      ),
    );
  }

  Widget _buildCurrentSubjectsCard() {
    final hasSubjects = _className.contains('12');
    return Container(
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 16.r,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book_outlined, color: widget.theme.primary, size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                'Current Subjects',
                style: GoogleFonts.inter(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            'Subjects assigned to your class',
            style: GoogleFonts.inter(
                fontSize: 12.sp, color: AppColors.textMedium),
          ),
          SizedBox(height: 16.h),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(3),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(2),
            },
            children: [
              TableRow(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
                ),
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    child: Text('Subject', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppColors.textMedium)),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    child: Text('Code', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppColors.textMedium)),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    child: Text('Type', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppColors.textMedium)),
                  ),
                ],
              ),
              if (hasSubjects) ...[
                _subjectRow('Mathematics', 'MATH12', 'Core'),
                _subjectRow('Physics', 'PHYS12', 'Core'),
                _subjectRow('Chemistry', 'CHEM12', 'Core'),
                _subjectRow('English', 'ENGL12', 'Language'),
              ],
            ],
          ),
          if (!hasSubjects)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 36.h),
              child: Center(
                child: Text(
                  'No subjects listed',
                  style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textMedium),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimetablesCard() {
    return Container(
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 16.r,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.access_time_rounded, color: widget.theme.primary, size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                'Timetables',
                style: GoogleFonts.inter(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            'Recent class schedules',
            style: GoogleFonts.inter(
                fontSize: 12.sp, color: AppColors.textMedium),
          ),
          SizedBox(height: 16.h),
          CustomPaint(
            painter: DashedRectPainter(
              color: const Color(0xFFCBD5E1),
              radius: 12.r,
            ),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 36.h),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'No timetables uploaded yet',
                    style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textMedium,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcademicStatusCard() {
    return Container(
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 16.r,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_outlined, color: widget.theme.primary, size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                'Academic Status',
                style: GoogleFonts.inter(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 12.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.school_outlined, color: const Color(0xFF64748B), size: 24.sp),
                      SizedBox(height: 10.h),
                      Text(
                        'Target Class',
                        style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: AppColors.textMedium),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '$_className ($_section)',
                        style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w800, color: widget.theme.primary),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 12.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.check_circle_outline_rounded, color: const Color(0xFF64748B), size: 24.sp),
                      SizedBox(height: 10.h),
                      Text(
                        'Attendance Progress',
                        style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: AppColors.textMedium),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        _isLoading ? 'Loading...' : '${attendanceRate.toStringAsFixed(0)}%',
                        style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w800, color: const Color(0xFF15803D)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceHistoryCard() {
    return Container(
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 16.r,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_toggle_off_rounded, color: widget.theme.primary, size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                'Attendance History',
                style: GoogleFonts.inter(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            'Recent attendance records',
            style: GoogleFonts.inter(
                fontSize: 12.sp, color: AppColors.textMedium),
          ),
          SizedBox(height: 16.h),
          if (_attendanceHistory.isEmpty)
            CustomPaint(
              painter: DashedRectPainter(
                color: const Color(0xFFCBD5E1),
                radius: 12.r,
              ),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 36.h),
                child: Column(
                  children: [
                    Icon(Icons.history_rounded, color: const Color(0xFFCBD5E1), size: 32.sp),
                    SizedBox(height: 8.h),
                    Text(
                      'No attendance records found',
                      style: GoogleFonts.inter(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.italic,
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
              itemCount: _attendanceHistory.length,
              separatorBuilder: (_, __) => const Divider(height: 16, color: AppColors.border),
              itemBuilder: (_, index) {
                final r = _attendanceHistory[index];
                final status = r['status'] as String;
                final bool isPresent = status == 'Present' || status == 'P';
                
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      r['date'] as String,
                      style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w600, color: AppColors.textDark),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: isPresent ? const Color(0xFFDCFCE7) : const Color(0xFFFFE4E6),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Text(
                        status,
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          color: isPresent ? const Color(0xFF15803D) : const Color(0xFFE11D48),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  TableRow _subjectRow(String sub, String code, String type) {
    return TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
      ),
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          child: Text(sub, style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w500, color: AppColors.textDark)),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          child: Text(code, style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w500, color: AppColors.textMedium)),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          child: Text(type, style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w500, color: AppColors.textMedium)),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // EXAMS & RESULTS TAB
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildExamsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Examination & Results', style: GoogleFonts.outfit(fontSize: 16.sp, fontWeight: FontWeight.w800)),
        Text('Configure terms, grading scales, and manage student results.', style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF64748B))),
        SizedBox(height: 20.h),

        // 1. Exam Management Card
        _buildActionCard(
          title: 'Exam Management',
          subtitle: 'Create and schedule exams, assign subjects and marks structure.',
          buttonLabel: 'Go to Exams',
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExamScheduleScreen())),
        ),
        SizedBox(height: 16.h),

        // 2. Terms & Grading Card
        _buildDualActionCard(
          title: 'Terms & Grading',
          subtitle: 'Define academic terms and customize grading scales for the institution.',
          btn1Label: 'Terms',
          onBtn1Pressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExamTermsScreen(theme: widget.theme))),
          btn2Label: 'Grading',
          onBtn2Pressed: () => _showGradingScaleDialog(),
        ),
        SizedBox(height: 16.h),

        // 3. Approvals Card
        _buildActionCard(
          title: 'Approvals',
          subtitle: 'Principal review and approval of generated student report cards.',
          buttonLabel: 'Pending Review',
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExamReportCardScreen(theme: widget.theme))),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required String buttonLabel,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.outfit(fontSize: 14.sp, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
          SizedBox(height: 4.h),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF64748B))),
          SizedBox(height: 16.h),
          SizedBox(
            width: double.infinity,
            height: 44.h,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0066CC),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
              ),
              onPressed: onPressed,
              child: Text(
                buttonLabel,
                style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDualActionCard({
    required String title,
    required String subtitle,
    required String btn1Label,
    required VoidCallback onBtn1Pressed,
    required String btn2Label,
    required VoidCallback onBtn2Pressed,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.outfit(fontSize: 14.sp, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
          SizedBox(height: 4.h),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF64748B))),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44.h,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                    ),
                    onPressed: onBtn1Pressed,
                    child: Text(
                      btn1Label,
                      style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w700, color: const Color(0xFF475569)),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: SizedBox(
                  height: 44.h,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                    ),
                    onPressed: onBtn2Pressed,
                    child: Text(
                      btn2Label,
                      style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w700, color: const Color(0xFF475569)),
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

  void _showGradingScaleDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text('Grading System', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• A+ : 95% - 100% (Excellent)', style: TextStyle(fontWeight: FontWeight.w500)),
            SizedBox(height: 6),
            Text('• A  : 90% - 94% (Very Good)'),
            SizedBox(height: 6),
            Text('• B+ : 85% - 89% (Good)'),
            SizedBox(height: 6),
            Text('• B  : 80% - 84% (Above Average)'),
            SizedBox(height: 6),
            Text('• C  : 70% - 79% (Average)'),
            SizedBox(height: 6),
            Text('• D  : 60% - 69% (Pass)'),
            SizedBox(height: 6),
            Text('• F  : Below 60% (Fail)', style: TextStyle(color: Colors.red)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // EMPTY STATE HELPER
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildEmptyState(String text, VoidCallback onCreate) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 32.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(Icons.folder_open_rounded, size: 48.sp, color: const Color(0xFFCBD5E1)),
          SizedBox(height: 12.h),
          Text(
            text,
            style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8)),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.theme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
            ),
            onPressed: onCreate,
            child: const Text('Create One', style: TextStyle(color: Colors.white)),
          ),
        ],
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
