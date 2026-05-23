import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import '../features/notices_screen.dart';
import '../features/fees_screen.dart';
import '../features/results_screen.dart';
import '../features/attendance_screen.dart';
import '../features/timetable_screen.dart';
import '../features/documents_screen.dart';

class ParentDashboard extends StatelessWidget {
  final RoleTheme theme;
  const ParentDashboard({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _header()),
          SliverPadding(
            padding: EdgeInsets.all(16.r),
            sliver: SliverList(delegate: SliverChildListDelegate([
              _stats(),
              SizedBox(height: 20.h),
              const SectionTitle(title: 'Child Overview'),
              SizedBox(height: 12.h),
              _childCard(),
              SizedBox(height: 20.h),
              const SectionTitle(title: 'Quick Access'),
              SizedBox(height: 12.h),
              _quickActions(context),
              SizedBox(height: 20.h),
              const SectionTitle(title: 'Parent Features'),
              SizedBox(height: 12.h),
              _modules(context),
              SizedBox(height: 100.h),
            ])),
          ),
        ],
      ),
    );
  }

  Widget _header() => Container(
    decoration: BoxDecoration(gradient: theme.gradient),
    child: SafeArea(bottom: false, child: Padding(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 28.h),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Hello 👋', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.7))),
          Text('Mr. Smith', style: GoogleFonts.inter(fontSize: 22.sp, fontWeight: FontWeight.w900, color: Colors.white)),
          SizedBox(height: 6.h),
          Container(padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8.r)),
            child: Text('Parent of Alex Rivera', style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w700, color: Colors.white))),
        ])),
        Container(width: 52.w, height: 52.w,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16.r), border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2.w)),
          child: Icon(Icons.family_restroom_rounded, color: Colors.white, size: 28.sp)),
      ]),
    )),
  );

  Widget _stats() => GridView.count(
    crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
    crossAxisSpacing: 12.w, mainAxisSpacing: 12.h, childAspectRatio: 1.4,
    children: const [
      InfoCard(title: "Child's Attendance", value: '92%', icon: Icons.check_circle_rounded, iconColor: Color(0xFF10B981), bgColor: Color(0xFFECFDF5), trend: 'This month'),
      InfoCard(title: 'Avg. Grade', value: 'A+', icon: Icons.star_rounded, iconColor: Color(0xFF8B5CF6), bgColor: Color(0xFFF5F3FF), trend: 'Top 5%'),
      InfoCard(title: 'Fee Status', value: 'Due', icon: Icons.credit_card_rounded, iconColor: Color(0xFFEF4444), bgColor: Color(0xFFFEF2F2), trend: '₹12,500 pending'),
      InfoCard(title: 'Pending Tasks', value: '04', icon: Icons.assignment_rounded, iconColor: Color(0xFFF59E0B), bgColor: Color(0xFFFFFBEB), trend: '1 due today'),
    ],
  );

  Widget _childCard() => Container(
    padding: EdgeInsets.all(20.r),
    decoration: BoxDecoration(
      gradient: theme.gradient, borderRadius: BorderRadius.circular(24.r),
      boxShadow: [BoxShadow(color: theme.primary.withValues(alpha: 0.3), blurRadius: 20.r, offset: Offset(0, 8.h))],
    ),
    child: Row(children: [
      Container(width: 56.w, height: 56.w,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16.r)),
        child: Icon(Icons.school_rounded, color: Colors.white, size: 28.sp)),
      SizedBox(width: 16.w),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Alex Rivera', style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.w900, color: Colors.white)),
        Text('Grade 12-A • Roll #24', style: GoogleFonts.inter(fontSize: 12.sp, color: Colors.white.withValues(alpha: 0.7))),
        SizedBox(height: 8.h),
        Row(children: [
          _chip('Attendance: 92%'),
          SizedBox(width: 8.w),
          _chip('Grade: A+'),
        ]),
      ])),
    ]),
  );

  Widget _chip(String t) => Container(
    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8.r)),
    child: Text(t, style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w700, color: Colors.white)),
  );

  Widget _quickActions(BuildContext context) {
    final actions = [
      {'label': 'Attendance',  'icon': Icons.check_circle_rounded,  'color': const Color(0xFF10B981), 'screen': const AttendanceScreen()},
      {'label': 'Results',     'icon': Icons.emoji_events_rounded,  'color': const Color(0xFF8B5CF6), 'screen': const ResultsScreen()},
      {'label': 'Timetable',   'icon': Icons.calendar_today_rounded,'color': const Color(0xFF3B82F6), 'screen': const TimetableScreen(isStudent: true)},
      {'label': 'Fee Payment', 'icon': Icons.credit_card_rounded,   'color': const Color(0xFFEF4444), 'screen': const FeesScreen()},
      {'label': 'Notices',     'icon': Icons.notifications_rounded, 'color': const Color(0xFFF59E0B), 'screen': const NoticesScreen()},
      {'label': 'Documents',   'icon': Icons.folder_rounded,        'color': const Color(0xFF64748B), 'screen': const DocumentsScreen()},
    ];
    return GridView.count(
      crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12.w, mainAxisSpacing: 12.h, childAspectRatio: 1.1,
      children: actions.map((a) => QuickBtn(
        label: a['label'] as String, icon: a['icon'] as IconData, color: a['color'] as Color,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => a['screen'] as Widget)),
      )).toList(),
    );
  }

  Widget _modules(BuildContext context) {
    final modules = [
      {'title': "View Child's Profile",    'desc': 'Academic & personal info',    'emoji': '👤', 'color': const Color(0xFF3B82F6), 'screen': const AttendanceScreen()},
      {'title': 'Attendance & Leave',      'desc': 'Monthly attendance report',   'emoji': '📅', 'color': const Color(0xFF10B981), 'screen': const AttendanceScreen()},
      {'title': 'Marks & Results',         'desc': 'Grade cards & reports',       'emoji': '🏆', 'color': const Color(0xFF8B5CF6), 'screen': const ResultsScreen()},
      {'title': 'Fee Details',             'desc': 'Online fee payment',          'emoji': '💳', 'color': const Color(0xFFEF4444), 'screen': const FeesScreen()},
      {'title': 'Exam Schedule',           'desc': 'Upcoming exams & admit card', 'emoji': '📋', 'color': const Color(0xFFF59E0B), 'screen': const TimetableScreen(isStudent: true)},
      {'title': 'Assignments',             'desc': 'Pending & submitted',         'emoji': '📝', 'color': const Color(0xFFF97316), 'screen': const AttendanceScreen()},
      {'title': 'Notices & Alerts',        'desc': 'School announcements',        'emoji': '📢', 'color': const Color(0xFFD97706), 'screen': const NoticesScreen()},
      {'title': 'Download Documents',      'desc': 'Certificates, receipts',      'emoji': '📁', 'color': const Color(0xFF64748B), 'screen': const DocumentsScreen()},
    ];
    return Column(
      children: modules.map((m) => FeatureCard(
        title: m['title'] as String, desc: m['desc'] as String, emoji: m['emoji'] as String,
        color: m['color'] as Color,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => m['screen'] as Widget)),
      )).toList(),
    );
  }
}
