import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import '../features/fees_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AccountantDashboard extends StatelessWidget {
  final RoleTheme theme;
  const AccountantDashboard({super.key, required this.theme});

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
              const SectionTitle(title: 'Fee Management'),
              SizedBox(height: 12.h),
              _quickActions(context),
              SizedBox(height: 20.h),
              const SectionTitle(title: 'Financial Modules'),
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
          Text('Finance Dashboard 💼', style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.7))),
          Text('Ms. Priya', style: GoogleFonts.inter(fontSize: 22.sp, fontWeight: FontWeight.w900, color: Colors.white)),
          SizedBox(height: 6.h),
          Container(padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8.r)),
            child: Text('Senior Accountant', style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w700, color: Colors.white))),
        ])),
        Container(width: 52.w, height: 52.h,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16.r), border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2.w)),
          child: Icon(Icons.account_balance_rounded, color: Colors.white, size: 28.sp)),
      ]),
    )),
  );

  Widget _stats() => GridView.count(
    crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
    crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.4,
    children: const [
      InfoCard(title: 'Fee Collected', value: '₹8.2L', icon: Icons.account_balance_wallet_rounded, iconColor: AppColors.accountantPrimary, bgColor: AppColors.accountantLight, trend: 'This month'),
      InfoCard(title: 'Pending Fees', value: '₹1.4L', icon: Icons.pending_rounded, iconColor: Color(0xFFEF4444), bgColor: Color(0xFFFEF2F2), trend: '48 students'),
      InfoCard(title: 'Transactions', value: '342', icon: Icons.receipt_long_rounded, iconColor: Color(0xFF3B82F6), bgColor: AppColors.studentLight, trend: 'This month'),
      InfoCard(title: 'Concessions', value: '12', icon: Icons.discount_rounded, iconColor: Color(0xFFF59E0B), bgColor: Color(0xFFFFFBEB), trend: 'Active'),
    ],
  );

  Widget _quickActions(BuildContext context) {
    final actions = [
      {'label': 'Collect Fee',    'icon': Icons.payments_rounded,          'color': const Color(0xFF16A34A)},
      {'label': 'Fee Structure',  'icon': Icons.list_alt_rounded,          'color': const Color(0xFF3B82F6)},
      {'label': 'Invoice',        'icon': Icons.receipt_rounded,           'color': const Color(0xFF8B5CF6)},
      {'label': 'Reports',        'icon': Icons.bar_chart_rounded,         'color': const Color(0xFFF97316)},
      {'label': 'Reminders',      'icon': Icons.notification_important_rounded, 'color': const Color(0xFFEF4444)},
      {'label': 'Concession',     'icon': Icons.discount_rounded,          'color': const Color(0xFFF59E0B)},
    ];
    return GridView.count(
      crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.1,
      children: actions.map((a) => QuickBtn(
        label: a['label'] as String, icon: a['icon'] as IconData, color: a['color'] as Color,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FeesScreen())),
      )).toList(),
    );
  }

  Widget _modules(BuildContext context) {
    final modules = [
      {'title': 'Fee Structure Mgmt',    'desc': 'Set & manage fee structures',    'emoji': '💰', 'color': const Color(0xFF16A34A)},
      {'title': 'Fee Collection',        'desc': 'Online & offline payments',      'emoji': '💳', 'color': const Color(0xFF3B82F6)},
      {'title': 'Invoice & Receipts',    'desc': 'Generate & download receipts',   'emoji': '🧾', 'color': const Color(0xFF8B5CF6)},
      {'title': 'Payment History',       'desc': 'Track all transactions',         'emoji': '📜', 'color': const Color(0xFF0EA5E9)},
      {'title': 'Due & Reminders',       'desc': 'Send payment reminders',         'emoji': '⏰', 'color': const Color(0xFFEF4444)},
      {'title': 'Income & Expense',      'desc': 'Financial statements',           'emoji': '📊', 'color': const Color(0xFFF97316)},
      {'title': 'Ledger & Journals',     'desc': 'Accounting entries',             'emoji': '📒', 'color': const Color(0xFF64748B)},
      {'title': 'Bank Reconciliation',   'desc': 'Match bank statements',          'emoji': '🏦', 'color': const Color(0xFF10B981)},
      {'title': 'Budget Management',     'desc': 'Annual budget planning',         'emoji': '📈', 'color': const Color(0xFFD97706)},
      {'title': 'Tax Reports',           'desc': 'GST & tax compliance',           'emoji': '🗂️', 'color': const Color(0xFFF59E0B)},
    ];
    return Column(
      children: modules.map((m) => FeatureCard(
        title: m['title'] as String, desc: m['desc'] as String, emoji: m['emoji'] as String,
        color: m['color'] as Color,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FeesScreen())),
      )).toList(),
    );
  }
}
