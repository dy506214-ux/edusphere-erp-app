import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:intl/intl.dart' as intl;

class ExamScheduleScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  final bool showAppBar;
  final ValueChanged<int>? onNavigate;

  const ExamScheduleScreen({
    super.key,
    this.onOpenDrawer,
    this.showAppBar = true,
    this.onNavigate,
  });

  @override
  State<ExamScheduleScreen> createState() => _ExamScheduleScreenState();
}

class _ExamScheduleScreenState extends State<ExamScheduleScreen> {
  List<Map<String, dynamic>> _exams = [];
  bool _isLoading = true;
  String _teacherName = 'Arjun Singh';

  String _searchQuery = '';
  String _selectedYear = 'All Years';
  String _selectedClass = 'All Classes';
  String _selectedTerm = 'All Terms';



  @override
  void initState() {
    super.initState();
    _loadTeacherName();
    _loadExams();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────
  // DATA
  // ─────────────────────────────────────────────────────────

  Future<void> _loadTeacherName() async {
    final prefs = await SharedPreferences.getInstance();
    final name =
        prefs.getString('teacher_name') ?? prefs.getString('user_name');
    if (name != null && name.isNotEmpty && mounted) {
      setState(() => _teacherName = name);
    }
  }

  String _getInitials(String name) {
    try {
      final parts = name.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      if (parts.isNotEmpty && parts[0].isNotEmpty) {
        return parts[0].substring(0, math.min(2, parts[0].length)).toUpperCase();
      }
    } catch (_) {}
    return 'AS';
  }


  List<Map<String, dynamic>> _seedExams() => [
        {
          'name': 'Half Yearly Examination',
          'class': 'Grade 1',
          'term': '-',
          'start_date': '19/06/2026',
          'status': 'Published',
          'subject': 'All Subjects',
          'time': '10:00 AM',
          'room': 'Hall A',
          'duration': '3 hrs',
          'syllabus': 'Full Syllabus',
          'academic_year': '2026-2027',
        },
      ];

  Future<void> _loadExams() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('examinations_schedule_list');
      if (raw != null) {
        final decoded = json.decode(raw) as List<dynamic>;
        final list = decoded
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        setState(() => _exams = list.isNotEmpty ? list : _seedExams());
      } else {
        final seed = _seedExams();
        await prefs.setString(
            'examinations_schedule_list', json.encode(seed));
        setState(() => _exams = seed);
      }
    } catch (_) {
      setState(() => _exams = _seedExams());
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveExams() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('examinations_schedule_list', json.encode(_exams));
  }

  List<Map<String, dynamic>> get _filteredExams {
    return _exams.where((e) {
      final name = (e['name'] as String? ??
              e['subject'] as String? ??
              '')
          .toLowerCase();
      if (!name.contains(_searchQuery.toLowerCase())) { return false; }
      if (_selectedYear != 'All Years' &&
          e['academic_year'] != _selectedYear) { return false; }
      if (_selectedClass != 'All Classes' &&
          e['class'] != _selectedClass) { return false; }
      if (_selectedTerm != 'All Terms' &&
          e['term'] != _selectedTerm) { return false; }
      return true;
    }).toList();
  }



  // ─────────────────────────────────────────────────────────
  // CREATE / EDIT
  // ─────────────────────────────────────────────────────────

