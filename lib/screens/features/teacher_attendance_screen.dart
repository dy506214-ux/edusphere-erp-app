import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/api_service.dart';
import '../../services/student_service.dart';
import '../../services/academic_service.dart';
import '../../services/attendance_service.dart';
import '../../theme/colors.dart';
import '../main_screen.dart';
import '../../widgets/teacher_app_bar.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:developer' as dev;
import '../../services/socket_service.dart';
import 'package:edusphere/theme/typography.dart';

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
  String _selectedSection = 'A';
  DateTime _selectedDate = DateTime.now();

  final List<String> _classes = [];
  final List<String> _sections = [];

  // Store classes fetched directly from Supabase (with correct UUIDs)
  List<Map<String, dynamic>> _apiClasses = [];
  // Store all sections from Supabase keyed by classId
  List<Map<String, dynamic>> _allSections = [];

  /// Load classes & sections directly from REST API — IDs match Student table
  Future<void> _loadApiClasses() async {
    if (!mounted) return;
    try {
      final classesMap = await AcademicService.instance.getClasses();
      final sectionsMap = await AcademicService.instance.getSections();
      final classesRes = classesMap['classes'] ?? classesMap['data'] ?? [];
      final sectionsRes = sectionsMap['sections'] ?? sectionsMap['data'] ?? [];

      if (mounted) {
        setState(() {
          _allSections = List<Map<String, dynamic>>.from(sectionsRes);
          _apiClasses = List<Map<String, dynamic>>.from(classesRes)
              .where((c) {
                final name = c['name']?.toString() ?? '';
                return name == 'Class 8' || name == 'Class 9' || name == 'Class 10' ||
                       name == 'Grade 8' || name == 'Grade 9' || name == 'Grade 10';
              })
              .toList();
          _classes.clear();
          for (var c in _apiClasses) {
            final name = c['name']?.toString() ?? '';
            if (name.isNotEmpty && !_classes.contains(name)) {
              _classes.add(name);
            }
          }
          // Sort classes numerically where possible, then alphabetically
          _classes.sort((a, b) {
            final numA = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            final numB = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            if (numA != numB) return numA.compareTo(numB);
            return a.compareTo(b);
          });
          if (_classes.isNotEmpty) {
            _selectedClass = _classes.first;
            _updateSectionsForSelectedClass();
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading classes: $e');
    }
  }

  void _updateSectionsForSelectedClass() {
    if (_selectedClass == null) return;
    final cls = _apiClasses.firstWhere(
      (c) => c['name'] == _selectedClass,
      orElse: () => {},
    );
    _sections.clear();
    if (cls.isNotEmpty) {
      final classId = cls['id']?.toString();
      final secList = _allSections
          .where((s) => s['classId']?.toString() == classId)
          .toList();
      for (var s in secList) {
        final sName = s['name']?.toString() ?? '';
        if (sName.isNotEmpty) {
          _sections.add(sName);
        }
      }
    }
    _sections.sort();
    if (_sections.isNotEmpty) {
      _selectedSection = _sections.first;
    } else {
      _selectedSection = 'A';
    }
  }

  // ── Attendance data ──
  bool _isLoading = false;
  // ── Analytics data ──
  bool _isAnalyticsLoading = false;
  List<Map<String, dynamic>> _analyticsData = [];

  // ── Analytics filters ──
  String _analyticsClass = 'All Classes';
  String _analyticsSection = 'All Sections';
  DateTime _analyticsFromDate =
      DateTime.now().subtract(const Duration(days: 30));
  DateTime _analyticsToDate = DateTime.now();
  bool _analyticsLoaded = false;
  List<Map<String, dynamic>> _analyticsStudentData = [];
  final List<Map<String, dynamic>> _createdSlots = [];
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadApiClasses();
    _loadExistingSlotsForDate();
    _connectRealtime();
  }

  void _connectRealtime() {
    try {
      SocketService().on('attendanceMarked', _onRealtimeEvent);
      SocketService().on('ATTENDANCE_MARKED', _onRealtimeEvent);
      SocketService().on('ATTENDANCE_UPDATED', _onRealtimeEvent);
    } catch (e) {
      dev.log('Error subscribing to teacher attendance realtime: $e');
    }
  }

  void _onRealtimeEvent(dynamic payload) {
    if (mounted) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted) {
          _loadExistingSlotsForDate();
          _loadAnalytics();
        }
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    try {
      SocketService().off('attendanceMarked', _onRealtimeEvent);
      SocketService().off('ATTENDANCE_MARKED', _onRealtimeEvent);
      SocketService().off('ATTENDANCE_UPDATED', _onRealtimeEvent);
    } catch (_) {}
    super.dispose();
  }

  String _mapClassName(String dbName) {
    return dbName.replaceAll('Class', 'Grade');
  }

  Future<void> _loadExistingSlotsForDate() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      // 1. Fetch classes & sections if not already loaded
      if (_apiClasses.isEmpty) {
        final classesMap = await AcademicService.instance.getClasses();
        final sectionsMap = await AcademicService.instance.getSections();
        _allSections = List<Map<String, dynamic>>.from(sectionsMap['sections'] ?? sectionsMap['data'] ?? []);
        _apiClasses = List<Map<String, dynamic>>.from(classesMap['classes'] ?? classesMap['data'] ?? [])
            .where((c) {
              final name = c['name']?.toString() ?? '';
              return name == 'Class 8' || name == 'Class 9' || name == 'Class 10' ||
                     name == 'Grade 8' || name == 'Grade 9' || name == 'Grade 10';
            })
            .toList();
      }

      // 2. Fetch all attendance slots for this date
      final slotsRes = await AttendanceService.instance.getSlots(date: dateStr);
      final List<dynamic> slotsList = slotsRes['slots'] ??
                                      (slotsRes['data'] is Map ? slotsRes['data']['slots'] : null) ??
                                      slotsRes['data'] ?? [];

      // Get teacher class IDs to filter slots
      final teacherClassIds = _apiClasses.map((c) => c['id']?.toString()).toSet();

      final List<Map<String, dynamic>> loadedSlots = [];

      for (var slot in slotsList) {
        final classId = slot['classId']?.toString();
        // Skip slots that are not in the teacher's classes
        if (!teacherClassIds.contains(classId)) continue;

        final rawClass = slot['class']?['name']?.toString() ?? '';
        final secName = slot['section']?['name']?.toString() ?? '';
        final String displaySection = secName.isNotEmpty ? 'Section $secName' : 'All Sections';

        final bool isSub = slot['status']?.toString() == 'COMPLETED';
        final int totalCount = slot['studentCount'] as int? ?? 0;
        final int markedCount = slot['_count']?['records'] as int? ?? 0;

        loadedSlots.add({
          'id': slot['id']?.toString() ?? '',
          'class': rawClass,
          'classId': classId,
          'section': displaySection,
          'sectionId': slot['sectionId']?.toString(),
          'date': DateTime.parse(slot['date']?.toString() ?? dateStr),
          'isSubmitted': isSub,
          'studentCount': totalCount,
          'markedCount': markedCount,
        });
      }

      if (mounted) {
        setState(() {
          _createdSlots.clear();
          _createdSlots.addAll(loadedSlots);
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
      String? classId;
      String? sectionId;

      if (_analyticsClass != 'All Classes') {
        final cls = _apiClasses.firstWhere((c) => _mapClassName(c['name']?.toString() ?? '') == _analyticsClass, orElse: () => {});
        classId = cls['id']?.toString();
      }

      final queryParams = {
        if (classId != null) 'classId': classId,
        'startDate': DateFormat('yyyy-MM-dd').format(_analyticsFromDate),
        'endDate': DateFormat('yyyy-MM-dd').format(_analyticsToDate),
      };

      final response = await ApiService.instance.get('attendance/analytics', queryParams: queryParams);

      if (response['success'] == true) {
        final List<dynamic> breakdown = response['dailyBreakdown'] ?? [];
        final List<dynamic> matrix = response['studentMatrix'] ?? [];

        final List<Map<String, dynamic>> list = breakdown.map((d) => {
          'date': d['date']?.toString() ?? '',
          'className': _analyticsClass,
          'P': d['present'] ?? 0,
          'A': d['absent'] ?? 0,
          'L': d['late'] ?? 0,
          'total': d['total'] ?? 0,
        }).toList();

        final List<Map<String, dynamic>> studentList = matrix.map((s) {
          final stats = s['stats'] ?? {};
          return {
            'name': s['name']?.toString() ?? '',
            'class': _analyticsClass,
            'P': stats['presentDays'] ?? 0,
            'A': stats['absentDays'] ?? 0,
            'L': stats['lateDays'] ?? 0,
            'total': stats['markedDates'] ?? 0,
          };
        }).toList();

        if (mounted) {
          setState(() {
            _analyticsData = list;
            _isAnalyticsLoading = false;
            _analyticsLoaded = true;
            _analyticsStudentData = studentList;
          });
        }
      }
    } catch (e) {
      dev.log('Error loading analytics: $e');
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
          )),
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
      appBar:
          widget.showAppBar ? const TeacherAppBar(title: 'EduSphere') : null,
      bottomNavigationBar:
          widget.showAppBar ? const TeacherBottomNavBar(activeIndex: 3) : null,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mark daily attendance and view date-wise analytics',
                style: AppTypography.small
                    .copyWith(color: const Color(0xFF475569)),
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
              color: isSelected
                  ? const Color(0xFF0F172A)
                  : const Color(0xFF64748B),
            ),
            SizedBox(width: 6.w),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                  color: isSelected
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF64748B)),
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
            style:
                AppTypography.caption.copyWith(color: const Color(0xFF94A3B8)),
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
                      style: AppTypography.small
                          .copyWith(color: const Color(0xFF0F172A)),
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
      style: AppTypography.caption.copyWith(color: const Color(0xFF374151)),
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
                        style: AppTypography.small
                            .copyWith(color: const Color(0xFF94A3B8)),
                      )
                    : null,
                isExpanded: true,
                icon: Icon(Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF64748B), size: 22.sp),
                style: AppTypography.small
                    .copyWith(color: const Color(0xFF0F172A)),
                items: items
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(
                            c == 'Class 8'
                                ? '8th Grade'
                                : c == 'Class 9'
                                    ? '9th Grade'
                                    : c == 'Class 10'
                                        ? '10th Grade'
                                        : c,
                          ),
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
              Icon(Icons.access_time_rounded,
                  size: 20.sp, color: const Color(0xFF0F172A)),
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
                    style: AppTypography.caption
                        .copyWith(color: const Color(0xFF94A3B8)),
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
                style: AppTypography.small.copyWith(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFF0052CC), // Blue color matching mockup
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
                    style: AppTypography.caption
                        .copyWith(color: const Color(0xFF64748B), height: 1.5),
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
                final totalRecs = isSub
                    ? (slot['markedCount'] as int? ?? 0)
                    : (slot['studentCount'] as int? ?? 0);

                final rawClass = slot['class'] as String;
                final displayClass = rawClass.replaceAll('Class', 'Grade');
                final String displayTitle =
                    (slot['section'] == 'All Sections' ||
                            (slot['section'] as String).isEmpty)
                        ? displayClass
                        : '$displayClass - ${slot['section']}';

                return GestureDetector(
                  onTap: () => _openSlotAttendance(slot['id']?.toString() ?? '', slot),
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
                            color: isSub
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFFEF3C7),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isSub
                                ? Icons.check_rounded
                                : Icons.access_time_rounded,
                            color: isSub
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF59E0B),
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
                                style: AppTypography.small
                                    .copyWith(color: const Color(0xFF0F172A)),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                isSub
                                    ? '$totalRecs records marked'
                                    : '$totalRecs records',
                                style: AppTypography.caption
                                    .copyWith(color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 10.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: isSub
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Text(
                            isSub ? 'Done' : 'Open',
                            style: AppTypography.caption.copyWith(
                                color: isSub
                                    ? const Color(0xFF15803D)
                                    : const Color(0xFFB45309)),
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
                  style: AppTypography.caption
                      .copyWith(color: const Color(0xFF94A3B8), height: 1.5),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openSlotAttendance(String slotId, Map<String, dynamic> slotData) async {
    // Show progress indicator while loading students
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: AppColors.teacherPrimary),
      ),
    );

    try {
      final slotDetail = await AttendanceService.instance.getSlotWithStudents(slotId);
      if (mounted) Navigator.pop(context); // Dismiss loading dialog

      final dataMap = slotDetail['data'] is Map ? slotDetail['data'] : slotDetail;
      final List<dynamic> entities = dataMap['entities'] ?? slotDetail['entities'] ?? [];
      final Map<String, dynamic> attendanceMap = Map<String, dynamic>.from(dataMap['attendance'] ?? slotDetail['attendance'] ?? {});

      final List<Map<String, dynamic>> studentList = [];
      final Map<String, String> statusMap = {};

      for (var item in entities) {
        final String sId = item['id']?.toString() ?? '';
        if (sId.isEmpty) continue;
        studentList.add({
          'id': sId,
          'userId': item['userId']?.toString() ?? '',
          'name': item['name'] ?? 'Unknown',
          'admission_no': item['identifier'] ?? '',
          'roll_no': item['rollNumber']?.toString() ?? '',
          'qr_code': item['qrCode']?.toString() ?? '',
        });

        final String? statusVal = attendanceMap[sId]?.toString();
        if (statusVal != null) {
          String localStatus = 'P';
          if (statusVal == 'ABSENT' || statusVal == 'A') localStatus = 'A';
          if (statusVal == 'LATE' || statusVal == 'L') localStatus = 'L';
          if (statusVal == 'ON_LEAVE' || statusVal == 'LV') localStatus = 'LV';
          statusMap[sId] = localStatus;
        }
      }

      final isSub = slotData['isSubmitted'] as bool? ?? false;
      final className = slotData['class'] as String? ?? '';
      final classId = slotData['classId'] as String?;
      final section = slotData['section'] as String? ?? 'All Sections';
      final sectionId = slotData['sectionId'] as String?;
      final date = slotData['date'] as DateTime? ?? _selectedDate;

      if (!mounted) return;

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MarkAttendanceScreen(
            className: className,
            classId: classId,
            section: section,
            sectionId: sectionId,
            slotId: slotId,
            date: date,
            students: studentList,
            initialAttendanceStatus: statusMap,
            isAlreadySubmitted: isSub,
          ),
        ),
      );

      if (result != null && result is Map<String, dynamic>) {
        if (result['delete'] == true) {
          // Call delete slot API
          if (!mounted) return;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => const Center(
              child: CircularProgressIndicator(color: AppColors.teacherPrimary),
            ),
          );
          try {
            await AttendanceService.instance.deleteSlot(slotId);
            if (mounted) Navigator.pop(context); // Dismiss loading dialog
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Attendance slot deleted successfully!'),
                  backgroundColor: Color(0xFF10B981),
                ),
              );
            }
            _loadExistingSlotsForDate();
          } catch (e) {
            if (mounted) Navigator.pop(context); // Dismiss loading dialog
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to delete slot: $e'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          }
        } else {
          _loadExistingSlotsForDate();
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Dismiss loading dialog
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load slot details: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _createNewSlotFromSelection() async {
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
          (s) =>
              s['classId']?.toString() == classId &&
              s['name']?.toString() == secName,
          orElse: () => {},
        );
        if (sec.isNotEmpty) {
          sectionId = sec['id']?.toString();
        }
      }

      // Check if slot already exists in _createdSlots before sending API request
      final existingSlot = _createdSlots.firstWhere(
        (s) => s['classId']?.toString() == classId && s['sectionId']?.toString() == sectionId,
        orElse: () => {},
      );

      if (existingSlot.isNotEmpty) {
        setState(() {
          _isLoading = false;
        });
        final String existingSlotId = existingSlot['id']?.toString() ?? '';
        if (existingSlotId.isNotEmpty) {
          await _openSlotAttendance(existingSlotId, existingSlot);
          return;
        }
      }

      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      // Call API to create slot in the database
      final createRes = await AttendanceService.instance.createSlot(
        date: dateStr,
        classId: classId,
        sectionId: sectionId,
      );

      if (createRes['success'] == true) {
        final slotId = createRes['data']?['id']?.toString() ?? '';
        final displaySection = _selectedSection != 'All Sections' ? 'Section $_selectedSection' : 'All Sections';

        final newSlotData = {
          'class': _selectedClass,
          'classId': classId,
          'section': displaySection,
          'sectionId': sectionId,
          'date': _selectedDate,
          'isSubmitted': false,
        };

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text('Attendance slot created',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                ],
              ),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        // Reload all slots from database
        await _loadExistingSlotsForDate();

        // Automatically open the newly created slot
        if (slotId.isNotEmpty) {
          await _openSlotAttendance(slotId, newSlotData);
        }
      } else {
        throw createRes['message'] ?? 'Failed to create slot';
      }
    } catch (e) {
      debugPrint('Error creating slot: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create slot: $e',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    const Color green = Color(0xFF10B981);
    const Color red = Color(0xFFEF4444);
    const Color amber = Color(0xFFF59E0B);

    final allClasses = ['All Classes', ..._classes];
    final allSections = [
      'All Sections',
      ..._sections.where((s) => s != 'All Sections')
    ];

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
                    child: Icon(Icons.bar_chart_rounded,
                        size: 18.sp, color: primary),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Attendance Analytics',
                          style: GoogleFonts.outfit(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Date-wise breakdown, trends, and student matrix',
                          style: AppTypography.caption
                              .copyWith(color: const Color(0xFF94A3B8)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
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
                        Text('Class',
                            style: AppTypography.caption
                                .copyWith(color: const Color(0xFF374151))),
                        SizedBox(height: 6.h),
                        _buildAnalyticsDropdown(
                          value: _analyticsClass,
                          items: allClasses,
                          onChanged: (v) => setState(
                              () => _analyticsClass = v ?? 'All Classes'),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Section',
                            style: AppTypography.caption
                                .copyWith(color: const Color(0xFF374151))),
                        SizedBox(height: 6.h),
                        _buildAnalyticsDropdown(
                          value: _analyticsSection,
                          items: allSections,
                          onChanged: (v) => setState(
                              () => _analyticsSection = v ?? 'All Sections'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),

              // Row 2: From Date + To Date + Load button (Responsive layout)
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth > 550) {
                    return Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('From Date',
                                  style: AppTypography.caption
                                      .copyWith(color: const Color(0xFF374151))),
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
                                      )),
                                      child: child!,
                                    ),
                                  );
                                  if (picked != null) {
                                    setState(() => _analyticsFromDate = picked);
                                  }
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
                              Text('To Date',
                                  style: AppTypography.caption
                                      .copyWith(color: const Color(0xFF374151))),
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
                                      )),
                                      child: child!,
                                    ),
                                  );
                                  if (picked != null) {
                                    setState(() => _analyticsToDate = picked);
                                  }
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
                                  : Icon(Icons.trending_up_rounded,
                                      size: 16.sp, color: Colors.white),
                              label: Text(
                                'Load Analytics',
                                style: AppTypography.caption
                                    .copyWith(color: Colors.white),
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
                    );
                  } else {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('From Date',
                                      style: AppTypography.caption
                                          .copyWith(color: const Color(0xFF374151))),
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
                                          )),
                                          child: child!,
                                        ),
                                      );
                                      if (picked != null) {
                                        setState(() => _analyticsFromDate = picked);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('To Date',
                                      style: AppTypography.caption
                                          .copyWith(color: const Color(0xFF374151))),
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
                                          )),
                                          child: child!,
                                        ),
                                      );
                                      if (picked != null) {
                                        setState(() => _analyticsToDate = picked);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12.h),
                        SizedBox(
                          width: double.infinity,
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
                                : Icon(Icons.trending_up_rounded,
                                    size: 16.sp, color: Colors.white),
                            label: Text(
                              'Load Analytics',
                              style: AppTypography.caption
                                  .copyWith(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                },
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
                    style: AppTypography.caption
                        .copyWith(color: const Color(0xFF94A3B8)),
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
                  Icon(Icons.inbox_outlined,
                      size: 48.sp, color: const Color(0xFFCBD5E1)),
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
                    style: AppTypography.caption
                        .copyWith(color: const Color(0xFF94A3B8)),
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
              ..._analyticsData.map(
                  (r) => _buildNewAnalyticsCard(r, green, red, amber, primary)),

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
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              size: 18.sp, color: const Color(0xFF94A3B8)),
          style: AppTypography.caption.copyWith(color: const Color(0xFF0F172A)),
          onChanged: onChanged,
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
        ),
      ),
    );
  }

  // ── Date field for analytics
  Widget _buildAnalyticsDateField(
      {required DateTime date, required VoidCallback onTap}) {
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
                style: AppTypography.caption
                    .copyWith(color: const Color(0xFF0F172A)),
              ),
            ),
            Icon(Icons.calendar_today_rounded,
                size: 14.sp, color: const Color(0xFF94A3B8)),
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
    final pctColor = pct >= 90
        ? green
        : pct >= 75
            ? amber
            : red;

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0D7DDC).withValues(alpha: 0.08),
            const Color(0xFF0D7DDC).withValues(alpha: 0.02)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border:
            Border.all(color: const Color(0xFF0D7DDC).withValues(alpha: 0.2)),
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
                    style: AppTypography.caption
                        .copyWith(color: const Color(0xFF94A3B8)),
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: AppTypography.caption
                  .copyWith(color: color.withValues(alpha: 0.8)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
    final dateStr = record['date']?.toString() ?? '';
    final className = record['className']?.toString() ?? '';
    final present = record['P'] as int? ?? 0;
    final absent = record['A'] as int? ?? 0;
    final late = record['L'] as int? ?? 0;
    final total = record['total'] as int? ?? 0;
    final pct = total > 0 ? (present / total * 100).round() : 0;
    final pctColor = pct >= 90
        ? green
        : pct >= 75
            ? amber
            : red;

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
                    child: Icon(Icons.calendar_today_rounded,
                        size: 14.sp, color: primary),
                  ),
                  SizedBox(width: 10.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fmtDate,
                        style: AppTypography.caption
                            .copyWith(color: const Color(0xFF0F172A)),
                      ),
                      if (className.isNotEmpty)
                        Text(
                          className,
                          style: AppTypography.caption
                              .copyWith(color: const Color(0xFF94A3B8)),
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
                  style: AppTypography.caption.copyWith(color: pctColor),
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: AppTypography.caption
                  .copyWith(color: color.withValues(alpha: 0.75)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
                  child: Text('Student',
                      style: AppTypography.caption
                          .copyWith(color: const Color(0xFF475569))),
                ),
                SizedBox(
                  width: 44.w,
                  child: Center(
                      child: Text('P',
                          style: AppTypography.caption.copyWith(color: green))),
                ),
                SizedBox(
                  width: 44.w,
                  child: Center(
                      child: Text('A',
                          style: AppTypography.caption.copyWith(color: red))),
                ),
                SizedBox(
                  width: 44.w,
                  child: Center(
                      child: Text('L',
                          style: AppTypography.caption.copyWith(color: amber))),
                ),
                SizedBox(
                  width: 44.w,
                  child: Center(
                      child: Text('%',
                          style: AppTypography.caption
                              .copyWith(color: const Color(0xFF6366F1)))),
                ),
              ],
            ),
          ),

          // Rows — limit to 20 for perf
          ...(_analyticsStudentData
              .take(20)
              .toList()
              .asMap()
              .entries
              .map((entry) {
            final i = entry.key;
            final s = entry.value;
            final p = s['P'] as int? ?? 0;
            final a = s['A'] as int? ?? 0;
            final l = s['L'] as int? ?? 0;
            final tot = s['total'] as int? ?? 0;
            final pct = tot > 0 ? (p / tot * 100).round() : 0;
            final pctColor = pct >= 90
                ? green
                : pct >= 75
                    ? amber
                    : red;
            final name = (s['name'] as String? ?? '').isNotEmpty
                ? s['name'] as String
                : 'Student';

            return Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: i.isEven ? Colors.white : const Color(0xFFFAFAFC),
                border: Border(
                  bottom: BorderSide(
                      color: const Color(0xFFF1F5F9),
                      width: i < _analyticsStudentData.length - 1 ? 1 : 0),
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
                            style: AppTypography.caption
                                .copyWith(color: const Color(0xFF6366F1)),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            name,
                            style: AppTypography.caption
                                .copyWith(color: const Color(0xFF0F172A)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 44.w,
                    child: Center(
                      child: Text('$p',
                          style: AppTypography.caption.copyWith(color: green)),
                    ),
                  ),
                  SizedBox(
                    width: 44.w,
                    child: Center(
                      child: Text('$a',
                          style: AppTypography.caption.copyWith(color: red)),
                    ),
                  ),
                  SizedBox(
                    width: 44.w,
                    child: Center(
                      child: Text('$l',
                          style: AppTypography.caption.copyWith(color: amber)),
                    ),
                  ),
                  SizedBox(
                    width: 44.w,
                    child: Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 6.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: pctColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          '$pct%',
                          style:
                              AppTypography.caption.copyWith(color: pctColor),
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
                style: AppTypography.caption
                    .copyWith(color: const Color(0xFF94A3B8)),
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
  final String? classId;
  final String section;
  final String? sectionId;
  final String slotId;
  final DateTime date;
  final List<Map<String, dynamic>> students;
  final Map<String, String> initialAttendanceStatus;
  final bool isAlreadySubmitted;

  const MarkAttendanceScreen({
    super.key,
    required this.className,
    this.classId,
    required this.section,
    this.sectionId,
    required this.slotId,
    required this.date,
    required this.students,
    required this.initialAttendanceStatus,
    required this.isAlreadySubmitted,
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

    // Auto-mark all unmarked students as Present to save teacher time
    if (!_isAlreadySubmitted) {
      for (var student in _students) {
        final String studentId = student['id']?.toString() ?? '';
        if (studentId.isNotEmpty && _attendanceStatus[studentId] == null) {
          _attendanceStatus[studentId] = 'P';
        }
      }
    }
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Unmarked Students',
            style:
                GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          content: Text(
            '${unmarkedStudents.length} student(s) are not marked.\n\nDo you want to mark them as Absent and submit?',
            style:
                AppTypography.caption.copyWith(color: const Color(0xFF475569)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel',
                  style: GoogleFonts.inter(color: const Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D7DDC),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('Mark Absent & Submit',
                  style: GoogleFonts.inter(
                      color: Colors.white, fontWeight: FontWeight.w700)),
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
      final List<Map<String, dynamic>> attendanceData = [];
      for (var student in _students) {
        final String studentId = student['id']?.toString() ?? '';
        if (studentId.isEmpty) continue;
        final statusLocal = _attendanceStatus[studentId] ?? 'A';

        String statusEnum = 'PRESENT';
        if (statusLocal == 'A') statusEnum = 'ABSENT';
        if (statusLocal == 'L') statusEnum = 'LATE';
        if (statusLocal == 'LV') statusEnum = 'ON_LEAVE';

        attendanceData.add({
          'entityId': studentId,
          'status': statusEnum,
        });
      }

      await AttendanceService.instance.submitSlotAttendance(widget.slotId, attendanceData);

      if (mounted) {
        try {
          SocketService().emit('ATTENDANCE_UPDATED', {'source': 'teacher_bulk_attendance'});
          SocketService().emit('ATTENDANCE_MARKED', {'source': 'teacher_bulk_attendance'});
          SocketService().emit('attendanceMarked', {'source': 'teacher_bulk_attendance'});
        } catch (e) {
          debugPrint('Socket emit error: $e');
        }

        setState(() {
          _isAlreadySubmitted = true;
          _isSubmitting = false;
        });

        // Emit socket event to ensure students see the update in real-time
        try {
          final socketPayload = {
            'date': dbDateStr,
            'attendanceData': attendanceData,
          };
          SocketService().emit('ATTENDANCE_UPDATED', socketPayload);
          SocketService().emit('ATTENDANCE_MARKED', socketPayload);
          SocketService().emit('attendanceMarked', socketPayload);
        } catch (_) {}

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Attendance submitted successfully!',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );

        Navigator.pop(context, {
          'success': true,
        });
      }
    } catch (e) {
      debugPrint('Error saving attendance: $e');
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Failed to submit: $e',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Stats calculation
    final totalCount = _students.length;
    final presentCount =
        _attendanceStatus.values.where((status) => status == 'P').length;
    final absentCount =
        _attendanceStatus.values.where((status) => status == 'A').length;
    final bool canGoBack = Navigator.canPop(context);

    return Scaffold(
      key: _scaffoldKey,
      // Only show drawer when NOT pushed on top of another route
      drawer: canGoBack
          ? null
          : const EduSphereDrawer(role: 'teacher', activeLabel: 'Attendance'),
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
                  border:
                      Border.all(color: const Color(0xFF0052CC), width: 1.5),
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
                              Flexible(
                                child: Text(
                                  '${widget.className.replaceAll('Class', 'Grade')} - ${widget.section}',
                                  style: AppTypography.small
                                      .copyWith(color: const Color(0xFF0F172A)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8.w, vertical: 2.h),
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
                                      _isAlreadySubmitted
                                          ? 'Submitted'
                                          : 'Open',
                                      style: AppTypography.caption.copyWith(
                                          color: _isAlreadySubmitted
                                              ? const Color(0xFF065F46)
                                              : const Color(0xFF92400E)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            '${_students.length} records',
                            style: AppTypography.caption
                                .copyWith(color: const Color(0xFF64748B)),
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

              // 2. Statistics Grid
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard('Total Students', '$totalCount', const Color(0xFF0F172A)),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: _buildStatCard('Present', '$presentCount', const Color(0xFF10B981)),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: _buildStatCard('Absent', '$absentCount', const Color(0xFFEF4444)),
                  ),
                ],
              ),
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
                        style: AppTypography.caption
                            .copyWith(color: const Color(0xFF94A3B8)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  );

                  final buttonsRow = Row(
                    children: [
                      _buildMarkAllButton('Mark All Present',
                          Icons.check_rounded, () => _markAll('P')),
                      SizedBox(width: 8.w),
                      _buildMarkAllButton('Mark All Absent',
                          Icons.close_rounded, () => _markAll('A')),
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
                            backgroundColor: const Color(0xFFEFF6FF),
                            child: Text(
                              _getInitials(student['name']),
                              style: AppTypography.small.copyWith(color: const Color(0xFF1D4ED8)),
                            ),
                          ),
                          SizedBox(width: 14.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  student['name'],
                                  style: AppTypography.small.copyWith(color: const Color(0xFF0F172A)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 4.h),
                                Row(
                                  children: [
                                    Text(
                                      'Adm: ${student['admission_no']}',
                                      style: AppTypography.caption.copyWith(color: const Color(0xFF64748B)),
                                    ),
                                    if (student['roll_no'] != null && student['roll_no'].toString().isNotEmpty) ...[
                                      SizedBox(width: 12.w),
                                      Text(
                                        'Roll: ${student['roll_no']}',
                                        style: AppTypography.caption.copyWith(color: const Color(0xFF64748B)),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (student['qr_code'] != null && student['qr_code'].toString().isNotEmpty)
                            Container(
                              width: 36.w,
                              height: 36.h,
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(5.r),
                                child: student['qr_code'].toString().startsWith('data:image')
                                    ? Image.memory(
                                        base64Decode(student['qr_code'].toString().split(',').last),
                                        fit: BoxFit.cover,
                                      )
                                    : QrImageView(
                                        data: student['qr_code'].toString(),
                                        version: QrVersions.auto,
                                        padding: EdgeInsets.all(2.r),
                                      ),
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
            style:
                AppTypography.caption.copyWith(color: const Color(0xFF64748B)),
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
              Flexible(
                child: Text(
                  label,
                  style: AppTypography.caption
                      .copyWith(color: const Color(0xFF475569)),
                  overflow: TextOverflow.ellipsis,
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
              Flexible(
                child: Text(
                  label,
                  style: AppTypography.caption.copyWith(
                      color: isSelected ? Colors.white : const Color(0xFF475569)),
                  overflow: TextOverflow.ellipsis,
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
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : Text(
                  'Submit Attendance (${_students.length} entries)',
                  style: AppTypography.caption.copyWith(color: Colors.white),
                ),
        ),
      ),
    );
  }
}
