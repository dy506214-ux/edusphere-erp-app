import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main_screen.dart';
class ExamDetailScreen extends StatefulWidget {
  final String examName;

  const ExamDetailScreen({Key? key, required this.examName}) : super(key: key);

  @override
  State<ExamDetailScreen> createState() => _ExamDetailScreenState();
}

class _ExamDetailScreenState extends State<ExamDetailScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _activeTabIndex = 0; // 0=Schedule, 1=Overview;
  bool _isChatOpen = false;

  final List<String> _tabs = [
    'Schedule',
    'Overview'
  ];

  final List<Map<String, dynamic>> _scheduleData = [
    {
      'Subject': 'Mathematics',
      'Date': '16/09/2024',
      'Time': '10:00',
      'Theory': '70',
      'Practical': '20',
      'Internal': '10',
      'Total': '100'
    },
    {
      'Subject': 'Hindi',
      'Date': '18/09/2024',
      'Time': '10:00',
      'Theory': '70',
      'Practical': '20',
      'Internal': '10',
      'Total': '100'
    },
    {
      'Subject': 'English',
      'Date': '15/09/2024',
      'Time': '10:00',
      'Theory': '70',
      'Practical': '20',
      'Internal': '10',
      'Total': '100'
    },
    {
      'Subject': 'Science',
      'Date': '17/09/2024',
      'Time': '10:00',
      'Theory': '70',
      'Practical': '20',
      'Internal': '10',
      'Total': '100'
    },
  ];

  final List<Map<String, dynamic>> _studentsData = List.generate(9, (index) {
    int sNum = index + 1;
    String section = sNum <= 5 ? 'A' : 'B';
    // Just to match the exact mockup numbering where 10 is inserted in the middle, but we'll stick to a simple sequence
    if (index == 5) sNum = 10;
    if (index > 5) sNum = index;
    return {
      'name': 'Student$sNum Grade1$section',
      'id': 'ADM-2024-$sNum',
      'theory': sNum == 1 ? '23' : '0',
      'prac': '0',
      'int': '0',
      'total': sNum == 1 ? '23' : '0',
      'absent': false,
    };
  });

  void _toggleChat() {
    setState(() {
      _isChatOpen = !_isChatOpen;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF0F4F8),
      drawer: EduSphereDrawer(role: 'teacher', activeLabel: 'Examinations'),
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTabs(),
                  SizedBox(height: 24.h),
                  if (_activeTabIndex == 0) _buildScheduleTab(),
                  if (_activeTabIndex == 1) _buildOverviewTab(),
                  SizedBox(height: 100.h), // space for FAB
                ],
              ),
            ),
          ),
          
          // Chat Overlay (Simulated)
          if (_isChatOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleChat,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.1),
                ),
              ),
            ),

          if (_isChatOpen)
            Positioned(
              bottom: 80.h,
              right: 16.w,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 280.w,
                  height: 360.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(16.r),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.assistant, color: Colors.white, size: 20.sp),
                            SizedBox(width: 8.w),
                            Text(
                              'EduSphere Assistant',
                              style: GoogleFonts.outfit(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: _toggleChat,
                              child: Icon(Icons.close, color: Colors.white, size: 20.sp),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            'How can I help you?',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Assistant Pop-up (Mockup style)
          if (!_isChatOpen)
            Positioned(
              bottom: 80.h,
              right: 16.w,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
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
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'HI TEACHER!',
                      style: GoogleFonts.inter(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'HOW CAN I\nHELP?',
                      style: GoogleFonts.inter(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF2563EB),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'exam_detail_chatbot_fab',
        backgroundColor: const Color(0xFF0284C7), // Blue matching mockup
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28.r)),
        onPressed: _toggleChat,
        child: Icon(
          _isChatOpen ? Icons.close_rounded : Icons.assistant_navigation,
          color: Colors.white,
        ),
      ),
      bottomNavigationBar: TeacherBottomNavBar(activeIndex: 7),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: Icon(Icons.menu, size: 28.sp, color: const Color(0xFF0F172A)),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
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
          icon: Icon(Icons.notifications_none_rounded, size: 26.sp),
          onPressed: () {},
        ),
        SizedBox(width: 8.w),
      ],
    );
  }

  Widget _buildTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: EdgeInsets.all(4.r),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9), // Light grey capsule background
          borderRadius: BorderRadius.circular(24.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: _tabs.asMap().entries.map((entry) {
            final idx = entry.key;
            final label = entry.value;
            final isActive = idx == _activeTabIndex;

            return GestureDetector(
              onTap: () => setState(() => _activeTabIndex = idx),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: isActive ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(20.r),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    color: isActive ? const Color(0xFF0F172A) : const Color(0xFF475569),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildScheduleTab() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: EdgeInsets.all(24.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Subject Schedule',
            style: GoogleFonts.outfit(
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 24.h),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _buildScheduleTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Container(
          width: 800.w, // Fixed width for horizontal scrolling
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: const Color(0xFFE2E8F0)),
            ),
          ),
          child: Row(
            children: [
              Expanded(flex: 3, child: Text('Subject', style: _headerStyle())),
              Expanded(flex: 2, child: Text('Date', style: _headerStyle())),
              Expanded(flex: 2, child: Text('Time', style: _headerStyle())),
              Expanded(flex: 2, child: Text('Theory', style: _headerStyle())),
              Expanded(flex: 2, child: Text('Practical', style: _headerStyle())),
              Expanded(flex: 2, child: Text('Internal', style: _headerStyle())),
              Expanded(flex: 2, child: Text('Total', style: _headerStyle())),
            ],
          ),
        ),

        // Data rows
        ..._scheduleData.asMap().entries.map((entry) {
          final e = entry.value;
          final isLast = entry.key == _scheduleData.length - 1;

          return Container(
            width: 800.w, // Fixed width for horizontal scrolling
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 16.h),
            decoration: BoxDecoration(
              color: Colors.white,
              border: isLast
                  ? null
                  : Border(bottom: BorderSide(color: const Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    e['Subject']!,
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
                Expanded(flex: 2, child: Text(e['Date']!, style: _cellStyle())),
                Expanded(flex: 2, child: Text(e['Time']!, style: _cellStyle())),
                Expanded(flex: 2, child: Text(e['Theory']!, style: _cellStyle())),
                Expanded(flex: 2, child: Text(e['Practical']!, style: _cellStyle())),
                Expanded(flex: 2, child: Text(e['Internal']!, style: _cellStyle())),
                Expanded(
                  flex: 2,
                  child: Text(
                    e['Total']!,
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  TextStyle _headerStyle() {
    return GoogleFonts.inter(
      fontSize: 10.sp,
      fontWeight: FontWeight.w600,
      color: const Color(0xFF64748B),
    );
  }

  TextStyle _cellStyle() {
    return GoogleFonts.inter(
      fontSize: 11.sp,
      fontWeight: FontWeight.w500,
      color: const Color(0xFF334155),
    );
  }

  Widget _buildOverviewTab() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: EdgeInsets.all(24.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Consolidated View',
            style: GoogleFonts.outfit(
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 24.h),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _buildOverviewTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Container(
          width: 1000.w, // Fixed width for horizontal scrolling
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: const Color(0xFFE2E8F0)),
            ),
          ),
          child: Row(
            children: [
              Expanded(flex: 1, child: Text('Rank', style: _headerStyle())),
              Expanded(flex: 4, child: Text('Student', style: _headerStyle())),
              Expanded(flex: 1, child: Text('Mat', style: _headerStyle())),
              Expanded(flex: 1, child: Text('Hin', style: _headerStyle())),
              Expanded(flex: 1, child: Text('Eng', style: _headerStyle())),
              Expanded(flex: 1, child: Text('Sci', style: _headerStyle())),
              Expanded(flex: 1, child: Text('Total', style: _headerStyle())),
              Expanded(flex: 1, child: Text('%', style: _headerStyle())),
              Expanded(flex: 1, child: Text('Grade', style: _headerStyle())),
            ],
          ),
        ),

        // Data rows
        ..._studentsData.asMap().entries.map((entry) {
          final idx = entry.key;
          final e = entry.value;
          final isLast = idx == _studentsData.length - 1;
          
          final rank = (idx + 1).toString();
          final mat = e['theory'] == '23' ? '23' : '0';
          final total = e['theory'] == '23' ? '23' : '0';
          final percent = e['theory'] == '23' ? '23%' : '0%';
          final grade = 'F';

          return Container(
            width: 1000.w, // Fixed width for horizontal scrolling
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 16.h),
            decoration: BoxDecoration(
              color: Colors.white,
              border: isLast
                  ? null
                  : Border(bottom: BorderSide(color: const Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Text(
                    rank,
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    e['name']!,
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      color: const Color(0xFF334155),
                    ),
                  ),
                ),
                Expanded(flex: 1, child: Text(mat, style: _cellStyle())),
                Expanded(flex: 1, child: Text('-', style: _cellStyle())),
                Expanded(flex: 1, child: Text('-', style: _cellStyle())),
                Expanded(flex: 1, child: Text('-', style: _cellStyle())),
                Expanded(
                  flex: 1,
                  child: Text(
                    total,
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
                Expanded(flex: 1, child: Text(percent, style: _cellStyle())),
                Expanded(
                  flex: 1,
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        child: Text(
                          grade,
                          style: GoogleFonts.inter(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
}
