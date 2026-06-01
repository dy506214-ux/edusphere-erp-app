import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'ai_generator_screen.dart';
import 'lesson_detail_screen.dart';
import 'add_lesson_screen.dart';
import 'analytics_detail_screen.dart';
import 'homework_screen.dart';
import 'notifications_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class LessonPlanScreen extends StatefulWidget {
  const LessonPlanScreen({super.key});

  @override
  State<LessonPlanScreen> createState() => _LessonPlanScreenState();
}

class _LessonPlanScreenState extends State<LessonPlanScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  final Color darkNavy = const Color(0xFF1E40AF);
  final Color backgroundGrey = const Color(0xFFF1F5F9);
  final Color accentBlue = const Color(0xFF3B82F6);
  final Color accentGreen = const Color(0xFF10B981);
  final Color accentAmber = const Color(0xFFF59E0B);
  final Color accentRose = const Color(0xFFF43F5E);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundGrey,
      body: Column(
        children: [
          _buildHeader(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildTodayTab(),
                _buildPlannerTab(),
                _buildAnalyticsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: darkNavy,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, bottom: 20, left: 20, right: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Lesson Planner', style: GoogleFonts.inter(fontSize: 22.sp, fontWeight: FontWeight.w800, color: Colors.white)),
                    Text('Physics — Grade 12 · Section A', style: GoogleFonts.inter(fontSize: 13.sp, color: Colors.white.withValues(alpha: 0.6))),
                  ],
                ),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                    child: Stack(
                      children: [
                        Container(
                          width: 8.w, height: 8.h,
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        ),
                        Icon(Icons.notifications_none_rounded, color: Colors.white, size: 24.sp),
                      ],
                    ),
                  ),
                  SizedBox(width: 12.w),
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF3B82F6),
                    child: Text('RS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.sp)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: darkNavy,
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(10.r),
          color: Colors.white,
        ),
        labelColor: darkNavy,
        unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
        labelStyle: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w700),
        indicatorPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        indicatorSize: TabBarIndicatorSize.tab,
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'Today'),
          Tab(text: 'Planner'),
          Tab(text: 'Analytics'),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSyllabusProgressCard(),
          SizedBox(height: 16.h),
          _buildAIGeneratorCard(),
          SizedBox(height: 16.h),
          _buildStatsGrid(),
          SizedBox(height: 24.h),
          Text('Chapters', style: GoogleFonts.inter(fontSize: 18.sp, fontWeight: FontWeight.w800, color: darkNavy)),
          SizedBox(height: 12.h),
          _buildChapterItem(
            context: context,
            chapter: 'Chapter 1',
            title: 'Thermodynamics',
            lessons: '8/8 lessons',
            tools: 'Smart Board + Lab',
            tags: ['Bloom\'s: Analyze, Create', 'Test done'],
            isComplete: true,
            progress: 1.0,
          ),
          _buildChapterItem(
            context: context,
            chapter: 'Chapter 2 · Active',
            title: 'Quantum Mechanics',
            lessons: '6/10 lessons',
            tools: 'Animation + Discussion',
            tags: ['Bloom\'s: Apply, Evaluate'],
            isComplete: false,
            progress: 0.6,
            isActive: true,
            extras: [
              _tagButton('5 weak', Colors.blue.shade50, Colors.blue),
              _tagButton('PPT ready', Colors.grey.shade100, Colors.grey),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSyllabusProgressCard() {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: const Color(0xFF1D4ED8), // Darker blue for contrast
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SYLLABUS PROGRESS', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.6), letterSpacing: 0.5)),
                    SizedBox(height: 8.h),
                    Text('78%', style: GoogleFonts.inter(fontSize: 48.sp, fontWeight: FontWeight.w900, color: Colors.white)),
                    SizedBox(height: 4.h),
                    Text('14 of 18 chapters covered', style: GoogleFonts.inter(fontSize: 14.sp, color: Colors.white.withValues(alpha: 0.8))),
                  ],
                ),
              ),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 80.w, height: 80.h,
                    child: CircularProgressIndicator(
                      value: 0.78,
                      strokeWidth: 8,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF10B981)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 20.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(10.r),
            child: LinearProgressIndicator(
              value: 0.78,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF10B981)),
            ),
          ),
          SizedBox(height: 20.h),
          Row(
            children: [
              _miniStat('6', 'Classes today'),
              _miniStat('84%', 'Attendance'),
              _miniStat('12', 'Weak students'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String val, String label) {
    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 4.w),
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Column(
          children: [
            Text(val, style: GoogleFonts.inter(fontSize: 18.sp, fontWeight: FontWeight.w800, color: Colors.white)),
            Text(label, style: GoogleFonts.inter(fontSize: 10.sp, color: Colors.white.withValues(alpha: 0.6))),
          ],
        ),
      ),
    );
  }

  Widget _buildAIGeneratorCard() {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIGeneratorScreen())),
      child: Container(
        padding: EdgeInsets.all(20.r),
        decoration: BoxDecoration(
          color: const Color(0xFF1E3A8A), // Deep blue for AI card
          borderRadius: BorderRadius.circular(24.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48.w, height: 48.h,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12.r)),
                  child: const Icon(Icons.bolt_rounded, color: Colors.white),
                ),
                SizedBox(width: 16.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AI Lesson Generator', style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.w800, color: Colors.white)),
                    Text('Tap to generate plan, quiz & notes', style: GoogleFonts.inter(fontSize: 12.sp, color: Colors.white.withValues(alpha: 0.6))),
                  ],
                ),
              ],
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                _chip('Quiz'),
                _chip('Notes'),
                _chip('Homework'),
                _chip('PPT Ideas'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      margin: EdgeInsets.only(right: 8.w),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Text(label, style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: Colors.white)),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.3, // Safe ratio to prevent overflow
      children: [
        _gridStatCard('4/6', 'Classes done', 'On track', accentGreen),
        _gridStatCard('3', 'Pending lessons', '1 overdue', accentRose),
        _gridStatCard('89%', 'HW submitted', 'Great', accentGreen),
        _gridStatCard('3.8', 'Avg score', 'Above avg', accentAmber),
      ],
    );
  }

  Widget _gridStatCard(String val, String label, String status, Color statusColor) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 24.w, height: 24.h, decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6.r))),
            ],
          ),
          const Spacer(),
          Text(val, style: GoogleFonts.inter(fontSize: 20.sp, fontWeight: FontWeight.w900, color: darkNavy)),
          Text(label, style: GoogleFonts.inter(fontSize: 11.sp, color: darkNavy.withValues(alpha: 0.6))),
          SizedBox(height: 8.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4.r)),
            child: Text(status, style: GoogleFonts.inter(fontSize: 9.sp, fontWeight: FontWeight.w800, color: statusColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildChapterItem({
    required BuildContext context,
    required String chapter,
    required String title,
    required String lessons,
    required String tools,
    required List<String> tags,
    required bool isComplete,
    required double progress,
    bool isActive = false,
    List<Widget>? extras,
  }) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChapterDetailScreen(title: title, chapter: chapter))),
      child: Container(
        margin: EdgeInsets.only(bottom: 16.h),
        padding: EdgeInsets.all(20.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24.r),
          border: isActive ? Border.all(color: accentBlue, width: 2.w) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(chapter, style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: darkNavy.withValues(alpha: 0.4))),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(color: isComplete ? accentGreen.withValues(alpha: 0.1) : (isActive ? accentBlue.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1)), borderRadius: BorderRadius.circular(8.r)),
                  child: Text(isComplete ? 'Complete' : (isActive ? 'Active' : 'Pending'), style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w800, color: isComplete ? accentGreen : (isActive ? accentBlue : Colors.grey))),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            Text(title, style: GoogleFonts.inter(fontSize: 18.sp, fontWeight: FontWeight.w800, color: darkNavy)),
            SizedBox(height: 4.h),
            Text('$lessons · $tools', style: GoogleFonts.inter(fontSize: 12.sp, color: darkNavy.withValues(alpha: 0.6))),
            SizedBox(height: 12.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(4.r),
              child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: backgroundGrey, valueColor: AlwaysStoppedAnimation(isComplete ? accentGreen : accentBlue)),
            ),
            SizedBox(height: 12.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(tags[0], style: GoogleFonts.inter(fontSize: 12.sp, color: darkNavy.withValues(alpha: 0.4))),
                if (tags.length > 1) 
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                    decoration: BoxDecoration(color: backgroundGrey, borderRadius: BorderRadius.circular(4.r), border: Border.all(color: Colors.black.withValues(alpha: 0.1))),
                    child: Text(tags[1], style: GoogleFonts.inter(fontSize: 10.sp, color: darkNavy.withValues(alpha: 0.6))),
                  ),
              ],
            ),
            if (extras != null) ...[
              SizedBox(height: 12.h),
              Row(children: extras),
            ]
          ],
        ),
      ),
    );
  }

  Widget _tagButton(String text, Color bg, Color textCol) {
    return Container(
      margin: EdgeInsets.only(right: 8.w),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6.r), border: Border.all(color: textCol.withValues(alpha: 0.2))),
      child: Text(text, style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w700, color: textCol)),
    );
  }

  Widget _buildTodayTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Today\'s schedule — May 12', style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.w800, color: darkNavy)),
          SizedBox(height: 16.h),
          _scheduleItem('9:00', 'Thermodynamics — Entropy', 'Class 12A · 44/48', 'Completed', 'HW assigned', accentGreen, 0.95),
          _scheduleItem('11:00', 'Wave Functions — QM', 'Class 12A · In progress', 'In Progress', '5 weak', accentBlue, 0.60),
          _scheduleItem('14:00', 'Transition Metals — Chem', 'Class 11B · Scheduled', 'Upcoming', null, Colors.grey, 0),
          _scheduleItem('16:00', 'Wave Optics — Class 10C', 'Class 10C · Scheduled', 'Upcoming', null, Colors.grey, 0),
          SizedBox(height: 24.h),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddLessonScreen())),
            child: _buildAddButton(darkNavy, 'Add new lesson'),
          ),
        ],
      ),
    );
  }

  Widget _scheduleItem(String time, String title, String subtitle, String status, String? extra, Color color, double progress) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LessonDetailScreen(title: title, chapter: subtitle.split(' · ')[0]))),
      child: Container(
        margin: EdgeInsets.only(bottom: 16.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Text(time, style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w700, color: darkNavy.withValues(alpha: 0.5))),
                SizedBox(height: 8.h),
                Container(width: 12.w, height: 12.h, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                Container(width: 2.w, height: 60.h, color: Colors.grey.shade300),
              ],
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Container(
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20.r)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(title, style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.w800, color: darkNavy))),
                        if (progress > 0) Text('${(progress * 100).round()}%', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w800, color: color)),
                      ],
                    ),
                    Text(subtitle, style: GoogleFonts.inter(fontSize: 12.sp, color: darkNavy.withValues(alpha: 0.6))),
                    SizedBox(height: 12.h),
                    Row(
                      children: [
                        _tagButton(status, color.withValues(alpha: 0.1), color),
                        if (extra != null) _tagButton(extra, accentAmber.withValues(alpha: 0.1), accentAmber),
                      ],
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

  Widget _buildPlannerTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Weekly planner', style: GoogleFonts.inter(fontSize: 18.sp, fontWeight: FontWeight.w800, color: darkNavy)),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddLessonScreen())),
                child: Text('+ Add', style: GoogleFonts.inter(color: accentBlue, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Container(
            padding: EdgeInsets.all(20.r),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24.r)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('This week — May 12–16', style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w700)),
                SizedBox(height: 16.h),
                _weeklyBar('Monday', 1.0, accentGreen, '4/4'),
                _weeklyBar('Tuesday', 0.75, accentBlue, '3/4'),
                _weeklyBar('Wednesday', 0.5, accentAmber, '2/4'),
                _weeklyBar('Thursday', 0.25, Colors.grey, '1/4'),
                _weeklyBar('Friday', 0.0, Colors.grey, '0/4'),
              ],
            ),
          ),
          SizedBox(height: 24.h),
          _buildSectionCard('Approval workflow', 'Quantum Mechanics Lesson Plan', [
            _workflowStep('Teacher', true),
            _workflowStep('HOD', false, active: true),
            _workflowStep('Principal', false),
          ], footer: 'Awaiting HOD review'),
          SizedBox(height: 24.h),
          _buildUpcomingExams(),
        ],
      ),
    );
  }

  Widget _weeklyBar(String day, double val, Color col, String count) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        children: [
          SizedBox(width: 80.w, child: Text(day, style: GoogleFonts.inter(fontSize: 12.sp, color: darkNavy.withValues(alpha: 0.6)))),
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(10.r), child: LinearProgressIndicator(value: val, minHeight: 12, backgroundColor: backgroundGrey, valueColor: AlwaysStoppedAnimation(col)))),
          SizedBox(width: 12.w),
          Text(count, style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w800, color: col)),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, String subtitle, List<Widget> items, {String? footer}) {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24.r)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.w800)),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 13.sp, color: darkNavy.withValues(alpha: 0.6))),
          SizedBox(height: 20.h),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: items),
          if (footer != null) ...[
            SizedBox(height: 16.h),
            Text(footer, style: GoogleFonts.inter(fontSize: 12.sp, color: accentBlue, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }

  Widget _workflowStep(String label, bool done, {bool active = false}) {
    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 4.w),
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          color: done ? accentGreen.withValues(alpha: 0.1) : (active ? accentBlue.withValues(alpha: 0.1) : backgroundGrey),
          borderRadius: BorderRadius.circular(12.r),
          border: active ? Border.all(color: accentBlue) : null,
        ),
        child: Center(child: Text(label, style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: done ? accentGreen : (active ? accentBlue : Colors.grey)))),
      ),
    );
  }

  Widget _buildUpcomingExams() {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HomeworkScreen())),
      child: Container(
        padding: EdgeInsets.all(20.r),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24.r)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Upcoming exams', style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.w800)),
            SizedBox(height: 16.h),
            _examItem('Physics Unit Test', 'May 18 · 6 days', accentRose),
            _examItem('Biology Mid Term', 'May 22 · 10 days', accentAmber),
            _examItem('Maths Chapter Test', 'May 25', Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _examItem(String title, String date, Color col) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: GoogleFonts.inter(fontSize: 13.sp, color: darkNavy.withValues(alpha: 0.6))),
          Text(date, style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w700, color: col)),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsDetailScreen())),
            child: _buildAnalyticsCard('Subject completion %', [
              _analyticsBar('Physics', 0.78, accentBlue, '78%'),
              _analyticsBar('Chemistry', 0.55, accentGreen, '55%'),
              _analyticsBar('Maths', 0.90, accentAmber, '90%'),
            ]),
          ),
          SizedBox(height: 20.h),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HomeworkScreen())),
            child: _buildAnalyticsCard('Homework completion by class', [
              _analyticsBar('Class 12A', 0.89, accentGreen, '89%'),
              _analyticsBar('Class 11B', 0.72, accentAmber, '72%'),
              _analyticsBar('Class 10C', 0.60, accentRose, '60%'),
            ]),
          ),
          SizedBox(height: 20.h),
          _buildAnalyticsCard('Topic-wise understanding', [
            _analyticsBar('Entropy', 0.90, accentGreen, '90%'),
            _analyticsBar('Wave func.', 0.65, accentBlue, '65%'),
            _analyticsBar('Numericals', 0.48, accentAmber, '48%'),
            _analyticsBar('Mirror formula', 0.35, accentRose, '35%'),
          ]),
          SizedBox(height: 20.h),
          Row(
            children: [
              Text('12 students need remedial support.', style: GoogleFonts.inter(fontSize: 13.sp, color: darkNavy.withValues(alpha: 0.6))),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsDetailScreen())),
                child: Text(' View list →', style: GoogleFonts.inter(fontSize: 13.sp, color: accentBlue, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard(String title, List<Widget> bars) {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24.r)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.w800)),
          SizedBox(height: 20.h),
          ...bars,
        ],
      ),
    );
  }

  Widget _analyticsBar(String label, double val, Color col, String pct) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Row(
        children: [
          SizedBox(width: 100.w, child: Text(label, style: GoogleFonts.inter(fontSize: 13.sp, color: darkNavy.withValues(alpha: 0.6)))),
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(10.r), child: LinearProgressIndicator(value: val, minHeight: 8, backgroundColor: backgroundGrey, valueColor: AlwaysStoppedAnimation(col)))),
          SizedBox(width: 12.w),
          Text(pct, style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w800, color: darkNavy)),
        ],
      ),
    );
  }

  Widget _buildAddButton(Color bg, String label) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 16.h),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16.r)),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, color: Colors.white, size: 20.sp),
            SizedBox(width: 8.w),
            Text(label, style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.w700, color: Colors.white)),
          ],
        ),
      ),
    );
  }


}

