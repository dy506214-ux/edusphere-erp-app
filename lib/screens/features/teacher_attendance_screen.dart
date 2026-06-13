import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/colors.dart';
import '../main_screen.dart';
import '../../widgets/teacher_app_bar.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:developer' as dev;
import '../../services/api_service.dart';



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
  String? _selectedClass;
  String _selectedSection = 'All Sections';
  DateTime _selectedDate = DateTime.now();

  final List<String> _classes = [];
  final List<String> _sections = ['All Sections'];

  // Store classes fetched directly from Supabase (with correct UUIDs)
  List<Map<String, dynamic>> _apiClasses = [];
  // Store all sections from Supabase keyed by classId
  List<Map<String, dynamic>> _allSections = [];

  /// Load classes & sections directly from Supabase — IDs match Student table
  Future<void> _loadApiClasses() async {
    if (!mounted) return;
    try {
      final classesRes = await _supabase.from('Class').select('id, name').order('name');
      final sectionsRes = await _supabase.from('Section').select('id, name, classId').order('name');

      if (mounted) {
        setState(() {
          _allSections = List<Map<String, dynamic>>.from(sectionsRes);
          _apiClasses = List<Map<String, dynamic>>.from(classesRes);
          _classes.clear();
          for (var c in _apiClasses) {
            final name = c['name']?.toString() ?? '';
            if (name.isNotEmpty && !_classes.contains(name)) {
              if (name == 'Class 8' || name == 'Class 9' || name == 'Class 10') {
                _classes.add(name);
              }
            }
          }
          _classes.sort((a, b) {
            final numA = int.tryParse(a.replaceAll('Class ', '')) ?? 0;
            final numB = int.tryParse(b.replaceAll('Class ', '')) ?? 0;
            return numA.compareTo(numB);
          });
          if (_classes.isNotEmpty) {
            _selectedClass = _classes.first;
            _updateSectionsForSelectedClass();
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading classes from Supabase: $e');
    }
  }

  void _updateSectionsForSelectedClass() {
    if (_selectedClass == null) return;
    final cls = _apiClasses.firstWhere(
      (c) => c['name'] == _selectedClass,
      orElse: () => {},
    );
    _sections.clear();
    _sections.add('All Sections');
    if (cls.isNotEmpty) {
      final classId = cls['id']?.toString();
      final secList = _allSections.where((s) => s['classId']?.toString() == classId).toList();
      for (var s in secList) {
        final sName = s['name']?.toString() ?? '';
        if (sName.isNotEmpty) {
          _sections.add('Section $sName');
        }
      }
    }
    _selectedSection = 'All Sections';
  }

  // ── Attendance data ──
  bool _isLoading = false;
  // ── Analytics data ──
  bool _isAnalyticsLoading = false;
  List<Map<String, dynamic>> _analyticsData = [];

  // ── Analytics filters ──
  String _analyticsClass = 'All Classes';
  String _analyticsSection = 'All Sections';
  DateTime _analyticsFromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _analyticsToDate = DateTime.now();
  bool _analyticsLoaded = false;
  List<Map<String, dynamic>> _analyticsStudentData = [];
  final List<Map<String, dynamic>> _createdSlots = [];

  final _supabase = Supabase.instance.client;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _loadApiClasses();
    _loadExistingSlotsForDate();
    _connectRealtime();
  }

  void _connectRealtime() {
    try {
      _realtimeChannel = _supabase.channel('public:teacher_attendance_sync')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'AttendanceRecord',
          callback: (payload) {
            if (mounted) {
              _loadExistingSlotsForDate();
              _loadAnalytics();
            }
          },
        );
      _realtimeChannel!.subscribe();
    } catch (e) {
      dev.log('Error subscribing to teacher attendance realtime: $e');
    }
  }

  @override
  void dispose() {
    if (_realtimeChannel != null) {
      try {
        _supabase.removeChannel(_realtimeChannel!);
      } catch (_) {}
    }
    super.dispose();
  }

  String _mapClassName(String dbName) {
    return dbName.replaceAll('Class', 'Grade');
  }

  Future<void> _loadExistingSlotsForDate() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _createdSlots.clear();
      });
    }
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      // 1. Fetch classes, sections, and students
      final classesRes = await _supabase.from('Class').select('id, name');
      final sectionsRes = await _supabase.from('Section').select('id, name, classId');

      // 2. Fetch all attendance records for the selected date
      final attendanceRecords = await _supabase
          .from('AttendanceRecord')
          .select('studentId, status, Student(id, currentClassId, sectionId, admissionNumber, User(firstName, lastName, email))')
          .eq('date', dateStr);

      // Group attendance records by classId and sectionId
      Map<String, List<Map<String, dynamic>>> groupedRecords = {};
      for (var record in attendanceRecords) {
        final student = record['Student'] as Map?;
        if (student == null) continue;
        final classId = student['currentClassId']?.toString();
        final sectionId = student['sectionId']?.toString() ?? 'null';
        if (classId == null) continue;
        final key = '$classId|$sectionId';
        groupedRecords.putIfAbsent(key, () => []).add(record);
      }

      for (var key in groupedRecords.keys) {
        final parts = key.split('|');
        final classId = parts[0];
        final sectionId = parts[1];

        final cls = classesRes.firstWhere((c) => c['id']?.toString() == classId, orElse: () => {});
        final sec = sectionId != 'null'
            ? sectionsRes.firstWhere((s) => s['id']?.toString() == sectionId, orElse: () => {})
            : {};

        final dbClassName = cls['name']?.toString() ?? 'Class';
        final displayClassName = _mapClassName(dbClassName);
        final sectionName = sec.isNotEmpty ? 'Section ${sec['name']}' : 'All Sections';

        final records = groupedRecords[key]!;

        // Fetch students for this class and section
        var studentQuery = _supabase
            .from('Student')
            .select('id, admissionNumber, currentClassId, sectionId, User(firstName, lastName, email)')
            .eq('currentClassId', classId);

        if (sectionId != 'null') {
          studentQuery = studentQuery.eq('sectionId', sectionId);
        }

        final studentRes = await studentQuery;

        final List<Map<String, dynamic>> studentList = [];
        for (var s in studentRes) {
          final user = s['User'] as Map? ?? {};
          final name = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
          studentList.add({
            'id': s['id']?.toString() ?? '',
            'name': name.isNotEmpty ? name : 'Unknown',
            'email': user['email']?.toString() ?? '',
            'class_name': displayClassName,
            'admission_no': s['admissionNumber']?.toString() ?? '',
          });
        }
        studentList.sort((a, b) => a['name'].compareTo(b['name']));

        // Map status for marked students
        Map<String, String> statusMap = {};
        for (var record in records) {
          final sId = record['studentId']?.toString() ?? '';
          final statusVal = record['status']?.toString() ?? '';

          String localStatus = 'P';
          if (statusVal == 'ABSENT') localStatus = 'A';
          if (statusVal == 'LATE') localStatus = 'L';

          if (sId.isNotEmpty) statusMap[sId] = localStatus;
        }

        _createdSlots.add({
          'class': dbClassName,
          'section': sectionName,
          'date': _selectedDate,
          'students': studentList,
          'attendanceStatus': statusMap,
          'isSubmitted': true,
        });
      }
    } catch (e) {
      dev.log('Error loading existing slots: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String get _dateStr => DateFormat('dd-MM-yyyy').format(_selectedDate);



  Future<void> _loadAnalytics() async {
    setState(() {
      _isAnalyticsLoading = true;
      _analyticsLoaded = false;
    });
    try {
      var query = _supabase
          .from('AttendanceRecord')
          .select('id, studentId, date, status, Student(currentClassId, Class(name), User(firstName, lastName))')
          .eq('attendeeType', 'STUDENT')
          .gte('date', DateFormat('yyyy-MM-dd').format(_analyticsFromDate))
          .lte('date', DateFormat('yyyy-MM-dd').format(_analyticsToDate))
          .order('date', ascending: false)
          .limit(500);

      final res = await query;

      // Group by date
      Map<String, Map<String, dynamic>> grouped = {};
      // Student-level: track per student attendance counts
      Map<String, Map<String, dynamic>> studentMap = {};

      for (var record in res) {
        final date = record['date']?.toString() ?? '';
        final student = record['Student'] as Map? ?? {};
        final classData = student['Class'] as Map? ?? {};
        final className = classData['name']?.toString() ?? 'Unknown';
        final mappedClassName = _mapClassName(className);

        // Class filter
        if (_analyticsClass != 'All Classes' && mappedClassName != _analyticsClass) continue;

        final userMap = student['User'] as Map? ?? {};
        final firstName = userMap['firstName']?.toString() ?? '';
        final lastName = userMap['lastName']?.toString() ?? '';
        final studentName = '$firstName $lastName'.trim();
        final studentId = record['studentId']?.toString() ?? '';

        final status = record['status']?.toString() ?? 'PRESENT';
        final isPresent = status == 'PRESENT' || status == 'P' || status == 'Present';
        final isAbsent = status == 'ABSENT' || status == 'A' || status == 'Absent';
        final isLate = status == 'LATE' || status == 'L' || status == 'Late';

        // Date grouping
        if (!grouped.containsKey(date)) {
          grouped[date] = {'date': date, 'className': mappedClassName, 'P': 0, 'A': 0, 'L': 0, 'total': 0};
        }
        if (isPresent) grouped[date]!['P'] = (grouped[date]!['P'] as int) + 1;
        if (isAbsent) grouped[date]!['A'] = (grouped[date]!['A'] as int) + 1;
        if (isLate) grouped[date]!['L'] = (grouped[date]!['L'] as int) + 1;
        grouped[date]!['total'] = (grouped[date]!['total'] as int) + 1;

        // Student grouping
        if (studentId.isNotEmpty) {
          studentMap[studentId] ??= {'name': studentName, 'class': mappedClassName, 'P': 0, 'A': 0, 'L': 0, 'total': 0};
          if (isPresent) studentMap[studentId]!['P'] = (studentMap[studentId]!['P'] as int) + 1;
          if (isAbsent) studentMap[studentId]!['A'] = (studentMap[studentId]!['A'] as int) + 1;
          if (isLate) studentMap[studentId]!['L'] = (studentMap[studentId]!['L'] as int) + 1;
          studentMap[studentId]!['total'] = (studentMap[studentId]!['total'] as int) + 1;
        }
      }

      final list = grouped.values.toList();
      list.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));

      final studentList = studentMap.values.toList();
      studentList.sort((a, b) {
        final aP = a['total'] > 0 ? (a['P'] / a['total']) : 0;
        final bP = b['total'] > 0 ? (b['P'] / b['total']) : 0;
        return (bP as num).compareTo(aP as num);
      });

      if (mounted) {
        setState(() {
          _analyticsData = list;
          _isAnalyticsLoading = false;
          _analyticsLoaded = true;
          // store student list for matrix
          _analyticsStudentData = studentList;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _analyticsData = [];
          _analyticsStudentData = [];
          _isAnalyticsLoading = false;
          _analyticsLoaded = true;
        });
      }
    }
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
      });
      _loadExistingSlotsForDate();
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: widget.showAppBar
          ? const TeacherAppBar(title: 'EduSphere')
          : null,
      bottomNavigationBar: widget.showAppBar ? const TeacherBottomNavBar(activeIndex: 3) : null,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mark daily attendance and view date-wise analytics',
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF475569),
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
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // TAB TOGGLE
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildTabToggle() {
    return Container(
      padding: EdgeInsets.all(4.r),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTabBtn(
            icon: Icons.check_rounded,
            label: 'Mark Attendance',
            isSelected: _activeTab == 0,
            onTap: () => setState(() => _activeTab = 0),
          ),
          SizedBox(width: 4.w),
          _buildTabBtn(
            icon: Icons.bar_chart_rounded,
            label: 'Analytics',
            isSelected: _activeTab == 1,
            onTap: () => setState(() => _activeTab = 1),
          ),
        ],
      ),
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
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10.r),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
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
              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
            ),
            SizedBox(width: 6.w),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
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

        // ── Attendance Slots Card ──
        _buildAttendanceSlotsCard(),
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
            value: 'Students',
            items: ['Students'],
            onChanged: (val) {},
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
              if (val != null) {
                setState(() {
                  _selectedClass = val;
                  _updateSectionsForSelectedClass();
                });
                _createNewSlotFromSelection();
              }
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
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: const Color(0xFFD0E1F9)),
              ),
              child: Row(
                children: [
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
                  Icon(Icons.calendar_today_outlined,
                      size: 18.sp, color: const Color(0xFF0F172A)),
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
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.replaceAll('Class', 'Grade')),
                        ))
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildAttendanceSlotsCard() {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.access_time_rounded, size: 20.sp, color: const Color(0xFF0F172A)),
              SizedBox(width: 8.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Attendance Slots",
                    style: GoogleFonts.outfit(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    "Today's attendance slots",
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // "+ Create Slot" Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _createNewSlotFromSelection,
              icon: Icon(Icons.add, color: Colors.white, size: 18.sp),
              label: Text(
                'Create Slot',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14.sp,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0052CC), // Blue color matching mockup
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24.r), // Pill shape
                ),
                padding: EdgeInsets.symmetric(vertical: 12.h),
                elevation: 0,
              ),
            ),
          ),
          SizedBox(height: 20.h),

          if (_isLoading) ...[
            SizedBox(height: 30.h),
            const Center(
              child: CircularProgressIndicator(
                color: AppColors.teacherPrimary,
                strokeWidth: 2.5,
              ),
            ),
            SizedBox(height: 30.h),
          ] else if (_createdSlots.isEmpty) ...[
            Center(
              child: Column(
                children: [
                  SizedBox(height: 20.h),
                  Icon(Icons.calendar_today_outlined,
                      size: 56.sp, color: const Color(0xFFCBD5E1)),
                  SizedBox(height: 14.h),
                  Text(
                    'No attendance slot for this date',
                    style: GoogleFonts.outfit(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'Click "Create Slot" to create an attendance slot and start marking',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      color: const Color(0xFF64748B),
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 20.h),
                ],
              ),
            ),
          ] else ...[
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _createdSlots.length,
              itemBuilder: (context, index) {
                final slot = _createdSlots[index];
                final isSub = slot['isSubmitted'] as bool? ?? false;
                final totalRecs = slot['students'] != null
                    ? (slot['students'] as List).length
                    : 0;

                final rawClass = slot['class'] as String;
                final displayClass = rawClass.replaceAll('Class', 'Grade');
                final String displayTitle = (slot['section'] == 'All Sections' || (slot['section'] as String).isEmpty)
                    ? displayClass
                    : '$displayClass - ${slot['section']}';

                return GestureDetector(
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MarkAttendanceScreen(
                          className: slot['class'] as String,
                          section: slot['section'] as String,
                          date: slot['date'] as DateTime,
                          students: List<Map<String, dynamic>>.from(slot['students'] as Iterable),
                          initialAttendanceStatus: Map<String, String>.from(slot['attendanceStatus'] as Map),
                          isAlreadySubmitted: isSub,
                          supabase: _supabase,
                        ),
                      ),
                    );

                    if (result != null && result is Map<String, dynamic>) {
                      if (result['delete'] == true) {
                        setState(() {
                          _createdSlots.removeAt(index);
                        });
                      } else {
                        setState(() {
                          slot['isSubmitted'] = true;
                          slot['attendanceStatus'] = result['attendanceStatus'];
                        });
                      }
                    }
                  },
                  child: Container(
                    margin: EdgeInsets.only(bottom: 12.h),
                    padding: EdgeInsets.all(16.r),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(10.r),
                          decoration: BoxDecoration(
                            color: isSub ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isSub ? Icons.check_rounded : Icons.access_time_rounded,
                            color: isSub ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                            size: 20.sp,
                          ),
                        ),
                        SizedBox(width: 14.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayTitle,
                                style: GoogleFonts.inter(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                isSub ? '$totalRecs records marked' : '$totalRecs records',
                                style: GoogleFonts.inter(
                                  fontSize: 12.sp,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: isSub ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Text(
                            isSub ? 'Done' : 'Open',
                            style: GoogleFonts.inter(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w700,
                              color: isSub ? const Color(0xFF15803D) : const Color(0xFFB45309),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: 16.h),
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Text(
                  'Select a class above to create a new slot or\nview/update existing attendance',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    color: const Color(0xFF94A3B8),
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _createNewSlotFromSelection() async {
    if (_selectedClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a class first',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: EdgeInsets.all(16.r),
        ),
      );
      return;
    }

    final exists = _createdSlots.any((slot) =>
        slot['class'] == _selectedClass &&
        slot['section'] == _selectedSection &&
        DateFormat('yyyy-MM-dd').format(slot['date'] as DateTime) ==
            DateFormat('yyyy-MM-dd').format(_selectedDate));

    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attendance slot already exists for this selection',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final cls = _apiClasses.firstWhere(
        (c) => c['name'] == _selectedClass,
        orElse: () => {},
      );

      if (cls.isEmpty) {
        throw 'Class not found. Please wait for classes to load.';
      }
      final classId = cls['id']?.toString() ?? '';
      if (classId.isEmpty) throw 'Invalid class ID';

      String? sectionId;
      if (_selectedSection != 'All Sections') {
        final secName = _selectedSection.replaceAll('Section ', '').trim();
        // Look up section from our Supabase-sourced sections list
        final sec = _allSections.firstWhere(
          (s) => s['classId']?.toString() == classId && s['name']?.toString() == secName,
          orElse: () => {},
        );
        if (sec.isNotEmpty) {
          sectionId = sec['id']?.toString();
        }
      }

      // 1. Fetch students for the class/section via Supabase
      var studentQuery = _supabase
          .from('Student')
          .select('id, admissionNumber, currentClassId, sectionId, User(firstName, lastName, email)')
          .eq('currentClassId', classId);

      if (sectionId != null) {
        studentQuery = studentQuery.eq('sectionId', sectionId);
      }

      final studentsRawList = await studentQuery;

      // 2. Fetch all attendance records for this date via Supabase
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final attendanceRawList = await _supabase
          .from('AttendanceRecord')
          .select('studentId, status')
          .eq('date', dateStr);

      final List<Map<String, dynamic>> studentList = [];
      final Map<String, String> statusMap = {};
      bool alreadySubmitted = false;

      for (var item in studentsRawList) {
        final user = item['User'] as Map? ?? {};
        final firstName = user['firstName'] ?? '';
        final lastName = user['lastName'] ?? '';
        final fullName = '$firstName $lastName'.trim();
        final email = user['email'] ?? '';
        final admission = item['admissionNumber'] ?? '';

        final sId = item['id']?.toString() ?? '';
        if (sId.isEmpty) continue;

        studentList.add({
          'id': sId,
          'name': fullName.isNotEmpty ? fullName : (email.isNotEmpty ? email.split('@')[0] : 'Unknown'),
          'email': email,
          'class_name': _selectedClass!,
          'admission_no': admission,
        });
      }

      studentList.sort((a, b) => a['name'].compareTo(b['name']));

      // Map attendance records to our students
      for (var att in attendanceRawList) {
        final sId = att['studentId']?.toString() ?? '';
        if (sId.isNotEmpty) {
          final isOurStudent = studentList.any((s) => s['id'] == sId);
          if (isOurStudent) {
            alreadySubmitted = true;
            final statusVal = att['status']?.toString() ?? '';
            String localStatus = 'P';
            if (statusVal == 'ABSENT' || statusVal == 'A') localStatus = 'A';
            if (statusVal == 'LATE' || statusVal == 'L') localStatus = 'L';
            statusMap[sId] = localStatus;
          }
        }
      }

      final newSlot = {
        'class': _selectedClass!,
        'section': _selectedSection,
        'date': _selectedDate,
        'students': studentList,
        'attendanceStatus': statusMap,
        'isSubmitted': alreadySubmitted,
      };

      if (mounted) {
        setState(() {
          _createdSlots.add(newSlot);
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Attendance slot created', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error creating slot via Supabase: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create slot: $e', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ANALYTICS TAB — new design
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildAnalyticsContent() {
    const Color primary = Color(0xFF0D7DDC);
    const Color green  = Color(0xFF10B981);
    const Color red    = Color(0xFFEF4444);
    const Color amber  = Color(0xFFF59E0B);

    final allClasses = ['All Classes', ..._classes];
    final allSections = ['All Sections', ..._sections.where((s) => s != 'All Sections')];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── FILTER CARD ────────────────────────────────────────────────────────
        Container(
          padding: EdgeInsets.all(18.r),
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
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(Icons.bar_chart_rounded, size: 18.sp, color: primary),
                  ),
                  SizedBox(width: 10.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Attendance Analytics',
                        style: GoogleFonts.outfit(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Date-wise breakdown, trends, and student matrix',
                        style: GoogleFonts.inter(
                          fontSize: 10.sp,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 16.h),

              // Row 1: Class + Section
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Class', style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w600, color: const Color(0xFF374151))),
                        SizedBox(height: 6.h),
                        _buildAnalyticsDropdown(
                          value: _analyticsClass,
                          items: allClasses,
                          onChanged: (v) => setState(() => _analyticsClass = v ?? 'All Classes'),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Section', style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w600, color: const Color(0xFF374151))),
                        SizedBox(height: 6.h),
                        _buildAnalyticsDropdown(
                          value: _analyticsSection,
                          items: allSections,
                          onChanged: (v) => setState(() => _analyticsSection = v ?? 'All Sections'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),

              // Row 2: From Date + To Date + Load button
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('From Date', style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w600, color: const Color(0xFF374151))),
                        SizedBox(height: 6.h),
                        _buildAnalyticsDateField(
                          date: _analyticsFromDate,
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _analyticsFromDate,
                              firstDate: DateTime(2024),
                              lastDate: DateTime(2027),
                              builder: (ctx, child) => Theme(
                                data: Theme.of(ctx).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: AppColors.teacherPrimary,
                                    onPrimary: Colors.white,
                                    surface: Colors.white,
                                    onSurface: Color(0xFF0F172A),
                                  ),
                                ),
                                child: child!,
                              ),
                            );
                            if (picked != null) setState(() => _analyticsFromDate = picked);
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('To Date', style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w600, color: const Color(0xFF374151))),
                        SizedBox(height: 6.h),
                        _buildAnalyticsDateField(
                          date: _analyticsToDate,
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _analyticsToDate,
                              firstDate: DateTime(2024),
                              lastDate: DateTime(2027),
                              builder: (ctx, child) => Theme(
                                data: Theme.of(ctx).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: AppColors.teacherPrimary,
                                    onPrimary: Colors.white,
                                    surface: Colors.white,
                                    onSurface: Color(0xFF0F172A),
                                  ),
                                ),
                                child: child!,
                              ),
                            );
                            if (picked != null) setState(() => _analyticsToDate = picked);
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Padding(
                    padding: EdgeInsets.only(top: 17.h),
                    child: SizedBox(
                      height: 44.h,
                      child: ElevatedButton.icon(
                        onPressed: _isAnalyticsLoading ? null : _loadAnalytics,
                        icon: _isAnalyticsLoading
                            ? SizedBox(
                                width: 14.w,
                                height: 14.h,
                                child: const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(Icons.trending_up_rounded, size: 16.sp, color: Colors.white),
                        label: Text(
                          'Load Analytics',
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          elevation: 0,
                          padding: EdgeInsets.symmetric(horizontal: 14.w),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),

        // ── EMPTY / LOADING / RESULTS ──────────────────────────────────────────
        if (_isAnalyticsLoading)
          Container(
            height: 200.h,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF0D7DDC),
                strokeWidth: 2.5,
              ),
            ),
          )
        else if (!_analyticsLoaded)
          // Not yet clicked — empty placeholder
          Container(
            padding: EdgeInsets.symmetric(vertical: 60.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bar_chart_rounded,
                    size: 52.sp,
                    color: const Color(0xFFCBD5E1),
                  ),
                  SizedBox(height: 14.h),
                  Text(
                    'No analytics loaded yet',
                    style: GoogleFonts.outfit(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF475569),
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'Select filters above and click "Load Analytics"',
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
        else if (_analyticsData.isEmpty)
          // Loaded but no data
          Container(
            padding: EdgeInsets.symmetric(vertical: 60.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox_outlined, size: 48.sp, color: const Color(0xFFCBD5E1)),
                  SizedBox(height: 12.h),
                  Text(
                    'No records found',
                    style: GoogleFonts.outfit(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF475569),
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'Try adjusting your filters or date range',
                    style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // — Overall summary chips
              _buildOverallSummary(green, red, amber),
              SizedBox(height: 16.h),

              // — Date-wise breakdown heading
              Text(
                'Date-wise Breakdown',
                style: GoogleFonts.outfit(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              SizedBox(height: 10.h),

              // — Date cards
              ..._analyticsData.map((r) => _buildNewAnalyticsCard(r, green, red, amber, primary)),

              // — Student matrix (if any)
              if (_analyticsStudentData.isNotEmpty) ...[
                SizedBox(height: 20.h),
                Text(
                  'Student Attendance Matrix',
                  style: GoogleFonts.outfit(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 10.h),
                _buildStudentMatrix(green, red, amber),
              ],
            ],
          ),
      ],
    );
  }

  // ── Dropdown for analytics filters
  Widget _buildAnalyticsDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 44.h,
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18.sp, color: const Color(0xFF94A3B8)),
          style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
          onChanged: onChanged,
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        ),
      ),
    );
  }

  // ── Date field for analytics
  Widget _buildAnalyticsDateField({required DateTime date, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44.h,
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                DateFormat('dd-MM-yyyy').format(date),
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
            Icon(Icons.calendar_today_rounded, size: 14.sp, color: const Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  // ── Overall summary row
  Widget _buildOverallSummary(Color green, Color red, Color amber) {
    int totalP = 0, totalA = 0, totalL = 0, totalAll = 0;
    for (final r in _analyticsData) {
      totalP += (r['P'] as int? ?? 0);
      totalA += (r['A'] as int? ?? 0);
      totalL += (r['L'] as int? ?? 0);
      totalAll += (r['total'] as int? ?? 0);
    }
    final pct = totalAll > 0 ? (totalP / totalAll * 100).round() : 0;
    final pctColor = pct >= 90 ? green : pct >= 75 ? amber : red;

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF0D7DDC).withValues(alpha: 0.08), const Color(0xFF0D7DDC).withValues(alpha: 0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFF0D7DDC).withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Overall Attendance',
                    style: GoogleFonts.outfit(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    '${_analyticsData.length} days • $totalAll total records',
                    style: GoogleFonts.inter(fontSize: 10.sp, color: const Color(0xFF94A3B8)),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: pctColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: pctColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '$pct%',
                  style: GoogleFonts.outfit(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w900,
                    color: pctColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              _buildSumChip('Present', totalP, green),
              SizedBox(width: 8.w),
              _buildSumChip('Absent', totalA, red),
              SizedBox(width: 8.w),
              _buildSumChip('Late', totalL, amber),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSumChip(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: GoogleFonts.outfit(
                fontSize: 18.sp,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
                color: color.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Date-wise breakdown card (new design)
  Widget _buildNewAnalyticsCard(
    Map<String, dynamic> record,
    Color green,
    Color red,
    Color amber,
    Color primary,
  ) {
    final dateStr   = record['date']?.toString() ?? '';
    final className = record['className']?.toString() ?? '';
    final present   = record['P'] as int? ?? 0;
    final absent    = record['A'] as int? ?? 0;
    final late      = record['L'] as int? ?? 0;
    final total     = record['total'] as int? ?? 0;
    final pct       = total > 0 ? (present / total * 100).round() : 0;
    final pctColor  = pct >= 90 ? green : pct >= 75 ? amber : red;

    String fmtDate = dateStr;
    try {
      fmtDate = DateFormat('EEE, dd MMM yyyy').format(DateTime.parse(dateStr));
    } catch (_) {}

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(7.r),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(Icons.calendar_today_rounded, size: 14.sp, color: primary),
                  ),
                  SizedBox(width: 10.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fmtDate,
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      if (className.isNotEmpty)
                        Text(
                          className,
                          style: GoogleFonts.inter(
                            fontSize: 10.sp,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
                decoration: BoxDecoration(
                  color: pctColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: pctColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '$pct%',
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    color: pctColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),

          // Stacked horizontal bar
          if (total > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6.r),
              child: SizedBox(
                height: 8.h,
                child: Row(
                  children: [
                    if (present > 0)
                      Flexible(
                        flex: present,
                        child: Container(color: green),
                      ),
                    if (late > 0)
                      Flexible(
                        flex: late,
                        child: Container(color: amber),
                      ),
                    if (absent > 0)
                      Flexible(
                        flex: absent,
                        child: Container(color: red),
                      ),
                    if (total - present - absent - late > 0)
                      Flexible(
                        flex: total - present - absent - late,
                        child: Container(color: const Color(0xFFE2E8F0)),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 10.h),
          ],

          // Stats row
          Row(
            children: [
              _buildStatPill('Present', present, green),
              SizedBox(width: 8.w),
              _buildStatPill('Absent', absent, red),
              SizedBox(width: 8.w),
              _buildStatPill('Late', late, amber),
              SizedBox(width: 8.w),
              _buildStatPill('Total', total, const Color(0xFF6366F1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 7.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: GoogleFonts.outfit(
                fontSize: 14.sp,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 9.sp,
                fontWeight: FontWeight.w600,
                color: color.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Student matrix
  Widget _buildStudentMatrix(Color green, Color red, Color amber) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16.r),
                topRight: Radius.circular(16.r),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text('Student', style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w700, color: const Color(0xFF475569))),
                ),
                SizedBox(
                  width: 44.w,
                  child: Center(child: Text('P', style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w700, color: green))),
                ),
                SizedBox(
                  width: 44.w,
                  child: Center(child: Text('A', style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w700, color: red))),
                ),
                SizedBox(
                  width: 44.w,
                  child: Center(child: Text('L', style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w700, color: amber))),
                ),
                SizedBox(
                  width: 44.w,
                  child: Center(child: Text('%', style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w700, color: const Color(0xFF6366F1)))),
                ),
              ],
            ),
          ),

          // Rows — limit to 20 for perf
          ...(_analyticsStudentData.take(20).toList().asMap().entries.map((entry) {
            final i   = entry.key;
            final s   = entry.value;
            final p   = s['P'] as int? ?? 0;
            final a   = s['A'] as int? ?? 0;
            final l   = s['L'] as int? ?? 0;
            final tot = s['total'] as int? ?? 0;
            final pct = tot > 0 ? (p / tot * 100).round() : 0;
            final pctColor = pct >= 90 ? green : pct >= 75 ? amber : red;
            final name = (s['name'] as String? ?? '').isNotEmpty ? s['name'] as String : 'Student';

            return Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: i.isEven ? Colors.white : const Color(0xFFFAFAFC),
                border: Border(
                  bottom: BorderSide(color: const Color(0xFFF1F5F9), width: i < _analyticsStudentData.length - 1 ? 1 : 0),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14.r,
                          backgroundColor: const Color(0xFFE0E7FF),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'S',
                            style: GoogleFonts.inter(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF6366F1),
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            name,
                            style: GoogleFonts.inter(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 44.w,
                    child: Center(
                      child: Text('$p', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: green)),
                    ),
                  ),
                  SizedBox(
                    width: 44.w,
                    child: Center(
                      child: Text('$a', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: red)),
                    ),
                  ),
                  SizedBox(
                    width: 44.w,
                    child: Center(
                      child: Text('$l', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: amber)),
                    ),
                  ),
                  SizedBox(
                    width: 44.w,
                    child: Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: pctColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          '$pct%',
                          style: GoogleFonts.inter(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700,
                            color: pctColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          })),

          // Footer note if more than 20
          if (_analyticsStudentData.length > 20)
            Padding(
              padding: EdgeInsets.all(12.r),
              child: Text(
                'Showing top 20 students by attendance rate',
                style: GoogleFonts.inter(fontSize: 10.sp, color: const Color(0xFF94A3B8)),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

class MarkAttendanceScreen extends StatefulWidget {
  final String className;
  final String section;
  final DateTime date;
  final List<Map<String, dynamic>> students;
  final Map<String, String> initialAttendanceStatus;
  final bool isAlreadySubmitted;
  final SupabaseClient supabase;

  const MarkAttendanceScreen({
    super.key,
    required this.className,
    required this.section,
    required this.date,
    required this.students,
    required this.initialAttendanceStatus,
    required this.isAlreadySubmitted,
    required this.supabase,
  });

  @override
  State<MarkAttendanceScreen> createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends State<MarkAttendanceScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late List<Map<String, dynamic>> _students;
  late Map<String, String> _attendanceStatus;
  bool _isSubmitting = false;
  late bool _isAlreadySubmitted;

  @override
  void initState() {
    super.initState();
    _students = List.from(widget.students);
    _attendanceStatus = Map.from(widget.initialAttendanceStatus);
    _isAlreadySubmitted = widget.isAlreadySubmitted;
  }

  void _markAll(String status) {
    setState(() {
      for (var student in _students) {
        final String studentId = student['id']?.toString() ?? '';
        _attendanceStatus[studentId] = status;
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

  Future<void> _submitAttendance() async {
    if (_students.isEmpty) return;

    // Check if any student is still unmarked
    final unmarkedStudents = _students.where((s) {
      final id = s['id']?.toString() ?? '';
      return _attendanceStatus[id] == null;
    }).toList();

    if (unmarkedStudents.isNotEmpty) {
      // Show a confirmation dialog asking whether to mark unmarked students as absent
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Unmarked Students',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          content: Text(
            '${unmarkedStudents.length} student(s) are not marked.\n\nDo you want to mark them as Absent and submit?',
            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D7DDC),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('Mark Absent & Submit',
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      // Mark all unmarked students as Absent
      setState(() {
        for (var s in unmarkedStudents) {
          final id = s['id']?.toString() ?? '';
          if (id.isNotEmpty) _attendanceStatus[id] = 'A';
        }
      });
    }

    setState(() => _isSubmitting = true);

    final dbDateStr = DateFormat('yyyy-MM-dd').format(widget.date);

    try {
      final attendanceData = <Map<String, dynamic>>[];
      for (var student in _students) {
        final String studentId = student['id']?.toString() ?? '';
        if (studentId.isEmpty) continue;
        final statusLocal = _attendanceStatus[studentId] ?? 'A';

        String statusEnum = 'PRESENT';
        if (statusLocal == 'A') statusEnum = 'ABSENT';
        if (statusLocal == 'L') statusEnum = 'LATE';

        attendanceData.add({
          'studentId': studentId,
          'status': statusEnum,
        });
      }

      final payload = {
        'date': dbDateStr,
        'attendanceData': attendanceData,
      };

      final response = await ApiService.instance.post('attendance/bulk', body: payload);
      if (response == null || response['success'] != true) {
        throw response != null ? (response['message'] ?? 'API response error') : 'No response from API';
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
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Attendance submitted successfully!',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );

        Navigator.pop(context, {
          'attendanceStatus': _attendanceStatus,
        });
      }
    } catch (e) {
      // ── Offline / DB error fallback ──
      // Save locally and navigate back so user doesn't lose their marking.
      if (mounted) {
        setState(() {
          _isAlreadySubmitted = true;
          _isSubmitting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Saved locally. Sync will happen when online.',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFF59E0B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
          ),
        );

        Navigator.pop(context, {
          'attendanceStatus': _attendanceStatus,
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Stats calculation
    final totalCount = _students.length;
    final presentCount = _attendanceStatus.values.where((status) => status == 'P').length;
    final absentCount = _attendanceStatus.values.where((status) => status == 'A').length;

    final bool canGoBack = Navigator.canPop(context);

    return Scaffold(
      key: _scaffoldKey,
      // Only show drawer when NOT pushed on top of another route
      drawer: canGoBack ? null : const EduSphereDrawer(role: 'teacher', activeLabel: 'Attendance'),
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: const TeacherAppBar(title: 'Mark Attendance'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Card mirroring active slot
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(color: const Color(0xFF0052CC), width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10.r),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E7FF),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Icon(
                        Icons.people_outline_rounded,
                        color: const Color(0xFF4F46E5),
                        size: 20.sp,
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${widget.className.replaceAll('Class', 'Grade')} - ${widget.section}',
                                style: GoogleFonts.inter(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                decoration: BoxDecoration(
                                  color: _isAlreadySubmitted
                                      ? const Color(0xFFD1FAE5)
                                      : const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!_isAlreadySubmitted) ...[
                                      Container(
                                        width: 6.w,
                                        height: 6.h,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFD97706),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      SizedBox(width: 4.w),
                                    ],
                                    Text(
                                      _isAlreadySubmitted ? 'Submitted' : 'Open',
                                      style: GoogleFonts.inter(
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w700,
                                        color: _isAlreadySubmitted
                                            ? const Color(0xFF065F46)
                                            : const Color(0xFF92400E),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            '${_students.length} records',
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: const Color(0xFFEF4444),
                        size: 20.sp,
                      ),
                      onPressed: () {
                        Navigator.pop(context, {'delete': true});
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),

              // 2. Stacked vertical statistic cards
              _buildStatCard('Total students', '$totalCount', const Color(0xFF0F172A)),
              _buildStatCard('Present', '$presentCount', const Color(0xFF10B981)),
              _buildStatCard('Absent', '$absentCount', const Color(0xFFEF4444)),
              SizedBox(height: 20.h),

              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 550;
                  final headerColumn = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Student List',
                        style: GoogleFonts.outfit(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        '${widget.className.replaceAll('Class', 'Grade')} - ${widget.section} • Mark attendance',
                        style: GoogleFonts.inter(
                          fontSize: 10.sp,
                          color: const Color(0xFF94A3B8),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  );

                  final buttonsRow = Row(
                    children: [
                      _buildMarkAllButton('Mark All Present', Icons.check_rounded, () => _markAll('P')),
                      SizedBox(width: 8.w),
                      _buildMarkAllButton('Mark All Absent', Icons.close_rounded, () => _markAll('A')),
                    ],
                  );

                  if (isWide) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: headerColumn),
                        SizedBox(width: 8.w),
                        Expanded(child: buttonsRow),
                      ],
                    );
                  } else {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        headerColumn,
                        SizedBox(height: 12.h),
                        buttonsRow,
                      ],
                    );
                  }
                },
              ),
              SizedBox(height: 16.h),

              // 4. Student list individual cards (Image 5 & 6 layout)
              ..._students.asMap().entries.map((entry) {
                final index = entry.key;
                final student = entry.value;
                final String studentId = student['id']?.toString() ?? '';
                final status = _attendanceStatus[studentId];

                return Container(
                  margin: EdgeInsets.only(bottom: 12.h),
                  padding: EdgeInsets.all(16.r),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.01),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Student Details Row
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20.r,
                            backgroundColor: const Color(0xFFEFF6FF), // Light blue avatar background
                            child: Text(
                              _getInitials(student['name']),
                              style: GoogleFonts.inter(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1D4ED8), // Darker blue initials
                              ),
                            ),
                          ),
                          SizedBox(width: 14.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  student['name'],
                                  style: GoogleFonts.inter(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  student['admission_no']?.toString().isNotEmpty == true
                                      ? student['admission_no']
                                      : 'R${index + 1}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.sp,
                                    color: const Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 14.h),
                      // Present & Absent Choice Buttons Row
                      Row(
                        children: [
                          _buildChoiceButton(
                            label: 'Present',
                            icon: Icons.check_rounded,
                            isSelected: status == 'P',
                            activeColor: const Color(0xFF10B981),
                            onTap: () {
                              setState(() {
                                _attendanceStatus[studentId] = 'P';
                              });
                            },
                          ),
                          SizedBox(width: 8.w),
                          _buildChoiceButton(
                            label: 'Absent',
                            icon: Icons.close_rounded,
                            isSelected: status == 'A',
                            activeColor: const Color(0xFFEF4444),
                            onTap: () {
                              setState(() {
                                _attendanceStatus[studentId] = 'A';
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
              // Padding at the bottom so the FAB doesn't overlay student card content
              SizedBox(height: 80.h),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildSubmitButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      // Only show bottom nav when NOT stacked on top of another route
      bottomNavigationBar: const TeacherBottomNavBar(activeIndex: 3),
    );
  }

  Widget _buildStatCard(String label, String value, Color valueColor) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.symmetric(vertical: 20.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 32.sp,
              fontWeight: FontWeight.w900,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkAllButton(String label, IconData icon, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14.sp, color: const Color(0xFF475569)),
              SizedBox(width: 6.w),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10.h),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.white,
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(
              color: isSelected ? activeColor : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14.sp,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
              SizedBox(width: 6.w),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: SizedBox(
        width: double.infinity,
        height: 48.h,
        child: ElevatedButton.icon(
          onPressed: _isSubmitting ? null : _submitAttendance,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0D7DDC),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30.r),
            ),
            elevation: 4,
          ),
          icon: _isSubmitting
              ? const SizedBox.shrink()
              : Icon(
                  Icons.description_outlined,
                  color: Colors.white,
                  size: 18.sp,
                ),
          label: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : Text(
                  'Submit Attendance (${_students.length} entries)',
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}
