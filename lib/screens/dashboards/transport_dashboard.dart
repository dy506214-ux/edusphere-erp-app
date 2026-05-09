import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';

class TransportDashboard extends StatelessWidget {
  final RoleTheme theme;
  const TransportDashboard({super.key, required this.theme});

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
              const SectionTitle(title: 'Live Tracking'),
              const SizedBox(height: 12),
              _liveTracking(context),
              const SizedBox(height: 20),
              const SectionTitle(title: 'Quick Actions'),
              const SizedBox(height: 12),
              _quickActions(context),
              const SizedBox(height: 20),
              const SectionTitle(title: 'Transport Modules'),
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
          Text('Transport Manager 🚌', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.7))),
          Text('Mr. Rajan', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 6),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
            child: Text('Fleet: 12 Vehicles Active', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white))),
        ])),
        Container(width: 52, height: 52,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.4), width: 2)),
          child: const Icon(Icons.directions_bus_rounded, color: Colors.white, size: 28)),
      ]),
    )),
  );

  Widget _stats() => GridView.count(
    crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
    crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.4,
    children: const [
      InfoCard(title: 'Active Vehicles', value: '12', icon: Icons.directions_bus_rounded, iconColor: AppColors.transportPrimary, bgColor: AppColors.transportLight, trend: '2 in maintenance'),
      InfoCard(title: 'Students Today', value: '486', icon: Icons.people_rounded, iconColor: AppColors.studentPrimary, bgColor: AppColors.studentLight, trend: 'Boarded safely'),
      InfoCard(title: 'Routes Active', value: '08', icon: Icons.route_rounded, iconColor: Color(0xFF10B981), bgColor: Color(0xFFECFDF5), trend: 'All on time'),
      InfoCard(title: 'Drivers', value: '14', icon: Icons.person_rounded, iconColor: Color(0xFFF59E0B), bgColor: Color(0xFFFFFBEB), trend: '12 on duty'),
    ],
  );

  Widget _liveTracking(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Bus Route 3 - Live', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppColors.textDark, fontSize: 15)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text('ON TIME', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.green)),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.background, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.map_rounded, size: 40, color: theme.primary),
                const SizedBox(height: 8),
                Text('Live Map View', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMedium)),
                Text('Bus #KA-01-1234 • ETA: 8 min', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textLight)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            _trackChip(Icons.speed_rounded, '42 km/h', Colors.blue),
            const SizedBox(width: 8),
            _trackChip(Icons.people_rounded, '38 students', Colors.green),
            const SizedBox(width: 8),
            _trackChip(Icons.location_on_rounded, '2.4 km away', Colors.orange),
          ]),
        ],
      ),
    );
  }

  Widget _trackChip(IconData icon, String label, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(child: Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: color), overflow: TextOverflow.ellipsis)),
      ]),
    ),
  );

  Widget _quickActions(BuildContext context) {
    final actions = [
      {'label': 'Add Vehicle',   'icon': Icons.add_circle_rounded,       'color': const Color(0xFF16A34A)},
      {'label': 'Routes',        'icon': Icons.route_rounded,            'color': const Color(0xFF3B82F6)},
      {'label': 'Drivers',       'icon': Icons.person_rounded,           'color': const Color(0xFF8B5CF6)},
      {'label': 'Schedule',      'icon': Icons.schedule_rounded,         'color': const Color(0xFFF97316)},
      {'label': 'Alerts',        'icon': Icons.warning_rounded,          'color': const Color(0xFFEF4444)},
      {'label': 'Reports',       'icon': Icons.bar_chart_rounded,        'color': const Color(0xFF64748B)},
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
      {'title': 'Vehicle Management',    'desc': 'Add/manage fleet vehicles',      'emoji': '🚌', 'color': const Color(0xFFEF4444)},
      {'title': 'Route Management',      'desc': 'Create & manage routes',         'emoji': '🗺️', 'color': const Color(0xFF3B82F6)},
      {'title': 'Driver Management',     'desc': 'Driver profiles & documents',    'emoji': '👨‍✈️', 'color': const Color(0xFF8B5CF6)},
      {'title': 'Student Allocation',    'desc': 'Assign students to routes',      'emoji': '👥', 'color': const Color(0xFF10B981)},
      {'title': 'Daily Schedule',        'desc': 'Morning & evening trips',        'emoji': '📅', 'color': const Color(0xFFF97316)},
      {'title': 'Live Tracking',         'desc': 'GPS location tracking',          'emoji': '📍', 'color': const Color(0xFF16A34A)},
      {'title': 'Delay Alerts',          'desc': 'SMS/Push notifications',         'emoji': '⚠️', 'color': const Color(0xFFD97706)},
      {'title': 'Vehicle Maintenance',   'desc': 'Service & fitness records',      'emoji': '🔧', 'color': const Color(0xFF64748B)},
      {'title': 'Driver Attendance',     'desc': 'Daily driver check-in',          'emoji': '✅', 'color': const Color(0xFF0EA5E9)},
      {'title': 'Transport Reports',     'desc': 'Usage & performance reports',    'emoji': '📊', 'color': const Color(0xFFF59E0B)},
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
