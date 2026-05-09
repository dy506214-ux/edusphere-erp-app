import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';

import '../../utils/pdf_utils.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final achievements = [
      {'title': 'Academic Excellence',    'desc': 'Scored A+ in Term 1',          'emoji': '🏆', 'date': 'Jan 2026',  'color': const Color(0xFFFFFBEB), 'content': 'This Certificate of Merit is awarded to Alex Rivera for outstanding academic performance and securing an A+ grade in Term 1 Examination.'},
      {'title': 'Perfect Attendance',     'desc': '100% attendance in December',  'emoji': '🎯', 'date': 'Dec 2025',  'color': const Color(0xFFECFDF5), 'content': 'This Certificate is proudly presented to Alex Rivera in recognition of maintaining 100% attendance for the entire month of December 2025.'},
      {'title': 'Science Olympiad',       'desc': '2nd place in district level',  'emoji': '🥈', 'date': 'Nov 2025',  'color': AppColors.studentLight, 'content': 'This certificate recognizes the exceptional scientific talent of Alex Rivera for winning the 2nd place in the District Level Science Olympiad.'},
      {'title': 'Best Project Award',     'desc': 'Physics project competition',  'emoji': '🔬', 'date': 'Oct 2025',  'color': const Color(0xFFF5F3FF), 'content': 'Awarded to Alex Rivera for the innovative project "Quantum Dynamics" which secured the 1st prize in the Physics Project Competition.'},
      {'title': 'Sports Champion',        'desc': 'Inter-school cricket team',    'emoji': '🏏', 'date': 'Sep 2025',  'color': const Color(0xFFFEF2F2), 'content': 'Awarded to Alex Rivera for exemplary sportsmanship and contribution to the Inter-school Cricket Championship win.'},
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PageHeader(title: 'Achievements & Certificates', subtitle: '5 earned', theme: roleThemes['student']!),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: achievements.length,
              itemBuilder: (_, i) {
                final a = achievements[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: a['color'] as Color, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                  child: Row(children: [
                    Text(a['emoji'] as String, style: const TextStyle(fontSize: 36)),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a['title'] as String, style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppColors.textDark, fontSize: 14)),
                      const SizedBox(height: 3),
                      Text(a['desc'] as String, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMedium)),
                      const SizedBox(height: 3),
                      Text(a['date'] as String, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textLight)),
                    ])),
                    GestureDetector(
                      onTap: () async {
                        showToast(context, 'Generating Certificate...');
                        await PDFUtils.generateAndSavePDF(context, 'Certificate - ${a['title'] as String}', a['content'] as String);
                      },
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                        child: const Icon(Icons.download_rounded, size: 18, color: AppColors.studentPrimary),
                      ),
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
