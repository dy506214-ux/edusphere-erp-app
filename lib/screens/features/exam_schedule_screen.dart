import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart' as intl;

class ExamScheduleScreen extends StatefulWidget {
  const ExamScheduleScreen({super.key});

  @override
  State<ExamScheduleScreen> createState() => _ExamScheduleScreenState();
}

class _ExamScheduleScreenState extends State<ExamScheduleScreen> {
  // ── Database State ──
  List<Map<String, dynamic>> _exams = [];
  
  // ── Filters & Search ──
  String _searchQuery = '';
  String _selectedYear = 'All Years';
  String _selectedClass = 'All Classes';
  String _selectedTerm = 'All Terms';

  // ── Chat Assistant State ──
  bool _isChatOpen = false;
  bool _showAssistantBubble = true;
  final List<Map<String, String>> _chatMessages = [];
  final _chatInputCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadExams();
    _initChat();
  }

  @override
  void dispose() {
    _chatInputCtrl.dispose();
    super.dispose();
  }

  // ═════════════════════════════════════════════════════════════════════════
  // DATABASE HELPER (LOCAL STORAGE)
  // ═════════════════════════════════════════════════════════════════════════

  Future<void> _loadExams() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString('examinations_schedule_list');
      if (raw != null) {
        final List<dynamic> decoded = json.decode(raw);
        setState(() {
          _exams = List<Map<String, dynamic>>.from(decoded);
        });
      } else {
        // Seed default exams
        final List<Map<String, dynamic>> defaultExams = [
          {
            'subject': 'Physics',
            'class': 'Class 10',
            'term': 'Final Term',
            'academic_year': '2026-2027',
            'date': '2026-06-10',
            'time': '10:00 AM',
            'room': 'Hall A',
            'duration': '3 hrs',
            'syllabus': 'Ch 1-8'
          },
          {
            'subject': 'Mathematics',
            'class': 'Class 10',
            'term': 'Final Term',
            'academic_year': '2026-2027',
            'date': '2026-06-12',
            'time': '10:00 AM',
            'room': 'Hall B',
            'duration': '3 hrs',
            'syllabus': 'Ch 1-10'
          },
          {
            'subject': 'Chemistry',
            'class': 'Class 10',
            'term': 'Final Term',
            'academic_year': '2026-2027',
            'date': '2026-06-14',
            'time': '02:00 PM',
            'room': 'Hall A',
            'duration': '3 hrs',
            'syllabus': 'Ch 1-7'
          },
          {
            'subject': 'English',
            'class': 'Class 10',
            'term': 'Final Term',
            'academic_year': '2026-2027',
            'date': '2026-06-16',
            'time': '10:00 AM',
            'room': 'Hall C',
            'duration': '2 hrs',
            'syllabus': 'Full Syllabus'
          },
          {
            'subject': 'Computer Sc.',
            'class': 'Class 10',
            'term': 'Final Term',
            'academic_year': '2026-2027',
            'date': '2026-06-18',
            'time': '10:00 AM',
            'room': 'Lab 501',
            'duration': '3 hrs',
            'syllabus': 'Ch 1-9'
          },
        ];
        setState(() {
          _exams = defaultExams;
        });
        await prefs.setString('examinations_schedule_list', json.encode(defaultExams));
      }
    } catch (_) {}
  }

  Future<void> _saveExams() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('examinations_schedule_list', json.encode(_exams));
    } catch (_) {}
  }

  // ═════════════════════════════════════════════════════════════════════════
  // INTERACTIVE ASSISTANT HELPER
  // ═════════════════════════════════════════════════════════════════════════

  void _initChat() {
    _chatMessages.add({
      'sender': 'bot',
      'text': 'Hello! I am Vikram, your Academic Assistant. How can I help you today?'
    });
  }

  void _toggleChat() {
    setState(() {
      _isChatOpen = !_isChatOpen;
      if (_isChatOpen) {
        _showAssistantBubble = false;
      }
    });
  }

  void _handleSendChatMessage() {
    final text = _chatInputCtrl.text.trim();
    if (text.isEmpty) return;

    _chatInputCtrl.clear();
    setState(() {
      _chatMessages.add({'sender': 'user', 'text': text});
    });

    String reply = '';
    final query = text.toLowerCase();

    if (query.contains('exam') || query.contains('schedule')) {
      reply = 'You can view the full Exam Schedule in the section below. You can also filter by Class, Term, or Academic Year.';
    } else if (query.contains('physics')) {
      reply = 'The Physics exam is scheduled for June 10, 2026, at 10:00 AM in Hall A. Syllabus covers Chapters 1-8.';
    } else if (query.contains('math') || query.contains('mathematics')) {
      reply = 'The Mathematics exam is on June 12, 2026, at 10:00 AM in Hall B. Syllabus covers Chapters 1-10.';
    } else if (query.contains('chemistry')) {
      reply = 'The Chemistry exam is on June 14, 2026, at 02:00 PM in Hall A. Syllabus covers Chapters 1-7.';
    } else if (query.contains('english')) {
      reply = 'The English exam is on June 16, 2026, at 10:00 AM in Hall C. Syllabus covers Full Syllabus.';
    } else if (query.contains('computer') || query.contains('cs')) {
      reply = 'The Computer Science exam is on June 18, 2026, at 10:00 AM in Lab 501. Syllabus covers Chapters 1-9.';
    } else {
      reply = "Hi! I am Vikram. I can answer questions about exam dates, syllabus, and room details. Try asking: 'When is the Physics exam?'";
    }

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _chatMessages.add({'sender': 'bot', 'text': reply});
        });
      }
    });
  }

  // ═════════════════════════════════════════════════════════════════════════
  // ACTIONS
  // ═════════════════════════════════════════════════════════════════════════

  void _onNavTap(int index) {
    if (index == 3) return; // Already on examinations
    Navigator.pop(context, index);
  }

  void _deleteExam(int index) {
    setState(() {
      _exams.removeAt(index);
    });
    _saveExams();
  }

  void _showCreateExamDialog() {
    final subjectCtrl = TextEditingController();
    final roomCtrl = TextEditingController();
    final syllabusCtrl = TextEditingController();
    final durationCtrl = TextEditingController(text: '3 hrs');
    final timeCtrl = TextEditingController(text: '10:00 AM');
    
    String selectedClass = 'Class 10';
    String selectedTerm = 'Final Term';
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          title: Text('Create Exam', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: subjectCtrl,
                  decoration: _dialogFieldDecoration('Subject Name', 'e.g. Physics'),
                ),
                SizedBox(height: 12.h),
                
                // Date picker
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2028),
                    );
                    if (picked != null) {
                      setStateDialog(() => selectedDate = picked);
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Date: ${intl.DateFormat('yyyy-MM-dd').format(selectedDate)}',
                          style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w500),
                        ),
                        const Icon(Icons.calendar_today, size: 18),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 12.h),

                TextField(
                  controller: timeCtrl,
                  decoration: _dialogFieldDecoration('Time', 'e.g. 10:00 AM'),
                ),
                SizedBox(height: 12.h),

                DropdownButtonFormField<String>(
                  initialValue: selectedClass,
                  decoration: _dialogFieldDecoration('Class', ''),
                  items: ['Class 10', 'Class 11', 'Class 12'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setStateDialog(() => selectedClass = v!),
                ),
                SizedBox(height: 12.h),

                DropdownButtonFormField<String>(
                  initialValue: selectedTerm,
                  decoration: _dialogFieldDecoration('Term', ''),
                  items: ['Term 1', 'Term 2', 'Final Term'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setStateDialog(() => selectedTerm = v!),
                ),
                SizedBox(height: 12.h),

                TextField(
                  controller: roomCtrl,
                  decoration: _dialogFieldDecoration('Room', 'e.g. Hall A'),
                ),
                SizedBox(height: 12.h),

                TextField(
                  controller: durationCtrl,
                  decoration: _dialogFieldDecoration('Duration', 'e.g. 3 hrs'),
                ),
                SizedBox(height: 12.h),

                TextField(
                  controller: syllabusCtrl,
                  decoration: _dialogFieldDecoration('Syllabus', 'e.g. Ch 1-8'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
              onPressed: () {
                if (subjectCtrl.text.trim().isEmpty) return;
                setState(() {
                  _exams.add({
                    'subject': subjectCtrl.text.trim(),
                    'class': selectedClass,
                    'term': selectedTerm,
                    'academic_year': '2026-2027',
                    'date': intl.DateFormat('yyyy-MM-dd').format(selectedDate),
                    'time': timeCtrl.text.trim(),
                    'room': roomCtrl.text.trim(),
                    'duration': durationCtrl.text.trim(),
                    'syllabus': syllabusCtrl.text.trim(),
                  });
                });
                _saveExams();
                Navigator.pop(ctx);
              },
              child: const Text('Create', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _dialogFieldDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: GoogleFonts.inter(fontSize: 12.sp),
      contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // BUILD METHODS
  // ═════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
                onPressed: () => Navigator.pop(context),
              )
            : IconButton(
                icon: const Icon(Icons.menu, color: Color(0xFF0F172A)),
                onPressed: () {},
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
            icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF0F172A)),
            onPressed: () {},
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF0F172A)),
                onPressed: () {},
              ),
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  padding: EdgeInsets.all(4.r),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '3',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: 8.w),
        ],
      ),
      body: Stack(
        children: [
          // Content Scroll View
          Positioned.fill(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
              child: Column(
                children: [
                  _buildHeaderCard(),
                  SizedBox(height: 16.h),
                  _buildChartsRow(),
                  SizedBox(height: 16.h),
                  _buildScheduleCard(),
                  SizedBox(height: 90.h), // space for assistant overlap
                ],
              ),
            ),
          ),

          // Assistant Overlay
          _buildAssistantFloatingButtons(),

          // Chat Window Overlay
          if (_isChatOpen) _buildChatWindow(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: const Icon(Icons.description_rounded, color: Colors.white, size: 24),
                ),
                SizedBox(height: 12.h),
                Text(
                  'Examinations',
                  style: GoogleFonts.outfit(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Manage exams, schedules, and results',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Image.asset(
            'assets/images/exam_illustration.png',
            width: 100.w,
            height: 100.h,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.assignment_outlined, size: 80, color: Colors.blue);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChartsRow() {
    return Row(
      children: [
        Expanded(child: _buildSubjectPerformanceCard()),
        SizedBox(width: 12.w),
        Expanded(child: _buildAverageScoreTrendCard()),
      ],
    );
  }

  Widget _buildSubjectPerformanceCard() {
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
          Text(
            'Subject Performance',
            style: GoogleFonts.outfit(
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            'Average marks distribution across subjects',
            style: GoogleFonts.inter(
              fontSize: 10.sp,
              color: const Color(0xFF64748B),
            ),
          ),
          SizedBox(height: 16.h),
          SizedBox(
            height: 80.h,
            child: Center(
              child: _exams.isEmpty
                  ? CustomPaint(
                      size: Size(64.w, 64.h),
                      painter: DonutChartPainter(isData: false),
                    )
                  : CustomPaint(
                      size: Size(64.w, 64.h),
                      painter: DonutChartPainter(isData: true),
                    ),
            ),
          ),
          SizedBox(height: 8.h),
          Center(
            child: Text(
              _exams.isEmpty ? 'No data available\nfor visualization' : 'No data available\nfor visualization',
              style: GoogleFonts.inter(
                fontSize: 9.sp,
                color: const Color(0xFF94A3B8),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAverageScoreTrendCard() {
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
          Text(
            'Average Score Trend',
            style: GoogleFonts.outfit(
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            'Class average performance over time',
            style: GoogleFonts.inter(
              fontSize: 10.sp,
              color: const Color(0xFF64748B),
            ),
          ),
          SizedBox(height: 16.h),
          SizedBox(
            height: 80.h,
            child: Center(
              child: _exams.isEmpty
                  ? CustomPaint(
                      size: Size(110.w, 64.h),
                      painter: LineChartPainter(isData: false),
                    )
                  : CustomPaint(
                      size: Size(110.w, 64.h),
                      painter: LineChartPainter(isData: true),
                    ),
            ),
          ),
          SizedBox(height: 8.h),
          Center(
            child: Text(
              _exams.isEmpty ? 'No data available\nfor visualization' : 'No data available\nfor visualization',
              style: GoogleFonts.inter(
                fontSize: 9.sp,
                color: const Color(0xFF94A3B8),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard() {
    final filtered = _exams.where((e) {
      final subject = e['subject']?.toLowerCase() ?? '';
      final search = _searchQuery.toLowerCase();
      if (!subject.contains(search)) return false;

      final year = e['academic_year'] ?? '2026-2027';
      if (_selectedYear != 'All Years' && year != _selectedYear) return false;

      final cls = e['class'] ?? 'Class 10';
      if (_selectedClass != 'All Classes' && cls != _selectedClass) return false;

      final term = e['term'] ?? 'Final Term';
      if (_selectedTerm != 'All Terms' && term != _selectedTerm) return false;

      return true;
    }).toList();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: EdgeInsets.all(16.r),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
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
                          'View and manage all scheduled examinations',
                          style: GoogleFonts.inter(
                            fontSize: 11.sp,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Text(
                      '${filtered.length} Total',
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              
              // Search Input
              TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search exams by name...',
                  hintStyle: GoogleFonts.inter(fontSize: 13.sp, color: const Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                  filled: true,
                  fillColor: Colors.white,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide: const BorderSide(color: Color(0xFF3B82F6)),
                  ),
                ),
              ),
              SizedBox(height: 12.h),

              // Filters Row
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 340;
                  if (isNarrow) {
                    return Column(
                      children: [
                        _buildFilterDropdown('Academic Year', _selectedYear, ['All Years', '2026-2027', '2025-2026'], (v) => setState(() => _selectedYear = v!)),
                        SizedBox(height: 8.h),
                        _buildFilterDropdown('Class', _selectedClass, ['All Classes', 'Class 10', 'Class 11', 'Class 12'], (v) => setState(() => _selectedClass = v!)),
                        SizedBox(height: 8.h),
                        _buildFilterDropdown('Term', _selectedTerm, ['All Terms', 'Term 1', 'Term 2', 'Final Term'], (v) => setState(() => _selectedTerm = v!)),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: _buildFilterDropdown('Academic Year', _selectedYear, ['All Years', '2026-2027', '2025-2026'], (v) => setState(() => _selectedYear = v!))),
                      SizedBox(width: 8.w),
                      Expanded(child: _buildFilterDropdown('Class', _selectedClass, ['All Classes', 'Class 10', 'Class 11', 'Class 12'], (v) => setState(() => _selectedClass = v!))),
                      SizedBox(width: 8.w),
                      Expanded(child: _buildFilterDropdown('Term', _selectedTerm, ['All Terms', 'Term 1', 'Term 2', 'Final Term'], (v) => setState(() => _selectedTerm = v!))),
                    ],
                  );
                },
              ),
              SizedBox(height: 20.h),

              // List/Empty state
              filtered.isEmpty ? _buildEmptyExamsState() : _buildExamsList(filtered),
            ],
          ),
          
          // FAB aligned in bottom-right of the card
          Positioned(
            right: 0,
            bottom: 0,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: const Color(0xFF3B82F6),
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
              onPressed: _showCreateExamDialog,
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
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
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: const Color(0xFF64748B), size: 18.sp),
              isExpanded: true,
              style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF1E293B), fontWeight: FontWeight.w600),
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyExamsState() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 32.h),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16.r),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.calendar_today_rounded, size: 36.sp, color: const Color(0xFF94A3B8)),
          ),
          SizedBox(height: 12.h),
          Text(
            'No exams found',
            style: GoogleFonts.outfit(
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Get started by creating your first exam',
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              color: const Color(0xFF64748B),
            ),
          ),
          SizedBox(height: 24.h), // space for overlapping FAB
        ],
      ),
    );
  }

  Widget _buildExamsList(List<Map<String, dynamic>> list) {
    return Column(
      children: [
        ...list.map((e) {
          final idx = _exams.indexOf(e);
          final subject = e['subject'] ?? '';
          final dateStr = e['date'] ?? '';
          final timeStr = e['time'] ?? '';
          final room = e['room'] ?? '';
          final duration = e['duration'] ?? '';
          final syllabus = e['syllabus'] ?? '';
          final className = e['class'] ?? '';

          String dateVal = '10';
          String monthVal = 'June';
          
          try {
            final parsedDate = DateTime.parse(dateStr);
            final formatterDate = intl.DateFormat('d');
            final formatterMonth = intl.DateFormat('MMM');
            
            dateVal = formatterDate.format(parsedDate);
            monthVal = formatterMonth.format(parsedDate);
          } catch (_) {
            if (dateStr.contains('-')) {
              final parts = dateStr.split('-');
              if (parts.length == 3) {
                dateVal = parts[2];
                final m = int.tryParse(parts[1]) ?? 6;
                final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                monthVal = months[m - 1];
              }
            }
          }

          return Container(
            margin: EdgeInsets.only(bottom: 12.h),
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                // Date Widget
                Container(
                  width: 50.w,
                  height: 54.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dateVal,
                        style: GoogleFonts.inter(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                      Text(
                        monthVal.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12.w),

                // Details Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            subject,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0F172A),
                              fontSize: 14.sp,
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Text(
                              className,
                              style: GoogleFonts.inter(
                                fontSize: 9.sp,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        '$timeStr • Room: $room • $duration',
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          color: const Color(0xFF475569),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        'Syllabus: $syllabus',
                        style: GoogleFonts.inter(
                          fontSize: 10.sp,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),

                // Delete Action
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                  onPressed: () => _deleteExam(idx),
                ),
              ],
            ),
          );
        }),
        SizedBox(height: 24.h), // spacing offset
      ],
    );
  }

  Widget _buildAssistantFloatingButtons() {
    return Positioned(
      right: 16.w,
      bottom: 16.h,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_showAssistantBubble)
            GestureDetector(
              onTap: _toggleChat,
              child: Container(
                margin: EdgeInsets.only(bottom: 8.h, right: 8.w),
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16.r),
                    topRight: Radius.circular(16.r),
                    bottomLeft: Radius.circular(16.r),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14.r,
                      backgroundColor: Colors.blue.shade100,
                      child: const Text('👨‍🏫', style: TextStyle(fontSize: 12)),
                    ),
                    SizedBox(width: 8.w),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Hi Vikram!',
                          style: GoogleFonts.inter(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'How can I help?',
                          style: GoogleFonts.inter(
                            fontSize: 10.sp,
                            color: const Color(0xFF2563EB),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          FloatingActionButton(
            heroTag: 'chatbot_fab',
            backgroundColor: const Color(0xFF2563EB),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.r)),
            onPressed: _toggleChat,
            child: const Icon(Icons.assistant_navigation, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildChatWindow() {
    return Positioned(
      right: 16.w,
      bottom: 80.h,
      width: 300.w,
      height: 380.h,
      child: Card(
        elevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        child: Column(
          children: [
            // Chat Header
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16.r),
                  topRight: Radius.circular(16.r),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14.r,
                        backgroundColor: Colors.white,
                        child: const Icon(Icons.assistant_rounded, color: Color(0xFF2563EB), size: 16),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'Vikram Assistant',
                        style: GoogleFonts.outfit(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 18),
                    onPressed: _toggleChat,
                  ),
                ],
              ),
            ),

            // Messages Container
            Expanded(
              child: Container(
                color: const Color(0xFFF8FAFC),
                child: ListView.builder(
                  padding: EdgeInsets.all(12.r),
                  itemCount: _chatMessages.length,
                  itemBuilder: (ctx, i) {
                    final msg = _chatMessages[i];
                    final isUser = msg['sender'] == 'user';
                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: EdgeInsets.only(bottom: 8.h),
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          color: isUser ? const Color(0xFF2563EB) : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(12.r),
                            topRight: Radius.circular(12.r),
                            bottomLeft: isUser ? Radius.circular(12.r) : Radius.zero,
                            bottomRight: isUser ? Radius.zero : Radius.circular(12.r),
                          ),
                          border: isUser ? null : Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          msg['text'] ?? '',
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            color: isUser ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Chat Input Panel
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatInputCtrl,
                      onSubmitted: (_) => _handleSendChatMessage(),
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        hintStyle: GoogleFonts.inter(fontSize: 12.sp, color: const Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8.w),
                      ),
                      style: GoogleFonts.inter(fontSize: 12.sp),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: Color(0xFF2563EB)),
                    onPressed: _handleSendChatMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
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
                icon: Icons.calendar_today_rounded,
                label: 'Calendar',
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
                icon: Icons.more_horiz_rounded,
                label: 'More',
                selected: false,
                color: const Color(0xFF2563EB),
                onTap: () => _onNavTap(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// SUPPORTING WIDGETS & PAINTERS
// ═════════════════════════════════════════════════════════════════════════

class DonutChartPainter extends CustomPainter {
  final bool isData;
  DonutChartPainter({required this.isData});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    if (!isData) {
      final paintBg = Paint()
        ..color = const Color(0xFFF1F5F9)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, paintBg);

      final paintOutline = Paint()
        ..color = const Color(0xFFE2E8F0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.w;
      canvas.drawCircle(center, radius - 4.w, paintOutline);

      final paintInner = Paint()..color = Colors.white;
      canvas.drawCircle(center, radius / 2, paintInner);
    } else {
      final rect = Rect.fromCircle(center: center, radius: radius - 4.w);
      final strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.w
        ..strokeCap = StrokeCap.round;

      final colors = [
        const Color(0xFF3B82F6),
        const Color(0xFF10B981),
        const Color(0xFFF59E0B),
        const Color(0xFF8B5CF6),
        const Color(0xFFEF4444),
      ];

      double startAngle = -3.14 / 2;
      final sweepAngles = [3.14 * 0.6, 3.14 * 0.5, 3.14 * 0.4, 3.14 * 0.3, 3.14 * 0.2];

      for (int i = 0; i < colors.length; i++) {
        strokePaint.color = colors[i];
        canvas.drawArc(rect, startAngle, sweepAngles[i], false, strokePaint);
        startAngle += sweepAngles[i] + 0.05;
      }

      canvas.drawCircle(center, radius / 2, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class LineChartPainter extends CustomPainter {
  final bool isData;
  LineChartPainter({required this.isData});

  @override
  void paint(Canvas canvas, Size size) {
    final paintGrid = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..strokeWidth = 1.h;

    for (double y = 0; y <= size.height; y += size.height / 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintGrid);
    }

    if (!isData) {
      final path = Path();
      path.moveTo(0, size.height * 0.7);
      path.quadraticBezierTo(
        size.width * 0.25, size.height * 0.6,
        size.width * 0.5, size.height * 0.75,
      );
      path.quadraticBezierTo(
        size.width * 0.75, size.height * 0.9,
        size.width, size.height * 0.65,
      );

      final paintLine = Paint()
        ..color = const Color(0xFFCBD5E1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.w;

      canvas.drawPath(path, paintLine);
    } else {
      final path = Path();
      path.moveTo(0, size.height * 0.6);
      path.lineTo(size.width * 0.2, size.height * 0.4);
      path.lineTo(size.width * 0.4, size.height * 0.7);
      path.lineTo(size.width * 0.6, size.height * 0.35);
      path.lineTo(size.width * 0.8, size.height * 0.5);
      path.lineTo(size.width, size.height * 0.2);

      final paintLine = Paint()
        ..color = const Color(0xFF3B82F6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.w
        ..strokeCap = StrokeCap.round;

      final fillPath = Path.from(path);
      fillPath.lineTo(size.width, size.height);
      fillPath.lineTo(0, size.height);
      fillPath.close();

      final paintFill = Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFF3B82F6).withValues(alpha: 0.2),
            const Color(0xFF3B82F6).withValues(alpha: 0.0),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

      canvas.drawPath(fillPath, paintFill);
      canvas.drawPath(path, paintLine);

      final paintDot = Paint()
        ..color = const Color(0xFF2563EB)
        ..style = PaintingStyle.fill;
      final paintDotBg = Paint()..color = Colors.white;

      final points = [
        Offset(0, size.height * 0.6),
        Offset(size.width * 0.2, size.height * 0.4),
        Offset(size.width * 0.4, size.height * 0.7),
        Offset(size.width * 0.6, size.height * 0.35),
        Offset(size.width * 0.8, size.height * 0.5),
        Offset(size.width, size.height * 0.2),
      ];

      for (var pt in points) {
        canvas.drawCircle(pt, 4.r, paintDot);
        canvas.drawCircle(pt, 2.r, paintDotBg);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

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
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: selected ? color : const Color(0xFF94A3B8), size: 24.sp),
              SizedBox(height: 2.h),
              Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  color: selected ? color : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