  void _showCreateExamDialog() {
    final nameCtrl = TextEditingController();
    final dateCtrl =
        TextEditingController(text: intl.DateFormat('dd/MM/yyyy').format(DateTime.now().add(const Duration(days: 14))));
    final roomCtrl = TextEditingController();
    final syllabusCtrl = TextEditingController();
    final durationCtrl = TextEditingController(text: '3 hrs');
    final timeCtrl = TextEditingController(text: '10:00 AM');
    String selectedClass = 'Grade 1';
    String selectedTerm = '-';
    String selectedStatus = 'Published';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setD) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r)),
          title: Text('Schedule Exam',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(nameCtrl, 'Exam Name', 'e.g. Half Yearly'),
                SizedBox(height: 10.h),
                _dialogField(dateCtrl, 'Start Date', 'dd/MM/yyyy'),
                SizedBox(height: 10.h),
                _dialogField(timeCtrl, 'Time', '10:00 AM'),
                SizedBox(height: 10.h),
                DropdownButtonFormField<String>(
                  initialValue: selectedClass,
                  decoration: _dec('Class'),
                  items: ['Grade 1', 'Grade 2', 'Grade 3', 'Class 10', 'Class 11', 'Class 12']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setD(() => selectedClass = v!),
                ),
                SizedBox(height: 10.h),
                DropdownButtonFormField<String>(
                  initialValue: selectedTerm,
                  decoration: _dec('Term'),
                  items: ['-', 'Term 1', 'Term 2', 'Final Term']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setD(() => selectedTerm = v!),
                ),
                SizedBox(height: 10.h),
                DropdownButtonFormField<String>(
                  initialValue: selectedStatus,
                  decoration: _dec('Status'),
                  items: ['Published', 'Draft', 'Upcoming']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setD(() => selectedStatus = v!),
                ),
                SizedBox(height: 10.h),
                _dialogField(roomCtrl, 'Room / Hall', 'e.g. Hall A'),
                SizedBox(height: 10.h),
                _dialogField(durationCtrl, 'Duration', 'e.g. 3 hrs'),
                SizedBox(height: 10.h),
                _dialogField(syllabusCtrl, 'Syllabus', 'e.g. Ch 1-8'),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB)),
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                setState(() {
                  _exams.insert(0, {
                    'name': nameCtrl.text.trim(),
                    'class': selectedClass,
                    'term': selectedTerm,
                    'start_date': dateCtrl.text.trim(),
                    'status': selectedStatus,
                    'time': timeCtrl.text.trim(),
                    'room': roomCtrl.text.trim(),
                    'duration': durationCtrl.text.trim(),
                    'syllabus': syllabusCtrl.text.trim(),
                    'academic_year': '2026-2027',
                    'subject': 'All Subjects',
                  });
                });
                _saveExams();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Exam scheduled!',
                      style: GoogleFonts.inter()),
                  backgroundColor: const Color(0xFF2563EB),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r)),
                ));
              },
              child: const Text('Create',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  TextField _dialogField(
      TextEditingController ctrl, String label, String hint) {
    return TextField(
      controller: ctrl,
      decoration: _dec(label, hint: hint),
    );
  }

  InputDecoration _dec(String label, {String hint = ''}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: GoogleFonts.inter(fontSize: 12.sp),
      contentPadding:
          EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r)),
    );
  }

  void _showExamActions(Map<String, dynamic> exam) {
    final idx = _exams.indexOf(exam);
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.all(20.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40.w,
              height: 4.h,
              margin: EdgeInsets.only(bottom: 16.h),
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(4.r),
              ),
            ),
            Text(
              exam['name'] as String? ?? 'Exam',
              style: GoogleFonts.outfit(
                  fontSize: 16.sp, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 16.h),
            ListTile(
              leading: const Icon(Icons.edit_outlined,
                  color: Color(0xFF2563EB)),
              title: Text('Edit Exam',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: Color(0xFFEF4444)),
              title: Text('Delete Exam',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFEF4444))),
              onTap: () {
                setState(() => _exams.removeAt(idx));
                _saveExams();
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _onNavTap(int index) {
    if (index == 3) return;
    if (widget.onNavigate != null) {
      widget.onNavigate!(index);
    } else {
      Navigator.pop(context, index);
    }
  }

  // ─────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(_teacherName);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              leading: Navigator.canPop(context)
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: Color(0xFF0F172A)),
                      onPressed: () => Navigator.pop(context),
                    )
                  : IconButton(
                      icon: const Icon(Icons.menu,
                          color: Color(0xFF0F172A)),
                      onPressed: widget.onOpenDrawer ?? () {},
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
                  icon: const Icon(Icons.notifications_none_outlined,
                      color: Color(0xFF0F172A)),
                  onPressed: () {},
                ),
                Padding(
                  padding: EdgeInsets.only(right: 16.w, left: 4.w),
                  child: Center(
                    child: CircleAvatar(
                      radius: 16.r,
                      backgroundColor: const Color(0xFFEFF6FF),
                      child: Text(
                        initials,
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF2563EB),
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
          Positioned.fill(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding:
                  EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 100.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Page heading
                  Text(
                    'Examinations',
                    style: GoogleFonts.outfit(
                      fontSize: 26.sp,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Manage exams, schedules, and results',
                    style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  SizedBox(height: 20.h),

                  // Charts row
                  _buildChartsRow(),
                  SizedBox(height: 16.h),

                  // Schedule card
                  _buildScheduleCard(),
                ],
              ),
            ),
          ),


        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ─────────────────────────────────────────────────────────
  // CHARTS ROW
  // ─────────────────────────────────────────────────────────

  Widget _buildChartsRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildRadarCard()),
        SizedBox(width: 12.w),
        Expanded(child: _buildLineChartCard()),
      ],
    );
  }

  /// Left card — Spider / Radar chart
  Widget _buildRadarCard() {
    return Container(
      padding: EdgeInsets.all(14.r),
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
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(Icons.bar_chart_rounded,
                    size: 16.sp, color: const Color(0xFF7C3AED)),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Subject Performance',
                      style: GoogleFonts.outfit(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Average marks distribution\nacross subjects',
                      style: GoogleFonts.inter(
                        fontSize: 8.5.sp,
                        color: const Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          SizedBox(
            height: 170.h,
            child: CustomPaint(
              size: Size(double.infinity, 170.h),
              painter: _RadarChartPainter(
                labels: const [
                  'Hindi',
                  'English',
                  'Science',
                  'Mathematics',
                  'Social Studies',
                ],
                values: const [0.85, 0.78, 0.70, 0.65, 0.72],
                fillColor:
                    const Color(0xFFEC4899).withValues(alpha: 0.3),
                strokeColor: const Color(0xFFEC4899),
                gridColor: const Color(0xFFE2E8F0),
                labelStyle: GoogleFonts.inter(
                  fontSize: 8.sp,
                  color: const Color(0xFF475569),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Right card — Line chart
  Widget _buildLineChartCard() {
    return Container(
      padding: EdgeInsets.all(14.r),
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
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(Icons.trending_up_rounded,
                    size: 16.sp, color: const Color(0xFF059669)),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Average Score Trend',
                      style: GoogleFonts.outfit(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Class average performance\nover time',
                      style: GoogleFonts.inter(
                        fontSize: 8.5.sp,
                        color: const Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          SizedBox(
            height: 150.h,
            child: CustomPaint(
              size: Size(double.infinity, 150.h),
              painter: _LineChartPainter(
                yLabels: const ['100', '75', '50', '25', '0'],
                xLabels: const [
                  "May'01", "May'07", "May'13", "May'19", "May'25"
                ],
                dataPoints: const [0.80, 0.79, 0.82, 0.80, 0.83],
                lineColor: const Color(0xFF2563EB),
                gridColor: const Color(0xFFE2E8F0),
                labelStyle: GoogleFonts.inter(
                  fontSize: 7.sp,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ),
          ),
          SizedBox(height: 8.h),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8.w,
                height: 8.w,
                decoration: const BoxDecoration(
                  color: Color(0xFF2563EB),
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 4.w),
              Text(
                'average',
                style: GoogleFonts.inter(
                  fontSize: 9.sp,
                  color: const Color(0xFF475569),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // SCHEDULE CARD (Table layout)
  // ─────────────────────────────────────────────────────────

  Widget _buildScheduleCard() {
    final filtered = _filteredExams;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: EdgeInsets.all(16.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(Icons.calendar_month_rounded,
                    size: 20.sp, color: const Color(0xFF2563EB)),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Examination Schedule',
                      style: GoogleFonts.outfit(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'View and manage all scheduled examinations (${filtered.length} total)',
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              // Add button
              GestureDetector(
                onTap: _showCreateExamDialog,
                child: Container(
                  padding: EdgeInsets.all(6.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(Icons.add_rounded,
                      color: Colors.white, size: 18.sp),
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),

          // Search label
          Text(
            'Search',
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF334155),
            ),
          ),
          SizedBox(height: 8.h),

          // Search field
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            style: GoogleFonts.inter(
                fontSize: 13.sp, color: const Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: 'Search exams by name...',
              hintStyle: GoogleFonts.inter(
                  fontSize: 13.sp, color: const Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: Color(0xFF94A3B8)),
              contentPadding: EdgeInsets.symmetric(
                  horizontal: 14.w, vertical: 12.h),
              filled: true,
              fillColor: Colors.white,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide: const BorderSide(
                    color: Color(0xFF3B82F6), width: 1.5),
              ),
            ),
          ),
          SizedBox(height: 16.h),

          // Filters
          Row(
            children: [
              Expanded(
                child: _buildFilterDropdown(
                  'Academic Year',
                  _selectedYear,
                  ['All Years', '2026-2027', '2025-2026'],
                  (v) => setState(() => _selectedYear = v!),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _buildFilterDropdown(
                  'Class',
                  _selectedClass,
                  ['All Classes', 'Grade 1', 'Grade 2', 'Grade 3',
                    'Class 10', 'Class 11', 'Class 12'],
                  (v) => setState(() => _selectedClass = v!),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _buildFilterDropdown(
                  'Term',
                  _selectedTerm,
                  ['All Terms', '-', 'Term 1', 'Term 2', 'Final Term'],
                  (v) => setState(() => _selectedTerm = v!),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // Table
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(
                    color: Color(0xFF2563EB)),
              ),
            )
          else if (filtered.isEmpty)
            _buildEmptyState()
          else
            _buildExamTable(filtered),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String currentValue,
    List<String> items,
    void Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF475569),
          ),
        ),
        SizedBox(height: 4.h),
        Container(
          height: 38.h,
          padding: EdgeInsets.symmetric(horizontal: 8.w),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentValue,
              icon: Icon(Icons.keyboard_arrow_down_rounded,
                  color: const Color(0xFF64748B), size: 16.sp),
              isExpanded: true,
              style: GoogleFonts.inter(
                  fontSize: 10.sp,
                  color: const Color(0xFF1E293B),
                  fontWeight: FontWeight.w600),
              items: items
                  .map((e) =>
                      DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 32.h),
      child: Column(
        children: [
          Icon(Icons.calendar_today_rounded,
              size: 48.sp, color: const Color(0xFFCBD5E1)),
          SizedBox(height: 16.h),
          Text('No exams found',
              style: GoogleFonts.outfit(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A))),
          SizedBox(height: 6.h),
          Text('Get started by creating your first exam',
              style: GoogleFonts.inter(
                  fontSize: 11.sp, color: const Color(0xFF64748B))),
          SizedBox(height: 24.h),
        ],
      ),
    );
  }

  /// Table matching the image: Exam Name | Class | Term | Start Date | Status | Actions
  Widget _buildExamTable(List<Map<String, dynamic>> list) {
    return Column(
      children: [
        // Header row
        Container(
          padding:
              EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(10.r),
              topRight: Radius.circular(10.r),
            ),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Text('Exam Name',
                    style: _headerStyle()),
              ),
              Expanded(
                flex: 3,
                child: Text('Class', style: _headerStyle()),
              ),
              Expanded(
                flex: 2,
                child: Text('Term', style: _headerStyle()),
              ),
              Expanded(
                flex: 3,
                child: Text('Start Date', style: _headerStyle()),
              ),
              Expanded(
                flex: 3,
                child: Text('Status', style: _headerStyle()),
              ),
              SizedBox(
                width: 32.w,
                child: Text('Actions', style: _headerStyle()),
              ),
            ],
          ),
        ),

        // Data rows
        ...list.asMap().entries.map((entry) {
          final e = entry.value;
          final isLast = entry.key == list.length - 1;
          final status = e['status'] as String? ?? 'Published';
          final isPublished = status == 'Published';
          final statusColor = isPublished
              ? const Color(0xFF059669)
              : status == 'Draft'
                  ? const Color(0xFF64748B)
                  : const Color(0xFF0284C7);
          final statusBg = isPublished
              ? const Color(0xFFD1FAE5)
              : status == 'Draft'
                  ? const Color(0xFFF1F5F9)
                  : const Color(0xFFE0F2FE);

          return Container(
            padding: EdgeInsets.symmetric(
                horizontal: 12.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                left: const BorderSide(color: Color(0xFFE2E8F0)),
                right: const BorderSide(color: Color(0xFFE2E8F0)),
                bottom: BorderSide(
                  color: isLast
                      ? const Color(0xFFE2E8F0)
                      : const Color(0xFFF1F5F9),
                ),
              ),
              borderRadius: isLast
                  ? BorderRadius.only(
                      bottomLeft: Radius.circular(10.r),
                      bottomRight: Radius.circular(10.r),
                    )
                  : null,
            ),
            child: Row(
              children: [
                // Exam Name
                Expanded(
                  flex: 5,
                  child: Text(
                    e['name'] as String? ??
                        e['subject'] as String? ??
                        'Untitled',
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Class
                Expanded(
                  flex: 3,
                  child: Text(
                    e['class'] as String? ?? '-',
                    style: _cellStyle(),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Term
                Expanded(
                  flex: 2,
                  child: Text(
                    e['term'] as String? ?? '-',
                    style: _cellStyle(),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Start Date
                Expanded(
                  flex: 3,
                  child: Text(
                    e['start_date'] as String? ??
                        e['date'] as String? ??
                        '-',
                    style: _cellStyle(),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Status badge
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 6.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      status,
                      style: GoogleFonts.inter(
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                // Actions
                SizedBox(
                  width: 32.w,
                  child: GestureDetector(
                    onTap: () => _showExamActions(e),
                    child: Icon(
                      Icons.more_vert_rounded,
                      color: const Color(0xFF64748B),
                      size: 18.sp,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  TextStyle _headerStyle() => GoogleFonts.inter(
        fontSize: 10.sp,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF475569),
      );

  TextStyle _cellStyle() => GoogleFonts.inter(
        fontSize: 10.sp,
        fontWeight: FontWeight.w500,
        color: const Color(0xFF334155),
      );

  // ─────────────────────────────────────────────────────────
  // ASSISTANT
  // ─────────────────────────────────────────────────────────



  // ─────────────────────────────────────────────────────────
  // BOTTOM NAV
  // ─────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: 8.w, vertical: 8.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.dashboard_rounded,
                label: 'Dashboard',
                selected: false,
                color: const Color(0xFF2563EB),
                onTap: () => _onNavTap(0),
              ),
              _NavItem(
                icon: Icons.calendar_month_rounded,
                label: 'Academic\nCalendar',
                selected: false,
                color: const Color(0xFF2563EB),
                onTap: () => _onNavTap(1),
              ),
              _NavItem(
                icon: Icons.people_outline_rounded,
                label: 'Students',
                selected: false,
                color: const Color(0xFF2563EB),
                onTap: () => _onNavTap(2),
              ),
              _NavItem(
                icon: Icons.description_rounded,
                label: 'Examinations',
                selected: true,
                color: const Color(0xFF2563EB),
                onTap: () => _onNavTap(3),
              ),
              _NavItem(
                icon: Icons.check_box_outlined,
                label: 'Assignments',
                selected: false,
                color: const Color(0xFF2563EB),
                onTap: () => _onNavTap(4),
              ),
              _NavItem(
                icon: Icons.more_horiz_rounded,
                label: 'More',
                selected: false,
                color: const Color(0xFF2563EB),
                onTap: () => _onNavTap(5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// RADAR CHART PAINTER
// ═══════════════════════════════════════════════════════════

class _RadarChartPainter extends CustomPainter {
  final List<String> labels;
  final List<double> values; // 0.0 – 1.0
  final Color fillColor;
  final Color strokeColor;
  final Color gridColor;
  final TextStyle labelStyle;

  _RadarChartPainter({
    required this.labels,
    required this.values,
    required this.fillColor,
    required this.strokeColor,
    required this.gridColor,
    required this.labelStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    // Leave margin for labels
    const labelMargin = 22.0;
    final maxRadius = math.min(cx, cy) - labelMargin;
    final n = labels.length;
    const rings = 4;

    // Draw grid rings
    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int r = 1; r <= rings; r++) {
      final radius = maxRadius * r / rings;
      final path = Path();
      for (int i = 0; i < n; i++) {
        final angle = 2 * math.pi * i / n - math.pi / 2;
        final x = cx + radius * math.cos(angle);
        final y = cy + radius * math.sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // Draw axis lines
    for (int i = 0; i < n; i++) {
      final angle = 2 * math.pi * i / n - math.pi / 2;
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + maxRadius * math.cos(angle),
            cy + maxRadius * math.sin(angle)),
        gridPaint,
      );
    }

    // Draw data polygon
    final dataPath = Path();
    for (int i = 0; i < n; i++) {
      final angle = 2 * math.pi * i / n - math.pi / 2;
      final r = maxRadius * (i < values.length ? values[i] : 0.5);
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) {
        dataPath.moveTo(x, y);
      } else {
        dataPath.lineTo(x, y);
      }
    }
    dataPath.close();

    canvas.drawPath(
        dataPath, Paint()..color = fillColor..style = PaintingStyle.fill);
    canvas.drawPath(
        dataPath,
        Paint()
          ..color = strokeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);

    // Draw dots at vertices
    final dotPaint = Paint()..color = strokeColor;
    for (int i = 0; i < n; i++) {
      final angle = 2 * math.pi * i / n - math.pi / 2;
      final r = maxRadius * (i < values.length ? values[i] : 0.5);
      canvas.drawCircle(
        Offset(cx + r * math.cos(angle), cy + r * math.sin(angle)),
        3.0,
        dotPaint,
      );
    }

    // Draw labels
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < n; i++) {
      final angle = 2 * math.pi * i / n - math.pi / 2;
      final labelR = maxRadius + labelMargin - 4;
      final lx = cx + labelR * math.cos(angle);
      final ly = cy + labelR * math.sin(angle);

      tp.text = TextSpan(text: labels[i], style: labelStyle);
      tp.layout();
      tp.paint(
        canvas,
        Offset(lx - tp.width / 2, ly - tp.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RadarChartPainter old) => true;
}

// ═══════════════════════════════════════════════════════════
// LINE CHART PAINTER
// ═══════════════════════════════════════════════════════════

class _LineChartPainter extends CustomPainter {
  final List<String> yLabels;
  final List<String> xLabels;
  final List<double> dataPoints; // 0.0 – 1.0 (fraction of Y range)
  final Color lineColor;
  final Color gridColor;
  final TextStyle labelStyle;

  _LineChartPainter({
    required this.yLabels,
    required this.xLabels,
    required this.dataPoints,
    required this.lineColor,
    required this.gridColor,
    required this.labelStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 28.0;
    const bottomPad = 18.0;
    const topPad = 6.0;
    final chartW = size.width - leftPad;
    final chartH = size.height - bottomPad - topPad;

    final tp = TextPainter(textDirection: TextDirection.ltr);

    // Draw horizontal grid lines + Y labels
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;

    for (int i = 0; i < yLabels.length; i++) {
      final frac = i / (yLabels.length - 1);
      final y = topPad + frac * chartH;

      canvas.drawLine(
          Offset(leftPad, y), Offset(size.width, y), gridPaint);

      tp.text = TextSpan(text: yLabels[i], style: labelStyle);
      tp.layout();
      tp.paint(
          canvas, Offset(0, y - tp.height / 2));
    }

    // Draw X labels
    for (int i = 0; i < xLabels.length; i++) {
      final frac = i / (xLabels.length - 1);
      final x = leftPad + frac * chartW;

      tp.text = TextSpan(text: xLabels[i], style: labelStyle);
      tp.layout();
      tp.paint(canvas,
          Offset(x - tp.width / 2, topPad + chartH + 4));
    }

    if (dataPoints.isEmpty) return;

    // Compute actual pixel points
    final pts = <Offset>[];
    for (int i = 0; i < dataPoints.length; i++) {
      final frac = i / (dataPoints.length - 1);
      final x = leftPad + frac * chartW;
      // dataPoints are 0.0–1.0 representing fraction of 100
      // But y-axis is inverted (top=high)
      final y = topPad + (1.0 - dataPoints[i]) * chartH;
      pts.add(Offset(x, y));
    }

    // Draw line
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 1; i < pts.length; i++) {
      final prev = pts[i - 1];
      final curr = pts[i];
      final mid = (prev.dx + curr.dx) / 2;
      path.cubicTo(mid, prev.dy, mid, curr.dy, curr.dx, curr.dy);
    }
    canvas.drawPath(path, linePaint);

    // Draw dots
    final dotFill = Paint()..color = lineColor;
    final dotBg = Paint()..color = Colors.white;
    for (final pt in pts) {
      canvas.drawCircle(pt, 4.0, dotFill);
      canvas.drawCircle(pt, 2.0, dotBg);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) => true;
}

// ═══════════════════════════════════════════════════════════
// NAV ITEM
// ═══════════════════════════════════════════════════════════

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding:
              EdgeInsets.symmetric(horizontal: 4.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: selected ? color : const Color(0xFF94A3B8),
                size: 22.sp,
              ),
              SizedBox(height: 2.h),
              Text(
                label,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: GoogleFonts.inter(
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w700,
                  color:
                      selected ? color : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
