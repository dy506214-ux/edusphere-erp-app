import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../theme/colors.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Teacher Attendance Screen — matches the EduSphere attendance design
// ══════════════════════════════════════════════════════════════════════════════
class TeacherAttendanceScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  final bool showAppBar;

  const TeacherAttendanceScreen({
    super.key,
    this.onOpenDrawer,
    this.showAppBar = true,
  });

  @override
  State<TeacherAttendanceScreen> createState() =>
      _TeacherAttendanceScreenState();
}

class _TeacherAttendanceScreenState extends State<TeacherAttendanceScreen> {
  // ── Tab: 0 = Mark Attendance, 1 = Analytics ──
  int _activeTab = 0;

  // ── Filters ──
  String _userType = 'Students';
  String? _selectedClass;
  String _selectedSection = 'All Sections';
  DateTime _selectedDate = DateTime.now();

  final List<String> _userTypes = ['Students', 'Teachers'];
  final List<String> _classes = [
    'Class 1',
    'Class 2',
    'Class 3',
    'Class 4',
    'Class 5',
    'Class 6',
    'Class 7',
    'Class 8',
    'Class 9',
    'Class 10',
  ];
  final List<String> _sections = [
    'All Sections',
    'Section A',
    'Section B',
    'Section C',
  ];

  // ── Attendance data ──
  bool _isLoading = false;
  bool _slotCreated = false;
  List<Map<String, dynamic>> _students = [];
  Map<String, String> _attendanceStatus = {}; // studentId -> P/A/L
  bool _isSubmitting = false;
  bool _isAlreadySubmitted = false;

  // ── Analytics data ──
  bool _isAnalyticsLoading = false;
  List<Map<String, dynamic>> _analyticsData = [];

  final _supabase = Supabase.instance.client;

  // ── Stats ──
  int get _totalStudents => _students.length;
  int get _presentCount =>
      _attendanceStatus.values.where((s) => s == 'P').length;
  int get _absentCount =>
      _attendanceStatus.values.where((s) => s == 'A').length;
  int get _lateCount =>
      _attendanceStatus.values.where((s) => s == 'L').length;

  String get _dateStr => DateFormat('dd-MM-yyyy').format(_selectedDate);
  String get _dbDateStr => DateFormat('yyyy-MM-dd').format(_selectedDate);
  String get _fullClassName {
    if (_selectedClass == null) return '';
    if (_selectedSection == 'All Sections') return '$_selectedClass - A';
    final sec = _selectedSection.replaceAll('Section ', '');
    return '$_selectedClass - $sec';
  }

  // ═════════════════════════════════════════════════════════════════════════
  // DATA LOADING
  // ═════════════════════════════════════════════════════════════════════════

