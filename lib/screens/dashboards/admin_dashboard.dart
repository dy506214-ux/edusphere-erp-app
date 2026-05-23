import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AdminDashboard extends StatelessWidget {
  final RoleTheme theme;
  const AdminDashboard({super.key, required this.theme});

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
              const SectionTitle(title: 'Admin Control Panel'),
              SizedBox(height: 12.h),
              _quickActions(context),
              SizedBox(height: 20.h),
              const SectionTitle(title: 'Management Modules'),
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
          Text('Admin Panel 🛡️', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.7))),
          Text('Dr. Sharma', style: GoogleFonts.inter(fontSize: 22.sp, fontWeight: FontWeight.w900, color: Colors.white)),
          SizedBox(height: 6.h),
          Container(padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8.r)),
            child: Text('School Administrator', style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w700, color: Colors.white))),
        ])),
        Container(width: 52.w, height: 52.h,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16.r), border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2.w)),
          child: Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 28.sp)),
      ]),
    )),
  );

  Widget _stats() => GridView.count(
    crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
    crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.4,
    children: const [
      InfoCard(title: 'Total Students', value: '1,240', icon: Icons.school_rounded, iconColor: AppColors.studentPrimary, bgColor: AppColors.studentLight, trend: '+12 this month'),
      InfoCard(title: 'Total Teachers', value: '86', icon: Icons.person_rounded, iconColor: AppColors.teacherPrimary, bgColor: AppColors.teacherLight, trend: '4 departments'),
      InfoCard(title: 'Attendance Today', value: '94%', icon: Icons.check_circle_rounded, iconColor: Color(0xFF10B981), bgColor: Color(0xFFECFDF5), trend: 'School average'),
      InfoCard(title: 'Fee Collection', value: '₹8.2L', icon: Icons.account_balance_rounded, iconColor: Color(0xFF8B5CF6), bgColor: Color(0xFFF5F3FF), trend: 'This month'),
    ],
  );

  Widget _quickActions(BuildContext context) {
    final actions = [
      {'label': 'Manage Users',   'icon': Icons.manage_accounts_rounded,  'color': const Color(0xFF8B5CF6)},
      {'label': 'Announcements',  'icon': Icons.campaign_rounded,         'color': const Color(0xFFF97316)},
      {'label': 'Reports',        'icon': Icons.bar_chart_rounded,        'color': const Color(0xFF3B82F6)},
      {'label': 'Settings',       'icon': Icons.settings_rounded,         'color': const Color(0xFF64748B)},
      {'label': 'Backup',         'icon': Icons.backup_rounded,           'color': const Color(0xFF10B981)},
      {'label': 'Audit Trail',    'icon': Icons.history_rounded,          'color': const Color(0xFFEF4444)},
    ];
    return GridView.count(
      crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.1,
      children: actions.map((a) => QuickBtn(
        label: a['label'] as String, icon: a['icon'] as IconData, color: a['color'] as Color,
        onTap: () => showToast(context, 'Opening ${a['label']}...'),
      )).toList(),
    );
  }

  Widget _modules(BuildContext context) {
    final modules = [
      {'title': 'User & Role Management',   'desc': 'Create/manage users & roles',    'emoji': '👥', 'color': const Color(0xFF8B5CF6)},
      {'title': 'Class & Section Setup',    'desc': 'Academic structure management',  'emoji': '🏫', 'color': const Color(0xFF3B82F6)},
      {'title': 'Syllabus Management',      'desc': 'Curriculum & lesson plans',      'emoji': '📚', 'color': const Color(0xFF10B981)},
      {'title': 'Exam & Result Mgmt',       'desc': 'Schedule & publish results',     'emoji': '📋', 'color': const Color(0xFFF59E0B)},
      {'title': 'Global Announcements',     'desc': 'SMS/Email/Push notifications',   'emoji': '📢', 'color': const Color(0xFFF97316)},
      {'title': 'Student Performance',      'desc': 'Analytics & reports',            'emoji': '📈', 'color': const Color(0xFF0EA5E9)},
      {'title': 'Attendance Reports',       'desc': 'Class & teacher reports',        'emoji': '✅', 'color': const Color(0xFF16A34A)},
      {'title': 'System Settings',          'desc': 'Configuration & backup',         'emoji': '⚙️', 'color': const Color(0xFF64748B)},
      {'title': 'Data Security',            'desc': 'Access logs & audit trail',      'emoji': '🔒', 'color': const Color(0xFFEF4444)},
      {'title': 'Feedback & Surveys',       'desc': 'Collect school feedback',        'emoji': '📊', 'color': const Color(0xFFD97706)},
    ];
    return Column(
      children: modules.map((m) => FeatureCard(
        title: m['title'] as String, desc: m['desc'] as String, emoji: m['emoji'] as String,
        color: m['color'] as Color,
        onTap: () => showToast(context, 'Opening ${m['title']}...'),
      )).toList(),
    );
  }
}