class ChapterDetailScreen extends StatelessWidget {
  final String title;
  final String chapter;

  const ChapterDetailScreen({super.key, required this.title, required this.chapter});

  @override
  Widget build(BuildContext context) {
    const Color darkNavy = Color(0xFF1E40AF);
    const Color accentBlue = Color(0xFF3B82F6);
    const Color accentGreen = Color(0xFF10B981);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          Container(
            color: darkNavy,
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, bottom: 20, left: 20, right: 20),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
                SizedBox(width: 8.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: GoogleFonts.inter(fontSize: 20.sp, fontWeight: FontWeight.w800, color: Colors.white)),
                      Text('$chapter · Physics Grade 12', style: GoogleFonts.inter(fontSize: 14.sp, color: Colors.white.withValues(alpha: 0.6))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(24.r),
                    decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(24.r)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ACTIVE · 6/10 LESSONS', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.6))),
                        SizedBox(height: 12.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('60%', style: GoogleFonts.inter(fontSize: 48.sp, fontWeight: FontWeight.w900, color: Colors.white)),
                            SizedBox(width: 70.w, height: 70.h, child: CircularProgressIndicator(value: 0.6, strokeWidth: 8, backgroundColor: Colors.white.withValues(alpha: 0.1), valueColor: const AlwaysStoppedAnimation(Color(0xFF10B981)))),
                          ],
                        ),
                        Text('6 of 10 lessons completed', style: GoogleFonts.inter(fontSize: 14.sp, color: Colors.white.withValues(alpha: 0.8))),
                        SizedBox(height: 16.h),
                        ClipRRect(borderRadius: BorderRadius.circular(10.r), child: LinearProgressIndicator(value: 0.6, minHeight: 8, backgroundColor: Colors.white.withValues(alpha: 0.1), valueColor: const AlwaysStoppedAnimation(Color(0xFF10B981)))),
                      ],
                    ),
                  ),
                  SizedBox(height: 24.h),
                  Container(
                    padding: EdgeInsets.all(20.r),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24.r)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Chapter info', style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.w800)),
                        SizedBox(height: 16.h),
                        _infoRow('Teaching method', 'Animation + Discussion'),
                        _infoRow('Bloom\'s level', 'Apply, Evaluate'),
                        _infoRow('Exam scheduled', 'May 18'),
                        _infoRow('Status', 'Active', isStatus: true),
                      ],
                    ),
                  ),
                  SizedBox(height: 24.h),
                  Text('Lessons breakdown', style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.w800)),
                  SizedBox(height: 12.h),
                  _lessonItem(context, 'Lesson 1 — Completed', 'Done', accentGreen),
                  _lessonItem(context, 'Lesson 2 — Completed', 'Done', accentGreen),
                  _lessonItem(context, 'Lesson 3 — Completed', 'Done', accentGreen),
                  _lessonItem(context, 'Lesson 7 — Active', 'Active', accentBlue),
                  _lessonItem(context, 'Lesson 8', 'Pending', Colors.grey),
                  SizedBox(height: 24.h),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddLessonScreen())),
                    child: _buildDetailAddButton(darkNavy, 'Add lesson to this chapter'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String val, {bool isStatus = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 14.sp, color: Colors.grey)),
          if (isStatus)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(color: const Color(0xFF3B82F6).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8.r)),
              child: Text(val, style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w800, color: const Color(0xFF3B82F6))),
            )
          else
            Text(val, style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _lessonItem(BuildContext context, String title, String status, Color col) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LessonDetailScreen(title: title, chapter: 'Chapter 2'))),
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.r)),
        child: Row(
          children: [
            Container(width: 12.w, height: 12.h, decoration: BoxDecoration(color: col.withValues(alpha: 0.2), shape: BoxShape.circle)),
            SizedBox(width: 16.w),
            Expanded(child: Text(title, style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w600, color: status == 'Active' ? col : Colors.black))),
            Text(status, style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: col)),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailAddButton(Color bg, String label) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 16.h),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16.r)),
      child: Center(
        child: Text(label, style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.w700, color: Colors.white)),
      ),
    );
  }
}