  Future<void> _loadAttendanceSlot() async {
    if (_selectedClass == null) return;
    setState(() {
      _isLoading = true;
      _slotCreated = false;
    });

    try {
      // Try to match students by class_name pattern
      final className = _fullClassName;
      final res = await _supabase
          .from('students')
          .select('id, name, email, class_name, admission_no')
          .eq('class_name', className)
          .order('name');

      final List<Map<String, dynamic>> studentList = [];
      for (var s in res) {
        studentList.add({
          'id': s['id']?.toString() ?? '',
          'name': s['name']?.toString() ?? 'Unknown',
          'email': s['email']?.toString() ?? '',
          'class_name': s['class_name']?.toString() ?? className,
          'admission_no': s['admission_no']?.toString() ?? '',
        });
      }

      // Check existing attendance for this date & class
      final existingAttendance = await _supabase
          .from('attendance')
          .select('student_id, status')
          .eq('date', _dbDateStr)
          .eq('class_name', className);

      Map<String, String> statusMap = {};
      bool alreadySubmitted = false;

      if (existingAttendance.isNotEmpty) {
        alreadySubmitted = true;
        for (var record in existingAttendance) {
          statusMap[record['student_id'].toString()] =
              record['status']?.toString() ?? 'P';
        }
      } else {
        for (var s in studentList) {
          statusMap[s['id']] = 'P';
        }
      }

      if (mounted) {
        setState(() {
          _students = studentList;
          _attendanceStatus = statusMap;
          _slotCreated = studentList.isNotEmpty || alreadySubmitted;
          _isAlreadySubmitted = alreadySubmitted;
          _isLoading = false;
        });
      }
    } catch (e) {
      // Fallback demo data
      if (mounted) {
        setState(() {
          _students = _getDemoStudents();
          _attendanceStatus = {};
          for (var s in _students) {
            _attendanceStatus[s['id']] = 'P';
          }
          _slotCreated = true;
          _isAlreadySubmitted = false;
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _getDemoStudents() {
    return [
      {'id': 'demo-1', 'name': 'Priya Singh', 'email': 'student1@demoschool.com', 'admission_no': 'ADM240001'},
      {'id': 'demo-2', 'name': 'Anjali Das', 'email': 'student2@demoschool.com', 'admission_no': 'ADM240002'},
      {'id': 'demo-3', 'name': 'Sneha Mair', 'email': 'student3@demoschool.com', 'admission_no': 'ADM240003'},
      {'id': 'demo-4', 'name': 'Arjun Reddy', 'email': 'student4@demoschool.com', 'admission_no': 'ADM240004'},
      {'id': 'demo-5', 'name': 'Ankit Gupta', 'email': 'student5@demoschool.com', 'admission_no': 'ADM240005'},
      {'id': 'demo-6', 'name': 'Deepak Yadav', 'email': 'student6@demoschool.com', 'admission_no': 'ADM240006'},
      {'id': 'demo-7', 'name': 'Riya Nair', 'email': 'student7@demoschool.com', 'admission_no': 'ADM240007'},
      {'id': 'demo-8', 'name': 'Karan Mishra', 'email': 'student8@demoschool.com', 'admission_no': 'ADM240008'},
    ];
  }

  Future<void> _createSlot() async {
    if (_selectedClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a class first',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: EdgeInsets.all(16.r),
        ),
      );
      return;
    }
    await _loadAttendanceSlot();
  }

  Future<void> _submitAttendance() async {
    if (_students.isEmpty) return;
    setState(() => _isSubmitting = true);

    try {
      final className = _fullClassName;

      // Delete existing then insert (upsert pattern)
      await _supabase
          .from('attendance')
          .delete()
          .eq('date', _dbDateStr)
          .eq('class_name', className);

      final records = <Map<String, dynamic>>[];
      for (var student in _students) {
        final studentId = student['id'];
        records.add({
          'student_id': studentId,
          'date': _dbDateStr,
          'status': _attendanceStatus[studentId] ?? 'P',
          'class_name': className,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      if (records.isNotEmpty) {
        await _supabase.from('attendance').insert(records);
      }

      if (mounted) {
        setState(() {
          _isAlreadySubmitted = true;
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Attendance submitted successfully!',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: EdgeInsets.all(16.r),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isAnalyticsLoading = true);
    try {
      final res = await _supabase
          .from('attendance')
          .select('id, student_id, date, status, class_name')
          .order('date', ascending: false)
          .limit(200);

      // Group by date
      Map<String, Map<String, int>> grouped = {};
      for (var record in res) {
        final date = record['date']?.toString() ?? '';
        final className = record['class_name']?.toString() ?? '';
        final key = '$date|$className';
        if (!grouped.containsKey(key)) {
          grouped[key] = {'P': 0, 'A': 0, 'L': 0, 'total': 0};
        }
        final status = record['status']?.toString() ?? 'P';
        if (status == 'P' || status == 'Present') {
          grouped[key]!['P'] = (grouped[key]!['P'] ?? 0) + 1;
        } else if (status == 'A' || status == 'Absent') {
          grouped[key]!['A'] = (grouped[key]!['A'] ?? 0) + 1;
        } else if (status == 'L' || status == 'Late') {
          grouped[key]!['L'] = (grouped[key]!['L'] ?? 0) + 1;
        }
        grouped[key]!['total'] = (grouped[key]!['total'] ?? 0) + 1;
      }

      List<Map<String, dynamic>> list = [];
      grouped.forEach((key, stats) {
        final parts = key.split('|');
        list.add({
          'date': parts[0],
          'class_name': parts.length > 1 ? parts[1] : '',
          'present': stats['P'] ?? 0,
          'absent': stats['A'] ?? 0,
          'late': stats['L'] ?? 0,
          'total': stats['total'] ?? 0,
        });
      });

      if (mounted) {
        setState(() {
          _analyticsData = list;
          _isAnalyticsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _analyticsData = [];
          _isAnalyticsLoading = false;
        });
      }
    }
  }

  void _markAll(String status) {
    setState(() {
      for (var student in _students) {
        _attendanceStatus[student['id']] = status;
      }
    });
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
    return 'S';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2027),
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
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _slotCreated = false;
        _students = [];
        _attendanceStatus = {};
      });
      if (_selectedClass != null) {
        _loadAttendanceSlot();
      }
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title ──
              Text(
                'Attendance',
                style: GoogleFonts.outfit(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'Mark daily attendance and view date-wise analytics',
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  color: const Color(0xFF64748B),
                ),
              ),
              SizedBox(height: 16.h),

              // ── Tab Toggle ──
              _buildTabToggle(),
              SizedBox(height: 16.h),

              // ── Content ──
              if (_activeTab == 0) _buildMarkAttendanceContent(),
              if (_activeTab == 1) _buildAnalyticsContent(),

              SizedBox(height: 80.h),
            ],
          ),
        ),
      ),
      floatingActionButton: _activeTab == 0
          ? FloatingActionButton(
              onPressed: _createSlot,
              backgroundColor: AppColors.teacherPrimary,
              elevation: 6,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r)),
              child: Icon(
                _slotCreated
                    ? Icons.refresh_rounded
                    : Icons.add_task_rounded,
                color: Colors.white,
                size: 24.sp,
              ),
            )
          : null,
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // TAB TOGGLE
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildTabToggle() {
    return Row(
      children: [
        _buildTabBtn(
          icon: Icons.check_rounded,
          label: 'Mark Attendance',
          isSelected: _activeTab == 0,
          onTap: () => setState(() => _activeTab = 0),
        ),
        SizedBox(width: 10.w),
        _buildTabBtn(
          icon: Icons.bar_chart_rounded,
          label: 'Analytics',
          isSelected: _activeTab == 1,
          onTap: () {
            setState(() => _activeTab = 1);
            if (_analyticsData.isEmpty) {
              _loadAnalytics();
            }
          },
        ),
      ],
    );
  }

  Widget _buildTabBtn({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.teacherPrimary : Colors.white,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: isSelected
                ? AppColors.teacherPrimary
                : const Color(0xFFE2E8F0),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.teacherPrimary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16.sp,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
            SizedBox(width: 6.w),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // MARK ATTENDANCE CONTENT
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildMarkAttendanceContent() {
    return Column(
      children: [
        // ── Select Type & Date Card ──
        _buildSelectTypeCard(),
        SizedBox(height: 16.h),

        // ── Today's Attendance Overview ──
        _buildTodayOverview(),

        // ── Student List (if slot created) ──
        if (_slotCreated && _students.isNotEmpty) ...[
          SizedBox(height: 16.h),
          _buildQuickActions(),
          SizedBox(height: 16.h),
          _buildStudentAttendanceList(),
          SizedBox(height: 16.h),
          _buildSubmitButton(),
        ],
      ],
    );
  }

  // ── SELECT TYPE & DATE CARD ──
  Widget _buildSelectTypeCard() {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Select Type & Date',
            style: GoogleFonts.outfit(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Choose user type, class, and date',
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              color: const Color(0xFF94A3B8),
            ),
          ),
          SizedBox(height: 20.h),

          // ── User Type ──
          _buildFieldLabel('User Type'),
          SizedBox(height: 6.h),
          _buildDropdown(
            icon: Icons.person_outline_rounded,
            value: _userType,
            items: _userTypes,
            onChanged: (val) {
              if (val != null) {
                setState(() => _userType = val);
              }
            },
          ),
          SizedBox(height: 16.h),

          // ── Class ──
          _buildFieldLabel('Class'),
          SizedBox(height: 6.h),
          _buildDropdown(
            icon: Icons.school_outlined,
            value: _selectedClass,
            hint: 'Select Class',
            items: _classes,
            onChanged: (val) {
              setState(() {
                _selectedClass = val;
                _slotCreated = false;
                _students = [];
                _attendanceStatus = {};
              });
            },
          ),
          SizedBox(height: 16.h),

          // ── Section ──
          _buildFieldLabel('Section (Optional)'),
          SizedBox(height: 6.h),
          _buildDropdown(
            icon: Icons.grid_view_rounded,
            value: _selectedSection,
            items: _sections,
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedSection = val;
                  _slotCreated = false;
                  _students = [];
                  _attendanceStatus = {};
                });
              }
            },
          ),
          SizedBox(height: 16.h),

