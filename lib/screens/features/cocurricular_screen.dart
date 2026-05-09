import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';

class CoCurricularScreen extends StatelessWidget {
  const CoCurricularScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final activities = [
      {'name': 'Cricket Team',      'type': 'Sports',  'emoji': '🏏', 'schedule': 'Mon, Wed 4-6 PM', 'status': 'Active',   'color': const Color(0xFFECFDF5)},
      {'name': 'Science Club',      'type': 'Academic','emoji': '🔬', 'schedule': 'Tue, Thu 3-5 PM', 'status': 'Active',   'color': AppColors.studentLight},
      {'name': 'Art & Craft',       'type': 'Arts',    'emoji': '🎨', 'schedule': 'Fri 2-4 PM',      'status': 'Active',   'color': const Color(0xFFFEF2F2)},
      {'name': 'Debate Club',       'type': 'Academic','emoji': '🎤', 'schedule': 'Wed 3-5 PM',      'status': 'Upcoming', 'color': const Color(0xFFFFFBEB)},
      {'name': 'Music Band',        'type': 'Arts',    'emoji': '🎵', 'schedule': 'Sat 10-12 AM',    'status': 'Active',   'color': const Color(0xFFF5F3FF)},
      {'name': 'Chess Club',        'type': 'Sports',  'emoji': '♟️', 'schedule': 'Mon 3-4 PM',      'status': 'Active',   'color': AppColors.background},
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PageHeader(title: 'Co-curricular Activities', subtitle: '6 activities enrolled', theme: roleThemes['student']!),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: activities.length,
              itemBuilder: (_, i) {
                final a = activities[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: a['color'] as Color, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                  child: Row(children: [
                    Text(a['emoji'] as String, style: const TextStyle(fontSize: 32)),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(a['name'] as String, style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppColors.textDark, fontSize: 14)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                          child: Text(a['type'] as String, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.textMedium)),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      Text('📅 ${a['schedule']}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMedium)),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: a['status'] == 'Active' ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(a['status'] as String, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800,
                        color: a['status'] == 'Active' ? const Color(0xFF10B981) : AppColors.warning)),
                    ),
                  ]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
