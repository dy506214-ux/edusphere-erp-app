import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
            padding: const EdgeInsets.all(16),
            sliver: SliverList(delegate: SliverChildListDelegate([
              _stats(),
              const SizedBox(height: 20),
              const SectionTitle(title: 'Child Overview'),
              const SizedBox(height: 12),
              _childCard(),
              const SizedBox(height: 20),
              const SectionTitle(title: 'Quick Access'),
              const SizedBox(height: 12),
              _quickActions(context),
              const SizedBox(height: 20),
              const SectionTitle(title: 'Parent Features'),
              const SizedBox(height: 12),
              _modules(context),
              const SizedBox(height: 100),
            ])),
          ),
        ],
      ),
    );
  }

  Widget _header() => Container(
    decoration: BoxDecoration(gradient: theme.gradient),
    child: SafeArea(bottom: false, child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Hello 👋', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.7))),
          Text('Mr. Smith', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 6),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
            child: Text('Parent of Alex Rivera', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white))),
        ])),
        Container(width: 52, height: 52,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.4), width: 2)),
          child: const Icon(Icons.family_restroom_rounded, color: Colors.white, size: 28)),
      ]),
    )),
  );

  Widget _stats() => GridView.count(
    crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
    crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.4,
    children: const [
      InfoCard(title: "Child's Attendance", value: '92%', icon: Icons.check_circle_rounded, iconColor: Color(0xFF10B981), bgColor: Color(0xFFECFDF5), trend: 'This month'),
      InfoCard(title: 'Avg. Grade', value: 'A+', icon: Icons.star_rounded, iconColor: Color(0xFF8B5CF6), bgColor: Color(0xFFF5F3FF), trend: 'Top 5%'),
      InfoCard(title: 'Fee Status', value: 'Due', icon: Icons.credit_card_rounded, iconColor: Color(0xFFEF4444), bgColor: Color(0xFFFEF2F2), trend: '₹12,500 pending'),
      InfoCard(title: 'Pending Tasks', value: '04', icon: Icons.assignment_rounded, iconColor: Color(0xFFF59E0B), bgColor: Color(0xFFFFFBEB), trend: '1 due today'),
    ],
  );

  Widget _childCard() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: theme.gradient, borderRadius: BorderRadius.circular(24),
      boxShadow: [BoxShadow(color: theme.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
    ),
    child: Row(children: [
      Container(width: 56, height: 56,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.school_rounded, color: Colors.white, size: 28)),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Alex Rivera', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
        Text('Grade 12-A • Roll #24', style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(0.7))),
        const SizedBox(height: 8),
        Row(children: [
          _chip('Attendance: 92%'),
          const SizedBox(width: 8),
          _chip('Grade: A+'),
        ]),
      ])),
    ]),
  );

  Widget _chip(String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
    child: Text(t, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
  );

  Widget _quickActions(BuildContext context) {
    final actions = [
      {'label': 'Attendance',  'icon': Icons.check_circle_rounded,  'color': const Color(0xFF10B981), 'screen': const AttendanceScreen()},
      {'label': 'Results',     'icon': Icons.emoji_events_rounded,  'color': const Color(0xFF8B5CF6), 'screen': const ResultsScreen()},
      {'label': 'Timetable',   'icon': Icons.calendar_today_rounded,'color': const Color(0xFF3B82F6), 'screen': const TimetableScreen()},
      {'label': 'Fee Payment', 'icon': Icons.credit_card_rounded,   'color': const Color(0xFFEF4444), 'screen': const FeesScreen()},
      {'label': 'Notices',     'icon': Icons.notifications_rounded, 'color': const Color(0xFFF59E0B), 'screen': const NoticesScreen()},
      {'label': 'Documents',   'icon': Icons.folder_rounded,        'color': const Color(0xFF64748B), 'screen': const DocumentsScreen()},
    ];
    return GridView.count(
      crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.1,
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
      {'title': 'Exam Schedule',           'desc': 'Upcoming exams & admit card', 'emoji': '📋', 'color': const Color(0xFFF59E0B), 'screen': const TimetableScreen()},
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