          // ── Date ──
          _buildFieldLabel('Date'),
          SizedBox(height: 6.h),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(12.r),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 18.sp, color: const Color(0xFF94A3B8)),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      _dateStr,
                      style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Icon(Icons.calendar_month_rounded,
                      size: 20.sp, color: const Color(0xFF94A3B8)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 12.sp,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF374151),
      ),
    );
  }

  Widget _buildDropdown({
    required IconData icon,
    required String? value,
    String? hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18.sp, color: const Color(0xFF94A3B8)),
          SizedBox(width: 12.w),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                hint: hint != null
                    ? Text(
                        hint,
                        style: GoogleFonts.inter(
                            fontSize: 14.sp, color: const Color(0xFF94A3B8)),
                      )
                    : null,
                isExpanded: true,
                icon: Icon(Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF64748B), size: 22.sp),
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF0F172A),
                ),
                items: items
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── TODAY'S ATTENDANCE OVERVIEW ──
  Widget _buildTodayOverview() {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: AppColors.teacherPrimary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(Icons.calendar_month_rounded,
                    size: 20.sp, color: AppColors.teacherPrimary),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's Attendance Overview",
                      style: GoogleFonts.outfit(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      _slotCreated
                          ? '$_totalStudents student slots created for today ($_dbDateStr)'
                          : 'student slots created for today ($_dbDateStr)',
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (_isLoading) ...[
            SizedBox(height: 30.h),
            const Center(
              child: CircularProgressIndicator(
                  color: AppColors.teacherPrimary, strokeWidth: 2.5),
            ),
            SizedBox(height: 30.h),
          ] else if (_slotCreated && _students.isNotEmpty) ...[
            SizedBox(height: 20.h),
            // Stats row
            Row(
              children: [
                _buildOverviewStat(
                    'Total', '$_totalStudents', const Color(0xFF3B82F6)),
                SizedBox(width: 8.w),
                _buildOverviewStat(
                    'Present', '$_presentCount', const Color(0xFF10B981)),
                SizedBox(width: 8.w),
                _buildOverviewStat(
                    'Absent', '$_absentCount', const Color(0xFFEF4444)),
                SizedBox(width: 8.w),
                _buildOverviewStat(
                    'Late', '$_lateCount', const Color(0xFFF59E0B)),
              ],
            ),
            if (_isAlreadySubmitted) ...[
              SizedBox(height: 12.h),
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded,
                        size: 14.sp, color: const Color(0xFF10B981)),
                    SizedBox(width: 6.w),
                    Text(
                      'Attendance already submitted for this date',
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ] else ...[
            // Empty state
            SizedBox(height: 30.h),
            Icon(Icons.calendar_view_month_rounded,
                size: 56.sp, color: const Color(0xFFE2E8F0)),
            SizedBox(height: 14.h),
            Text(
              'No attendance slots created today',
              style: GoogleFonts.outfit(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              'Select a class above and create a slot to start\nmarking attendance',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11.sp,
                color: const Color(0xFF94A3B8),
                height: 1.5,
              ),
            ),
            SizedBox(height: 16.h),
            Divider(color: const Color(0xFFF1F5F9), height: 1.h),
            SizedBox(height: 12.h),
            Text(
              'Select a class above to create a new slot or\nview/update existing attendance',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11.sp,
                color: const Color(0xFF94A3B8),
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOverviewStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.inter(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w900,
                  color: color),
            ),
            SizedBox(height: 2.h),
            Text(
              label,
              style: GoogleFonts.inter(
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w600,
                  color: color.withValues(alpha: 0.8)),
            ),
          ],
        ),
      ),
    );
  }

  // ── QUICK ACTIONS ──
  Widget _buildQuickActions() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Text(
            'Quick:',
            style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF475569)),
          ),
          SizedBox(width: 10.w),
          _buildQuickBtn(
              'All Present', const Color(0xFF10B981), () => _markAll('P')),
          SizedBox(width: 6.w),
          _buildQuickBtn(
              'All Absent', const Color(0xFFEF4444), () => _markAll('A')),
          SizedBox(width: 6.w),
          _buildQuickBtn(
              'All Late', const Color(0xFFF59E0B), () => _markAll('L')),
        ],
      ),
    );
  }

  Widget _buildQuickBtn(String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8.r),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  color: color),
            ),
          ),
        ),
      ),
    );
  }

  // ── STUDENT ATTENDANCE LIST ──
  Widget _buildStudentAttendanceList() {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.all(16.r),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Student Attendance',
                      style: GoogleFonts.outfit(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A)),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '${_students.length} students • $_fullClassName',
                      style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          color: const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
                if (_isAlreadySubmitted)
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 10.w, vertical: 5.h),
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded,
                            size: 14.sp,
                            color: const Color(0xFF10B981)),
                        SizedBox(width: 4.w),
                        Text(
                          'Saved',
                          style: GoogleFonts.inter(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF10B981)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Table header
          Container(
            color: const Color(0xFFF8FAFC),
            padding:
                EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            child: Row(
              children: [
                SizedBox(
                  width: 24.w,
                  child: Text('#',
                      style: GoogleFonts.inter(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF475569))),
                ),
                Expanded(
                  child: Text('Student',
                      style: GoogleFonts.inter(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF475569))),
                ),
                SizedBox(
                  width: 130.w,
                  child: Center(
                    child: Text('Status',
                        style: GoogleFonts.inter(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF475569))),
                  ),
                ),
              ],
            ),
          ),

          // Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _students.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
            itemBuilder: (context, index) {
              final student = _students[index];
              final studentId = student['id'];
              final status = _attendanceStatus[studentId] ?? 'P';

              return Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: 16.w, vertical: 10.h),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24.w,
                      child: Text(
                        '${index + 1}',
                        style: GoogleFonts.inter(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF94A3B8)),
                      ),
                    ),
                    // Avatar
                    Container(
                      width: 36.w,
                      height: 36.h,
                      decoration: BoxDecoration(
                        color: AppColors.teacherPrimary
                            .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Center(
                        child: Text(
                          _getInitials(student['name']),
                          style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.teacherPrimary),
                        ),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student['name'],
                            style: GoogleFonts.inter(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1E293B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            student['admission_no'] ??
                                student['email'] ??
                                '',
                            style: GoogleFonts.inter(
                                fontSize: 9.sp,
                                color: const Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                    // P / A / L buttons
                    SizedBox(
                      width: 130.w,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildStatusBtn('P', status,
                              const Color(0xFF10B981), studentId),
                          SizedBox(width: 6.w),
                          _buildStatusBtn('A', status,
                              const Color(0xFFEF4444), studentId),
                          SizedBox(width: 6.w),
                          _buildStatusBtn('L', status,
                              const Color(0xFFF59E0B), studentId),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          SizedBox(height: 8.h),
        ],
      ),
    );
  }

  Widget _buildStatusBtn(
      String btnStatus, String currentStatus, Color color, String studentId) {
    final isSelected = currentStatus == btnStatus;
    return InkWell(
      onTap: () {
        setState(() {
          _attendanceStatus[studentId] = btnStatus;
        });
      },
      borderRadius: BorderRadius.circular(8.r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 36.w,
        height: 32.h,
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ]
              : null,
        ),
        child: Center(
          child: Text(
            btnStatus,
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: FontWeight.w800,
              color: isSelected ? Colors.white : color,
            ),
          ),
        ),
      ),
    );
  }

  // ── SUBMIT BUTTON ──
  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 52.h,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitAttendance,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.teacherPrimary,
          disabledBackgroundColor: const Color(0xFF94A3B8),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14.r)),
          elevation: 2,
          shadowColor: AppColors.teacherPrimary.withValues(alpha: 0.4),
        ),
        child: _isSubmitting
            ? SizedBox(
                width: 22.w,
                height: 22.h,
                child: const CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isAlreadySubmitted
                        ? Icons.update_rounded
                        : Icons.check_circle_outline_rounded,
                    color: Colors.white,
                    size: 20.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    _isAlreadySubmitted
                        ? 'Update Attendance'
                        : 'Submit Attendance',
                    style: GoogleFonts.inter(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                ],
              ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // ANALYTICS TAB
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildAnalyticsContent() {
    if (_isAnalyticsLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(
              color: AppColors.teacherPrimary, strokeWidth: 2.5),
        ),
      );
    }

    if (_analyticsData.isEmpty) {
      return Container(
        padding: EdgeInsets.all(40.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.bar_chart_rounded,
                  size: 56.sp, color: const Color(0xFFE2E8F0)),
              SizedBox(height: 14.h),
              Text(
                'No analytics data yet',
                style: GoogleFonts.outfit(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A)),
              ),
              SizedBox(height: 6.h),
              Text(
                'Submit attendance to see analytics here',
                style: GoogleFonts.inter(
                    fontSize: 11.sp, color: const Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary card
        Container(
          padding: EdgeInsets.all(20.r),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Attendance Records',
                style: GoogleFonts.outfit(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A)),
              ),
              SizedBox(height: 4.h),
              Text(
                '${_analyticsData.length} records found',
                style: GoogleFonts.inter(
                    fontSize: 11.sp, color: const Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
        SizedBox(height: 12.h),

        // Records list
        ..._analyticsData.map((record) => _buildAnalyticsCard(record)),
      ],
    );
  }

  Widget _buildAnalyticsCard(Map<String, dynamic> record) {
    final dateStr = record['date']?.toString() ?? '';
    final className = record['class_name']?.toString() ?? '';
    final present = record['present'] as int? ?? 0;
    final absent = record['absent'] as int? ?? 0;
    final late = record['late'] as int? ?? 0;
    final total = record['total'] as int? ?? 0;
    final pct = total > 0 ? (present / total * 100).round() : 0;

    String formattedDate = dateStr;
    try {
      final parsed = DateTime.parse(dateStr);
      formattedDate = DateFormat('EEE, dd MMM yyyy').format(parsed);
    } catch (_) {}

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      color:
                          AppColors.teacherPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(Icons.calendar_today_rounded,
                        size: 14.sp, color: AppColors.teacherPrimary),
                  ),
                  SizedBox(width: 10.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formattedDate,
                        style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A)),
                      ),
                      if (className.isNotEmpty)
                        Text(
                          className,
                          style: GoogleFonts.inter(
                              fontSize: 10.sp,
                              color: const Color(0xFF94A3B8)),
                        ),
                    ],
                  ),
                ],
              ),
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: pct >= 90
                      ? const Color(0xFF10B981).withValues(alpha: 0.1)
                      : pct >= 75
                          ? const Color(0xFFF59E0B)
                              .withValues(alpha: 0.1)
                          : const Color(0xFFEF4444)
                              .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  '$pct%',
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    color: pct >= 90
                        ? const Color(0xFF10B981)
                        : pct >= 75
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFFEF4444),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              _buildMiniStat('Present', '$present', const Color(0xFF10B981)),
              SizedBox(width: 10.w),
              _buildMiniStat('Absent', '$absent', const Color(0xFFEF4444)),
              SizedBox(width: 10.w),
              _buildMiniStat('Late', '$late', const Color(0xFFF59E0B)),
              SizedBox(width: 10.w),
              _buildMiniStat('Total', '$total', const Color(0xFF3B82F6)),
            ],
          ),
          SizedBox(height: 10.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: LinearProgressIndicator(
              value: total > 0 ? present / total : 0,
              minHeight: 6,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation(
                pct >= 90
                    ? const Color(0xFF10B981)
                    : pct >= 75
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFFEF4444),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
                fontSize: 15.sp,
                fontWeight: FontWeight.w800,
                color: color),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: GoogleFonts.inter(
                fontSize: 9.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}
